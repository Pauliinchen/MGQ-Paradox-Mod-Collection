#----------------------------------------------------------------
#  Equipment_Window.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Sized the item list by opener_size, a documented call of the framework
#                            - Drew a gem's tooltip as before: each effect line wrapped on its own, the name narrowed beside its elements
#                            - Built every screen from the framework's general parts and its readers of the game's data
#                            - Carried the window's own gear changes: equip, Optimize, Clear, favorites and gems
#                            - Showed a weapon's elements in one chip after the item's name
#                            - Prefixed every id of the window with ew_
#                            - Showed the hotkey help under the pages, naming the keys of the part in focus
#                            - Named a gamepad's shoulders as the tab step while the details show two or more tabs
#      Paulinchen  2026-11-08: Removed the G hotkey, so the window opens only in place of the game's equip screen
#      Paulinchen  2026-11-05: Built the stats, the item's head, its gems, its summary and its details from the gear components
#                              of UI::Equip
#                            - Rewrote the window as a component of the framework's UI layer
#      Paulinchen  2026-11-04: Named the button row and the stats for other mods' changes, and let them read the
#                              character and the item shown
#      Paulinchen  2026-10-30: Stopped loading the framework by hand
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# An equipment window that replaces the game's equip screen. It is a sample of the Mod Framework's
# UI layer: every screen is built from the framework's general parts and its readers of the game's
# data, and the window changes the gear itself through the game's own methods.
# The framework's zip brings it into the game's Patch folder as a mod of its own, which the website
# lists as equipment-window and updates.
module Equipment_Window
  # Short name for the framework's UI module.
  UI = Mod_Framework::UI

  # Texts of the links that slide the details in and out.
  DETAILS = "Details #{[0x2192].pack('U')}"
  BACK = "#{[0x2190].pack('U')} Back"

  # Last line of a summary that is cut off, while the details are out of view.
  MORE_DETAILS = "+%d more #{[0xB7].pack('U')} #{DETAILS}"

  # Text of an empty slot.
  NOTHING_TEXT = "Nothing equipped"

  # Tooltips of the Optimize and Clear buttons.
  OPTIMIZE_TIP = "Equip the strongest items in every slot that can change"
  CLEAR_TIP = "Take off everything in the slots that can change"

  # Last tooltip line of a gem: how to change it, or that it cannot change.
  CLICK_TEXT = "Click to change"
  CONFIRM_TEXT = "Confirm or click to change"
  FIXED_TEXT = "Fixed: gems cannot change"

  # What the key help says each key does.
  KEY_TEXTS = { change: "Change", character: "Character", next_tab: "Next tab", tabs: "Tabs", close: "Close", back: "Back", search: "Search",
                list: "Back to the list", filter: "Filter", colors: "Colors" }

  # The other texts the window shows, by what they say.
  TEXTS = { equipped: "Equipped", remove: "Remove", remove_note: "Leaves the slot empty", selected: "Selected", nothing_selected: "Nothing selected",
            gem_words: ["gem", "gems"], gem_count: "#{[0xB7].pack('U')} %s", empty_socket: "Empty socket", empty_line: "Empty", socket: "Socket %d of %d",
            no_effects: "None", now: "Now", after: "After", no_change: "No change", pick: "Pick a gem", no_gems: "No gems in the bag",
            search: "Search by name", favorites: "Favorites", clear: "Clear", no_items: "No items for this slot", no_item: "No item matches",
            no_gem: "No gem matches", gem_title: "%s: Socket %d", color_tip: "%s gems", fixed: "the gems of %s of %s cannot change" }

  # What joins the parts of the line under an item's name.
  JOIN = " #{[0xB7].pack('U')} "

  # The least size of the dialogs, which take the window's place and size: the screen at its least height.
  DIALOG_SIZE = [640, 400]

  # Writes a line into the framework's log.
  #
  # @param line [String] The line.
  def self.log(line)
    Mod_Framework.log("Equipment Window: #{line}")
  end

  # Puts an item into a slot, or takes its item out, through the game's change_equip, with the
  # equip sound, or the buzzer when the slot is fixed or the game refused it.
  #
  # @param actor [Game_Actor] The character.
  # @param slot [Integer] The slot.
  # @param item [RPG::EquipItem, Symbol, nil] The item; nil or UI::Game::REMOVE takes it out.
  # @param quiet [Boolean] Whether it plays no sound and logs nothing, as inside Optimize.
  # @return [Boolean] Whether the game took the change.
  def self.equip(actor, slot, item, quiet = false)
    item = nil if item == UI::Game::REMOVE
    taken = false
    if actor.equip_change_ok?(slot)
      before = actor.equips[slot]
      actor.change_equip(slot, item)
      after = actor.equips[slot]
      taken = item.nil? ? after.nil? : !after.nil? && (after.equal?(item) || !after.equal?(before))
    end
    return taken if quiet

    change = "#{UI::Game.actor_ref(actor)}, #{UI::Game.slot_name(actor, slot)}: #{item ? UI::Game.item_ref(item) : 'nothing'}"
    log(taken ? "Equip for #{change}" : "Equip refused for #{change}: #{actor.equip_change_ok?(slot) ? 'the game did not take it' : 'the slot is fixed'}")
    Sound.send(taken ? :play_equip : :play_buzzer)
    taken
  end

  # Runs the game's Optimize, then puts into each slot it changed the item that raises the
  # character's stats most, since the game judges an item by its own parameters alone.
  #
  # @param actor [Game_Actor] The character.
  def self.optimize(actor)
    Sound.play_equip
    logging_slots(actor, "Optimize") do
      before = actor.equips.dup
      actor.optimize_equipments
      actor.equips.each_index { |slot| equip_strongest(actor, slot) unless actor.equips[slot].equal?(before[slot]) }
    end
  end

  # Takes off everything in the slots that can change, as the game's Clear does.
  #
  # @param actor [Game_Actor] The character.
  def self.clear(actor)
    Sound.play_equip
    logging_slots(actor, "Clear") { actor.clear_equipments }
  end

  # Marks an item a favorite or takes the mark away, as the game's item lists do.
  #
  # @param item [RPG::BaseItem] The item.
  def self.toggle_favorite(item)
    return unless $game_party.respond_to?(:set_favorite_item)

    $game_party.set_favorite_item(item)
    log("Favorite: #{UI::Game.item_ref(item)} #{UI::Game.favorite?(item) ? 'marked' : 'unmarked'}")
  end

  # Puts a gem into a socket of the item in a character's slot, or empties the socket, as the
  # game's gem screen does, with the equip sound, or the buzzer when the game refused it.
  #
  # @param actor [Game_Actor] The character.
  # @param slot [Integer] The slot.
  # @param socket [Integer] The socket, from 0.
  # @param gem [RPG::Item, nil] The gem, nil to empty the socket.
  # @return [Boolean] Whether the game took the change.
  def self.change_gem(actor, slot, socket, gem)
    item = UI::Equip.item(actor, slot)
    what = gem ? "#{UI::Game.item_name(gem)} into socket #{socket + 1}" : "the gem out of socket #{socket + 1}"
    why = UI::Equip.gem_preview(item, socket, gem, :actor => actor, :slot => slot)[:refusal]
    if why.nil? && gem
      held = UI::Equip.sockets($game_party.create_socket_item(item) { |socketed| socketed.change_stone(socket, gem) })[socket]
      why = "the game did not take it" unless held && (held.equal?(gem) || (held.class == gem.class && held.id == gem.id))
    elsif why.nil?
      item.change_stone(socket, nil)
      why = "the game did not take it" unless UI::Equip.sockets($game_party.restore_socket_item(item))[socket].nil?
    end
    log(why ? "Gems refused: #{what} of #{UI::Game.item_ref(item)}: #{why}" : "Gems: #{what} of #{UI::Game.item_ref(item)}")
    Sound.send(why ? :play_buzzer : :play_equip)
    why.nil?
  end

  # Runs a command on a character's gear and logs the slots before and after.
  #
  # @param actor [Game_Actor] The character.
  # @param command [String] The command's name.
  def self.logging_slots(actor, command)
    slots = lambda { actor.equips.each_with_index.map { |item, slot| "#{UI::Game.slot_name(actor, slot)} #{item ? UI::Game.item_name(item) : '-'}" }.join(", ") }
    before = slots.call
    yield
    log("#{command} for #{actor.name}: before #{before}; after #{slots.call}")
  end

  # Puts into a slot the item that raises the stats most, each as a share of its value with the
  # slot empty, so a stat counts by its change and not its size; the worn item wins a tie.
  #
  # @param actor [Game_Actor] The character.
  # @param slot [Integer] The slot.
  def self.equip_strongest(actor, slot)
    worn = actor.equips[slot]
    items = UI::Equip.item_rows(actor, slot).map { |row| row[:item] }.compact.uniq
    return if items.empty?

    empty, *stats = UI::Equip.stats_with(actor, slot, [nil, worn] + items)
    strength = lambda { |with| with.zip(empty).inject(0.0) { |sum, (value, without)| sum + value.to_f / [without, 1].max } }
    best = ([worn] + items).each_with_index.max_by { |_item, place| strength.call(stats[place]) }[0]
    equip(actor, slot, best, true) unless best.equal?(worn)
  end
  private_class_method :logging_slots, :equip_strongest

  # The parts the window and its dialogs share: an item's head, its gems and what it adds.
  module Parts
    # Room between two halves and between a gem cell's slots and its note, 4 px a unit.
    SIDE_SPACING = 3
    SOCKET_SPACING = 2

    # The game's escape codes in an effect line, left out where the lines sort.
    ESCAPE_CODE = /\\[A-Za-z]+(\[[^\]]*\])?/

    # Describes two halves side by side, each as wide as the other.
    #
    # @param options [Hash] More params of their row.
    def halves(options = {}, &block)
      stack({ row: true, spacing: SIDE_SPACING }.merge(options), &block)
    end

    # Tells an item's name and the game's color for it, nil for the plain text color.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Array] The name and the color.
    def item_look(item)
      color = UI::Game.item_color(item)
      [UI::Game.item_name(item), color == 0 ? nil : color]
    end

    # Describes an icon with a name after it in the small font.
    #
    # @param mark [Integer, nil] The icon, nil for none.
    # @param name [String] The name.
    # @param color [Symbol, Integer, nil] Its color.
    # @param options [Hash] More params of their row, such as key:.
    def named(mark, name, color, options = {})
      stack({ row: true, spacing: 0.5 }.merge(options)) do
        icon mark if mark
        text name, typo: :body2, color: color, align: :center
      end
    end

    # Tells the chip of the elements an item strikes with, their names in its tooltip.
    #
    # @param item [RPG::EquipItem, nil] The item.
    # @return [Proc, nil] The markup, nil without elements.
    def elements_chip(item)
      elements = UI::Equip.elements(item)
      return nil if elements.empty?

      -> { chip_set { chip icons: elements.map { |element| element[:icon] }, tooltip: elements.map { |element| element[:name] }.join(", ") } }
    end

    # Describes an item's header: its icon, its name in its color with its elements' chip after it,
    # and a line under it; without an item the empty text, dim, stands for the name.
    #
    # @param item [RPG::EquipItem, nil] The item.
    # @param subtitle [String] The line under the name.
    # @param options [Hash] :empty (the text without an item) and more params of the header.
    def item_head(item, subtitle, options = {})
      title, color = item ? item_look(item) : [options[:empty].to_s, :dim]
      params = { title_color: color, icon: item && item.icon_index, subtitle: subtitle, title_after: elements_chip(item) }
      header title, params.merge(options.reject { |name, _value| name == :empty })
    end

    # Tells a slot per socket, a gem's with its tooltip, kept while the gems and notes stay the same.
    #
    # @param gems [Array<RPG::Item, nil>] A gem or nil per socket.
    # @param notes [Array, nil] Per socket the note ending its tooltip, a text and its color.
    # @return [Array<Hash, nil>] The slots, nil for an empty socket.
    def socket_slots(gems, notes = nil)
      memo(gems, notes) do
        gems.each_with_index.map { |gem, place| gem && { icon: gem.icon_index, tooltip: -> { gem_tip(gem, place, gems.size, notes && notes[place]) } } }
      end
    end

    # Describes a gem's tooltip: its name and elements, its socket, what it adds and a note.
    #
    # @param gem [RPG::Item] The gem.
    # @param place [Integer] Its socket, from 0.
    # @param count [Integer] The item's sockets.
    # @param note [Array, nil] The note's text and color.
    def gem_tip(gem, place, count, note)
      info = UI::Equip.gem_info(gem)
      name, color = item_look(gem)
      stack spacing: 1 do
        stack row: true, spacing: 0.5 do
          icon gem.icon_index
          text name, typo: :subtitle1, color: color, align: :center, fit: :narrow
          info[:elements].each { |element| icon element[:icon], tooltip: element[:name], key: element[:id], margin: [0, 0, 0, 0.5] }
        end
        text format(TEXTS[:socket], place + 1, count), typo: :body2, color: :dim, padding: [0, 0, 0, UI::ICON_STEP / 4.0]
        text UI::Equip::NOTHING_TEXT, typo: :body2, color: :dim if info[:stats].flatten.empty? && info[:effects].empty?
        stats_block(info[:stats], dense: false) unless info[:stats].flatten.empty?
        tip_lines(info[:effects]).each { |line| text line, typo: :body2, escapes: true, wrap: true }
        text note[0], typo: :body2, color: note[1], wrap: true if note
      end
    end

    # Tells the effect lines of a gem one after another, each group's sorted by its text without
    # escape codes, ignoring case.
    #
    # @param effects [Array<Hash>] Its groups, see UI::Equip.effects.
    # @return [Array<String>] The lines.
    def tip_lines(effects)
      effects.map do |group|
        group[:lines].each_with_index.sort_by { |line, place| [line.gsub(ESCAPE_CODE, "").downcase, place] }.map { |line, _place| line }
      end.flatten
    end

    # Describes the stats an item adds: the parameters over the rates, a line between them.
    #
    # @param rows [Array<Array<Hash>>] The rows of the parameters and of the rates.
    # @param options [Hash] :before (the rows to judge them against) and :dense.
    def stats_block(rows, options = {})
      basic, rates = rows
      before = options[:before] || []
      dense = options.fetch(:dense, true)
      stack spacing: 0 do
        stat_grid basic, before: before[0], columns: 2, size: :small, dense: dense unless basic.empty?
        divider unless basic.empty? || rates.empty?
        stat_grid rates, before: before[1], columns: 2, size: :small, dense: dense unless rates.empty?
      end
    end

    # Describes what an item adds: its stats, then its effect lines, or a line that it adds nothing.
    #
    # @param rows [Array<Array<Hash>>] The rows of its parameters and of its rates.
    # @param effects [Array] Its effect lines, see UI::Equip.effects.
    # @param options [Hash] :before (see stats_block) and more params of its lines.
    def item_body(rows, effects, options = {})
      stats_block(rows, before: options[:before]) unless rows.flatten.empty?
      nothing = rows.flatten.empty? && effects.empty? ? UI::Equip::NOTHING_TEXT : nil
      lines effects, { columns: :room, sort: true, titles: false, escapes: true, empty: nothing }.merge(options.reject { |name, _value| name == :before })
    end

    # Describes a dialog in the window's place: a search beside the block's filter, the list, the
    # comparison under it and the hotkey help.
    #
    # @param title [String] The title.
    # @param name [String] What the ids of the dialog and its list are named after, such as "item".
    # @param options [Hash] :gate (its if:), :list and :compare (lambdas of markup), :keys (its key_help's params).
    def picker(title, name, options)
      frame = { id: :"ew_#{name}_dialog", cover: true, min_size: DIALOG_SIZE }
      frame[:if] = options[:gate] if options[:gate]
      dialog title, frame do
        stack row: true do
          text_field bind: :search, placeholder: TEXTS[:search], max_length: 30, steer: :"ew_#{name}_list", grow: 1
          yield
        end
        options[:list].call
        divider
        options[:compare].call
        key_help options[:keys]
      end
    end

    # Tells whether an item's name holds what the search holds, ignoring case.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Boolean] Whether it does.
    def searched?(item)
      UI::Game.item_name(item).downcase.include?(search.to_s.downcase)
    end
  end

  # The worn item set against another, side by side as the game's equip screen sets them: headers,
  # gems with what the equip does with each, stats judged against the worn item's and effect lines.
  # Short of room it folds step by step: the effect lines take one row, the gems become a count
  # after each header's line, the headers take one row.
  class Compare < UI::Component
    include Parts

    # The steps of its compact forms.
    STEP_LINES = 1
    STEP_GEMS = 2
    STEP_HEADER = 3

    # How opaque the star of an item that is no favorite draws.
    STAR_OFF_OPACITY = 96

    # The gem count's share of the room its header's line leaves, so it shows only where it fits.
    COUNT_GROW = 99

    # The character.
    param :actor

    # The slot, from 0.
    param :slot

    # The row of UI::Equip.item_rows set against the worn item, or its item; nil for none yet.
    param :picked, nil

    # Describes the comparison.
    def render
      worn = UI::Equip.item(actor, slot)
      value = picked.is_a?(Hash) ? picked[:data] : picked
      removing = value == UI::Game::REMOVE
      item = removing ? nil : value
      after = UI::Equip.gems_after(worn, item)
      compared = UI::Equip.compare(worn, item, :gems => after[:gems])
      worn_gems = UI::Equip.socketed?(worn) ? { gems: UI::Equip.sockets(worn), notes: after[:worn_notes], note: after[:worn_note] } : nil
      picked_gems = UI::Equip.socketed?(item) ? { gems: after[:gems], notes: after[:item_notes], note: after[:item_note] } : nil
      stack spacing: 1 do
        halves do
          worn ? side_head(worn, [TEXTS[:equipped], UI::Game.type_name(worn)], worn_gems) : side_head(nil, [TEXTS[:equipped]], nil, NOTHING_TEXT)
          picked_head(item, removing, picked_gems)
        end
        if worn_gems || picked_gems
          halves(compact: { STEP_GEMS => { visible: false } }) do
            gem_cell(worn_gems)
            gem_cell(picked_gems)
          end
        end
        halves do
          side_body(worn, nil, compared[:worn], compared[:shared], nil, !worn.nil?)
          side_body(item, after[:gems], compared[:item], compared[:shared], worn && compared[:worn], item || removing)
        end
      end
    end

    private

    # Describes the picked side's header: the item with its star, the remove row's, or nothing picked.
    #
    # @param item [RPG::EquipItem, nil] The item picked.
    # @param removing [Boolean] Whether the worn item comes out.
    # @param gems [Hash, nil] The side's gems: :gems, :notes and :note.
    def picked_head(item, removing, gems)
      return side_head(item, [TEXTS[:selected], UI::Game.type_name(item)], gems, nil, star(item)) if item
      return side_head(nil, [TEXTS[:remove_note]], nil, TEXTS[:remove]) if removing

      side_head(nil, [TEXTS[:selected]], nil, TEXTS[:nothing_selected])
    end

    # Describes a side's header in its half.
    #
    # @param item [RPG::EquipItem, nil] The item.
    # @param parts [Array<String>] The parts of the line under the name.
    # @param gems [Hash, nil] The side's gems, see picked_head.
    # @param empty [String, nil] What stands for the name without an item.
    # @param trailing [Proc, nil] The markup at the end of the name's row, such as the star.
    def side_head(item, parts, gems, empty = nil, trailing = nil)
      line = parts.map { |part| part.to_s }.reject { |part| part.empty? }.join(JOIN)
      stack width: 0, grow: 1 do
        item_head(item, line, empty: empty, note: gem_count(gems), trailing: trailing, compact: { STEP_HEADER => { dense: true } })
      end
    end

    # Tells the markup of a side's gem count after its header's line, such as "· 3 gems", whose
    # tooltip lists each gem with what the equip does with it, then the side's note.
    #
    # @param gems [Hash, nil] The side's gems, see picked_head.
    # @return [Proc, nil] The markup, nil without gems or a note to tell.
    def gem_count(gems)
      return nil unless gems

      listed = gems[:gems].each_with_index.select { |gem, _place| gem }.map { |gem, place| [gem, gems[:notes][place]] }
      return nil if listed.empty? && gems[:note].nil?

      count = format(TEXTS[:gem_count], UI.counted(listed.size, *TEXTS[:gem_words]))
      lambda do
        tooltip content: -> { gems_tip(listed, gems[:note]) }, visible: false, width: 0, grow: COUNT_GROW, compact: { STEP_GEMS => { visible: true } } do
          text [count, ""], typo: :body2, color: :dim
        end
      end
    end

    # Describes the tooltip of a gem count: each gem with its note under it, then the side's note.
    #
    # @param listed [Array<Array>] Each gem and its note, a text and its color, or nil.
    # @param note [Array, nil] The side's note, a text and its color.
    def gems_tip(listed, note)
      stack spacing: 1 do
        listed.each_with_index do |(gem, gem_note), place|
          named(gem.icon_index, *item_look(gem), key: place)
          text gem_note[0], typo: :body2, color: gem_note[1], wrap: true, key: place if gem_note
        end
        text note[0], typo: :body2, color: note[1], wrap: true if note
      end
    end

    # Tells the markup of the star after the picked item's header: lit while it is a favorite.
    #
    # @param item [RPG::EquipItem] The item picked.
    # @return [Proc, nil] The markup, nil in a game without favorites.
    def star(item)
      return nil unless UI::Game.favorite_icon

      on = UI::Game.favorite?(item)
      -> { icon UI::Game.favorite_icon, opacity: on ? nil : STAR_OFF_OPACITY, tooltip: UI::Game.favorite_text(on), on_click: -> { Equipment_Window.toggle_favorite(item) } }
    end

    # Describes a side's gem slots with their note beside them, or under them without room.
    #
    # @param gems [Hash, nil] The side's gems, see picked_head; nil for an empty half.
    def gem_cell(gems)
      stack row: true, spacing: SOCKET_SPACING, wrap: true, width: 0, grow: 1 do
        if gems
          slot_row socket_slots(gems[:gems], gems[:notes]), empty_icon: UI::Game.empty_socket_icon, empty_tooltip: TEXTS[:empty_socket]
          text gems[:note][0], typo: :body2, color: gems[:note][1], align: :center if gems[:note]
        end
      end
    end

    # Describes a side's stats and effect lines, those both items share left out.
    #
    # @param item [RPG::EquipItem, nil] The side's item.
    # @param gems [Array<RPG::Item, nil>, nil] Its gems after the equip, nil for those it holds.
    # @param rows [Array<Array<Hash>>] The rows of its parameters and of its rates.
    # @param shared [Array<String>] The effect lines both items have.
    # @param against [Array<Array<Hash>>, nil] The worn side's rows to judge them against.
    # @param shown [Boolean] Whether the side shows anything.
    def side_body(item, gems, rows, shared, against, shown)
      stack spacing: 1, width: 0, grow: 1 do
        if shown
          effects = UI::Equip.effects(item, :gems => gems, :shared => shared, :actor => actor)
          item_body(rows, effects, before: against, compact: { STEP_LINES => { most_rows: 1 } })
        end
      end
    end
  end

  # The dialog that changes the item in a slot, as the game's equip list does: a search and a Filter
  # over the items in two columns, the worn item set against the one under the cursor. D (the game's
  # Z) opens the Filter, S (its Y) marks a favorite; a pick equips the item and closes the dialog.
  class ItemDialog < UI::Component
    include Parts

    # The rows the list shows in a dialog of the least height, and how many more per how much
    # higher, so the comparison keeps about half the room.
    LEAST_ROWS = 6
    MORE_ROWS = [3, 80]

    # The value of the Filter's favorites entry.
    FAVORITES = :favorites

    # The character.
    param :actor

    # The slot, from 0.
    param :slot

    # Whether the Filter keeps the favorites only as it opens.
    param :favorites, false

    # Whether the Filter keeps the favorites only, each time that changes.
    event :favorites

    # What the search holds.
    state :search, ""

    # The values of the Filter's entries that are on.
    state(:filters) { favorites ? [FAVORITES] : [] }

    # The row under the list's cursor: the first item's as it opens.
    state(:row) { UI::Equip.item_rows(actor, slot).find { |each| each[:item] } }

    # Whether the Filter's menu is open.
    state :menu_open, false

    # Whether a field types, which names other keys in the key help.
    watch { UI.typing? }

    # Describes the dialog.
    def render
      rows = UI::Equip.item_rows(actor, slot)
      types = UI::Game.type_filters(rows)
      item_list = lambda do
        list rows, id: :ew_item_list, bind: :row, columns: 2, spacing: 6, most_rows: least_rows, autofocus: true, filter: ->(each) { kept?(each[:item]) },
                   no_match: TEXTS[:no_item], empty: TEXTS[:no_items], on_submit: ->(picked) { pick(picked) }, on_button: list_buttons,
                   button_help: { z: KEY_TEXTS[:filter], y: row_item && UI::Game.favorite_text(UI::Game.favorite?(row_item)) }
      end
      tallest = UI::Equip.room(rows, UI::Equip.item(actor, slot)).map { |item| { picked: item } }
      comparison = -> { compare actor: actor, slot: slot, picked: row, height: :fill, id: :ew_item_compare, compact_for: tallest }
      picker UI::Game.slot_name(actor, slot), "item", list: item_list, compare: comparison, keys: { entries: key_entries, auto: !menu_open } do
        select placeholder: KEY_TEXTS[:filter], bind: :filters, multi: true, clear_text: TEXTS[:clear], steer: :ew_item_list, button: :z, id: :ew_item_filter,
               on_change: ->(values) { emit(:favorites, values.include?(FAVORITES)) }, on_open: -> { self.menu_open = true }, on_close: -> { self.menu_open = false } do
          select_item TEXTS[:favorites], value: FAVORITES, icon: UI::Game.favorite_icon, disabled: rows.none? { |each| UI::Game.favorite?(each[:item]) }
          (types.size > 1 ? types : []).each { |type| select_item type[:text], value: type[:value], key: type[:value] }
        end
      end
    end

    private

    # Tells whether the Filter and the search keep an item: a favorite while Favorites is on, one of
    # the types that are on, and a name that holds the search.
    #
    # @param item [RPG::EquipItem] The item.
    # @return [Boolean] Whether they keep it.
    def kept?(item)
      types = filters - [FAVORITES]
      return false if filters.include?(FAVORITES) && !UI::Game.favorite?(item)
      return false unless types.empty? || types.include?(UI::Game.type_key(item))

      searched?(item)
    end

    # Tells how many rows the list shows by the height of the window whose place the dialog takes.
    #
    # @return [Integer] The rows, at least one.
    def least_rows
      size = opener_size
      height = size ? [size[1], DIALOG_SIZE[1]].max : Graphics.height
      [LEAST_ROWS + (height - DIALOG_SIZE[1]) * MORE_ROWS[0] / MORE_ROWS[1], 1].max
    end

    # Tells the game's buttons the list takes: none while the search types, so S and D type.
    #
    # @return [Hash] Each button's handler.
    def list_buttons
      UI.typing? ? {} : { z: -> { part(:ew_item_filter).open_menu }, y: -> { mark_favorite } }
    end

    # Tells the item under the cursor.
    #
    # @return [RPG::EquipItem, nil] The item, nil on a row of no item.
    def row_item
      row.is_a?(Hash) ? row[:item] : nil
    end

    # Tells the key help's entries: only what closes the Filter's menu while it is open; else Tab
    # into the search or back to the list, and Back last while no field types.
    #
    # @return [Array<Hash>] The entries.
    def key_entries
      return [{ button: :Z, text: KEY_TEXTS[:close] }] if menu_open
      return [{ key: "Tab", text: KEY_TEXTS[:list] }] if UI.typing?

      [{ key: "Tab", text: KEY_TEXTS[:search] }, { button: :B, text: KEY_TEXTS[:back] }]
    end

    # Equips a picked row's item, or takes the slot's item out, and closes; a refusal only buzzes.
    #
    # @param picked [Hash] The row.
    def pick(picked)
      close if Equipment_Window.equip(actor, slot, picked[:data])
    end

    # Marks the cursor's item a favorite or takes the mark away; a row of no item buzzes.
    def mark_favorite
      return UI.buzz("a favorite mark on #{row.is_a?(Hash) ? row[:text].inspect : 'no row'}: it holds no item") unless row_item

      UI.confirm_sound
      Equipment_Window.toggle_favorite(row_item)
    end
  end

  # The dialog that changes the gem in one socket of the item in a slot: the bag's gems that go in
  # without pushing another socket's gem out, a search and a toggle per color over them, which the
  # digits turn on and off, and the socket's gem now set against the one under the cursor. A change
  # closes it, a refused one keeps it open; on a slot whose gems cannot change it only buzzes.
  class GemDialog < UI::Component
    include Parts

    # The rows a gem's lines take in the comparison, and the height of each.
    LINE_ROWS = 2
    LINE_ROW = 14

    # The height of a side of the comparison: a gem's name with its icon and its lines.
    SIDE_HEIGHT = UI::ICON_SIZE + LINE_ROWS * LINE_ROW

    # The character.
    param :actor

    # The slot, from 0.
    param :slot

    # The socket it changes, from 0; the first empty one when not given.
    param :socket, nil

    # The sockets the change changed, from 0.
    event :change

    # What the search holds.
    state :search, ""

    # The colors whose toggles are on, by their icons.
    state(:colors) { [] }

    # The row under the list's cursor: the first gem's as it opens.
    state(:row) { gem_rows.find { |each| each[:item] } || gem_rows.first }

    # Whether a field types, which names other keys in the key help.
    watch { UI.typing? }

    # Describes the dialog.
    def render
      gem_list = lambda do
        list gem_rows, id: :ew_gem_list, bind: :row, height: :fill, rows_shown: :fill, autofocus: true, filter: ->(each) { kept?(each[:item]) },
                       no_match: TEXTS[:no_gem], on_submit: ->(picked) { pick(picked) }
      end
      title = format(TEXTS[:gem_title], UI::Game.slot_name(actor, slot), place + 1)
      picker title, "gem", gate: -> { changeable }, list: gem_list, compare: -> { gem_compare }, keys: { entries: key_entries } do
        toggle_group bind: :colors, multi: true, number_keys: true do
          color_filters.each do |each|
            toggle_item "", icon: each[:icon], value: each[:value], tooltip: each[:tooltip], disabled: each[:disabled], key: each[:value]
          end
        end
      end
    end

    private

    # Describes the socket's gem now set against the gem under the cursor, as high wherever it rests.
    def gem_compare
      captions = [TEXTS[:now], TEXTS[:after]]
      after_text, gem = after
      halves(height: SIDE_HEIGHT) do
        field(TEXTS[:now], caption_width: captions, width: 0, grow: 1) { gem_block(UI::Equip.sockets(item)[place]) }
        field(TEXTS[:after], caption_width: captions, width: 0, grow: 1) { after_text ? text(after_text, typo: :body2, color: :dim) : gem_block(gem) }
      end
    end

    # Works out what the cursor's row does: no row asks for a pick, the dim row of an empty bag says
    # so, the socket's own gem changes nothing, any other row puts its gem or none there.
    #
    # @return [Array] The text the After side shows instead of a gem, or nil, and the gem afterwards.
    def after
      return [TEXTS[:pick], nil] unless row.is_a?(Hash)
      return [TEXTS[:no_gems], nil] if row[:disabled] == true && !row[:remove]

      preview = UI::Equip.gem_preview(item, place, row[:remove] ? nil : row[:data])
      [preview[:unchanged] ? TEXTS[:no_change] : nil, preview[:gem]]
    end

    # Describes a gem with the lines it adds under its name in the tiny font, or the empty socket.
    #
    # @param gem [RPG::Item, nil] The gem, nil for an empty socket.
    def gem_block(gem)
      return named(UI::Game.empty_socket_icon, TEXTS[:empty_socket], :dim) unless gem

      stack spacing: 0 do
        named(gem.icon_index, *item_look(gem))
        lines UI::Equip.gem_info(gem)[:lines], size: :tiny, columns: :auto, gutter: UI::ICON_STEP, height: LINE_ROWS * LINE_ROW
      end
    end

    # Tells the key help's entries: Tab into the search or back to the list, the digits of the colors
    # while there are two or more and Back last, both while no field types.
    #
    # @return [Array<Hash>] The entries.
    def key_entries
      typing = UI.typing?
      entries = [{ key: "Tab", text: typing ? KEY_TEXTS[:list] : KEY_TEXTS[:search] }]
      entries << { key: "1-#{color_filters.size}", text: KEY_TEXTS[:colors] } if !typing && color_filters.size >= 2
      entries << { button: :B, text: KEY_TEXTS[:back] } unless typing
      entries
    end

    # Tells whether the slot's gems may change, the dialog's gate: true, else why not, with the buzzer.
    #
    # @return [Boolean, String] true, or why not.
    def changeable
      return true if UI::Equip.gems_changeable?(actor, slot)

      UI.buzz
      format(TEXTS[:fixed], UI::Game.slot_name(actor, slot), UI::Game.actor_ref(actor))
    end

    # Tells the item, as the slot holds it now.
    #
    # @return [RPG::EquipItem, nil] The item.
    def item
      UI::Equip.item(actor, slot)
    end

    # Tells the socket it changes: the one given, kept on the item's sockets, else the first empty one.
    #
    # @return [Integer] The socket, from 0.
    def place
      gems = UI::Equip.sockets(item)
      given = socket.nil? ? gems.index(nil) || 0 : socket.to_i
      [[given, gems.size - 1].min, 0].max
    end

    # Tells the list's rows: the remove row, greyed while the socket is empty, then the gems.
    #
    # @return [Array<Hash>] The rows.
    def gem_rows
      UI::Equip.gem_rows(item, place)
    end

    # Tells whether the color toggles and the search keep a gem.
    #
    # @param gem [RPG::Item] The gem.
    # @return [Boolean] Whether they keep it.
    def kept?(gem)
      (colors.empty? || colors.include?(UI::Equip.gem_color(gem))) && searched?(gem)
    end

    # Tells a toggle per color, off where the bag has none or another socket holds one.
    #
    # @return [Array<Hash>] Each color's :icon, :value, :tooltip and :disabled.
    def color_filters
      UI::Equip.gem_colors(item, place, :tooltip => TEXTS[:color_tip])
    end

    # Puts a picked row's gem into the socket, or empties it for the remove row, and closes; a pick
    # that changes nothing buzzes, and one the game refuses keeps the dialog open.
    #
    # @param picked [Hash] The row.
    def pick(picked)
      gem = picked[:remove] ? nil : picked[:data]
      preview = UI::Equip.gem_preview(item, place, gem)
      if preview[:unchanged]
        return UI.buzz("#{gem ? UI::Game.item_ref(gem) : 'no gem'} into socket #{place + 1} of #{UI::Game.item_ref(item)}: #{preview[:note][0].downcase}")
      end
      return unless Equipment_Window.change_gem(actor, slot, place, gem)

      emit(:change, preview[:changed])
      close
    end
  end

  # The window: the character, the gear and the details, two of the three pages side by side, and
  # the hotkey help under them.
  class EquipWindow < UI::Component
    include Parts

    # The width of the socket numbers' gutter on the Gems tab and of the pieces' gutter on the Set tab.
    SOCKET_GUTTER = 16
    STEP_GUTTER = 36

    # The character the window opens on.
    param :actor

    # The character shown; Q and W switch it.
    state(:shown) { actor }

    # The index of the selected slot.
    state :slot, 0

    # The first page shown: 0 for character and gear, 1 for gear and details.
    state :page, 0

    # The details' tab, kept while the slot changes.
    state :details_tab, :info

    # Whether the item dialog lists favorites only.
    state :favorites, false

    # The part in focus the key help names keys for: :slots, :optimize, :clear or :details.
    state :keys_for, :slots

    # Whether a gamepad was used last, whose shoulders step the details' tabs while they show.
    watch { UI.pad? }

    # The character other mods' changes may read.
    expose(:actor) { shown }

    # The selected item other mods' changes may read.
    expose(:item) { current_item }

    # Describes the window.
    def render
      window UI::Game.actor_title(shown), id: :ew_equipment_window, width: :screen, height: :screen, min_size: [0, 400],
                                          resizable: :height, on_page: ->(step) { switch(step) } do
        slides bind: :page, shown: 2, id: :ew_pages, height: :fill do
          slide(id: :ew_character) { character_page }
          slide(id: :ew_gear) { gear_page }
          slide(id: :ew_details, can_enter: -> { !current_item.nil? }) { details_page }
        end
        key_help entries: key_entries, id: :ew_keys
      end
    end

    # Describes the character page: Optimize and Clear, the Library art and the stats.
    def character_page
      stack row: true, id: :ew_buttons do
        button UI::Game.term(:optimize), variant: :outlined, grow: 1, tooltip: OPTIMIZE_TIP, on_click: -> { Equipment_Window.optimize(shown) },
                                         on_focus: -> { self.keys_for = :optimize }, on_blur: -> { self.keys_for = :details }
        button UI::Game.term(:clear), variant: :outlined, grow: 1, tooltip: CLEAR_TIP, on_click: -> { Equipment_Window.clear(shown) },
                                      on_focus: -> { self.keys_for = :clear }, on_blur: -> { self.keys_for = :details }
      end
      image portrait: shown, fit: :cover, anchor: :top, grow: 1, min_size: [160, 96]
      paper id: :ew_stats do
        text "Basic", typo: :subtitle2
        character_stats(:basic)
        text "Other", typo: :subtitle2
        character_stats(:other)
      end
    end

    # Describes one kind of the character's stats, those the last change raised or lowered in the
    # game's colors for better and worse until they change again or another character shows.
    #
    # @param kind [Symbol] :basic for HP, MP and the parameters, :other for the rates.
    def character_stats(kind)
      [:equips, :level, :states].each { |read| UI::Game.send(read, shown) }
      rows = UI::Game.stat_rows(shown, kind == :basic ? { :rates => [] } : { :params => [] })
      @judged ||= {}
      seen = @judged[kind]
      before = seen && seen[:actor].equal?(shown) ? (seen[:rows] == rows ? seen[:before] : seen[:rows]) : nil
      @judged[kind] = { actor: shown, rows: rows, before: before }
      stat_grid rows, before: before, columns: 2, size: :small
    end

    # Describes the gear page: the slot list and the summary only the mouse uses.
    def gear_page
      item = current_item
      list UI::Equip.slot_rows(shown), bind_index: :slot, id: :ew_slots, most_rows: 8, autofocus: true, on_submit: -> { pick },
                                       on_focus: -> { self.keys_for = :slots }, on_blur: -> { self.keys_for = :details }
      divider
      aside id: :ew_summary, height: :fill do
        subtitle, look = UI::Equip.slot_note(shown, slot)
        item_head(item, subtitle, subtitle_color: look, empty: NOTHING_TEXT, note: -> { details_link }, on_click: (:forward if item))
        if UI::Equip.socketed?(item)
          slot_row socket_slots(UI::Equip.sockets(item)), id: :ew_summary_gems, empty_icon: UI::Game.empty_socket_icon, empty_tooltip: TEXTS[:empty_socket],
                                                         note: -> { gem_note(CLICK_TEXT) }, on_pick: ->(socket) { pick_socket(socket, :ew_summary_gems) }
        end
        summary(item) if item
      end
    end

    # Describes what an item adds; while the details are out of view the last line counts the lines
    # left out and slides the details in.
    #
    # @param item [RPG::EquipItem] The item.
    def summary(item)
      more = page == 0 ? { more_text: MORE_DETAILS, more_color: :system, on_more: :forward } : {}
      stack spacing: 1, height: :fill do
        item_body(UI::Equip.stats(item), UI::Equip.effects(item, :actor => shown), more.merge(grow: 1))
      end
    end

    # Describes the link to the details while they are out of view.
    def details_link
      button DETAILS, variant: :text, disabled: current_item.nil?, on_click: :forward if page == 0
    end

    # Describes the details page: Back and the item's tabs over its type, or the empty slot's name.
    def details_page
      item = current_item
      return item_tabs(item) if item

      button BACK, variant: :text, on_click: :back
      text UI::Game.slot_name(shown, slot), color: :dim
      text NOTHING_TEXT, color: :dim
    end

    # Describes Back and the Info, Gems and Set tabs of an item, its type under them.
    #
    # @param item [RPG::EquipItem] The item.
    def item_tabs(item)
      tabs bind: :details_tab, id: :ew_detail_tabs do
        tabs_header { button BACK, variant: :text, on_click: :back }
        tabs_subheader { type_section(item) }
        tab("Info", id: :ew_info) { info_section(item) }
        tab("Gems #{UI::Equip.gems_text(item)}", id: :ew_gems) { gems_section(item) } if UI::Equip.socketed?(item)
        tab("Set", id: :ew_sets) { sets_section(item) } if UI::Equip.in_set?(item)
      end
    end

    # Describes the item's type and the traits all items of that type share, small and grey.
    #
    # @param item [RPG::EquipItem] The item.
    def type_section(item)
      type = UI::Game.type_name(item)
      traits = UI::Equip.type_lines(item)
      stack spacing: 1 do
        unless type.empty?
          group type, size: :tiny, title_color: :dim, dense: true, spacing: 0 do
            lines traits, size: :tiny, color: :dim, columns: :room, span: true, spacing: 2, escapes: true unless traits.empty?
          end
        end
      end
    end

    # Describes the item's Base Stats and Special Effects, as the game's info page names them.
    #
    # @param item [RPG::EquipItem] The item.
    def info_section(item)
      base = UI::Equip.base_stats(item)
      stack spacing: 2.5 do
        group("Base Stats", dense: true, spacing: 0) { stat_grid base, columns: 2, size: :small, dense: true } unless base.empty?
        group "Special Effects", dense: true, spacing: 0, grow: 1 do
          lines UI::Equip.special_effects(item), columns: :room, sort: true, titles: false, escapes: true, empty: TEXTS[:no_effects], grow: 1
        end
      end
    end

    # Describes a line per socket with its gem and the gem's description, which the keys walk and
    # confirm picks.
    #
    # @param item [RPG::EquipItem] The item.
    def gems_section(item)
      gems = UI::Equip.sockets(item)
      socket_lines = memo(gems) do
        gems.each_with_index.map do |gem, place|
          line = { text: TEXTS[:empty_line], icon: UI::Game.empty_socket_icon, color: :dim }
          line = { item: gem, detail: UI::Equip.gem_info(gem)[:description], tooltip: -> { gem_tip(gem, place, gems.size, nil) } } if gem
          { label: (place + 1).to_s, color: :dim, lines: [line] }
        end
      end
      stack spacing: 1 do
        lines socket_lines, id: :ew_tab_gems, gutter: SOCKET_GUTTER, escapes: true, note: -> { gem_note(CONFIRM_TEXT) },
                            on_pick: ->(socket) { pick_socket(socket, :ew_tab_gems) }, grow: 1
      end
    end

    # Describes each set the item belongs to side by side: its name and worn pieces over its bonuses.
    #
    # @param item [RPG::EquipItem] The item.
    def sets_section(item)
      stack row: true, spacing: 3, grow: 1 do
        UI::Equip.set_lines(item, shown).each do |set|
          group set[:name], note: set[:note], title_color: set[:color], size: :medium, dense: true, width: 0, grow: 1, key: set[:name] do
            lines set[:lines], gutter: STEP_GUTTER, group_spacing: 1, escapes: true, grow: 1
          end
        end
      end
    end

    # Describes the last tooltip line of a gem: how to change it, or that its slot is fixed.
    #
    # @param how [String] The line when it can change.
    def gem_note(how)
      UI::Equip.gems_changeable?(shown, slot) ? text(how, color: :system) : text(FIXED_TEXT, color: :warning)
    end

    # Tells the key help's entries for the part in focus: Change, the shoulders and Close on the
    # slot list; the button's action, the shoulders and Back on Optimize and Clear; on the details
    # Next tab while two or more tabs show and no gamepad was used last, the shoulders and Back.
    #
    # @return [Array<Hash>] The entries.
    def key_entries
      back = { button: :B, text: KEY_TEXTS[:back] }
      case keys_for
      when :slots then [{ button: :C, text: KEY_TEXTS[:change] }, shoulders_entry, { button: :B, text: KEY_TEXTS[:close] }]
      when :optimize, :clear then [{ button: :C, text: UI::Game.term(keys_for) }, shoulders_entry, back]
      else (tabbed? && !UI.pad? ? [{ key: "Tab", text: KEY_TEXTS[:next_tab] }] : []) + [shoulders_entry, back]
      end
    end

    # Tells what Q and W or a gamepad's shoulders do: a gamepad's shoulders step the details' tabs
    # while two or more show, as the framework's tabs in view take them; else they switch the character.
    #
    # @return [Hash] The entry.
    def shoulders_entry
      { button: [:L, :R], text: UI.pad? && page == 1 && tabbed? ? KEY_TEXTS[:tabs] : KEY_TEXTS[:character] }
    end

    # Tells whether the selected item shows two or more tabs on the details page.
    #
    # @return [Boolean] Whether it does.
    def tabbed?
      item = current_item
      UI::Equip.socketed?(item) || UI::Equip.in_set?(item) ? true : false
    end

    # Returns the item in the selected slot.
    #
    # @return [RPG::EquipItem, nil] The item, or nil for an empty slot.
    def current_item
      UI::Equip.item(shown, slot)
    end

    # Opens the item dialog for the selected slot and keeps its favorites choice.
    def pick
      UI.open ItemDialog, actor: shown, slot: slot, favorites: favorites, on_favorites: ->(on) { self.favorites = on }
    end

    # Opens the gem dialog on a socket picked, whose changed sockets pulse in the part it was picked
    # in; in a slot whose gems cannot change it buzzes instead.
    #
    # @param socket [Integer] The socket, from 0.
    # @param from [Symbol] The id of that part.
    def pick_socket(socket, from)
      item = current_item
      if UI::Equip.gems_fixed?(shown, item, slot)
        return UI.buzz("socket #{socket + 1} of #{UI::Game.item_ref(item)}: #{UI::Game.actor_ref(shown)} wears it where its gems cannot change")
      end

      UI.open GemDialog, actor: shown, slot: slot, socket: socket, on_change: ->(sockets) { part(from).pulse(sockets) }
    end

    # Switches to the previous or next character and keeps the page, the slot and the tab.
    #
    # @param step [Integer] -1 for the previous character, 1 for the next.
    def switch(step)
      other = UI::Game.next_actor(shown, step)
      return unless other

      self.shown = other
      self.slot = [slot, UI::Equip.slot_rows(other).size - 1].min
      part(:ew_pages).enter_from(step)
    end
  end

  # The row that picks which screen the menu's Equip opens.
  Mod_Framework::Options.add(:equipment_window_screen, "[Equipment Window] Equip Command",
                             "Which screen the menu's Equip opens.",
                             { 1 => "Equipment Window", 0 => "Game's Screen" }, 1)

  UI.replace_scene Scene_Equip, EquipWindow, if: -> { Mod_Framework::Options.value(:equipment_window_screen) != 0 },
                                             params: ->(_scene) { { actor: $game_party.menu_actor } }
end
