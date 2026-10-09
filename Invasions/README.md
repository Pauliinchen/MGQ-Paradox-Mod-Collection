# Invasions

Lets more monsters of the area join a random encounter or a boss fight while you fight it. After each turn there is a small chance that another group of the monsters you could meet where you stand joins the battle.

- The monsters that join are picked the way the game picks a random encounter for the spot you stand on, so they belong to the area and its regions. Only a boss fight on a map without random encounters draws from the dungeon around it instead, as described below.
- Each invasion first shows a warning in the middle of the screen: a flashing red **WARNING** between moving bands of caution tape, the screen pulsing red and the game's alarm sounding.
- Then the monsters fade in next to the ones already there, followed by the game's own **... appears!** message, and choose their actions in the very next turn.
- While any of them stands, you cannot flee: **Escape** and escape skills and items only tell you **You cannot flee as long as you are surrounded!**, and Escape costs no turn.
- A battle gets at most **2** invasions by default. The first can come after the first turn at the earliest.
- Random encounters you can flee from get invasions, and so do story boss fights, including optional ones. Other story and event battles, battle replays from the Library and battles during time stop never do, nor do maps and regions where encounters are off.
- A boss fight on a map with random encounters draws from that map's monsters, like a random encounter. A boss fight on a map without them draws from the dungeon around it, such as the castle, tower or ruins it takes place in, with any of that dungeon's monsters. A boss fight with neither gets no invasions, nor does one on a map without random encounters whose nearest monsters are those of the world map, or of the boss alone.
- At most **8** monsters stand in a battle at once; fallen ones free their place. When there is no room in the battle or on the screen, the monsters wait until fallen ones free some. Monsters whose picture fills the whole screen never join while another such monster, such as many a boss, stands.
- The new monsters count like any other for EXP, gold, drops, the monster library, recruiting and the chance to escape. Talk and temptation work for them as long as they are among the first six monsters of the battle, as the game covers no more. The fight against Lilith Origin gets no invasions, since it resets their talk every turn.

## Options

With [Mod Config Remake](../0_ModConfigRemake) or the Mod Config Menu, **Invasion Chance** under **Invasions** in the mod options sets the chance after each turn, from **Off** to **100%**, **Invasions per Battle** below it how many invasions a battle gets at most, from **1** to **5**, and **In Boss Battles** whether story boss fights, including optional ones, get invasions too. They are **5%**, **2** and **On** by default and are kept in each save.

## Settings

`ENABLED` is a constant at the top of `Invasions.rb`. Open it in any text editor to change it. `ENABLED = false` turns invasions off without uninstalling the mod.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Invasions.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Invasions.rb) and put it into the `Patch` folder.

To uninstall, delete `Patch\Invasions.rb`.

## Compatibility

Made for 3.06, with and without the English translation.

The mod replaces no game methods. It runs alongside these, leaving what they do unchanged, and hooks them once the first scene starts, so it also wraps the versions the newer translation's plugins define:

- `Scene_Battle#turn_end`, to roll for an invasion after each turn
- `Scene_Battle#start_party_command_selection`, to let the invaders join before the next command phase
- `Scene_Battle#update_basic`, to move the warning on and notice monsters that joined the battle
- `Scene_Battle#terminate`, to take the warning off the screen when the battle ends
- `Scene_Battle#command_escape` and `BattleManager.process_forced_escape`, to keep the party from fleeing while invaders stand
- `Game_Troop#clear`, so every battle starts without invasions

Mods that replace these without calling the original may not work together with it.
