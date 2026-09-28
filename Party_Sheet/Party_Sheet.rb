#----------------------------------------------------------------
#  Party_Sheet.rb
#
#  Changelog:
#      Paulinchen  2026-09-27: Added a Theme option that makes the page white and gold for Ilias, dark and purple for Alice.
#                            - Blocked scripts and outside requests in the page with a content security policy.
#                            - Wrote the page indented, an element or CSS declaration per line.
#                            - Created
#
#----------------------------------------------------------------

# Writes Party Sheet.html next to Game.exe at the press of KEY or from the Mod Config Menu: every
# party member with the full picture of the Library, levels, stats, equipment, abilities, trait and
# the jobs and races mastered. It can also take an image of the Frontline. It must never interrupt
# the game, so every entry point rescues.
module MGQ_PartySheet
  # Turns the sheet off without uninstalling it.
  ENABLED = true

  # Key that writes the sheet, anywhere in the game.
  KEY = :F7

  # Whether the page carries its images inside (true) or links them from the game folder (false).
  # Embedded, the page can be moved and shared on its own, at a few MB.
  EMBED_IMAGES = true

  # Page written next to Game.exe.
  FILE = "Party Sheet.html"

  # Quality from 0 to 1 at which the browser converts the page's embedded portraits to WebP,
  # several times smaller than the game's PNGs. nil keeps the PNGs.
  PORTRAIT_QUALITY = 0.85

  # Image of the Frontline written next to the page.
  IMAGE_FILE = "Party Sheet.png"

  # Log next to the page, which only appears when something went wrong.
  LOG_FILE = "Party Sheet.log"

  # Lines logged per session at most, a part missing from the game would be logged at every write.
  MAX_LOG_LINES = 60

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already
  def self.hookable?
    !Scene_Base.method_defined?(:mgq_party_sheet_update_basic)
  end

  # Writes what the Output option asks for, for the party that is loaded, and plays the save sound
  # when it did, the buzzer when no game is loaded.
  def self.write
    return unless ENABLED

    if $game_party.nil? || $game_party.all_members.empty?
      Sound.play_buzzer
      return
    end

    page = Options.page? ? Page.build : nil
    File.open(path(FILE), "wb") { |file| file.write(page) } if page
    Browser.run(page, Options.image?)
    Sound.play_save
  rescue => e
    log("could not write the party sheet: #{e.class}: #{e.message}")
  end

  # Writes the sheet when KEY was pressed this frame. Called once per frame, after the input updated.
  def self.check_key
    write if Input.trigger?(KEY)
  rescue => e
    log("key check failed: #{e.class}: #{e.message}")
  end

  # Builds a part of the page, leaving it out when the game lacks what it reads.
  #
  # @param part [String] what the part shows, for the log
  # @yieldreturn [String] the part's HTML
  # @return [String] the HTML, "" when building it failed
  def self.safely(part)
    yield
  rescue => e
    log("#{part} left out: #{e.class}: #{e.message}")
    ""
  end

  # Builds the path of a file inside the game folder.
  #
  # @param name [String] the file name, relative to the game folder
  # @return [String] the full path
  def self.path(name)
    "#{game_dir}/#{name}"
  end

  # @param name [String] the file name, relative to the game folder
  # @return [Boolean] whether the file is in the game folder, false for one inside Game.rgss3a
  def self.exist?(name)
    File.exist?(path(name))
  end

  # The folder of Game.exe.
  #
  # Asked of Windows, the working directory is wherever a shortcut or Steam started the game.
  #
  # @return [String] the folder, with forward slashes
  def self.game_dir
    @game_dir ||= begin
      buffer = "\0" * 512
      length = Win32API.new('kernel32', 'GetModuleFileNameA', 'lpl', 'l').call(0, buffer, 512)
      File.dirname(buffer[0, length].tr("\\", "/"))
    end
  rescue
    @game_dir = Dir.pwd
  end

  # Appends a line to LOG_FILE, prefixed with the time.
  #
  # @param message [String] the line to append
  def self.log(message)
    @log_lines = (@log_lines || 0) + 1
    return if @log_lines > MAX_LOG_LINES

    File.open(path(LOG_FILE), "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end

  # The mod's entries in the Mod Config Menu when it is installed, in the game's Config menu
  # otherwise: what to write, a button that writes it, and the page's colours.
  module Options
    # What the sheet writes: 0 the page and the image, 1 the page, 2 the image.
    OUTPUT = :mod_party_sheet_output

    # The button that writes the sheet.
    WRITE = :mod_party_sheet_write

    # Whether the colours follow the side chosen (0) or are always the ones of Shown Theme (1).
    THEME = :mod_party_sheet_theme

    # Which colours the page has while Theme is Static: 0 dark and purple, 1 white and gold.
    SHOWN_THEME = :mod_party_sheet_shown_theme

    # Theme's value that keeps the colours of Shown Theme.
    STATIC = 1

    # Shown Theme's value for white and gold.
    LIGHT = 1

    # Output's values by their name and help in the menu. The first one is the default.
    OUTPUTS = {
      0 => ["Page and Image", "Party Sheet.html with the whole party, and Party Sheet.png of the Frontline."],
      1 => ["Page",           "Party Sheet.html with the whole party."],
      2 => ["Image",          "Party Sheet.png of the Frontline."],
    }

    # Theme's values by their name and help in the menu. The first one is the default.
    THEMES = {
      0 => ["Dynamic", "White and gold if you chose Ilias, dark and purple if you chose Alice or have not chosen yet."],
      1 => ["Static",  "Always the colours Shown Theme picks."],
    }

    # Shown Theme's values by their name and help in the menu. The first one is the default.
    SHOWN_THEMES = {
      0 => ["Alice (Dark)",  "Always dark and purple."],
      1 => ["Ilias (Light)", "Always white and gold."],
    }

    # Adds the entries before the menu's last one, which returns, and takes Shown Theme out while
    # Theme is Dynamic. Its entry is kept, so arrange can put it back.
    #
    # The Mod Config Menu defines MOD_CONTENTS in 0_ModConfigMenu.rb, which the mod loader runs
    # before this script.
    def self.register
      config = NWConst::Config
      @menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS

      add(OUTPUT, "[Party Sheet] Output", "What the party sheet writes into the game folder.", OUTPUTS)
      @menu.insert(-2, :key => WRITE, :name => "     -> Write Party Sheet", :sub => false,
                       :help => "Write the party sheet now. #{KEY} does the same anywhere in the game.")
      @theme = add(THEME, "[Party Sheet] Theme", "The colours of the party sheet.", THEMES)
      @shown_theme = add(SHOWN_THEME, "     -> Shown Theme", "The colours of the party sheet while Theme is Static.", SHOWN_THEMES)

      arrange
    end

    # Adds an option before the menu's last entry.
    #
    # @param key [Symbol] the option, its key in $game_system.conf
    # @param name [String] its name in the menu
    # @param help [String] its help in the menu
    # @param values [Hash{Integer => Array(String, String)}] its values by their name and help, the
    #   first one being the default
    # @return [Hash] its entry in the menu
    def self.add(key, name, help, values)
      config = NWConst::Config
      entry = { :key => key, :name => name, :sub => true, :help => "#{help}\r\n←/→ Toggle" }

      @menu.insert(-2, entry)
      config::DATA[key] = values.keys
      config::DATA_TEXT[key] = {}
      values.each { |value, (label, text)| config::DATA_TEXT[key][value] = { :name => label, :help => text } }
      config::DEFAULT[key] = values.keys.first
      entry
    end

    # Puts Shown Theme into the menu, below Theme, while Theme is Static, and takes it out otherwise.
    # The config windows call it before they draw, so the menu follows every change.
    #
    # @return [Boolean] whether the menu changed
    def self.arrange
      return false unless @shown_theme

      listed = @menu.any? { |item| item.equal?(@shown_theme) }
      return false if listed == static_theme?

      if listed
        @menu.reject! { |item| item.equal?(@shown_theme) }
      else
        @menu.insert(@menu.index { |item| item.equal?(@theme) } + 1, @shown_theme)
      end
      true
    end

    # Reads an option as the menu currently shows it.
    #
    # @param key [Symbol] the option
    # @return [Integer] its value, its default until it was changed
    def self.value(key)
      value = $game_system.conf[key] rescue nil
      value.nil? ? NWConst::Config::DEFAULT[key] : value
    end

    # @return [Boolean] whether the sheet writes the page
    def self.page?
      value(OUTPUT) != 2
    end

    # @return [Boolean] whether the sheet takes the image of the Frontline
    def self.image?
      value(OUTPUT) != 1
    end

    # @return [Boolean] whether the colours are always the ones of Shown Theme
    def self.static_theme?
      value(THEME) == STATIC
    end

    # @return [Boolean] whether the page is white and gold rather than dark and purple
    def self.light?
      static_theme? ? value(SHOWN_THEME) == LIGHT : Party.side == :ilias
    end
  end

  # Turns game values into text that is safe inside the page.
  module Text
    # Characters HTML reads as markup, by their escaped form.
    ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;" }

    # Control codes the game's windows draw as colors or icons, like \C[2] or \I[125], written with
    # a backslash or, once the windows converted them, with an escape character.
    CONTROL_CODE = /[\\\e][A-Za-z]+(?:\[[^\]]*\])?|[\\\e][{}|.!<>^$]/

    # Spaces, with the no-break space some of the game's written lines use and the full-width one,
    # which \s leaves out in Ruby 1.9.
    SPACES = /[\s 　]+/

    # @param value [Object] the value
    # @return [String] the value as text, escaped for HTML
    def self.html(value)
      value.to_s.gsub(/[&<>"']/) { |char| ESCAPES[char] }
    end

    # @param value [Object] text from the game's data
    # @return [String] the text without control codes or repeated spaces, escaped for HTML
    def self.game(value)
      html(plain(value))
    end

    # @param value [Object] text from the game's data, like a description, over several lines
    # @return [String] each line without control codes, escaped for HTML, joined by line breaks
    def self.lines(value)
      value.to_s.split(/\r?\n/).map { |line| game(line) }.reject(&:empty?).join("<br>")
    end

    # @param value [Object] text from the game's data
    # @return [String] the text without control codes, with every run of spaces as one plain space
    def self.plain(value)
      value.to_s.gsub(CONTROL_CODE, "").gsub(SPACES, " ").strip
    end

    # Smallest number the status screen shortens.
    LARGE = 10_000_000

    # @param value [Integer] a whole number
    # @return [String] the number with thousands separators, like 1,234,567
    def self.number(value)
      value.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    # Shortens a number like the status screen does, with the units of the game or its translation.
    #
    # @param value [Integer] a whole number
    # @return [String] the number shortened from LARGE on, like 12.346Mil., with separators below
    def self.large(value)
      value = value.to_i
      return number(value) if value < LARGE || !value.respond_to?(:give_unit_floor)

      html(value.give_unit_floor(12))
    end

    # @param rate [Float] a rate, 1.0 being 100%
    # @return [String] the rate in percent, cut like the game's status screen does
    def self.percent(rate)
      "#{(rate * 100).to_i}%"
    end

    # @param path [String] a path relative to the page, or a full one with its drive
    # @return [String] the path percent-encoded for a URL
    def self.url(path)
      path.gsub(/[^A-Za-z0-9\-._~\/:]/) { |char| char.unpack("C*").map { |byte| format("%%%02X", byte) }.join }
    end
  end

  # What the page shows of the party, read from the game.
  module Party
    # Extensions a picture may have, in the order they are looked for.
    PICTURE_EXTENSIONS = [".png", ".jpg"]

    # @return [Array<Game_Actor>] the members who fight
    def self.front
      $game_party.battle_members
    end

    # @return [Array<Game_Actor>] the members who wait in reserve
    def self.reserve
      $game_party.all_members - front
    end

    # @param actor [Game_Actor] the actor
    # @return [RPG::Class, nil] the job, nil while she has none
    def self.job(actor)
      actor.class_id > 0 ? $data_classes[actor.class_id] : nil
    end

    # @param actor [Game_Actor] the actor
    # @return [RPG::Class, nil] the race, nil while she has none
    def self.race(actor)
      actor.tribe_id > 0 ? $data_classes[actor.tribe_id] : nil
    end

    # Lists the jobs or races an actor has mastered, in the order of the game's status screen.
    #
    # A job or race whose level in level_list reached its max_lv counts as mastered.
    #
    # @param actor [Game_Actor] the actor
    # @param kind [Symbol] :job? for jobs, :tribe? for races
    # @return [Array<RPG::Class>] the jobs or races
    def self.mastered(actor, kind)
      ids = actor.level_list.select do |id, level|
        data = $data_classes[id]
        data && data.send(kind) && level >= data.max_lv
      end.keys

      ids.sort_by { |id| [$data_classes[id].class_lank, id] }.map { |id| $data_classes[id] }
    end

    # Names the ranks of jobs or races as the job change screen does, like Basic Jobs or Sealed Races.
    #
    # @param type [Integer] 0 for jobs, 1 for races
    # @return [Hash{Integer => String}] the names by rank, in the screen's order, empty when the
    #   game has none
    def self.ranks(type)
      names = NWConst::JobChange::CLASS_TYPE[type] || []
      names.each_with_index.each_with_object({}) { |(name, rank), ranks| ranks[rank] = name unless name.to_s.empty? }
    rescue NameError
      {}
    end

    # Finds the picture the Library shows of a companion.
    #
    # @param actor [Game_Actor] the actor
    # @return [String, nil] its path relative to the game folder, nil when it is not a loose file
    def self.picture(actor)
      image = NWConst::Library::ACTOR_IMAGE[actor.id]
      return nil unless image.is_a?(Array)

      PICTURE_EXTENSIONS.map { |extension| "#{image[0]}#{image[1]}#{extension}" }
                        .find { |file| MGQ_PartySheet.exist?(file) }
    end

    # @param actor [Game_Actor] the actor
    # @return [String, nil] the path of her face sheet relative to the game folder, nil when it is
    #   not a loose file
    def self.face(actor)
      file = "Graphics/Faces/#{actor.face_name}.png"
      !actor.face_name.to_s.empty? && MGQ_PartySheet.exist?(file) ? file : nil
    end

    # @return [Boolean] whether the icon sheet is a loose file the page can show
    def self.icons?
      @icons = MGQ_PartySheet.exist?("Graphics/System/IconSet.png") if @icons.nil?
      @icons
    end

    # Pairs the slots of an actor with what she wears, as the game's status screen does.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(String, RPG::EquipItem)>] the slot names and items, nil for an empty slot
    def self.equipment(actor)
      equips = actor.equips
      actor.basic_equip_slots.each_with_index.map { |etype, index| [Vocab.etype(etype), equips[index]] }
    end

    # Lists what an item gives on its own, its gems left out, as the game's status screen names it:
    # its stat bonuses, then its effects. An item whose description adds lines of its own shows
    # those instead of its effects' names, as in the game.
    #
    # The socket count the game lists first is left out, as the gems show on their own.
    #
    # @param item [RPG::EquipItem, RPG::Armor] the item, or an armor that carries a gem's effects
    # @return [Array<String>] the bonuses, without control codes or repeats
    def self.bonuses(item)
      sockets = item.respond_to?(:socket?) && item.socket? ? Text.plain(item.socket_name) : nil

      names = [:param_names, :enchant_names].select { |method| item.respond_to?(method) }.map { |method| item.send(method) }
      names.flatten.compact.map { |name| Text.plain(name) }.reject { |name| name.empty? || name == sockets }.uniq
    end

    # @param item [RPG::EquipItem] the item
    # @return [Array<RPG::Item, nil>] the gem in each of its sockets, nil for an empty one
    def self.gems(item)
      item.respond_to?(:stones) ? item.stones : []
    end

    # A gem's effects come from the armors it names, which the game adds to whoever wears the item.
    #
    # @param gem [RPG::Item] the gem
    # @return [Array<String>] everything the gem gives, without control codes
    def self.gem_bonuses(gem)
      Array(gem.enchant_stone_id).flatten.map { |id| $data_armors[id] }.compact.map { |armor| bonuses(armor) }.flatten.uniq
    end

    # Feature names, by the game's naming method, that Effects leaves out: they show as resists, stats,
    # skill types or boosts, or only mean something on the item that has them.
    NOT_EFFECTS = [:element_rate_name, :state_rate_name, :state_resist_name, :element_drain_name,
                   :param_name, :xparam_name, :xparam_ex_name, :sparam_name,
                   :stype_add_name, :stype_seal_name, :multi_booster_name,
                   :equip_wtype_name, :equip_atype_name, :equip_fix_name, :equip_seal_name,
                   :equip_mastery_name, :collaplse_type_name, :dummy_enchant_name]

    # Lists the element resists an actor has with everything she wears, as the game's status
    # screen shows them.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(Integer, String, String, Symbol)>] the icon, element, resist and its kind
    def self.element_resists(actor)
      extended = $game_switches[NWConst::Sw::ADD_ELEMENT_RESIST]
      ids = extended ? NWConst::Status::ADD_ELEMENT_RESIST : NWConst::Status::ELEMENT_RESIST
      icons = extended ? NWConst::Status::ADD_ELEMENT_ICONS : NWConst::Status::ELEMENT_ICONS

      ids.each_with_index.map do |id, index|
        [icons[index], $data_system.elements[id]] + element_resist(actor, id)
      end
    end

    # @param actor [Game_Actor] the actor
    # @param id [Integer] the element
    # @return [Array(String, Symbol)] the resist as the status screen writes it, and its kind
    def self.element_resist(actor, id)
      return ["REFLECT", :reflect] if actor.element_reflection(id)
      return ["ABSORB", :absorb] if actor.element_drain?(id)

      resist(actor.element_rate(id))
    end

    # Lists the status resists an actor has with everything she wears, as the game's status
    # screen shows them.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(Integer, String, String, Symbol)>] the icon, state, resist and its kind
    def self.state_resists(actor)
      NWConst::Status::STATE_RESIST.map do |id|
        state = $data_states[id]
        [state.icon_index, state.name] + resist(actor.state_resist?(id) ? 0.0 : actor.state_rate(id))
      end
    end

    # @param rate [Float] how much of an element or state gets through, 1.0 being all of it
    # @return [Array(String, Symbol)] the rate as the status screen writes it, and whether it is
    #   :good, :bad, :normal or :null
    def self.resist(rate)
      percent = (rate * 100).to_i
      return ["NULL", :null] if percent == 0

      ["#{percent}%", percent < 100 ? :good : percent > 100 ? :bad : :normal]
    end

    # @param actor [Game_Actor] the actor
    # @return [Array<Array(String, Boolean)>] the skill types she can use, and whether each is sealed
    def self.skill_types(actor)
      actor.added_skill_types.sort.map { |id| [$data_system.skill_types[id], actor.skill_type_sealed?(id)] }
    end

    # Names what an actor's job, race, equipment, abilities and states give her beyond resists, stats
    # and boosts, the way the game names it on equipment. Effects of one kind are combined the way
    # the game combines them; kinds it applies one by one stay apart.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(String, String, String, Integer)>] each effect's category and name, how
    #   its sources were combined, nil for one source, and how many of it apply one by one
    def self.effects(actor)
      objects = actor.feature_objects
      table = namer.enchant_method_table
      codes = table.keys.reject { |code| NOT_EFFECTS.include?(table[code]) }

      codes.map { |code| Combine.effects(objects.features(code)) }.flatten(1)
    end

    # Combines an actor's boosters per element, skill type, weapon type or skill, the way the game
    # combines them for damage, and names the totals like the game names boosters on equipment.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(String, String, String)>] each boost's category and name, and how its
    #   sources were combined, nil for one source
    def self.boosts(actor)
      code = namer.enchant_method_table.key(:multi_booster_name)
      Combine.boosts(code, actor.feature_objects.features(code))
    end

    # @param features [Array<RPG::BaseItem::Feature>] the features
    # @return [Array<String>] their names on equipment, leaving out the ones the game has no name for
    def self.names_of(features)
      features.map do |feature|
        method = namer.enchant_method_table[feature.code]
        begin
          method ? namer.send(method, feature) : nil
        rescue
          nil
        end
      end.flatten.compact.map { |name| name.to_s.strip }.reject(&:empty?)
    end

    # @return [RPG::BaseItem] an item whose methods name features the way the equipment screens do
    def self.namer
      @namer ||= RPG::BaseItem.new
    end

    # @param names [Array<String>] names, some repeated
    # @return [Array<Array(String, Integer)>] each name once with how often it came, in first order
    def self.tally(names)
      counts = Hash.new(0)
      names.each { |name| counts[name] += 1 }
      counts.to_a
    end

    # Lists an actor's equipped abilities by category, in the order of the game's ability screen.
    # Proof Abilities, which only Part 3 has, cost no AP.
    #
    # @param actor [Game_Actor] the actor
    # @return [Array<Array(Integer, String, Array<RPG::Skill>, Array(Integer, Integer))>] each category
    #   she has abilities equipped in: its skill type, name, abilities, and AP used and maximum, nil
    #   for Proof Abilities
    def self.abilities(actor)
      NWConst::Ability::INIT_ABILITY_SKILL_TYPE.map do |id|
        skills = (actor.equip_abilities[id] || []).map { |skill_id| $data_skills[skill_id] }.compact
        next nil if skills.empty?

        ap = NWConst::Ability::ABILITY_SKILL_TYPE.include?(id) ? [actor.ap(id), actor.max_ap(id)] : nil
        [id, $data_system.skill_types[id], skills, ap]
      end.compact
    end

    # @param actor [Game_Actor] the actor
    # @return [Array<String>, nil] the name of her trait followed by its description lines, nil when
    #   she has none
    def self.trait(actor)
      NWConst::Library::ACTOR_FIX_ABILITY[actor.id]
    end

    # @return [String] the name of the map the party is on, "" on a map without one
    def self.location
      $game_map.display_name.to_s
    rescue
      ""
    end

    # Side chosen, by the name in the editor of the switch that records the choice.
    SIDES = { "Ilias Chosen" => :ilias, "Alice Chosen" => :alice }

    # Reads the switches by their names, so no id is hard-coded.
    #
    # @return [Symbol, nil] the side this playthrough chose, :ilias or :alice, nil before the choice
    def self.side
      switch = SIDES.keys.find do |name|
        id = $data_system.switches.index(name)
        id && $game_switches[id]
      end
      SIDES[switch]
    rescue
      nil
    end
  end

  # Combines features of one kind the way the game does in battle, so the sheet shows the value that
  # applies instead of each source's.
  module Combine
    # How the game combines each kind of effect, read from its Game_BattlerBase: the feature code,
    # the module of its data id and the data id, nil for every data id of the code, the rule, and
    # whether its values are counts rather than rates. Kinds left out are applied one by one.
    #
    # Rules: :sum adds up, :product multiplies, :max and :min keep one, :chance combines chances as
    # 1 - (1 - a)(1 - b), :once is a flag that applies once however often it comes, :cost multiplies
    # cost rates per skill type or skill, :tp adds up max SP, :exp keeps the best bonus less the
    # worst cut, :union joins lists of states, :repeat adds up extra strikes.
    RULES = [
      [:FEATURE_DEBUFF_RATE,     nil, nil, :product],
      [:FEATURE_ATK_STATE,       nil, nil, :sum],
      [:FEATURE_ATK_TIMES,       nil, nil, :sum, true],
      [:FEATURE_ATK_SPEED,       nil, nil, :once],
      [:FEATURE_ATK_ELEMENT,     nil, nil, :once],
      [:FEATURE_SLOT_TYPE,       nil, nil, :once],
      [:FEATURE_SPECIAL_FLAG,    nil, nil, :once],
      [:FEATURE_PARTY_ABILITY,   nil, nil, :once],
      [:FEATURE_BLOCK_RATE,      nil, nil, :chance],
      [:FEATURE_TERRAIN_BOOSTER, nil, nil, :max],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :GET_GOLD_RATE,  :max],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :GET_ITEM_RATE,  :max],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :COLLECT_RATE,   :max],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :ENCOUNTER_RATE, :product],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :SLOT_CHANCE,    :once],
      [:FEATURE_PARTY_EX_ABILITY, :PartyEx, :UNLOCK_LEVEL,   :max, true],
      [:FEATURE_BATTLER_ABILITY, :Battler, :STEAL_SUCCESS,       :max],
      [:FEATURE_BATTLER_ABILITY, :Battler, :AUTO_STAND,          :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :HEEL_REVERSE,        :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :AUTO_STATE,          :union],
      [:FEATURE_BATTLER_ABILITY, :Battler, :METAL_BODY,          :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :DEFENSE_WALL,        :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_MP_CONVERT,   :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_GOLD_CONVERT, :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_MP_DRAIN,     :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_GOLD_DRAIN,   :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :STYPE_COST_RATE,     :cost],
      [:FEATURE_BATTLER_ABILITY, :Battler, :SKILL_COST_RATE,     :cost],
      [:FEATURE_BATTLER_ABILITY, :Battler, :TP_COST_RATE,        :product],
      [:FEATURE_BATTLER_ABILITY, :Battler, :HP_COST_RATE,        :product],
      [:FEATURE_BATTLER_ABILITY, :Battler, :GOLD_COST_RATE,      :product],
      [:FEATURE_BATTLER_ABILITY, :Battler, :INCREASE_TP,         :tp],
      [:FEATURE_BATTLER_ABILITY, :Battler, :START_TP_RATE,       :max],
      [:FEATURE_BATTLER_ABILITY, :Battler, :BATTLE_END_HEEL_HP,  :max],
      [:FEATURE_BATTLER_ABILITY, :Battler, :BATTLE_END_HEEL_MP,  :max],
      [:FEATURE_BATTLER_ABILITY, :Battler, :CERTAIN_COUNTER,     :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :MAGICAL_COUNTER,     :chance],
      [:FEATURE_BATTLER_ABILITY, :Battler, :PHYSICAL_REFLECTION, :chance],
      [:FEATURE_BATTLER_ABILITY, :Battler, :CONSIDERATE,         :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :GET_EXP_RATE,        :exp],
      [:FEATURE_BATTLER_ABILITY, :Battler, :GET_CLASSEXP_RATE,   :exp],
      [:FEATURE_BATTLER_ABILITY, :Battler, :INVOKE_REPEATS_TYPE, :repeat],
      [:FEATURE_BATTLER_ABILITY, :Battler, :INVOKE_REPEATS_SKILL, :repeat],
      [:FEATURE_BATTLER_ABILITY, :Battler, :OWN_CRUSH_RESIST,    :once],
      [:FEATURE_BATTLER_ABILITY, :Battler, :IGNORE_OVER_DRIVE,   :once],
    ]

    # How the game combines each kind of booster, by its data id's name. Boosters by element, skill
    # type, weapon type or skill are added up per key; kinds left out are applied one by one.
    BOOSTERS = {
      :ELEMENT => :sum, :WEAPON_PHYSICAL => :sum, :WEAPON_MAGICAL => :sum, :WEAPON_CERTAIN => :sum,
      :STATE_RATIO_TYPE => :sum, :STATE_FIX_TYPE => :sum, :SKILL_TYPE => :sum,
      :STATE_RATIO_SKILL => :sum, :SKILL => :sum, :WTYPE_SKILL => :sum,
      :CRITICAL => :sum, :COUNTER => :max, :OVER_SOUL => :max, :FALL_HP => :once,
    }

    # Boosters whose value holds a rate per element, skill type, weapon type or skill.
    KEYED_BOOSTERS = [:ELEMENT, :WEAPON_PHYSICAL, :WEAPON_MAGICAL, :WEAPON_CERTAIN, :STATE_RATIO_TYPE,
                      :STATE_FIX_TYPE, :SKILL_TYPE, :STATE_RATIO_SKILL, :SKILL, :WTYPE_SKILL]

    # Categories the effects are sorted into, by their feature code, the module of their data id and
    # the data id, nil for every data id of the code. Costs per skill type or skill go by the
    # resource they cost, see COST_CATEGORIES; effects left out go to Other.
    CATEGORIES = [
      ["Strikes",      :FEATURE_ATK_ELEMENT,     nil,      nil],
      ["Strikes",      :FEATURE_ATK_STATE,       nil,      nil],
      ["Strikes",      :FEATURE_ATK_TIMES,       nil,      nil],
      ["Strikes",      :FEATURE_ATK_SPEED,       nil,      nil],
      ["Strikes",      :FEATURE_BATTLER_ABILITY, :Battler, :NORMAL_ATTACK],
      ["Strikes",      :FEATURE_BATTLER_ABILITY, :Battler, :INVOKE_REPEATS_TYPE],
      ["Strikes",      :FEATURE_BATTLER_ABILITY, :Battler, :INVOKE_REPEATS_SKILL],
      ["Wielding",     :FEATURE_SLOT_TYPE,       nil,      nil],
      ["SP",           :FEATURE_BATTLER_ABILITY, :Battler, :TP_COST_RATE],
      ["SP",           :FEATURE_BATTLER_ABILITY, :Battler, :INCREASE_TP],
      ["SP",           :FEATURE_BATTLER_ABILITY, :Battler, :START_TP_RATE],
      ["SP",           :FEATURE_SPECIAL_FLAG,    nil,      :PRESERVE_TP],
      ["MP",           :FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_MP_CONVERT],
      ["MP",           :FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_MP_DRAIN],
      ["HP",           :FEATURE_BATTLER_ABILITY, :Battler, :HP_COST_RATE],
      ["HP",           :FEATURE_BATTLER_ABILITY, :Battler, :HEEL_REVERSE],
      ["HP",           :FEATURE_BATTLER_ABILITY, :Battler, :TRIGGER_STATE],
      ["Gold",         :FEATURE_BATTLER_ABILITY, :Battler, :GOLD_COST_RATE],
      ["Gold",         :FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_GOLD_CONVERT],
      ["Gold",         :FEATURE_BATTLER_ABILITY, :Battler, :DAMAGE_GOLD_DRAIN],
      ["Defense",      :FEATURE_BLOCK_RATE,      nil,      nil],
      ["Defense",      :FEATURE_DEBUFF_RATE,     nil,      nil],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :PHYSICAL_REFLECTION],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :AUTO_STAND],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :METAL_BODY],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :DEFENSE_WALL],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :INVALIDATE_WALL],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :OWN_CRUSH_RESIST],
      ["Defense",      :FEATURE_BATTLER_ABILITY, :Battler, :IGNORE_OVER_DRIVE],
      ["Defense",      :FEATURE_SPECIAL_FLAG,    nil,      :GUARD],
      ["Defense",      :FEATURE_SPECIAL_FLAG,    nil,      :SUBSTITUTE],
      ["Counters",     :FEATURE_BATTLER_ABILITY, :Battler, :CERTAIN_COUNTER],
      ["Counters",     :FEATURE_BATTLER_ABILITY, :Battler, :MAGICAL_COUNTER],
      ["Counters",     :FEATURE_BATTLER_ABILITY, :Battler, :CONSIDERATE],
      ["Battle Start", :FEATURE_BATTLER_ABILITY, :Battler, :AUTO_STATE],
      ["Battle Start", :FEATURE_BATTLER_ABILITY, :Battler, :BATTLE_START_SKILL],
      ["Turn",         :FEATURE_BATTLER_ABILITY, :Battler, :TURN_START_SKILL],
      ["Turn",         :FEATURE_BATTLER_ABILITY, :Battler, :TURN_END_SKILL],
      ["Turn",         :FEATURE_ACTION_PLUS,     nil,      nil],
      ["Defeat",       :FEATURE_BATTLER_ABILITY, :Battler, :DEAD_SKILL],
      ["Defeat",       :FEATURE_BATTLER_ABILITY, :Battler, :FINAL_INVOKE],
      ["After Battle", :FEATURE_BATTLER_ABILITY, :Battler, :BATTLE_END_HEEL_HP],
      ["After Battle", :FEATURE_BATTLER_ABILITY, :Battler, :BATTLE_END_HEEL_MP],
      ["After Battle", :FEATURE_BATTLER_ABILITY, :Battler, :GET_EXP_RATE],
      ["After Battle", :FEATURE_BATTLER_ABILITY, :Battler, :GET_CLASSEXP_RATE],
      ["After Battle", :FEATURE_BATTLER_ABILITY, :Battler, :STEAL_SUCCESS],
      ["Party",        :FEATURE_PARTY_ABILITY,   nil,      nil],
      ["Party",        :FEATURE_PARTY_EX_ABILITY, nil,     nil],
    ]

    # Order of the effect categories on the sheet.
    CATEGORY_ORDER = ["Strikes", "Wielding", "SP", "MP", "HP", "Gold", "Defense", "Counters",
                      "Battle Start", "Turn", "Defeat", "After Battle", "Party", "Other"]

    # Category of a cost per skill type or skill, by the resource it costs as the game names it.
    COST_CATEGORIES = { "TP" => "SP", "MP" => "MP", "HP" => "HP", "GOLD" => "Gold" }

    # Category of each kind of booster, by its data id's name. Kinds left out go to Other.
    BOOST_CATEGORIES = {
      :ELEMENT => "Element",
      :SKILL_TYPE => "Skill Type", :STATE_RATIO_TYPE => "Skill Type", :STATE_FIX_TYPE => "Skill Type",
      :WEAPON_PHYSICAL => "Weapon", :WEAPON_MAGICAL => "Weapon", :WEAPON_CERTAIN => "Weapon", :WTYPE_SKILL => "Weapon",
      :SKILL => "Skill", :STATE_RATIO_SKILL => "Skill",
      :CRITICAL => "Critical & Counter", :COUNTER => "Critical & Counter", :OVER_SOUL => "Critical & Counter",
    }

    # Order of the booster categories on the sheet.
    BOOST_ORDER = ["Element", "Skill Type", "Weapon", "Skill", "Critical & Counter", "Other"]

    # How each rule reads in a tooltip.
    WORDS = {
      :sum => "added up", :product => "multiplied", :max => "the highest counts", :min => "the lowest counts",
      :chance => "chances combined", :cost => "multiplied, never below 1%", :tp => "added up",
      :exp => "the best bonus less the worst cut",
    }

    # @param features [Array<RPG::BaseItem::Feature>] features of one code, from every source
    # @return [Array<Array(String, String, String, Integer)>] each effect's category and name, how
    #   its sources were combined, nil for one source, and how many of it apply one by one
    def self.effects(features)
      features.group_by { |feature| key(feature) }.map do |_, group|
        rule, count = rule_for(group.first)
        category = category_for(group.first)
        (rule ? combined(group, rule, count) : apart(group)).map { |entry| [category] + entry }
      end.flatten(1)
    end

    # @param code [Integer] the booster feature code
    # @param features [Array<RPG::BaseItem::Feature>] the boosters, from every source
    # @return [Array<Array(String, String, String)>] each boost's category and name, and how its
    #   sources were combined, nil for one source
    def self.boosts(code, features)
      features.group_by(&:data_id).map do |id, group|
        name = booster_names[id]
        rule = BOOSTERS[name]
        category = BOOST_CATEGORIES.fetch(name, "Other")

        entries = if rule.nil?
                    apart(group)
                  elsif rule == :once
                    Party.names_of([group.first]).map { |label| [label, nil] }
                  elsif KEYED_BOOSTERS.include?(name)
                    parts = {}
                    group.each { |feature| feature.value.each { |part, value| (parts[part] ||= []) << value } }
                    parts.map { |part, values| named(code, id, { part => total(rule, values) }, rule, values) }.flatten(1)
                  else
                    named(code, id, total(rule, group.map(&:value)), rule, group.map(&:value))
                  end
        entries.map { |label, formula, _| [category, label, formula] }
      end.flatten(1)
    end

    # @param feature [RPG::BaseItem::Feature] the feature
    # @return [String] the category its effect is sorted into
    def self.category_for(feature)
      rule, _ = rule_for(feature)
      return COST_CATEGORIES.fetch(feature.value[:type].to_s.upcase, "Other") if rule == :cost

      categories[[feature.code, feature.data_id]] || categories[feature.code] || "Other"
    end

    # CATEGORIES with its names looked up, once. A name the game lacks leaves its entry out.
    #
    # @return [Hash{Array(Integer, Integer), Integer => String}] the categories by code and data id,
    #   or by code alone
    def self.categories
      @categories ||= CATEGORIES.each_with_object({}) do |(category, code, scope, id), categories|
        code = constant(nil, code)
        next unless code

        if id
          id = constant(scope, id)
          categories[[code, id]] = category if id
        else
          categories[code] = category
        end
      end
    end

    # Combines a group of features of one kind by its rule.
    #
    # @param group [Array<RPG::BaseItem::Feature>] the features
    # @param rule [Symbol] the rule, see RULES
    # @param count [Boolean] whether the values are counts rather than rates
    # @return [Array<Array(String, String, Integer)>] the effects' names, formulas and 1
    def self.combined(group, rule, count)
      first = group.first
      case rule
      when :once
        Party.names_of([first]).map { |label| [label, nil, 1] }
      when :union
        named(first.code, first.data_id, group.map(&:value).flatten.uniq, nil, [])
      when :repeat
        strikes = {}
        group.each { |feature| feature.value.each { |part, times| strikes[part] = (strikes[part] || 1) + times - 1 } }
        named(first.code, first.data_id, strikes, nil, [])
      when :cost
        rates = group.map { |feature| feature.value[:rate] }
        named(first.code, first.data_id, first.value.merge(:rate => total(:cost, rates)), :cost, rates)
      when :tp
        amounts = group.map { |feature| feature.value[:plus] ? feature.value[:num] : -feature.value[:num] }
        sum = amounts.inject(0) { |all, amount| all + amount }
        value = first.value.merge(:plus => sum >= 0, :num => sum.abs)
        formula = group.size > 1 ? "#{sources(group.size, :tp)}\n#{amounts.map { |amount| signed(amount) }.join(' ')} = #{signed(sum)}" : nil
        Party.names_of([RPG::BaseItem::Feature.new(first.code, first.data_id, value)]).map { |label| [label, formula, 1] }
      else
        values = group.map(&:value)
        named(first.code, first.data_id, total(rule, values), rule, values, count)
      end
    end

    # Names features the game applies one by one, counting the ones that repeat.
    #
    # @param group [Array<RPG::BaseItem::Feature>] the features
    # @return [Array<Array(String, nil, Integer)>] each name once, with how often it came
    def self.apart(group)
      Party.tally(Party.names_of(group)).map { |label, times| [label, nil, times] }
    end

    # Names a combined value, with the formula that led to it.
    #
    # @param code [Integer] the feature code
    # @param id [Integer] the feature's data id
    # @param value [Object] the combined value
    # @param rule [Symbol, nil] the rule, nil when the formula would show nothing new
    # @param values [Array<Numeric>] the values that were combined
    # @param count [Boolean] whether the values are counts rather than rates
    # @return [Array<Array(String, String, Integer)>] the names, the formula, nil for one value, and 1
    def self.named(code, id, value, rule, values, count = false)
      formula = rule && values.size > 1 ? formula(rule, values, count) : nil
      Party.names_of([RPG::BaseItem::Feature.new(code, id, value)]).map { |label| [label, formula, 1] }
    end

    # @param rule [Symbol] the rule
    # @param values [Array<Numeric>] the values
    # @return [Numeric] the values combined by the rule
    def self.total(rule, values)
      case rule
      when :sum     then values.inject { |all, value| all + value }
      when :product then values.inject(1.0) { |all, value| all * value }
      when :cost    then [values.inject(1.0) { |all, value| all * value }, 0.01].max
      when :max     then values.max
      when :min     then values.min
      when :chance  then 1.0 - values.inject(1.0) { |all, value| all * (1.0 - value) }
      when :exp
        lowest = ([1.0] + values).min
        lowest <= 0.0 ? 0.0 : [values.max, 1.0].max - (1.0 - lowest)
      end
    end

    # @param rule [Symbol] the rule
    # @param values [Array<Numeric>] the values that were combined
    # @param count [Boolean] whether the values are counts rather than rates
    # @return [String] how many sources there were, how they combine, and the sum that shows it
    def self.formula(rule, values, count = false)
      parts = values.map { |value| amount(value, count) }
      result = amount(total(rule, values), count)
      sum = case rule
            when :sum             then "#{parts.join(' + ')} = #{result}"
            when :product, :cost  then "#{parts.join(' × ')} = #{result}"
            when :max             then "highest of #{parts.join(', ')} = #{result}"
            when :min             then "lowest of #{parts.join(', ')} = #{result}"
            when :chance          then "1 − #{parts.map { |part| "(1 − #{part})" }.join} = #{result}"
            when :exp             then "best bonus and worst cut of #{parts.join(', ')} = #{result}"
            end
      "#{sources(values.size, rule)}\n#{sum}"
    end

    # @param number [Integer] how many sources there were
    # @param rule [Symbol] the rule
    # @return [String] the tooltip's first line
    def self.sources(number, rule)
      "From #{number} sources, #{WORDS[rule]}:"
    end

    # @param value [Numeric] a rate, 1.0 being 100%, or a count
    # @param count [Boolean] whether the value is a count
    # @return [String] the value as the tooltip shows it
    def self.amount(value, count = false)
      count ? value.to_s.sub(/\.0\z/, "") : "#{(value * 100).round}%"
    end

    # @param amount [Integer] a change to max SP
    # @return [String] the change with its sign
    def self.signed(amount)
      amount < 0 ? "−#{-amount}" : "+#{amount}"
    end

    # Groups features that combine: of one code and data id, and for cost rates of one kind of cost
    # and skill type or skill, for max SP of fixed or percent changes.
    #
    # @param feature [RPG::BaseItem::Feature] the feature
    # @return [Array] its group
    def self.key(feature)
      rule, _ = rule_for(feature)
      value = feature.value
      extra = case rule
              when :cost then [value[:type], value[:id]]
              when :tp   then [value[:per]]
              else []
              end
      [feature.code, feature.data_id] + extra
    end

    # @param feature [RPG::BaseItem::Feature] the feature
    # @return [Array(Symbol, Boolean), nil] the rule and whether its values are counts, nil when the
    #   game applies the feature one by one
    def self.rule_for(feature)
      rules[[feature.code, feature.data_id]] || rules[feature.code]
    end

    # RULES with its names looked up, once. A name the game lacks leaves its rule out.
    #
    # @return [Hash{Array(Integer, Integer), Integer => Array(Symbol, Boolean)}] the rules by code
    #   and data id, or by code alone
    def self.rules
      @rules ||= RULES.each_with_object({}) do |(code, scope, id, rule, count), rules|
        code = constant(nil, code)
        next unless code

        if id
          id = constant(scope, id)
          rules[[code, id]] = [rule, count] if id
        else
          rules[code] = [rule, count]
        end
      end
    end

    # @return [Hash{Integer => Symbol}] the booster data ids by their names, once
    def self.booster_names
      @booster_names ||= BOOSTERS.keys.each_with_object({}) do |name, names|
        id = constant(:Booster, name)
        names[id] = name if id
      end
    end

    # Looks up a constant where the game's own naming methods find it: in its module when that is
    # reachable from RPG::BaseItem, else unqualified, as those methods mostly name it.
    #
    # @param scope [Symbol, nil] the module inside NWFeature that holds it, nil for none
    # @param name [Symbol] the constant
    # @return [Integer, nil] its value, nil when the game has none of that name
    def self.constant(scope, name)
      begin
        return RPG::BaseItem.const_get(scope).const_get(name) if scope
      rescue NameError
      end
      RPG::BaseItem.const_get(name)
    rescue NameError
      nil
    end
  end

  # The src of the page's images, embedded as data URIs or linked from the game folder.
  module Images
    # Size of a face in Graphics/Faces, and faces per row of a face sheet.
    FACE_SIZE = 96
    FACES_PER_ROW = 4

    # Size of an icon in Graphics/System/IconSet.png, and icons per row.
    ICON_SIZE = 24
    ICONS_PER_ROW = 16

    # Icon of an empty socket, as the game's equipment windows draw it.
    EMPTY_SOCKET_ICON = 3471

    # Media types by the extensions a picture may have.
    MEDIA_TYPES = { ".png" => "image/png", ".jpg" => "image/jpeg" }

    # Shows a loose image as it is.
    #
    # @param file [String] the image, relative to the game folder
    # @return [String] the src that shows it
    def self.file(file)
      return Text.url(file) unless EMBED_IMAGES

      data = File.open(MGQ_PartySheet.path(file), "rb") { |stream| stream.read }
      data_uri(MEDIA_TYPES[File.extname(file).downcase], data)
    end

    # Cuts a face out of its sheet, loaded through the game so a packed Game.rgss3a works too.
    #
    # @param name [String] the face sheet in Graphics/Faces
    # @param index [Integer] the face on the sheet
    # @return [String] the src that shows it, embedded
    def self.face(name, index)
      @faces ||= {}
      @faces[[name, index]] ||= cell(Cache.face(name), index, FACE_SIZE, FACES_PER_ROW)
    end

    # Cuts an icon out of the icon sheet, loaded through the game so a packed Game.rgss3a works too.
    #
    # Embedding the whole sheet would add about 3 MB for a few dozen icons.
    #
    # @param index [Integer] the icon
    # @return [String] the src that shows it, embedded
    def self.icon(index)
      @icons ||= {}
      @icons[index] ||= cell(Cache.system("Iconset"), index, ICON_SIZE, ICONS_PER_ROW)
    end

    # @param sheet [Bitmap] a sheet of equally sized cells
    # @param index [Integer] the cell, counted row by row
    # @param size [Integer] the width and height of a cell in pixels
    # @param per_row [Integer] the cells per row
    # @return [String] a data URI of the cell as a PNG
    def self.cell(sheet, index, size, per_row)
      png = Png.encode(sheet, index % per_row * size, index / per_row * size, size, size)
      data_uri("image/png", png)
    end

    # @param media_type [String] the image's media type
    # @param data [String] the image's bytes
    # @return [String] a data URI of the image
    def self.data_uri(media_type, data)
      "data:#{media_type};base64,#{[data].pack('m').delete("\n")}"
    end
  end

  # Writes part of a Bitmap as a PNG, as RGSS3 has no way to save one.
  #
  # Reading pixel by pixel is slow, so it suits faces and icons, not the Library's pictures.
  module Png
    # Bytes every PNG starts with.
    SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

    # IHDR fields after the size: 8 bits per channel, RGBA, deflate, no filter, no interlace.
    FORMAT = [8, 6, 0, 0, 0]

    # @param bitmap [Bitmap] the image to cut from
    # @param x [Integer] left edge of the part
    # @param y [Integer] top edge of the part
    # @param width [Integer] width of the part
    # @param height [Integer] height of the part
    # @return [String] the PNG's bytes
    def self.encode(bitmap, x, y, width, height)
      rows = (y...y + height).map do |row|
        channels = (x...x + width).map do |column|
          color = bitmap.get_pixel(column, row)
          [color.red, color.green, color.blue, color.alpha]
        end
        ([0] + channels.flatten.map(&:to_i)).pack("C*")
      end

      SIGNATURE +
        chunk("IHDR", ([width, height] + FORMAT).pack("N2C5")) +
        chunk("IDAT", Zlib::Deflate.deflate(rows.join)) +
        chunk("IEND", "")
    end

    # @param type [String] the chunk's four letter type
    # @param data [String] the chunk's bytes
    # @return [String] the chunk with its length and checksum
    def self.chunk(type, data)
      [data.bytesize, type, data, Zlib.crc32(type + data)].pack("NA4A*N")
    end
  end

  # Converts the page's portraits to WebP and takes the image of the Frontline, with a browser that
  # runs without a window. A PowerShell script drives the browser, so the game does not wait for it.
  module Browser
    # Browsers that can do both, relative to the folders programs are installed in. The first one
    # found is used.
    BROWSERS = ["Microsoft/Edge/Application/msedge.exe", "Google/Chrome/Application/chrome.exe"]

    # Folder inside the user's temporary folder that holds the pages, the script and the browser's
    # profile. A profile of its own keeps an open browser window out of the way.
    WORK_DIR = "MGQ Party Sheet"

    # Copy of the page that converts its own portraits, inside WORK_DIR.
    CONVERT_FILE = "Convert.html"

    # Page the image is taken of, inside WORK_DIR.
    FRONTLINE_FILE = "Frontline.html"

    # Script that drives the browser, inside WORK_DIR.
    SCRIPT_FILE = "Browser.ps1"

    # Replaces each portrait with its WebP, once the page has loaded, unless the WebP comes out
    # larger. The script then takes itself out, puts back the page's policy and marks the body, so
    # the page the browser dumps is the page without it.
    CONVERT_SCRIPT = "<script id=\"convert\">window.addEventListener('load',function(){" \
                     "[].forEach.call(document.querySelectorAll('.portrait img'),function(img){try{" \
                     "var canvas=document.createElement('canvas');canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;" \
                     "canvas.getContext('2d').drawImage(img,0,0);var webp=canvas.toDataURL('image/webp',%s);" \
                     "if(webp.indexOf('data:image/webp')===0&&webp.length<img.src.length)img.src=webp;}catch(e){}});" \
                     "var script=document.getElementById('convert');script.parentNode.removeChild(script);" \
                     "document.querySelector('meta[http-equiv]').setAttribute('content',\"%s\");" \
                     "document.body.setAttribute('data-converted','1');});</script>"

    # Converts the page: the browser loads the converting copy and dumps it once the portraits are
    # WebP, which then replaces the page. The dump joins the html and head tags and leaves blank
    # lines where CONVERT_SCRIPT was, which the script mends. Takes the image: the browser measures
    # the Frontline, which its page reports on its body, then takes a screenshot at exactly that
    # size, as a screenshot holds the browser's window and no more.
    SCRIPT = <<-'PS1'
param([string]$Browser, [string]$UserData, [string]$Log, [string]$Convert, [string]$Page, [string]$Frontline, [string]$Image)
$common = @('--headless', '--disable-gpu', '--no-first-run', '--hide-scrollbars', "--user-data-dir=$UserData")
if ($Convert) {
  try {
    $arguments = "--headless --disable-gpu --no-first-run `"--user-data-dir=$UserData`" --dump-dom `"$(([Uri]$Convert).AbsoluteUri)`""
    Start-Process -FilePath $Browser -ArgumentList $arguments -RedirectStandardOutput "$Convert.out" -RedirectStandardError "$Convert.err" -WindowStyle Hidden -Wait
    $html = [IO.File]::ReadAllText("$Convert.out", [Text.Encoding]::UTF8)
    if ($html -notmatch 'data-converted="1"') { throw 'the browser did not convert the portraits' }
    $html = $html.Replace(' data-converted="1"', '')
    $html = $html -replace '<html([^>]*)><head>', ('<html$1>' + "`n  <head>")
    $html = $html -replace '\s*</body>\s*</html>\s*$', "`n  </body>`n</html>`n"
    if (-not $html.StartsWith('<!DOCTYPE')) { $html = "<!DOCTYPE html>`n$html" }
    [IO.File]::WriteAllText("$Page.tmp", $html, (New-Object Text.UTF8Encoding $false))
    Move-Item -LiteralPath "$Page.tmp" -Destination $Page -Force
  } catch {
    Add-Content -LiteralPath $Log -Value "$(Get-Date)  portraits not converted: $_"
  }
}
if ($Frontline) {
  try {
    $url = ([Uri]$Frontline).AbsoluteUri
    $dom = & $Browser @common '--window-size=4000,3000' '--dump-dom' $url | Out-String
    if ($dom -notmatch 'data-size="(\d+)x(\d+)"') { throw 'the page reported no size' }
    & $Browser @common "--window-size=$($Matches[1]),$($Matches[2])" "--screenshot=$Image" $url | Out-Null
  } catch {
    Add-Content -LiteralPath $Log -Value "$(Get-Date)  image failed: $_"
  }
}
    PS1

    # Writes what the browser needs and starts the script.
    #
    # @param page [String, nil] the page just written, nil when none was
    # @param image [Boolean] whether to take the image of the Frontline
    def self.run(page, image)
      convert = page && EMBED_IMAGES && PORTRAIT_QUALITY
      return unless convert || image

      unless browser
        MGQ_PartySheet.log("no Microsoft Edge or Google Chrome found to convert the portraits or take #{IMAGE_FILE}")
        return
      end

      Dir.mkdir(work_path("")) unless File.directory?(work_path(""))
      File.open(work_path(CONVERT_FILE), "wb") { |file| file.write(converting(page)) } if convert
      File.open(work_path(FRONTLINE_FILE), "wb") { |file| file.write(Page.frontline(base)) } if image
      File.open(work_path(SCRIPT_FILE), "wb") { |file| file.write(SCRIPT) }

      result = shell_execute.call(0, "open", "powershell.exe", arguments(convert, image), windows_path(MGQ_PartySheet.game_dir), 0)
      MGQ_PartySheet.log("could not start PowerShell: error #{result}") if result <= 32
    end

    # The page's policy forbids scripts, so the copy allows inline ones until CONVERT_SCRIPT puts
    # the policy back.
    #
    # @param page [String] the page
    # @return [String] the page with CONVERT_SCRIPT at the end of its body
    def self.converting(page)
      script = format(CONVERT_SCRIPT, PORTRAIT_QUALITY, Page::POLICY)
      page.sub(Page::POLICY, "#{Page::POLICY}; script-src 'unsafe-inline'").sub("</body>", "#{script}</body>")
    end

    # @param convert [Boolean] whether to convert the page's portraits
    # @param image [Boolean] whether to take the image of the Frontline
    # @return [String] PowerShell's command line, running the script
    def self.arguments(convert, image)
      arguments = ["-NoProfile", "-NonInteractive", "-ExecutionPolicy Bypass", "-WindowStyle Hidden",
                   "-File #{quoted(work_path(SCRIPT_FILE))}",
                   "-Browser #{quoted(browser)}",
                   "-UserData #{quoted(work_path('Browser'))}",
                   "-Log #{quoted(MGQ_PartySheet.path(LOG_FILE))}"]
      arguments += ["-Convert #{quoted(work_path(CONVERT_FILE))}", "-Page #{quoted(MGQ_PartySheet.path(FILE))}"] if convert
      arguments += ["-Frontline #{quoted(work_path(FRONTLINE_FILE))}", "-Image #{quoted(MGQ_PartySheet.path(IMAGE_FILE))}"] if image
      arguments.join(" ")
    end

    # The image's page lies in the temporary folder, so linked images need the game folder as base.
    #
    # @return [String, nil] the base address of the image's page, nil while the images are embedded
    def self.base
      EMBED_IMAGES ? nil : "file:///#{Text.url(MGQ_PartySheet.game_dir)}/"
    end

    # @param name [String] a file name inside WORK_DIR, "" for the folder itself
    # @return [String] its full path
    def self.work_path(name)
      "#{ENV['TEMP'].tr("\\", "/")}/#{WORK_DIR}/#{name}".chomp("/")
    end

    # @param path [String] a path with forward slashes
    # @return [String] the path with backslashes, in quotes, as a command line expects it
    def self.quoted(path)
      "\"#{windows_path(path)}\""
    end

    # Finds the browser, once per session.
    #
    # The game runs as a 32-bit program, for which ProgramFiles names the 32-bit folder, so the
    # 64-bit one is asked for by ProgramW6432.
    #
    # @return [String, nil] the browser's path, nil when none is installed
    def self.browser
      return @browser if @searched

      @searched = true
      folders = ["ProgramFiles(x86)", "ProgramW6432", "ProgramFiles", "LOCALAPPDATA"].map { |name| ENV[name] }.compact
      @browser = BROWSERS.map { |program| folders.map { |folder| "#{folder}/#{program}" } }.flatten
                         .find { |path| File.exist?(path) }
    end

    # @param path [String] a path with forward slashes
    # @return [String] the path with backslashes, as a command line expects it
    def self.windows_path(path)
      path.tr("/", "\\")
    end

    # @return [Win32API] ShellExecuteA, which starts a program without waiting for it
    def self.shell_execute
      @shell_execute ||= Win32API.new('shell32', 'ShellExecuteA', 'lppppl', 'l')
    end
  end

  # Writes the page like hand-written code: an element per line, indented by how deep it sits, and
  # its CSS a declaration per line.
  #
  # Only whitespace between elements changes, which the browser ignores next to blocks and between
  # grid and flex items, so the page looks the same.
  module Pretty
    # One step of indentation.
    INDENT = "  "

    # Elements that take lines of their own. The others stay on their neighbours' line, where the
    # line break would show as a space.
    BLOCKS = %w(doctype html head body meta base title style header footer section article div ul li dl dt dd
                details summary h1 h2 h3 h4 p)

    # Elements without content or closing tag.
    VOIDS = %w(doctype meta base img br)

    # A CSS declaration, whose parentheses may hold semicolons, like a data URI's.
    DECLARATION = /(?:[^;(]+|\([^)]*\))+/

    # @param html [String] the page as built
    # @return [String] the page indented
    def self.html(html)
      lines = []
      add_nodes(tree(html), 0, lines)
      lines.join("\n") + "\n"
    end

    # Reads the page into nested elements. It relies on the page being well-formed, which it is
    # as Page escapes every game text.
    #
    # @param html [String] the page
    # @return [Array<Array(String, String, Array), String>] the top elements and text, each element
    #   being its name, its opening tag and its content
    def self.tree(html)
      root = [nil, nil, []]
      open = [root]
      html.scan(/<[^>]*>|[^<]+/) do |token|
        if token.start_with?("</")
          open.pop if open.size > 1
        elsif token.start_with?("<")
          node = [token[/\A<!?(\w+)/, 1].downcase, token, []]
          open.last[2] << node
          open << node unless VOIDS.include?(node[0])
        else
          open.last[2] << token
        end
      end
      root[2]
    end

    # Adds a line per block, and one per run of inline elements and text between blocks.
    #
    # @param nodes [Array<Array, String>] elements and text, in order
    # @param depth [Integer] how deep they sit
    # @param lines [Array<String>] the lines so far
    def self.add_nodes(nodes, depth, lines)
      run = []
      (nodes + [nil]).each do |node|
        if node.nil? || block?(node)
          text = run.map { |part| inline(part) }.join.strip
          lines << INDENT * depth + text unless text.empty?
          run = []
          add_element(node, depth, lines) if node
        else
          run << node
        end
      end
    end

    # Adds a block: on one line when it holds only inline content, its content indented between
    # its tags otherwise.
    #
    # @param node [Array(String, String, Array)] the element
    # @param depth [Integer] how deep it sits
    # @param lines [Array<String>] the lines so far
    def self.add_element(node, depth, lines)
      name, tag, children = node
      pad = INDENT * depth

      if VOIDS.include?(name)
        lines << pad + tag
      elsif name == "style"
        lines << pad + tag
        add_css(children.join, depth + 1, lines)
        lines << "#{pad}</style>"
      elsif children.any? { |child| block?(child) }
        lines << pad + tag
        add_nodes(children, depth + 1, lines)
        lines << "#{pad}</#{name}>"
      else
        lines << pad + inline(node)
      end
    end

    # @param css [String] a style sheet, or the rules inside an at-rule like @media
    # @param depth [Integer] how deep the rules sit
    # @param lines [Array<String>] the lines so far
    def self.add_css(css, depth, lines)
      pad = INDENT * depth
      rules(css).each do |prelude, body|
        lines << "#{pad}#{prelude} {"
        if body.include?("{")
          add_css(body, depth + 1, lines)
        else
          body.scan(DECLARATION) do |declaration|
            property, value = declaration.split(":", 2)
            lines << "#{pad}#{INDENT}#{property.strip}: #{value.strip};" if value
          end
        end
        lines << "#{pad}}"
      end
    end

    # @param css [String] a style sheet, or the rules inside an at-rule
    # @return [Array<Array(String, String)>] each rule's selector or at-rule, and what its braces hold
    def self.rules(css)
      rules = []
      depth = 0
      from = 0
      opened = 0
      css.scan(/[{}]/) do |brace|
        at = $~.begin(0)
        if brace == "{"
          opened = at if depth == 0
          depth += 1
        else
          depth -= 1
          next unless depth == 0

          rules << [css[from...opened].strip, css[opened + 1...at]]
          from = at + 1
        end
      end
      rules
    end

    # @param node [Array, String] an element or text
    # @return [Boolean] whether it takes lines of its own
    def self.block?(node)
      node.is_a?(Array) && BLOCKS.include?(node[0])
    end

    # @param node [Array, String] an element or text
    # @return [String] its HTML as it was built
    def self.inline(node)
      return node if node.is_a?(String)

      name, tag, children = node
      VOIDS.include?(name) ? tag : "#{tag}#{children.map { |child| inline(child) }.join}</#{name}>"
    end
  end

  # The HTML of the page.
  module Page
    # Lets the page show its own styles and images and nothing else: no script runs and nothing
    # loads from the internet, whatever the page holds.
    POLICY = "default-src 'none'; style-src 'unsafe-inline'; img-src data:#{EMBED_IMAGES ? '' : ' file:'}; " \
             "base-uri 'none'; form-action 'none'"
    # Stats shown as tiles, by the method that reads them and their name on the status screen.
    STATS = [[:mhp, "Max HP"], [:mmp, "Max MP"], [:atk, "Attack"], [:def, "Defense"],
             [:mat, "Magic"], [:mdf, "Willpower"], [:agi, "Agility"], [:luk, "Dexterity"]]

    # Rates shown below the tiles, by the method that reads them and their name on the status screen.
    RATES = [[:hit, "Hit Rate"], [:cri, "Critical Rate"],
             [:magical_critical, "Magic Critical Rate"], [:booster_critical, "Critical Damage"],
             [:eva, "Evasion Rate"], [:mev, "Magic Evasion Rate"],
             [:certain_evasion, "Auto-Hit Evasion Rate"], [:cnt, "Counter Rate"],
             [:magical_counter, "Magic Counter Rate"], [:certain_counter, "Auto-Hit Counter Rate"]]

    # Colours of the page for Alice: dark and purple.
    DARK = <<-'CSS'
:root{color-scheme:dark;--bg:#120e17;--card:#1c1624;--tile:#241c2e;--line:#34293f;--text:#efe9f6;--muted:#a597b5;--gold:#e9c46a;--rose:#e58fb3;
--glow:#2a1d3a;--halo:#3b2a52;--shade:rgba(18,14,23,.94);--name-shadow:0 2px 6px #000;--chip:#2b2137;--chip-text:#cdbfe0;
--trait:linear-gradient(135deg,#2a1f35,#221a2b);--trait-text:#d8cde6;--tip:rgba(13,10,18,.85);--shadow:rgba(0,0,0,.35);--tip-shadow:rgba(0,0,0,.5);
--good:#86d4a3;--bad:#ef8f8f;--reflect:#8ec5ff;--absorb:#c79bff}
    CSS

    # Colours of the page for Ilias: white and gold. The ability colours are darkened, as the
    # yellow ones vanish on white.
    LIGHT = <<-'CSS'
:root{color-scheme:light;--bg:#f7f2e6;--card:#fffdf8;--tile:#f4ecda;--line:#e2d3b1;--text:#2b2418;--muted:#75674c;--gold:#94700f;--rose:#a8566f;
--glow:#fff3cf;--halo:#fbecc0;--shade:rgba(255,253,248,.94);--name-shadow:0 1px 4px #fff;--chip:#efe4cb;--chip-text:#5a4d33;
--trait:linear-gradient(135deg,#fbf2da,#f6ead0);--trait-text:#4d4330;--tip:rgba(255,253,248,.92);--shadow:rgba(120,95,40,.15);--tip-shadow:rgba(120,95,40,.25);
--good:#2d8049;--bad:#c0392b;--reflect:#2a6db5;--absorb:#7c47bf}
.abilities summary b{color:color-mix(in srgb,var(--c) 65%,#000)}
    CSS

    # Style of the page, in the colours of DARK or LIGHT. Paths inside are relative to the game
    # folder, where the page lies.
    STYLE = <<-'CSS'
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(1200px 600px at 50% -200px,var(--glow),transparent),var(--bg);color:var(--text);font:15px/1.5 "Segoe UI",system-ui,sans-serif}
.page{max-width:1900px;margin:0 auto;padding:32px 16px 48px}
.top h1{margin:0;font:600 34px/1.1 Georgia,"Times New Roman",serif;color:var(--gold);letter-spacing:.02em}
.top p{margin:4px 0 18px;color:var(--muted)}
.facts{display:flex;flex-wrap:wrap;gap:10px;margin:0;padding:0;list-style:none}
.facts li{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 14px}
.facts span{display:block;font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}
.group{margin:36px 0 14px;padding-bottom:6px;border-bottom:1px solid var(--line);font:600 20px Georgia,serif;color:var(--gold)}
.group small{margin-left:8px;font:400 14px "Segoe UI",sans-serif;color:var(--muted)}
.party{display:grid;grid-template-columns:repeat(auto-fill,minmax(380px,1fr));gap:18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;box-shadow:0 10px 30px var(--shadow)}
.portrait{position:relative;aspect-ratio:4/3;display:flex;align-items:center;justify-content:center;overflow:hidden;border-radius:13px 13px 0 0;background:radial-gradient(circle at 50% 65%,var(--halo),var(--card) 70%);border-bottom:1px solid var(--line)}
.portrait img{display:block;width:100%;height:100%;object-fit:contain}
.face{width:96px;height:96px;transform:scale(2);background-repeat:no-repeat}
.initial{font:600 120px Georgia,serif;color:var(--line)}
.title{position:absolute;left:0;right:0;bottom:0;display:flex;align-items:baseline;gap:10px;padding:32px 16px 10px;background:linear-gradient(transparent,var(--shade))}
.title h3{margin:0;font:600 24px Georgia,serif;text-shadow:var(--name-shadow)}
.title span{margin-left:auto;color:var(--gold);font-weight:600;white-space:nowrap}
.body{padding:12px 16px 16px}
.classes{display:grid;gap:6px}
.class{display:flex;align-items:center;gap:8px;background:var(--tile);border-radius:8px;padding:6px 10px}
.class .kind{width:40px;font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}
.class .name{flex:1}
.class .level{color:var(--muted);font-variant-numeric:tabular-nums;white-space:nowrap}
.class.mastered .level{color:var(--gold)}
h4{margin:16px 0 6px;font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:var(--muted)}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}
.stat{background:var(--tile);border-radius:8px;padding:6px 8px;min-width:0}
.stat span{display:block;font-size:11px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.stat b{display:block;font-size:15px;font-variant-numeric:tabular-nums;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rates{display:grid;grid-template-columns:1fr 1fr;column-gap:16px;margin:8px 0 0;font-size:12px}
.rates div{display:flex;justify-content:space-between;gap:6px;padding:2px 0;border-bottom:1px dashed var(--line)}
.rates dt{color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rates dd{margin:0;font-variant-numeric:tabular-nums}
.equips{display:grid;gap:4px;margin:0;padding:0;list-style:none}
.equips li{display:grid;grid-template-columns:92px 24px 1fr;gap:4px 8px;align-items:center}
.slot{font-size:12px;color:var(--muted)}
.equips .name{display:flex;flex-wrap:wrap;align-items:center;gap:2px 8px}
.gem-icons{display:inline-flex;gap:1px}
.gem-icons .icon:not(.sprite){width:18px;height:18px}
.equips .gem{margin-top:6px}
.equips .gem>span{display:inline-flex;align-items:center;gap:4px;font-size:13px}
.equips .gem .chips{margin-top:4px}
.icon{display:block;width:24px;height:24px}
.sprite{background-image:url("Graphics/System/IconSet.png");background-repeat:no-repeat}
.empty{color:var(--muted);font-style:italic}
.equips details{grid-column:3;margin:0 0 4px;padding:2px 8px}
.equips .chips>span{font-size:11px;background:var(--chip);color:var(--chip-text);border:0;border-radius:4px;padding:1px 6px}
.chips .sealed{text-decoration:line-through;color:var(--muted)}
.chips i{font-style:normal;color:var(--gold)}
.resists{display:grid;grid-template-columns:1fr 1fr;column-gap:14px;margin:8px 0 2px;font-size:12px}
.resists div{display:flex;align-items:center;gap:6px;min-width:0;border-bottom:1px dashed var(--line)}
.resists .icon{flex:none}
.resists dt{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.resists dd{margin:0;font-variant-numeric:tabular-nums}
.resists .normal{opacity:.5}
.resists .good dd{color:var(--good)}
.resists .bad dd{color:var(--bad)}
.resists .null dd{color:var(--gold)}
.resists .reflect dd{color:var(--reflect)}
.resists .absorb dd{color:var(--absorb)}
.trait{padding:8px 12px;border-left:3px solid var(--rose);border-radius:8px;background:var(--trait)}
.trait b{color:var(--rose)}
.trait p{margin:4px 0 0;font-size:13px;color:var(--trait-text)}
.abilities{display:grid;gap:6px}
.abilities details{margin:0;border-left:3px solid var(--c)}
.abilities summary{font-size:12px}
.abilities summary b{margin:0;color:var(--c)}
.abilities summary span{float:right;font-variant-numeric:tabular-nums}
.ability .chips{margin-top:4px}
.tip{position:relative;cursor:help}
.tipbox{display:none;position:absolute;left:0;top:calc(100% + 6px);z-index:10;width:max-content;max-width:300px;padding:8px 10px;border:1px solid var(--line);border-radius:8px;background:var(--tip);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px);color:var(--text);font-size:12px;line-height:1.45;box-shadow:0 8px 24px var(--tip-shadow);pointer-events:none}
.tip:hover>.tipbox{display:block}
.ability .chips>span{display:inline-flex;align-items:center;gap:4px;padding:0 8px 0 2px;border:0;border-radius:4px;background:var(--chip)}
details{margin-top:8px;background:var(--tile);border-radius:8px;padding:6px 10px}
summary{cursor:pointer;font-size:13px;color:var(--muted)}
summary b{margin-left:6px;color:var(--gold)}
.chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:8px}
details.category{margin-top:6px;padding:4px 8px;background:var(--chip)}
details.category summary{font-size:11px;text-transform:uppercase;letter-spacing:.06em}
.category .chips{margin-top:6px}
.chips>span{font-size:12px;border:1px solid var(--line);border-radius:999px;padding:1px 8px}
.none{margin-top:8px;font-size:13px;color:var(--muted)}
footer{margin-top:40px;font-size:12px;text-align:center;color:var(--muted)}
@media (max-width:440px){.party{grid-template-columns:1fr}.stats{grid-template-columns:repeat(2,1fr)}.rates{grid-template-columns:1fr}}
    CSS

    # Style that leaves the folded lists out and fits a card into a narrower column, for printing
    # and the image.
    COMPACT = <<-'CSS'
.group{margin-top:24px}
.card{box-shadow:none}
.portrait{aspect-ratio:16/10}
.portrait img{object-fit:cover;object-position:50% 15%}
.stats{grid-template-columns:1fr 1fr}
.stat{display:flex;justify-content:space-between;align-items:baseline;gap:8px;padding:3px 8px}
.stat span{font-size:12px}
.stat b{font-size:13px}
details,.applied,.abilities,.none{display:none}
    CSS

    # Style for printing, a row of four cards per page.
    PRINT = <<-'CSS'
@page{size:420mm 400mm;margin:0}
*{-webkit-print-color-adjust:exact;print-color-adjust:exact}
html{background:var(--bg)}
.page{max-width:none;padding:24px}
.group{break-after:avoid}
.party{grid-template-columns:repeat(4,minmax(0,1fr))}
.card{break-inside:avoid}
    CSS

    # Style for the image's page: the Frontline as wide as its cards, so the screenshot holds nothing
    # else.
    SHOT = <<-'CSS'
body{margin:0;background:var(--bg)}
.shot{width:fit-content;padding:24px;background:radial-gradient(900px 400px at 50% -150px,var(--glow),transparent),var(--bg)}
    CSS

    # Width of a card in the image, in pixels.
    CARD_WIDTH = 370

    # Colour of each ability category, by its skill type, matching its icons in the game's ability
    # screen: Combat, Job, Magic, Defense, Special and Proof Abilities.
    ABILITY_COLORS = { 1 => "#e5534b", 2 => "#5b7cf0", 3 => "#4cc46a", 4 => "#f09a3e", 5 => "#e8d44d", 999 => "#f5c542" }

    # Puts the Frontline's size on the body, width by height, where the script that takes the image
    # reads it.
    SIZE_SCRIPT = "<script>var box=document.querySelector('.shot').getBoundingClientRect();" \
                  "document.body.setAttribute('data-size',Math.ceil(box.width)+'x'+Math.ceil(box.height));</script>"

    # The body is built before the head, which carries the icons the body shows.
    #
    # @return [String] the whole page
    def self.build
      @icons = {}
      body = ['<body><div class="page">',
              MGQ_PartySheet.safely("header") { header },
              group("Frontline", Party.front),
              group("Reserve", Party.reserve),
              "<footer>Written by Party_Sheet.rb on #{Time.now.strftime('%Y-%m-%d %H:%M')}</footer>",
              '</div></body></html>'].join("\n")

      policy = "<meta http-equiv=\"Content-Security-Policy\" content=\"#{POLICY}\">"
      page = [head("#{STYLE}#{palette}@media print{#{PRINT}#{COMPACT}}#{icon_style}", policy), body].join("\n")

      pretty = MGQ_PartySheet.safely("indentation") { Pretty.html(page) }
      pretty.empty? ? page : pretty
    end

    # Builds the page the image is taken of: the header over the Frontline in a single row. It
    # runs SIZE_SCRIPT and is never shared, so it carries no POLICY.
    #
    # @param base [String, nil] the address linked images are relative to, nil when they are embedded
    # @return [String] the image's page
    def self.frontline(base)
      @icons = {}
      actors = Party.front
      columns = "grid-template-columns:repeat(#{actors.size},#{CARD_WIDTH}px)"
      shot = "<section class=\"shot\">#{MGQ_PartySheet.safely('header') { header }}#{heading('Frontline', actors.size)}" \
             "<div class=\"party\" style=\"#{columns}\">#{cards(actors)}</div></section>"

      base_tag = base ? "<base href=\"#{Text.html(base)}\">" : ""
      [head("#{STYLE}#{palette}#{COMPACT}#{SHOT}#{icon_style}", base_tag), '<body>', shot, SIZE_SCRIPT, '</body></html>'].join("\n")
    end

    # Follows STYLE, whose rules the palette's own ones override.
    #
    # @return [String] the colours the Theme option picks, DARK when they cannot be told
    def self.palette
      Options.light? ? LIGHT : DARK
    rescue => e
      MGQ_PartySheet.log("theme left dark: #{e.class}: #{e.message}")
      DARK
    end

    # @param style [String] the page's CSS
    # @param extra [String] a tag the head carries besides the usual ones, "" for none
    # @return [String] the page up to its body
    def self.head(style, extra = "")
      ['<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">',
       extra,
       '<meta name="viewport" content="width=device-width,initial-scale=1">',
       "<title>Party Sheet</title><style>#{style}</style></head>"].join("\n")
    end

    # @return [String] the title and the facts about the save
    def self.header
      facts = [["Play Time", Text.html($game_system.playtime_s)],
               ["Gold", "#{Text.large($game_party.gold)} #{Text.html(Vocab.currency_unit)}"],
               ["Location", Text.game(Party.location)],
               ["Party", Text.number($game_party.all_members.size)]]
      items = facts.reject { |_, value| value.strip.empty? }
                   .map { |label, value| "<li><span>#{label}</span>#{value}</li>" }

      '<header class="top"><h1>Party Sheet</h1><p>Monster Girl Quest! Paradox</p>' \
        "<ul class=\"facts\">#{items.join}</ul></header>"
    end

    # @param title [String] the heading
    # @param actors [Array<Game_Actor>] the members
    # @return [String] the heading and a card per member, "" without members
    def self.group(title, actors)
      return "" if actors.empty?

      "#{heading(title, actors.size)}<div class=\"party\">#{cards(actors)}</div>"
    end

    # @param title [String] the heading
    # @param count [Integer] the members under it
    # @return [String] the heading with the count beside it
    def self.heading(title, count)
      "<h2 class=\"group\">#{title}<small>#{count}</small></h2>"
    end

    # @param actors [Array<Game_Actor>] the members
    # @return [String] a card per member
    def self.cards(actors)
      actors.map { |actor| MGQ_PartySheet.safely("card of #{actor.name}") { card(actor) } }.join
    end

    # @param actor [Game_Actor] the member
    # @return [String] her card
    def self.card(actor)
      name = actor.name
      ['<article class="card">',
       portrait(actor),
       '<div class="body">',
       MGQ_PartySheet.safely("jobs of #{name}") { classes(actor) },
       MGQ_PartySheet.safely("stats of #{name}") { stats(actor) },
       MGQ_PartySheet.safely("equipment of #{name}") { equipment(actor) },
       MGQ_PartySheet.safely("abilities of #{name}") { abilities(actor) },
       MGQ_PartySheet.safely("trait of #{name}") { trait(actor) },
       applied(actor),
       MGQ_PartySheet.safely("mastery of #{name}") { mastery(actor) },
       '</div></article>'].join
    end

    # @param actor [Game_Actor] the member
    # @return [String] her picture with her name and level over it
    def self.portrait(actor)
      title = "<div class=\"title\"><h3>#{Text.html(actor.name)}</h3>" \
              "<span>Lv #{Text.number(actor.base_level)}</span></div>"
      "<div class=\"portrait\">#{MGQ_PartySheet.safely("picture of #{actor.name}") { art(actor) }}#{title}</div>"
    end

    # Shows the Library's picture of a member, her face when the picture is missing or packed inside
    # Game.rgss3a, her initial when the face cannot be shown either.
    #
    # @param actor [Game_Actor] the member
    # @return [String] the image
    def self.art(actor)
      picture = Party.picture(actor)
      return "<img src=\"#{Images.file(picture)}\" alt=\"\">" if picture

      face(actor) || "<div class=\"initial\">#{Text.html(actor.name[0, 1])}</div>"
    end

    # @param actor [Game_Actor] the member
    # @return [String, nil] her face, nil when she has none or it cannot be shown
    def self.face(actor)
      return nil if actor.face_name.to_s.empty?
      return "<img class=\"face\" src=\"#{Images.face(actor.face_name, actor.face_index)}\" alt=\"\">" if EMBED_IMAGES

      file = Party.face(actor)
      return nil unless file

      position = sprite_position(actor.face_index, Images::FACE_SIZE, Images::FACES_PER_ROW)
      "<div class=\"face\" style=\"background-image:url('#{Text.url(file)}');background-position:#{position}\"></div>"
    rescue
      nil
    end

    # @param actor [Game_Actor] the member
    # @return [String] her job and race with their levels
    def self.classes(actor)
      rows = [["Job", Party.job(actor), actor.class_level], ["Race", Party.race(actor), actor.tribe_level]]
      rows = rows.select { |row| row[1] }.map do |kind, data, level|
        mastered = level >= data.max_lv
        "<div class=\"class#{mastered ? ' mastered' : ''}\"><span class=\"kind\">#{kind}</span>" \
          "<span class=\"name\">#{Text.game(data.name)}</span>" \
          "<span class=\"level\">Lv #{level} / #{data.max_lv}#{mastered ? ' &#9733;' : ''}</span></div>"
      end

      "<div class=\"classes\">#{rows.join}</div>"
    end

    # @param actor [Game_Actor] the member
    # @return [String] her stats as tiles and her rates below them
    def self.stats(actor)
      tiles = STATS.map do |method, label|
        value = actor.send(method)
        "<div class=\"stat\" title=\"#{label}: #{Text.number(value)}\"><span>#{label}</span><b>#{Text.large(value)}</b></div>"
      end
      rates = RATES.select { |method, _| actor.respond_to?(method) }.map do |method, label|
        "<div><dt title=\"#{label}\">#{label}</dt><dd>#{Text.percent(actor.send(method))}</dd></div>"
      end

      "<h4>Stats</h4><div class=\"stats\">#{tiles.join}</div><dl class=\"rates\">#{rates.join}</dl>"
    end

    # @param actor [Game_Actor] the member
    # @return [String] what she wears, slot by slot
    def self.equipment(actor)
      rows = Party.equipment(actor).map { |slot, item| equipment_row(slot, item) }
      "<h4>Equipment</h4><ul class=\"equips\">#{rows.join}</ul>"
    end

    # @param slot [String] the slot's name
    # @param item [RPG::EquipItem, nil] the item in it, nil for an empty slot
    # @return [String] the slot with the item's icon, name, gem icons, bonuses and gems
    def self.equipment_row(slot, item)
      slot = "<span class=\"slot\">#{Text.game(slot)}</span>"
      return "<li>#{slot}<span></span><span class=\"empty\">empty</span></li>" unless item

      gems = Party.gems(item)
      gem_icons = gems.map { |gem| icon(gem ? gem.icon_index : Images::EMPTY_SOCKET_ICON) }.join
      name = "<span class=\"name\">#{tip(Text.game(item.name), item.description)}" \
             "#{gem_icons.empty? ? '' : "<span class=\"gem-icons\">#{gem_icons}</span>"}</span>"

      "<li>#{slot}#{icon(item.icon_index)}#{name}#{bonus_fold(Party.bonuses(item))}#{gem_fold(gems)}</li>"
    end

    # @param gems [Array<RPG::Item, nil>] the gem in each of an item's sockets, nil for an empty one
    # @return [String] each socket with its gem's icon, name and bonuses, folded away under Gems
    #   with the filled sockets of all, "" for an item without sockets
    def self.gem_fold(gems)
      return "" if gems.empty?

      rows = gems.map do |gem|
        next "<div class=\"gem\"><span class=\"empty\">empty socket</span></div>" unless gem

        chips = Party.gem_bonuses(gem).map { |bonus| "<span>#{Text.game(bonus)}</span>" }
        "<div class=\"gem\">#{tip("#{icon(gem.icon_index)}#{Text.game(gem.name)}", gem.description)}" \
          "<div class=\"chips\">#{chips.join}</div></div>"
      end
      "<details><summary>Gems<b>#{gems.compact.size} / #{gems.size}</b></summary>#{rows.join}</details>"
    end

    # @param bonuses [Array<String>] what an item or gem gives
    # @return [String] the bonuses folded away under Effects, "" without any
    def self.bonus_fold(bonuses)
      chips = bonuses.map { |bonus| "<span>#{Text.game(bonus)}</span>" }
      folded("Effects", chips.size, "<div class=\"chips\">#{chips.join}</div>")
    end

    # Shows an icon. An embedded icon only names its class, which icon_style fills with the image
    # once, however often the page shows it.
    #
    # @param index [Integer] the icon
    # @return [String] the icon, an empty cell when it cannot be shown
    def self.icon(index)
      if EMBED_IMAGES
        @icons[index] ||= Images.icon(index)
        return "<span class=\"icon i#{index}\"></span>"
      end
      return "<span></span>" unless Party.icons?

      "<span class=\"icon sprite\" style=\"background-position:#{sprite_position(index, Images::ICON_SIZE, Images::ICONS_PER_ROW)}\"></span>"
    rescue
      "<span></span>"
    end

    # @return [String] a CSS rule per icon the page shows, each carrying the icon's image
    def self.icon_style
      @icons.map { |index, image| ".i#{index}{background:url(#{image}) 0 0/100% 100% no-repeat}" }.join("\n")
    end

    # Lists the abilities a member has equipped, a fold per category in the colour of its icons in
    # the game's ability screen, with the AP it uses of its maximum.
    #
    # @param actor [Game_Actor] the member
    # @return [String] the categories she has abilities equipped in, "" when she has none
    def self.abilities(actor)
      folds = Party.abilities(actor).map do |id, name, skills, ap|
        chips = skills.map { |skill| tip("#{icon(skill.icon_index)}#{Text.game(skill.name)}", skill.description) }
        points = ap ? "<span>#{ap[0]} / #{ap[1]} AP</span>" : ""
        "<details class=\"ability\" style=\"--c:#{ABILITY_COLORS.fetch(id, 'var(--muted)')}\">" \
          "<summary><b>#{Text.game(name)}</b>#{points}</summary><div class=\"chips\">#{chips.join}</div></details>"
      end
      folds.empty? ? "" : "<div class=\"abilities\"><h4>Abilities</h4>#{folds.join}</div>"
    end

    # Shows the game's description of an item or ability while the pointer rests on it.
    #
    # @param content [String] the HTML the description belongs to
    # @param description [String, nil] the description from the game's data
    # @return [String] the content in a span, with the description as its tooltip when there is one
    def self.tip(content, description)
      text = Text.lines(description)
      return "<span>#{content}</span>" if text.empty?

      "<span class=\"tip\">#{content}<small class=\"tipbox\">#{text}</small></span>"
    end

    # @param actor [Game_Actor] the member
    # @return [String] her trait with its description, "" when she has none
    def self.trait(actor)
      trait = Party.trait(actor)
      return "" unless trait.is_a?(Array) && trait.first

      "<h4>Trait</h4><div class=\"trait\"><b>#{Text.game(trait.first)}</b>" \
        "<p>#{Text.game(trait[1..-1].join(' '))}</p></div>"
    end

    # @param actor [Game_Actor] the member
    # @return [String] the jobs and races she mastered, each list folded away and sorted by rank
    #   under the job change screen's names for them, like Sealed Jobs
    def self.mastery(actor)
      [["Jobs", :job?, 0], ["Races", :tribe?, 1]].map do |label, kind, type|
        ranks = Party.ranks(type)
        chips = Party.mastered(actor, kind).map do |data|
          [ranks.fetch(data.class_lank, "Other"), "<span>#{Text.game(data.name)}</span>"]
        end
        next "<div class=\"none\">No #{label.downcase} mastered yet</div>" if chips.empty?

        folded("Mastered #{label}", chips.size, categorized(chips, ranks.values + ["Other"], true))
      end.join
    end

    # Shows what everything a member has adds up to, each list folded away. A list the game version
    # cannot provide is left out on its own.
    #
    # @param actor [Game_Actor] the member
    # @return [String] her resists, skill types, effects and boosts
    def self.applied(actor)
      name = actor.name
      parts = [MGQ_PartySheet.safely("element resists of #{name}") { resists("Element Resists", Party.element_resists(actor)) },
               MGQ_PartySheet.safely("status resists of #{name}") { resists("Status Resists", Party.state_resists(actor)) },
               MGQ_PartySheet.safely("skill types of #{name}") { skill_types(actor) },
               MGQ_PartySheet.safely("effects of #{name}") { effects(actor) },
               MGQ_PartySheet.safely("boosts of #{name}") { boosts(actor) }].join
      parts.empty? ? "" : "<div class=\"applied\"><h4>Applied Effects</h4>#{parts}</div>"
    end

    # @param label [String] the list's name
    # @param resists [Array<Array(Integer, String, String, Symbol)>] the icon, name, resist and its
    #   kind of each element or state
    # @return [String] every resist, folded away, counting the ones that differ from 100%
    def self.resists(label, resists)
      rows = resists.map do |icon_index, name, text, kind|
        "<div class=\"#{kind}\">#{icon(icon_index)}<dt>#{Text.game(name)}</dt><dd>#{text}</dd></div>"
      end
      changed = resists.count { |row| row[3] != :normal }

      folded(label, changed, "<dl class=\"resists\">#{rows.join}</dl>", true)
    end

    # @param actor [Game_Actor] the member
    # @return [String] the skill types she can use, folded away, sealed ones struck through
    def self.skill_types(actor)
      chips = Party.skill_types(actor).map do |name, sealed|
        "<span#{sealed ? ' class="sealed"' : ''}>#{Text.game(name)}</span>"
      end
      folded("Skill Types", chips.size, "<div class=\"chips\">#{chips.join}</div>")
    end

    # @param actor [Game_Actor] the member
    # @return [String] her effects, combined as in battle, folded away. An effect from several
    #   sources explains in its tooltip how they combine; one the game applies one by one shows how
    #   often it applies.
    def self.effects(actor)
      chips = Party.effects(actor).map do |category, name, formula, times|
        [category, combined_chip("#{Text.game(name)}#{times > 1 ? " <i>&times;#{times}</i>" : ''}", formula)]
      end
      folded("Effects", chips.size, categorized(chips, Combine::CATEGORY_ORDER))
    end

    # @param actor [Game_Actor] the member
    # @return [String] her boosts, combined as in battle, folded away, each explaining in its tooltip
    #   how several sources combine
    def self.boosts(actor)
      chips = Party.boosts(actor).map { |category, name, formula| [category, combined_chip(Text.game(name), formula)] }
      folded("Boosts", chips.size, categorized(chips, Combine::BOOST_ORDER))
    end

    # @param chips [Array<Array(String, String)>] each chip's category and HTML
    # @param order [Array<String>] the categories in the order they show
    # @param open [Boolean] whether the categories start unfolded
    # @return [String] a fold per category with its chips, the categories without chips left out
    def self.categorized(chips, order, open = false)
      groups = chips.group_by(&:first)
      order.select { |category| groups[category] }.map do |category|
        "<details class=\"category\"#{open ? ' open' : ''}><summary>#{Text.html(category)}<b>#{groups[category].size}</b></summary>" \
          "<div class=\"chips\">#{groups[category].map(&:last).join}</div></details>"
      end.join
    end

    # @param label [String] the chip's HTML
    # @param formula [String, nil] how its sources combine, nil for a single source
    # @return [String] the chip, with the formula as its tooltip and marked when there is one
    def self.combined_chip(label, formula)
      formula ? tip("#{label} <i>&#8721;</i>", formula) : "<span>#{label}</span>"
    end

    # @param label [String] what the list holds
    # @param count [Integer] the number shown next to the label
    # @param body [String] the list
    # @param always [Boolean] whether to show the list even when the count is 0
    # @return [String] the list folded away under its label, "" for an empty list
    def self.folded(label, count, body, always = false)
      return "" if count == 0 && !always

      "<details><summary>#{label}<b>#{count}</b></summary>#{body}</details>"
    end

    # Finds a cell in a sheet of equally sized images, like a face or an icon.
    #
    # @param index [Integer] the cell, counted row by row
    # @param size [Integer] the width and height of a cell in pixels
    # @param per_row [Integer] the cells per row
    # @return [String] the CSS background-position that shows the cell
    def self.sprite_position(index, size, per_row)
      "-#{index % per_row * size}px -#{index / per_row * size}px"
    end
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first, its result is returned unchanged, and writing
# the sheet never raises.

if MGQ_PartySheet::ENABLED && MGQ_PartySheet.hookable?
  begin
    MGQ_PartySheet::Options.register
  rescue => e
    MGQ_PartySheet.log("options FAILED: #{e.class}: #{e.message}")
  end

  # Every scene updates the input in update_basic once per frame, so KEY triggers once per press.
  # Graphics.update also runs in waits that leave the input alone, where one press would repeat.
  begin
    class Scene_Base
      alias mgq_party_sheet_update_basic update_basic
      def update_basic(*args)
        result = mgq_party_sheet_update_basic(*args)
        MGQ_PartySheet.check_key
        result
      end
    end
  rescue => e
    MGQ_PartySheet.log("key hook FAILED: #{e.class}: #{e.message}")
  end

  # The config windows draw every option again after each change, so Shown Theme comes and goes
  # right away. The game's window sizes its contents to the options once, the Mod Config Menu's its
  # width, so both are measured again when the options change.
  begin
    [:Window_Config, :Window_ModConfig].select { |name| Object.const_defined?(name) }.each do |name|
      Object.const_get(name).class_eval do
        alias_method :mgq_party_sheet_refresh, :refresh
        define_method(:refresh) do
          if (MGQ_PartySheet::Options.arrange rescue false)
            calculate_and_resize if respond_to?(:calculate_and_resize)
            create_contents
          end
          mgq_party_sheet_refresh
        end
      end
    end
  rescue => e
    MGQ_PartySheet.log("config window hooks FAILED: #{e.class}: #{e.message}")
  end

  # The config windows call the handler of an entry's key when it is chosen, and stay active.
  begin
    class Scene_Config
      alias mgq_party_sheet_start start
      def start(*args)
        result = mgq_party_sheet_start(*args)
        [@config_window, @mod_config_window].compact.each do |window|
          window.set_handler(MGQ_PartySheet::Options::WRITE, proc { MGQ_PartySheet.write })
        end
        result
      end
    end
  rescue => e
    MGQ_PartySheet.log("config hook FAILED: #{e.class}: #{e.message}")
  end
end
