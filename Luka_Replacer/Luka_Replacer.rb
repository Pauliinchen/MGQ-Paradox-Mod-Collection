#----------------------------------------------------------------
#  Luka_Replacer.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Wrote the log into the game folder's Logs folder
#                            - Rebuilt the game's feature index of a hero's data, so their trait counts and Lest no longer crashes a new game
#                            - Closed the title commands while the list of heroes shows, so choosing a hero never looks like the plain title screen
#                            - Swapped Luka's faces in every window that draws a face, not only the message window
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Lets a new game start with another hero in Luka's place. It is a reskin: the hero keeps Luka's
# actor ids, so the story still treats them as Luka, and brings their own name, looks, starting
# job, race, equipment and trait, and their own share of what the story gives Luka. Heroes come
# from hero packs. Every entry point rescues, so the mod never stops the game.
module MGQ_LukaReplacer
  # Turns the mod off without uninstalling it.
  ENABLED = true

  # Folder next to Game.exe that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Log in LOG_DIR, which only appears when something went wrong.
  LOG_FILE = "Luka Replacer.log"

  # Lines logged per session at most.
  MAX_LOG_LINES = 60

  # Folder of the hero files, one per hero named after its key.
  HEROES_DIR = "Patch/Luka_Replacer/Heroes"

  # The extension of a hero file.
  HERO_FILE = ".luka"

  # Folder the images of hero files are unpacked to, one folder per hero named after its key.
  CACHE_DIR = "Patch/Luka_Replacer/Cache"

  # The file in a hero's cache folder that tells which hero file its images come from.
  STAMP_FILE = "stamp"

  # The first bytes of a hero file, then its container version.
  HERO_MAGIC = "LUKA"
  HERO_VERSION = 1

  # The start of the keystream that hides a hero file's body: "LUKA" as a number. Each key byte
  # comes from the next state of a linear congruential generator.
  KEY_SEED = 0x4C554B41
  KEY_MULTIPLIER = 1103515245
  KEY_INCREMENT = 12345

  # A hero pack's definition, an entry of the hero file.
  PACK_FILE = "hero.txt"

  # An image entry of a hero file: the pack image's file name and .png.
  IMAGE_ENTRY = /\A([A-Za-z0-9_\-]{1,64})\.png\z/

  # The newest pack format this mod reads.
  PACK_FORMAT = 1

  # Heroes that come with the mod, as pack text. A pack of the same key replaces one.
  BUILT_IN = {
    "kazuya" => "source=815\ntrait_from=815\njob=110\nequip0=891\n", # Engineer with a Dueling Pistol.
  }

  # A hero's key, which names its hero file and travels in saves and to other players.
  KEY = /\A[a-z0-9_]{1,32}\z/

  # A pack image's file name, without its extension.
  PACK_IMAGE_FILE = /\A[A-Za-z0-9_\-]{1,64}\z/

  # The name an image of a pack goes by in the game, which Cache.load_bitmap resolves: "$" for a
  # single-character sprite sheet, then lr~<key>~<file>.
  PACK_IMAGE = /\A\$?lr~([a-z0-9_]{1,32})~([A-Za-z0-9_\-]{1,64})\z/

  # Luka's actor ids the hero takes over: his forms through the story, which the game keeps as one
  # character. Form 4, Father of Chaos, stays Luka's, like World Breaker and Judgement.
  PERSONAS = [1, 2, 3]

  # Luka's form 4, Father of Chaos, which keeps his name, looks and stats.
  FATHER_OF_CHAOS = 4

  # Luka's base form, which takes the hero's trait in place of his own. His later forms are story
  # power-ups and keep their power, with the hero's trait added: the form's own trait in the pack,
  # else the base form's, and the form's own looks, else the base form's.
  BASE_FORM = 1

  # A form key of a pack line, like form2.sprite. Lines of form 4 are left out.
  FORM_KEY = /\Aform([23])\.(\w+)\z/

  # Note tags that make up a trait: unique skills, the armor class, skill type boosts, stat
  # replacements, states added or exploited by skill types and the recruit rate.
  TRAIT_TAG = /\A<(固有習得|人間時追加特徴|スキルタイプ強化|窮地スキルタイプ強化|全快スキルタイプ強化|能力値置き換え|ステート特攻スキルタイプ|スキルタイプステート敵付加|仲間加入倍率)/

  # Luka's unique skills by level, of which the hero keeps those of KEPT_SKILL_TYPES: Talk.
  UNIQUE_SKILLS_TAG = /\A<固有習得\s?([\d\-,\s]+)>\z/

  # A starting equipment tag of a slot.
  START_EQUIP_TAG = /<初期装備(\d)(?::|：)[^>]*>/

  # The starting race tag.
  START_RACE_TAG = /<初期サブクラス\s?\d+>/

  # The tag of jobs and races a character starts with a level in.
  CLASS_LEVELS_TAG = /<経験済職業\s?[\d\-,\s]+>/

  # The note tags of what a pack may set in place of Luka's for every form, by the hero's field.
  HIDDEN_TAGS = {
    :categories => /<カテゴリー(?::|：)[^>]*>/,
    :special_categories => /<特殊カテゴリー\s?[\d,\s]+>/,
    :seduction_skill => /<誘惑時使用スキル(?::|：)\d+>/,
    :skill_change => /<スキル変化\s?[\d\-,\s]+>/,
    :exp_curve => /<経験値曲線\s?\d+>/,
    :sp_base => /<TP基本値\s?\d+>/,
    :sp_level => /<TPLv補正\s?\d+(?:\.\d+)?>/,
    :sp_level100 => /<TPLv100補正\s?\d+(?:\.\d+)?>/,
    :sp_start => /<開始時TP\s?[^>%]*%>/,
  }

  # A whole number of a pack line.
  WHOLE_NUMBER = /\A\d{1,6}\z/

  # A number of a pack line that may have two decimals.
  DECIMAL_NUMBER = /\A\d{1,6}(?:\.\d{1,2})?\z/

  # The numbers a pack may set in place of Luka's for every form, by the hero's field: the pack
  # value's pattern and the note tag it becomes.
  NUMBER_TAGS = {
    :exp_curve => [WHOLE_NUMBER, "<経験値曲線 %s>"],
    :sp_base => [WHOLE_NUMBER, "<TP基本値 %s>"],
    :sp_level => [DECIMAL_NUMBER, "<TPLv補正 %s>"],
    :sp_level100 => [DECIMAL_NUMBER, "<TPLv100補正 %s>"],
    :sp_start => [WHOLE_NUMBER, "<開始時TP %s%%>"],
  }

  # The Library's artist credit tag, which a hero never takes from Luka.
  ARTIST_TAG = /<イラスト(?::|：)[^>]*>/

  # A category name as the game's notes write it.
  CATEGORY_NAME = /\A[^\s<>,]{1,64}\z/

  # The value of a skill change tag: <skill>-<skill it becomes>,...
  SKILL_CHANGE = /\A\d{1,6}-\d{1,6}(?:,\s?\d{1,6}-\d{1,6})*\z/

  # Database features of Hero's Blood every form of Luka carries, which a pack may drop: hit and
  # evasion, target rate and two flags, by code and data id.
  LUKA_EXTRAS = [[22, 1], [22, 2], [23, 0], [51, 32], [52, 41]]

  # The kinds of cut-in the game plays.
  CUTIN_TYPES = [:basic, :slide, :focus, :long]

  # The fields of a battle line entry that make it a cut-in.
  CUTIN_FIELDS = [:ct_type, :ct_pic, :ct_se]

  # A sound effect's name in Audio/SE.
  SE_NAME = /\A[^\\\/:<>]{1,64}\z/

  # Names that contain Luka's but name someone else, which keep their name.
  KEPT_NAMES = ["Luka Holly", "Luka Rinoa", "Luka Heine", "Luka Kyrie", "Luka Doppel", "Doppel Luka",
                "Idea Luka", "Father of Chaos Luka"]

  # The kinds of what the story gives Luka, as story rules name them.
  STORY_KINDS = %w[class skill form back]

  # Luka's forms the story changes a hero between: back to the base form, or into the later forms
  # 2 and 3. Form 4 never comes from an event.
  FORMS = [1, 2, 3]

  # The Chaos and White Rabbit form, whose end follows its own rules whatever form comes next.
  CHAOS_FORM = 3

  # A story event's key: a common event or an event on a map.
  EVENT_KEY = /\A(?:ce:\d{1,5}|map:\d{1,4}:\d{1,5})\z/

  # The sprites where Luka carries someone, by the pack's name for each.
  CARRY_SPRITES = { "$Ruka(hold_Knight)01_cip" => :knight, "$Ruka(hold_Princess)01_cip" => :princess }

  # Luka's poses of single scenes, which no form uses, by file and place: the hero's base sprite.
  EXTRA_SPRITES = [[["Main04_cip", 1], BASE_FORM], [["Main04_cip", 2], BASE_FORM]]

  # Feature code that lets a character use a skill type.
  FEATURE_SKILL_TYPE = 41

  # Skill types of Luka's base form a hero keeps: Talk, which recruiting needs, and Special, which
  # every character has. Any other comes from the hero's trait.
  KEPT_SKILL_TYPES = [39, 63]

  # A sex bit only heroines have. Every form of Luka counts as Luka, which skills aimed at men and
  # binding look for; a heroine is female instead, and this bit lets binding still find her.
  HEROINE = 0x10

  # The job whose stats by level are an actor's base stats is this plus the actor's id.
  BASE_PARAM_BASE = 400

  # The stats a custom curve covers, and the highest level the game keeps in a stats table.
  STATS = 8
  TABLE_LEVEL = 99

  # The range of a stats table entry, which the game keeps as a 16-bit number.
  STAT_RANGE = -32768..32767

  # Luka's face files, in his actor data and in the story's messages.
  LUKA_FACE = /\Aruka_fc\d+\z/i

  # The width and height of a face in a face sheet.
  FACE_SIZE = 96

  # Faces in a row of a face sheet: the game draws cell n at column n % 4, row n / 4, whatever the
  # sheet's width.
  FACE_COLUMNS = 4

  # The situations of battle and knock-out lines a hero's face sheet may show another cell in.
  SITUATIONS = [:skill, :pinch, :down, :pleasure, :eaten]

  # The share of max HP at or below which a hero's battle skill lines show the :pinch cell.
  PINCH_HP = 0.25

  # The knock-out lines of a character, by the method that makes each, and their situation.
  DOWN_SITUATIONS = { :dead_word => :down, :orgasm_word => :pleasure, :incontinence_word => :pleasure,
                      :predation_word => :eaten }

  # Printable ASCII, the characters of a translated name.
  ASCII_NAME = /\A[ -~]+\z/

  # A hero: what their pack says, read but not yet checked against the game's data.
  #
  # Images are [:game, file, index] or [:pack, file]. Equipment is the item id by slot, 0 for an
  # empty slot. Story rules are :skip or the id given instead, by "class:<id>" or "skill:<id>".
  # Base stats are :luka, :custom or an actor's id; curves are [level 1, level 99, growth] by stat.
  # Class levels are the level by job or race the hero starts with. Skipped places are
  # "kind:id@event" keys; gains are [event, kind, id]; carry images are by :knight and :princess.
  # Categories, special categories, the seduction skill, the skill change and NUMBER_TAGS are nil
  # to keep Luka's. Cut-ins are [skill ids, type, image, sound effect or nil]. The face cell is the normal
  # cell of a pack face; expressions are the cell by situation, nil without a line of them.
  Hero = Struct.new(:key, :name, :nickname, :source_id, :trait_from, :job_id, :race_id, :base_stats,
                    :equips, :sprite, :face, :picture, :trait_name, :trait_lines, :features, :tags,
                    :story, :recruit_self, :stand_in, :sex, :forms, :level, :curves, :class_levels,
                    :skipped_at, :gains, :carry, :dir, :artist, :categories, :special_categories,
                    :seduction_skill, :skill_change, :monster_skills, :luka_features, :cutins,
                    :face_cell, :expressions, :follow_lines, :exp_curve, :sp_base, :sp_level,
                    :sp_level100, :sp_start)

  # What a hero's pack sets for one of Luka's later forms; what it leaves out comes from the base
  # form. The form's trait replaces the base form's only when own_trait is set, and its cut-ins,
  # expressions and follow_lines, nil without a line of them, the base form's. Its face cell goes
  # with its own face.
  Form = Struct.new(:sprite, :face, :picture, :own_trait, :trait_name, :trait_lines, :features, :tags,
                    :source_id, :cutins, :face_cell, :expressions, :follow_lines)

  class << self
    # The key of the hero this game plays, nil for Luka.
    #
    # @return [String, nil] The key.
    attr_reader :current

    # The hero chosen for the new game about to be set up, until the save holds it.
    #
    # @return [String, nil] The key, nil for Luka.
    attr_accessor :pending
  end

  # Finds a hero.
  #
  # @param key [String, nil] The hero's key.
  # @return [Hero, nil] The hero, nil for Luka or a key no pack offers.
  def self.hero(key)
    key && heroes.find { |hero| hero.key == key }
  end

  # Lists the heroes: the built-in ones, then those of the hero files by name, a file replacing a
  # built-in hero of its key. Read once, after the game's data loaded.
  #
  # @return [Array<Hero>] The heroes whose file could be read.
  def self.heroes
    @heroes ||= begin
      found = {}
      BUILT_IN.each { |key, text| found[key] = Pack.read(text, key, nil) }
      Pack.files.each do |key, path|
        begin
          entries = Pack.entries(path)
          raise "it has no #{PACK_FILE}" unless entries[PACK_FILE]

          found[key] = Pack.read(Pack.text(entries[PACK_FILE]), key, Pack.unpack_images(key, path, entries))
        rescue => e
          log("left out the hero file #{File.basename(path)}: #{e.class}: #{e.message}")
        end
      end
      found.values.each { |hero| Pack.check(hero) }
      built_in = found.values.select { |hero| BUILT_IN.key?(hero.key) && !hero.dir }
      built_in + (found.values - built_in).sort_by { |hero| name_of(hero).downcase }
    end
  end

  # Reads Luka's name as the game's data has it.
  #
  # @return [String] The name, like "Luka" or "ルカ".
  def self.luka_name
    original(PERSONAS.first).name
  end

  # Reads a hero's name: their pack's, else their source actor's, else their key.
  #
  # @param hero [Hero] The hero.
  # @return [String] The name.
  def self.name_of(hero)
    hero.name || (source_actor(hero) && source_actor(hero).name) || hero.key
  end

  # Finds the actor a hero takes what their pack leaves out from.
  #
  # @param hero [Hero] The hero.
  # @return [RPG::Actor, nil] The actor, nil when the pack names none.
  def self.source_actor(hero)
    hero.source_id && $data_actors[hero.source_id]
  end

  # Makes the game play a hero, or Luka again: Luka's forms take the hero's data, the status
  # screen and the Library the hero's trait and picture, and Luka, when the loaded game has him,
  # the hero's name and looks.
  #
  # @param key [String, nil] The hero's key, nil for Luka.
  def self.apply(key)
    @current = hero(key) ? key : nil
    @name_pattern = nil
    PERSONAS.each { |persona_id| $data_actors[persona_id] = data(@current, persona_id) if $data_actors[persona_id] }
    Library.apply(hero(@current))
    refresh_luka
  rescue => e
    log("could not play #{key.inspect}: #{e.class}: #{e.message}")
  end

  # Lets Luka of the loaded game take his name and looks from his data again.
  def self.refresh_luka
    return unless $game_actors && $game_actors.exist?(PERSONAS.first)

    luka = $game_actors[PERSONAS.first]
    [:init_name, :init_nickname, :init_graphics].each { |step| luka.send(step) }
    luka.refresh
    $game_player.refresh if $game_player
  end

  # Builds the data of one of Luka's forms as a hero has it.
  #
  # @param key [String, nil] The hero's key, nil or "" for Luka.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [RPG::Actor] The data, Luka's own for Luka.
  def self.data(key, persona_id)
    hero = hero(key)
    return original(persona_id) unless hero

    @built ||= {}
    @built[[hero.key, persona_id]] ||= build(hero, persona_id)
  end

  # Copies the data of one of Luka's forms before the mod changes it.
  #
  # @param persona_id [Integer] One of PERSONAS.
  # @return [RPG::Actor] The copy.
  def self.original(persona_id)
    @originals ||= {}
    @originals[persona_id] ||= Marshal.load(Marshal.dump($data_actors[persona_id]))
  end

  # Builds one of Luka's forms as a hero: the hero's name, looks, starting job, race and
  # equipment, and their trait, in place of Luka's own in the base form and on top of the form's
  # in the later ones.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [RPG::Actor] The form's data.
  def self.build(hero, persona_id)
    luka = original(persona_id)
    data = Marshal.load(Marshal.dump(luka))
    data.name = name_of(hero)
    nickname = hero.nickname || (source_actor(hero) && source_actor(hero).nickname)
    data.nickname = nickname unless nickname.to_s.empty?
    data.character_name, data.character_index = sprite_of(hero, persona_id) || [luka.character_name, luka.character_index]
    data.face_name, data.face_index = face_of(hero, persona_id) || [luka.face_name, luka.face_index]
    data.class_id = hero.job_id if hero.job_id
    data.instance_variable_set(:@features, features_of(hero, luka, persona_id))
    data.note = note_of(hero, luka, persona_id)
    data.note_analyze
    credit(data, hero.artist)
    make_female(data) if hero.sex == :female
    data.initial_level = hero.level if hero.level && hero.level > 0
    # The game reads features through an index it builds once at load, and the copy of Luka's
    # data still holds his; without the hero's trait in it, starting gear only the trait allows
    # is taken off while the actor is built, which loops the game until its stack overflows.
    data.setting_feature_data if data.respond_to?(:setting_feature_data)
    data
  end

  # Sets the Library's artist credit of a form.
  #
  # The credit is set past the note, since the game's tag takes no spaces and a translation patch
  # credits a character without one with their own name.
  #
  # @param data [RPG::Actor] The form's data, its notes read.
  # @param artist [String, nil] The artist, nil for no credit.
  def self.credit(data, artist)
    data_ex = data.instance_variable_get(:@data_ex)
    data_ex[:illustrator_name] = artist.to_s if data_ex
  end

  # Makes a form female for the skills that only affect one sex: those aimed at women affect her,
  # those aimed at men no longer do. HEROINE keeps binding, which aims at Luka alone, aimed at her.
  #
  # @param data [RPG::Actor] The form's data, its notes read.
  def self.make_female(data)
    return unless defined?(NWSex::FEMALE)

    data_ex = data.instance_variable_get(:@data_ex)
    data_ex[:sex] = NWSex::FEMALE | HEROINE if data_ex
  end

  # Adds a heroine to what a skill aimed at Luka alone, like binding, may hit.
  #
  # @param scope [Integer] The sexes the skill may hit.
  # @return [Integer] The sexes, with HEROINE when the skill aims at Luka alone.
  def self.scope(scope)
    defined?(NWSex::LUCA) && scope == NWSex::LUCA ? scope | HEROINE : scope
  end

  # Builds the database features of a form as a hero: the hero's trait wins over a feature of the
  # form with the same code and id, the base form drops Luka's skill types but KEPT_SKILL_TYPES,
  # and every form drops LUKA_EXTRAS when the pack says so.
  #
  # @param hero [Hero] The hero.
  # @param luka [RPG::Actor] The form.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array<RPG::BaseItem::Feature>] The features.
  def self.features_of(hero, luka, persona_id)
    own = luka.instance_variable_get(:@features)
    if persona_id == BASE_FORM
      own = own.reject { |feature| feature.code == FEATURE_SKILL_TYPE && !KEPT_SKILL_TYPES.include?(feature.data_id) }
    end
    own = own.reject { |feature| LUKA_EXTRAS.include?([feature.code, feature.data_id]) } if hero.luka_features == :drop
    added = trait_features(hero, persona_id)
    taken = added.map { |feature| [feature.code, feature.data_id] }
    own.reject { |feature| taken.include?([feature.code, feature.data_id]) } + added
  end

  # Lists a hero's trait features in a form: the form's own trait when the pack gives it one, else
  # the base trait, those of the actor the pack copies it from, then the pack's own.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array<RPG::BaseItem::Feature>] The features.
  def self.trait_features(hero, persona_id)
    form = own_trait_form(hero, persona_id)
    copied = !form && hero.trait_from ? Array($data_actors[hero.trait_from].instance_variable_get(:@features)) : []
    copied + (form || hero).features.map { |code, data_id, value| RPG::BaseItem::Feature.new(code, data_id, value) }
  end

  # Lists a hero's trait tags in a form, the way trait_features lists the features.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array<String>] The tags.
  def self.trait_tags(hero, persona_id)
    form = own_trait_form(hero, persona_id)
    return form.tags if form

    copied = hero.trait_from ? $data_actors[hero.trait_from].note.to_s.scan(/<[^>]*>/).select { |tag| tag =~ TRAIT_TAG } : []
    copied + hero.tags
  end

  # Finds a later form whose pack gives it a trait of its own.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Form, nil] The form, nil when it takes the base trait.
  def self.own_trait_form(hero, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    form && form.own_trait ? form : nil
  end

  # Writes the note of a form as a hero: the form's own, without Luka's trait tags in the base
  # form but his Talk skill, without his artist credit, with the hero's race, equipment and
  # HIDDEN_TAGS in place of Luka's, then the hero's trait tags, so a single-value tag like the
  # armor class becomes the hero's.
  #
  # @param hero [Hero] The hero.
  # @param luka [RPG::Actor] The form.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [String] The note.
  def self.note_of(hero, luka, persona_id)
    own = luka.note.to_s.gsub(START_EQUIP_TAG) { |tag| hero.equips.key?($1.to_i) ? "" : tag }
    own = own.gsub(START_RACE_TAG, "") if hero.race_id
    own = own.gsub(CLASS_LEVELS_TAG, "") unless hero.class_levels.empty?
    own = own.gsub(ARTIST_TAG, "")
    HIDDEN_TAGS.each { |field, tag| own = own.gsub(tag, "") unless hero[field].nil? }
    if persona_id == BASE_FORM
      own = own.gsub(/<[^>]*>/) { |tag| tag =~ UNIQUE_SKILLS_TAG ? kept_unique_skills($1) : tag =~ TRAIT_TAG ? "" : tag }
    end
    equips = hero.equips.select { |_, item_id| item_id > 0 }.map { |slot, item_id| "<初期装備#{slot}:#{item_id}>" }
    race = hero.race_id ? ["<初期サブクラス #{hero.race_id}>"] : []
    levels = hero.class_levels.sort.map { |class_id, level| "#{class_id}-#{level}" }
    classes = levels.empty? ? [] : ["<経験済職業 #{levels.join(',')}>"]
    [own, *race, *classes, *hidden_tags(hero), *trait_tags(hero, persona_id), *equips].join("\n")
  end

  # Writes the HIDDEN_TAGS a hero's pack sets.
  #
  # @param hero [Hero] The hero.
  # @return [Array<String>] The tags, none for what the pack leaves to Luka or sets to none.
  def self.hidden_tags(hero)
    tags = Array(hero.categories).map { |name| "<カテゴリー：#{name}>" }
    tags.push("<特殊カテゴリー #{hero.special_categories.join(',')}>") unless Array(hero.special_categories).empty?
    tags.push("<誘惑時使用スキル:#{hero.seduction_skill}>") if hero.seduction_skill.to_i > 0
    tags.push("<スキル変化 #{hero.skill_change}>") unless hero.skill_change.to_s.empty?
    NUMBER_TAGS.each { |field, (_, tag)| tags.push(tag % hero[field]) unless hero[field].nil? }
    tags
  end

  # Keeps those of Luka's unique skills a hero keeps: the skills of KEPT_SKILL_TYPES, his Talk.
  # The game teaches unique skills from the base form's note in every form.
  #
  # @param entries [String] The tag's level-skill entries.
  # @return [String] The tag with the kept entries, "" when none is kept.
  def self.kept_unique_skills(entries)
    kept = entries.scan(/(\d+)-(\d+)/).select do |_, skill_id|
      skill = $data_skills[skill_id.to_i]
      skill && KEPT_SKILL_TYPES.include?(skill.stype_id)
    end
    kept.empty? ? "" : "<固有習得 #{kept.map { |level, skill_id| "#{level}-#{skill_id}" }.join(',')}>"
  end

  # Reads an image a hero shows in a form: the form's own, else the base form's.
  #
  # @param hero [Hero] The hero.
  # @param field [Symbol] :sprite, :face or :picture.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array, nil] The image, nil when the pack sets none.
  def self.image_of(hero, field, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    (form && form[field]) || hero[field]
  end

  # Reads the sprite a hero shows on the map in a form: the form's, else the base form's, else
  # their source actor's.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array(String, Integer), nil] The sprite file and place in it, nil to keep Luka's.
  def self.sprite_of(hero, persona_id = BASE_FORM)
    image = image_of(hero, :sprite, persona_id)
    return ["$lr~#{hero.key}~#{image[1]}", 0] if image && image[0] == :pack
    return [image[1], image[2]] if image

    source = source_actor(hero)
    source && [source.character_name, source.character_index]
  end

  # Reads the face a hero shows in a form, the way sprite_of reads the sprite, in its normal cell:
  # the pack's face cell for a pack face, the place in the file for a game face, 0 for a cell the
  # sheet lacks.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array(String, Integer), nil] The face file and place in it, nil to keep Luka's.
  def self.face_of(hero, persona_id = BASE_FORM)
    image = image_of(hero, :face, persona_id)
    face = if image && image[0] == :pack
             ["lr~#{hero.key}~#{image[1]}", face_owner(hero, persona_id).face_cell || 0]
           elsif image
             [image[1], image[2]]
           else
             source = source_actor(hero)
             source && [source.face_name, source.face_index]
           end
    face && [face[0], face_cell?(face[0], face[1]) ? face[1] : 0]
  end

  # Finds whose face a form shows: the form's own, else the base form's.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Hero, Form] The hero or the form, whose face cell goes with that face.
  def self.face_owner(hero, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    form && form.face ? form : hero
  end

  # Tells whether a face sheet has a cell.
  #
  # @param name [String] The face file, a pack's by its name in the game.
  # @param cell [Integer] The cell.
  # @return [Boolean] Whether the cell is on the sheet, false when the sheet cannot be read.
  def self.face_cell?(name, cell)
    sheet = face_sheet(name)
    return false unless sheet && cell.is_a?(Integer) && cell >= 0

    cell % FACE_COLUMNS < sheet[0] && cell / FACE_COLUMNS < sheet[1]
  end

  # Measures a face sheet once per file.
  #
  # @param name [String] The face file.
  # @return [Array(Integer, Integer), nil] Its columns and rows, nil when it cannot be read.
  def self.face_sheet(name)
    @face_sheets ||= {}
    return @face_sheets[name] if @face_sheets.key?(name)

    bitmap = Cache.face(name)
    @face_sheets[name] = [[bitmap.width / FACE_SIZE, FACE_COLUMNS].min, bitmap.height / FACE_SIZE]
  rescue => e
    log("could not measure the face #{name}: #{e.class}: #{e.message}")
    @face_sheets[name] = nil
  end

  # Lists the cells a hero's face sheet shows in a form by situation: the form's own when its pack
  # lines give any, else the base form's.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Hash{Symbol => Integer}] The cell by one of SITUATIONS.
  def self.expressions_of(hero, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    (form && form.expressions) || hero.expressions || {}
  end

  # Tells whether a hero's face in a form follows the based-on character's lines: shows the cell
  # of that character's face the line shows.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Boolean] Whether the form's pack line says so, else the base form's.
  def self.follows_lines?(hero, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    follow = form && !form.follow_lines.nil? ? form.follow_lines : hero.follow_lines
    follow ? true : false
  end

  # Tells whether a face is one of Luka's that a hero's takes the place of: any of his but Father
  # of Chaos's.
  #
  # @param name [String, nil] The face file.
  # @return [Boolean] Whether it is.
  def self.luka_face?(name)
    name.to_s =~ LUKA_FACE && name != original(FATHER_OF_CHAOS).face_name ? true : false
  end

  # Swaps a sprite of one of Luka's forms for the hero's in that form.
  #
  # @param name [String] The sprite file.
  # @param index [Integer] The sprite's place in the file.
  # @param key [String, nil] The hero's key, nil for Luka.
  # @return [Array(String, Integer)] The hero's sprite file and place, the given ones for any
  #   other sprite or for Luka.
  def self.sprite(name, index, key = @current)
    hero = hero(key)
    return carry_sprite(hero, CARRY_SPRITES[name]) || [name, index] if hero && CARRY_SPRITES.key?(name)

    persona_id = hero && luka_sprite_form(name, index)
    looks = persona_id && sprite_of(hero, persona_id)
    looks || [name, index]
  end

  # Reads the sprite a hero shows where Luka carries someone: the pack's, else their map sprite.
  #
  # @param hero [Hero] The hero.
  # @param field [Symbol] :knight or :princess.
  # @return [Array(String, Integer), nil] The sprite file and place in it, nil to keep Luka's.
  def self.carry_sprite(hero, field)
    image = hero.carry[field]
    return ["$lr~#{hero.key}~#{image[1]}", 0] if image && image[0] == :pack
    return [image[1], image[2]] if image

    sprite_of(hero, BASE_FORM)
  end

  # Swaps a face of Luka for the hero's in the form it belongs to, in its normal cell; faces of no
  # form, like the expressions of ruka_fc2, are the base form's, and Father of Chaos keeps his.
  #
  # @param name [String] The face file.
  # @param index [Integer] The face's place in the file.
  # @param key [String, nil] The hero's key, nil for Luka.
  # @return [Array(String, Integer)] The hero's face file and place, the given ones for any other
  #   face or for Luka.
  def self.face(name, index, key = @current)
    hero = hero(key)
    return [name, index] unless hero && luka_face?(name)

    persona_id = PERSONAS.find { |id| original(id).face_name == name } || BASE_FORM
    face_of(hero, persona_id) || [name, index]
  rescue => e
    log("could not give the hero a face: #{e.class}: #{e.message}")
    [name, index]
  end

  # Finds the form of Luka a sprite belongs to.
  #
  # @param name [String] The sprite file.
  # @param index [Integer] The sprite's place in the file.
  # @return [Integer, nil] The form's actor id, nil when no form of Luka has that sprite.
  def self.luka_sprite_form(name, index)
    @luka_sprites ||= PERSONAS.map { |persona_id| [[original(persona_id).character_name, original(persona_id).character_index], persona_id] } + EXTRA_SPRITES
    found = @luka_sprites.find { |sprite, _| sprite == [name, index] }
    found && found[1]
  end

  # Finds the folder and file of a pack image, for Cache.load_bitmap.
  #
  # @param filename [String] The image's name in the game.
  # @return [Array(String, String), nil] The hero's cache folder and the file, nil for any other
  #   image.
  def self.pack_image(filename)
    match = PACK_IMAGE.match(filename.to_s)
    hero = match && hero(match[1])
    hero && hero.dir ? ["#{hero.dir}/", match[2]] : nil
  end

  # Finds the hero a character plays: Luka's forms of this game, or of another player's in MGQ
  # Online, take that game's.
  #
  # @param actor [Game_Battler, nil] The character.
  # @return [Hero, nil] The hero, nil for Luka and every other character.
  def self.hero_of(actor)
    return nil unless actor.is_a?(Game_Actor) && PERSONAS.include?(actor.id)

    hero(actor.instance_variable_get(:@mgq_luka_key) || @current)
  end

  # Finds the stats by level a character's base stats come from, when the hero has their own: the
  # hero's in the base form, grown in a later form as Luka's grow in it.
  #
  # @param actor [Game_Actor] The character.
  # @return [RPG::Class, nil] Another actor's stats or the hero's custom ones, nil to keep the
  #   character's own.
  def self.base_stats(actor)
    hero = hero_of(actor)
    stats = hero && hero_stats(hero)
    return stats if !stats || actor.id == BASE_FORM

    @form_stats ||= {}
    @form_stats[[hero.key, actor.id]] ||= form_stats(stats, actor.id)
  rescue => e
    log("could not build the hero's stats: #{e.class}: #{e.message}")
    nil
  end

  # Finds the stats by level of a hero's base form.
  #
  # @param hero [Hero] The hero.
  # @return [RPG::Class, nil] Another actor's stats or the hero's custom ones, nil for Luka's.
  def self.hero_stats(hero)
    case hero.base_stats
    when Integer then $data_classes[BASE_PARAM_BASE + hero.base_stats]
    when :custom then custom_stats(hero)
    end
  end

  # Grows a hero's base stats into one of Luka's later forms: each stat at each level by the share
  # Luka's stats in that form have of his base stats.
  #
  # @param base [RPG::Class] The hero's stats by level.
  # @param persona_id [Integer] The form's actor id.
  # @return [RPG::Class] The form's stats by level.
  def self.form_stats(base, persona_id)
    luka = $data_classes[BASE_PARAM_BASE + BASE_FORM].params
    form = $data_classes[BASE_PARAM_BASE + persona_id].params
    stats = Marshal.load(Marshal.dump(base))
    STATS.times do |stat|
      (0..TABLE_LEVEL).each do |level|
        share = luka[stat, level].to_i == 0 ? 1.0 : form[stat, level].to_i / luka[stat, level].to_f
        stats.params[stat, level] = stat_value(base.params[stat, level].to_i * share)
      end
    end
    stats
  end

  # Rounds a stat and keeps it in STAT_RANGE.
  #
  # @param value [Numeric] The stat.
  # @return [Integer] The stat the table can keep.
  def self.stat_value(value)
    [[(value + 0.5).floor, STAT_RANGE.first].max, STAT_RANGE.last].min
  end

  # Builds the stats by level of a hero's custom curves, once per hero.
  #
  # @param hero [Hero] The hero.
  # @return [RPG::Class, nil] Luka's stats job with the curves' values, nil without all of them.
  def self.custom_stats(hero)
    return nil unless (0...STATS).all? { |stat| hero.curves[stat] }

    @custom_stats ||= {}
    @custom_stats[hero.key] ||= begin
      stats = Marshal.load(Marshal.dump($data_classes[BASE_PARAM_BASE + BASE_FORM]))
      STATS.times do |stat|
        (0..TABLE_LEVEL).each { |level| stats.params[stat, level] = curve_value(hero.curves[stat], level) }
      end
      stats
    end
  end

  # Works out a stat at a level of its curve: from the level 1 value to the level 99 value along
  # the power 2^(growth/10) of the share of the way.
  #
  # @param curve [Array(Integer, Integer, Integer)] The level 1 value, level 99 value and growth.
  # @param level [Integer] The level, 0 to 99.
  # @return [Integer] The value.
  def self.curve_value(curve, level)
    first, last, growth = curve
    share = [[level - 1, 0].max, TABLE_LEVEL - 1].min / (TABLE_LEVEL - 1).to_f
    stat_value(first + (last - first) * share ** (2 ** (growth / 10.0)))
  end

  # Finds the EXP curve a character's base level follows, when the hero has their own: in every
  # form of Luka, Father of Chaos included.
  #
  # The game keeps the EXP and not the curve, so a form on another curve would move the EXP out of
  # the level's range, and the next gain would level the character down.
  #
  # @param actor [Game_Actor] The character.
  # @return [RPG::Class, nil] The hero's curve, nil to keep the character's own.
  def self.exp_curve(actor)
    return nil unless (PERSONAS + [FATHER_OF_CHAOS]).include?(actor.id)

    hero = hero(actor.instance_variable_get(:@mgq_luka_key) || @current)
    hero && hero.exp_curve ? $data_classes[hero.exp_curve] : nil
  rescue => e
    log("could not find the hero's EXP curve: #{e.class}: #{e.message}")
    nil
  end

  # Puts the EXP of Luka of the loaded game back into his level's range on the curve he follows
  # now, keeping the level, for a save started before the hero's pack changed the curve.
  def self.fit_exp
    return unless $game_actors && $game_actors.exist?(BASE_FORM)

    luka = $game_actors[BASE_FORM]
    first = luka.current_level_exp(:base)
    return if luka.base_exp >= first && (luka.base_exp < luka.next_level_exp(:base) || luka.max_level?(:base))

    log("hero #{@current}: EXP #{luka.base_exp} set to #{first}, the start of level #{luka.base_level}")
    luka.base_exp = first
  rescue => e
    log("could not fit the hero's EXP to their curve: #{e.class}: #{e.message}")
  end

  # Runs a check of whether a character can equip an item, so exclusive_actors knows whose it is.
  #
  # @param actor [Game_Actor] The character.
  # @return [Object] What the block returns.
  def self.with_wearer(actor)
    wearer = @wearer
    @wearer = actor
    yield
  ensure
    @wearer = wearer
  end

  # Lists who may equip an item reserved for some characters: for a hero, also the hero's form
  # when the item is reserved for the character they are based on, or that the form is.
  #
  # @param actor_ids [Array<Integer>, nil] The characters the game reserves the item for.
  # @return [Array<Integer>, nil] The characters, with the hero's form when it may equip the item.
  def self.exclusive_actors(actor_ids)
    actor = @wearer
    return actor_ids unless actor_ids && actor && !actor_ids.include?(actor.id)

    (gear_owners(actor) & actor_ids).empty? ? actor_ids : actor_ids + [actor.id]
  rescue => e
    log("could not check the hero's reserved gear: #{e.class}: #{e.message}")
    actor_ids
  end

  # Lists the characters whose reserved gear a character may equip as a hero: the hero's source
  # and the source of the form.
  #
  # @param actor [Game_Actor] The character.
  # @return [Array<Integer>] The actors, none for anyone but a hero.
  def self.gear_owners(actor)
    hero = hero_of(actor)
    return [] unless hero

    form = actor.id != BASE_FORM && hero.forms[actor.id]
    [hero.source_id, form ? form.source_id : nil].compact
  end

  # Reads what the hero's pack makes of something the story gives Luka.
  #
  # @param kind [String] "class" for a job or race, "skill" for a skill.
  # @param id [Integer] What the story gives.
  # @return [Symbol, Integer, nil] :skip, the id given instead, or nil to give it as the story does.
  def self.story_rule(kind, id)
    hero = hero(@current)
    hero && hero.story["#{kind}:#{id}"]
  end

  # Works out the job or race the story gives a character as the hero's pack has it.
  #
  # @param actor_id [Integer] The character.
  # @param class_id [Integer] The job or race the story gives.
  # @param event [String, nil] The key of the event running, nil for none.
  # @return [Integer, nil] The job or race given, nil for none.
  def self.story_class(actor_id, class_id, event)
    return class_id unless PERSONAS.include?(actor_id)
    return nil if skipped_here?("class", class_id, event)

    rule = story_rule("class", class_id)
    rule == :skip ? nil : rule || class_id
  rescue => e
    log("could not apply the story rule for class #{class_id}: #{e.class}: #{e.message}")
    class_id
  end

  # Works out the form the story changes Luka into as the hero's pack has it.
  #
  # A change counts by the form it leaves: leaving the Chaos form, to any form, ends it ("back:3",
  # as after the Koron fight, which returns to the cross-dressing form when Luka wore it); leaving
  # the cross-dressing form for the base form ends that ("back:2"); any other change starts the
  # form it goes to ("form:2", "form:3"). The same event can do either, so only the form Luka is
  # in tells which.
  #
  # @param persona_id [Integer] The form the story changes into.
  # @param event [String, nil] The key of the event running, nil for none.
  # @return [Integer, nil] The form changed into, nil for none.
  def self.story_form(persona_id, event)
    return persona_id unless FORMS.include?(persona_id)

    luka = $game_actors && $game_actors[BASE_FORM]
    leaving = luka ? luka.id : BASE_FORM
    return persona_id if leaving == persona_id || !FORMS.include?(leaving)
    return story_end(leaving, persona_id, event) if leaving == CHAOS_FORM || persona_id == BASE_FORM
    return nil if skipped_here?("form", persona_id, event)

    rule = story_rule("form", persona_id)
    return nil if rule == :skip

    FORMS.include?(rule) ? rule : persona_id
  rescue => e
    log("could not apply the story rule for form #{persona_id}: #{e.class}: #{e.message}")
    persona_id
  end

  # Works out where the story takes the hero when it ends a later form: the rules of that form's
  # end.
  #
  # @param ending [Integer] The later form that ends.
  # @param persona_id [Integer] The form the story changes into.
  # @param event [String, nil] The key of the event running, nil for none.
  # @return [Integer, nil] The form changed into, nil to stay in the form.
  def self.story_end(ending, persona_id, event)
    return nil if skipped_here?("back", ending, event)

    rule = story_rule("back", ending)
    return nil if rule == :skip

    FORMS.include?(rule) && rule != ending ? rule : persona_id
  end

  # Works out what the hero gets where the story's Change Skills command teaches a skill.
  #
  # @param params [Array] The command's parameters: actor kind, actor, learn or forget, skill.
  # @param event [String, nil] The key of the event running, nil for none.
  # @return [Symbol, Integer, nil] :skip, the skill taught instead, or nil to run the command as
  #   the story does.
  def self.story_skill(params, event)
    return nil unless params[2] == 0

    skipped_here?("skill", params[3], event) ? :skip : story_rule("skill", params[3])
  rescue => e
    log("could not apply the story rule for skill #{params[3]}: #{e.class}: #{e.message}")
    nil
  end

  # Tells whether the hero's pack takes away what the story gives at the event giving it.
  #
  # @param kind [String] "class", "skill" or "form".
  # @param id [Integer] What the story gives.
  # @param event [String, nil] The key of the event running, nil for none.
  # @return [Boolean] Whether the hero does not get it there.
  def self.skipped_here?(kind, id, event)
    hero = hero(@current)
    hero && event && hero.skipped_at["#{kind}:#{id}@#{event}"] ? true : false
  end

  # Names the event an interpreter runs: a common event by its list, else the map's event.
  #
  # @param list [Array<RPG::EventCommand>] The commands it runs.
  # @param map_id [Integer] The map it started on.
  # @param event_id [Integer] The map's event, 0 for none.
  # @return [String, nil] The event's key, nil for a battle's or another list.
  def self.event_key(list, map_id, event_id)
    @common_lists ||= ($data_common_events || []).compact.each_with_object({}) { |common, found| found[common.list.object_id] = common.id }
    common_id = @common_lists[list.object_id]
    return "ce:#{common_id}" if common_id

    event_id.to_i > 0 ? "map:#{map_id}:#{event_id}" : nil
  rescue => e
    log("could not name an event: #{e.class}: #{e.message}")
    nil
  end

  # Gives the hero what their pack adds after a story event, once per game.
  #
  # @param event [String, nil] The key of the event that ran, nil for none.
  def self.event_done(event)
    hero = event && hero(@current)
    return unless hero && $game_system

    done = ($game_system.mgq_luka_gains ||= [])
    hero.gains.each do |key, kind, id|
      tag = "#{kind}:#{id}@#{key}"
      next if key != event || done.include?(tag)

      done.push(tag)
      kind == :form ? $game_party.persona_change(id) : $game_actors[BASE_FORM].learn_skill(id)
      log("hero #{hero.key}: gained #{tag}")
    end
  rescue => e
    log("could not give what the hero gains at #{event}: #{e.class}: #{e.message}")
  end

  # Tells whether the hero's pack keeps their own actor from joining as a companion.
  #
  # @param actor_id [Integer] The actor about to join.
  # @return [Boolean] Whether that actor is the hero's source and their pack blocks it.
  def self.blocked?(actor_id)
    hero = hero(@current)
    hero && hero.recruit_self == :block && hero.source_id == actor_id ? true : false
  end

  # Swaps the hero's own actor for their stand-in in a party the story sets.
  #
  # @param actor_ids [Array<Integer>] The party's actors.
  # @return [Array<Integer>] The actors, the hero's own one replaced when their pack names a
  #   stand-in.
  def self.stand_in(actor_ids)
    hero = hero(@current)
    return actor_ids unless hero && hero.stand_in && hero.source_id

    actor_ids.map { |actor_id| actor_id == hero.source_id ? hero.stand_in : actor_id }
  end

  # Writes the hero's name where a text names Luka. Translated names are swapped as whole words but
  # KEPT_NAMES; untranslated ones only as the speaker, since Japanese words like イルカ contain ルカ.
  #
  # @param text [String] The text, its escape codes converted.
  # @return [String] The text naming the hero.
  def self.rename(text)
    return text unless @current && text.is_a?(String)

    hero_name = name_of(hero(@current))
    text.gsub(name_pattern) { |found| KEPT_NAMES.include?(found) ? found : hero_name }
  rescue => e
    log("could not rename Luka in a text: #{e.class}: #{e.message}")
    text
  end

  # Builds what finds Luka's name in a text, KEPT_NAMES included so they stay whole.
  #
  # @return [Regexp] The pattern.
  def self.name_pattern
    @name_pattern ||= begin
      name = Regexp.escape(luka_name)
      kept = KEPT_NAMES.map { |kept_name| Regexp.escape(kept_name) }.join("|")
      luka_name =~ ASCII_NAME ? /\b(?:#{kept}|#{name})\b/ : /(?<=【|<)#{name}(?=】|>)/
    end
  end

  # Writes the hero's name into a text about to be drawn, like the save screen's "Luka Level:".
  #
  # A text that already names the hero is left, so a hero whose name contains Luka's is not named
  # twice.
  #
  # @param args [Array] The arguments of Bitmap#draw_text, changed in place.
  def self.rename_drawn(args)
    index = args.first.is_a?(Rect) ? 1 : 4
    text = args[index]
    return unless text.is_a?(String) && text.include?(luka_name) && !text.include?(name_of(hero(@current)))

    args[index] = rename(text)
  rescue => e
    log("could not rename Luka in a drawn text: #{e.class}: #{e.message}")
  end

  # Finds whose battle lines a character speaks: the source of the hero's form, else the hero's,
  # when the game has lines of theirs.
  #
  # @param actor [Game_Battler] The character.
  # @return [Integer, nil] The source's actor id, nil for the character's own lines.
  def self.lines_source(actor)
    hero = hero_of(actor)
    return nil unless hero && defined?(NWConst::Actor::SKILL_WORDS)

    form = actor.id != BASE_FORM && hero.forms[actor.id]
    source_id = (form && form.source_id) || hero.source_id
    source_id && NWConst::Actor::SKILL_WORDS.key?(source_id) ? source_id : nil
  rescue => e
    log("could not find the hero's battle lines: #{e.class}: #{e.message}")
    nil
  end

  # Builds the battle lines and cut-ins of a character: for a hero, the lines without their
  # cut-ins, then the hero's cut-ins of the form.
  #
  # @param actor [Game_Battler] The character.
  # @param table [Hash, nil] The lines the game found, by skill id or ids.
  # @return [Hash, nil] The lines, the game's for anyone but a hero.
  def self.skill_word_hash(actor, table)
    hero = hero_of(actor)
    return table unless hero

    @word_tables ||= {}
    @word_tables[[hero.key, actor.id, table.object_id]] ||= word_table(hero, table, cutins_of(hero, actor.id))
  rescue => e
    log("could not build the hero's battle lines: #{e.class}: #{e.message}")
    table
  end

  # Builds a hero's battle lines from a character's.
  #
  # Each cut-in goes last under its own key, since the game takes the last entry naming a skill;
  # it keeps that skill's lines. Entries the game shares with every character (summons, marked
  # :common) keep their cut-ins.
  #
  # @param hero [Hero] The hero.
  # @param table [Hash, nil] The character's lines, by skill id or ids.
  # @param cutins [Array<Array>] The hero's cut-ins in the form.
  # @return [Hash, nil] The lines, nil when there are neither lines nor cut-ins.
  def self.word_table(hero, table, cutins)
    return nil unless table || !cutins.empty?

    words = {}
    (table || {}).each do |skill_key, entry|
      words[skill_key] = entry[:common] ? entry : entry.reject { |field, _| CUTIN_FIELDS.include?(field) }
    end
    cutins.each do |skill_ids, type, image, se|
      picture = image[0] == :pack ? "lr~#{hero.key}~#{image[1]}" : image[1]
      skill_ids.each do |skill_id|
        found = words.keys.select { |skill_key| skill_key.respond_to?(:include?) ? skill_key.include?(skill_id) : skill_key == skill_id }.last
        entry = found ? words[found].dup : {}
        words.delete([skill_id])
        words[[skill_id]] = entry.merge(:ct_type => type, :ct_pic => picture, :ct_se => se)
      end
    end
    words
  end

  # Lists a hero's cut-ins in a form: the form's own when its pack lines give any, else the base
  # form's.
  #
  # @param hero [Hero] The hero.
  # @param persona_id [Integer] One of PERSONAS.
  # @return [Array<Array>] The cut-ins.
  def self.cutins_of(hero, persona_id)
    form = persona_id != BASE_FORM && hero.forms[persona_id]
    (form && form.cutins) || hero.cutins
  end

  # Makes a battle or knock-out line a hero speaks theirs: their name as the speaker of another
  # character's line, and their face of the form, in the cell line_cell picks, in place of that
  # character's face or Luka's. A line with the source's face swaps only for a hero with a face of
  # their own.
  #
  # Word#replace_name only knows the untranslated game's 【Name】, so the translated "\n<Name>"
  # is renamed here too.
  #
  # @param actor [Game_Battler] The character speaking.
  # @param word [Word, nil] The line.
  # @param situation [Symbol] One of SITUATIONS, :skill for any battle skill line.
  # @return [Word, nil] The line, a changed copy for a hero.
  def self.dress_word(actor, word, situation)
    hero = word && !word.common && hero_of(actor)
    return word unless hero

    source_id = lines_source(actor)
    face = face_of(hero, actor.id)
    shown = word.instance_variable_get(:@face_name)
    sources_face = source_id && image_of(hero, :face, actor.id) && shown == $data_actors[source_id].face_name
    swapped = face && (sources_face || luka_face?(shown))
    return word unless source_id || swapped

    dressed = Marshal.load(Marshal.dump(word))
    rename_speaker(dressed, $data_actors[source_id].name, name_of(hero)) if source_id
    if swapped
      source_cell = sources_face ? word.instance_variable_get(:@face_index) : nil
      dressed.instance_variable_set(:@face_name, face[0])
      dressed.instance_variable_set(:@face_index, line_cell(hero, actor, face, source_cell, situation))
    end
    dressed
  rescue => e
    log("could not give the hero a battle line: #{e.class}: #{e.message}")
    word
  end

  # Names a hero as the speaker of a line in place of the character it comes from.
  #
  # @param word [Word] The line, changed in place.
  # @param source_name [String] The character's name.
  # @param hero_name [String] The hero's name.
  def self.rename_speaker(word, source_name, hero_name)
    speaker = /(【|\\<n|<)#{Regexp.escape(source_name)}(?=】|>)/
    lines = word.instance_variable_get(:@words)
    lines.map! { |line| line.gsub(speaker) { "#{$1}#{hero_name}" } } if lines
  end

  # Picks the cell of a hero's face sheet a battle or knock-out line shows: the cell of the
  # based-on character's face the line shows when the form follows their lines, else the
  # situation's, else the normal cell, each only when the sheet has it.
  #
  # @param hero [Hero] The hero.
  # @param actor [Game_Battler] The character speaking.
  # @param face [Array(String, Integer)] The hero's face sheet in the form and its normal cell.
  # @param source_cell [Integer, nil] The cell of the based-on character's face the line shows,
  #   nil for a line with another face.
  # @param situation [Symbol] One of SITUATIONS, :skill for any battle skill line.
  # @return [Integer] The cell.
  def self.line_cell(hero, actor, face, source_cell, situation)
    return source_cell if source_cell && follows_lines?(hero, actor.id) && face_cell?(face[0], source_cell)

    situation = :pinch if situation == :skill && actor.hp <= actor.mhp * PINCH_HP
    cell = expressions_of(hero, actor.id)[situation]
    cell && face_cell?(face[0], cell) ? cell : face[1]
  end

  # Tells whether a character has a cut-in for a skill, without raising for a skill no line names.
  #
  # @param actor [Game_Battler] The character, a hero.
  # @param skill_id [Integer] The skill.
  # @return [Boolean] Whether a cut-in plays.
  def self.cutin?(actor, skill_id)
    words = actor.skill_word_hash && actor.skill_words(skill_id)
    words ? words.key?(:ct_type) : false
  rescue => e
    log("could not look up the hero's cut-in: #{e.class}: #{e.message}")
    false
  end

  # Tells whether a character is a heroine, whom Luka's climax effect in battle leaves out.
  #
  # @param actor [Game_Battler, nil] The character.
  # @return [Boolean] Whether the character plays a female hero.
  def self.heroine?(actor)
    hero = hero_of(actor)
    hero && hero.sex == :female ? true : false
  rescue => e
    log("could not tell whether the hero is female: #{e.class}: #{e.message}")
    false
  end

  # Tells whether a character may learn the skills the game keeps from Luka, like monster skills.
  #
  # @param actor [Game_Actor] The character.
  # @return [Boolean] Whether the character plays a hero whose pack allows it.
  def self.monster_skills?(actor)
    hero = hero_of(actor)
    hero && hero.monster_skills ? true : false
  rescue => e
    log("could not tell whether the hero learns monster skills: #{e.class}: #{e.message}")
    false
  end

  # Reads the hero a character shows, for the builds MGQ Online sends to other players.
  #
  # @param actor [Game_Actor] The character.
  # @return [String] The hero's key, "" for Luka and every other character.
  def self.hero_key(actor)
    return "" unless PERSONAS.include?(actor.id)

    key = actor.instance_variable_get(:@mgq_luka_key) || @current
    hero(key) ? key : ""
  end

  # Gives Luka of another player's game, rebuilt in this one, the hero that game plays, for MGQ
  # Online. Leaves the character's job, levels and equipment to the rebuild. A hero without a pack
  # in this game shows as Luka.
  #
  # @param actor [Game_Actor] The rebuilt character.
  # @param key [String] The hero's key, "" for Luka.
  def self.dress(actor, key)
    return unless PERSONAS.include?(actor.id)

    actor.instance_variable_set(:@mgq_luka_key, hero(key) ? key : "")
    data = actor.actor
    actor.instance_variable_set(:@name, data.name)
    actor.instance_variable_set(:@nickname, data.nickname)
    actor.set_graphic(data.character_name, data.character_index, data.face_name, data.face_index)
  rescue => e
    log("could not dress a character as #{key.inspect}: #{e.class}: #{e.message}")
  end

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Title.method_defined?(:mgq_luka_replacer_command_new_game)
  end

  # Appends a line to LOG_FILE, prefixed with the time.
  #
  # @param message [String] The line to append.
  def self.log(message)
    @log_lines = (@log_lines || 0) + 1
    return if @log_lines > MAX_LOG_LINES

    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    File.open("#{LOG_DIR}/#{LOG_FILE}", "ab") { |file| file.write("#{Time.now}  #{message}\n") }
  rescue
  end

  # Hero packs: a hero file <key>.luka per hero in HEROES_DIR. It
  # holds the entry PACK_FILE and a <file>.png entry per pack image, hidden so that no text editor
  # opens it.
  #
  # PACK_FILE holds key=value lines; # starts a comment. Keys a pack leaves out keep Luka's, or
  # take the source actor's where it names one:
  #
  #   format=1                     the pack format
  #   name=, nickname=             the hero's name and title
  #   source=<actor>               the actor whose name, title and looks the hero takes by default
  #   trait_from=<actor>           an actor whose trait (features, trait tags, description) the
  #                                hero takes, before the pack's own feature= and tag= lines
  #   level=<n>                    the level the hero starts at; companions join at the hero's level
  #   job=<id>, race=<id>          the starting job and race
  #   class_levels=<id>-<lv>,...   the jobs and races the hero starts with and their levels; the
  #                                hero can change between them from the start
  #   base_stats=luka|<actor>|custom   whose stats by level the hero has: Luka's, an actor's or
  #                                the hero's own from the stat lines
  #   stat0= to stat7=<lv1>,<lv99>,<growth>   a custom curve per stat (max HP first): the values
  #                                at levels 1 and 99, and growth from -10 (early) to 10 (late)
  #   equip0= to equip5=<id>       starting equipment by slot (0 the weapon), 0 for none
  #   sprite=, face=               game:<file>#<index> or pack:<file>; a face file may be a sheet of
  #                                1-4 columns and 1-2 rows of 96x96 cells, cell n at column n % 4,
  #                                row n / 4
  #   face_cell=<n>                the cell of a pack face in story messages and menus, 0 when left
  #                                out; a game face's is its #<index>
  #   expressions=<situation>:<n>,...   the cell battle and knock-out lines show by situation: skill,
  #                                pinch (skill lines at 25% HP or less), down, pleasure, eaten; a
  #                                situation left out shows the normal cell
  #   expressions_follow_lines=yes  a line of the based-on character with their face shows the
  #                                hero's cell of the same number
  #   picture=                     the Library picture: game:<file> or pack:<file>
  #   trait=, trait_line=          the trait's name and description lines
  #   feature=<code>:<id>:<value>  a database feature of the trait
  #   tag=<...>                    a note tag of the trait
  #   story=class|skill:<id>:keep|skip|<id>   what the hero gets where the story gives Luka that;
  #                                form:2|3 for a change into a form, back:2|3 for a change back to
  #                                the base form ending that form (the replacement is a form 1-3)
  #   recruit_self=allow|block     whether the source actor may also join as a companion
  #   stand_in=<actor>             who takes the source actor's place in parties the story sets
  #   story_skip=<kind>:<id>@<event>   a story event where the hero does not get that, like
  #                                skill:937@map:858:230, form:2@ce:3880 or back:3@ce:9058
  #   story_add=skill|form:<id>@<event>   a skill or ability, or a change into form 1, 2 or 3, the
  #                                hero gets once after that event ran
  #   carry_knight=, carry_princess=   the sprites where Luka carries the knight or the princess:
  #                                game:<file>#<index> or pack:<file>; left out, the hero's sprite
  #   sex=male|female              which skills that only affect one sex affect the hero
  #   artist=<text>                the Library's artist credit; left out, none
  #   categories=<name>,...        the categories, as the game's notes name them; empty for none
  #   special_categories=<id>,...  the special categories; empty for none
  #   seduction_skill=<id>         the skill used under seduction; 0 for none
  #   skill_change=<id>-<id>,...   the skills that turn into others; empty for none
  #   exp_curve=<job>              the job whose EXP table the hero's level follows, in every form
  #                                of Luka (his is 386)
  #   sp_base=<n>                  max SP before levels (Luka's 5)
  #   sp_level=<n>, sp_level100=<n>   hundredths of a max SP point gained per level, up to level 99
  #                                and past it (Luka's 30 each); up to two decimals
  #   sp_start=<n>                 the percent of max SP the hero starts a battle with (Luka's 50)
  #   learn_monster_skills=yes     lets the hero learn the skills the game keeps from Luka
  #   luka_features=keep|drop      whether every form keeps the extras of Luka's Hero's Blood
  #   cutin=<skill>,...;<type>;<image>[;<sound>]   a cut-in for those skills: type basic, slide,
  #                                focus or long, image game:<picture> or pack:<file>, and a sound
  #                                effect; left out, the hero has no cut-ins
  #   form2.sprite=, form2.face=, form2.picture=   the looks of Luka's later forms (form2 and
  #                                form3); left out, the base form's
  #   form2.source=<actor>         the actor whose battle lines the form speaks; left out, source's
  #   form2.cutin=                 the form's cut-ins; without any, the base form's
  #   form2.face_cell=             the cell of the form's own pack face
  #   form2.expressions=, form2.expressions_follow_lines=   the form's; left out, the base form's
  #   form2.own_trait=yes          gives the form its own trait from its form2.trait=,
  #                                form2.trait_line=, form2.feature= and form2.tag= lines;
  #                                without it, the form has the base trait
  #
  # The categories, special categories, seduction skill, skill change, EXP curve and SP lines, left
  # out, are Luka's in each form; set, they are the hero's in every form. Gear the game reserves for
  # the source actor, or for a form's source in that form, fits the hero too.
  #
  # A pack is plain text and images, never Ruby or Marshal data, since loading those from someone
  # else's file could run code.
  module Pack
    # Finds the hero files.
    #
    # @return [Array<Array(String, String)>] The key and path of each, by key.
    def self.files
      Dir.glob("#{HEROES_DIR}/*#{HERO_FILE}").map { |path| [File.basename(path, HERO_FILE), path] }
         .select { |key, _| key =~ KEY }.sort
    end

    # Reads the entries of a hero file: HERO_MAGIC, the version byte, then the body, a zlib stream
    # hidden by crypt.
    #
    # @param path [String] The hero file.
    # @return [Hash{String => String}] The data of each entry, by name.
    # @raise [RuntimeError] When the file is no hero file this mod reads.
    def self.entries(path)
      raw = File.open(path, "rb") { |file| file.read }
      raise "it is no hero file" unless raw.size > HERO_MAGIC.size + 1 && raw[0, HERO_MAGIC.size] == HERO_MAGIC
      raise "its version #{raw.getbyte(HERO_MAGIC.size)} is unknown" unless raw.getbyte(HERO_MAGIC.size) == HERO_VERSION

      parse(Zlib::Inflate.inflate(crypt(raw[(HERO_MAGIC.size + 1)..-1])))
    end

    # Splits the payload of a hero file into its entries: a 16-bit count, then per entry a 16-bit
    # name length, the name, a 32-bit data length and the data, all little-endian.
    #
    # @param payload [String] The payload, binary.
    # @return [Hash{String => String}] The data of each entry, by name.
    # @raise [RuntimeError] When the payload is cut short.
    def self.parse(payload)
      payload.force_encoding("ASCII-8BIT")
      found = {}
      offset = 2
      take(payload, 0, 2).unpack("v")[0].times do
        name_size = take(payload, offset, 2).unpack("v")[0]
        name = take(payload, offset + 2, name_size).force_encoding("UTF-8")
        data_size = take(payload, offset + 2 + name_size, 4).unpack("V")[0]
        found[name] = take(payload, offset + 6 + name_size, data_size)
        offset += 6 + name_size + data_size
      end
      found
    end

    # Cuts a piece out of a payload.
    #
    # @param payload [String] The payload, binary.
    # @param offset [Integer] Where the piece starts.
    # @param size [Integer] Its size in bytes.
    # @return [String] The piece.
    # @raise [RuntimeError] When the payload ends before the piece does.
    def self.take(payload, offset, size)
      piece = payload[offset, size]
      raise "it is cut short" unless piece && piece.size == size

      piece
    end

    # Hides or reveals the body of a hero file: each byte XOR the keystream's byte at its place.
    #
    # The bytes are XORed in 16-bit pairs, since RGSS3's Ruby keeps only 30-bit numbers small and
    # a byte at a time is slow for large images.
    #
    # @param data [String] The body or the zlib stream, binary.
    # @return [String] The other one.
    def self.crypt(data)
      padded = data + "\0" * (data.size % 2)
      words = padded.unpack("v*")
      keys = keystream(padded.size).unpack("v*")
      words.each_index { |index| words[index] ^= keys[index] }
      words.pack("v*")[0, data.size]
    end

    # Builds the keystream as far as a size, kept for the next file: per byte the generator's next
    # state, then its bits 16 to 23.
    #
    # @param size [Integer] The bytes needed.
    # @return [String] The keystream's first size bytes, binary.
    def self.keystream(size)
      @keystream ||= "".force_encoding("ASCII-8BIT")
      @key_state ||= KEY_SEED
      missing = size - @keystream.size
      if missing > 0
        bytes = Array.new(missing) do
          @key_state = (@key_state * KEY_MULTIPLIER + KEY_INCREMENT) & 0xFFFFFFFF
          (@key_state >> 16) & 0xFF
        end
        @keystream << bytes.pack("C*")
      end
      @keystream[0, size]
    end

    # Reads the pack text of a hero file.
    #
    # @param data [String] The PACK_FILE entry.
    # @return [String] Its text.
    def self.text(data)
      data.dup.force_encoding("UTF-8").sub(/\A﻿/, "")
    end

    # Unpacks the images of a hero file into its cache folder, unless they come from this very file
    # already, so the game loads them from there.
    #
    # @param key [String] The hero's key.
    # @param path [String] The hero file.
    # @param entries [Hash{String => String}] The file's entries.
    # @return [String] The cache folder; a failed unpack leaves images out, which check logs.
    def self.unpack_images(key, path, entries)
      dir = "#{CACHE_DIR}/#{key}"
      stat = File.stat(path)
      stamp = "#{stat.size} #{stat.mtime.to_i} #{stat.mtime.usec}"
      stamp_path = "#{dir}/#{STAMP_FILE}"
      return dir if File.exist?(stamp_path) && File.open(stamp_path, "rb") { |file| file.read } == stamp

      make_dir(dir)
      Dir.glob("#{dir}/*.png").each { |old| File.delete(old) }
      entries.each do |name, data|
        next unless name =~ IMAGE_ENTRY

        File.open("#{dir}/#{name}", "wb") { |file| file.write(data) }
      end
      File.open(stamp_path, "wb") { |file| file.write(stamp) }
      dir
    rescue => e
      MGQ_LukaReplacer.log("could not unpack the images of #{File.basename(path)}: #{e.class}: #{e.message}")
      dir
    end

    # Makes a folder and those above it that are missing.
    #
    # @param dir [String] The folder, its parts split by "/".
    def self.make_dir(dir)
      made = nil
      dir.split("/").each do |part|
        made = made ? "#{made}/#{part}" : part
        Dir.mkdir(made) unless File.directory?(made)
      end
    end

    # Reads a pack.
    #
    # @param text [String] The pack's text.
    # @param key [String] The hero's key.
    # @param dir [String, nil] The folder of the hero's images, nil for a built-in hero.
    # @return [Hero] The hero.
    def self.read(text, key, dir)
      hero = Hero.new(key, nil, nil, nil, nil, nil, nil, :luka, {}, nil, nil, nil, nil, [], [], [], {}, :allow, nil, :male, {}, nil, {}, {}, {}, [], {}, dir,
                      nil, nil, nil, nil, nil, false, :keep, [], nil, nil, false, nil, nil, nil, nil, nil)
      text.each_line do |raw|
        line = raw.strip
        next if line.empty? || line.start_with?("#")

        name, value = line.split("=", 2)
        name = name.strip
        value = value.to_s.strip
        if (form = FORM_KEY.match(name))
          read_form_line(hero, form[1].to_i, form[2], value)
        else
          read_line(hero, name, value)
        end
      end
      hero
    end

    # Reads one formN.key=value line into a hero's form.
    #
    # @param hero [Hero] The hero.
    # @param persona_id [Integer] The form's actor id.
    # @param name [String] The key after "formN.".
    # @param value [String] The value.
    def self.read_form_line(hero, persona_id, name, value)
      form = hero.forms[persona_id] ||= Form.new(nil, nil, nil, false, nil, [], [], [], nil, nil, nil, nil, nil)
      case name
      when "sprite" then form.sprite = image(value, true)
      when "face" then form.face = image(value, true)
      when "face_cell" then form.face_cell = number(value)
      when "expressions" then expressions(form, value)
      when "expressions_follow_lines" then form.follow_lines = value == "yes"
      when "picture" then form.picture = image(value, false)
      when "source" then form.source_id = number(value)
      when "cutin" then cutin(form, value)
      when "own_trait" then form.own_trait = value == "yes"
      when "trait" then form.trait_name = value
      when "trait_line" then form.trait_lines.push(value)
      when "feature" then feature(form, value)
      when "tag" then form.tags.push(value) if value =~ /\A<[^<>]+>\z/
      end
    end

    # Reads one key=value line into a hero.
    #
    # @param hero [Hero] The hero.
    # @param name [String] The key.
    # @param value [String] The value.
    def self.read_line(hero, name, value)
      case name
      when "format" then raise "pack format #{value} is newer than this mod" if value.to_i > PACK_FORMAT
      when "name" then hero.name = value unless value.empty?
      when "nickname" then hero.nickname = value unless value.empty?
      when "source" then hero.source_id = number(value)
      when "trait_from" then hero.trait_from = number(value)
      when "level" then hero.level = number(value)
      when "job" then hero.job_id = number(value)
      when "race" then hero.race_id = number(value)
      when "class_levels" then class_levels(hero, value)
      when "base_stats" then hero.base_stats = value == "custom" ? :custom : number(value) || :luka
      when /\Aequip([0-5])\z/ then hero.equips[$1.to_i] = number(value) || 0
      when /\Astat([0-7])\z/ then curve(hero, $1.to_i, value)
      when "sprite" then hero.sprite = image(value, true)
      when "face" then hero.face = image(value, true)
      when "face_cell" then hero.face_cell = number(value)
      when "expressions" then expressions(hero, value)
      when "expressions_follow_lines" then hero.follow_lines = value == "yes"
      when "picture" then hero.picture = image(value, false)
      when "trait" then hero.trait_name = value
      when "trait_line" then hero.trait_lines.push(value)
      when "feature" then feature(hero, value)
      when "tag" then hero.tags.push(value) if value =~ /\A<[^<>]+>\z/
      when "story" then story(hero, value)
      when "recruit_self" then hero.recruit_self = value == "block" ? :block : :allow
      when "stand_in" then hero.stand_in = number(value)
      when "story_skip" then at_event(value) { |key, event| hero.skipped_at["#{key}@#{event}"] = true }
      when "story_add" then at_event(value) { |key, event| gain(hero, key, event) }
      when "carry_knight" then hero.carry[:knight] = image(value, true)
      when "carry_princess" then hero.carry[:princess] = image(value, true)
      when "sex" then hero.sex = value == "female" ? :female : :male
      when "artist" then hero.artist = value unless value.empty? || value =~ /[<>]/
      when "categories" then hero.categories = list(value).select { |category| category =~ CATEGORY_NAME }
      when "special_categories" then hero.special_categories = list(value).map { |id| number(id) }.compact
      when "seduction_skill" then hero.seduction_skill = number(value)
      when "skill_change" then hero.skill_change = value if value.empty? || value =~ SKILL_CHANGE
      when "learn_monster_skills" then hero.monster_skills = value == "yes"
      when "luka_features" then hero.luka_features = value == "drop" ? :drop : :keep
      when "cutin" then cutin(hero, value)
      when "exp_curve", "sp_base", "sp_level", "sp_level100", "sp_start" then hero[name.to_sym] = value unless value.empty?
      end
    end

    # Splits a comma list.
    #
    # @param text [String] The value.
    # @return [Array<String>] The entries, without blanks.
    def self.list(text)
      text.split(",").map(&:strip).reject(&:empty?)
    end

    # Reads a cut-in: <skill>,...;<type>;<image>[;<sound effect>]. Its skills and type are checked
    # with the game's data.
    #
    # @param owner [Hero, Form] The hero or form whose cut-in it is.
    # @param text [String] The value.
    def self.cutin(owner, text)
      skill_ids, type, picture, se = text.split(";").map(&:strip)
      ids = list(skill_ids.to_s).map { |id| number(id) }
      shown = image(picture.to_s, false)
      return if ids.empty? || !ids.all? || !shown || !(se.to_s.empty? || (se =~ SE_NAME && se !~ /\.\./))

      (owner.cutins ||= []).push([ids, type.to_s, shown, se.to_s.empty? ? nil : se])
    end

    # Reads the cells of a face sheet by situation: <situation>:<cell>,... Situations are checked
    # with check, and several lines add up.
    #
    # @param owner [Hero, Form] The hero or form whose face it is.
    # @param text [String] The value; empty sets none, so a form shows only its normal cell.
    def self.expressions(owner, text)
      found = owner.expressions ||= {}
      list(text).each do |entry|
        situation, cell = entry.split(":", 2).map(&:strip)
        found[situation] = number(cell.to_s) if number(cell.to_s)
      end
    end

    # Reads a whole number.
    #
    # @param text [String] The value.
    # @return [Integer, nil] The number, nil when the value is none.
    def self.number(text)
      text =~ /\A\d{1,6}\z/ ? text.to_i : nil
    end

    # Reads an image: game:<file>#<index> or pack:<file>.
    #
    # @param text [String] The value.
    # @param indexed [Boolean] Whether a game image names a place in its file.
    # @return [Array, nil] [:game, file, index] or [:pack, file], nil for anything else.
    def self.image(text, indexed)
      kind, rest = text.split(":", 2)
      return [:pack, rest] if kind == "pack" && rest =~ PACK_IMAGE_FILE

      file, index = rest.to_s.split("#", 2)
      return nil unless kind == "game" && !file.to_s.empty? && file !~ /[\\\/:]|\.\./

      [:game, file, indexed ? index.to_i : 0]
    end

    # Reads a feature: <code>:<id>:<value>.
    #
    # @param owner [Hero, Form] The hero or form whose trait it belongs to.
    # @param text [String] The value.
    def self.feature(owner, text)
      code, data_id, value = text.split(":")
      return unless number(code.to_s) && number(data_id.to_s) && value.to_s =~ /\A-?\d+(\.\d+)?\z/

      owner.features.push([code.to_i, data_id.to_i, value.to_f])
    end

    # Reads <kind>:<id>@<event> and hands the normalized "kind:id" key and the event key on.
    #
    # @param text [String] The value.
    # @yieldparam key [String] Like "skill:937".
    # @yieldparam event [String] Like "map:858:230" or "ce:3880".
    def self.at_event(text)
      gain, event = text.split("@", 2)
      kind, id = gain.to_s.split(":")
      return unless STORY_KINDS.include?(kind) && number(id.to_s) && event.to_s =~ EVENT_KEY

      yield "#{kind}:#{id.to_i}", event
    end

    # Adds something a hero gets after a story event: a skill or ability, or a form.
    #
    # @param hero [Hero] The hero.
    # @param key [String] Like "skill:930" or "form:2".
    # @param event [String] The event's key.
    def self.gain(hero, key, event)
      kind, id = key.split(":")
      hero.gains.push([event, kind.to_sym, id.to_i]) if kind == "skill" || (kind == "form" && FORMS.include?(id.to_i))
    end

    # Reads the jobs and races a hero starts with: <class>-<level>,...
    #
    # @param hero [Hero] The hero.
    # @param text [String] The value.
    def self.class_levels(hero, text)
      text.split(",").each do |pair|
        class_id, level = pair.strip.split("-")
        hero.class_levels[class_id.to_i] = level.to_i if number(class_id.to_s) && number(level.to_s) && level.to_i > 0
      end
    end

    # Reads a stat's custom curve: <level 1 value>,<level 99 value>,<growth>.
    #
    # @param hero [Hero] The hero.
    # @param stat [Integer] The stat, 0 for max HP.
    # @param text [String] The value.
    def self.curve(hero, stat, text)
      first, last, growth = text.split(",")
      return unless number(first.to_s) && number(last.to_s) && growth.to_s =~ /\A-?\d{1,2}\z/

      hero.curves[stat] = [first.to_i, last.to_i, growth.to_i]
    end

    # Reads a story rule: class|skill:<id>:keep|skip|<id>.
    #
    # @param hero [Hero] The hero.
    # @param text [String] The value.
    def self.story(hero, text)
      kind, id, rule = text.split(":")
      return unless STORY_KINDS.include?(kind) && number(id.to_s)

      key = "#{kind}:#{id.to_i}"
      case rule
      when "skip" then hero.story[key] = :skip
      when "keep" then hero.story.delete(key)
      else hero.story[key] = number(rule.to_s) if number(rule.to_s)
      end
    end

    # Drops what a hero's pack names that this game's data lacks, logging each, so a pack made for
    # another game version still loads.
    #
    # @param hero [Hero] The hero.
    def self.check(hero)
      [:source_id, :trait_from, :stand_in].each do |field|
        id = hero[field]
        next unless id && !(id > 0 && $data_actors[id] && !$data_actors[id].name.to_s.empty?)

        problem(hero, "actor #{id}")
        hero[field] = nil
      end
      [:job_id, :race_id].each do |field|
        id = hero[field]
        next unless id && !(id > 0 && $data_classes[id])

        problem(hero, "job or race #{id}")
        hero[field] = nil
      end
      hero.class_levels.keys.each do |class_id|
        next if class_id > 0 && $data_classes[class_id]

        problem(hero, "job or race #{class_id}")
        hero.class_levels.delete(class_id)
      end
      if hero.base_stats.is_a?(Integer) && !$data_classes[BASE_PARAM_BASE + hero.base_stats]
        problem(hero, "base stats of actor #{hero.base_stats}")
        hero.base_stats = :luka
      end
      if hero.base_stats == :custom && !(0...STATS).all? { |stat| hero.curves[stat] }
        MGQ_LukaReplacer.log("hero #{hero.key}: the pack lacks a curve for some stats, Luka's stats used")
        hero.base_stats = :luka
      end
      hero.equips.each do |slot, item_id|
        table = slot == 0 ? $data_weapons : $data_armors
        next if item_id == 0 || (item_id < table.size && table[item_id])

        problem(hero, "equipment #{item_id}")
        hero.equips.delete(slot)
      end
      ([hero] + hero.forms.values).each do |owner|
        [:sprite, :face, :picture].each do |field|
          image = owner[field]
          next unless image && image[0] == :pack && !(hero.dir && File.exist?("#{hero.dir}/#{image[1]}.png"))

          problem(hero, "image #{image[1]}.png")
          owner[field] = nil
        end
      end
      hero.carry.keys.each do |field|
        image = hero.carry[field]
        next unless image && image[0] == :pack && !(hero.dir && File.exist?("#{hero.dir}/#{image[1]}.png"))

        problem(hero, "image #{image[1]}.png")
        hero.carry.delete(field)
      end
      hero.gains.reject! do |event, kind, id|
        missing = kind == :skill && !(id > 0 && $data_skills[id])
        problem(hero, "skill #{id} to gain at #{event}") if missing
        missing
      end
      hero.story.keys.each do |key|
        kind = key.split(":").first
        rule = hero.story[key]
        next unless rule.is_a?(Integer) && !story_target?(kind, rule)

        problem(hero, "#{kind} #{rule} to give for #{key}")
        hero.story.delete(key)
      end
      hero.forms.values.each do |form|
        next unless form.source_id && !(form.source_id > 0 && $data_actors[form.source_id] && !$data_actors[form.source_id].name.to_s.empty?)

        problem(hero, "actor #{form.source_id}")
        form.source_id = nil
      end
      if hero.seduction_skill.to_i > 0 && !$data_skills[hero.seduction_skill]
        problem(hero, "skill #{hero.seduction_skill} to use under seduction")
        hero.seduction_skill = nil
      end
      numbers(hero)
      if hero.exp_curve && !(hero.exp_curve > 0 && $data_classes[hero.exp_curve])
        problem(hero, "EXP curve #{hero.exp_curve}")
        hero.exp_curve = nil
      end
      ([hero] + hero.forms.values).each { |owner| owner.cutins.reject! { |cutin| !cutin?(hero, cutin) } if owner.cutins }
      ([hero] + hero.forms.values).each { |owner| owner.expressions = situations(hero, owner.expressions) if owner.expressions }
    end

    # Turns the values of a hero's NUMBER_TAGS into numbers, dropping and logging each that is none.
    #
    # @param hero [Hero] The hero.
    def self.numbers(hero)
      NUMBER_TAGS.each do |field, (pattern, _)|
        value = hero[field]
        next if value.nil?

        if value.to_s =~ pattern
          hero[field] = value.to_s.include?(".") ? value.to_f : value.to_i
        else
          MGQ_LukaReplacer.log("hero #{hero.key}: #{field}=#{value} is no valid number, left out")
          hero[field] = nil
        end
      end
    end

    # Keys the cells of a face sheet by the situations this mod knows, dropping any other.
    #
    # @param hero [Hero] The hero.
    # @param expressions [Hash{String => Integer}] The cells by the situation's name in the pack.
    # @return [Hash{Symbol => Integer}] The cells by one of SITUATIONS.
    def self.situations(hero, expressions)
      expressions.each_with_object({}) do |(name, cell), known|
        situation = SITUATIONS.find { |candidate| candidate.to_s == name }
        if situation
          known[situation] = cell
        else
          MGQ_LukaReplacer.log("hero #{hero.key}: unknown expression situation #{name}, left out")
        end
      end
    end

    # Tells whether what a story rule gives instead exists.
    #
    # @param kind [String] "class", "skill" or "form".
    # @param id [Integer] What the rule gives.
    # @return [Boolean] Whether the game has it.
    def self.story_target?(kind, id)
      case kind
      when "class" then id > 0 && $data_classes[id] ? true : false
      when "skill" then id > 0 && $data_skills[id] ? true : false
      else FORMS.include?(id)
      end
    end

    # Checks a cut-in: drops its skills the game lacks and gives it its type.
    #
    # @param hero [Hero] The hero.
    # @param cutin [Array] The cut-in, changed in place.
    # @return [Boolean] Whether the cut-in can play.
    def self.cutin?(hero, cutin)
      skill_ids, type, image, _ = cutin
      skill_ids.reject! do |skill_id|
        missing = !(skill_id > 0 && $data_skills[skill_id])
        problem(hero, "skill #{skill_id} for a cut-in") if missing
        missing
      end
      cutin[1] = CUTIN_TYPES.find { |known| known.to_s == type.to_s }
      problem(hero, "cut-in type #{type}") unless cutin[1]
      missing_image = image[0] == :pack && !(hero.dir && File.exist?("#{hero.dir}/#{image[1]}.png"))
      problem(hero, "image #{image[1]}.png") if missing_image
      !skill_ids.empty? && cutin[1] && !missing_image ? true : false
    end

    # Logs what a pack names that the game lacks.
    #
    # @param hero [Hero] The hero.
    # @param what [String] What is missing.
    def self.problem(hero, what)
      MGQ_LukaReplacer.log("hero #{hero.key}: this game has no #{what}, left out")
    end
  end

  # The status screen's trait and the Library's picture, which the game reads from tables by
  # actor id.
  module Library
    # Gives Luka's base form a hero's trait description and picture, or Luka's own again.
    #
    # @param hero [Hero, nil] The hero, nil for Luka.
    def self.apply(hero)
      PERSONAS.each do |persona_id|
        swap(:ACTOR_FIX_ABILITY, persona_id, hero && trait(hero, persona_id))
        swap(:ACTOR_IMAGE, persona_id, hero && picture(hero, persona_id))
      end
    end

    # Writes a hero's entry into a table of the game's Library, keeping Luka's to put back.
    #
    # @param name [Symbol] The table's constant in NWConst::Library.
    # @param persona_id [Integer] The form's actor id.
    # @param entry [Array, nil] The hero's entry, nil for Luka's.
    def self.swap(name, persona_id, entry)
      return unless defined?(NWConst::Library) && NWConst::Library.const_defined?(name)

      table = NWConst::Library.const_get(name)
      @luka ||= {}
      @luka[[name, persona_id]] = table[persona_id] unless @luka.key?([name, persona_id])
      value = entry || @luka[[name, persona_id]]
      if value
        table[persona_id] = value
      else
        table.delete(persona_id)
      end
    end

    # Reads a hero's trait description in a form: the form's own when it has its own trait, else
    # the base trait's, from the pack or the actor the pack copies the trait from.
    #
    # @param hero [Hero] The hero.
    # @param persona_id [Integer] The form's actor id.
    # @return [Array<String>, nil] The trait's name and lines, nil to show none.
    def self.trait(hero, persona_id)
      form = MGQ_LukaReplacer.own_trait_form(hero, persona_id)
      return form.trait_name ? [form.trait_name, *form.trait_lines] : nil if form
      return [hero.trait_name, *hero.trait_lines] if hero.trait_name

      hero.trait_from && NWConst::Library::ACTOR_FIX_ABILITY[hero.trait_from]
    end

    # Reads a hero's Library picture in a form: from their pack, a game picture with the Library's
    # own placement when it has one, else their source actor's.
    #
    # @param hero [Hero] The hero.
    # @param persona_id [Integer] The form's actor id.
    # @return [Array, nil] The picture's entry, nil to keep Luka's.
    def self.picture(hero, persona_id)
      image = MGQ_LukaReplacer.image_of(hero, :picture, persona_id)
      return ["#{hero.dir}/", image[1], 0] if image && image[0] == :pack
      return placed(image[1]) || ["Graphics/Pictures/", image[1], 0] if image

      hero.source_id && NWConst::Library::ACTOR_IMAGE[hero.source_id]
    end

    # Finds the Library's own entry for a picture, with its placement.
    #
    # @param file [String] The picture's file.
    # @return [Array, nil] The entry, nil when no actor's uses that picture.
    def self.placed(file)
      NWConst::Library::ACTOR_IMAGE.values.find { |entry| entry.is_a?(Array) && entry[1] == file }
    end
  end

  # The heading over the list of heroes.
  class Window_Heading < Window_Base
    # The heading's text.
    TEXT = "Play as"

    # Creates the heading centred above a list.
    #
    # @param list [Window] The list below it.
    def initialize(list)
      super(list.x, list.y - fitting_height(1), list.width, fitting_height(1))
      draw_text(0, 0, contents_width, line_height, TEXT, 1)
    end
  end

  # The list of Luka and the heroes, shown on the title screen after New Game.
  class Window_Heroes < Window_Command
    # Width of the list.
    WIDTH = 240

    # Rows shown at most before the list scrolls.
    MAX_ROWS = 10

    # Creates the list in the middle of the screen.
    def initialize
      super(0, 0)
      self.x = (Graphics.width - width) / 2
      self.y = (Graphics.height - height) / 2
    end

    # @return [Integer] The list's width.
    def window_width
      WIDTH
    end

    # @return [Integer] The rows shown, at most MAX_ROWS.
    def visible_line_number
      [item_max, MAX_ROWS].min
    end

    # Lists Luka first, then every hero, each with its key.
    def make_command_list
      add_command(MGQ_LukaReplacer.luka_name, :hero, true, nil)
      MGQ_LukaReplacer.heroes.each { |hero| add_command(MGQ_LukaReplacer.name_of(hero), :hero, true, hero.key) }
    end
  end
end

# Game hooks.

if MGQ_LukaReplacer::ENABLED && MGQ_LukaReplacer.hookable?
  # The save keeps which hero its game plays.
  class Game_System
    # The key of the hero this game plays, nil for Luka.
    #
    # @return [String, nil] The key.
    attr_accessor :mgq_luka_replacer

    # What the hero already gained after story events, as "kind:id@event".
    #
    # @return [Array<String>, nil] The gains, nil before the first.
    attr_accessor :mgq_luka_gains
  end

  # New Game asks for the hero first. MGQ Online starts a new game in a world through the same
  # command, so worlds ask too.
  begin
    class Scene_Title
      alias mgq_luka_replacer_command_new_game command_new_game
      def command_new_game(*args)
        return mgq_luka_replacer_command_new_game(*args) if @mgq_luka_replacer_chosen || MGQ_LukaReplacer.heroes.empty?

        begin
          mgq_luka_replacer_open_heroes
        rescue => e
          MGQ_LukaReplacer.log("hero list FAILED: #{e.class}: #{e.message}")
          mgq_luka_replacer_close_heroes
          mgq_luka_replacer_command_new_game(*args)
        end
      end

      # Opens the list of heroes in place of the title commands, which close meanwhile, so it never
      # looks like the plain title screen. The title screen disposes its windows whenever it opens
      # another screen, like the options, and comes back as the same scene, so the list is made
      # again once disposed.
      def mgq_luka_replacer_open_heroes
        @command_window.close.deactivate if @command_window
        unless mgq_luka_replacer_heroes_alive?
          @mgq_luka_replacer_heroes = MGQ_LukaReplacer::Window_Heroes.new
          @mgq_luka_replacer_heroes.set_handler(:hero, method(:mgq_luka_replacer_on_hero))
          @mgq_luka_replacer_heroes.set_handler(:cancel, method(:mgq_luka_replacer_on_heroes_cancel))
          @mgq_luka_replacer_heading = MGQ_LukaReplacer::Window_Heading.new(@mgq_luka_replacer_heroes)
        end
        @mgq_luka_replacer_heroes.select(0)
        [@mgq_luka_replacer_heroes, @mgq_luka_replacer_heading].each(&:show)
        @mgq_luka_replacer_heroes.activate
      end

      # Starts the new game with the hero chosen.
      def mgq_luka_replacer_on_hero
        MGQ_LukaReplacer.pending = @mgq_luka_replacer_heroes.current_ext
        mgq_luka_replacer_close_heroes
        @mgq_luka_replacer_chosen = true
        command_new_game
      end

      # Goes back to the title commands.
      def mgq_luka_replacer_on_heroes_cancel
        mgq_luka_replacer_close_heroes
        @command_window.open.activate if @command_window
      end

      # Hides the list of heroes and its heading. The scene disposes them as it ends: it updates
      # every window it collected at the start of the frame, so one disposed by a handler during
      # that frame would crash the update.
      def mgq_luka_replacer_close_heroes
        return unless mgq_luka_replacer_heroes_alive?

        @mgq_luka_replacer_heroes.deactivate
        [@mgq_luka_replacer_heroes, @mgq_luka_replacer_heading].each(&:hide)
      end

      # Tells whether the list of heroes and its heading exist and are not disposed.
      #
      # @return [Boolean] Whether both can still be shown.
      def mgq_luka_replacer_heroes_alive?
        [@mgq_luka_replacer_heroes, @mgq_luka_replacer_heading].all? { |window| window && !window.disposed? }
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("title hook FAILED: #{e.class}: #{e.message}")
  end

  # A new game creates Luka from the hero's data and keeps the hero in the save; loading a save
  # plays the hero it keeps. MGQ Online's PvP battles put saves back through the same method.
  begin
    class << DataManager
      alias mgq_luka_replacer_setup_new_game setup_new_game
      def setup_new_game(*args)
        key = MGQ_LukaReplacer.pending
        MGQ_LukaReplacer.pending = nil
        MGQ_LukaReplacer.apply(key)
        result = mgq_luka_replacer_setup_new_game(*args)
        $game_system.mgq_luka_replacer = MGQ_LukaReplacer.current
        result
      end

      alias mgq_luka_replacer_extract_save_contents extract_save_contents
      def extract_save_contents(*args)
        result = mgq_luka_replacer_extract_save_contents(*args)
        MGQ_LukaReplacer.apply($game_system.mgq_luka_replacer)
        MGQ_LukaReplacer.fit_exp if MGQ_LukaReplacer.current
        result
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("save hooks FAILED: #{e.class}: #{e.message}")
  end

  # Images of hero packs, which live in the hero's cache folder instead of the game's Graphics.
  begin
    class << Cache
      alias mgq_luka_replacer_load_bitmap load_bitmap
      def load_bitmap(folder_name, filename, *args)
        folder_name, filename = MGQ_LukaReplacer.pack_image(filename) || [folder_name, filename]
        mgq_luka_replacer_load_bitmap(folder_name, filename, *args)
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("image hook FAILED: #{e.class}: #{e.message}")
  end

  # Luka's data, his graphics changed by the story, his base stats, and Luka of another player's
  # game.
  begin
    class Game_Actor
      alias mgq_luka_replacer_actor actor
      def actor
        @mgq_luka_key ? MGQ_LukaReplacer.data(@mgq_luka_key, @actor_id) : mgq_luka_replacer_actor
      end

      alias mgq_luka_replacer_set_graphic set_graphic
      def set_graphic(character_name, character_index, face_name, face_index)
        if MGQ_LukaReplacer::PERSONAS.include?(@actor_id)
          key = @mgq_luka_key || MGQ_LukaReplacer.current
          character_name, character_index = MGQ_LukaReplacer.sprite(character_name, character_index, key)
          face_name, face_index = MGQ_LukaReplacer.face(face_name, face_index, key)
        end
        mgq_luka_replacer_set_graphic(character_name, character_index, face_name, face_index)
      end

      if method_defined?(:base)
        alias mgq_luka_replacer_base base
        def base
          MGQ_LukaReplacer.base_stats(self) || mgq_luka_replacer_base
        end
      end

      if method_defined?(:skill_learnable?)
        alias mgq_luka_replacer_skill_learnable? skill_learnable?
        def skill_learnable?(skill)
          return true if skill.is_a?(RPG::Skill) && MGQ_LukaReplacer.monster_skills?(self)

          mgq_luka_replacer_skill_learnable?(skill)
        end
      end

      if method_defined?(:exp_curve)
        alias mgq_luka_replacer_exp_curve exp_curve
        def exp_curve
          MGQ_LukaReplacer.exp_curve(self) || mgq_luka_replacer_exp_curve
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("actor hooks FAILED: #{e.class}: #{e.message}")
  end

  # Gear reserved for the character a hero is based on, which the hero may equip too.
  begin
    if RPG::EquipItem.method_defined?(:exclusive_actors)
      class Game_Actor
        alias mgq_luka_replacer_equippable? equippable?
        def equippable?(item)
          MGQ_LukaReplacer.with_wearer(self) { mgq_luka_replacer_equippable?(item) }
        end
      end

      class RPG::EquipItem
        alias mgq_luka_replacer_exclusive_actors exclusive_actors
        def exclusive_actors
          MGQ_LukaReplacer.exclusive_actors(mgq_luka_replacer_exclusive_actors)
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("reserved gear hooks FAILED: #{e.class}: #{e.message}")
  end

  # A hero's battle lines: their source's, or Luka's, with the hero's cut-ins in place of the
  # character's.
  begin
    class Game_Actor
      alias mgq_luka_replacer_word_id word_id
      def word_id
        MGQ_LukaReplacer.lines_source(self) || mgq_luka_replacer_word_id
      end

      alias mgq_luka_replacer_skill_word_hash skill_word_hash
      def skill_word_hash
        MGQ_LukaReplacer.skill_word_hash(self, mgq_luka_replacer_skill_word_hash)
      end

      alias mgq_luka_replacer_down_word_hash down_word_hash
      def down_word_hash
        source_id = MGQ_LukaReplacer.lines_source(self)
        lines = source_id && NWConst::Actor::DOWN_WORDS[source_id]
        lines || mgq_luka_replacer_down_word_hash
      end

      alias mgq_luka_replacer_exist_cutin? exist_cutin?
      def exist_cutin?(skill_id)
        return mgq_luka_replacer_exist_cutin?(skill_id) unless MGQ_LukaReplacer.hero_of(self)

        MGQ_LukaReplacer.cutin?(self, skill_id)
      end

      alias mgq_luka_replacer_skill_word skill_word
      def skill_word(skill_id)
        MGQ_LukaReplacer.dress_word(self, mgq_luka_replacer_skill_word(skill_id), :skill)
      end

      MGQ_LukaReplacer::DOWN_SITUATIONS.each do |line, situation|
        original = "mgq_luka_replacer_#{line}"
        alias_method original, line
        define_method(line) do |*args|
          MGQ_LukaReplacer.dress_word(self, send(original, *args), situation)
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("battle line hooks FAILED: #{e.class}: #{e.message}")
  end

  # Luka's climax effect in battle, which a heroine leaves out, and a hero's cut-ins for skills
  # without lines, which the game only plays after a line.
  begin
    class Scene_Battle
      alias mgq_luka_replacer_process_down_word process_down_word
      def process_down_word(target, *args)
        @mgq_luka_replacer_target = target
        mgq_luka_replacer_process_down_word(target, *args)
      ensure
        @mgq_luka_replacer_target = nil
      end

      alias mgq_luka_replacer_process_luca_orgasm process_luca_orgasm
      def process_luca_orgasm(*args)
        luka = @mgq_luka_replacer_target || ($game_actors && $game_actors[MGQ_LukaReplacer::BASE_FORM])
        mgq_luka_replacer_process_luca_orgasm(*args) unless MGQ_LukaReplacer.heroine?(luka)
      end

      alias mgq_luka_replacer_process_skill_word process_skill_word
      def process_skill_word(item, action = nil, *args)
        result = mgq_luka_replacer_process_skill_word(item, action, *args)
        mgq_luka_replacer_cutin_alone(item, action)
        result
      end

      # Plays a hero's cut-in for a skill without lines, under the game's own cut-in options.
      #
      # @param item [RPG::UsableItem] The skill or item used.
      # @param action [Game_Action, nil] The action using it.
      def mgq_luka_replacer_cutin_alone(item, action)
        return unless item && item.is_skill? && MGQ_LukaReplacer.hero_of(@subject)
        return if skip_mode? || $game_system.conf[:bt_skip_cutin] || @subject.exist_skill_word?(item.id)
        return if action && action.symbol == :chain_action && $game_system.conf[:bt_skip_chain_action_cutin]
        return unless @subject.exist_cutin?(item.id)

        @subject.cutin(item.id).execute(method(:wait))
      rescue => e
        MGQ_LukaReplacer.log("could not play the hero's cut-in: #{e.class}: #{e.message}")
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("battle scene hooks FAILED: #{e.class}: #{e.message}")
  end

  # Texts drawn without the message system, like the save screen's "Luka Level:" and the
  # Library's records.
  begin
    class Bitmap
      alias mgq_luka_replacer_draw_text draw_text
      def draw_text(*args)
        MGQ_LukaReplacer.rename_drawn(args) if MGQ_LukaReplacer.current
        mgq_luka_replacer_draw_text(*args)
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("drawn text hook FAILED: #{e.class}: #{e.message}")
  end

  # What the story gives Luka: jobs and races through set_class_level, skills through the Change
  # Skills command. The hero's pack keeps, skips or replaces each.
  begin
    class Game_Interpreter
      alias mgq_luka_replacer_setup setup
      def setup(list, event_id = 0, *args)
        mgq_luka_replacer_setup(list, event_id, *args)
        @mgq_luka_event = MGQ_LukaReplacer.event_key(list, @map_id, event_id)
      end

      alias mgq_luka_replacer_run run
      def run(*args)
        mgq_luka_replacer_run(*args)
        MGQ_LukaReplacer.event_done(@mgq_luka_event)
      end

      alias mgq_luka_replacer_set_class_level set_class_level
      def set_class_level(actor_id, class_id, *args)
        given = MGQ_LukaReplacer.story_class(actor_id, class_id, @mgq_luka_event)
        mgq_luka_replacer_set_class_level(actor_id, given, *args) if given
      end

      if method_defined?(:persona_change)
        alias mgq_luka_replacer_persona_change persona_change
        def persona_change(persona_id, *args)
          given = MGQ_LukaReplacer.story_form(persona_id, @mgq_luka_event)
          mgq_luka_replacer_persona_change(given, *args) if given
        end
      end

      alias mgq_luka_replacer_command_318 command_318
      def command_318
        rule = MGQ_LukaReplacer.story_skill(@params, @mgq_luka_event)
        return mgq_luka_replacer_command_318 unless rule

        begin
          iterate_actor_var(@params[0], @params[1]) do |actor|
            if !MGQ_LukaReplacer::PERSONAS.include?(actor.id)
              actor.learn_skill(@params[3])
            elsif rule != :skip
              actor.learn_skill(rule)
            end
          end
        rescue => e
          MGQ_LukaReplacer.log("story rule for skill #{@params[3]} FAILED: #{e.class}: #{e.message}")
          mgq_luka_replacer_command_318
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("story hooks FAILED: #{e.class}: #{e.message}")
  end

  # Binding aims at Luka alone; a heroine counts as female, not as Luka.
  begin
    class RPG::Skill
      alias mgq_luka_replacer_ext_scope ext_scope
      def ext_scope
        MGQ_LukaReplacer.scope(mgq_luka_replacer_ext_scope)
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("binding hook FAILED: #{e.class}: #{e.message}")
  end

  # The hero's own actor as a companion, and parties the story sets.
  begin
    class Game_Party
      alias mgq_luka_replacer_add_actor add_actor
      def add_actor(actor_id, *args)
        mgq_luka_replacer_add_actor(actor_id, *args) unless MGQ_LukaReplacer.blocked?(actor_id)
      end

      alias mgq_luka_replacer_add_stand_actor add_stand_actor
      def add_stand_actor(actor_id, *args)
        mgq_luka_replacer_add_stand_actor(actor_id, *args) unless MGQ_LukaReplacer.blocked?(actor_id)
      end

      alias mgq_luka_replacer_set_temp_actors set_temp_actors
      def set_temp_actors(actor_ids, *args)
        mgq_luka_replacer_set_temp_actors(MGQ_LukaReplacer.stand_in(Array(actor_ids)), *args)
      end

      alias mgq_luka_replacer_add_temp_actors add_temp_actors
      def add_temp_actors(actor_ids, *args)
        mgq_luka_replacer_add_temp_actors(MGQ_LukaReplacer.stand_in(Array(actor_ids)), *args)
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("party hooks FAILED: #{e.class}: #{e.message}")
  end

  # Story scenes show Luka as events and change the player's sprite by move routes. Other
  # characters, like MGQ Online's other players, keep the sprite their game sent.
  begin
    [Game_Player, Game_Follower, Game_Event].each do |klass|
      klass.class_eval do
        alias_method :mgq_luka_replacer_character_name, :character_name
        alias_method :mgq_luka_replacer_character_index, :character_index

        define_method(:character_name) do
          MGQ_LukaReplacer.sprite(mgq_luka_replacer_character_name, mgq_luka_replacer_character_index)[0]
        end

        define_method(:character_index) do
          MGQ_LukaReplacer.sprite(mgq_luka_replacer_character_name, mgq_luka_replacer_character_index)[1]
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end

  # Every text shown goes through here, messages with their name box, choices and the battle log
  # included.
  begin
    class Window_Base
      alias mgq_luka_replacer_convert_escape_characters convert_escape_characters
      def convert_escape_characters(*args)
        MGQ_LukaReplacer.rename(mgq_luka_replacer_convert_escape_characters(*args))
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("text hook FAILED: #{e.class}: #{e.message}")
  end

  # Messages take their faces from the story's commands, not from Luka's data, so faces are swapped
  # where any window draws them: through draw_face_hue, which draw_face calls too.
  begin
    class Window_Base
      if method_defined?(:draw_face_hue)
        alias mgq_luka_replacer_draw_face_hue draw_face_hue
        def draw_face_hue(face_name, face_index, *args)
          face_name, face_index = MGQ_LukaReplacer.face(face_name, face_index)
          mgq_luka_replacer_draw_face_hue(face_name, face_index, *args)
        end
      else
        alias mgq_luka_replacer_draw_face draw_face
        def draw_face(face_name, face_index, *args)
          face_name, face_index = MGQ_LukaReplacer.face(face_name, face_index)
          mgq_luka_replacer_draw_face(face_name, face_index, *args)
        end
      end
    end
  rescue => e
    MGQ_LukaReplacer.log("message face hook FAILED: #{e.class}: #{e.message}")
  end
end
