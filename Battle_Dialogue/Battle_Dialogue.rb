#----------------------------------------------------------------
#  Battle_Dialogue.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Took a battle message as soon as it is added, not only when the battle waits for it
#                            - Kept a message's speaker on the message, where whoever adds it may set it
#                            - Drew faces and speaker names the way the message window does, faces in their hue
#      Paulinchen  2026-10-02: Showed an enemy's answers to Talk and other event lines at the enemy side
#      Paulinchen  2026-09-29: Read the untranslated game's speaker lines and wrapped text without spaces
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# Shows what is said in a battle in boxes that slide out at the screen's sides, in the style of
# Map_Display, instead of the message window, which stops the battle until a key is pressed. A
# line of the player's team slides out at the left, one of the enemy side at the right, each with a
# bar of its side's color at the screen's edge, the speaker's face and name, and a tail fading out
# into the battle; a summon speaks on its summoner's side. A message nobody says, such as
# "... appears!", shows as a see-through strip below the skill name at the top. It must never
# interrupt the game, so every entry point rescues.
module Battle_Dialogue
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

  # Space between the text and the edges of a box.
  PADDING = 8

  # Size of the face, shrunk from the face file's 96 pixels.
  FACE_SIZE = 48

  # Size of a face in a face file, and faces in a row of it.
  FACE_FILE_SIZE = 96
  FACE_COLUMNS = 4

  # Height of a line of text, and the text's size.
  LINE_HEIGHT = 18
  FONT_SIZE = 16

  # Color behind the text of a box, and of a strip, which lets more of the battle through.
  BACKGROUND_COLOR = Color.new(0, 0, 0, 170)
  STRIP_BACKGROUND_COLOR = Color.new(0, 0, 0, 110)

  # Color of the bar at a box's outer edge and of the speaker's name, for the player's team and
  # for the enemy side.
  FRIEND_COLOR = Color.new(120, 220, 120)
  ENEMY_COLOR = Color.new(255, 110, 110)

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
  rescue
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
    boxes = boxes_at(side)
    boxes.shift.dispose while boxes.size >= (side == :top ? MAX_STRIPS : MAX_BOXES)
    boxes << Window_BattleDialogue.new(said ? face_name.to_s : "", face_index.to_i, face_hue, name, lines, side)
    arrange
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

  # Moves the boxes on by one frame. Called once per frame by the battle.
  def self.update
    all_boxes.each do |boxes|
      boxes.each(&:update)
      boxes.select(&:done?).each(&:dispose)
      boxes.reject!(&:done?)
    end
    arrange
  rescue
  end

  # Takes every box off the screen. Called when the battle ends.
  def self.clear
    all_boxes.flatten.each(&:dispose)
    @boxes = nil
  rescue
  end

  # Stacks the boxes of each place from its top down, the newest first.
  def self.arrange
    [:left, :right, :top].each do |side|
      y = side == :top ? STRIP_TOP : TOP
      boxes_at(side).reverse_each do |box|
        box.y = y
        y += box.height + (side == :top ? 2 : MARGIN)
      end
    end
  end

  # @param side [Symbol] :left, :right or :top
  # @return [Array<Window_BattleDialogue>] the boxes there, the oldest first
  def self.boxes_at(side)
    @boxes ||= { :left => [], :right => [], :top => [] }
    @boxes[side]
  end

  # @return [Array<Array<Window_BattleDialogue>>] the boxes of every place
  def self.all_boxes
    [:left, :right, :top].map { |side| boxes_at(side) }
  end
end

# One message in a box at a side of the screen, sliding in, or in a strip at the top, fading in;
# then holding, then fading out.
class Window_BattleDialogue < Window_Base
  include Battle_Dialogue

  # @param face_name [String] the face file, empty for none
  # @param face_index [Integer] the face in the file
  # @param face_hue [Integer] the hue the face is drawn in
  # @param name [String, nil] who speaks
  # @param lines [Array<String>] the message's lines, their codes converted
  # @param side [Symbol] :left for the player's team, :right for the enemy side, :top for a strip
  def initialize(face_name, face_index, face_hue, name, lines, side)
    @side = side
    @face_name = face_name
    @face_index = face_index
    @face_hue = face_hue
    @name = name
    @text = lines.map { |line| Battle_Dialogue.plain(line) }.join(" ")
    @text_lines = @side == :top ? [@text] : wrap(@text)
    super(0, 0, box_width, box_height)
    self.opacity = 0
    self.z = 210
    @frame = 0
    @hold = [HOLD_FRAMES + HOLD_FRAMES_PER_CHARACTER * @text.size, MAX_HOLD_FRAMES].min
    draw_box
    place
  end

  # Leaves no room between the edge of the window and its contents, so the window is the box.
  #
  # @return [Integer] 0
  def standard_padding
    0
  end

  # Moves the box on by one frame.
  def update
    super
    @frame += 1
    place unless done?
  end

  # @return [Boolean] whether the box has faded out
  def done?
    @frame >= SLIDE_FRAMES + @hold + FADE_FRAMES
  end

  # Places the box for the current frame: sliding or fading in, holding, then fading out.
  #
  # Named place because Window#move already exists and takes a rectangle.
  def place
    coming = [@frame.to_f / SLIDE_FRAMES, 1.0].min
    fading = @frame - SLIDE_FRAMES - @hold
    opacity = fading > 0 ? 255 - 255 * fading / FADE_FRAMES : 255

    if @side == :top
      self.x = (Graphics.width - width) / 2
      opacity = [opacity, (255 * coming).round].min
    else
      slide = ((width + MARGIN) * (1.0 - coming) ** 2).round
      self.x = @side == :right ? Graphics.width - width - MARGIN + slide : MARGIN - slide
    end
    self.contents_opacity = opacity
  end

  private

  # @return [Integer] a side box's width with its tail, or a strip's, which fits its text within
  #   half the screen
  def box_width
    return WIDTH + FADE_WIDTH unless @side == :top

    measure = Bitmap.new(1, 1)
    measure.font.size = FONT_SIZE
    [measure.text_size(@text).width + PADDING * 2, Graphics.width / 2].min
  ensure
    measure.dispose if measure
  end

  # @return [Integer] the height the face, the name and the text need
  def box_height
    text = (@name ? 1 : 0) + @text_lines.size
    padding = @side == :top ? 2 : PADDING
    [text * LINE_HEIGHT, face? ? FACE_SIZE : 0].max + padding * 2
  end

  # @return [Boolean] whether the box shows a face
  def face?
    !@face_name.empty?
  end

  # @return [Color] the color of the bar and the name: the speaker's side's
  def side_color
    @side == :right ? ENEMY_COLOR : FRIEND_COLOR
  end

  # @return [Integer] where the text starts: after the bar and the face at the left, after the tail
  #   at the right
  def text_x
    return PADDING if @side == :top
    return FADE_WIDTH + PADDING if @side == :right

    ACCENT_WIDTH + PADDING + (face? ? FACE_SIZE + PADDING : 0)
  end

  # @return [Integer] how wide the text may be, between the face and the bar
  def text_width
    return box_width - PADDING * 2 if @side == :top

    WIDTH - PADDING * 2 - ACCENT_WIDTH - (face? ? FACE_SIZE + PADDING : 0)
  end

  # Draws the box: a strip with its text, or a box with the bar and the face at its outer edge,
  # the name and the text, and the tail fading out.
  def draw_box
    contents.font.size = FONT_SIZE
    if @side == :top
      contents.fill_rect(contents.rect, STRIP_BACKGROUND_COLOR)
      contents.draw_text(0, 2, contents.width, LINE_HEIGHT, @text, 1)
      return
    end

    draw_background
    draw_small_face if face?

    y = PADDING
    if @name
      contents.font.color = side_color
      contents.draw_text(text_x, y, text_width, LINE_HEIGHT, @name)
      y += LINE_HEIGHT
    end
    contents.font.color = normal_color
    @text_lines.each do |line|
      contents.draw_text(text_x, y, text_width, LINE_HEIGHT, line)
      y += LINE_HEIGHT
    end
  end

  # Draws the background, solid behind the face and the text and fading out in the tail, and the
  # bar at the outer edge.
  def draw_background
    full = contents.width
    height = contents.height
    clear = Color.new(BACKGROUND_COLOR.red, BACKGROUND_COLOR.green, BACKGROUND_COLOR.blue, 0)

    if @side == :right
      contents.gradient_fill_rect(0, 0, FADE_WIDTH, height, clear, BACKGROUND_COLOR)
      contents.fill_rect(FADE_WIDTH, 0, full - FADE_WIDTH, height, BACKGROUND_COLOR)
      contents.fill_rect(full - ACCENT_WIDTH, 0, ACCENT_WIDTH, height, side_color)
    else
      contents.fill_rect(0, 0, WIDTH, height, BACKGROUND_COLOR)
      contents.gradient_fill_rect(WIDTH, 0, FADE_WIDTH, height, BACKGROUND_COLOR, clear)
      contents.fill_rect(0, 0, ACCENT_WIDTH, height, side_color)
    end
  end

  # Draws the face shrunk to FACE_SIZE, next to the bar at the box's outer edge. It is drawn full
  # size by draw_face_hue, the way every window draws a face, then shrunk.
  def draw_small_face
    face = Bitmap.new(FACE_FILE_SIZE, FACE_FILE_SIZE)
    draw_onto(face) { draw_face_hue(@face_name, @face_index, @face_hue, 0, 0) }
    x = @side == :right ? contents.width - ACCENT_WIDTH - PADDING - FACE_SIZE : ACCENT_WIDTH + PADDING
    contents.stretch_blt(Rect.new(x, PADDING, FACE_SIZE, FACE_SIZE), face, face.rect)
  rescue
    @face_name = ""
  ensure
    face.dispose if face
  end

  # Lets the block's drawing land on another bitmap than the box's contents.
  #
  # @param bitmap [Bitmap] the bitmap to draw on
  def draw_onto(bitmap)
    box = contents
    self.contents = bitmap
    yield
  ensure
    self.contents = box
  end

  # Breaks a text into lines that fit the box, between words, and inside a word too wide for a
  # line of its own, such as Japanese text, which has no spaces.
  #
  # @param text [String] the text
  # @return [Array<String>] the lines
  def wrap(text)
    measure = Bitmap.new(1, 1)
    measure.font.size = FONT_SIZE
    room = text_width
    lines = [""]
    text.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if measure.text_size(candidate).width <= room
        lines[-1] = candidate
      elsif measure.text_size(word).width <= room
        lines << word
      else
        lines << "" unless lines.last.empty?
        word.each_char do |character|
          lines << "" if measure.text_size(lines.last + character).width > room && !lines.last.empty?
          lines[-1] += character
        end
      end
    end
    lines.reject(&:empty?)
  ensure
    measure.dispose if measure
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
        Battle_Dialogue.update
      end

      alias_method :battle_dialogue_terminate, :terminate
      define_method(:terminate) do
        Battle_Dialogue.clear
        battle_dialogue_terminate
      end
    end
  rescue
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
  rescue
  end
end
