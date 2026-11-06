# Map Display

Shows the name of the map in the top left corner for a few seconds after each map change, with a colored bar on its right. It replaces the game's own centered map name.

- Slides in, stays for 3 seconds, then slides out.
- Sits below other boxes in the top left corner, such as MGQ Online's Leader HUD.
- Maps without a name, and maps where the game turns the name display off, show nothing.
- Wears the look picked in the Mod Framework's Interface Look.

## Requirements

**Map Display requires the [Mod Framework](https://mgqonline.org/mods/mod-framework).** Without it, Map Display does nothing and the game shows its own map name. It comes on its own, not with the Collection or MGQ Online: install it as its page says.

## Moving the name

Hold **Alt** while the name shows and drag it to put it somewhere else. Pick **Default** under **Interface Positions** in Options > Mods to put it back in the top left corner. The place counts for every save.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. Install the [Mod Framework](https://mgqonline.org/mods/mod-framework) as its page says.
3. [Download `Map_Display.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Map_Display.rb) and put it into the `Patch` folder.

To uninstall, delete `Patch\Map_Display.rb`.

## Settings

How long the name stays is the constant `SECONDS` at the top of `Map_Display.rb`. Open it in any text editor to change it.

## Compatibility

Tested on 3.06 with the English translation.

Map Display draws in place of the game's map name window (`Window_MapName`) through the Mod Framework. The game still opens and closes that window, so mods that only call it keep working. Another mod that draws that window itself, or changes its `open` or `refresh`, is incompatible.
