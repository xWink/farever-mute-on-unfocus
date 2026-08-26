# Farever Mute When Unfocused

A small unofficial [HLX](https://github.com/hlx-framework/hlx-core) mod for **Farever** that mutes the game's own audio when the Farever window loses focus and restores the previous volume when you return to the game.

It only changes Farever's internal FMOD master VCA (`vca:/MASTER`). It does **not** change the Windows volume mixer or mute other applications.

## Installation

### 1. Install HLX Core

Install HLX Core into your Farever game directory. After HLX is installed, your Farever folder should contain an `hlx` directory with a `mods` subfolder.

A typical Steam install path is:

```text
C:\Program Files (x86)\Steam\steamapps\common\Farever\
```

### 2. Install this mod

Use the compiled `mute-unfocused.hl` from the v1.0.0 package.

Create this directory if it does not already exist:

```text
Farever\hlx\mods\mute-unfocused\
```

Place the file here:

```text
Farever\hlx\mods\mute-unfocused\mute-unfocused.hl
```

The final layout should look like:

```text
Farever\
└── hlx\
    └── mods\
        └── mute-unfocused\
            └── mute-unfocused.hl
```

Fully close and relaunch Farever. When you Alt-Tab away, Farever should become silent. Returning to the game restores the volume that was active before it lost focus.

## How it works

The mod hooks `GameApp.update` through HLX and watches `hxd.Window.isFocused`.

When focus changes:

- **Focused → unfocused:** read the current Farever master VCA volume and set `vca:/MASTER` to `0`.
- **Unfocused → focused:** restore the saved master VCA volume.

Because this is done through Farever's FMOD API, other Windows applications are unaffected.

## Building from source

The tested v1.0.0 binary was compiled against the Farever build current on **August 25, 2026**. Game updates can change the generated game API and may require recompiling.

Prerequisites:

- Haxe 4.3.x (v1.0.0 was built with Haxe 4.3.7)
- HLX runtime (`hlx-runtime`)
- A `farever-gamelib` generated from your current Farever `hlboot.dat`

Typical setup:

```text
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
hlx-gamelib-generator <path-to-Farever/hlboot.dat> <output-gamelib-dir>
haxelib dev farever-gamelib <output-gamelib-dir>
```

Then run from the repository root:

```text
haxe compile.hxml
```

The output is:

```text
build/mute-unfocused/mute-unfocused.hl
```

## Compatibility

This mod is tied to Farever's internal API. Small content updates may leave it working unchanged, while larger game/engine updates may break the hook or generated wrappers.

If Farever stops launching after an update, remove:

```text
Farever\hlx\mods\mute-unfocused\
```

and relaunch the game. Rebuild the mod against the new `hlboot.dat` before reinstalling it.

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Farever's developers, HLX, Steam, or Valve. Use third-party mods at your own risk, especially in online games.
