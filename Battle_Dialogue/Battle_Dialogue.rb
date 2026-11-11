#----------------------------------------------------------------
#  Battle_Dialogue.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Logged each failure once into the Mod Framework's log instead of passing over it
#      Paulinchen  2026-11-09: Let the strip give up its side room at half the screen as before
#                            - Took fading lines off at once at the battle's end and gave the strip's text its old width
#                            - Drew the battle lines through the Mod Framework, which it now needs
#                            - Logged each line shown with its side and speaker
#      Paulinchen  2026-10-06: Took a battle message as soon as it is added, not only when the battle waits for it
#                            - Kept a message's speaker on the message, where whoever adds it may set it
#                            - Drew faces and speaker names the way the message window does, faces in their hue
#      Paulinchen  2026-10-02: Showed an enemy's answers to Talk and other event lines at the enemy side
#      Paulinchen  2026-09-29: Read the untranslated game's speaker lines and wrapped text without spaces
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# Shows what is said in a battle in boxes that slide out at the screen's sides instead of the
# message window, which stops the battle until a key is pressed. A line of the player's team slides
# out at the left, one of the enemy side at the right, each with a bar of its side's color at the
# screen's edge, the speaker's face and name, and a tail fading out into the battle; a summon speaks
# on its summoner's side. A message nobody says, such as "... appears!", shows as a see-through
# strip below the skill name at the top. It must never interrupt the game, so every entry point
# rescues.
module Battle_Dialogue
  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR, which only appears when the Mod Framework is missing.
  LOG_FILE = "Battle Dialogue.log"

  # Writes a line to the log.
  #
  # @param message [String] What happened.
  def self.log(message)
    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end
end

if defined?(Mod_Framework::UI.column)
  module Battle_Dialogue
    # Short name for the framework's UI module.
    UI = Mod_Framework::UI

    # Logs a failure into the Mod Framework's log once per place and error class, since most places
    # run every frame.
    #
    # @param place [String] What failed.
    # @param error [Exception] The error raised.
    def self.failed(place, error)
      @failed ||= {}
      return if @failed[[place, error.class]]

      @failed[[place, error.class]] = true
      Mod_Framework.log("Battle Dialogue: #{place} FAILED: #{error.class}: #{error.message}")
    rescue
    end

    # Turns the boxes off without uninstalling them.
    ENABLED = true

    # Frames a box takes to slide or fade in.
    SLIDE_FRAMES = 15

    # Frames a box stays at least, and per character of its text, and at most.
    HOLD_FRAMES = 90
    HOLD_FRAMES_PER_CHARACTER = 2
    MAX_HOLD_FRAMES = 300

    # Frames a box takes to fade out.
    FADE_FRAMES = 30

    # Boxes on one side at most, and strips at the top. A new one pushes the oldest out.
    MAX_BOXES = 3
    MAX_STRIPS = 2

    # Width of a box at a side, without the tail it fades out in.
    WIDTH = 240

    # Width of the tail on a box's inner side, in which its background fades out into the battle.
    FADE_WIDTH = 48

    # Where the boxes at the sides start, below the strips.
    TOP = 88

    # Where the strips start, right below the skill name the battle shows at the top.
    STRIP_TOP = 52

    # Gap between the boxes and the edges of the screen, and between two boxes.
    MARGIN = 8

    # Gap between two strips.
    STRIP_GAP = 2

    # Pixels of the framework's unit of room, in which padding is given.
    UNIT = 4

    # Room between the bar, the face, the text and the edges of a box, in units.
    PADDING = 2

    # Room above and below the text of a strip, and at its sides, in units.
    STRIP_PADDING = [0.5, 2]

    # Size of the face, shrunk from the face file's 96 pixels.
    FACE_SIZE = 48

    # Height of a line of text.
    LINE_HEIGHT = 18

    # Color behind the text of a box, and of a strip, which lets more of the battle through.
    BACKGROUND_COLOR = [0, 0, 0, 170]
    STRIP_BACKGROUND_COLOR = [0, 0, 0, 110]

    # Color of the bar at a box's outer edge and of the speaker's name, for the player's team and
    # for the enemy side.
    FRIEND_COLOR = [120, 220, 120]
    ENEMY_COLOR = [255, 110, 110]

    # The game's text color the text is written in, the message window's normal color.
    TEXT_COLOR = 0

    # Outline of the texts: the game's own, Font.default_out_color, which is half see-through.
    TEXT_OUTLINE = [0, 0, 0, 128]

    # Width of the bar.
    ACCENT_WIDTH = 3

    # A speaker's name box code of the message system, "\n<Name>", its backslash converted.
    SPEAKER_CODE = /\en<([^>]*)>/

    # The untranslated game's speaker line, the name in brackets opening a message: "【Name】".
    SPEAKER_LINE = /\A【([^】]*)】\s*/

    # A summon's line starts with its name alone on the first line, "Sylph:".
    SUMMON_NAME = /\A([^:\e]{1,30}):\s*\z/

    # A converted code of the message system, such as a color, an icon or a wait, and any other.
    MESSAGE_CODE = /\e[A-Za-z]+(\[[^\]]*\])?(<[^>]*>)?/
    OTHER_CODE = /\e./

    # The columns the boxes of each side and the strips stack in, the newest on top.
    UI.column :battle_left, at: [MARGIN, TOP], gap: MARGIN, align: :left
    UI.column :battle_right, at: [Graphics.width - MARGIN, TOP], gap: MARGIN, align: :right
    UI.column :battle_top, at: [Graphics.width / 2, STRIP_TOP], gap: STRIP_GAP, align: :center

    # A line a box or a strip shows: its id, its side (:left, :right or :top), who says it, their
    # face, the plain text, the frames its box starts fading out at and is gone at, and the handle
    # UI.show answered for its box.
    Line = Struct.new(:id, :side, :name, :face_name, :face_index, :face_hue, :text, :fades_at, :gone_at, :handle)

    # A line at a side: the bar at the screen's edge, the face beside it, the name and the text,
    # and the tail toward the screen's middle.
    class Box < UI::Component
      # The line it shows.
      param :line

      # Describes the box, which slides in from its side, stays until its time is over, then fades
      # out where it stands.
      def render
        left = line.side == :left
        hud column: left ? :battle_left : :battle_right, id: line.id, layer: :over, width: WIDTH + FADE_WIDTH,
            enter: :move, leave: :fade, motion_frames: [SLIDE_FRAMES, FADE_FRAMES],
            background: { color: BACKGROUND_COLOR, fade: [left ? :right : :left, FADE_WIDTH] }, border: false, padding: 0,
            outline: TEXT_OUTLINE, mouse: :none, movable: false, :if => -> { Graphics.frame_count < line.fades_at } do
          stack row: true, spacing: 0 do
            bar if left
            stack row: true, spacing: PADDING, grow: 1, padding: room(left) do
              face if left
              stack spacing: 0, grow: 1 do
                text line.name, typo: :body2, line_height: LINE_HEIGHT, color: side_color, fit: :squeeze if line.name
                text line.text, typo: :body2, line_height: LINE_HEIGHT, color: TEXT_COLOR, wrap: true unless line.text.empty?
              end
              face unless left
            end
            bar unless left
          end
        end
      end

      private

      # @return [Array] the color of the bar and the name: the speaker's side's
      def side_color
        line.side == :right ? ENEMY_COLOR : FRIEND_COLOR
      end

      # Tells the room around the face and the text, which keeps the tail on the inner side free.
      #
      # @param left [Boolean] Whether the box is at the left.
      # @return [Array<Integer>] Top, right, bottom and left, in units.
      def room(left)
        tail = PADDING + FADE_WIDTH / UNIT
        left ? [PADDING, tail, PADDING, PADDING] : [PADDING, PADDING, PADDING, tail]
      end

      # Describes the bar at the box's outer edge, without the room a divider keeps at its sides.
      def bar
        divider vertical: true, color: side_color, thickness: ACCENT_WIDTH, align_self: :stretch, padding: 0
      end

      # Describes the speaker's face, shrunk from the face file and drawn in its hue, when the line
      # has one.
      def face
        return if line.face_name.empty?

        avatar face: [line.face_name, line.face_index], hue: line.face_hue, shape: :box, background: false,
               width: FACE_SIZE, height: FACE_SIZE, align_self: :start
      end
    end

    # A line nobody says, in a see-through strip at the top as wide as its text, half the screen at
    # most, where the strip gives its side room to the text.
    class Strip < UI::Component
      # The line it shows.
      param :line

      # Describes the strip, which fades in, stays until its time is over, then fades out.
      def render
        hud column: :battle_top, id: line.id, layer: :over, motion_frames: [SLIDE_FRAMES, FADE_FRAMES],
            background: STRIP_BACKGROUND_COLOR, border: false, padding: STRIP_PADDING, padding_shrinks: true,
            max_size: [Graphics.width / 2, nil], outline: TEXT_OUTLINE, mouse: :none, movable: false,
            :if => -> { Graphics.frame_count < line.fades_at } do
          text line.text, typo: :body2, line_height: LINE_HEIGHT, color: TEXT_COLOR, fit: :squeeze
        end
      end
    end

    # Reports whether a battle is on screen, whose messages show in boxes.
    #
    # @return [Boolean]
    def self.active?
      ENABLED && $game_party.in_battle && !over? ? true : false
    end

    # Tells whether the battle is won or lost, whose messages stay in the message window.
    #
    # Victory screens such as Victory_Screen.rb wait for these messages to be read, so a box would
    # skip their pages.
    #
    # @return [Boolean] Whether the victory or defeat is being shown.
    def self.over?
      $game_temp.in_victory_message || BattleManager.instance_variable_get(:@phase).nil?
    end

    # Marks a battler as the speaker of the messages the block shows, whose side decides the box's.
    #
    # @param battler [Game_Battler, nil] the battler
    # @return [Object] what the block returns
    def self.speaking(battler)
      earlier = $game_message.speaker
      $game_message.speaker = battler
      yield
    ensure
      $game_message.speaker = earlier
    end

    # Takes the waiting message out of the message window and shows it in a box.
    #
    # @return [Boolean] whether it took one; a message with choices or number input stays
    def self.take_message
      message = $game_message
      return false unless message.has_text? && !message.choice? && !message.num_input?

      face_hue = message.respond_to?(:face_hue) ? message.face_hue.to_i : 0
      show(message.face_name, message.face_index, message.texts.dup, face_hue, speaker_of(message))
      message.clear
      true
    rescue => e
      failed("taking a message", e)
      false
    end

    # Finds the battler who says a message: the one it names, for the stand-in the game uses for
    # automatic skills the battler it stands in for.
    #
    # @param message [Game_Message] the message
    # @return [Game_Battler, nil] the battler, nil when the message names none
    def self.speaker_of(message)
      speaker = message.speaker
      defined?(Game_Master) && speaker.is_a?(Game_Master) ? speaker.observer : speaker
    end

    # Shows a message: in a box at its speaker's side when a character says it, in a strip at the
    # top otherwise.
    #
    # @param face_name [String] the face file, empty for none
    # @param face_index [Integer] the face in the file
    # @param lines [Array<String>] the message's lines
    # @param face_hue [Integer] the hue the face is drawn in
    # @param speaker [Game_Battler, nil] who says it, nil to tell their side by the name and face
    def self.show(face_name, face_index, lines, face_hue = 0, speaker = nil)
      # The untranslated game adds a speaker's line and what they say as one line with a break.
      lines = converted(lines).map { |line| line.split("\n") }.flatten
      name = nil

      if (first = lines.first) && first =~ SPEAKER_CODE
        name = plain($1)
        lines[0] = first.sub(SPEAKER_CODE, "")
      elsif first && first =~ SPEAKER_LINE
        name = plain($1)
        lines[0] = first.sub(SPEAKER_LINE, "")
      elsif first && first =~ SUMMON_NAME
        name = plain($1)
        lines.shift
      end

      lines = lines.reject { |line| line.strip.empty? }
      return if lines.empty? && name.nil?

      said = name || !face_name.to_s.empty?
      side = !said ? :top : (speaker ? side_of_battler(speaker) : side_of_speaker(name, face_name.to_s))
      text = lines.map { |line| plain(line) }.join(" ")
      fades_at = Graphics.frame_count + SLIDE_FRAMES + [HOLD_FRAMES + HOLD_FRAMES_PER_CHARACTER * text.size, MAX_HOLD_FRAMES].min
      @shown = @shown.to_i + 1
      line = Line.new("battle_dialogue_#{@shown}", side, name, said ? face_name.to_s : "", face_index.to_i, face_hue.to_i, text,
                      fades_at, fades_at + FADE_FRAMES)

      boxes = boxes_at(side)
      boxes.shift.handle.hide(at_once: true) while boxes.size >= (side == :top ? MAX_STRIPS : MAX_BOXES)
      line.handle = UI.show(side == :top ? Strip : Box, line: line)
      boxes << line if line.handle
      speaker_named = name || (said ? "the face #{face_name} #{face_index}" : "nobody")
      Mod_Framework.log("Battle Dialogue showed line #{@shown} at the #{side}, said by #{speaker_named}")
    end

    # Fills in the message system's codes of a message's lines the way every window does, before the
    # speaker is read from them, so the name shown is the one the message window would show.
    #
    # @param lines [Array<String>] the lines
    # @return [Array<String>] the lines, the codes left starting with "\e"
    def self.converted(lines)
      converter = Window_Base.new(0, 0, 32, 32)
      converter.visible = false
      lines.map { |line| converter.convert_escape_characters(line.to_s) }
    rescue
      lines.map { |line| line.to_s.gsub("\\", "\e") }
    ensure
      converter.dispose if converter
    end

    # Turns a converted line into plain text: colors, icons and waits left out.
    #
    # @param line [String] the line
    # @return [String] the plain text
    def self.plain(line)
      line.gsub(MESSAGE_CODE, "").gsub(OTHER_CODE, "").strip
    end

    # @param battler [Game_Battler] the battler who speaks
    # @return [Symbol] :right for an enemy, :left for the player's team
    def self.side_of_battler(battler)
      $game_troop.members.include?(battler) ? :right : :left
    end

    # Tells the side of a line no battler is marked for, such as an enemy's answer in a Talk event or
    # a line of a battle's story event.
    #
    # Talk events often name the enemy differently from its battler, so anyone not in the party counts
    # as the enemy side, and an enemy's name wins over a companion of the same kind.
    #
    # @param name [String, nil] the speaker's name, which may end in a companion's "(Affection:...)"
    # @param face_name [String] the face file, empty for none
    # @return [Symbol] :left for a party member, :right otherwise
    def self.side_of_speaker(name, face_name)
      if name
        name = name.sub(/\s*\([^)]*\)\s*\z/, "").strip
        return :right if $game_troop.members.any? { |enemy| enemy.original_name == name }

        friend = $game_party.members.any? { |actor| actor.name == name }
      else
        friend = $game_party.members.any? { |actor| actor.face_name == face_name }
      end
      friend ? :left : :right
    end

    # Takes every box off the screen at once, also one fading out. Called when the battle ends.
    def self.clear
      all_boxes.flatten.each { |line| line.handle.hide(at_once: true) }
      @boxes = nil
    rescue => e
      failed("clearing the boxes", e)
    end

    # Tells the lines whose boxes show at a place, those fading out too, which still hold their place
    # and count toward its most.
    #
    # @param side [Symbol] :left, :right or :top
    # @return [Array<Line>] the lines, the oldest first
    def self.boxes_at(side)
      @boxes ||= { :left => [], :right => [], :top => [] }
      @boxes[side].reject! { |line| Graphics.frame_count >= line.gone_at }
      @boxes[side]
    end

    # @return [Array<Array<Line>>] the lines of the boxes of every place
    def self.all_boxes
      [:left, :right, :top].map { |side| boxes_at(side) }
    end
  end

  # The game hooks, which wrap the originals. The game's plugins load after the Patch folder and some
  # define battle methods anew, so the hooks go in once the first scene starts.
  module Battle_Dialogue
    # Installs the hooks. Calling it again does nothing.
    def self.install
      return if @installed
      @installed = true

      # A message names the battler who says it in its speaker, which whoever adds a message in a
      # battle may set and which goes with the message when it is cleared.
      Game_Message.class_eval do
        attr_accessor :speaker unless method_defined?(:speaker)

        alias_method :battle_dialogue_clear, :clear
        define_method(:clear) do
          battle_dialogue_clear
          self.speaker = nil
        end
      end

      Scene_Battle.class_eval do
        alias_method :battle_dialogue_wait_for_message, :wait_for_message
        define_method(:wait_for_message) do
          next if Battle_Dialogue.active? && Battle_Dialogue.take_message

          battle_dialogue_wait_for_message
        end

        # A skill's line is its user's, a line on being hit or falling the target's.
        alias_method :battle_dialogue_process_skill_word, :process_skill_word
        define_method(:process_skill_word) do |*args|
          Battle_Dialogue.speaking(@subject) { battle_dialogue_process_skill_word(*args) }
        end

        alias_method :battle_dialogue_process_down_word, :process_down_word
        define_method(:process_down_word) do |target, *args|
          Battle_Dialogue.speaking(target) { battle_dialogue_process_down_word(target, *args) }
        end

        # A message added without the battle waiting for it, such as one another mod adds, is taken
        # before the message window sees it.
        alias_method :battle_dialogue_update_basic, :update_basic
        define_method(:update_basic) do
          Battle_Dialogue.take_message if Battle_Dialogue.active?
          battle_dialogue_update_basic
        end

        alias_method :battle_dialogue_terminate, :terminate
        define_method(:terminate) do
          Battle_Dialogue.clear
          battle_dialogue_terminate
        end
      end
    rescue => e
      failed("install", e)
    end
  end

  unless SceneManager.respond_to?(:battle_dialogue_run)
    begin
      class << SceneManager
        alias battle_dialogue_run run
        def run
          Battle_Dialogue.install rescue nil
          battle_dialogue_run
        end
      end
    rescue => e
      Battle_Dialogue.failed("SceneManager hook", e)
    end
  end
else
  Battle_Dialogue.log("Battle Dialogue needs the Mod Framework, which is missing or too old, so battles show their lines in the message window.")
end
