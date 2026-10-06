# Luka Replacer

> **Experimental.** Luka Replacer has known bugs, and much of the story played with another hero is untested. Keep a copy of your saves, and please report what you find as an [issue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/issues).

Lets you start a new game with another hero in Luka's place. The story still treats your hero as Luka, but they carry their own name, looks, sex, base stats, starting jobs and races (several, each with a level), equipment and trait, and get their own share of what the story gives Luka.

- After **New Game**, a list asks who to play as: Luka or one of the heroes.
- Your hero's name replaces Luka's in messages, speaker names, choices and the battle log, and in the texts the game draws itself, like "Luka Level" on the save screen and the Library's records. Other characters named after him, like Luka Holly, Doppel Luka or Father of Chaos Luka, keep their names.
- Your hero's sprite and face replace Luka's on the map, in menus, in battle and in story messages, also in Luka's poses of single scenes, and their picture and artist show in the Library. Story pictures still show Luka.
- In battle your hero speaks the lines of the character they come from, under their own name and with their own face, or Luka's lines when that character has none. Luka's cut-ins are gone; your hero shows the cut-ins their pack sets, with pictures of the game or of the pack.
- A hero's face can be a sheet of expressions (up to four across and two down). Story messages and menus show the normal face; battle lines, lines at low HP, knock-outs, defeats by pleasure and being eaten can each show another expression, as the pack sets. A pack can also let the hero copy the expression of the character whose lines they speak.
- Your hero grows by Luka's base stats, another character's, or curves of their own.
- Your hero has their own trait instead of Luka's *Hero's Blood*, shown on the status screen. They keep only what recruiting needs from Luka: the Talk skill and the Talk skill type. A pack can also drop the extras of *Hero's Blood* every form of Luka carries (hit and evasion, target rate and two flags).
- A pack can give your hero their own categories, special categories, skill used under seduction and skill changes, and let them learn the skills the game keeps from Luka, like monster skills.
- A pack can give your hero their own EXP curve (`exp_curve=<job>`, Luka's is 386) and SP: max SP before levels (`sp_base=`), hundredths of a max SP point gained per level up to 99 and past it (`sp_level=`, `sp_level100=`) and the percent of max SP a battle starts with (`sp_start=`). Left out, Luka's stay. The EXP curve holds in Father of Chaos too, so the level never jumps when the form changes; a save started before the pack changed the curve keeps its level.
- Gear reserved for the character your hero is based on fits your hero too, besides Luka's own gear; in a Part 3 form also the gear of the character that form speaks as.
- Where the story gives Luka a job, race, skill, ability or a change of form (the Hero job at Mt. Saint Amos, the Lowly Angel race, the camp lessons, the spirits, the costume change and the changes back to his base form), each hero gets it, nothing, or something else, as their pack says, and a pack can leave out single story events or add gains at events of its choice. The end of the cross-dressing form and the end of the Chaos and White Rabbit form have rules of their own, so a hero can, for example, stay in one form while leaving the other.
- A heroine is female for the skills that only affect one sex; binding still works on her, and Luka's climax effect after a defeat by pleasure is left out. The story's words stay as they are.
- The save remembers the hero, so loading it plays them again.

- In Luka's Part 3 forms (cross-dressing, Chaos and White Rabbit) the hero can look different, speak another character's lines, show their own cut-ins and have a trait of their own; whatever a pack leaves out follows the hero's base form. Their stats grow from the hero's base stats as Luka's grow in that form. Each form keeps Luka's own power in it, which the story's fights need, except where the hero's trait sets the same.
- Father of Chaos, like World Breaker and Judgement, stays Luka as the game has him.
- Where the story shows Luka carrying the knight or the princess, the hero shows their own sprite, or the one their pack sets.

## Heroes

Luka Replacer comes with 8 heroes as **hero files**: one `<name>.luka` file per hero in `Patch\Luka_Replacer\Heroes`. A file holds the hero's whole pack, their images included. More heroes are added the same way.

The mod unpacks a hero's images into `Patch\Luka_Replacer\Cache` and unpacks them again only when the hero file changes. A file that is not a valid hero file is skipped and noted in `Luka Replacer.log`.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Luka_Replacer.zip`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Luka_Replacer.zip) and extract it into the `Patch` folder. You then have `Luka_Replacer.rb` in `Patch`, and the heroes in `Patch\Luka_Replacer\Heroes`.
3. For more heroes, put their `.luka` files into `Patch\Luka_Replacer\Heroes`.

To uninstall, delete `Patch\Luka_Replacer.rb` and the `Patch\Luka_Replacer` folder. A save started with another hero keeps their starting job and gear after that. To play as Luka again, start a new game.

## Multiplayer

With [Monster Girl Quest! Online](https://github.com/Pauliinchen/MGQ-Online), other players see your hero in battles and on the map. Players without this mod, or without your hero's pack, see Luka in battle.

## Compatibility

Tested on 3.06 with the English translation. Without it, the speaker names change but the rest of each message keeps ルカ, since many Japanese words contain those letters.

The mod replaces no game methods. It runs alongside these, leaving what they do unchanged:

- `Scene_Title#command_new_game`, to ask for the hero
- `DataManager.setup_new_game` and `DataManager.extract_save_contents`, to keep the hero in the save and fit a loaded game's EXP to the hero's curve
- `Cache.load_bitmap`, for images in hero packs
- `Game_Actor#actor`, `Game_Actor#set_graphic`, `Game_Actor#base`, `Game_Actor#skill_learnable?` and `Game_Actor#exp_curve`
- `Game_Actor#equippable?` and `RPG::EquipItem#exclusive_actors`, for gear reserved for the hero's character
- `Game_Actor#word_id`, `#skill_word_hash`, `#down_word_hash`, `#exist_cutin?`, `#skill_word`, `#dead_word`, `#orgasm_word`, `#predation_word` and `#incontinence_word`, for the hero's battle lines, cut-ins and expressions
- `Scene_Battle#process_skill_word`, `#process_down_word` and `#process_luca_orgasm`
- `Game_Interpreter#setup`, `#run`, `#set_class_level`, `#persona_change` and `#command_318`, for what the story gives Luka
- `Game_Party#add_actor`, `#add_stand_actor`, `#set_temp_actors` and `#add_temp_actors`
- `RPG::Skill#ext_scope`, so binding finds a heroine
- `Game_Player`, `Game_Follower` and `Game_Event`: `character_name` and `character_index`
- `Window_Base#convert_escape_characters` and `Bitmap#draw_text`
- `Window_Message#draw_face_hue`

## Credits

Cecil's images come from *Hyperdimension Girl Quest!* (D-Gate / The_HeroLuka).
