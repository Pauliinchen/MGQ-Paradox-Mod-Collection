#----------------------------------------------------------------
#  Map_Display.rb
#
#  Changelog:
#      Paulinchen  2026-09-27: Created
#
#----------------------------------------------------------------

# Shows the name of the map in the top left corner for a few seconds after each map change, in the
# style of Now Playing with the coloured bar on the right.
#
# Scene_Map opens the window after each map change and closes it before the next, so only its
# drawing and movement are replaced.
class Window_MapName
  # Frames the box takes to slide in.
  SLIDE_FRAMES = 15

  # Frames the box stays fully visible, 3 seconds at 60 frames per second.
  HOLD_FRAMES = 180

  # Frames the box takes to fade out.
  FADE_FRAMES = 30

  # Gap between the box and the edges of the screen.
  MARGIN = 8

  # Space between the text and the edges of the box.
  PADDING = 10

  # Height of the box.
  HEIGHT = 30

  # Width of the coloured bar on the right of the box.
  ACCENT_WIDTH = 3

  # Size of the text.
  FONT_SIZE = 20

  # Color of the box behind the text.
  BACKGROUND_COLOR = Color.new(0, 0, 0, 170)

  # Color of the bar on the right of the box.
  ACCENT_COLOR = Color.new(255, 200, 120)

  # Creates the window, hidden until the first map change.
  def initialize
    super(0, MARGIN, 1, HEIGHT)
    self.opacity = 0
    stop
  end

  # Leaves no room between the edge of the window and its contents, so the window is the box.
  #
  # @return [Integer] 0
  def standard_padding
    0
  end

  # Moves the box on by one frame. Called once per frame from Scene_Map.
  def update
    super
    return unless @frame

    close unless $game_map.name_display
    @frame += 1
    if @frame >= SLIDE_FRAMES + HOLD_FRAMES + FADE_FRAMES
      stop
    else
      place
    end
  end

  # Starts showing the name of the map the player just arrived on. Maps without a name show nothing.
  #
  # @return [Window_MapName] self
  def open
    name = $game_map.display_name
    if name.empty? || !$game_map.name_display
      stop
    else
      draw_box(name)
      @frame = 0
      self.visible = true
      place
    end
    self
  end

  # Starts fading the box out, unless it already is.
  #
  # @return [Window_MapName] self
  def close
    @frame = [@frame, SLIDE_FRAMES + HOLD_FRAMES].max if @frame
    self
  end

  # Hides the box until the next map change.
  def stop
    self.visible = false
    @frame = nil
  end

  # Places the box for the current frame: sliding in, holding, then fading out.
  #
  # Named place because Window#move already exists and takes a rectangle.
  def place
    slide = [@frame.to_f / SLIDE_FRAMES, 1.0].min
    self.x = MARGIN - ((width + MARGIN) * (1.0 - slide) ** 2).round

    fading = @frame - SLIDE_FRAMES - HOLD_FRAMES
    self.contents_opacity = fading > 0 ? 255 - 255 * fading / FADE_FRAMES : 255
  end

  # Resizes the window to fit a map name and draws the box around it.
  #
  # @param name [String] the map name
  def draw_box(name)
    contents.font.size = FONT_SIZE
    text_width = contents.text_size(name).width

    self.width = text_width + PADDING * 2 + ACCENT_WIDTH
    create_contents
    contents.font.size = FONT_SIZE
    contents.fill_rect(contents.rect, BACKGROUND_COLOR)
    contents.fill_rect(width - ACCENT_WIDTH, 0, ACCENT_WIDTH, HEIGHT, ACCENT_COLOR)
    contents.draw_text(PADDING, 0, text_width + PADDING, HEIGHT, name)
  end
end
