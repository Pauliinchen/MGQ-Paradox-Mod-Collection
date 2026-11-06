#----------------------------------------------------------------
#  Map_Display.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Drew the map name through the Mod Framework's UI layer
#                            - Slid the name in and out
#      Paulinchen  2026-09-27: Created
#
#----------------------------------------------------------------

# Shows the name of the map in the top left corner for a few seconds after each map change.
module Map_Display
  # Seconds the name stays before it slides out.
  SECONDS = 3

  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR, which only appears when the Mod Framework is missing.
  LOG_FILE = "Map Display.log"

  # Writes a line to the log.
  #
  # @param message [String] What happened.
  def self.log(message)
    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end
end

if defined?(Mod_Framework::UI.replace_window)
  module Map_Display
    # Short name for the framework's UI module.
    UI = Mod_Framework::UI

    # The map name with an accent bar at its right, drawn in place of the game's map name window.
    class Banner < UI::Component
      # The game's map name window, which the game opens after each map change.
      param :game_window

      # Notes how often the game drew its window so far, so only a later drawing shows the name.
      def setup
        @refreshes = game_window.refreshes
      end

      # Describes the name on a box that slides in after a map change and out after SECONDS.
      def render
        hud anchor: :top_left, order: 50, id: :map_display, place_name: "Map name", enter: :slide,
            hide_while: -> { hidden? } do
          stack row: true do
            text UI::Game.map_name, typo: :subtitle1
            divider vertical: true, color: :primary, thickness: 3, align_self: :stretch
          end
        end
      end

      # Tells whether the name hides now. Asked every frame, it also starts the seconds once the game
      # draws its window anew, which it does as it opens the window after a map change.
      #
      # @return [Boolean] Whether it hides.
      def hidden?
        if game_window.refreshes != @refreshes
          @refreshes = game_window.refreshes
          @opened_at = Graphics.frame_count
        end
        @opened_at.nil? || !$game_map.name_display || $game_map.display_name.empty? ||
          Graphics.frame_count - @opened_at >= SECONDS * Graphics.frame_rate
      end
    end

    UI.replace_window Window_MapName, Banner
  end
else
  Map_Display.log("Map Display needs the Mod Framework, which is missing or too old, so the game shows its own map name.")
end
