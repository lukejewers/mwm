# MWM (MacOS Window Manager)

A lightweight, native window manager (& app launcher) for macOS written in Swift, built to replace a hammerspoon script.

MWM is a compiled binary that interacts directly with the Carbon and Accessibility APIs for app launching and window manipulation.

## Installation

```console
$ make
$ make install
```

This will:

1. Compile the mwm binary.
2. Move the binary to /usr/local/bin/.
3. Load the com.user.mwm.plist as a LaunchAgent for persistence across reboots.

## Keybindings

All hotkeys use the Hyper Key combination: Control + Command.

### Application Launch & Focus

| Key | Target Application | Special Behavior          |
|-----|--------------------|---------------------------|
| J   | Emacs              | Respects layout mode      |
| K   | Firefox            | Respects layout mode      |
| L   | Ghostty            | Respects layout mode      |
| M   | Messages           | Toggle hide/show (popup)  |

### Window Management

| Key   | Action                                |
|-------|---------------------------------------|
| Left  | Snap focused window to the Left Half  |
| Right | Snap focused window to the Right Half |
| Up    | Maximize focused window               |
| Down  | Center focused window (70% size)      |

### Layout Modes

| Key | Mode       | Description                                                                       |
|-----|------------|-----------------------------------------------------------------------------------|
| F   | Fullscreen | Sets global state to Fullscreen; maximizes current window.                        |
| E   | Split Pane | Automatically tiles Emacs and Firefox 50/50. Press again to swap their positions. |

### Popup Apps

For apps designated as Popups (Messages): if the app is already focused, pressing its hotkey will hide it; if it's being focused, MWM automatically centers it.
