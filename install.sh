#!/usr/bin/env bash
#
# Quickshell Configuration Installer
# Installs and configures this modular Quickshell desktop shell suite on Linux.
#

set -euo pipefail

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_GRAY="\033[90m"

log_info()    { printf "%b[INFO]%b %s\n" "$C_CYAN" "$C_RESET" "$*"; }
log_ok()      { printf "%b[OK]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
log_warn()    { printf "%b[WARN]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
log_error()   { printf "%b[ERROR]%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; }
log_step()    { printf "\n%b==>%b %b%s%b\n" "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# Default flags
NON_INTERACTIVE=false
MODE="auto" # auto, symlink, copy, in-place
LINK_BIN=true
INSTALL_DEPS=false
INSTALL_SYSTEMD=false
CHECK_ONLY=false
UNINSTALL=false

usage() {
    cat << EOF
${C_BOLD}Quickshell Configuration Installer${C_RESET}

${C_BOLD}USAGE:${C_RESET}
    ./install.sh [OPTIONS]

${C_BOLD}OPTIONS:${C_RESET}
    -y, --yes, --non-interactive  Run without prompting (accept defaults)
    --symlink                     Symlink repository to ~/.config/quickshell
    --copy                        Copy repository files to ~/.config/quickshell
    --install-deps                Automatically install missing dependencies via package manager
    --no-bin                      Do not create ~/.local/bin/qs-ctl link
    --systemd                     Install and enable systemd user service (quickshell.service)
    --check                       Only check dependencies and environment without installing
    --uninstall                   Remove links and installed services created by this installer
    -h, --help                    Show this help message

${C_BOLD}EXAMPLES:${C_RESET}
    ./install.sh                  # Interactive installation
    ./install.sh -y --symlink     # Non-interactive symlink install
    ./install.sh --check          # Check dependencies
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --symlink)
            MODE="symlink"
            shift
            ;;
        --copy)
            MODE="copy"
            shift
            ;;
        --install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        --no-bin)
            LINK_BIN=false
            shift
            ;;
        --systemd)
            INSTALL_SYSTEMD=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

detect_distro() {
    DISTRO_ID="unknown"
    DISTRO_LIKE=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    fi
}

detect_package_manager() {
    detect_distro
    if command -v pacman >/dev/null 2>&1; then
        PKG_MNGR="pacman"
        if command -v paru >/dev/null 2>&1; then
            AUR_HELPER="paru"
        elif command -v yay >/dev/null 2>&1; then
            AUR_HELPER="yay"
        else
            AUR_HELPER=""
        fi
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MNGR="dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MNGR="apt"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MNGR="zypper"
    elif command -v nix-env >/dev/null 2>&1; then
        PKG_MNGR="nix"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MNGR="apk"
    elif command -v xbps-install >/dev/null 2>&1; then
        PKG_MNGR="xbps"
    else
        PKG_MNGR="unknown"
    fi
}

check_dependencies() {
    log_step "Checking System Dependencies"
    detect_package_manager

    local missing_required=()
    local missing_recommended=()

    # Required: quickshell
    if command -v quickshell >/dev/null 2>&1 || command -v qs >/dev/null 2>&1; then
        log_ok "Quickshell found: $(command -v quickshell 2>/dev/null || command -v qs)"
    else
        log_warn "Quickshell not found in PATH."
        missing_required+=("quickshell")
    fi

    # Required: python3
    if command -v python3 >/dev/null 2>&1; then
        log_ok "Python 3 found: $(python3 --version 2>&1)"
    else
        log_error "Python 3 not found."
        missing_required+=("python3")
    fi

    # Recommended: wl-copy (wl-clipboard)
    if command -v wl-copy >/dev/null 2>&1; then
        log_ok "wl-clipboard (wl-copy) found"
    else
        log_warn "wl-clipboard (wl-copy) not found (used by Calculator widget for clipboard copying)"
        missing_recommended+=("wl-clipboard")
    fi

    # Recommended: gtk-launch (glib2 / gtk3)
    if command -v gtk-launch >/dev/null 2>&1; then
        log_ok "gtk-launch found"
    else
        log_warn "gtk-launch not found (used by AppMenu to launch desktop applications)"
        missing_recommended+=("gtk3/libglib2.0-bin")
    fi

    # Font suggestions
    if command -v fc-list >/dev/null 2>&1; then
        if fc-list : family | grep -iq "nerd"; then
            log_ok "Nerd Font detected (used for icons in UI widgets)"
        else
            log_warn "No Nerd Font detected (recommended for status icons)"
        fi
        if fc-list : family | grep -iq "cantarell"; then
            log_ok "Cantarell font detected (used by Clock Card)"
        else
            log_info "Cantarell font not found (UI will fall back to system default font)"
        fi
    fi

    if [ ${#missing_required[@]} -gt 0 ]; then
        log_warn "Missing required packages: ${missing_required[*]}"
        show_install_commands "${missing_required[@]}" "${missing_recommended[@]}"
        if [ "$INSTALL_DEPS" = true ]; then
            try_install_dependencies "${missing_required[@]}" "${missing_recommended[@]}"
        elif [ "$CHECK_ONLY" = false ] && [ "$NON_INTERACTIVE" = false ]; then
            printf "\n%bWould you like to attempt installing missing dependencies now? [y/N]: %b" "$C_YELLOW" "$C_RESET"
            read -r resp
            if [[ "$resp" =~ ^[Yy]$ ]]; then
                try_install_dependencies "${missing_required[@]}" "${missing_recommended[@]}"
            fi
        fi
    elif [ ${#missing_recommended[@]} -gt 0 ]; then
        log_info "All required tools are installed! Optional packages: ${missing_recommended[*]}"
    else
        log_ok "All core dependencies satisfied!"
    fi
}

show_install_commands() {
    log_info "Package installation guide for your system ($DISTRO_ID / $PKG_MNGR):"
    case "$PKG_MNGR" in
        pacman)
            echo "    Arch / CachyOS / Manjaro:"
            if [ -n "${AUR_HELPER:-}" ]; then
                echo "      $AUR_HELPER -S quickshell wl-clipboard python gtk3 ttf-meslo-nerd-font-powerlevel10k cantarell-fonts"
            else
                echo "      sudo pacman -S quickshell wl-clipboard python gtk3 cantarell-fonts"
                echo "      (Or install quickshell-git from AUR)"
            fi
            ;;
        dnf)
            echo "    Fedora / RHEL:"
            echo "      sudo dnf install wl-clipboard python3 gtk3 cantarell-fonts"
            echo "      # For Quickshell, enable COPR or build from source:"
            echo "      sudo dnf copr enable error/quickshell && sudo dnf install quickshell"
            ;;
        apt)
            echo "    Debian / Ubuntu / Mint:"
            echo "      sudo apt update && sudo apt install -y wl-clipboard python3 libglib2.0-bin fonts-cantarell"
            echo "      # For Quickshell: compile from source (https://git.outfoxxed.me/outfoxxed/quickshell) or install via Nix/Cargo"
            ;;
        zypper)
            echo "    openSUSE:"
            echo "      sudo zypper install wl-clipboard python3 gtk3-tools cantarell-fonts"
            ;;
        nix)
            echo "    Nix / NixOS:"
            echo "      nix-env -iA nixos.quickshell nixos.wl-clipboard nixos.python3"
            ;;
        *)
            echo "    Install 'quickshell', 'python3', 'wl-clipboard', and 'gtk3' using your distribution package manager."
            ;;
    esac
}

try_install_dependencies() {
    log_step "Attempting Package Installation"
    case "$PKG_MNGR" in
        pacman)
            if [ -n "${AUR_HELPER:-}" ]; then
                log_info "Using $AUR_HELPER..."
                "$AUR_HELPER" -S --needed quickshell wl-clipboard python gtk3 cantarell-fonts || true
            else
                sudo pacman -S --needed wl-clipboard python gtk3 cantarell-fonts || true
                if ! command -v quickshell >/dev/null 2>&1; then
                    log_warn "Please install 'quickshell' (e.g. from AUR or source)."
                fi
            fi
            ;;
        dnf)
            sudo dnf install -y wl-clipboard python3 gtk3 cantarell-fonts || true
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y wl-clipboard python3 libglib2.0-bin fonts-cantarell || true
            ;;
        zypper)
            sudo zypper install -y wl-clipboard python3 gtk3-tools cantarell-fonts || true
            ;;
        *)
            log_warn "Automatic package installation is not supported for $PKG_MNGR. Please install dependencies manually."
            ;;
    esac
}

setup_target_directory() {
    log_step "Setting up configuration directory"

    local is_same_dir=false
    if [ -d "$TARGET_DIR" ] && [ "$(cd "$SOURCE_DIR" && pwd -P)" = "$(cd "$TARGET_DIR" && pwd -P)" ]; then
        is_same_dir=true
    fi

    if [ "$is_same_dir" = true ]; then
        log_ok "Repository is located directly at $TARGET_DIR (in-place install)."
        MODE="in-place"
    else
        log_info "Source repository: $SOURCE_DIR"
        log_info "Target directory:  $TARGET_DIR"

        if [ "$MODE" = "auto" ]; then
            if [ "$NON_INTERACTIVE" = true ]; then
                MODE="symlink"
            else
                printf "\nHow would you like to link the configuration to %s?\n" "$TARGET_DIR"
                echo "  1) Symlink (Recommended - git pulls update live)"
                echo "  2) Copy (Standalone copy, independent of source repo)"
                printf "Choice [1/2, default 1]: "
                read -r choice
                case "$choice" in
                    2) MODE="copy" ;;
                    *) MODE="symlink" ;;
                esac
            fi
        fi

        # Handle existing target
        if [ -L "$TARGET_DIR" ]; then
            log_info "Removing existing symlink at $TARGET_DIR"
            rm "$TARGET_DIR"
        elif [ -d "$TARGET_DIR" ]; then
            local backup_dir="${TARGET_DIR}.bak.$(date +%Y%m%d%H%M%S)"
            log_warn "Existing directory found at $TARGET_DIR"
            log_info "Creating backup at $backup_dir"
            mv "$TARGET_DIR" "$backup_dir"
        fi

        mkdir -p "$(dirname "$TARGET_DIR")"

        if [ "$MODE" = "symlink" ]; then
            log_info "Creating symlink: $TARGET_DIR -> $SOURCE_DIR"
            ln -s "$SOURCE_DIR" "$TARGET_DIR"
            log_ok "Symlink created."
        elif [ "$MODE" = "copy" ]; then
            log_info "Copying files to $TARGET_DIR"
            mkdir -p "$TARGET_DIR"
            cp -r "$SOURCE_DIR"/* "$TARGET_DIR"/
            log_ok "Files copied successfully."
        fi
    fi
}

initialize_state_files() {
    log_step "Initializing state and permissions"

    local target="$TARGET_DIR"
    if [ ! -d "$target" ]; then
        target="$SOURCE_DIR"
    fi

    # Make scripts executable
    if [ -f "$target/apply-idle-settings.py" ]; then
        chmod +x "$target/apply-idle-settings.py"
        log_ok "apply-idle-settings.py marked executable"
    fi
    if [ -f "$target/bin/qs-ctl" ]; then
        chmod +x "$target/bin/qs-ctl"
        log_ok "bin/qs-ctl marked executable"
    fi

    # Initialize default JSON state files if they don't exist
    for f in idle-settings.json recent-apps.json wallpaper-state.json; do
        if [ ! -f "$target/$f" ] && [ -f "$target/$f.example" ]; then
            cp "$target/$f.example" "$target/$f"
            log_ok "Created initial $f from template"
        else
            log_info "Preserving existing $f"
        fi
    done
}

install_binary_helper() {
    if [ "$LINK_BIN" = false ]; then
        return 0
    fi

    log_step "Setting up qs-ctl CLI helper"
    mkdir -p "$BIN_DIR"

    local src_ctl="$SOURCE_DIR/bin/qs-ctl"
    local dst_ctl="$BIN_DIR/qs-ctl"

    if [ -f "$src_ctl" ]; then
        ln -sf "$src_ctl" "$dst_ctl"
        chmod +x "$dst_ctl"
        log_ok "Installed qs-ctl to $dst_ctl"

        if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
            log_warn "$BIN_DIR is not currently in your PATH."
            log_info "Add this to your ~/.bashrc or ~/.zshrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
}

install_systemd_service() {
    log_step "Systemd User Service Setup"

    local svc_file="$SOURCE_DIR/quickshell.service"
    if [ ! -f "$svc_file" ]; then
        return 0
    fi

    if [ "$INSTALL_SYSTEMD" = false ] && [ "$NON_INTERACTIVE" = false ]; then
        printf "\nWould you like to install the systemd user service for Quickshell? [y/N]: "
        read -r resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then
            INSTALL_SYSTEMD=true
        fi
    fi

    if [ "$INSTALL_SYSTEMD" = true ]; then
        mkdir -p "$SYSTEMD_USER_DIR"
        cp "$svc_file" "$SYSTEMD_USER_DIR/quickshell.service"
        log_ok "Installed quickshell.service to $SYSTEMD_USER_DIR"
        systemctl --user daemon-reload || true
        log_info "To enable and start the service:"
        log_info "  systemctl --user enable --now quickshell.service"
    else
        log_info "Skipping systemd user service. (Can be installed anytime with ./install.sh --systemd)"
    fi
}

uninstall() {
    log_step "Uninstalling Quickshell Configuration"

    if [ -L "$TARGET_DIR" ]; then
        log_info "Removing symlink $TARGET_DIR"
        rm "$TARGET_DIR"
        log_ok "Removed configuration symlink."
    elif [ -d "$TARGET_DIR" ]; then
        log_warn "Target $TARGET_DIR is a full directory, not a symlink. Leaving directory intact."
    fi

    if [ -L "$BIN_DIR/qs-ctl" ]; then
        log_info "Removing $BIN_DIR/qs-ctl"
        rm "$BIN_DIR/qs-ctl"
        log_ok "Removed qs-ctl binary link."
    fi

    if [ -f "$SYSTEMD_USER_DIR/quickshell.service" ]; then
        log_info "Disabling and removing quickshell.service"
        systemctl --user stop quickshell.service 2>/dev/null || true
        systemctl --user disable quickshell.service 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/quickshell.service"
        systemctl --user daemon-reload 2>/dev/null || true
        log_ok "Removed systemd service."
    fi

    log_ok "Uninstall completed."
    exit 0
}

# Main flow
if [ "$UNINSTALL" = true ]; then
    uninstall
fi

check_dependencies

if [ "$CHECK_ONLY" = true ]; then
    log_ok "Check complete."
    exit 0
fi

setup_target_directory
initialize_state_files
install_binary_helper
install_systemd_service

log_step "Installation Summary"
printf "%bQuickshell setup is ready!%b\n\n" "$C_GREEN$C_BOLD" "$C_RESET"
echo "Quick Start:"
echo "  1. Start Quickshell manually:"
echo "       qs-ctl start     (or 'quickshell')"
echo ""
echo "  2. Test IPC controls:"
echo "       qs-ctl menu             # Toggle application menu"
echo "       qs-ctl switcher         # Toggle window switcher"
echo "       qs-ctl calendar         # Toggle calendar card"
echo "       qs-ctl wallpaper next   # Switch to next wallpaper"
echo ""
echo "  3. Wayland Compositor Autostart:"
echo "       Add 'quickshell' (or 'qs-ctl start') to your compositor's autostart configuration."
echo ""
echo "For more details and keybinding examples, see README.md."
