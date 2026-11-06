# Now Playing

Shows the name of the music in the top right corner for a few seconds whenever a new track starts. The names are the ones from the music room of Kagetsumugi's jukebox.

- Slides in, stays for 3 seconds, then fades out.
- After a map change it waits until the screen has faded in, so it slides in together with the map name of [Map Display](../Map_Display).
- Shows up everywhere: on maps, in menus, in battles and, without the Mod Framework, on the title screen.
- Tracks the music room doesn't list show nothing.

## Requirements

The [Mod Framework](https://mgqonline.org/mods/mod-framework) is optional. Without it, the name shows in the box described above. It comes on its own, not with the Collection or MGQ Online: install it as its page says.

## With the Mod Framework

With the [Mod Framework](https://mgqonline.org/mods/mod-framework), the name shows in a box in the look picked under **Interface Look** in Options > Mods, below other boxes in the top right corner, such as MGQ Online's, and slides out at the end. To move it, hold **Alt** while the name shows and drag it. **Default** under **Interface Positions** in Options > Mods puts it back in the top right corner. The place counts for every save.

## Install

1. Install the community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. If you already use other Patch folder mods, you have it.
2. [Download `Now_Playing.rb`](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Now_Playing.rb) and put it into the `Patch` folder.

To uninstall, delete `Patch\Now_Playing.rb`.

## Settings

Timing, colors and font size are constants at the top of `Now_Playing.rb`. Open it in any text editor to change them. With the Mod Framework, only `HOLD_FRAMES` and `ACCENT_COLOR` count; the look picked in Options > Mods sets the rest.

## Compatibility

Tested on 3.06 with the English translation.
