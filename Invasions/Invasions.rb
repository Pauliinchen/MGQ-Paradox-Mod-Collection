#----------------------------------------------------------------
#  Invasions.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Lets more monsters of the area join a random encounter or a boss fight while it runs. After each
# turn there is a chance that the game's own encounter roll for the tile the party stands on picks
# a troop, whose monsters join the battle before the next command phase; a boss fight on a map
# without encounters draws from the dungeon around it instead. Only the game that computes a battle
# rolls, so a game that plays another game's battle back never adds monsters of its own. Every
# entry point rescues, so the mod never stops the game.
module MGQ_Invasions
  # Turns the mod off without uninstalling it.
  ENABLED = true

  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR, which only appears when something went wrong.
  LOG_FILE = "Invasions.log"

  # Lines logged per session at most.
  MAX_LOG_LINES = 40

  # Option that sets the chance of an invasion each turn, its key in $game_system.conf.
  CHANCE_OPTION = :mod_invasions_chance

  # The chance each turn, in percent, until the player changes it.
  DEFAULT_CHANCE = 5

  # Option that sets how many invasions a battle gets at most, its key in $game_system.conf.
  MAX_OPTION = :mod_invasions_max

  # Invasions a battle gets at most until the player changes it.
  DEFAULT_MAX = 2

  # Option that lets boss fights get invasions, 1 for On and 0 for Off, its key in
  # $game_system.conf.
  BOSS_OPTION = :mod_invasions_bosses

  # Whether boss fights get invasions until the player changes it, 1 for On.
  DEFAULT_BOSSES = 1

  # Enemies a troop holds at most, standing or hidden; fallen ones free their place.
  TROOP_LIMIT = 8

  # Share of the narrower of two enemies' pictures that may hide behind the other.
  MAX_OVERLAP = 0.5

  # Share of a standing screen-wide picture, around its middle, that invaders keep clear of.
  WIDE_COVER = 0.5

  # Pixels between two places an invader may stand at.
  PLACE_STEP = 8

  # Width of a picture the game cannot measure.
  DEFAULT_WIDTH = 160

  # Width from which the game's troop setup stands a picture in the middle of the screen
  # (Game_Troop#auto_correct_bitmap_xy).
  WIDE_PICTURE = 640

  # Height from which the game's troop setup stands a picture at the bottom of the screen.
  TALL_PICTURE = 360

  # Troop name tag that keeps wide pictures where the troop places them.
  UNFIXED_TAG = /<画像非固定>/

  # The first game variable of the enemy ids that the talk and temptation common events read, one
  # per troop index.
  TALK_VARIABLE = 29

  # Troop indices those common events cover; variables past them belong to other things.
  TALK_SLOTS = 6

  # The game's alarm in Audio/SE, which sounds as the warning of an invasion opens.
  ALARM_SE = "mon_alarm"

  # Volume of the alarm.
  ALARM_VOLUME = 90

  # What the party is told when it tries to flee while invaders stand.
  SURROUNDED_TEXT = "You cannot flee as long as you are surrounded!"

  # Writes a line to the log, at most MAX_LOG_LINES per session.
  #
  # @param message [String] What happened.
  def self.log(message)
    @log_lines = (@log_lines || 0) + 1
    return if @log_lines > MAX_LOG_LINES

    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end

  # Reads one of the mod's options.
  #
  # Options are read at every roll, since a multiplayer world may set them while the game runs.
  #
  # @param key [Symbol] The option, its key in $game_system.conf.
  # @param default [Integer] Its value until the player changes it.
  # @return [Integer] The option's value.
  def self.option(key, default)
    value = $game_system.conf[key] rescue nil
    value.nil? ? default : value.to_i
  end

  # Reads the chance of an invasion each turn.
  #
  # @return [Integer] The chance in percent.
  def self.chance
    option(CHANCE_OPTION, DEFAULT_CHANCE)
  end

  # Reads how many invasions a battle gets at most.
  #
  # @return [Integer] The invasions.
  def self.max
    option(MAX_OPTION, DEFAULT_MAX)
  end

  # Tells whether boss fights may get invasions.
  #
  # @return [Boolean] Whether they may.
  def self.bosses?
    option(BOSS_OPTION, DEFAULT_BOSSES) != 0
  end

  # Rolls for an invasion at the end of a turn and keeps the troop it picks for the next command
  # phase.
  #
  # Only Scene_Battle#turn_end calls it, which runs only in the game that computes the battle. A
  # troop that would stand behind a screen-wide picture misses rather than waits, as such pictures
  # mostly belong to bosses that stand until the battle ends.
  def self.roll
    troop = $game_troop
    troop.mgq_invasions_first_turn ||= troop.turn_count
    return if troop.mgq_invasions_pending
    return unless chance > 0 && used < max

    map_id = list_map
    return unless map_id && encounters_on?(map_id) && !time_stop?
    return unless rand(100) < chance

    troop_id = pick(map_id)
    troop.mgq_invasions_pending = troop_id if invaders(troop_id).any? && !behind_wide?(troop_id)
  rescue => e
    log("roll FAILED: #{e.class}: #{e.message}")
  end

  # Finds the map whose encounter list the running battle's invaders come from: this map for a
  # random encounter of it or a boss fight on a map with encounters, the dungeon map around it for
  # a boss fight on a map without.
  #
  # @return [Integer, nil] The map, nil when the battle may not get invasions.
  def self.list_map
    return nil unless real_battle?

    map = $game_map
    return map.map_id if random_encounter?
    return nil unless boss_fight?

    map.encounter_list.empty? ? DUNGEON_MAPS[map.map_id] : map.map_id
  end

  # Tells whether time stop runs, which would freeze invaders the moment they join.
  #
  # @return [Boolean] Whether it does.
  def self.time_stop?
    party = $game_party
    party.respond_to?(:in_over_drive?) && party.in_over_drive? ? true : false
  end

  # Counts the invasions the running battle has used.
  #
  # A game that took over a battle after its first turn holds the invaders of the game that computed
  # it before but not their count, so there enemies past the troop's own that this game did not add
  # use up every invasion; the game that ended the first turn added every invader itself, and
  # enemies others brought into its battle use up none.
  #
  # @return [Integer] The invasions used.
  def self.used
    troop = $game_troop
    return troop.mgq_invasions_count if troop.mgq_invasions_first_turn == 1

    data = troop.troop
    own = data ? data.members.count { |member| $data_enemies[member.enemy_id] } : 0
    grown = troop.members.size - own
    grown > troop.mgq_invasions_added ? max : troop.mgq_invasions_count
  end

  # Tells whether the running battle is fought for real against the game's own enemies: no Library
  # replay, no challenge battle, no troop of other battlers.
  #
  # @return [Boolean] Whether it is.
  def self.real_battle?
    return false if $game_temp.respond_to?(:in_memory_battle) && $game_temp.in_memory_battle

    troop = $game_troop
    return false if troop.respond_to?(:challenge_battle?) && troop.challenge_battle?

    troop.members.all? { |member| member.is_a?(Game_Enemy) }
  end

  # Tells whether the running battle is a random encounter of the current map.
  #
  # BattleManager.can_escape? is false while an enemy binds the party, so its own flag is read.
  #
  # @return [Boolean] Whether it is.
  def self.random_encounter?
    manager = BattleManager
    return false unless manager.instance_variable_get(:@can_escape)
    return false if manager.instance_variable_get(:@can_lose)
    return false unless manager.instance_variable_get(:@event_proc).nil?

    data = $game_troop.troop
    data && $game_map.encounter_list.any? { |encounter| encounter.troop_id == data.id } ? true : false
  end

  # Tells whether the running battle is a boss fight of BOSSES while boss fights may get invasions.
  #
  # Boss fights are event battles that cannot be fled from or may be lost, so only the list tells
  # them from the story's other event battles, which never get invasions.
  #
  # @return [Boolean] Whether it is.
  def self.boss_fight?
    return false unless bosses?

    data = $game_troop.troop
    data && BOSSES.key?(data.id) ? true : false
  end

  # Tells whether a map allows encounters right now, and on the current map also the region the
  # party stands on.
  #
  # @param map_id [Integer] The map whose encounter list the invaders come from.
  # @return [Boolean] Whether they do.
  def self.encounters_on?(map_id)
    system = $game_system
    return false if system.encounter_disabled
    if system.respond_to?(:no_enemy_maps_get)
      return false if system.no_enemy_maps_get.include?(map_id)
    end
    return true unless map_id == $game_map.map_id
    if defined?(Game_System::EncountRegion::NONE) && $game_player.respond_to?(:encount_region)
      return false if $game_player.encount_region == Game_System::EncountRegion::NONE
    end
    true
  end

  # Picks the troop that invades: the game's own encounter roll for the tile the party stands on,
  # or a troop of another map's whole list by weight.
  #
  # The tile's region means nothing on another map, so no region narrows that list.
  #
  # @param map_id [Integer] The map whose encounter list the invaders come from.
  # @return [Integer] The troop, 0 for none.
  def self.pick(map_id)
    return $game_player.make_encounter_troop_id if map_id == $game_map.map_id

    list = encounter_list(map_id)
    value = rand([list.inject(0) { |sum, encounter| sum + encounter.weight }, 1].max)
    list.each do |encounter|
      value -= encounter.weight
      return encounter.troop_id if value < 0
    end
    0
  end

  # Loads a map's encounter list the way the game loads the map, once per map.
  #
  # @param map_id [Integer] The map.
  # @return [Array<RPG::Map::Encounter>] The list, empty when the map cannot be loaded.
  def self.encounter_list(map_id)
    @encounter_lists ||= {}
    @encounter_lists[map_id] ||= begin
      load_data(DataManager.map_file_name(map_id)).encounter_list
    rescue => e
      log("map #{map_id} FAILED: #{e.class}: #{e.message}")
      []
    end
  end

  # Lists the members of a troop that would join: those the troop does not hide, whose enemy the
  # database has.
  #
  # @param troop_id [Integer] The troop, 0 for none.
  # @return [Array<RPG::Troop::Member>] The members, none for an unknown troop.
  def self.invaders(troop_id)
    data = troop_id.to_i > 0 ? $data_troops[troop_id] : nil
    return [] unless data

    data.members.select { |member| !member.hidden && $data_enemies[member.enemy_id] }
  end

  # Tells whether a troop brings a picture as wide as the screen while one already stands there.
  #
  # @param troop_id [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.behind_wide?(troop_id)
    return false unless wide_standing?

    invaders(troop_id).any? do |member|
      full_width?(width($data_enemies[member.enemy_id].replace_data))
    end
  end

  # Tells whether an enemy on the screen has a picture as wide as the screen, which stands in its
  # middle.
  #
  # @return [Boolean] Whether one has.
  def self.wide_standing?
    standing.any? { |enemy| !enemy.hidden? && full_width?(width(enemy)) }
  end

  # Lets the troop picked at the end of the turn join the battle, before the command phase opens
  # so its monsters choose their actions with the others.
  #
  # A troop without room waits for a later command phase, since fallen enemies free their places.
  #
  # @param scene [Scene_Battle] The battle.
  def self.spawn(scene)
    troop = $game_troop
    troop_id = troop.mgq_invasions_pending
    return unless troop_id && spawn_time?(scene)

    enemies = build(troop_id)
    return unless enemies

    troop.mgq_invasions_pending = nil
    join(scene, enemies)
    troop.mgq_invasions_count += 1
    troop.mgq_invasions_added += enemies.size
  rescue => e
    troop.mgq_invasions_pending = nil if troop
    log("spawn FAILED: #{e.class}: #{e.message}")
  end

  # Tells whether the command phase opens after a turn of a battle still running.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Boolean] Whether it does.
  def self.spawn_time?(scene)
    return false if scene.scene_changing? || !BattleManager.turn_end?

    !(BattleManager.respond_to?(:battle_end?) && BattleManager.battle_end?)
  end

  # Builds a troop's members as the game's troop setup does and places them among the enemies on
  # the screen.
  #
  # @param troop_id [Integer] The troop.
  # @return [Array<Game_Enemy>, nil] The enemies, hidden, with their indices after the troop's
  #   members; nil when the troop has no room for them.
  def self.build(troop_id)
    data = $data_troops[troop_id]
    members = invaders(troop_id)
    return nil if members.empty? || standing.size + members.size > TROOP_LIMIT

    first = $game_troop.members.size
    enemies = members.each_with_index.map do |member, offset|
      enemy = Game_Enemy.new(first + offset, $data_enemies[member.enemy_id].replace_data.id)
      enemy.screen_x, enemy.screen_y = scaled(member.x, member.y)
      correct(enemy, data)
      enemy
    end
    return nil unless place(members, enemies)

    enemies.each do |enemy|
      enemy.on_battle_start
      enemy.hide
    end
    enemies
  end

  # Scales a troop place from the editor's 544x416 screen to the game's screen, as the game's
  # troop setup does.
  #
  # @param x [Integer] The place's x in the editor.
  # @param y [Integer] Its y.
  # @return [Array(Integer, Integer)] The place on the game's screen.
  def self.scaled(x, y)
    width = defined?($VXA_O_WIDTH) && $VXA_O_WIDTH
    height = defined?($VXA_O_HEIGHT) && $VXA_O_HEIGHT
    return [x, y] unless width && height

    [(x * (Graphics.width * 1.0 / width)).to_i, (y * (Graphics.height * 1.0 / height)).to_i]
  end

  # Moves a wide picture to the middle and a tall one to the bottom of the screen, as the game's
  # troop setup does.
  #
  # The game's own correction disposes the cached picture, which the sprites of enemies already on
  # the screen may show, so the picture is only measured here.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @param data [RPG::Troop] The troop it comes from, whose name may keep wide pictures in place.
  def self.correct(enemy, data)
    bitmap = picture(enemy)
    return unless bitmap

    enemy.screen_x = Graphics.width / 2 if bitmap.width >= WIDE_PICTURE && data.name !~ UNFIXED_TAG
    enemy.screen_y = bitmap.height if bitmap.height >= TALL_PICTURE
  end

  # Loads an enemy's picture from the game's cache.
  #
  # @param enemy [Game_Enemy, RPG::Enemy] The enemy, in battle or in the database.
  # @return [Bitmap, nil] The picture, nil when it cannot be loaded.
  def self.picture(enemy)
    Cache.battler(enemy.battler_name, enemy.battler_hue)
  rescue
    nil
  end

  # Measures an enemy's picture.
  #
  # @param enemy [Game_Enemy, RPG::Enemy] The enemy, in battle or in the database.
  # @return [Integer] Its width, DEFAULT_WIDTH when unknown.
  def self.width(enemy)
    bitmap = picture(enemy)
    bitmap ? bitmap.width : DEFAULT_WIDTH
  end

  # Lists the enemies that hold a place in the troop: all but the fallen.
  #
  # @return [Array<Game_Enemy>] The enemies standing or hidden.
  def self.standing
    $game_troop.members.reject { |enemy| fallen?(enemy) }
  end

  # Tells whether an enemy has fallen, also one hidden after its defeat, so its place is free.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Boolean] Whether it has.
  def self.fallen?(enemy)
    enemy.dead? || (enemy.hidden? && enemy.death_state?) ? true : false
  end

  # Tells whether a picture is as wide as the screen.
  #
  # @param width [Integer] The picture's width.
  # @return [Boolean] Whether it is.
  def self.full_width?(width)
    width >= Graphics.width
  end

  # Tells the part of the screen a standing enemy covers for placing invaders.
  #
  # Invaders draw behind the enemies already there, so a screen-wide picture keeps them off its
  # middle, but only WIDE_COVER of it, or no invader would ever find room beside it.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Array(Integer, Integer)] The left and right edges.
  def self.cover(enemy)
    picture_width = width(enemy)
    picture_width = (picture_width * WIDE_COVER).to_i if full_width?(picture_width)
    span(enemy.screen_x, picture_width)
  end

  # Places the invaders where at most MAX_OVERLAP of each picture hides behind another. Members at
  # the same place in their troop are one picture in parts and move together.
  #
  # A screen-wide picture keeps the middle the troop setup gave it, so it only finds a place while
  # no other screen-wide picture stands there.
  #
  # @param members [Array<RPG::Troop::Member>] The troop's members that join.
  # @param enemies [Array<Game_Enemy>] Their enemies in the same order, moved in place.
  # @return [Boolean] Whether every one found a place.
  def self.place(members, enemies)
    taken = standing.reject(&:hidden?).map { |enemy| cover(enemy) }
    wide = wide_standing?
    groups(members, enemies).each do |group|
      widest = group.map { |enemy| width(enemy) }.max
      if full_width?(widest)
        return false if wide

        wide = true
        next
      end

      x = free_x(widest, taken)
      return false unless x

      group.each { |enemy| enemy.screen_x = x }
      taken << span(x, widest)
    end
    true
  end

  # Groups the invaders by their place in the troop.
  #
  # @param members [Array<RPG::Troop::Member>] The troop's members that join.
  # @param enemies [Array<Game_Enemy>] Their enemies in the same order.
  # @return [Array<Array<Game_Enemy>>] The enemies of each place, in troop order.
  def self.groups(members, enemies)
    places = []
    groups = {}
    members.each_with_index do |member, index|
      place = [member.x, member.y]
      places << place unless groups[place]
      (groups[place] ||= []) << enemies[index]
    end
    places.map { |place| groups[place] }
  end

  # Finds the place on the screen where a picture hides least behind the others, the nearest to the
  # middle among equals.
  #
  # @param width [Integer] The picture's width.
  # @param taken [Array<Array(Integer, Integer)>] The others' left and right edges.
  # @return [Integer, nil] The picture's middle, nil when every place hides more than MAX_OVERLAP.
  def self.free_x(width, taken)
    screen = Graphics.width
    half = width / 2
    spots = (half..(screen - half)).step(PLACE_STEP).to_a
    best = spots.min_by { |x| [crowding(x - half, x + half, taken), (x - screen / 2).abs] }
    best && crowding(best - half, best + half, taken) <= MAX_OVERLAP ? best : nil
  end

  # Measures how much a picture hides behind others, or they behind it.
  #
  # @param left [Integer] The picture's left edge.
  # @param right [Integer] Its right edge.
  # @param taken [Array<Array(Integer, Integer)>] The others' left and right edges.
  # @return [Float] The largest share of the narrower of two pictures that the other covers.
  def self.crowding(left, right, taken)
    shares = taken.map do |other_left, other_right|
      overlap = [right, other_right].min - [left, other_left].max
      narrower = [right - left, other_right - other_left].min
      overlap > 0 ? overlap.to_f / [narrower, 1].max : 0.0
    end
    shares.max || 0.0
  end

  # Tells the left and right edges of a picture.
  #
  # @param x [Integer] Its middle, an enemy's screen x.
  # @param width [Integer] Its width.
  # @return [Array(Integer, Integer)] The edges.
  def self.span(x, width)
    [x - width / 2, x + width / 2]
  end

  # Warns of the invasion, then adds the invaders to the troop, fades them in and announces them.
  #
  # The troop's indices name enemies in actions, battle events and the talk variables, so the
  # invaders only ever go to the end.
  #
  # @param scene [Scene_Battle] The battle.
  # @param enemies [Array<Game_Enemy>] The invaders, hidden.
  def self.join(scene, enemies)
    warn(scene)
    troop = $game_troop
    enemies.each { |enemy| troop.members.push(enemy) }
    enemies.each { |enemy| enemy.mgq_invader = true }
    @seen = troop.members.dup
    enemies.each { |enemy| set_talk(enemy) }
    BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
    discover(enemies)
    redraw(scene)
    enemies.each(&:appear)
    troop.send(:make_unique_names)
    scene.send(:wait_for_effect)
    enemies.each { |enemy| $game_message.add(format(Vocab::Emerge, enemy.name)) }
    scene.send(:wait_for_message)
  end

  # Shows the warning with the alarm and lets the battle run until it closes.
  #
  # The battle's frame update moves the warning on, see Warning.update; the loop stops after
  # Warning::FRAMES even when nothing does.
  #
  # @param scene [Scene_Battle] The battle.
  def self.warn(scene)
    Warning.show(true)
    Warning::FRAMES.times do
      break unless Warning.active?

      scene.send(:update_for_wait)
    end
    Warning.dispose
  end

  # Notices enemies that joined the running battle without this game's invasion, such as those a
  # multiplayer host's invasion adds to a game that plays its battle back: marks them as invaders and
  # shows the warning without the alarm, which the host's game sounds. Called every frame of a
  # battle.
  #
  # Only enemies added after those this game already saw count; a troop whose first enemies changed
  # was set up anew and is only noted.
  def self.watch
    members = $game_troop.members
    seen = @seen
    return if seen && members.size == seen.size && members.last.equal?(seen.last)

    @seen = members.dup
    return unless seen && members.size > seen.size
    return unless members.first(seen.size).zip(seen).all? { |now, before| now.equal?(before) }

    joined = members.drop(seen.size).select { |enemy| enemy.is_a?(Game_Enemy) }
    return if joined.empty?

    joined.each { |enemy| enemy.mgq_invader = true }
    Warning.show(false)
  rescue => e
    log("watch FAILED: #{e.class}: #{e.message}")
  end

  # Forgets the enemies watch saw, as a new battle sets its troop up.
  def self.forget_seen
    @seen = nil
  end

  # Tells whether invaders stand in the battle, which keeps the party from fleeing.
  #
  # @return [Boolean] Whether any invader is alive and shown.
  def self.surrounded?
    $game_troop.members.any? { |enemy| enemy.is_a?(Game_Enemy) && enemy.mgq_invader? && enemy.exist? }
  rescue => e
    log("surrounded FAILED: #{e.class}: #{e.message}")
    false
  end

  # Turns the party's Escape command down while invaders stand: tells why and opens the party's
  # commands again, so the turn is not lost.
  #
  # @param scene [Scene_Battle] The battle.
  def self.refuse_escape(scene)
    Sound.play_buzzer
    $game_message.add(SURROUNDED_TEXT)
    scene.send(:wait_for_message)
    scene.send(:start_party_command_selection)
  end

  # Turns an escape skill or item of the party down while invaders stand, telling why.
  def self.refuse_forced_escape
    $game_message.add(SURROUNDED_TEXT)
    BattleManager.wait_for_message
  end

  # Writes an invader's id where the talk and temptation common events look for it.
  #
  # The troop's own turn event writes only its own members' ids, so without this an invader would
  # talk with the id an earlier battle left behind.
  #
  # @param enemy [Game_Enemy] The invader.
  def self.set_talk(enemy)
    return unless enemy.index < TALK_SLOTS

    $game_variables[TALK_VARIABLE + enemy.index] = enemy.enemy_id
  end

  # Marks the invaders as seen in the monster library, as the battle start does for the others.
  #
  # @param enemies [Array<Game_Enemy>] The invaders.
  def self.discover(enemies)
    return unless defined?($game_library) && $game_library && $game_library.respond_to?(:enemy)

    library = $game_library.enemy
    library.set_discovery(enemies.map(&:id)) if library.respond_to?(:set_discovery)
  rescue => e
    log("library FAILED: #{e.class}: #{e.message}")
  end

  # Builds the enemies' sprites anew, which creates those of the invaders while they are hidden so
  # they fade in once they appear.
  #
  # @param scene [Scene_Battle] The battle.
  def self.redraw(scene)
    spriteset = scene.instance_variable_get(:@spriteset)
    return unless spriteset

    spriteset.dispose_enemies
    spriteset.create_enemies
  end

  # The warning an invasion shows in the middle of the screen, after the boss warnings of arcade
  # shooters: a box between two bands of moving caution tape, WARNING flashing in red between two
  # warning signs, the screen pulsing red, and the game's alarm.
  module Warning
    # Frames the warning stays, about as long as the alarm sounds.
    FRAMES = 150

    # Frames the box takes to open, and to close again.
    OPEN_FRAMES = 10

    # Frames WARNING stays lit, and then dimmed, in each flash.
    BLINK_FRAMES = 20

    # Opacity of WARNING while dimmed.
    DIM_OPACITY = 60

    # Frames of one pulse of the red over the screen, strongest while WARNING is lit.
    PULSE_FRAMES = BLINK_FRAMES * 2

    # Opacity of the red over the screen at its strongest.
    TINT_OPACITY = 72

    # Height of the box, which spans the screen's width.
    HEIGHT = 116

    # Opacity of the box behind its text.
    BOX_ALPHA = 150

    # Opacity of the caution tape.
    TAPE_OPACITY = 200

    # Height of each band of caution tape.
    TAPE = 12

    # Width of one stripe of the tape.
    STRIPE = 12

    # Height of the line with WARNING and its signs.
    TITLE_HEIGHT = 54

    # Pixels between the top tape and the line with WARNING.
    TITLE_GAP = 4

    # Height of a warning sign.
    SIGN = 36

    # Pixels between WARNING and each warning sign.
    SIGN_GAP = 16

    # Above every window of the battle.
    Z = 500

    # What the box says below WARNING.
    TEXT = "Monsters are invading!"

    # Shows the warning anew.
    #
    # @param sound [Boolean] Whether the alarm sounds; a game that plays another game's battle back
    #   hears that game's.
    def self.show(sound)
      dispose
      build
      @frame = 0
      update_sprites
      alarm if sound
    rescue => e
      MGQ_Invasions.log("warning FAILED: #{e.class}: #{e.message}")
      dispose
    end

    # Tells whether the warning shows.
    #
    # @return [Boolean] Whether it does.
    def self.active?
      !@frame.nil?
    end

    # Moves the warning on by a frame and closes it after FRAMES. Called every frame of a battle.
    def self.update
      return unless @frame

      @frame += 1
      return dispose if @frame >= FRAMES

      update_sprites
    rescue => e
      MGQ_Invasions.log("warning update FAILED: #{e.class}: #{e.message}")
      dispose
    end

    # Takes the warning off the screen.
    def self.dispose
      @frame = nil
      Array(@sprites).each do |sprite|
        sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
        sprite.dispose unless sprite.disposed?
      end
      @sprites = nil
      @viewport.dispose if @viewport && !@viewport.disposed?
      @viewport = nil
    rescue
      @sprites = nil
      @viewport = nil
    end

    # Sounds the game's alarm.
    def self.alarm
      RPG::SE.new(ALARM_SE, ALARM_VOLUME, 100).play
    rescue => e
      MGQ_Invasions.log("alarm FAILED: #{e.class}: #{e.message}")
    end

    # Makes the warning's sprites, the box closed.
    def self.build
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = Z
      @tint = sprite(Bitmap.new(Graphics.width, Graphics.height), 0, 0, 0, 0)
      @tint.bitmap.fill_rect(@tint.bitmap.rect, Color.new(255, 0, 0))
      @box = sprite(box_bitmap, center_x, HEIGHT / 2, center_x, center_y)
      @tapes = [0, HEIGHT - TAPE].map do |top|
        tape = sprite(tape_bitmap, center_x, HEIGHT / 2 - top, center_x, center_y)
        tape.src_rect.set(0, 0, width, TAPE)
        tape.opacity = TAPE_OPACITY
        tape
      end
      @title = sprite(title_bitmap, center_x, HEIGHT / 2 - TAPE - TITLE_GAP, center_x, center_y)
      @sprites = [@tint, @box] + @tapes + [@title]
      @sprites.each_with_index { |part, layer| part.z = layer }
    end

    # Makes a sprite of the warning.
    #
    # @param bitmap [Bitmap] What it shows.
    # @param ox [Integer] Its origin's x on the bitmap.
    # @param oy [Integer] Its origin's y on the bitmap; parts of the box take the box's middle, so
    #   they open and close around it together.
    # @param x [Integer] Where its origin stands on the screen.
    # @param y [Integer] Where its origin stands on the screen.
    # @return [Sprite] The sprite.
    def self.sprite(bitmap, ox, oy, x, y)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = bitmap
      sprite.ox = ox
      sprite.oy = oy
      sprite.x = x
      sprite.y = y
      sprite
    end

    # Tells the box's width, the screen's.
    #
    # @return [Integer] The width.
    def self.width
      Graphics.width
    end

    # Tells the middle of the screen's width.
    #
    # @return [Integer] The x.
    def self.center_x
      width / 2
    end

    # Tells the middle of the screen's height.
    #
    # @return [Integer] The y.
    def self.center_y
      Graphics.height / 2
    end

    # Draws the box: dark but showing the battle through, red lines along the tape, the text below
    # WARNING.
    #
    # @return [Bitmap] The box.
    def self.box_bitmap
      bitmap = Bitmap.new(width, HEIGHT)
      bitmap.fill_rect(bitmap.rect, Color.new(0, 0, 0, BOX_ALPHA))
      red = Color.new(230, 30, 30)
      bitmap.fill_rect(0, TAPE, width, 2, red)
      bitmap.fill_rect(0, HEIGHT - TAPE - 2, width, 2, red)
      bitmap.font.size = 20
      bitmap.font.bold = true
      bitmap.font.color = Color.new(255, 255, 255)
      top = TAPE + TITLE_GAP + TITLE_HEIGHT
      bitmap.draw_text(0, top, width, HEIGHT - TAPE - top, TEXT, 1)
      bitmap
    end

    # Draws a band of caution tape, red and black stripes slanting, two stripes wider than the box
    # so it can move by that much and start over.
    #
    # @return [Bitmap] The tape.
    def self.tape_bitmap
      bitmap = Bitmap.new(width + STRIPE * 2, TAPE)
      bitmap.fill_rect(bitmap.rect, Color.new(20, 20, 20))
      red = Color.new(220, 25, 25)
      TAPE.times do |row|
        x = -row
        while x < bitmap.width
          bitmap.fill_rect(x, row, STRIPE, 1, red)
          x += STRIPE * 2
        end
      end
      bitmap
    end

    # Draws the line that flashes: WARNING in red between two yellow warning signs.
    #
    # @return [Bitmap] The line.
    def self.title_bitmap
      bitmap = Bitmap.new(width, TITLE_HEIGHT)
      bitmap.font.size = 44
      bitmap.font.bold = true
      bitmap.font.color = Color.new(255, 40, 40)
      bitmap.font.out_color = Color.new(90, 0, 0) if bitmap.font.respond_to?(:out_color=)
      reach = bitmap.text_size("WARNING").width / 2 + SIGN_GAP + SIGN / 2
      bitmap.draw_text(0, 0, width, TITLE_HEIGHT, "WARNING", 1)
      top = (TITLE_HEIGHT - SIGN) / 2
      draw_sign(bitmap, center_x - reach, top)
      draw_sign(bitmap, center_x + reach, top)
      bitmap
    end

    # Draws a warning sign: a yellow triangle with a black exclamation mark.
    #
    # @param bitmap [Bitmap] Where.
    # @param middle [Integer] The sign's middle on the bitmap.
    # @param top [Integer] The sign's top on the bitmap.
    def self.draw_sign(bitmap, middle, top)
      yellow = Color.new(255, 200, 0)
      SIGN.times do |row|
        half = row / 2 + 1
        bitmap.fill_rect(middle - half, top + row, half * 2, 1, yellow)
      end
      bitmap.font.size = 24
      bitmap.font.bold = true
      bitmap.font.color = Color.new(0, 0, 0)
      bitmap.draw_text(middle - SIGN / 2, top + 8, SIGN, SIGN - 8, "!", 1)
    end

    # Places the sprites for the current frame: the box opening or closing, WARNING lit or dimmed,
    # the tape moved on and the red over the screen pulsing.
    def self.update_sprites
      open = [[@frame, FRAMES - @frame].min.to_f / OPEN_FRAMES, 1.0].min
      ([@box, @title] + @tapes).each { |sprite| sprite.zoom_y = open }
      @title.opacity = (@frame / BLINK_FRAMES).even? ? 255 : DIM_OPACITY
      shift = @frame % (STRIPE * 2)
      @tapes.each { |tape| tape.src_rect.x = shift }
      pulse = (Math.sin(@frame * 2 * Math::PI / PULSE_FRAMES) + 1) / 2
      @tint.opacity = (TINT_OPACITY * pulse * open).to_i
    end
  end

  # The mod's options in the Mod Config menu.
  module Options
    # The chances an invasion can have each turn, in percent, by their name and help in the menu.
    CHANCES = [0, 1, 2, 3, 5, 10, 15, 20, 25, 50, 100].each_with_object({}) do |percent, values|
      values[percent] = if percent == 0
                          ["Off", "No invasions."]
                        else
                          ["#{percent}%", "#{percent}% each turn."]
                        end
    end

    # The invasions a battle can get at most, by their name and help in the menu.
    MAXIMUMS = (1..5).each_with_object({}) do |count, values|
      values[count] = [count.to_s, "#{count} invasion#{count == 1 ? '' : 's'} a battle."]
    end

    # On and Off, by their name and help in the menu.
    SWITCH = {
      1 => ["On", "Boss fights get invasions."],
      0 => ["Off", "Boss fights get none."],
    }

    # Adds the options before the menu's last entry, which returns.
    #
    # The Mod Config Menu or Mod Config Remake defines MOD_CONTENTS, and the mod loader runs both
    # before this script.
    def self.register
      config = NWConst::Config
      menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS
      add(menu, CHANCE_OPTION, "[Invasions] Invasion Chance", CHANCES, DEFAULT_CHANCE,
          "The chance after each turn of a random encounter or boss fight that more monsters of " \
          "the area join the battle, as often as Invasions per Battle allows.")
      add(menu, MAX_OPTION, "     -> Invasions per Battle", MAXIMUMS, DEFAULT_MAX,
          "How many times more monsters can join one battle.")
      add(menu, BOSS_OPTION, "     -> In Boss Battles", SWITCH, DEFAULT_BOSSES,
          "Lets more monsters join story boss fights, including optional ones, too.")
    end

    # Adds an option before the menu's last entry.
    #
    # @param menu [Array<Hash>] The menu's entries.
    # @param key [Symbol] The option, its key in $game_system.conf.
    # @param name [String] Its name in the menu.
    # @param values [Hash{Integer => Array(String, String)}] Its values by their name and help.
    # @param default [Integer] Its value until the player changes it.
    # @param help [String] Its help in the menu.
    def self.add(menu, key, name, values, default, help)
      config = NWConst::Config
      menu.insert(-2, :key => key, :name => name, :sub => true, :help => "#{help}\r\n←/→ Toggle")
      config::DATA[key] = values.keys
      config::DATA_TEXT[key] = {}
      values.each do |value, (label, text)|
        config::DATA_TEXT[key][value] = { :name => label, :help => text }
      end
      config::DEFAULT[key] = default
    end
  end
end

# Game hooks.
#
# Each wraps a game method: the mod does its part first, rescuing its own errors, and the original
# always runs.
module MGQ_Invasions
  # Installs the hooks, once. The translation's plugins load after the Patch folder and define
  # battle methods anew, so the hooks go in once the first scene starts and wrap whatever the
  # plugins left.
  def self.install
    return if @installed || Scene_Battle.method_defined?(:mgq_invasions_turn_end)

    @installed = true
    install_troop_hooks
    install_battle_hooks
  rescue => e
    log("install FAILED: #{e.class}: #{e.message}")
  end

  # A new battle or a retry clears the troop, and with it the invasion picked and the invasions
  # counted.
  def self.install_troop_hooks
    Game_Troop.class_eval do
      alias_method :mgq_invasions_clear, :clear
      # Clears the troop and the mod's state of the battle.
      def clear
        mgq_invasions_clear
        @mgq_invasions_pending = nil
        @mgq_invasions_count = 0
        @mgq_invasions_added = 0
        @mgq_invasions_first_turn = nil
        MGQ_Invasions.forget_seen
      end
    end
  end

  # The roll comes at the end of a turn, which only the game that computes the battle reaches; the
  # invaders join at the command phase that follows.
  def self.install_battle_hooks
    Scene_Battle.class_eval do
      alias_method :mgq_invasions_turn_end, :turn_end
      # Rolls for an invasion, then ends the turn.
      def turn_end
        MGQ_Invasions.roll
        mgq_invasions_turn_end
      end

      alias_method :mgq_invasions_start_party_command_selection, :start_party_command_selection
      # Lets an invasion picked at the end of the turn join, then opens the command phase.
      def start_party_command_selection
        MGQ_Invasions.spawn(self)
        mgq_invasions_start_party_command_selection
      end

      alias_method :mgq_invasions_update_basic, :update_basic
      # Updates the battle, then notices enemies that joined it and moves the warning on.
      def update_basic
        mgq_invasions_update_basic
        MGQ_Invasions.watch
        MGQ_Invasions::Warning.update
      end

      alias_method :mgq_invasions_terminate, :terminate
      # Takes the warning off the screen, then ends the battle.
      def terminate
        MGQ_Invasions::Warning.dispose
        mgq_invasions_terminate
      end

      alias_method :mgq_invasions_command_escape, :command_escape
      # Flees, unless invaders stand.
      def command_escape
        return mgq_invasions_command_escape unless MGQ_Invasions.surrounded?

        begin
          MGQ_Invasions.refuse_escape(self)
        rescue => e
          MGQ_Invasions.log("refusing to flee FAILED: #{e.class}: #{e.message}")
          mgq_invasions_command_escape
        end
      end
    end
    install_escape_hook
  end

  # An escape skill or item of the party goes through BattleManager.process_forced_escape, which
  # invaders keep from fleeing too.
  def self.install_escape_hook
    return unless BattleManager.respond_to?(:process_forced_escape)

    BattleManager.singleton_class.class_eval do
      alias_method :mgq_invasions_process_forced_escape, :process_forced_escape
      # Flees, unless invaders stand.
      def process_forced_escape
        return mgq_invasions_process_forced_escape unless MGQ_Invasions.surrounded?

        begin
          MGQ_Invasions.refuse_forced_escape
        rescue => e
          MGQ_Invasions.log("refusing to flee FAILED: #{e.class}: #{e.message}")
          mgq_invasions_process_forced_escape
        end
      end
    end
  end
end

# The invasion picked and the invasions counted live in the troop, so a new battle, a retry and
# the battle's retry snapshot each carry their own.
class Game_Troop
  # Reads the troop picked to join at the next command phase.
  #
  # @return [Integer, nil] The troop, nil for none.
  def mgq_invasions_pending
    @mgq_invasions_pending
  end

  # Sets the troop to join at the next command phase.
  #
  # @param troop_id [Integer, nil] The troop, nil for none.
  def mgq_invasions_pending=(troop_id)
    @mgq_invasions_pending = troop_id
  end

  # Reads the invasions of this battle so far.
  #
  # @return [Integer] The count, 0 in a troop from before the mod.
  def mgq_invasions_count
    @mgq_invasions_count.to_i
  end

  # Sets the invasions of this battle so far.
  #
  # @param count [Integer] The count.
  def mgq_invasions_count=(count)
    @mgq_invasions_count = count
  end

  # Reads the enemies this game's invasions added to the battle so far.
  #
  # @return [Integer] The count, 0 in a troop from before the mod.
  def mgq_invasions_added
    @mgq_invasions_added.to_i
  end

  # Sets the enemies this game's invasions added to the battle so far.
  #
  # @param count [Integer] The count.
  def mgq_invasions_added=(count)
    @mgq_invasions_added = count
  end

  # Reads the turn whose end this game computed first in this battle.
  #
  # @return [Integer, nil] The turn, nil before this game ended one.
  def mgq_invasions_first_turn
    @mgq_invasions_first_turn
  end

  # Sets the turn whose end this game computed first in this battle.
  #
  # @param turn [Integer, nil] The turn, nil for none.
  def mgq_invasions_first_turn=(turn)
    @mgq_invasions_first_turn = turn
  end
end

# Which enemies are invaders, kept on the enemy so the battle's retry snapshot carries it.
class Game_Enemy
  # Tells whether the enemy joined the battle in an invasion.
  #
  # @return [Boolean] Whether it did.
  def mgq_invader?
    @mgq_invader ? true : false
  end

  # Marks the enemy as one that joined the battle in an invasion.
  #
  # @param value [Boolean] Whether it did.
  def mgq_invader=(value)
    @mgq_invader = value
  end
end

# Boss fights and the dungeons around them.
module MGQ_Invasions
  # The boss list and the dungeon table below are generated from the game data.
  # Regenerate with gen_invasions_bosses.rb rather than editing it.

  # Story boss fights, including optional ones, by troop id and the fight's name.
  BOSSES = {
    # Part 1 - Ilias Continent.
    26 => "Four bandits (Goblin Girl, Tiny Lamia, Vampire Girl, Dragon Pup)",
    27 => "Four bandits (Goblin Girl, Tiny Lamia, Vampire Girl, Dragon Pup)",
    28 => "Four bandits (Goblin Girl, Tiny Lamia, Vampire Girl, Dragon Pup)",
    29 => "Four bandits (Goblin Girl, Tiny Lamia, Vampire Girl, Dragon Pup)",
    71 => "Queen Harpy",
    126 => "Morrigan",

    # Part 1 - Natalia Region.
    196 => "Chrome and Frederica",
    212 => "Sylph",

    # Part 1 - Safina Region.
    248 => "Sara",
    249 => "Astaroth",
    299 => "Gnome",
    327 => "Adramelech",

    # Part 2 - Noah Region.
    588 => "Bonnie and Ashel",
    607 => "Alma Elma, then Granberia",
    608 => "Alma Elma, then Granberia",
    609 => "Alma Elma, then Granberia",
    610 => "Alma Elma, then Granberia",
    655 => "Mephisto",
    665 => "Tezcatlipoca and Quetzalcoatl",
    666 => "Tezcatlipoca and Quetzalcoatl",
    670 => "Tezcatlipoca and Quetzalcoatl",
    669 => "Tezcatlipoca and Quetzalcoatl",
    671 => "Tezcatlipoca and Quetzalcoatl",
    672 => "Gnosis or Zion",
    673 => "Gnosis or Zion",
    678 => "Undine and Erubetie",
    679 => "Undine and Erubetie",

    # Part 2 - Infiltration.
    718 => "Queen Ant",
    705 => "Lilith",
    874 => "Lilith",
    719 => "Lilith",

    # Part 2 - Gold Region.
    735 => "Poseidoness",
    771 => "Succubus Witch",
    751 => "Salamander (and Granberia on the Ilias route)",
    752 => "Salamander (and Granberia on the Ilias route)",
    769 => "Lilith and Lilim",

    # Part 2 - All Out War.
    784 => "Queen Fairy",
    785 => "Queen Elf",
    793 => "Queen Alraune and Aži Dahāka",
    794 => "Queen Alraune and Aži Dahāka",
    801 => "El",
    802 => "Queen Mermaid",
    812 => "Carmilla and Elizabeth",
    813 => "Carmilla and Elizabeth",
    981 => "Spider Princess",
    807 => "Spider Princess",
    814 => "Queen Vampire",

    # Part 2 - Orbs and Snow Continent.
    836 => "Black Dahlia, Black Mamba and Black Rose",
    837 => "Black Alice",
    838 => "Black Alice",
    839 => "Black Alice",
    247 => "Sphinx",
    854 => "Eden",
    868 => "Sonya Mazda (Alice) or Sonya Mainyu (Ilias)",
    869 => "Sonya Mazda (Alice) or Sonya Mainyu (Ilias)",
    870 => "Sonya Chaos",

    # Part 3 - Before the Great Decision.
    871 => "La Croix zombie waves",
    872 => "La Croix zombie waves",
    1451 => "Garuda",
    1458 => "Erubetie",
    1461 => "Erubetie",
    1475 => "Himiko",
    1476 => "Himiko",
    1477 => "Himiko",
    1488 => "Elf Princess and Izanami",
    1489 => "Elf Princess and Izanami",
    1490 => "Armored Berserker",
    1491 => "Armored Berserker",
    1492 => "Yao",
    1501 => "Black Dahlia, Black Mamba and Black Rose",
    1502 => "Tamamo",
    1503 => "Erubetie",
    1504 => "Granberia",
    1505 => "Great Decision fights (Raphaela, Gnosis and Zion, Eden / Morrigan and Astaroth, Alipheese the 15th)",
    1506 => "Great Decision fights (Raphaela, Gnosis and Zion, Eden / Morrigan and Astaroth, Alipheese the 15th)",
    1507 => "Great Decision fights (Raphaela, Gnosis and Zion, Eden / Morrigan and Astaroth, Alipheese the 15th)",
    1508 => "Great Decision fights (Raphaela, Gnosis and Zion, Eden / Morrigan and Astaroth, Alipheese the 15th)",
    1509 => "Great Decision fights (Raphaela, Gnosis and Zion, Eden / Morrigan and Astaroth, Alipheese the 15th)",

    # Part 3 - Angelic Dominion route (Alice).
    1517 => "Heaven's Gate",
    1531 => "Leafael and Rapunzel",
    1532 => "Leafael and Rapunzel",
    1528 => "Grandine and Gnomaren",
    1537 => "Grandine and Gnomaren",
    1544 => "Gabriela",
    1554 => "Uriela, Sabiriel and Fernandez",
    1557 => "Uriela, Sabiriel and Fernandez",
    1558 => "Uriela, Sabiriel and Fernandez",
    1564 => "Sariela",
    1574 => "Luka Rinoa and Doppel",
    1570 => "Gigamander",
    1584 => "Armored Berserker and Amphisbaena",
    1589 => "Armored Berserker and Amphisbaena",
    1590 => "Laplace",
    1592 => "Tsukuyomi",
    1599 => "Metatronne and Sandalphone",
    1610 => "Zion (three fights)",
    1611 => "Zion (three fights)",
    1612 => "Zion (three fights)",
    1613 => "Ilias, Puruel and Inuel",
    1615 => "Holmiel",
    1620 => "Luka Kyrie",
    1623 => "Titania and Zylphe",
    1624 => "Titania and Zylphe",
    1634 => "Cosmos",
    1635 => "Cosmos",
    1642 => "Aži Dahāka",
    1646 => "Himiko and Izanami",
    1651 => "Himiko and Izanami",
    1652 => "Devouring Alice",
    1659 => "Marcellus and Black Alice",
    1660 => "Marcellus and Black Alice",
    1661 => "Arc-En-Ciel and Sigrdrifa",
    1670 => "Arc-En-Ciel and Sigrdrifa",
    1674 => "Doppel Lukas and Lucifina",
    1675 => "Doppel Lukas and Lucifina",
    1685 => "Eden",
    1722 => "Micaela",
    1723 => "Ilias",
    1724 => "Chaos Ilias",
    1725 => "Chaos Ilias",

    # Part 3 - Monster Realm route (Ilias).
    1745 => "Queen Eva",
    1763 => "Malboro Girl, then Kanon",
    1769 => "Malboro Girl, then Kanon",
    1784 => "Kanade",
    1788 => "Queen Lamia and Grimoire",
    1789 => "Queen Lamia and Grimoire",
    1793 => "Queen Scylla and Ghatanothoa",
    1794 => "Queen Scylla and Ghatanothoa",
    1807 => "Tamamo",
    1814 => "Tamamo",
    1830 => "Roza",
    1831 => "Roza",
    1818 => "Archaeopteryx and Queen Harpy",
    1819 => "Archaeopteryx and Queen Harpy",
    1833 => "Ambrosia and Shiva",
    1834 => "Ambrosia and Shiva",
    1846 => "Yu, Chrome and Rei",
    1847 => "Minagi and Alipheese the 10th",
    1848 => "Minagi and Alipheese the 10th",
    1853 => "Alipheese the 7th",
    1857 => "Alipheese the 6th, 9th, 11th and 12th",
    1863 => "Alipheese the 6th, 9th, 11th and 12th",
    1866 => "Alipheese the 6th, 9th, 11th and 12th",
    1869 => "Kagetsumugi and her dolls",
    1879 => "Queen Eva and Loa",
    1880 => "Queen Eva and Loa",
    1883 => "Mephisto",
    1891 => "Hiruko",
    1902 => "Kagetsumugi and Magatsu-Karura, then Black Alice",
    1903 => "Kagetsumugi and Magatsu-Karura, then Black Alice",
    1929 => "Erubetie Kanade",
    1942 => "Alipheese the 16th",
    1943 => "Saja",
    1944 => "Alipheese",
    1945 => "Chaos Alipheese",
    1946 => "Chaos Alipheese",

    # Part 3 - Chaos route (start, fixed order).
    1959 => "Kagetsumugi and her dolls",
    1965 => "Nero and Neris",
    1973 => "Adramelech",
    1974 => "EX Sonya",
    1975 => "Angolmois",

    # Part 3 - Chaos route (free order, sorted by level).
    2042 => "Greedy Papi, Gob, Teeny and Vanilla",
    2091 => "Greedy Papi, Gob, Teeny and Vanilla",
    2092 => "Greedy Papi, Gob, Teeny and Vanilla",
    1983 => "Gabriela and Kanon",
    1984 => "Gabriela and Kanon",
    1987 => "Uriela",
    1989 => "Kanade",
    1995 => "Hiruko",
    1996 => "Hiruko",
    2000 => "Magatsu-Omikami",
    2001 => "Magatsu-Omikami",
    1999 => "Apiro Lagos",
    2003 => "Zion and Laplace",
    2004 => "Zion and Laplace",
    2005 => "Sigrdrifa",
    2006 => "Metatronne and Sandalphone, then Singularity",
    2010 => "Metatronne and Sandalphone, then Singularity",
    2015 => "Forsaken Spawn",
    2016 => "Sisel, EX-Kyubi, Frere and Bloody Dragon",
    2017 => "Sisel, EX-Kyubi, Frere and Bloody Dragon",
    2018 => "Sisel, EX-Kyubi, Frere and Bloody Dragon",
    2019 => "Sisel, EX-Kyubi, Frere and Bloody Dragon",
    2029 => "Saja",
    2047 => "World Drown",
    2053 => "Cosmos",
    2054 => "No Life King",
    2061 => "No Life King",
    2062 => "Angolmois",
    2063 => "Magatsu-Omikami",
    2221 => "Hiruko, Kanon and Kanade",
    2090 => "Baal Zebub",
    2095 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2096 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2097 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2098 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2099 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2100 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2101 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2102 => "Envious Lily, Gluttonous Cassandra, Wrathful Cow Demon Queen, Lustful and Prideful sinners",
    2107 => "Greedy, Envious and Slothful Eva",
    2108 => "Greedy, Envious and Slothful Eva",
    2109 => "Greedy, Envious and Slothful Eva",
    2110 => "Seven Deadly Sins",
    2133 => "The All-Knowing",
    2224 => "Agaliarept",
    2225 => "Agaliarept",
    2226 => "Agaliarept",
    2227 => "Agaliarept",
    2228 => "Agaliarept",
    2137 => "Echidna Queen",
    2144 => "Cthulhu",
    2154 => "Dimensional Eroder",
    2156 => "Dark Phoenix",
    2157 => "Star Eater",
    2158 => "Star Eater",
    2176 => "Black Alice",
    2222 => "Idea Lukas",
    2185 => "EX Sonya",
    2187 => "Koron",
    2188 => "Koron",

    # Part 3 - Chaos route (finale, fixed order).
    2211 => "Goddess, Demon and Fiend",
    2212 => "Goddess, Demon and Fiend",
    2213 => "Goddess, Demon and Fiend",
    2214 => "World Breaker and Judgement",
    2215 => "World Breaker and Judgement",
    2216 => "Deus Ex Machina",
    2217 => "Chaos",
    2218 => "Chaos",
    2219 => "Chaos",

    # Optional quest fights.
    770 => "Cassandra and Emily",
    1571 => "Hainuwele",
    2060 => "Nychta Telos",
    2079 => "Beelzebub",
    2086 => "Queen Bee, Queen Ant, Spider Princess and Queen Roach (Baal Zebub quest)",
    2087 => "Queen Bee, Queen Ant, Spider Princess and Queen Roach (Baal Zebub quest)",
    2088 => "Queen Bee, Queen Ant, Spider Princess and Queen Roach (Baal Zebub quest)",
    2089 => "Queen Bee, Queen Ant, Spider Princess and Queen Roach (Baal Zebub quest)",
    2131 => "Hakutenko",
    2132 => "Upaya Jorogumo",
  }

  # Maps of boss fights without an encounter list of their own, by map id, and the dungeon map whose
  # list their invaders come from: the nearest map above them in the map tree that has a list.
  #
  # A world map is never that map, as its monsters roam a whole region, not the dungeon, nor is a
  # map whose list holds only the boss fought there. World maps are the maps with a list at the top
  # of their folder's map tree; dungeons, towers and castle floors always sit below a folder map or
  # a world map.
  DUNGEON_MAPS = {
    217 => 152, # Devastated Plains
    332 => 324, # Monster Lord's Castle 1F
    405 => 392, # Esta Large Crater
    410 => 324, # Monster Lord's Castle 1F
    414 => 379, # Safar Desert Ruins 1L
    430 => 324, # Monster Lord's Castle 1F
    431 => 324, # Monster Lord's Castle 1F
    432 => 324, # Monster Lord's Castle 1F
    619 => 167, # Administrator's Tower 1F
    1017 => 1322, # イリアス神殿 第1層
    1019 => 1322, # イリアス神殿 第1層
    1076 => 1837, # 混沌月面
    1135 => 1321, # 邪神城 5F
    1211 => 1014, # Mt. Saint Amos (AD)
    1303 => 1299, # Administrator's Tower 1F
    1364 => 1360, # 嫉妬の殿堂 1F西
    1490 => 1487, # Remina Research Facility Second Sector Entrance
    1514 => 1083, # ルルイエに至る道 B1F
    1682 => 1674, # Black Mansion 1F (AD)
    1803 => 1796, # 混沌黒の屋敷 1F
    1822 => 1228, # Safar Ruins Area 1 (MR)
    1834 => 1598, # 混沌記憶の場所 第1層
    1988 => 1465, # 混沌リマ村廃墟
  }
  # End of the generated tables.
end

if MGQ_Invasions::ENABLED && !SceneManager.respond_to?(:mgq_invasions_run)
  begin
    MGQ_Invasions::Options.register
  rescue => e
    MGQ_Invasions.log("options FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << SceneManager
      alias mgq_invasions_run run

      # Installs the hooks over the translation's plugins, then runs the game.
      def run
        MGQ_Invasions.install
        mgq_invasions_run
      end
    end
  rescue => e
    MGQ_Invasions.log("scene hook FAILED: #{e.class}: #{e.message}")
  end
end
