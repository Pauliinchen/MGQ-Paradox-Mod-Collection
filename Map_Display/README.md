# Map Display

Shows the name of the map in the top left corner for a few seconds after each map change, in the same style as [Now Playing](../Now_Playing) with the coloured bar on the right. It replaces the game's own centred map name.

- Slides in, stays for 3 seconds, then fades out.
- Maps without a name, and maps where the game turns the name display off, show nothing.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Map_Display.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Map_Display.rb) and put it into the `Patch` folder.

To uninstall, delete `Patch\Map_Display.rb`.

## Settings

Timing, colors and font size are constants at the top of `Map_Display.rb`. Open it in any text editor to change them.

## Compatibility

Tested on 3.06 with the English translation.

Please note that this mod replaces the following methods:

- `Window_MapName#initialize`
- `Window_MapName#update`
- `Window_MapName#open`
- `Window_MapName#close`

Any mod altering these will be incompatible.
