#----------------------------------------------------------------
#  Now_Playing.rb
#
#  Changelog:
#      Paulinchen  2026-09-27: Held the popup back while the screen is dark.
#      Paulinchen  2026-09-26: Created
#
#----------------------------------------------------------------

# Shows the name of the background music in the top right corner for a few seconds, each time a
# new track starts. The names come from the music room of Kagetsumugi's jukebox.
module Now_Playing
  # Frames the popup takes to slide in.
  SLIDE_FRAMES = 15

  # Frames the popup stays fully visible, 3 seconds at 60 frames per second.
  HOLD_FRAMES = 180

  # Frames the popup takes to fade out.
  FADE_FRAMES = 30

  # Gap between the popup and the edges of the screen.
  MARGIN = 8

  # Space between the text and the edges of the popup.
  PADDING = 10

  # Height of the popup.
  HEIGHT = 30

  # Width of the coloured bar on the left of the popup.
  ACCENT_WIDTH = 3

  # Drawn above everything the game shows, message windows included.
  Z = 10_000

  # Size of the text.
  FONT_SIZE = 20

  # Color of the popup behind the text.
  BACKGROUND_COLOR = Color.new(0, 0, 0, 170)

  # Color of the bar on the left of the popup.
  ACCENT_COLOR = Color.new(255, 200, 120)

  # Put in front of the track name.
  PREFIX = "♪ "

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
    Popup.show(title) if title
  end

  # Forgets the current track, so playing it again shows it again. Called from the Audio.bgm_stop hook.
  def self.stopped
    @current = nil
  end

  # The box in the top right corner.
  module Popup
    # Starts showing a track name, replacing the one on screen.
    #
    # @param title [String] the track name
    def self.show(title)
      sprite.bitmap.dispose if sprite.bitmap
      sprite.bitmap = draw(PREFIX + title)
      sprite.opacity = 255
      sprite.visible = true
      @frame = 0
      move
    end

    # Moves the popup on by one frame. Called once per frame from the Graphics.update hook.
    #
    # A map transfer starts the new music while the screen is still black, so the popup waits for
    # the screen to light up and slides in together with the map name.
    def self.update
      return unless @frame && @sprite && !@sprite.disposed?
      return if @frame == 0 && Graphics.brightness < 255

      @frame += 1
      if @frame >= SLIDE_FRAMES + HOLD_FRAMES + FADE_FRAMES
        @sprite.visible = false
        @frame = nil
      else
        move
      end
    end

    # Places the popup for the current frame: sliding in, holding, then fading out.
    def self.move
      width = sprite.bitmap.width
      resting_x = Graphics.width - width - MARGIN
      slide = [@frame.to_f / SLIDE_FRAMES, 1.0].min

      sprite.x = resting_x + ((width + MARGIN) * (1.0 - slide) ** 2).round
      sprite.y = MARGIN

      fading = @frame - SLIDE_FRAMES - HOLD_FRAMES
      sprite.opacity = fading > 0 ? 255 - 255 * fading / FADE_FRAMES : 255
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
      Now_Playing.played(args[0]) rescue nil
      result
    end

    alias now_playing_bgm_stop bgm_stop
    def bgm_stop(*args)
      result = now_playing_bgm_stop(*args)
      Now_Playing.stopped rescue nil
      result
    end
  end

  # Graphics.update runs every frame in every scene, so the popup moves on even in menus and battles.
  class << Graphics
    alias now_playing_update update
    def update
      now_playing_update
      Now_Playing::Popup.update rescue nil
    end
  end
end
