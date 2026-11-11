#----------------------------------------------------------------
#  Now_Playing.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Logged each track shown, and each failure once instead of passing over it
#      Paulinchen  2026-11-07: Drew the box as a HUD of the Mod Framework when it is installed
#      Paulinchen  2026-09-27: Held the popup back while the screen is dark.
#      Paulinchen  2026-09-26: Created
#
#----------------------------------------------------------------

# Shows the name of the background music in the top right corner for a few seconds, each time a
# new track starts. The names come from the music room of Kagetsumugi's jukebox.
module Now_Playing
  # Frames the popup takes to slide in. The Mod Framework slides its HUD at its own pace.
  SLIDE_FRAMES = 15

  # Frames the box stays fully visible, 3 seconds at 60 frames per second.
  HOLD_FRAMES = 180

  # Frames the popup takes to fade out. The Mod Framework fades its HUD at its own pace.
  FADE_FRAMES = 30

  # Gap between the popup and the edges of the screen.
  MARGIN = 8

  # Space between the text and the edges of the popup.
  PADDING = 10

  # Height of the popup.
  HEIGHT = 30

  # Width of the coloured bar on the left of the box.
  ACCENT_WIDTH = 3

  # Drawn above everything the game shows, message windows included.
  Z = 10_000

  # Size of the text in the popup. The HUD takes the size of the player's Interface Look.
  FONT_SIZE = 20

  # Color of the popup behind the text. The HUD takes the background of the player's Interface Look.
  BACKGROUND_COLOR = Color.new(0, 0, 0, 170)

  # Color of the bar on the left of the box.
  ACCENT_COLOR = Color.new(255, 200, 120)

  # Put in front of the track name.
  PREFIX = "♪ "

  # The HUD's place among the Mod Framework's HUDs in the top right corner: lower lies nearer the
  # edge, and the framework's notices are 100.
  ORDER = 50

  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR of what the mod did and what failed, while the Mod Framework is missing.
  LOG_FILE = "Now Playing.log"

  # Writes a line into the Mod Framework's log, or into LOG_FILE without the framework.
  #
  # @param message [String] what happened
  def self.log(message)
    return Mod_Framework.log("Now Playing: #{message}") if defined?(Mod_Framework.log)

    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end

  # Logs a failure once per place and error class, since the hooks run every frame.
  #
  # @param place [String] what failed
  # @param error [Exception] the error raised
  def self.failed(place, error)
    @failed ||= {}
    return if @failed[[place, error.class]]

    @failed[[place, error.class]] = true
    log("#{place} FAILED: #{error.class}: #{error.message}")
  end

  # Track names by BGM file name, read from the music room once.
  #
  # The music room keys its tracks by id, a popup needs them by the file that is played.
  #
  # @return [Hash{String => String}] names by lower-case file name, without folder or extension
  def self.titles
    @titles ||= NWConst::Library::BGM_SCENE_ITEMS.values.each_with_object({}) do |item, titles|
      titles[key_of(item[:file])] = item[:name].to_s if item[:file] && item[:name]
    end
  rescue
    @titles = {}
  end

  # Turns a played file into the key of titles: "Audio/BGM/Title.ogg" becomes "title".
  #
  # @param file [String] the file as handed to Audio.bgm_play
  # @return [String] the key
  def self.key_of(file)
    File.basename(file.to_s, ".*").downcase
  end

  # Shows the name of a track that just started. Called from the Audio.bgm_play hook.
  #
  # The game fades music in by playing the same file again every frame at a higher volume, so only
  # a file other than the current one counts as a new track.
  #
  # @param file [String] the file as handed to Audio.bgm_play
  def self.played(file)
    key = key_of(file)
    return if key == @current

    @current = key
    title = titles[key]
    return unless title

    show(PREFIX + title)
    log("showed #{title} (#{key})")
  end

  # Forgets the current track, so playing it again shows it again. Called from the Audio.bgm_stop hook.
  def self.stopped
    @current = nil
  end

  # Starts showing a text, replacing the one on screen. The next frame puts it on the screen.
  #
  # @param text [String] the text
  def self.show(text)
    @text = text
    @frame = 0
    @drawn = false
  end

  # @return [String] the text the box shows, empty before the first track
  def self.text
    @text.to_s
  end

  # Moves the box on by one frame. Called once per frame from the Graphics.update hook.
  #
  # A map transfer starts the new music while the screen is still black, so the box waits for
  # the screen to light up and slides in together with the map name.
  def self.update
    return unless @frame

    draw unless @drawn
    return if waiting?

    @frame += 1
    @frame = nil if @frame >= SLIDE_FRAMES + HOLD_FRAMES + FADE_FRAMES
    Popup.place(@frame) unless @hud
  end

  # Puts the text on the screen: in the Mod Framework's HUD when it shows one, else in the popup.
  #
  # The music starts inside a scene's work, so the HUD shows between two frames instead.
  def self.draw
    @drawn = true
    @hud = Hud.show
    @hud ? Popup.hide : Popup.show(@text)
  end

  # @return [Boolean] whether the box waits for the screen to light up
  def self.waiting?
    @frame == 0 && Graphics.brightness < 255
  end

  # Tells whether the HUD hides now: before the first track, while it waits for the screen to
  # light up, and once it stayed for HOLD_FRAMES. Asked by the HUD every frame.
  #
  # @return [Boolean] whether it hides
  def self.hidden?
    @frame.nil? || waiting? || @frame >= SLIDE_FRAMES + HOLD_FRAMES
  end

  # The box as a HUD of the Mod Framework, which stacks it below the other HUDs of the top right
  # corner, such as MGQ Online's.
  module Hud
    # Shows the HUD unless it shows already. It stays across scenes and hides between tracks.
    #
    # @return [Boolean] whether it shows; false without the Mod Framework or when the framework
    #   refused it
    def self.show
      return false unless const_defined?(:Box, false)
      return refused("the Mod Framework runs without its DLL, so the popup shows the music") unless Mod_Framework.available?

      @handle = Mod_Framework::UI.show(Box) unless @handle && @handle.shown?
      return true if @handle

      refused("the Mod Framework refused the HUD, so the popup shows the music")
    rescue => e
      @handle = nil
      refused("showing the HUD FAILED, so the popup shows the music: #{e.class}: #{e.message}")
    end

    # Writes why the HUD does not show into the Mod Framework's log, once.
    #
    # @param message [String] what happened
    # @return [Boolean] false, as the HUD does not show
    def self.refused(message)
      Mod_Framework.log("Now Playing: #{message}") unless @refused
      @refused = true
      false
    end
  end

  # The box in the top right corner when the Mod Framework is missing or refused its HUD.
  module Popup
    # Draws a text into the popup, which then waits beyond the screen's edge to slide in.
    #
    # @param text [String] the text
    def self.show(text)
      sprite.bitmap.dispose if sprite.bitmap
      sprite.bitmap = draw(text)
      place(0)
    end

    # Takes the popup off the screen.
    def self.hide
      @sprite.visible = false if @sprite && !@sprite.disposed?
    end

    # Places the popup for a frame of its showing: sliding in, holding, then fading out.
    #
    # @param frame [Integer, nil] frames since it slid in, nil once it is over
    def self.place(frame)
      return hide unless frame && @sprite && !@sprite.disposed? && @sprite.bitmap

      width = @sprite.bitmap.width
      resting_x = Graphics.width - width - MARGIN
      slide = [frame.to_f / SLIDE_FRAMES, 1.0].min

      @sprite.x = resting_x + ((width + MARGIN) * (1.0 - slide) ** 2).round
      @sprite.y = MARGIN

      fading = frame - SLIDE_FRAMES - HOLD_FRAMES
      @sprite.opacity = fading > 0 ? 255 - 255 * fading / FADE_FRAMES : 255
      @sprite.visible = true
    end

    # Draws the popup around a text.
    #
    # @param text [String] the text
    # @return [Bitmap] the popup, sized to fit the text
    def self.draw(text)
      measure = Bitmap.new(1, 1)
      measure.font.size = FONT_SIZE
      text_width = measure.text_size(text).width
      measure.dispose

      bitmap = Bitmap.new(ACCENT_WIDTH + text_width + PADDING * 2, HEIGHT)
      bitmap.font.size = FONT_SIZE
      bitmap.fill_rect(bitmap.rect, BACKGROUND_COLOR)
      bitmap.fill_rect(0, 0, ACCENT_WIDTH, HEIGHT, ACCENT_COLOR)
      bitmap.draw_text(ACCENT_WIDTH + PADDING, 0, text_width + PADDING, HEIGHT, text)
      bitmap
    end

    # The sprite of the popup, created on first use.
    #
    # A viewport of its own keeps it on screen across every scene, since no scene disposes it.
    #
    # @return [Sprite] the sprite
    def self.sprite
      if @sprite.nil? || @sprite.disposed?
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @sprite = Sprite.new(@viewport)
        @sprite.visible = false
      end
      @sprite
    end
  end
end

if defined?(Mod_Framework::UI.show)
  module Now_Playing
    module Hud
      # Short name for the framework's UI module.
      UI = Mod_Framework::UI

      # The bar's color as the framework takes it.
      ACCENT = [ACCENT_COLOR.red.to_i, ACCENT_COLOR.green.to_i, ACCENT_COLOR.blue.to_i]

      # The bar and the name, above the game's windows as the popup is.
      class Box < UI::Component
        # Describes the box, which slides in as a track starts and out once it stayed.
        def render
          hud anchor: :top_right, order: ORDER, id: :now_playing, place_name: "Now playing", layer: :over,
              enter: :slide, hide_while: -> { Now_Playing.hidden? } do
            stack row: true do
              divider vertical: true, color: ACCENT, thickness: ACCENT_WIDTH, align_self: :stretch
              text -> { Now_Playing.text }, typo: :subtitle1
            end
          end
        end
      end
    end
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first, its result is returned unchanged, and the
# mod's part never raises, so music and drawing work the same with and without the mod.

unless Audio.respond_to?(:now_playing_bgm_play)
  # Every piece of music passes Audio.bgm_play: map and battle music, the title screen, loading a
  # save, the jukebox and the game's own fades.
  class << Audio
    alias now_playing_bgm_play bgm_play
    def bgm_play(*args)
      result = now_playing_bgm_play(*args)
      begin
        Now_Playing.played(args[0])
      rescue => e
        Now_Playing.failed("played", e)
      end
      result
    end

    alias now_playing_bgm_stop bgm_stop
    def bgm_stop(*args)
      result = now_playing_bgm_stop(*args)
      begin
        Now_Playing.stopped
      rescue => e
        Now_Playing.failed("stopped", e)
      end
      result
    end
  end

  # Graphics.update runs every frame in every scene, so the box moves on even in menus and battles.
  class << Graphics
    alias now_playing_update update
    def update
      now_playing_update
      begin
        Now_Playing.update
      rescue => e
        Now_Playing.failed("update", e)
      end
    end
  end
end
