# Luka Replacer

> **Experimental.** Luka Replacer has known bugs, and much of the story played with another hero is untested. Keep a copy of your saves, and please report what you find as an [issue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/issues).

Lets you start a new game with another hero in Luka's place. The story still treats your hero as Luka, but they bring their own name, looks, sex, base stats, starting jobs, races, equipment and trait.

## What changes

- After **New Game**, a list asks who to play as: Luka or one of the heroes. The save remembers the choice.
- Your hero's name replaces Luka's in messages, choices, the battle log, the save screen and the Library. Other characters named after Luka keep their names.
- Your hero's sprite, face and picture replace Luka's on the map, in menus, in battle and in story messages. Story pictures still show Luka.
- In battle your hero speaks the lines of the character they come from, with their own face and expressions, and shows their own cut-ins.
- Your hero grows by their own base stats and has their own trait instead of *Hero's Blood*. They keep Luka's Talk skill, which recruiting needs.
- Where the story gives Luka a job, race, skill or change of form, your hero gets it, nothing, or something else, as their hero file says.
- A heroine counts as female for skills that only affect one sex.
- In Luka's Part 3 forms your hero can look different and speak other lines; Father of Chaos, World Breaker and Judgement stay Luka.

## Heroes

Each hero is a `.luka` hero file in `Patch\Luka_Replacer\Heroes`, which holds everything about the hero, their images included. The heroes that come with the mod are in that folder after installing; more are added by putting their files there.

The mod unpacks a hero's images into `Patch\Luka_Replacer\Cache`. A file that is not a valid hero file is skipped and noted in `Logs\Luka Replacer.log` in the game folder.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Luka_Replacer.zip`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Luka_Replacer.zip) and extract it into the game folder, the one with `Game.exe`. Its `Patch` folder puts `Luka_Replacer.rb` into your `Patch` folder and the heroes into `Patch\Luka_Replacer\Heroes`.

To uninstall, delete `Patch\Luka_Replacer.rb` and the `Patch\Luka_Replacer` folder. A save started with another hero keeps their starting job and gear; to play as Luka again, start a new game.

## Multiplayer

With [Monster Girl Quest! Online](https://github.com/Pauliinchen/MGQ-Online), other players see your hero in battles and on the map. Players without this mod or without your hero's file see Luka.

## Compatibility

Made for 3.06 with the English translation. Without it, the speaker names change but the rest of each message keeps ルカ, since many Japanese words contain those letters.

The mod replaces no game methods. It runs alongside these, leaving what they do unchanged:

- `Scene_Title#command_new_game`, to ask for the hero
- `DataManager.setup_new_game` and `DataManager.extract_save_contents`, to keep the hero in the save
- `Cache.load_bitmap`, for the images in hero files
- `Game_Actor#actor`, `#set_graphic`, `#base`, `#skill_learnable?`, `#exp_curve` and `#equippable?`, and `RPG::EquipItem#exclusive_actors`
- `Game_Actor#setup` and `Game_Actors#[]`, so starting gear your hero cannot wear goes to the bag
- `Game_Actor#word_id`, `#skill_word_hash`, `#down_word_hash`, `#exist_cutin?`, `#skill_word`, `#dead_word`, `#orgasm_word`, `#predation_word` and `#incontinence_word`, for the hero's battle lines, cut-ins and expressions
- `Scene_Battle#process_skill_word`, `#process_down_word` and `#process_luca_orgasm`
- `Game_Interpreter#setup`, `#run`, `#set_class_level`, `#persona_change` and `#command_318`, for what the story gives Luka
- `Game_Party#add_actor`, `#add_stand_actor`, `#set_temp_actors` and `#add_temp_actors`
- `RPG::Skill#ext_scope`, so binding finds a heroine
- `Game_Player`, `Game_Follower` and `Game_Event`: `character_name` and `character_index`
- `Window_Base#convert_escape_characters` and `Bitmap#draw_text`
- `Window_Base#draw_face_hue` (`#draw_face` in versions without it), for faces in every window

## Credits

Cecil's images come from *Hyperdimension Girl Quest!* (D-Gate / The_HeroLuka).

Herzfeld's images come from RPG Maker (Archeia).
