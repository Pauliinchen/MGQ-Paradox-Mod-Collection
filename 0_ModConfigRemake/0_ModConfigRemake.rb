#----------------------------------------------------------------
#  0_ModConfigRemake.rb
#
#  Changelog:
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# A menu for the options of other mods, which replaces the Mod Config Menu: mods add their entries to
# NWConst::Config::MOD_CONTENTS as they would for it, and need no change. It lists the mods, by the
# "[Mod Name]" their options start with, next to the options of the one chosen: in a Mods tab of the
# tabbed options screen that newer translations bring, and behind its own entry of the options
# screen otherwise.
#
# With 0_ModConfigMenu.rb still installed, it takes that menu's place, and it must never interrupt the
# game, so every entry point rescues.
module ModConfigRemake
  # The tab of the tabbed options screen that holds the mods' options.
  TAB = "Mods"

  # Where the list names options of no mod: neither named "[Mod Name] ..." nor indented under one.
  GLOBAL = "Global"

  # The mod's name at the start of an option's name, "[Mod Name] Option", which lists the option
  # under that mod.
  MOD_NAME = /\A\s*\[([^\]]+)\]\s*/

  # The start of an option's name that sits under the option above it, "   Option" or "-> Option".
  INDENTED = /\A(\s|->)/

  # Where the menu starts on the options screen without tabs, below its help.
  TOP = 120

  # Whether 0_ModConfigMenu.rb, which loads before this script, is installed, whose menu this one
  # replaces.
  ORIGINAL = NWConst::Config.const_defined?(:MOD_CONTENTS)

  # Reads the values an option can take, from its :values, an array or a proc, or else from DATA.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [Array] The values in order, none when it has none.
  def self.values_of(entry)
    values = entry[:values]
    values = values.call if values.respond_to?(:call)
    values ||= NWConst::Config::DATA[entry[:key]]
    values ? values.to_a : []
  rescue
    []
  end

  # Reads an option's current value.
  #
  # @param key [Symbol] The option.
  # @return [Object] Its value in $game_system.conf, its default until it was changed.
  def self.value_of(key)
    value = $game_system.conf[key]
    value.nil? ? NWConst::Config::DEFAULT[key] : value
  end

  # Finds a value among an option's values.
  #
  # Decimals from a :values proc are computed anew each time, so they only match within a margin.
  #
  # @param values [Array] The option's values.
  # @param value [Object] The value to find.
  # @return [Integer, nil] Its place, nil when it is none of them.
  def self.index_of(values, value)
    values.index { |candidate| candidate.is_a?(Float) || value.is_a?(Float) ? (candidate.to_f - value.to_f).abs < 1e-6 : candidate == value }
  rescue
    nil
  end

  # Writes an option's value as the menu shows it.
  #
  # @param entry [Hash] The option's entry.
  # @return [String] The name DATA_TEXT gives the value, else the value itself.
  def self.value_text(entry)
    value = value_of(entry[:key])
    texts = NWConst::Config::DATA_TEXT[entry[:key]]
    named = texts[value] if texts
    return named[:name].to_s if named && named[:name]

    value.is_a?(Float) ? format("%.2f", value) : value.to_s
  rescue
    ""
  end

  # Reads a text of an entry that may be a proc.
  #
  # @param text [String, Proc, nil] The text.
  # @return [String] The text, "" for none.
  def self.text(text)
    (text.respond_to?(:call) ? text.call : text).to_s
  rescue
    ""
  end

  # Writes the help of an option: its own, then its value's, with eval<...> filled in like the
  # game's own options.
  #
  # @param entry [Hash] The option's entry.
  # @return [String] The help.
  def self.help_text(entry)
    help = text(entry[:help])
    if entry[:sub]
      texts = NWConst::Config::DATA_TEXT[entry[:key]]
      named = texts[value_of(entry[:key])] if texts
      extra = named ? text(named[:help]) : ""
      help += "\r\n#{extra}" unless extra.empty? || help.include?(extra)
    end
    help.gsub(/eval<(\S+)>/) { eval($1).to_s rescue "" }
  rescue
    ""
  end

  # Sorts the mods' options by mod: an option named "[Mod Name] ..." goes to that mod's group, an
  # indented one to the group of the option above it, any other one to GLOBAL.
  #
  # Some mods name every option "[Mod Name] ...", so a name that has a group already adds to it.
  #
  # @return [Array<Array(String, Array<Hash>)>] Each mod's name and entries, GLOBAL first while it has
  #   any, the others in the order they first appear in MOD_CONTENTS, Return left out.
  def self.groups
    current = GLOBAL
    grouped = NWConst::Config::MOD_CONTENTS.each_with_object({ GLOBAL => [] }) do |entry, groups|
      next if entry[:key] == :return

      name = text(entry[:name])
      current = name[MOD_NAME, 1] || (name =~ INDENTED ? current : GLOBAL)
      (groups[current] ||= []) << entry
    end
    grouped.delete(GLOBAL) if grouped[GLOBAL].empty?
    grouped.to_a
  end

  # Runs a mod's own code, such as an :on_change proc or a button's handler, so that its failure
  # leaves the menu running.
  #
  # @return [Object, nil] What the block returns, nil when it fails.
  def self.safely
    yield
  rescue
    nil
  end

  # Tells whether an option can be changed, as its :enable proc says.
  #
  # @param entry [Hash] The option's entry.
  # @return [Boolean] Whether it is not greyed out.
  def self.enabled?(entry)
    entry[:enable] ? (entry[:enable].call ? true : false) : true
  rescue
    true
  end

  # Links the menu to the options screen, once.
  #
  # The translation's plugins load after the Patch folder and may replace the options screen, so
  # the menu links to whichever screen is there once the first scene starts.
  def self.install
    return if @installed
    @installed = true

    if defined?(Window_BetterConfigTabs)
      install_tab
    elsif !ORIGINAL
      install_entry
    end
  rescue
  end

  # Gives the tabbed options screen a Mods tab, which shows the menu in the place of the tab's list.
  def self.install_tab
    entry = NWConst::Config::CONTENTS.find { |item| item[:key] == :mod_settings }
    return unless entry

    entry[:group] = TAB
    Scene_Config.class_eval do
      alias_method :mod_config_remake_on_config_tab_ok, :on_config_tab_ok

      # Opens the chosen tab, the Mods tab as the menu of the mods' options.
      define_method(:on_config_tab_ok) do
        tab = @config_window.current_tab
        next mod_config_remake_on_config_tab_ok unless tab && tab[:name] == ModConfigRemake::TAB

        @item_window.clear_items
        open_mod_config(@item_window.x, @item_window.y, @item_window.width, @item_window.height)
      end
    end
  end

  # Opens the menu from its entry of the options screen, which has no tabs.
  #
  # 0_ModConfigMenu.rb links its entry the same way, to start_mod_config, which is this script's.
  def self.install_entry
    Scene_Config.class_eval do
      alias_method :mod_config_remake_create_config_window, :create_config_window

      # Builds the options screen, then has the menu's entry open the menu.
      define_method(:create_config_window) do
        mod_config_remake_create_config_window
        @config_window.set_handler(:mod_settings, method(:start_mod_config))
      end
    end
  end
end

unless ModConfigRemake::ORIGINAL
  module NWConst::Config
    # The entries of the mods' options, which mods insert before the last one, Return.
    #
    # Return stays last although the menu does not show it, since every mod inserts at -2 and would
    # otherwise land before the previous mod's last option.
    MOD_CONTENTS = [{ :key => :return, :name => "Return", :sub => false, :help => "Go back to the options." }]

    CONTENTS.insert(-2, { :key => :mod_settings, :name => "Mod Config Menu", :sub => false,
                          :help => "Change the options of your mods." })

    # Tells mods where to add their options.
    #
    # @return [Array<Hash>] MOD_CONTENTS.
    def self.mod_target
      MOD_CONTENTS
    end
  end
end

# 0_ModConfigMenu.rb's window gives way to this script's: reopening it would mix the two, and the
# mods that hook it load after this script.
Object.send(:remove_const, :Window_ModConfig) if ModConfigRemake::ORIGINAL && Object.const_defined?(:Window_ModConfig)

# The options of the mod chosen in the list of mods: an option's name and value per row, changed with
# left and right, greyed out while its :enable proc says no. Confirming a row without values calls
# the handler named after its key, so the buttons of mods work.
#
# Its rows are the chosen mod's options, so an index counts those, not every entry of MOD_CONTENTS.
class Window_ModConfig < Window_Selectable
  # Mods made for the Mod Config Menu reopen this window and read DATA or MOD_CONTENTS unqualified.
  include NWConst::Config

  # Creates the options, hidden, below the help of the options screen.
  def initialize
    @rows = []
    super(0, ModConfigRemake::TOP, Graphics.width, Graphics.height - ModConfigRemake::TOP)
    deactivate.hide
  end

  # Shows the options of one mod.
  #
  # @param mod [String, nil] The mod, see ModConfigRemake.groups, nil for none.
  def show_mod(mod)
    @mod = mod
    refresh
  end

  # Keeps the place the menu opened at, which mods made for the Mod Config Menu ask it to measure
  # anew after their options change.
  def calculate_and_resize
  end

  # Lists the options of the mod shown, as they were at the last refresh.
  #
  # @return [Array<Hash>] Its entries in MOD_CONTENTS, in order.
  def rows
    @rows
  end

  # Counts the rows.
  #
  # @return [Integer] One per option shown.
  def item_max
    @rows.size
  end

  # Finds the entry of a row.
  #
  # @param index [Integer] The row.
  # @return [Hash, nil] Its entry in MOD_CONTENTS.
  def entry(index = self.index)
    index >= 0 ? @rows[index] : nil
  end

  # Reads the key of a row, which names the handler a row without values calls.
  #
  # @param index [Integer] The row.
  # @return [Symbol, nil] Its key.
  def key(index = self.index)
    row = entry(index)
    row && row[:key]
  end

  # Tells whether a row is an option with values rather than a button.
  #
  # @param index [Integer] The row.
  # @return [Boolean] Whether it has values.
  def sub_exist?(index)
    row = entry(index)
    row && row[:sub] ? true : false
  end

  # Reads the name of a row as its mod gave it.
  #
  # @param index [Integer] The row.
  # @return [String] The name, "" for no row.
  def name(index)
    row = entry(index)
    row ? ModConfigRemake.text(row[:name]) : ""
  end

  # Reads the name of a row's current value.
  #
  # @param index [Integer] The row.
  # @return [String] The value as the menu shows it, "" for a button or no row.
  def sub_name(index)
    sub_exist?(index) ? ModConfigRemake.value_text(entry(index)) : ""
  end

  # Writes the help of a row: its own, then its value's.
  #
  # @param index [Integer] The row.
  # @return [String] The help, "" for no row.
  def help_text(index)
    row = entry(index)
    row ? ModConfigRemake.help_text(row) : ""
  end

  # Reads the help of a row's current value alone.
  #
  # @param index [Integer] The row.
  # @return [String] The value's help from DATA_TEXT, "" for none.
  def sub_help_text(index)
    return "" unless sub_exist?(index)

    row = entry(index)
    texts = DATA_TEXT[row[:key]]
    named = texts[ModConfigRemake.value_of(row[:key])] if texts
    named ? ModConfigRemake.text(named[:help]) : ""
  rescue
    ""
  end

  # Tells whether a row can be used, as its :enable proc says.
  #
  # @param index [Integer] The row.
  # @return [Boolean] Whether it is not greyed out.
  def item_enabled?(index)
    row = entry(index)
    row ? ModConfigRemake.enabled?(row) : false
  end

  # Takes the mod's options anew, then draws every row on contents sized to them.
  #
  # Mods show and hide options just before this runs, so the rows are read here.
  def refresh
    group = ModConfigRemake.groups.find { |name, _| name == @mod }
    @rows = group ? group[1] : []
    create_contents
    super
    call_update_help
  end

  # Draws a row, an option with its value at the right, its name without "[Mod Name]", which the
  # list of mods shows.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    row = entry(index)
    return unless row

    rect = item_rect_for_text(index)
    change_color(normal_color, ModConfigRemake.enabled?(row))
    draw_text(rect, ModConfigRemake.text(row[:name]).sub(ModConfigRemake::MOD_NAME, ""))
    draw_text(rect, ModConfigRemake.value_text(row), 2) if row[:sub]
    change_color(normal_color)
  end

  # Lets every row be confirmed, which the menu answers itself.
  #
  # @return [Boolean] Always true.
  def ok_enabled?
    true
  end

  # Moves an option to its next value, or presses a button: calls the handler named after its key.
  def process_ok
    row = entry
    return unless row
    return change_value(1) if row[:sub]
    return Sound.play_buzzer unless ModConfigRemake.enabled?(row)

    Sound.play_ok
    Input.update
    ModConfigRemake.safely { call_handler(row[:key]) }
  end

  # Moves the option to its next value.
  #
  # @param wrap [Boolean] Whether the cursor may wrap, which does not apply.
  def cursor_right(wrap = false)
    change_value(1)
  end

  # Moves the option to its previous value.
  #
  # @param wrap [Boolean] Whether the cursor may wrap, which does not apply.
  def cursor_left(wrap = false)
    change_value(-1)
  end

  # Shows the help of the current row.
  def update_help
    @help_window.set_text(help_text(index)) if @help_window
  end

  private

  # Moves the current option by some values, wrapping around, and tells its mod.
  #
  # @param step [Integer] 1 for the next value, -1 for the previous.
  def change_value(step)
    row = entry
    return unless row && row[:sub]
    return Sound.play_buzzer unless ModConfigRemake.enabled?(row)

    values = ModConfigRemake.values_of(row)
    return if values.empty?

    at = ModConfigRemake.index_of(values, ModConfigRemake.value_of(row[:key])) || 0
    value = values[(at + step) % values.size]
    $game_system.conf[row[:key]] = value
    ModConfigRemake.safely { row[:on_change].call(value) } if row[:on_change].respond_to?(:call)
    Sound.play_cursor
    refresh
  end
end

# The list of mods at the left of the menu, which shows the options of the mod it points at in the
# options at its right.
class Window_ModConfigMods < Window_Selectable
  # Narrowest width of the list.
  MIN_WIDTH = 140

  # Widest width of the list, which longer names are squeezed into.
  MAX_WIDTH = 220

  # Creates the list, hidden.
  #
  # @param options_window [Window_ModConfig] The options that show the mod chosen.
  def initialize(options_window)
    @options_window = options_window
    @names = []
    super(0, ModConfigRemake::TOP, MIN_WIDTH, fitting_height(1))
    deactivate.hide
  end

  # Lists the mods anew and places the list at the left of an area, as wide as its longest name.
  #
  # @param x [Integer] The area's left edge.
  # @param y [Integer] The area's top edge.
  # @param height [Integer] The area's height.
  def open_at(x, y, height)
    @names = ModConfigRemake.groups.map(&:first)
    move(x, y, list_width, height)
    refresh
    select([[index, 0].max, [item_max - 1, 0].max].min)
  end

  # Counts the mods.
  #
  # @return [Integer] One per mod with options.
  def item_max
    @names.size
  end

  # Draws a mod's name.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    draw_text(item_rect_for_text(index), @names[index])
  end

  # Draws every mod anew, on contents sized to the current number of mods.
  def refresh
    create_contents
    super
  end

  # Moves the cursor, then shows the options of the mod it points at.
  def update
    super
    show_selected if @shown != index
  end

  # Shows the options of the mod the cursor points at.
  def show_selected
    @shown = index
    @options_window.show_mod(index >= 0 ? @names[index] : nil)
  end

  # Shows what the list does, or that no mod has options.
  def update_help
    return unless @help_window

    name = index >= 0 ? @names[index] : nil
    @help_window.set_text(name ? "The options of #{name}.\r\nConfirm to change them." : "None of your mods has options.")
  end

  private

  # Measures the list's width from its longest name.
  #
  # @return [Integer] The width in pixels.
  def list_width
    measure = Bitmap.new(1, 1)
    longest = @names.map { |name| measure.text_size(name).width }.max.to_i
    [[longest + standard_padding * 2 + 8, MIN_WIDTH].max, MAX_WIDTH].min
  ensure
    measure.dispose if measure
  end
end

class Scene_Config
  # 0_ModConfigMenu.rb's start calls create_mod_config_window already, which is this script's.
  unless ModConfigRemake::ORIGINAL
    alias mod_config_remake_start start

    # Starts the options screen with the menu of the mods' options, hidden.
    #
    # Mods set their handlers on the menu once this returns, so it is made here rather than when
    # it opens.
    def start
      mod_config_remake_start
      create_mod_config_window
    end
  end

  # Creates the menu of the mods' options, hidden: the list of mods and the options of the one
  # chosen.
  def create_mod_config_window
    @mod_config_window = Window_ModConfig.new
    @mod_config_window.viewport = @viewport
    @mod_config_window.help_window = @help_window
    @mod_config_window.z = 200
    @mod_config_window.set_handler(:cancel, method(:leave_mod_options))

    @mod_config_list_window = Window_ModConfigMods.new(@mod_config_window)
    @mod_config_list_window.viewport = @viewport
    @mod_config_list_window.help_window = @help_window
    @mod_config_list_window.z = 200
    @mod_config_list_window.set_handler(:ok, method(:enter_mod_options))
    @mod_config_list_window.set_handler(:cancel, method(:end_mod_config))
  end

  # Opens the menu of the mods' options below the help of the options screen, over its list.
  def start_mod_config
    open_mod_config(0, ModConfigRemake::TOP, Graphics.width, Graphics.height - ModConfigRemake::TOP)
  end

  # Opens the menu of the mods' options in an area: the list of mods at its left, active, and the
  # options of the mod it points at at its right.
  #
  # The windows are made here when start did not make them, as when another script's MOD_CONTENTS
  # was taken for the Mod Config Menu's.
  #
  # @param x [Integer] The area's left edge.
  # @param y [Integer] The area's top edge.
  # @param width [Integer] The area's width.
  # @param height [Integer] The area's height.
  def open_mod_config(x, y, width, height)
    create_mod_config_window unless @mod_config_list_window
    @config_window.deactivate if @config_window
    @item_window.deactivate if @item_window

    @mod_config_list_window.open_at(x, y, height)
    list_width = @mod_config_list_window.width
    @mod_config_window.move(x + list_width, y, width - list_width, height)
    @mod_config_window.unselect
    @mod_config_window.deactivate.show
    @mod_config_list_window.show_selected
    @mod_config_list_window.show.activate
  end

  # Moves from the list of mods into the options of the chosen one.
  def enter_mod_options
    if @mod_config_window.item_max == 0
      Sound.play_buzzer
      return @mod_config_list_window.activate
    end

    @mod_config_list_window.deactivate
    @mod_config_window.activate.select(0)
  end

  # Moves from a mod's options back to the list of mods.
  def leave_mod_options
    @mod_config_window.deactivate.unselect
    @mod_config_list_window.activate
  end

  # Closes the menu of the mods' options and goes back to where it opened from.
  def end_mod_config
    @mod_config_list_window.deactivate.hide
    @mod_config_window.deactivate.hide
    @config_window.activate if @config_window
  end
end

unless SceneManager.respond_to?(:mod_config_remake_run)
  begin
    class << SceneManager
      alias mod_config_remake_run run

      # Links the menu of the mods' options to the options screen, then runs the game.
      def run
        ModConfigRemake.install rescue nil
        mod_config_remake_run
      end
    end
  rescue
  end
end
