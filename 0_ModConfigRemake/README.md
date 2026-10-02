# Mod Config Remake

A menu for the options of your other mods, which replaces the Mod Config Menu. Mods made for the Mod Config Menu work with it as they are.

- It lists your mods at the left, such as **Discord** or **EXP Overlord**, and shows the options of the one you point at at the right. Confirm moves into its options, Cancel goes back to the list, and Cancel in the list closes the menu.
- Options that belong to no mod in particular are listed under **Global**, which only shows when there are any.
- With newer versions of the English translation, whose options screen has tabs, the menu is the **Mods** tab. The original Mod Config Menu no longer opens there.
- With older versions, the **Mod Config Menu** entry in the options opens it.
- Left and right change an option, Confirm moves it to its next value or presses a button.
- A key binding shows its key. Confirm it, then press the new key; Esc keeps the old one. Keys the game uses itself (Enter, Space, Esc, the arrows, Z, X, Shift, Ctrl, A, S, D, Q, W, Page Up, Page Down, F1, F2, F5 to F9 and F12) and keys another option has already are refused.
- Options and buttons a mod greys out cannot be used until it allows them again.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `0_ModConfigRemake.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/0_ModConfigRemake.rb) and put it into the `Patch` folder.

It takes the place of the Mod Config Menu, so `Patch\0_ModConfigMenu.rb` can stay or go. Your mods keep their settings, since both menus store them the same way.

To uninstall, delete `Patch\0_ModConfigRemake.rb`.

## For mod authors

Add your options the way the Mod Config Menu expects them: insert an entry before the last one of `NWConst::Config::MOD_CONTENTS` (or `NWConst::Config.mod_target`), and fill `DATA`, `DATA_TEXT` and `DEFAULT` for its key. An entry understands:

| Key | Meaning |
|---|---|
| `:key` | The option's key in `$game_system.conf`, `:mod_` first. |
| `:name` | Its name in the menu, a text or a proc. Start the first option of your mod with `[Mod Name] `, which names your mod in the list and is left out of the names shown. Indent the options that follow it, `"     Option"` or `"     -> Option"`, so they stay under your mod. An option with neither goes to **Global**. |
| `:help` | Its help, a text or a proc. The value's help from `DATA_TEXT` follows it. |
| `:sub` | `true` for an option with values, `false` for a button, which calls the handler of its key on the menu's window, `Window_ModConfig`. |
| `:values` | Its values, an array or a proc, in place of `DATA`. |
| `:enable` | A proc; while it returns false, the option is greyed out and cannot be changed. |
| `:on_change` | A proc called with the new value after each change. |
| `:keybind` | `true` for a key binding: its value is a key's Windows code, such as `0x54` for T, which the menu shows by its name and replaces with the next key the player presses. It needs no `DATA`. Leave `:sub` out. |
| `:value` | For a key binding only: a proc that reads its key, in place of `$game_system.conf`, which the game keeps in each save. With it, the menu stores nothing itself: keep the key from `:on_change`, such as in a file of your mod, so it holds in every save. |

Key bindings came with 1.3.0. Older versions of this menu and the Mod Config Menu show them as buttons that do nothing, so add one only while `ModConfigRemake::Keys` is defined, and keep your default key otherwise. `ModConfigRemake::Keys.name(code)` names a key as the menu does.

`Scene_Config#refresh_mod_config` draws the options again, as in the Mod Config Menu; call it when one of your options changes how others show.

The menu's window shows one mod's options at a time, so in `Window_ModConfig` an index counts that mod's rows, not the entries of `MOD_CONTENTS`: use `entry(index)` or `key(index)` to find a row's entry. An error in your `:on_change` proc or a button's handler leaves the menu running.

## Compatibility

Tested on 3.06 with the English translation, with and without its tabbed options screen.

This mod wraps the following methods and calls the original from them:

- `Scene_Config#start` (without `0_ModConfigMenu.rb`)
- `Scene_Config#create_config_window` (options screen without tabs, without `0_ModConfigMenu.rb`)
- `Scene_Config#on_config_tab_ok` (tabbed options screen)
- `SceneManager.run`

Mods that replace these without calling the original may not work together with it.

It defines the following anew, replacing those of `0_ModConfigMenu.rb` when that is installed:

- `Window_ModConfig`, the whole class
- `Scene_Config#create_mod_config_window`
- `Scene_Config#start_mod_config`
- `Scene_Config#refresh_mod_config`
- `Scene_Config#end_mod_config`

Mods that hook these methods of `0_ModConfigMenu.rb` or keep its window class get this mod's instead.
