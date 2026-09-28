# Battle Dialogue

Shows what is said in a battle in boxes that slide out at the sides of the screen, in the same style as [Map Display](../Map_Display), instead of the message window. The battle no longer stops until you press a key: animations and damage go on while the lines are shown.

- Lines of your party slide out at the left with a green bar, lines of the enemy side at the right with a red bar, each with the speaker's face and name. The box fades out towards the middle of the screen.
- A summon speaks on the side of whoever summoned it.
- Messages nobody says, such as "... appears!", show as a see-through strip at the top, below the skill name.
- Each box stays for 1.5 to 5 seconds, depending on how long the line is, then fades out. Up to three stack on each side, the newest on top.
- Messages with choices stay in the normal message window.
- Once a battle is won or lost, its messages stay in the normal message window too, so victory screens such as Victory_Screen.rb wait for you as before.

The [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence) mod uses it in live friend battles, so neither player waits for the other to press a key.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Battle_Dialogue.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Battle_Dialogue.rb) and put it into the `Patch` folder.

To uninstall, delete `Patch\Battle_Dialogue.rb`.

## Settings

Timing, sizes, positions and colors are constants at the top of `Battle_Dialogue.rb`. Open it in any text editor to change them. `ENABLED = false` turns the boxes off without uninstalling the mod.

## Compatibility

Tested on 3.06 with the English translation.

This mod wraps the following methods and calls the original from them:

- `Scene_Battle#wait_for_message`
- `Scene_Battle#process_skill_word`
- `Scene_Battle#process_down_word`
- `Scene_Battle#update_basic`
- `Scene_Battle#terminate`

Mods that replace these without calling the original may not work together with it.
