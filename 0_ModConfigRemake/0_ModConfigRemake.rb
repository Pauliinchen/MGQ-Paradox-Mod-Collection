#----------------------------------------------------------------
#  0_ModConfigRemake.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Greyed out the options a multiplayer world sets, saying so in their help
#      Paulinchen  2026-10-02: Added key bindings, options that take the next key pressed
#                            - Added refresh_mod_config, which EXP Overlord calls after its options change
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

  # The arrow of an indented option's name, which a message about the option leaves out.
  INDENTED_MARK = /\A\s*->\s*/

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

  # Tells whether an option binds a key: its value is a key's Windows code, which the next key
  # pressed replaces.
  #
  # @param entry [Hash] The option's entry.
  # @return [Boolean] Whether it binds a key.
  def self.key_binding?(entry)
    entry[:keybind] ? true : false
  end

  # Reads a key binding's current value, from its :value proc when it has one.
  #
  # Only key bindings read :value, so an option of another mod with a key of that name stays as it is.
  #
  # @param entry [Hash] The key binding's entry.
  # @return [Object] Its value.
  def self.entry_value(entry)
    entry[:value].respond_to?(:call) ? entry[:value].call : value_of(entry[:key])
  rescue
    nil
  end

  # Finds the option of any mod that a key is bound to already.
  #
  # @param code [Integer] The key's Windows code.
  # @param except [Hash] The option being bound, which may keep its own key.
  # @return [Hash, nil] The option's entry, nil when no other option has the key.
  def self.key_owner(code, except)
    NWConst::Config::MOD_CONTENTS.find { |entry| !entry.equal?(except) && key_binding?(entry) && entry_value(entry).to_i == code }
  end

  # Names an option for a message: its name without "[Mod Name]", followed by the mod in brackets.
  #
  # @param entry [Hash] The option's entry.
  # @return [String] The name, such as "Chat (Monster Girl Quest! Online)".
  def self.option_name(entry)
    name = text(entry[:name])
    mod = name[MOD_NAME, 1]
    short = name.sub(MOD_NAME, "").sub(INDENTED_MARK, "").strip
    mod ? "#{short} (#{mod})" : short
  end

  # Writes an option's value as the menu shows it.
  #
  # @param entry [Hash] The option's entry.
  # @return [String] The key's name for a key binding, else the name DATA_TEXT gives the value, else
  #   the value itself.
  def self.value_text(entry)
    return Keys.name(entry_value(entry).to_i) if key_binding?(entry)

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
    if key_binding?(entry)
      help += "\r\nConfirm, then press the new key."
    elsif entry[:sub]
      texts = NWConst::Config::DATA_TEXT[entry[:key]]
      named = texts[value_of(entry[:key])] if texts
      extra = named ? text(named[:help]) : ""
      help += "\r\n#{extra}" unless extra.empty? || help.include?(extra)
    end
    help += "\r\nSet by the world you play in." if world_key?(entry)
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

  # Tells whether an option can be changed: not while a multiplayer world sets it, else as its
  # :enable proc says.
  #
  # @param entry [Hash] The option's entry.
  # @return [Boolean] Whether it is not greyed out.
  def self.enabled?(entry)
    return false if world_key?(entry)

    entry[:enable] ? (entry[:enable].call ? true : false) : true
  rescue
    true
  end

  # Takes the options a multiplayer world sets while the player is in it, such as Monster Girl
  # Quest! Online's, which the menu then shows greyed out; none outside a world.
  #
  # @param keys [Array<Symbol>] The options' keys.
  def self.world_keys=(keys)
    @world_keys = Array(keys).map { |key| key.to_sym }
  end

  # Lists the options a multiplayer world sets.
  #
  # @return [Array<Symbol>] The options' keys, none outside a world.
  def self.world_keys
    @world_keys || []
  end

  # Tells whether a multiplayer world sets an option. Key bindings and options marked
  # :personal => true stay the player's own.
  #
  # @param entry [Hash] The option's entry.
  # @return [Boolean] Whether it does.
  def self.world_key?(entry)
    !entry[:personal] && !key_binding?(entry) && world_keys.include?(entry[:key])
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

  # The keyboard as key binding options read it, from Windows: the keys' names, and the next key
  # pressed.
  module Keys
    # Set in a key state while the key is down.
    DOWN = 0x8000

    # Windows' code of Escape, which leaves a binding unchanged.
    ESCAPE = 0x1B

    # The keys a binding takes: the keyboard's, without the mouse buttons, the Windows keys, which
    # leave the game, and Shift, Ctrl and Alt without a side, which Windows reports with the sided ones.
    BINDABLE = [0x08, 0x09, 0x0D, 0x13, 0x14, 0x1B, 0x5D, 0x90, 0x91, 0xE2] +
               (0x20..0x2E).to_a + (0x30..0x39).to_a + (0x41..0x5A).to_a + (0x60..0x6F).to_a +
               (0x70..0x87).to_a + (0xA0..0xA5).to_a + (0xBA..0xC0).to_a + (0xDB..0xDF).to_a

    # The keys the game uses itself: its buttons on the keyboard as RGSS sets them (Enter, Space, Z,
    # Esc, X, Num 0, Shift, A, S, D, Q, W, Page Up and Page Down, the arrows and Num 2, 4, 6 and 8),
    # Ctrl, which skips messages, F1, F2 and F12 of RGSS, and F5 to F9, which the game takes.
    GAME_KEYS = [0x0D, 0x20, 0x5A, 0x1B, 0x58, 0x60, 0xA0, 0xA1, 0x41, 0x53, 0x44, 0x51, 0x57, 0x21,
                 0x22, 0x25, 0x26, 0x27, 0x28, 0x62, 0x64, 0x66, 0x68, 0xA2, 0xA3, 0x70, 0x71, 0x7B,
                 0x74, 0x75, 0x76, 0x77, 0x78]

    # Names of the keys whose name is no character of the keyboard's layout.
    NAMES = {
      0x08 => "Backspace", 0x09 => "Tab", 0x0D => "Enter", 0x13 => "Pause", 0x14 => "Caps Lock",
      0x1B => "Esc", 0x20 => "Space", 0x21 => "Page Up", 0x22 => "Page Down", 0x23 => "End",
      0x24 => "Home", 0x25 => "Left", 0x26 => "Up", 0x27 => "Right", 0x28 => "Down",
      0x29 => "Select", 0x2A => "Print", 0x2B => "Execute", 0x2C => "Print Screen",
      0x2D => "Insert", 0x2E => "Delete", 0x5D => "Menu", 0x6A => "Num *", 0x6B => "Num +",
      0x6C => "Num Separator", 0x6D => "Num -", 0x6E => "Num .", 0x6F => "Num /", 0x90 => "Num Lock",
      0x91 => "Scroll Lock", 0xA0 => "Left Shift", 0xA1 => "Right Shift", 0xA2 => "Left Ctrl",
      0xA3 => "Right Ctrl", 0xA4 => "Left Alt", 0xA5 => "Right Alt",
    }
    (0x30..0x39).each { |code| NAMES[code] = (code - 0x30).to_s }
    (0x41..0x5A).each { |code| NAMES[code] = code.chr }
    (0x60..0x69).each { |code| NAMES[code] = "Num #{code - 0x60}" }
    (0x70..0x87).each { |code| NAMES[code] = "F#{code - 0x6F}" }

    # Names a key: from NAMES, else the character the keyboard's layout prints on it.
    #
    # @param code [Integer] The key's Windows code, 0 for none.
    # @return [String] The name, such as "F11" or "Ü".
    def self.name(code)
      return "None" if code.to_i <= 0

      NAMES[code] || layout_name(code) || format("Key %02X", code)
    end

    # Asks Windows for the character the keyboard's layout prints on a key.
    #
    # @param code [Integer] The key's Windows code.
    # @return [String, nil] The character, nil when Windows has none.
    def self.layout_name(code)
      scan = api('MapVirtualKeyW', 'ii', 'i').call(code, 0)
      return nil if scan == 0

      buffer = "\0" * 64
      length = api('GetKeyNameTextW', 'ipi', 'i').call(scan << 16, buffer, 32)
      length > 0 ? buffer.unpack('v*')[0, length].pack('U*') : nil
    rescue
      nil
    end

    # Tells whether the game uses a key itself.
    #
    # @param code [Integer] The key's Windows code.
    # @return [Boolean] Whether it does.
    def self.game_key?(code)
      GAME_KEYS.include?(code)
    end

    # Starts watching for the next key, leaving out the keys held now, such as the one that confirmed.
    def self.start_watch
      @held = BINDABLE.select { |code| down?(code) }
    end

    # Finds a key that went down since the last look, while the game's window is in front.
    #
    # @return [Integer, nil] The key's Windows code, nil when none went down.
    def self.watch
      down = BINDABLE.select { |code| down?(code) }
      pressed = (down - @held.to_a).first
      @held = down
      pressed && in_front? ? pressed : nil
    end

    # Tells whether a key is down.
    #
    # @param code [Integer] The key's Windows code.
    # @return [Boolean] Whether it is.
    def self.down?(code)
      (api('GetAsyncKeyState', 'i', 'i').call(code) & DOWN) != 0
    end

    # Tells whether the game's window is in front, since Windows reports the keys pressed in any window.
    #
    # @return [Boolean] Whether the window in front belongs to this game.
    def self.in_front?
      owner = [0].pack('L')
      api('GetWindowThreadProcessId', 'lp', 'l').call(api('GetForegroundWindow', 'v', 'l').call, owner)
      @process_id ||= Win32API.new('kernel32', 'GetCurrentProcessId', 'v', 'l').call
      owner.unpack('L')[0] == @process_id
    end

    # Loads a function of user32.dll.
    #
    # @param name [String] The function.
    # @param arguments [String] Its arguments, in Win32API notation.
    # @param result [String] Its result, in Win32API notation.
    # @return [Win32API] The function, loaded once.
    def self.api(name, arguments, result)
      @functions ||= {}
      @functions[name] ||= Win32API.new('user32', name, arguments, result)
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
# the handler named after its key, so the buttons of mods work; confirming a key binding waits for
# the next key pressed.
#
# Its rows are the chosen mod's options, so an index counts those, not every entry of MOD_CONTENTS.
class Window_ModConfig < Window_Selectable
  # Mods made for the Mod Config Menu reopen this window and read DATA or MOD_CONTENTS unqualified.
  include NWConst::Config

  # What a key binding's row shows while it waits for the key.
  WAITING_TEXT = "Press a key . . ."

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
    if @mod_config_remake_binding && @mod_config_remake_binding.equal?(row)
      change_color(system_color)
      draw_text(rect, WAITING_TEXT, 2)
    elsif row[:sub] || ModConfigRemake.key_binding?(row)
      draw_text(rect, ModConfigRemake.value_text(row), 2)
    end
    change_color(normal_color)
  end

  # Takes the next key pressed while a key binding waits for it, and the input as usual otherwise.
  def update
    super
    update_binding if @mod_config_remake_binding
  end

  # Moves the cursor, unless a key binding waits for its key.
  def process_cursor_move
    super unless @mod_config_remake_binding
  end

  # Confirms or cancels, unless a key binding waits for its key.
  def process_handling
    super unless @mod_config_remake_binding
  end

  # Lets every row be confirmed, which the menu answers itself.
  #
  # @return [Boolean] Always true.
  def ok_enabled?
    true
  end

  # Moves an option to its next value, waits for a key binding's new key, or presses a button: calls
  # the handler named after its key.
  def process_ok
    row = entry
    return unless row
    return change_value(1) if row[:sub]
    return Sound.play_buzzer unless ModConfigRemake.enabled?(row)
    return start_binding(row) if ModConfigRemake.key_binding?(row)

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

  # Has a key binding wait for the next key pressed.
  #
  # @param row [Hash] The key binding's entry.
  def start_binding(row)
    Sound.play_ok
    @mod_config_remake_binding = row
    @mod_config_remake_key = nil
    ModConfigRemake::Keys.start_watch
    refresh
    ask_for_key
  end

  # Takes the key pressed for the waiting key binding: Escape keeps the old key, a key the game uses
  # or another option has is refused, any other key becomes the option's.
  #
  # The binding ends only once the key is released, so the game's input never sees its press and
  # Escape or a key the game also reads does not reach the menu.
  def update_binding
    return finish_binding unless @mod_config_remake_key.nil? || ModConfigRemake::Keys.down?(@mod_config_remake_key)

    code = ModConfigRemake::Keys.watch
    return unless code && @mod_config_remake_key.nil?

    if code == ModConfigRemake::Keys::ESCAPE
      Sound.play_cancel
      @mod_config_remake_key = code
    elsif ModConfigRemake::Keys.game_key?(code)
      Sound.play_buzzer
      ask_for_key("#{ModConfigRemake::Keys.name(code)} is one of the game's own keys.")
    elsif (owner = ModConfigRemake.key_owner(code, @mod_config_remake_binding))
      Sound.play_buzzer
      ask_for_key("#{ModConfigRemake::Keys.name(code)} is already the key of #{ModConfigRemake.option_name(owner)}.")
    else
      bind_key(code)
      @mod_config_remake_key = code
    end
  end

  # Makes a key the waiting option's, and tells its mod.
  #
  # @param code [Integer] The key's Windows code.
  def bind_key(code)
    row = @mod_config_remake_binding
    $game_system.conf[row[:key]] = code unless row[:value].respond_to?(:call)
    ModConfigRemake.safely { row[:on_change].call(code) } if row[:on_change].respond_to?(:call)
    Sound.play_ok
  end

  # Ends the wait for a key, once the key pressed is released.
  def finish_binding
    @mod_config_remake_binding = nil
    @mod_config_remake_key = nil
    refresh
  end

  # Tells in the help which key the waiting option wants.
  #
  # @param refusal [String, nil] Why the last key pressed was refused, nil for none.
  def ask_for_key(refusal = nil)
    return unless @help_window

    current = ModConfigRemake.value_text(@mod_config_remake_binding)
    if refusal
      @help_window.set_text("#{refusal}\r\nPress another key, or Esc to keep #{current}.")
    else
      @help_window.set_text("Press the new key for #{ModConfigRemake.option_name(@mod_config_remake_binding)}.\r\nEsc keeps #{current}.")
    end
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

  # Draws the options of the mod shown anew, with their help. Mods made for the Mod Config Menu, such
  # as EXP Overlord, call it after one of their options changed others.
  def refresh_mod_config
    return unless @mod_config_window

    @mod_config_window.refresh
    @mod_config_window.call_update_help
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
