#----------------------------------------------------------------
#  Level_Cap.rb
#
#  Changelog:
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Caps the base level until the story's bosses fall and limits how many jobs and races of each
# tier a character can take up. Each boss on the list raises the cap and the limits once beaten;
# whether it is beaten comes from the game's own story switches and variables, so saves from
# before the mod work too. Levels and classes are never taken away. Every entry point rescues,
# so the mod never stops the game.
module MGQ_LevelCap
  # Turns the mod off without uninstalling it.
  ENABLED = true

  # Log next to Game.exe, which only appears when something went wrong.
  LOG_FILE = "Level Cap.log"

  # Lines logged per session at most.
  MAX_LOG_LINES = 40

  # Option that turns the level cap on or off, its key in $game_system.conf.
  CAP_OPTION = :mod_level_cap

  # Option that turns the job and race limits on or off, its key in $game_system.conf.
  LIMITS_OPTION = :mod_level_cap_limits

  # The cap, job limits and race limits of a new game, before any boss falls.
  START = [5, [2, 0, 0, 0, 0], [1, 0, 0, 0, 0]]

  # Names of the tiers, Basic to Forbidden, as the job change screen shows them.
  TIERS = %w[Basic Intermediate Advanced Sealed Forbidden]

  # The window skin color, yellow, of a level at its maximum or a full tier.
  FULL_COLOR = 17

  # The window skin color, orange, of a level above its maximum or a tier over its limit.
  OVER_COLOR = 20

  # The bosses that raise the cap and the limits, in story order: name, cap, job limits and race
  # limits per tier (Basic to Forbidden), and the test that the boss is beaten.
  #
  # The test lists alternatives, any of which counts; each is a list of conditions that must all
  # hold: [:v, id, n] for variable id at n or more, [:s, id] for switch id on. They are the
  # conditions under which the boss appears in Hades, the rematch hall. A nil cap lifts the cap
  # and every limit.
  MILESTONES = [
    # Part 1: Ilias Continent
    ["Four bandits", 10, [2,1,0,0,0], [1,0,0,0,0], [[[:v,1003,8]]]],
    ["Queen Harpy", 15, [2,1,0,0,0], [1,0,0,0,0], [[[:v,1011,4]]]],
    ["Morrigan", 18, [2,1,0,0,0], [1,0,0,0,0], [[[:v,1019,6]]]],

    # Part 1: Natalia Region
    ["Micaela event", 20, [3,2,0,0,0], [2,1,0,0,0], [[[:v,1021,2]]]],

    # Part 1: Safina Region
    ["Adramelech", 25, [4,2,0,0,0], [2,2,0,0,0], [[[:v,1032,7]]]],

    # Part 2: Noah Region
    ["Alma Elma, then Granberia", 30, [4,2,0,0,0], [2,2,0,0,0], [[[:v,1052,6]]]],

    # Part 2: Infiltration
    ["Lilith", 35, [4,2,0,0,0], [2,2,0,0,0], [[[:v,1063,13]]]],

    # Part 2: Gold Region
    ["Salamander", 40, [5,3,1,0,0], [2,2,1,0,0], [[[:v,1001,28]]]],

    # Part 2: All Out War
    ["Queen Elf", 43, [5,3,1,0,0], [2,2,1,0,0], [[[:v,1070,3]]]],
    ["Queen Mermaid", 45, [5,3,1,0,0], [2,2,1,0,0], [[[:v,1071,3]]]],
    ["Spider Princess", 47, [5,3,1,0,0], [2,2,1,0,0], [[[:v,1072,3]]]],
    ["Queen Vampire", 50, [5,3,1,0,0], [2,2,1,0,0], [[[:v,1073,3]]]],

    # Part 2: Orbs and Snow Continent
    ["Black Alice", 65, [5,3,1,0,0], [2,2,1,0,0], [[[:s,2261]]]],
    ["Sonya Chaos", 55, [5,4,1,0,0], [2,2,1,0,0], [[[:v,1001,34]]]],

    # Part 3: Before the Great Decision
    ["Garuda", 60, [5,4,2,1,0], [3,2,2,1,0], [[[:v,1001,37]]]],
    ["Tamamo", 61, [5,4,2,1,0], [3,2,2,1,0], [[[:s,2485]]]],
    ["Erubetie", 62, [5,4,2,1,0], [3,2,2,1,0], [[[:s,2486]]]],
    ["Granberia", 63, [5,4,2,1,0], [3,2,2,1,0], [[[:s,2487]]]],
    ["Great Decision", 65, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,1]], [[:v,1142,1]]]],

    # Part 3: Angelic Dominion route (Alice)
    ["Heaven's Gate", 67, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,4]]]],
    ["Gabriela", 70, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,18]]]],
    ["Uriela, Sabiriel and Fernandez", 75, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,30]]]],
    ["Sariela", 78, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,30]]]],
    ["Laplace", 80, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1141,38]]]],
    ["Metatronne and Sandalphone", 83, [6,5,4,1,0], [3,2,2,1,0], [[[:v,1141,43]]]],
    ["Zion (three fights)", 85, [6,5,4,1,0], [3,2,2,1,0], [[[:v,1173,8]]]],
    ["Cosmos", 90, [6,5,4,1,0], [3,2,2,1,0], [[[:v,1151,6]]]],
    ["Aži Dahāka", 95, [7,6,4,1,0], [3,2,2,1,0], [[[:v,1141,58]]]],
    ["Marcellus and Black Alice", 95, [7,6,4,1,0], [3,2,2,1,0], [[[:v,1141,62]]]],
    ["Doppel Lukas and Lucifina", 100, [7,6,4,2,0], [3,3,2,1,0], [[[:v,1141,67]]]],
    ["Micaela", 105, [7,6,4,2,0], [3,3,2,1,0], [[[:v,1141,73]]]],
    ["Ilias", 115, [7,6,5,2,0], [3,3,2,1,0], [[[:s,7096]]]],
    ["Chaos Ilias", 120, [8,7,6,2,0], [4,3,3,2,0], [[[:s,7096]]]],

    # Part 3: Monster Realm route (Ilias)
    ["Queen Eva", 67, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1142,8]]]],
    ["Malboro Girl, then Kanon", 70, [6,5,3,1,0], [3,2,2,1,0], [[[:s,2594], [:v,1142,25]]]],
    ["Kanade", 75, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1142,33]]]],
    ["Tamamo", 80, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1142,34]]]],
    ["Tamamo", 83, [6,5,3,1,0], [3,2,2,1,0], [[[:v,1142,36]]]],
    ["Minagi and Alipheese the 10th", 85, [6,5,4,1,0], [3,2,2,1,0], [[[:v,1169,23]]]],
    ["Kagetsumugi and her dolls", 90, [6,5,4,1,0], [3,2,2,1,0], [[[:v,1142,47]]]],
    ["Hiruko", 95, [7,6,4,1,0], [3,2,2,1,0], [[[:v,1142,60]]]],
    ["Kagetsumugi and Magatsu-Karura, then Black Alice", 95, [7,6,4,1,0], [3,2,2,1,0], [[[:v,1142,63]]]],
    ["Doppel Lukas and Lucifina", 100, [7,6,4,2,0], [3,3,2,1,0], [[[:v,1142,71]]]],
    ["Saja", 105, [7,6,4,2,0], [3,3,2,1,0], [[[:v,1142,81]]]],
    ["Alipheese", 115, [7,6,5,2,0], [3,3,2,1,0], [[[:s,7097]]]],
    ["Chaos Alipheese", 120, [8,7,6,2,0], [4,3,3,2,0], [[[:s,7097]]]],

    # Part 3: Chaos route (start, fixed order)
    ["Kagetsumugi and her dolls", 125, [8,7,6,3,0], [4,3,3,2,1], [[[:v,1143,4]]]],
    ["Angolmois", 130, [8,7,6,3,0], [4,3,3,2,1], [[[:v,1143,18]]]],

    # Part 3: Chaos route (free order, sorted by level)
    ["Greedy Papi, Gob, Teeny and Vanilla", 135, [8,7,6,3,0], [5,4,3,2,1], [[[:v,1319,7]]]],
    ["Gabriela and Kanon", 135, [8,7,6,3,0], [5,4,3,2,1], [[[:v,1301,8]]]],
    ["Uriela", 135, [8,7,6,3,1], [5,4,3,2,1], [[[:v,1302,5]]]],
    ["Kanade", 140, [8,7,6,3,1], [5,4,3,2,1], [[[:v,1302,7]]]],
    ["Hiruko", 140, [8,7,6,3,1], [5,4,3,2,1], [[[:v,1304,5]]]],
    ["Magatsu-Omikami", 145, [8,7,6,3,1], [5,4,3,2,1], [[[:v,1307,3]]]],
    ["Apiro Lagos", 147, [8,7,6,3,1], [5,4,3,2,1], [[[:v,1305,6]]]],
    ["Zion and Laplace", 151, [8,7,6,4,1], [5,4,3,2,1], [[[:v,1308,8]]]],
    ["Sigrdrifa", 153, [8,7,6,4,1], [5,4,3,2,1], [[[:v,1308,11]]]],
    ["Metatronne and Sandalphone, then Singularity", 155, [8,7,6,4,1], [5,4,3,2,1], [[[:v,1308,13]]]],
    ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, [9,8,7,4,1], [5,4,3,2,1], [[[:s,3030], [:s,3031], [:s,3032], [:s,3033]]]],
    ["Saja", 168, [9,8,7,4,1], [5,4,3,2,1], [[[:v,1312,3]]]],
    ["World Drown", 175, [9,8,7,4,1], [5,4,3,2,1], [[[:v,1313,5]]]],
    ["Cosmos", 180, [9,8,7,4,1], [5,4,3,2,1], [[[:v,1315,6]]]],
    ["No Life King", 185, [9,8,7,4,1], [5,4,3,2,1], [[[:v,1316,11]]]],
    ["Angolmois", 190, [9,8,7,4,1], [5,4,3,2,1], [[[:v,1314,3]]]],
    ["Hiruko, Kanon and Kanade", 195, [9,8,7,5,1], [5,4,3,2,1], [[[:v,1317,3]]]],
    ["Baal Zebub", 203, [9,8,7,5,1], [5,4,3,2,1], [[[:v,1318,10]]]],
    ["Seven Deadly Sins vessels", 210, [9,8,7,5,1], [5,4,3,2,1], [[[:v,1328,6], [:v,1331,5], [:v,1329,4], [:v,1332,5], [:v,1326,4]]]],
    ["Greedy, Envious and Slothful Eva", 213, [9,8,7,5,1], [5,4,3,2,1], [[[:v,1325,11]]]],
    ["Seven Deadly Sins", 215, [10,9,8,5,2], [5,4,3,2,2], [[[:v,1325,12]]]],
    ["The All-Knowing", 220, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1334,4]]]],
    ["Agaliarept", 225, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1373,13]]]],
    ["Echidna Queen", 228, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1335,5]]]],
    ["Cthulhu", 230, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1336,5]]]],
    ["Dimensional Eroder", 235, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1338,4]]]],
    ["Star Eater", 240, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1339,5]]]],
    ["Black Alice", 245, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1342,5]]]],
    ["Idea Lukas", 250, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1342,5]]]],
    ["EX Sonya", 255, [10,9,8,6,2], [5,4,3,2,2], [[[:v,1343,3]]]],
    ["Koron", 260, [10,9,8,7,3], [6,5,4,3,2], [[[:v,1345,5]]]],

    # Part 3: Chaos route (finale, fixed order)
    ["Goddess, Demon and Fiend", 275, [10,9,8,7,3], [6,5,4,3,2], [[[:s,3079], [:s,3078], [:s,3077]]]],
    ["World Breaker and Judgement", 285, [10,9,8,7,3], [6,5,4,3,2], [[[:s,3080], [:s,3081]]]],
    ["Deus Ex Machina", 300, [10,9,8,7,3], [6,5,4,3,2], [[[:s,7039]]]],
    ["Chaos", nil, nil, nil, [[[:s,7039]]]],
  ]

  # Writes a line to the log, at most MAX_LOG_LINES per session.
  #
  # @param message [String] what happened
  def self.log(message)
    @log_lines = (@log_lines || 0) + 1
    return if @log_lines > MAX_LOG_LINES

    File.open(LOG_FILE, "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end

  # Reads one of the mod's options; both are on until the player turns them off.
  #
  # @param key [Symbol] CAP_OPTION or LIMITS_OPTION
  # @return [Boolean] whether the option is on
  def self.option_on?(key)
    value = $game_system.conf[key] rescue nil
    value.nil? || value == 1
  end

  # @param milestone [Array] an entry of MILESTONES
  # @return [Boolean] whether the game's story state says its boss is beaten
  def self.beaten?(milestone)
    milestone[4].any? do |conditions|
      conditions.all? do |kind, id, step|
        kind == :s ? $game_switches[id] : $game_variables[id].to_i >= step
      end
    end
  end

  # Works out where the story stands: the highest cap and, tier by tier, the highest limits among
  # the beaten bosses.
  #
  # @return [Array(Integer, Array<Integer>, Array<Integer>), nil] the cap, the job limits and the
  #   race limits; nil without a running game or once the final battle lifted every limit
  def self.progress
    return nil unless $game_switches && $game_variables

    cap, jobs, races = START
    MILESTONES.each do |milestone|
      next unless beaten?(milestone)
      return nil if milestone[1].nil?

      cap = [cap, milestone[1]].max
      jobs = higher(jobs, milestone[2])
      races = higher(races, milestone[3])
    end
    [cap, jobs, races]
  end

  # @param first [Array<Integer>] limits per tier
  # @param second [Array<Integer>] limits per tier
  # @return [Array<Integer>] the higher of both, tier by tier
  def self.higher(first, second)
    first.each_index.map { |tier| [first[tier], second[tier]].max }
  end

  # @return [Integer, nil] the current level cap, nil while the cap is off or lifted
  def self.cap
    return nil if @bypass.to_i > 0 || !option_on?(CAP_OPTION)

    state = progress
    state && state[0]
  end

  # Runs a block with the cap out of the way, for levels the story sets itself.
  #
  # @return [Object] what the block returns
  def self.bypass
    @bypass = @bypass.to_i + 1
    yield
  ensure
    @bypass -= 1
  end

  # @param actor [Game_Actor] a character
  # @return [Boolean] whether the character's base level stands at the cap and would rise without it
  def self.capped?(actor)
    limit = cap
    limit && actor.base_level >= limit && actor.base_level < actor.mgq_level_cap_max_level(:base)
  end

  # @param class_id [Integer] a job or race
  # @return [Symbol, nil] :job, :race, or nil for neither
  def self.kind(class_id)
    if NWConst::Class::JOB_RANGE.include?(class_id) then :job
    elsif NWConst::Class::TRIBE_RANGE.include?(class_id) then :race
    end
  end

  # @param class_id [Integer] a job or race
  # @return [Integer] its tier, 1 (Basic) to 5 (Forbidden), 0 for none
  def self.tier(class_id)
    data = $data_classes[class_id]
    data ? data.class_lank.to_i : 0
  end

  # Counts a character's jobs or races per tier. One counts from level 2, so a job tried out at
  # level 1 and dropped again takes no room.
  #
  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>] the count per tier, Basic to Forbidden
  def self.counts(actor, kind)
    counts = [0, 0, 0, 0, 0]
    actor.level_list.each do |class_id, level|
      next if level.to_i < 2 || kind(class_id) != kind

      tier = tier(class_id)
      counts[tier - 1] += 1 if tier.between?(1, 5)
    end
    counts
  end

  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>, nil] the limit per tier, nil while the limits are off or lifted
  def self.limits(kind)
    return nil unless option_on?(LIMITS_OPTION)

    state = progress
    state && (kind == :job ? state[1] : state[2])
  end

  # Tells whether a character may switch to a job or race. One counted already (level 2 or more)
  # always can; a new one only while its tier has room.
  #
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @return [Boolean] whether the limits allow it
  def self.allowed?(actor, class_id)
    !full_tier(actor, class_id)
  end

  # Finds why the limits refuse a job or race, if they do.
  #
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @return [Array(Symbol, Integer, Integer, Integer), nil] its kind, tier, count and limit when the
  #   tier is full, nil when the limits allow it
  def self.full_tier(actor, class_id)
    return nil if actor.nil? || actor.level_list[class_id].to_i >= 2

    kind = kind(class_id)
    tier = tier(class_id)
    limits = kind && limits(kind)
    return nil unless limits && tier.between?(1, 5)

    count = counts(actor, kind)[tier - 1]
    count >= limits[tier - 1] ? [kind, tier, count, limits[tier - 1]] : nil
  end

  # The mod's two options in the Mod Config menu.
  module Options
    # On and Off, by their name and help in the menu. The first one is the default.
    SWITCH = {
      1 => ["On", "On."],
      0 => ["Off", "Off."],
    }

    # Adds both options before the menu's last entry, which returns.
    #
    # The Mod Config Menu or Mod Config Remake defines MOD_CONTENTS, and the mod loader runs both
    # before this script.
    def self.register
      config = NWConst::Config
      menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS
      add(menu, CAP_OPTION, "[Level Cap] Level Cap",
          "Keeps the base level at or below the level of the next story boss. EXP past the cap is lost.")
      add(menu, LIMITS_OPTION, "     -> Job and Race Limits",
          "Limits how many jobs and races of each tier a character can take up. Beaten bosses raise the limits.")
    end

    # Adds an On/Off option before the menu's last entry.
    #
    # @param menu [Array<Hash>] the menu's entries
    # @param key [Symbol] the option, its key in $game_system.conf
    # @param name [String] its name in the menu
    # @param help [String] its help in the menu
    def self.add(menu, key, name, help)
      config = NWConst::Config
      menu.insert(-2, :key => key, :name => name, :sub => true, :help => "#{help}\r\n←/→ Toggle")
      config::DATA[key] = SWITCH.keys
      config::DATA_TEXT[key] = {}
      SWITCH.each { |value, (label, text)| config::DATA_TEXT[key][value] = { :name => label, :help => text } }
      config::DEFAULT[key] = SWITCH.keys.first
    end
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs, and the mod only narrows what it returns or adds to
# what it draws. An error in the mod falls back to the game's own answer.
module MGQ_LevelCap
  # Installs the hooks, once. The translation's plugins load after the Patch folder and define job
  # change and level drawing methods anew, so the hooks go in once the first scene starts and wrap
  # whatever the plugins left.
  def self.install
    return if @installed || Game_Actor.method_defined?(:mgq_level_cap_max_level)

    @installed = true
    install_level_hooks
    install_job_change_hooks
    install_window_hooks
  rescue => e
    log("install FAILED: #{e.class}: #{e.message}")
  end

  # The base level's maximum feeds change_exp, which clamps the EXP to it: EXP past the cap is
  # lost and the level stops. Never below the current level, or change_exp would level down.
  # Levels the story sets go past the cap: companions lifted to the party's level, Change Level.
  def self.install_level_hooks
    Game_Actor.class_eval do
      alias_method :mgq_level_cap_max_level, :max_level
      def max_level(kind)
        maximum = mgq_level_cap_max_level(kind)
        return maximum unless kind == :base

        cap = MGQ_LevelCap.cap
        cap ? [[cap, base_level].max, maximum].min : maximum
      rescue => e
        MGQ_LevelCap.log("max_level FAILED: #{e.class}: #{e.message}")
        mgq_level_cap_max_level(kind)
      end
    end

    Game_Interpreter.class_eval do
      alias_method :mgq_level_cap_level_adjust, :level_adjust
      def level_adjust(*args)
        MGQ_LevelCap.bypass { mgq_level_cap_level_adjust(*args) }
      end

      alias_method :mgq_level_cap_command_316, :command_316
      def command_316
        MGQ_LevelCap.bypass { mgq_level_cap_command_316 }
      end
    end
  end

  # The job change list greys out a new job or race while its tier is full; the seed list behind it
  # follows, since it asks the same question. The job's details tell why, and the tier tabs show
  # each tier's count.
  def self.install_job_change_hooks
    Foo::JobChange::Window_ClassName.class_eval do
      alias_method :mgq_level_cap_class_change_enable?, :class_change_enable?
      def class_change_enable?(id)
        mgq_level_cap_class_change_enable?(id) && MGQ_LevelCap.allowed?(actor, id)
      rescue => e
        MGQ_LevelCap.log("class_change_enable? FAILED: #{e.class}: #{e.message}")
        mgq_level_cap_class_change_enable?(id)
      end
    end

    status = Foo::JobChange::Window_ClassStatus
    status.class_eval do
      alias_method :mgq_level_cap_draw_status, :draw_status
      def draw_status
        mgq_level_cap_draw_status
        mgq_level_cap_draw_full_tier
      end
    end
    # The translation's paged job details draw a title on each page instead of calling draw_status.
    if status.method_defined?(:draw_page_title)
      status.class_eval do
        alias_method :mgq_level_cap_draw_page_title, :draw_page_title
        def draw_page_title(*args)
          mgq_level_cap_draw_page_title(*args)
          mgq_level_cap_draw_full_tier_title(args[1])
        end
      end
    end

    Foo::JobChange::Window_ClassType.class_eval do
      alias_method :mgq_level_cap_draw_item, :draw_item
      def draw_item(index)
        return mgq_level_cap_draw_item(index) unless mgq_level_cap_tier_count(index)

        mgq_level_cap_set_font(index)
        mgq_level_cap_draw_tier(index) || mgq_level_cap_draw_item(index)
      end

      alias_method :mgq_level_cap_command_name, :command_name
      def command_name(index)
        @mgq_level_cap_blank ? "" : mgq_level_cap_command_name(index)
      end

      # The scene draws the tabs before it tells the list which character changes, and seeds raise
      # levels on this screen, so the tabs redraw whenever the counts they show change.
      alias_method :mgq_level_cap_update, :update
      def update
        mgq_level_cap_update
        mgq_level_cap_refresh_counts if visible
      end
    end
  end

  # Every window that draws levels shows them with their maximum, including windows of the
  # translation's plugins that place them in their own way; the status screen shows the level and
  # the cap instead of "COMPLETE".
  def self.install_window_hooks
    level_windows = [Window_Base]
    ObjectSpace.each_object(Class) do |klass|
      own = klass < Window_Base && klass.instance_methods(false).include?(:draw_actor_level)
      level_windows << klass if own
    end
    level_windows.each do |klass|
      klass.class_eval do
        alias_method :mgq_level_cap_draw_actor_level, :draw_actor_level
        def draw_actor_level(actor, x, y, kind)
          return if mgq_level_cap_draw_level(actor, x, y, kind)

          mgq_level_cap_draw_actor_level(actor, x, y, kind)
        end
      end
    end

    Window_Base.class_eval do
      alias_method :mgq_level_cap_draw_actor_simple_status, :draw_actor_simple_status
      def draw_actor_simple_status(actor, x, y, next_exp = false)
        @mgq_level_cap_actor = next_exp ? actor : nil
        mgq_level_cap_draw_actor_simple_status(actor, x, y, next_exp)
      ensure
        @mgq_level_cap_actor = nil
      end

      alias_method :mgq_level_cap_draw_text, :draw_text
      def draw_text(*args)
        if @mgq_level_cap_measured
          @mgq_level_cap_measured << MGQ_LevelCap.text_args(args)
          return
        end
        mgq_level_cap_mark_cap(args) if @mgq_level_cap_actor
        mgq_level_cap_draw_text(*args)
        mgq_level_cap_remember_text(args)
      end
    end
  end

  # @param args [Array] the arguments of Window_Base#draw_text, a Rect or x, y, width and height
  #   first
  # @return [Array] x, y, width, height, text and alignment
  def self.text_args(args)
    if args[0].is_a?(Rect)
      rect, text, align = args
      [rect.x, rect.y, rect.width, rect.height, text, align || 0]
    else
      x, y, width, height, text, align = args
      [x, y, width, height, text, align || 0]
    end
  end
end

class Foo::JobChange::Window_ClassStatus
  # Draws which tier is full or over its limit and how many of its jobs or races are taken, when
  # the limits refuse the job shown.
  def mgq_level_cap_draw_full_tier
    full = MGQ_LevelCap.full_tier(actor, @class_id)
    return unless full

    reset_font_settings
    change_color(mgq_level_cap_full_color(full))
    draw_text(4, contents_height - line_height, contents_width - 8, line_height,
              "#{mgq_level_cap_full_text(full)}: #{full[2]} of #{full[3]} taken.")
    change_color(normal_color)
  rescue => e
    MGQ_LevelCap.log("full tier note FAILED: #{e.class}: #{e.message}")
  end

  # Draws the same note shorter on a page title of the translation's paged job details, left of
  # the title's right-hand text.
  #
  # @param right_text [String, nil] what the title shows on the right
  def mgq_level_cap_draw_full_tier_title(right_text)
    full = MGQ_LevelCap.full_tier(actor, @class_id)
    return unless full

    bold = contents.font.bold
    size = contents.font.size
    contents.font.bold = true
    contents.font.size = size - 2
    right = contents_width - 4
    right -= text_size(right_text.to_s).width + 12 if right_text
    text = "#{mgq_level_cap_full_text(full)} (#{full[2]}/#{full[3]})"
    width = text_size(text).width
    change_color(mgq_level_cap_full_color(full))
    draw_text(right - width, 1, width + 2, line_height, text)
    change_color(normal_color)
  rescue => e
    MGQ_LevelCap.log("full tier title FAILED: #{e.class}: #{e.message}")
  ensure
    contents.font.bold = bold unless bold.nil?
    contents.font.size = size if size
  end

  # @param full [Array] what MGQ_LevelCap.full_tier returned
  # @return [String] the tier and its state, such as "Basic jobs full"
  def mgq_level_cap_full_text(full)
    kind, tier, count, limit = full
    noun = kind == :job ? "jobs" : "races"
    "#{MGQ_LevelCap::TIERS[tier - 1]} #{noun} #{count > limit ? 'over the limit' : 'full'}"
  end

  # @param full [Array] what MGQ_LevelCap.full_tier returned
  # @return [Color] yellow for a full tier, orange for one over its limit
  def mgq_level_cap_full_color(full)
    text_color(full[2] > full[3] ? MGQ_LevelCap::OVER_COLOR : MGQ_LevelCap::FULL_COLOR)
  end
end

# The tier tabs above the job change list show how many jobs or races of each tier the character
# has taken and may take ("Basic 2/3").
class Foo::JobChange::Window_ClassType
  # The gap in pixels between a tier's name and its count.
  MGQ_LEVEL_CAP_GAP = 8

  # @return [Array(Array<Integer>, Array<Integer>), nil] the character's counts and the limits of
  #   the kind shown, nil without a character (the job library) or while the limits are off
  def mgq_level_cap_tier_state
    actor = @class_name.actor
    kind = [:job, :race][@class_type_id]
    limits = actor && kind && MGQ_LevelCap.limits(kind)
    limits && [MGQ_LevelCap.counts(actor, kind), limits]
  end

  # @param index [Integer] the tab
  # @return [Array(Integer, Integer), nil] the tab's count and limit, nil when no limits apply
  def mgq_level_cap_tier_count(index)
    state = mgq_level_cap_tier_state
    tier = command_ext(index)
    return nil unless state && tier.is_a?(Integer) && tier.between?(1, 5)

    [state[0][tier - 1], state[1][tier - 1]]
  rescue => e
    MGQ_LevelCap.log("tier count FAILED: #{e.class}: #{e.message}")
    nil
  end

  # Lets the game's or a plugin's draw_item set the tab's font, drawing an empty name, so the
  # count is drawn in the font the tab would have.
  #
  # @param index [Integer] the tab
  def mgq_level_cap_set_font(index)
    @mgq_level_cap_blank = true
    mgq_level_cap_draw_item(index)
  ensure
    @mgq_level_cap_blank = false
  end

  # Redraws the tabs when the character, their counts or the limits differ from those drawn.
  def mgq_level_cap_refresh_counts
    shown = [@class_name.actor, @class_type_id, mgq_level_cap_tier_state]
    return if shown == @mgq_level_cap_shown

    @mgq_level_cap_shown = shown
    refresh
  rescue => e
    MGQ_LevelCap.log("tier tab refresh FAILED: #{e.class}: #{e.message}")
  end

  # @param count [Integer] the jobs or races taken in a tier
  # @param limit [Integer] how many the tier allows
  # @return [Color] white with room left, yellow when full, orange when over the limit (a
  #   companion who joined with more)
  def mgq_level_cap_count_color(count, limit)
    return normal_color if count < limit

    text_color(count == limit ? MGQ_LevelCap::FULL_COLOR : MGQ_LevelCap::OVER_COLOR)
  end

  # Draws a tab as the tier's name and its count, "taken/limit", the count colored by how full
  # the tier is.
  #
  # @param index [Integer] the tab
  # @return [Boolean] whether it drew, false when no limits apply
  def mgq_level_cap_draw_tier(index)
    count, limit = mgq_level_cap_tier_count(index)
    return false unless count

    rect = item_rect_for_text(index)
    label = MGQ_LevelCap::TIERS[command_ext(index) - 1]
    number = "#{count}/#{limit}"
    number_width = text_size(number).width
    label_width = [text_size(label).width, rect.width - MGQ_LEVEL_CAP_GAP - number_width].min
    left = rect.x + (rect.width - label_width - MGQ_LEVEL_CAP_GAP - number_width) / 2
    change_color(normal_color, command_enabled?(index))
    draw_text(left, rect.y, label_width, rect.height, label)
    change_color(mgq_level_cap_count_color(count, limit))
    number_x = left + label_width + MGQ_LEVEL_CAP_GAP
    draw_text(number_x, rect.y, number_width + 2, rect.height, number)
    true
  rescue => e
    MGQ_LevelCap.log("tier tab FAILED: #{e.class}: #{e.message}")
    false
  end
end

# Menus show each level with its maximum ("Lv 1 / 5", the base level's maximum being the cap), and
# the status screen shows the level and the cap instead of "COMPLETE" while a character waits for
# the cap to rise.
class Window_Base
  # The gap in pixels between a level and its maximum.
  MGQ_LEVEL_CAP_GAP = 6

  # The narrowest text box that may hold a name a level squeezes.
  MGQ_LEVEL_CAP_NAME_WIDTH = 60

  # How many of the last drawn texts a window keeps for squeezing.
  MGQ_LEVEL_CAP_REMEMBERED = 8

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :base, :class or :tribe
  # @return [Integer, nil] the maximum to show beside the level: the cap for the base level, the
  #   job's or race's own maximum otherwise, nil while the Level Cap option is off or lifted
  def mgq_level_cap_shown_maximum(actor, kind)
    return nil unless MGQ_LevelCap.option_on?(MGQ_LevelCap::CAP_OPTION)
    return actor.max_level(kind) unless kind == :base

    limit = MGQ_LevelCap.cap
    limit if limit && limit < actor.mgq_level_cap_max_level(:base)
  end

  # Runs the window's own draw_actor_level without drawing, to learn where it puts the level
  # number; the game and the translation's plugins each place it differently.
  #
  # @param actor [Game_Actor] the character
  # @param x [Integer] where the window draws the level
  # @param y [Integer] the line's top
  # @param kind [Symbol] :base, :class or :tribe
  # @return [Array, nil] the number's x, y, width, height, text and alignment
  def mgq_level_cap_level_number(actor, x, y, kind)
    size = contents.font.size
    @mgq_level_cap_measured = []
    mgq_level_cap_draw_actor_level(actor, x, y, kind)
    level = actor.level[kind].to_s
    @mgq_level_cap_measured.reverse.find { |args| args[4].to_s == level }
  ensure
    @mgq_level_cap_measured = nil
    contents.font.size = size if size
  end

  # Draws "Lv", the level and a smaller, translucent "/ maximum" (full size and yellow with the
  # level once it reaches the maximum, orange above it), ending where the window's own level number
  # ends, so the wider text grows to the left into the free space after the name.
  #
  # @param actor [Game_Actor] the character
  # @param x [Integer] where the window draws the level
  # @param y [Integer] the line's top
  # @param kind [Symbol] :base, :class or :tribe
  # @return [Boolean] whether it drew, false when no maximum is shown
  def mgq_level_cap_draw_level(actor, x, y, kind)
    maximum = mgq_level_cap_shown_maximum(actor, kind)
    return false unless maximum

    number = mgq_level_cap_level_number(actor, x, y, kind)
    return false unless number

    number_x, y, number_width, height, _text, align = number
    lv_width = text_size(Vocab.level_a).width
    reached = actor.max_level?(kind)
    over = actor.level[kind] > maximum
    color = text_color(over ? MGQ_LevelCap::OVER_COLOR : MGQ_LevelCap::FULL_COLOR)
    size = contents.font.size
    maximum_size = reached ? size : size * 3 / 4
    level = actor.level[kind].to_s
    level_width = text_size(level).width
    right = align == 2 ? number_x + number_width : number_x + level_width
    contents.font.size = maximum_size
    maximum_text = "/ #{maximum}"
    maximum_width = text_size(maximum_text).width
    contents.font.size = size
    maximum_x = right - maximum_width
    level_x = maximum_x - MGQ_LEVEL_CAP_GAP - level_width
    label_x = level_x - 3 - lv_width
    mgq_level_cap_squeeze_text_before(label_x, y)

    change_color(system_color)
    mgq_level_cap_draw_text(label_x, y, lv_width + 2, height, Vocab.level_a)
    change_color(reached ? color : normal_color)
    mgq_level_cap_draw_text(level_x, y, level_width + 2, height, level, 2)
    reached ? change_color(color) : change_color(normal_color, false)
    contents.font.size = maximum_size
    maximum_y = y + (size - maximum_size) / 2
    mgq_level_cap_draw_text(maximum_x, maximum_y, maximum_width + 2, height, maximum_text)
    true
  rescue => e
    MGQ_LevelCap.log("level with maximum FAILED: #{e.class}: #{e.message}")
    false
  ensure
    contents.font.size = size if size
  end

  # Redraws the name drawn last on the level's line narrower when it reaches into the level, so
  # the game condenses it instead of the level covering it.
  #
  # @param left [Integer] where the level's text starts
  # @param y [Integer] the level's line top
  def mgq_level_cap_squeeze_text_before(left, y)
    entry = (@mgq_level_cap_texts || []).reverse.find do |text_x, text_y, width, height|
      (text_y + height / 2 - y - line_height / 2).abs < line_height / 2 &&
        text_x < left && text_x + width > left - MGQ_LEVEL_CAP_GAP
    end
    return unless entry

    text_x, text_y, width, height, text, align, size, color = entry
    room = left - MGQ_LEVEL_CAP_GAP - text_x
    font_size = contents.font.size
    font_color = contents.font.color.clone
    contents.font.size = size
    return if text_size(text).width <= room

    contents.clear_rect(text_x, text_y + (height - size) / 2 - 1, width, size + 2)
    contents.font.color = color.clone
    mgq_level_cap_draw_text(text_x, text_y, room, height, text, align)
  rescue => e
    MGQ_LevelCap.log("name squeeze FAILED: #{e.class}: #{e.message}")
  ensure
    contents.font.size = font_size if font_size
    contents.font.color = font_color if font_color
  end

  # Keeps the last texts wide enough to be names, with the font they were drawn in, for
  # mgq_level_cap_squeeze_text_before; narrower ones such as message letters are skipped.
  #
  # @param args [Array] the arguments of draw_text
  def mgq_level_cap_remember_text(args)
    x, y, width, height, text, align = MGQ_LevelCap.text_args(args)
    return unless text.is_a?(String) && !text.empty? && width.to_i >= MGQ_LEVEL_CAP_NAME_WIDTH

    texts = (@mgq_level_cap_texts ||= [])
    texts.shift if texts.size >= MGQ_LEVEL_CAP_REMEMBERED
    font = contents.font
    texts << [x, y, width, height, text, align, font.size, font.color.clone]
  rescue => e
    MGQ_LevelCap.log("text memory FAILED: #{e.class}: #{e.message}")
  end

  # Puts the base level and the cap in place of its "COMPLETE" in the status screen's NEXT
  # line, while the character stands at the cap.
  #
  # @param args [Array] the arguments of draw_text, changed in place
  def mgq_level_cap_mark_cap(args)
    index = args[0].is_a?(Rect) ? 1 : 4
    text = args[index]
    return unless text.is_a?(String) && text.start_with?("NEXT COMPLETE")
    return unless MGQ_LevelCap.capped?(@mgq_level_cap_actor)

    args[index] = text.sub("COMPLETE", "#{@mgq_level_cap_actor.base_level}/#{MGQ_LevelCap.cap}")
  rescue => e
    MGQ_LevelCap.log("cap mark FAILED: #{e.class}: #{e.message}")
  end
end

if MGQ_LevelCap::ENABLED && !SceneManager.respond_to?(:mgq_level_cap_run)
  begin
    MGQ_LevelCap::Options.register
  rescue => e
    MGQ_LevelCap.log("options FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << SceneManager
      alias mgq_level_cap_run run

      # Installs the hooks over the translation's plugins, then runs the game.
      def run
        MGQ_LevelCap.install
        mgq_level_cap_run
      end
    end
  rescue => e
    MGQ_LevelCap.log("scene hook FAILED: #{e.class}: #{e.message}")
  end
end
