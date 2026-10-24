#----------------------------------------------------------------
#  Level_Cap.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Replaced the job and race limits with points spent on slots per tier
#                            - Added slot allocation and class reset to the job change screen
#                            - Mastered classes in remembered tiers on taking them up
#                            - Offered the points as a page to other mods' screens through ModPages
#      Paulinchen  2026-10-06: Wrote the log into the game folder's Logs folder
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Caps the base level until the story's bosses fall, and lets each character spend points on job
# and race slots per tier. Each boss on the list raises the cap and the points once beaten; whether
# it is beaten comes from the game's own story switches and variables, so saves from before the mod
# work too. Every entry point rescues, so the mod never stops the game.
module MGQ_LevelCap
  # Turns the mod off without uninstalling it.
  ENABLED = true

  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR, which only appears when something went wrong.
  LOG_FILE = "Level Cap.log"

  # Lines logged per session at most.
  MAX_LOG_LINES = 40

  # Option that turns the level cap on or off, its key in $game_system.conf.
  CAP_OPTION = :mod_level_cap

  # Option that turns the job and race points on or off, its key in $game_system.conf.
  LIMITS_OPTION = :mod_level_cap_limits

  # The cap, the points and the highest open job and race tiers of a new game, before any boss
  # falls.
  START = [5, 1, 1, 1]

  # What one slot of each tier costs, Basic to Forbidden, for jobs and for races.
  PRICES = { :job => [1, 2, 4, 6, 12], :race => [2, 4, 8, 12, 24] }

  # The slots every character has for free: the one Basic job and the one Basic race they keep.
  FREE_SLOTS = { :job => [1, 0, 0, 0, 0], :race => [1, 0, 0, 0, 0] }

  # Names of the tiers, Basic to Forbidden, as the job change screen shows them.
  TIERS = %w[Basic Intermediate Advanced Sealed Forbidden]

  # The window skin color, yellow, of a level at its maximum or a full tier.
  FULL_COLOR = 17

  # The window skin color, orange, of a level above its maximum or a tier over its limit.
  OVER_COLOR = 20

  # The bosses that raise the cap and the points, in story order: name, cap, points, the highest
  # job tier and race tier open from then on, and the test that the boss is beaten.
  #
  # The test lists alternatives, any of which counts; each is a list of conditions that must all
  # hold: [:v, id, n] for variable id at n or more, [:s, id] for switch id on. They are the
  # conditions under which the boss appears in Hades, the rematch hall. A nil cap lifts the level
  # cap; the points and the slots still apply.
  MILESTONES = [
    # Part 1: Ilias Continent
    ["Four bandits", 10, 2, 2, 1, [[[:v,1003,8]]]],
    ["Queen Harpy", 15, 3, 2, 1, [[[:v,1011,4]]]],
    ["Morrigan", 18, 4, 2, 1, [[[:v,1019,6]]]],

    # Part 1: Natalia Region
    ["Micaela event", 20, 5, 2, 2, [[[:v,1021,2]]]],

    # Part 1: Safina Region
    ["Adramelech", 25, 6, 2, 2, [[[:v,1032,7]]]],

    # Part 2: Noah Region
    ["Alma Elma, then Granberia", 30, 9, 2, 2, [[[:v,1052,6]]]],

    # Part 2: Infiltration
    ["Lilith", 35, 12, 2, 2, [[[:v,1063,13]]]],

    # Part 2: Gold Region
    ["Salamander", 40, 15, 3, 3, [[[:v,1001,28]]]],

    # Part 2: All Out War
    ["Queen Elf", 43, 18, 3, 3, [[[:v,1070,3]]]],
    ["Queen Mermaid", 45, 21, 3, 3, [[[:v,1071,3]]]],
    ["Spider Princess", 47, 24, 3, 3, [[[:v,1072,3]]]],
    ["Queen Vampire", 50, 27, 3, 3, [[[:v,1073,3]]]],

    # Part 2: Orbs and Snow Continent
    ["Black Alice", 65, 30, 3, 3, [[[:s,2261]]]],
    ["Sonya Chaos", 55, 33, 3, 3, [[[:v,1001,34]]]],

    # Part 3: Before the Great Decision
    ["Garuda", 60, 37, 4, 4, [[[:v,1001,37]]]],
    ["Tamamo", 61, 41, 4, 4, [[[:s,2485]]]],
    ["Erubetie", 62, 45, 4, 4, [[[:s,2486]]]],
    ["Granberia", 63, 49, 4, 4, [[[:s,2487]]]],
    ["Great Decision", 65, 53, 4, 4, [[[:v,1141,1]], [[:v,1142,1]]]],

    # Part 3: Angelic Dominion route (Alice)
    ["Heaven's Gate", 67, 57, 4, 4, [[[:v,1141,4]]]],
    ["Gabriela", 70, 61, 4, 4, [[[:v,1141,18]]]],
    ["Uriela, Sabiriel and Fernandez", 75, 65, 4, 4, [[[:v,1141,30]]]],
    ["Sariela", 78, 69, 4, 4, [[[:v,1141,30]]]],
    ["Laplace", 80, 73, 4, 4, [[[:v,1141,38]]]],
    ["Metatronne and Sandalphone", 83, 77, 4, 4, [[[:v,1141,43]]]],
    ["Zion (three fights)", 85, 81, 4, 4, [[[:v,1173,8]]]],
    ["Cosmos", 90, 85, 4, 4, [[[:v,1151,6]]]],
    ["Aži Dahāka", 95, 89, 4, 4, [[[:v,1141,58]]]],
    ["Marcellus and Black Alice", 95, 93, 4, 4, [[[:v,1141,62]]]],
    ["Doppel Lukas and Lucifina", 100, 97, 4, 4, [[[:v,1141,67]]]],
    ["Micaela", 105, 101, 4, 4, [[[:v,1141,73]]]],
    ["Ilias", 115, 105, 4, 4, [[[:s,7096]]]],
    ["Chaos Ilias", 120, 109, 4, 4, [[[:s,7096]]]],

    # Part 3: Monster Realm route (Ilias)
    ["Queen Eva", 67, 57, 4, 4, [[[:v,1142,8]]]],
    ["Malboro Girl, then Kanon", 70, 61, 4, 4, [[[:s,2594], [:v,1142,25]]]],
    ["Kanade", 75, 65, 4, 4, [[[:v,1142,33]]]],
    ["Tamamo", 80, 69, 4, 4, [[[:v,1142,34]]]],
    ["Tamamo", 83, 73, 4, 4, [[[:v,1142,36]]]],
    ["Minagi and Alipheese the 10th", 85, 77, 4, 4, [[[:v,1169,23]]]],
    ["Kagetsumugi and her dolls", 90, 81, 4, 4, [[[:v,1142,47]]]],
    ["Hiruko", 95, 85, 4, 4, [[[:v,1142,60]]]],
    ["Kagetsumugi and Magatsu-Karura, then Black Alice", 95, 89, 4, 4, [[[:v,1142,63]]]],
    ["Doppel Lukas and Lucifina", 100, 93, 4, 4, [[[:v,1142,71]]]],
    ["Saja", 105, 97, 4, 4, [[[:v,1142,81]]]],
    ["Alipheese", 115, 101, 4, 4, [[[:s,7097]]]],
    ["Chaos Alipheese", 120, 109, 4, 4, [[[:s,7097]]]],

    # Part 3: Chaos route (start, fixed order)
    ["Kagetsumugi and her dolls", 125, 114, 4, 5, [[[:v,1143,4]]]],
    ["Angolmois", 130, 119, 4, 5, [[[:v,1143,18]]]],

    # Part 3: Chaos route (free order, sorted by level)
    ["Greedy Papi, Gob, Teeny and Vanilla", 135, 124, 4, 5, [[[:v,1319,7]]]],
    ["Gabriela and Kanon", 135, 129, 4, 5, [[[:v,1301,8]]]],
    ["Uriela", 135, 134, 5, 5, [[[:v,1302,5]]]],
    ["Kanade", 140, 139, 5, 5, [[[:v,1302,7]]]],
    ["Hiruko", 140, 144, 5, 5, [[[:v,1304,5]]]],
    ["Magatsu-Omikami", 145, 149, 5, 5, [[[:v,1307,3]]]],
    ["Apiro Lagos", 147, 154, 5, 5, [[[:v,1305,6]]]],
    ["Zion and Laplace", 151, 159, 5, 5, [[[:v,1308,8]]]],
    ["Sigrdrifa", 153, 164, 5, 5, [[[:v,1308,11]]]],
    ["Metatronne and Sandalphone, then Singularity", 155, 169, 5, 5, [[[:v,1308,13]]]],
    ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, 174, 5, 5, [[[:s,3030], [:s,3031], [:s,3032], [:s,3033]]]],
    ["Saja", 168, 179, 5, 5, [[[:v,1312,3]]]],
    ["World Drown", 175, 184, 5, 5, [[[:v,1313,5]]]],
    ["Cosmos", 180, 189, 5, 5, [[[:v,1315,6]]]],
    ["No Life King", 185, 194, 5, 5, [[[:v,1316,11]]]],
    ["Angolmois", 190, 199, 5, 5, [[[:v,1314,3]]]],
    ["Hiruko, Kanon and Kanade", 195, 204, 5, 5, [[[:v,1317,3]]]],
    ["Baal Zebub", 203, 209, 5, 5, [[[:v,1318,10]]]],
    ["Seven Deadly Sins vessels", 210, 214, 5, 5, [[[:v,1328,6], [:v,1331,5], [:v,1329,4], [:v,1332,5], [:v,1326,4]]]],
    ["Greedy, Envious and Slothful Eva", 213, 219, 5, 5, [[[:v,1325,11]]]],
    ["Seven Deadly Sins", 215, 224, 5, 5, [[[:v,1325,12]]]],
    ["The All-Knowing", 220, 229, 5, 5, [[[:v,1334,4]]]],
    ["Agaliarept", 225, 234, 5, 5, [[[:v,1373,13]]]],
    ["Echidna Queen", 228, 239, 5, 5, [[[:v,1335,5]]]],
    ["Cthulhu", 230, 244, 5, 5, [[[:v,1336,5]]]],
    ["Dimensional Eroder", 235, 249, 5, 5, [[[:v,1338,4]]]],
    ["Star Eater", 240, 254, 5, 5, [[[:v,1339,5]]]],
    ["Black Alice", 245, 259, 5, 5, [[[:v,1342,5]]]],
    ["Idea Lukas", 250, 264, 5, 5, [[[:v,1342,5]]]],
    ["EX Sonya", 255, 269, 5, 5, [[[:v,1343,3]]]],
    ["Koron", 260, 274, 5, 5, [[[:v,1345,5]]]],

    # Part 3: Chaos route (finale, fixed order)
    ["Goddess, Demon and Fiend", 275, 279, 5, 5, [[[:s,3079], [:s,3078], [:s,3077]]]],
    ["World Breaker and Judgement", 285, 284, 5, 5, [[[:s,3080], [:s,3081]]]],
    ["Deus Ex Machina", 300, 289, 5, 5, [[[:s,7039]]]],
    ["Chaos", nil, 339, 5, 5, [[[:s,7039]]]],
  ]

  # Writes a line to the log, at most MAX_LOG_LINES per session.
  #
  # @param message [String] what happened
  def self.log(message)
    @log_lines = (@log_lines || 0) + 1
    return if @log_lines > MAX_LOG_LINES

    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
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
    milestone[5].any? do |conditions|
      conditions.all? do |kind, id, step|
        kind == :s ? $game_switches[id] : $game_variables[id].to_i >= step
      end
    end
  end

  # Works out where the story stands: the highest cap, points and open tiers among the beaten
  # bosses.
  #
  # @return [Array(Integer, Integer, Integer, Integer), nil] the cap (nil once the final battle
  #   lifted it), the points and the highest open job and race tiers; nil without a running game
  def self.progress
    return nil unless $game_switches && $game_variables

    state = START.dup
    lifted = false
    MILESTONES.each do |milestone|
      next unless beaten?(milestone)

      lifted ||= milestone[1].nil?
      state.each_index { |i| state[i] = [state[i], milestone[i + 1]].max if milestone[i + 1] }
    end
    state[0] = nil if lifted
    state
  end

  # @return [Integer, nil] the current level cap, nil while the cap is off, bypassed or lifted
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
  # @return [Symbol, nil] :job, :race, or nil for neither; kept once looked up, since the game's
  #   ranges are long lists
  def self.kind(class_id)
    @kinds ||= {}
    return @kinds[class_id] if @kinds.key?(class_id)

    @kinds[class_id] = if NWConst::Class::JOB_RANGE.include?(class_id) then :job
                       elsif NWConst::Class::TRIBE_RANGE.include?(class_id) then :race
                       end
  end

  # @param class_id [Integer] a job or race
  # @return [Integer] its tier, 1 (Basic) to 5 (Forbidden), 0 for none
  def self.tier(class_id)
    data = $data_classes[class_id]
    data ? data.class_lank.to_i : 0
  end

  # @return [Boolean] whether points and slots apply: the option is on in a running game
  def self.active?
    option_on?(LIMITS_OPTION) && !progress.nil?
  end

  # @return [Integer] the points every character has, from the beaten bosses
  def self.points
    state = progress
    state ? state[1] : 0
  end

  # @param kind [Symbol] :job or :race
  # @return [Integer] the highest tier of that kind the story has opened
  def self.open_tier(kind)
    state = progress
    return 5 unless state

    kind == :job ? state[2] : state[3]
  end

  # The mod's record of a character, saved with them: the slots bought per tier and the most jobs
  # and races they ever had mastered per tier.
  #
  # @param actor [Game_Actor] the character
  # @return [Hash, nil] :slots and :mastered, each by kind; nil before the character's conversion
  def self.record(actor)
    actor && actor.instance_variable_get(:@mgq_level_cap)
  end

  # Counts a character's jobs or races per tier: each one at level 2 or more, and the one worn. One
  # tried at level 1 and dropped again, or a Basic race kept at level 1 to be picked later, takes
  # no room.
  #
  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>] the count per tier, Basic to Forbidden
  def self.counts(actor, kind)
    counts = [0, 0, 0, 0, 0]
    worn = kind == :job ? actor.class_id : actor.tribe_id
    actor.level_list.each do |class_id, level|
      next unless kind(class_id) == kind && (level.to_i >= 2 || class_id == worn)

      tier = tier(class_id)
      counts[tier - 1] += 1 if tier.between?(1, 5)
    end
    counts
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>] how many jobs or races of each tier stand at their maximum level
  def self.mastered_counts(actor, kind)
    counts = [0, 0, 0, 0, 0]
    actor.level_list.each do |class_id, level|
      data = $data_classes[class_id]
      next unless data && kind(class_id) == kind && level.to_i >= data.max_lv

      tier = tier(class_id)
      counts[tier - 1] += 1 if tier.between?(1, 5)
    end
    counts
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>, nil] the slots per tier, nil while no limits apply to the character
  def self.limits(actor, kind)
    data = record(actor)
    data && active? ? data[:slots][kind] : nil
  end

  # @param actor [Game_Actor] the character
  # @return [Integer] the points the character's bought slots cost, the free ones aside
  def self.spent(actor)
    data = record(actor)
    return 0 unless data

    [:job, :race].inject(0) do |sum, kind|
      (0..4).inject(sum) do |total, i|
        total + (data[:slots][kind][i] - FREE_SLOTS[kind][i]) * PRICES[kind][i]
      end
    end
  end

  # @param actor [Game_Actor] the character
  # @return [Integer] the points left to spend, below zero when the bosses beaten give fewer
  def self.free_points(actor)
    points - spent(actor)
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
  # @return [Boolean] whether the tier is open and the free points pay one more slot
  def self.can_add?(actor, kind, tier)
    record(actor) && active? && tier <= open_tier(kind) &&
      free_points(actor) >= PRICES[kind][tier - 1]
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
  # @return [Boolean] whether the tier has a bought slot nothing fills
  def self.can_remove?(actor, kind, tier)
    data = record(actor)
    return false unless data && active?

    slots = data[:slots][kind][tier - 1]
    slots > FREE_SLOTS[kind][tier - 1] && slots > counts(actor, kind)[tier - 1]
  end

  # Buys or refunds one slot of a tier.
  #
  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
  # @param step [Integer] 1 to buy, -1 to refund
  # @return [Boolean] whether the slot changed
  def self.change_slot(actor, kind, tier, step)
    allowed = step > 0 ? can_add?(actor, kind, tier) : can_remove?(actor, kind, tier)
    return false unless allowed

    record(actor)[:slots][kind][tier - 1] += step
    true
  end

  # Raises the remembered mastered counts to what the character has mastered now; they never drop.
  #
  # @param actor [Game_Actor] the character
  def self.remember_mastery(actor)
    data = record(actor)
    return unless data

    [:job, :race].each do |kind|
      now = mastered_counts(actor, kind)
      data[:mastered][kind] = (0..4).map { |i| [data[:mastered][kind][i], now[i]].max }
    end
  end

  # Masters the job or race a character just took up, while its tier has more remembered
  # masteries than mastered jobs or races. Levelling through the game learns its skills.
  #
  # @param actor [Game_Actor] the character, wearing the job or race
  # @param class_id [Integer] the job or race
  def self.auto_master(actor, class_id)
    data = record(actor)
    kind = kind(class_id)
    tier = tier(class_id)
    job = $data_classes[class_id]
    return unless data && active? && kind && job && tier.between?(1, 5)
    return if actor.level_list[class_id].to_i >= job.max_lv
    return unless mastered_counts(actor, kind)[tier - 1] < data[:mastered][kind][tier - 1]

    actor.change_level(job.max_lv, false, kind == :job ? :class : :tribe)
    actor.recover_all
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Array<Integer>] the Basic jobs or races the character has, highest level first, the
  #   ones a reset may keep
  def self.basic_choices(actor, kind)
    ids = actor.level_list.keys.select { |id| kind(id) == kind && tier(id) == 1 }
    ids.sort_by { |id| [-actor.level_list[id].to_i, id] }
  end

  # Resets a character's jobs and races and refunds every slot. They keep one Basic job and one
  # Basic race, and their other Basic races at level 1 so they can still pick them; the job
  # change screen refuses Basic races a character has never had. Every skill and ability a job or
  # race teaches goes, Proofs included, until the jobs and races are learned again. The base level
  # stays.
  #
  # @param actor [Game_Actor] the character, converted already
  # @param job_id [Integer] the Basic job to keep
  # @param race_id [Integer] the Basic race to keep
  # @return [Boolean] whether the character was reset
  def self.reset(actor, job_id, race_id)
    return false unless record(actor)

    keep_only(actor, job_id, race_id, [])
    record(actor)[:slots] = { :job => FREE_SLOTS[:job].dup, :race => FREE_SLOTS[:race].dup }
    actor.refresh
    true
  end

  # Drops every job and race but those worn and those kept, keeps the other Basic races at level 1
  # and forgets what the dropped ones taught.
  #
  # @param actor [Game_Actor] the character, with a record
  # @param job_id [Integer] the job to wear
  # @param race_id [Integer] the race to wear
  # @param kept [Array<Integer>] the other jobs and races to keep at their levels
  def self.keep_only(actor, job_id, race_id, kept)
    remember_mastery(actor)
    exp = actor.instance_variable_get(:@exp)
    pool = basic_choices(actor, :race) - [race_id] - kept
    removed = actor.level_list.keys - [job_id, race_id] - kept - pool

    actor.change_class(job_id, :class)
    actor.change_class(race_id, :tribe)
    removed.each do |id|
      actor.level_list.delete(id)
      exp.delete(id)
    end
    pool.each do |id|
      actor.level_list[id] = 1
      exp[id] = $data_classes[id].exp_for_level(1)
    end
    forget_taught_skills(actor)
  end

  # Forgets every skill and ability any job or race teaches, also those of jobs and races dropped
  # before and those a companion joins with, unless a job or race the character has at its level
  # or their own growth teaches it too.
  #
  # @param actor [Game_Actor] the character, already reset
  def self.forget_taught_skills(actor)
    kept = []
    actor.level_list.each do |id, level|
      next unless $data_classes[id]

      $data_classes[id].learnings.each { |learning| kept << learning.skill_id if learning.level <= level }
    end
    own = actor.original_persona_data_actor.peculiar_skill rescue []
    own.each { |skill| kept << skill[:id] if skill[:lv] <= actor.base_level }
    learned = actor.instance_variable_get(:@skills).to_a + actor.all_abilities
    ((learned & class_taught_skills) - kept).uniq.each { |skill_id| forget_skill(actor, skill_id) }
  end

  # @return [Array<Integer>] every skill and ability some job or race teaches
  def self.class_taught_skills
    @class_taught_skills ||= $data_classes.compact.map { |data| data.learnings.map { |learning| learning.skill_id } }.flatten.uniq
  end

  # Forgets a skill or ability. The game's own forget_skill leaves abilities of other skill types
  # than the five ability types learned, such as the Proofs many jobs and races teach.
  #
  # @param actor [Game_Actor] the character
  # @param skill_id [Integer] the skill
  def self.forget_skill(actor, skill_id)
    actor.forget_skill(skill_id)
    skill = $data_skills[skill_id]
    return unless skill

    [:@abilities, :@equip_abilities].each do |name|
      lists = actor.instance_variable_get(name)
      list = lists && lists[skill.stype_id]
      list.delete(skill_id) if list
    end
  end

  # Starts the mod's record of a character the first time it meets them: remembers what they
  # mastered and spends their points on slots for the classes they have, see plan_slots; the
  # classes the points do not pay for go. Saves from before the mod and companions who join later
  # go through it once.
  #
  # @param actor [Game_Actor] the character
  def self.convert(actor)
    return if record(actor) || !active?

    actor.instance_variable_set(:@mgq_level_cap,
                                :slots => { :job => FREE_SLOTS[:job].dup, :race => FREE_SLOTS[:race].dup },
                                :mastered => { :job => [0, 0, 0, 0, 0], :race => [0, 0, 0, 0, 0] })
    plan = plan_slots(actor)
    if plan
      keep_only(actor, plan[:job], plan[:race], plan[:kept])
      record(actor)[:slots] = plan[:slots]
      actor.refresh
      return
    end

    # Without a Basic job or race to keep, the character keeps everything and gets the slots for it.
    slots = [:job, :race].map do |kind|
      have = counts(actor, kind)
      [kind, (0..4).map { |i| [have[i], FREE_SLOTS[kind][i]].max }]
    end
    record(actor)[:slots] = Hash[slots]
    remember_mastery(actor)
    log("#{actor.name} has no Basic job or race to keep; kept every class")
  end

  # Plans which classes a character keeps on their first meeting and the slots that pay for them:
  # the worn job and race first, or a Basic one where the points cannot pay for it; then a job and
  # a race by turns, each time the highest tier the points still pay for, the higher level first
  # within a tier. A class only stays together with the classes its requirements name, so each
  # is paid for with them.
  #
  # @param actor [Game_Actor] the character
  # @return [Hash, nil] :job and :race to wear, :kept (every class kept) and :slots; nil without a
  #   Basic job or race to fall back on
  def self.plan_slots(actor)
    plan = { :free => points, :kept => [], :slots => { :job => FREE_SLOTS[:job].dup, :race => FREE_SLOTS[:race].dup },
             :used => { :job => [0, 0, 0, 0, 0], :race => [0, 0, 0, 0, 0] }, :needs => {},
             :open => { :job => open_tier(:job), :race => open_tier(:race) } }
    [[:job, actor.class_id], [:race, actor.tribe_id]].each do |kind, worn|
      plan[kind] = keep_with_needs(plan, actor, worn) ? worn : keep_choice(actor, kind)
      return nil unless plan[kind]

      keep_with_needs(plan, actor, plan[kind]) || keep_in_plan(plan, [plan[kind]])
    end
    queues = [:job, :race].map do |kind|
      held = actor.level_list.keys.select { |id| kind(id) == kind && actor.level_list[id].to_i >= 2 }
      held.sort_by { |id| [-tier(id), -actor.level_list[id].to_i, id] }
    end
    turn = 0
    idle = 0
    while idle < queues.size
      taken = queues[turn].find { |id| !plan[:kept].include?(id) && affordable?(plan, id) && keep_with_needs(plan, actor, id) }
      idle = taken ? 0 : idle + 1
      turn = 1 - turn
    end
    plan
  end

  # Tells whether the points left could pay for a class's own slot, before asking what its
  # requirements add.
  #
  # @param plan [Hash] the plan, see plan_slots
  # @param class_id [Integer] the job or race
  # @return [Boolean] whether they could
  def self.affordable?(plan, class_id)
    cost = cost_of(plan, [class_id])
    cost && cost <= plan[:free]
  end

  # Keeps a class in a plan with the classes its requirements name, when the points pay for all of
  # them.
  #
  # @param plan [Hash] the plan, see plan_slots, changed in place
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @return [Boolean] whether it is kept
  def self.keep_with_needs(plan, actor, class_id)
    return true if plan[:kept].include?(class_id)

    bundle = needs_of(plan, actor, class_id, [])
    bundle && keep_in_plan(plan, bundle)
  end

  # Lists a class and what its requirements name that the plan does not keep yet: every class it
  # needs, and for each choice of classes the one that costs least, each at the level asked.
  #
  # @param plan [Hash] the plan, see plan_slots
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @param path [Array<Integer>] the classes asking for it, against requirements going in a circle
  # @return [Array<Integer>, nil] the classes; nil when the character lacks one at the level asked
  def self.needs_of(plan, actor, class_id, path)
    return [] if plan[:kept].include?(class_id)
    return nil if path.include?(class_id) || !actor.level_list.key?(class_id)
    return plan[:needs][class_id] if plan[:needs].key?(class_id)

    plan[:needs][class_id] = find_needs(plan, actor, class_id, path)
  end

  # Works out what needs_of tells, while the plan keeps nothing new.
  #
  # @param plan [Hash] the plan, see plan_slots
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @param path [Array<Integer>] the classes asking for it
  # @return [Array<Integer>, nil] the classes; nil when the character lacks one at the level asked
  def self.find_needs(plan, actor, class_id, path)

    data = $data_classes[class_id]
    bundle = [class_id]
    met = lambda { |need| actor.level_list[need[:id]].to_i >= need[:lv] }
    data.need_jobchange_class.each do |need|
      more = met.call(need) && needs_of(plan, actor, need[:id], path + [class_id])
      return nil unless more

      bundle |= more
    end
    data.select_jobchange_class.each do |choices|
      options = choices.select { |need| met.call(need) }.map { |need| needs_of(plan, actor, need[:id], path + [class_id]) }
      options = options.select { |option| option && cost_of(plan, bundle | option) }
      return nil if options.empty?

      bundle |= options.min_by { |option| [cost_of(plan, bundle | option), option.size] }
    end
    bundle
  end

  # Prices classes the plan would keep: the slots they need beyond the free ones of the plan.
  #
  # @param plan [Hash] the plan, see plan_slots
  # @param bundle [Array<Integer>] the jobs and races
  # @return [Integer, nil] the points; nil when the story has not opened a tier of them
  def self.cost_of(plan, bundle)
    taken = Hash.new(0)
    bundle.each do |class_id|
      kind = kind(class_id)
      index = tier(class_id) - 1
      return nil unless kind && index.between?(0, plan[:open][kind] - 1)

      taken[[kind, index]] += 1
    end
    taken.inject(0) do |sum, ((kind, index), count)|
      room = plan[:slots][kind][index] - plan[:used][kind][index]
      sum + [count - room, 0].max * PRICES[kind][index]
    end
  end

  # Keeps classes in a plan when their tiers are open and the free slots and the points left pay
  # for all of them.
  #
  # @param plan [Hash] the plan, see plan_slots, changed in place
  # @param bundle [Array<Integer>] the jobs and races
  # @return [Boolean] whether they are kept
  def self.keep_in_plan(plan, bundle)
    cost = cost_of(plan, bundle)
    return false unless cost && cost <= plan[:free]

    plan[:free] -= cost
    plan[:needs].clear
    bundle.each do |class_id|
      kind = kind(class_id)
      index = tier(class_id) - 1
      plan[:slots][kind][index] += 1 if plan[:used][kind][index] >= plan[:slots][kind][index]
      plan[:used][kind][index] += 1
      plan[:kept] << class_id
    end
    true
  end

  # @param actor [Game_Actor] the character
  # @param kind [Symbol] :job or :race
  # @return [Integer, nil] the worn job or race when it is Basic, otherwise the Basic one of the
  #   highest level
  def self.keep_choice(actor, kind)
    worn = kind == :job ? actor.class_id : actor.tribe_id
    tier(worn) == 1 ? worn : basic_choices(actor, kind).first
  end

  # Converts every character the mod has not met yet and brings everyone's remembered masteries up
  # to date: the party and those waiting in the Pocket Castle, all of whom the job change screen
  # lists.
  def self.convert_party
    return unless $game_party && active?

    members = $game_party.respond_to?(:include_members) ? $game_party.include_members : $game_party.all_members
    members.each do |actor|
      convert(actor)
      remember_mastery(actor)
    end
  rescue => e
    log("convert_party FAILED: #{e.class}: #{e.message}")
  end

  # Tells whether a character may switch to a job or race. One counted already (level 2 or more)
  # always can; a new one only while its tier has a free slot.
  #
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @return [Boolean] whether the slots allow it
  def self.allowed?(actor, class_id)
    !full_tier(actor, class_id)
  end

  # Finds why the slots refuse a job or race, if they do. The worn one of the same tier still at
  # level 1 makes room, since switching drops it.
  #
  # @param actor [Game_Actor] the character
  # @param class_id [Integer] the job or race
  # @return [Array(Symbol, Integer, Integer, Integer), nil] its kind, tier, count and slots when
  #   the tier is full, nil when the slots allow it
  def self.full_tier(actor, class_id)
    return nil if actor.nil? || actor.level_list[class_id].to_i >= 2

    kind = kind(class_id)
    tier = tier(class_id)
    limits = kind && limits(actor, kind)
    return nil unless limits && tier.between?(1, 5)

    count = counts(actor, kind)[tier - 1]
    worn = kind == :job ? actor.class_id : actor.tribe_id
    count -= 1 if worn != class_id && tier(worn) == tier && actor.level_list[worn].to_i < 2
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
      add(menu, LIMITS_OPTION, "     -> Job and Race Points",
          "Each character spends points on job and race slots per tier in the job change screen. Beaten bosses give more points.")
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
    install_point_hooks
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

  # The job change screen's character menu gets Allocate and Reset; a confirmed job
  # or race comes mastered while the character's remembered masteries allow it. Party members are
  # converted whenever the map or the job change screen starts, which also catches new companions.
  def self.install_point_hooks
    Foo::JobChange::Window_Popup.class_eval do
      alias_method :mgq_level_cap_make_command_list, :make_command_list
      def make_command_list
        return mgq_level_cap_make_command_list unless @actor_ok && MGQ_LevelCap.active?

        mgq_level_cap_make_command_list
        cancel = @list.pop
        add_command("Allocate", :mgq_level_cap_allocate)
        add_command("Reset", :mgq_level_cap_reset)
        @list.push(cancel)
      end

      alias_method :mgq_level_cap_window_height, :window_height
      def window_height
        @actor_ok && MGQ_LevelCap.active? ? fitting_height(5) : mgq_level_cap_window_height
      end
    end

    Scene_JobChange.class_eval do
      alias_method :mgq_level_cap_start, :start
      def start
        MGQ_LevelCap.convert_party
        mgq_level_cap_start
      end

      alias_method :mgq_level_cap_create_popup_window, :create_popup_window
      def create_popup_window
        mgq_level_cap_create_popup_window
        mgq_level_cap_create_windows
      end

      alias_method :mgq_level_cap_process_class_ok, :process_class_ok
      def process_class_ok
        actor = change_actor
        class_id = @class_name_window.select_class_id
        mgq_level_cap_process_class_ok
        begin
          MGQ_LevelCap.auto_master(actor, class_id)
          @result_popup_window.refresh
        rescue => e
          MGQ_LevelCap.log("auto_master FAILED: #{e.class}: #{e.message}")
        end
      end
    end

    Scene_Map.class_eval do
      alias_method :mgq_level_cap_start, :start
      def start
        MGQ_LevelCap.convert_party
        mgq_level_cap_start
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
              "#{mgq_level_cap_full_text(full)}: #{full[2]} of #{full[3]} slots taken.")
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

  # @return [Array(Array<Integer>, Array<Integer>), nil] the character's counts and slots of the
  #   kind shown, nil without a character (the job library) or while no limits apply
  def mgq_level_cap_tier_state
    actor = @class_name.actor
    kind = [:job, :race][@class_type_id]
    limits = actor && kind && MGQ_LevelCap.limits(actor, kind)
    limits && [MGQ_LevelCap.counts(actor, kind), limits.dup]
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

module MGQ_LevelCap
  # The width in pixels of the allocation windows.
  WINDOW_WIDTH = 520

  # Shows a character's free and total points above the slot list, and how to change slots.
  class Window_Points < Window_Base
    def initialize
      super((Graphics.width - WINDOW_WIDTH) / 2, 0, WINDOW_WIDTH, fitting_height(2))
      self.z = 600
      self.back_opacity = 255
      @actor = nil
      hide
    end

    # @param actor [Game_Actor] the character shown
    def actor=(actor)
      @actor = actor
      refresh
    end

    # Draws the character's name and points, and the keys below.
    def refresh
      contents.clear
      return unless @actor

      free = MGQ_LevelCap.free_points(@actor)
      change_color(normal_color)
      draw_text(0, 0, contents_width, line_height, @actor.name)
      change_color(free < 0 ? text_color(OVER_COLOR) : system_color)
      draw_text(0, 0, contents_width, line_height, "#{free} of #{MGQ_LevelCap.points} points free", 2)
      change_color(normal_color, false)
      draw_text(0, line_height, contents_width, line_height, "←/→ Remove or add a slot")
    rescue => e
      MGQ_LevelCap.log("points window FAILED: #{e.class}: #{e.message}")
    end
  end

  # Lists the ten tiers, jobs then races, each with its taken and bought slots, its price and how
  # many jobs or races of it the character ever had mastered. ←/→ refund or buy a slot.
  class Window_Slots < Window_Selectable
    # The rows: kind and tier.
    ROWS = [:job, :race].product([1, 2, 3, 4, 5])

    # @param y [Integer] the window's top
    def initialize(y)
      super((Graphics.width - WINDOW_WIDTH) / 2, y, WINDOW_WIDTH, fitting_height(ROWS.size))
      self.z = 600
      self.back_opacity = 255
      @actor = nil
      hide
      deactivate
    end

    # @return [Integer] the rows, none without a character
    def item_max
      @actor ? ROWS.size : 0
    end

    # @param actor [Game_Actor] the character shown
    def actor=(actor)
      @actor = actor
      refresh
      select(0)
    end

    # Draws a tier: its name, "taken/slots", its price and the remembered masteries. A tier the
    # story has not opened yet is greyed out.
    #
    # @param index [Integer] the row
    def draw_item(index)
      kind, tier = ROWS[index]
      record = MGQ_LevelCap.record(@actor)
      return unless record

      rect = item_rect_for_text(index)
      open = tier <= MGQ_LevelCap.open_tier(kind)
      count = MGQ_LevelCap.counts(@actor, kind)[tier - 1]
      slots = record[:slots][kind][tier - 1]
      mastered = record[:mastered][kind][tier - 1]
      change_color(normal_color, open)
      draw_text(rect.x, rect.y, 185, rect.height, "#{TIERS[tier - 1]} #{kind == :job ? 'jobs' : 'races'}")
      change_color(slot_color(count, slots), open)
      draw_text(rect.x + 185, rect.y, 60, rect.height, "#{count}/#{slots}", 2)
      change_color(normal_color, open)
      draw_text(rect.x + 265, rect.y, 105, rect.height, open ? "#{PRICES[kind][tier - 1]} pts" : "Opens later")
      draw_text(rect.x + 370, rect.y, rect.width - 370, rect.height, "#{mastered} mastered", 2) if mastered > 0
    rescue => e
      MGQ_LevelCap.log("slot row FAILED: #{e.class}: #{e.message}")
    end

    # @param count [Integer] the jobs or races taken in the tier
    # @param slots [Integer] the tier's slots
    # @return [Color] white with room left, yellow when full, orange when over
    def slot_color(count, slots)
      return normal_color if count < slots || slots.zero?

      text_color(count == slots ? FULL_COLOR : OVER_COLOR)
    end

    # Buys a slot of the tier under the cursor.
    def cursor_right(wrap = false)
      change_slot(1)
    end

    # Refunds a slot of the tier under the cursor.
    def cursor_left(wrap = false)
      change_slot(-1)
    end

    # @param step [Integer] 1 to buy, -1 to refund
    def change_slot(step)
      kind, tier = ROWS[index]
      return Sound.play_buzzer unless MGQ_LevelCap.change_slot(@actor, kind, tier, step)

      Sound.play_cursor
      redraw_item(index)
      call_handler(:change)
    end
  end

  # A short list to pick from: the Basic job to keep, the Basic race to keep, then Reset or Cancel.
  class Window_Choice < Window_Command
    def initialize
      @choices = []
      super(0, 0)
      self.z = 600
      self.back_opacity = 255
      hide
      deactivate
    end

    # @return [Integer] the window's width in pixels
    def window_width
      280
    end

    # @return [Integer] room for every choice, eight at most
    def window_height
      fitting_height([[@choices.size, 1].max, 8].min)
    end

    # Shows new choices in the middle of the screen.
    #
    # @param choices [Array<Array(String, Object)>] each shown name and the value it stands for
    def choices=(choices)
      @choices = choices
      self.height = window_height
      refresh
      select(0)
      self.x = (Graphics.width - width) / 2
      self.y = (Graphics.height - height) / 2
    end

    # Lists the choices, each with its value.
    def make_command_list
      @choices.each { |name, value| add_command(name, :ok, true, value) }
    end
  end
end

# The pages mods offer to other mods' screens, kept apart from every mod: whichever mod loads first
# defines it, so no mod names another.
module ModPages
  @pages = []

  # Adds a page once.
  #
  # @param page [Object] The page.
  def self.add(page)
    @pages << page unless @pages.include?(page)
  end

  # Lists the pages added, in their order.
  #
  # @return [Array<Object>] The pages.
  def self.all
    @pages.dup
  end
end unless defined?(ModPages)

module MGQ_LevelCap
  # The job and race points as a page another mod's screen may show, such as a tab of a world
  # overview: the characters in groups, each with a control per tier in the pane that Left and Right
  # buy and refund slots with, and a Reset button beside their name. Its answers follow ModPages'
  # usual page: title, shown?, head, groups, row, pane, adjust, menu and choose.
  class Page
    # Granberia's actor, whose portrait heads the page.
    GRANBERIA = 16

    # @return [String] The tab's title.
    def title
      "Level Cap"
    end

    # @return [Boolean] Whether the points apply now.
    def shown?
      $game_party && MGQ_LevelCap.active? ? true : false
    end

    # @return [Array] The head's title, note, lines and portrait: the prices, the open tiers and
    #   Granberia.
    def head
      opened = "Open: jobs up to #{TIERS[MGQ_LevelCap.open_tier(:job) - 1]}, races up to #{TIERS[MGQ_LevelCap.open_tier(:race) - 1]}."
      ["Job and race points", "#{MGQ_LevelCap.points} points",
       ["Slots cost #{PRICES[:job].join('/')} points (Basic to Forbidden), races double.", opened], looks($game_actors[GRANBERIA])]
    end

    # @return [Array<Array>] The party and the Pocket Castle, each with their characters' ids.
    def groups
      party = $game_party.all_members.select { |actor| MGQ_LevelCap.record(actor) }.map { |actor| actor.id }
      members = $game_party.respond_to?(:include_members) ? $game_party.include_members : $game_party.all_members
      castle = members.select { |actor| MGQ_LevelCap.record(actor) }.map { |actor| actor.id } - party
      [["Party", party], ["Pocket Castle", castle]].reject { |_, ids| ids.empty? }
    end

    # @param id [Integer] A character's actor id.
    # @return [Array] Their row: name, worn job and race, free points, not dimmed.
    def row(id)
      actor = $game_actors[id]
      [actor.name, "#{actor.class.name} / #{actor.tribe.name}", "#{MGQ_LevelCap.free_points(actor)} free", false]
    end

    # @param id [Integer] A character's actor id.
    # @return [Array] Their pane: name, looks, under Jobs and Races a control per tier with taken
    #   and bought slots, price and remembered masteries, toned by how full it is, and their free
    #   points under the name.
    def pane(id)
      actor = $game_actors[id]
      lines = []
      Window_Slots::ROWS.each_with_index do |(kind, tier), index|
        if tier == 1
          lines << [:gap] unless lines.empty?
          lines << [:text, kind == :job ? "Jobs" : "Races"]
        end
        lines << [:control, index, TIERS[tier - 1], slot_note(actor, kind, tier), tone(actor, kind, tier),
                  MGQ_LevelCap.can_remove?(actor, kind, tier) ? true : false, MGQ_LevelCap.can_add?(actor, kind, tier) ? true : false]
      end
      [actor.name, looks(actor), lines, "#{MGQ_LevelCap.free_points(actor)} of #{MGQ_LevelCap.points} points free"]
    end

    # Buys or refunds a slot of a tier.
    #
    # @param id [Integer] A character's actor id.
    # @param index [Integer] The tier's place in Window_Slots::ROWS.
    # @param step [Integer] 1 to buy, -1 to refund.
    # @return [String, nil] Why the slot did not change; nil once it did.
    def adjust(id, index, step)
      actor = $game_actors[id]
      kind, tier = Window_Slots::ROWS[index]
      return nil if MGQ_LevelCap.change_slot(actor, kind, tier, step)

      refusal(actor, kind, tier, step)
    end

    # Lists the Reset button, then after it the Basic job to keep, the Basic race to keep and the
    # confirmation.
    #
    # @param id [Integer] A character's actor id.
    # @param path [Array<Integer>] The button and the choices taken so far.
    # @return [Array<Array>] Each choice's text and whether it can be taken; none once path is whole.
    def menu(id, path)
      actor = $game_actors[id]
      return [] unless actor && MGQ_LevelCap.record(actor)

      case path.size
      when 0 then [["Reset", !MGQ_LevelCap.basic_choices(actor, :job).empty? && !MGQ_LevelCap.basic_choices(actor, :race).empty?]]
      when 1 then choices(actor, :job)
      when 2 then choices(actor, :race)
      when 3 then [["Reset", true], ["Cancel", true]]
      else []
      end
    end

    # Resets with the Basic job and race picked, once confirmed.
    #
    # @param id [Integer] A character's actor id.
    # @param path [Array<Integer>] The button and the choices taken.
    # @return [String, nil] What happened; nil for a reset called off.
    def choose(id, path)
      return nil unless path[3] == 0

      actor = $game_actors[id]
      job = MGQ_LevelCap.basic_choices(actor, :job)[path[1]]
      race = MGQ_LevelCap.basic_choices(actor, :race)[path[2]]
      MGQ_LevelCap.reset(actor, job, race) ? "Reset #{actor.name}'s jobs and races." : "#{actor.name} cannot be reset."
    end

    private

    # @param actor [Game_Actor, nil] A character.
    # @return [Array, nil] How they look: map sprite and face; nil without a character.
    def looks(actor)
      actor && [actor.character_name, actor.character_index, actor.face_name, actor.face_index]
    end

    # @param actor [Game_Actor] The character.
    # @param kind [Symbol] :job or :race
    # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
    # @return [String] Such as "1/2, 4 pts, 2 mastered".
    def slot_note(actor, kind, tier)
      record = MGQ_LevelCap.record(actor)
      mastered = record[:mastered][kind][tier - 1]
      note = "#{MGQ_LevelCap.counts(actor, kind)[tier - 1]}/#{record[:slots][kind][tier - 1]}, #{price_text(kind, tier)}"
      mastered > 0 ? "#{note}, #{mastered} mastered" : note
    end

    # @param actor [Game_Actor] The character.
    # @param kind [Symbol] :job or :race
    # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
    # @return [Symbol, nil] :dim before the story opens the tier, :bad with more classes than slots,
    #   :warn while full, :good with room left; nil without slots.
    def tone(actor, kind, tier)
      return :dim if tier > MGQ_LevelCap.open_tier(kind)

      count = MGQ_LevelCap.counts(actor, kind)[tier - 1]
      slots = MGQ_LevelCap.record(actor)[:slots][kind][tier - 1]
      if count > slots then :bad
      elsif count < slots then :good
      elsif slots > 0 then :warn
      end
    end

    # @param actor [Game_Actor] The character.
    # @param kind [Symbol] :job or :race
    # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
    # @param step [Integer] 1 to buy, -1 to refund.
    # @return [String] Why the slot cannot change.
    def refusal(actor, kind, tier, step)
      record = MGQ_LevelCap.record(actor)
      return "#{actor.name}'s slots cannot change now." unless record && MGQ_LevelCap.active?

      name = slot_name(kind, tier)
      if step > 0
        return "#{name} open later in the story." if tier > MGQ_LevelCap.open_tier(kind)

        "A slot of #{name} costs #{price_text(kind, tier)}; #{actor.name} has #{MGQ_LevelCap.free_points(actor)} free."
      elsif record[:slots][kind][tier - 1] <= FREE_SLOTS[kind][tier - 1]
        "#{actor.name} has no bought slot of #{name} to remove."
      else
        "Every slot of #{name} is taken; a reset frees them."
      end
    end

    # @param actor [Game_Actor] The character.
    # @param kind [Symbol] :job or :race
    # @return [Array<Array>] The Basic jobs or races a reset may keep.
    def choices(actor, kind)
      MGQ_LevelCap.basic_choices(actor, kind).map { |id| [$data_classes[id].name, true] }
    end

    # @param kind [Symbol] :job or :race
    # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
    # @return [String] A slot's price, such as "1 pt" or "6 pts".
    def price_text(kind, tier)
      price = PRICES[kind][tier - 1]
      price == 1 ? "1 pt" : "#{price} pts"
    end

    # @param kind [Symbol] :job or :race
    # @param tier [Integer] 1 (Basic) to 5 (Forbidden)
    # @return [String] Such as "Sealed jobs".
    def slot_name(kind, tier)
      "#{TIERS[tier - 1]} #{kind == :job ? 'jobs' : 'races'}"
    end
  end
end

# The character menu's Allocate opens the slot list; Reset asks for the Basic job
# and race to keep, resets and then opens the slot list.
class Scene_JobChange
  # Creates the allocation windows and connects the character menu's two commands.
  def mgq_level_cap_create_windows
    @mgq_level_cap_points = MGQ_LevelCap::Window_Points.new
    @mgq_level_cap_slots = MGQ_LevelCap::Window_Slots.new(0)
    top = (Graphics.height - @mgq_level_cap_points.height - @mgq_level_cap_slots.height) / 2
    @mgq_level_cap_points.y = top
    @mgq_level_cap_slots.y = top + @mgq_level_cap_points.height
    @mgq_level_cap_slots.set_handler(:change, method(:mgq_level_cap_slots_changed))
    @mgq_level_cap_slots.set_handler(:cancel, method(:mgq_level_cap_close_slots))
    @mgq_level_cap_choice = MGQ_LevelCap::Window_Choice.new
    @mgq_level_cap_choice.set_handler(:ok, method(:mgq_level_cap_choice_ok))
    @mgq_level_cap_choice.set_handler(:cancel, method(:mgq_level_cap_back_to_actors))
    @popup_window.set_handler(:mgq_level_cap_allocate, method(:mgq_level_cap_open_slots))
    @popup_window.set_handler(:mgq_level_cap_reset, method(:mgq_level_cap_start_reset))
  rescue => e
    MGQ_LevelCap.log("allocation windows FAILED: #{e.class}: #{e.message}")
  end

  # @return [Game_Actor] the character picked in the character list
  def mgq_level_cap_actor
    $game_actors[@actors_window.select_actor_id]
  end

  # Opens the slot list for the picked character.
  def mgq_level_cap_open_slots
    actor = mgq_level_cap_actor
    MGQ_LevelCap.remember_mastery(actor)
    @popup_window.hide.deactivate
    @mgq_level_cap_choice.hide.deactivate
    @mgq_level_cap_points.actor = actor
    @mgq_level_cap_points.show
    @mgq_level_cap_slots.actor = actor
    @mgq_level_cap_slots.show.activate
  end

  # Redraws the points after a slot was bought or refunded.
  def mgq_level_cap_slots_changed
    @mgq_level_cap_points.refresh
  end

  # Closes the slot list.
  def mgq_level_cap_close_slots
    @mgq_level_cap_points.hide
    @mgq_level_cap_slots.hide.deactivate
    mgq_level_cap_back_to_actors
  end

  # Returns to the character list, showing the picked character as they are now.
  def mgq_level_cap_back_to_actors
    @mgq_level_cap_choice.hide.deactivate
    @popup_window.hide.deactivate
    @help_window.text = "Please select a character"
    @actor_status_window.refresh
    @actors_window.activate
  end

  # Starts a reset with the Basic job to keep.
  def mgq_level_cap_start_reset
    @popup_window.hide.deactivate
    @mgq_level_cap_step = :job
    mgq_level_cap_offer(:job)
  end

  # Offers the character's Basic jobs or races to keep, and takes the only one without asking.
  #
  # @param kind [Symbol] :job or :race
  def mgq_level_cap_offer(kind)
    ids = MGQ_LevelCap.basic_choices(mgq_level_cap_actor, kind)
    if ids.empty?
      Sound.play_buzzer
      return mgq_level_cap_back_to_actors
    end
    @help_window.text = "Keep which Basic #{kind == :job ? 'job' : 'race'}?"
    @mgq_level_cap_choice.choices = ids.map { |id| [$data_classes[id].name, id] }
    return mgq_level_cap_choice_ok if ids.size == 1

    @mgq_level_cap_choice.show.activate
  end

  # Takes the job, then the race, then the confirmation, and resets.
  def mgq_level_cap_choice_ok
    value = @mgq_level_cap_choice.current_ext
    case @mgq_level_cap_step
    when :job
      @mgq_level_cap_job = value
      @mgq_level_cap_step = :race
      mgq_level_cap_offer(:race)
    when :race
      @mgq_level_cap_race = value
      @mgq_level_cap_step = :confirm
      @help_window.text = "Reset jobs and races? Points come back, base level stays."
      @mgq_level_cap_choice.choices = [["Reset", true], ["Cancel", false]]
      @mgq_level_cap_choice.show.activate
    else
      return mgq_level_cap_back_to_actors unless value

      done = MGQ_LevelCap.reset(mgq_level_cap_actor, @mgq_level_cap_job, @mgq_level_cap_race)
      return mgq_level_cap_back_to_actors unless done

      # The job list keeps what it answered for this character; a reset changes those answers.
      @class_name_window.actor_id = -1
      @help_window.text = "Please select a character"
      @actor_status_window.refresh
      mgq_level_cap_open_slots
    end
  rescue => e
    MGQ_LevelCap.log("reset FAILED: #{e.class}: #{e.message}")
    mgq_level_cap_back_to_actors
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
    ModPages.add(MGQ_LevelCap::Page.new)
  rescue => e
    MGQ_LevelCap.log("page FAILED: #{e.class}: #{e.message}")
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
