# Modular Quickshell Desktop Suite

A feature-packed, modular desktop shell and widgets suite built with [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) (Qt6 / QML) for Wayland.

---

## Features

- **App Launcher & Calculator (`AppMenu.qml`, `Calculator.js`, `AppSearch.js`)**
  - Instant fuzzy search across desktop applications (`.desktop` entries).
  - Built-in live math calculator with clipboard copy (`wl-copy`).
  - Automatically tracks recently launched applications.

- **Window & Workspace Switcher (`AppSwitcher.qml`, `WindowSwitcherService.qml`)**
  - Visual workspace overview with grouped windows.
  - Active window focus, window closing, and workspace navigation.
  - Built-in session controls (Lock, Logout, Reboot, Poweroff).

- **Dynamic Wallpaper Engine (`WallpaperSelector.qml`, `WallpaperService.qml`, `BackgroundLayer.qml`)**
  - Automatic directory scanner across `~/Pictures`, `~/Wallpapers`, and `~/.local/share/wallpapers`.
  - Visual grid wallpaper picker with thumbnail caching.
  - Configurable automated slideshow intervals and randomizer.

- **Native Polkit Agent (`PolkitDialog.qml`)**
  - Native Wayland authentication dialog for Polkit privilege elevation.

- **Clock & Interactive Calendar (`ClockCard.qml`, `Calendar.qml`)**
  - Large lock/idle clock display with configurable font size, color, and smooth animations.
  - Interactive monthly calendar with day/week navigation.

- **Idle & Power Management Settings (`IdleSettings.qml`, `apply-idle-settings.py`)**
  - Visual configuration panel for screen dim, display turn-off, and lock timeouts.

- **Screen Edge Hot Corners (`HotCorner*.qml`, `HotCornerService.qml`)**
  - Four screen corner trigger areas with cooldown protection and visual indicators.
  - Configurable actions (focus left/right, center focused window, app switcher).

- **Unified IPC & CLI Controller (`bin/qs-ctl`)**
  - Control any widget or service over IPC using a simple CLI helper.

---

## Dependencies

### Core Requirements
| Dependency | Description |
|------------|-------------|
| **`quickshell`** (0.3+) | Modern Qt6-based Wayland desktop shell engine |
| **`python3`** | Required for idle settings persistence script |

### Recommended Utilities & Fonts
| Package | Purpose |
|---------|---------|
| **`wl-clipboard`** (`wl-copy`) | Copies calculator results to clipboard |
| **`gtk3`** / **`libglib2.0-bin`** (`gtk-launch`) | Launches `.desktop` applications from App Menu |
| **Nerd Font** (e.g. `MesloLGS Nerd Font`) | Icons in launcher, wallpaper picker, and dialogs |
| **`cantarell-fonts`** | Clean typography for the clock card |

> **Note on Compositors**: This shell uses Wayland's standard `wlr-layer-shell` protocol. It can run on any Wayland compositor. Window switching and hot-corner navigation dynamically support Hyprland and Niri when present, but neither compositor is a mandatory dependency.

---

## Quick Installation

### Method 1: Automated Installer (Recommended)

Clone the repository anywhere and run the included installer:

```bash
git clone https://github.com/yourusername/quickshell-config.git
cd quickshell-config
./install.sh
```

The installer will:
1. Check dependencies and suggest package manager commands for your Linux distro.
2. Link or copy the configuration to `~/.config/quickshell`.
3. Set up default state files without overwriting existing data.
4. Symlink `qs-ctl` into `~/.local/bin/qs-ctl` for easy shortcut binding.
5. Optionally install a `quickshell.service` systemd user unit.

#### Non-Interactive / Dotfile Managers (Symlink mode)
```bash
./install.sh -y --symlink
```

---

### Method 2: Manual Installation

1. **Install Quickshell and dependencies:**
   - **Arch Linux / CachyOS / Manjaro**:
     ```bash
     sudo pacman -S quickshell wl-clipboard python gtk3 cantarell-fonts
     # If quickshell is not in official repos:
     # paru -S quickshell-git
     ```
   - **Fedora**:
     ```bash
     sudo dnf copr enable error/quickshell
     sudo dnf install quickshell wl-clipboard python3 gtk3 cantarell-fonts
     ```
   - **Ubuntu / Debian**:
     ```bash
     sudo apt update && sudo apt install wl-clipboard python3 libglib2.0-bin fonts-cantarell
     # Install quickshell from source: https://git.outfoxxed.me/outfoxxed/quickshell
     ```
   - **openSUSE**:
     ```bash
     sudo zypper install wl-clipboard python3 gtk3-tools cantarell-fonts
     ```
   - **Nix / NixOS**:
     ```bash
     nix-env -iA nixos.quickshell nixos.wl-clipboard nixos.python3
     ```

2. **Clone directly into your user configuration directory:**
   ```bash
   git clone https://github.com/yourusername/quickshell-config.git ~/.config/quickshell
   cd ~/.config/quickshell
   chmod +x apply-idle-settings.py bin/qs-ctl
   ```

3. **Initialize state files:**
   ```bash
   cp -n idle-settings.json.example idle-settings.json
   cp -n recent-apps.json.example recent-apps.json
   cp -n wallpaper-state.json.example wallpaper-state.json
   ```

---

## Running Quickshell

### Start / Stop / Restart

Using `qs-ctl`:
```bash
qs-ctl start      # Launch in background
qs-ctl status     # Check process status
qs-ctl restart    # Restart shell
qs-ctl stop       # Terminate shell
```

Or run directly:
```bash
quickshell
```

### Autostart with Systemd
If enabled during installation, run:
```bash
systemctl --user enable --now quickshell.service
```

---

## CLI & IPC Reference (`qs-ctl`)

The suite registers Quickshell IPC endpoints. You can use the `qs-ctl` wrapper or `qs ipc call <target> <method>`:

| Command | Action |
|---------|--------|
| `qs-ctl menu` | Toggle application menu / launcher |
| `qs-ctl switcher` | Toggle window and workspace switcher |
| `qs-ctl calendar` | Toggle calendar view |
| `qs-ctl clock` | Open lock/idle clock display |
| `qs-ctl wallpaper toggle` | Open wallpaper selector dialog |
| `qs-ctl wallpaper next` | Jump to next wallpaper in directory |
| `qs-ctl wallpaper prev` | Jump to previous wallpaper |
| `qs-ctl wallpaper random` | Pick a random wallpaper |
| `qs-ctl wallpaper set <file>` | Set specific wallpaper image |
| `qs-ctl hotcorner toggle` | Toggle screen edge hot corners on/off |

---

## Keybinding Examples

You can easily bind these commands to hotkeys in your compositor configuration:

### Hyprland (`hyprland.conf`)
```ini
# Shell & Menu Keybindings
bind = SUPER, Space, exec, qs-ctl menu
bind = SUPER, Tab, exec, qs-ctl switcher
bind = SUPER, C, exec, qs-ctl calendar
bind = SUPER, W, exec, qs-ctl wallpaper toggle
bind = SUPER SHIFT, W, exec, qs-ctl wallpaper next

# Autostart Quickshell
exec-once = quickshell
```

### Niri (`config.kdl`)
```kdl
binds {
    Mod+Space { spawn "qs-ctl" "menu"; }
    Mod+Tab   { spawn "qs-ctl" "switcher"; }
    Mod+C     { spawn "qs-ctl" "calendar"; }
    Mod+W     { spawn "qs-ctl" "wallpaper" "toggle"; }
}

spawn-at-startup "quickshell"
```

### Sway / Wayfire / River (`sway/config`)
```ini
bindsym Mod4+space exec qs-ctl menu
bindsym Mod4+Tab exec qs-ctl switcher
bindsym Mod4+c exec qs-ctl calendar
bindsym Mod4+w exec qs-ctl wallpaper toggle

exec quickshell
```

---

## File Structure

```text
~/.config/quickshell/
├── shell.qml                    # Main entry point & IPC handler definitions
├── AppMenu.qml                  # Application launcher overlay
├── AppSearch.js                 # Search scoring & indexing logic
├── AppSwitcher.qml              # Workspace and window switcher overlay
├── BackgroundLayer.qml          # Wayland wallpaper background surface
├── Calculator.js                # Live expression calculator parser
├── Calendar.qml                 # Calendar popup widget
├── ClockCard.qml                # Lock / idle clock display
├── HotCorner*.qml               # Corner hitboxes and visual indicators
├── HotCornerService.qml         # Hot corner event coordinator
├── IdleSettings.qml             # Timeout settings GUI
├── PolkitDialog.qml             # Polkit authentication agent
├── SystemActionButton.qml       # Reusable button component
├── WallpaperSelector.qml        # Wallpaper grid browser modal
├── WallpaperService.qml         # Wallpaper scanner & slideshow manager
├── WindowSwitcherService.qml    # Window manager bridge
├── apply-idle-settings.py       # Idle daemon config helper
├── install.sh                   # Distro installer & environment validator
├── quickshell.service           # Systemd user unit template
└── bin/
    └── qs-ctl                   # CLI & IPC control tool
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
