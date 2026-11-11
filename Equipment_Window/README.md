# Equipment Window

Replaces the game's equip screen with a window that shows a character's slots, the items for the picked slot and what an item would change, all on one screen.

- **Q** and **W** turn to the previous and next character.
- Pick a slot, then an item: the stats show what it changes before you equip it.
- *Optimize* equips the strongest items in every slot that can change, and *Clear* takes off everything in those slots.
- A search box finds items by name, and *Favorites* shows only the items you marked.
- **Right** on a slot slides in the item's details, with its *Info*, *Gems* and *Set* tabs. **Tab** steps the tabs, also while the cursor is on the slots; on a gamepad **L** and **R** do.
- To set or take out a gem: put the cursor on the item's slot, press **Right** to show the details, **Tab** to the *Gems* tab, then **Right** again onto its sockets. Pick a socket with **Up** and **Down** and press confirm to open the gem list. Pick a gem to set it, or *Remove gem* to take the socket's gem out; a gem taken out goes back to the bag. Cancel closes the list without a change. In the list, the number keys show only the gems of one color and **Tab** goes into the search. With the mouse, click a socket under the item's name.
- The hotkey help under the window names the keys of the part the cursor is on.
- Wears the look picked in the Mod Framework's Interface Look, and works with the mouse.

## Requirements

**Equipment Window requires the [Mod Framework](https://mgqonline.org/mods/mod-framework).** It comes on its own, not with the Collection or MGQ Online: install it as its page says. The framework's zip brings a first copy of the Equipment Window, so it is often installed already. It needs the Mod Framework 0.1.1 or newer; on an older one the menu's Equip keeps opening the game's screen.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. Install the [Mod Framework](https://mgqonline.org/mods/mod-framework) as its page says.
3. [Download `Equipment_Window.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Equipment_Window.rb) and put it into the `Patch` folder, unless the framework brought it.

To uninstall, delete `Patch\Equipment_Window.rb`, or turn it off in the Mod List.

## Settings

*[Equipment Window] Equip Command* in Options > Mods picks which screen the menu's Equip command opens: this window or the game's own.

## Compatibility

Tested on 3.06 with the English translation.

The window opens where the game's equip screen would; set the Equip Command to the game's screen for a mod that needs that screen.
