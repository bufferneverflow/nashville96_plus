#!/usr/bin/env bash
#
# Nashville96 Plus — custom XFCE setup installer
#
# Installs the required XFCE packages, then deploys the bundled
# Nashville96-Kanagawa GTK/xfwm4 theme, SE98 icon set, Perfect DOS VGA 437
# font (with BigBlue Terminal as pixel-styled fallback), wallpaper, and
# xfconf/panel/terminal configuration for the current user.
#
# Usage: ./install.sh
# Run as your normal user (it uses sudo only for package installation).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.local/share/nashville96-plus"
XFCE_CONF="$HOME/.config/xfce4"
CHANNEL_DIR="$XFCE_CONF/xfconf/xfce-perchannel-xml"
WALLPAPER="$DATA_DIR/wallpaper_4k_23242f_tomo.png"

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run this script as your normal user, not root (sudo is used only where needed)."

SUDO=""
if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    warn "sudo not found — package installation will be skipped unless you are root."
fi

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
install_yay() {
    command -v yay >/dev/null 2>&1 && return 0
    msg "Installing yay (AUR helper)..."
    if pacman -Si yay >/dev/null 2>&1; then
        # Available as a repo package (CachyOS, Manjaro, ...)
        $SUDO pacman -S --needed --noconfirm yay
    else
        # Vanilla Arch: bootstrap from the AUR
        $SUDO pacman -S --needed --noconfirm git base-devel
        local tmp
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
}

install_packages() {
    msg "Installing XFCE packages..."
    if command -v pacman >/dev/null 2>&1; then
        # Arch / CachyOS
        $SUDO pacman -S --needed --noconfirm \
            xfce4-session xfwm4 xfce4-panel xfce4-settings xfdesktop xfconf \
            libxfce4ui exo garcon thunar thunar-volman xfce4-terminal \
            xfce4-appfinder xfce4-whiskermenu-plugin xfce4-screenshooter \
            xfce4-notifyd ristretto xdg-user-dirs \
            xdg-desktop-portal xdg-desktop-portal-gtk dconf fish
        install_yay
    elif command -v apt-get >/dev/null 2>&1; then
        # Debian / Ubuntu
        $SUDO apt-get update
        $SUDO apt-get install -y \
            xfce4 xfce4-terminal xfce4-whiskermenu-plugin xfce4-screenshooter \
            xfce4-notifyd thunar ristretto xdg-user-dirs \
            xdg-desktop-portal xdg-desktop-portal-gtk dconf-gsettings-backend \
            libglib2.0-bin fish
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora
        $SUDO dnf install -y \
            xfce4-session xfwm4 xfce4-panel xfce4-settings xfdesktop \
            xfce4-terminal xfce4-appfinder xfce4-whiskermenu-plugin \
            xfce4-screenshooter xfce4-notifyd Thunar thunar-volman \
            ristretto xdg-user-dirs \
            xdg-desktop-portal xdg-desktop-portal-gtk dconf glib2 fish
    else
        warn "No supported package manager found (pacman/apt/dnf)."
        warn "Install XFCE + xfce4-whiskermenu-plugin + xfce4-screenshooter manually, then re-run."
        return 1
    fi
}
install_packages

# ---------------------------------------------------------------------------
# 2. Theme, icons, fonts, assets
# ---------------------------------------------------------------------------
msg "Installing Nashville96-Kanagawa theme to ~/.themes ..."
mkdir -p "$HOME/.themes"
cp -r "$REPO_DIR/themes/Nashville96-Kanagawa" "$HOME/.themes/"

msg "Installing SE98 icon theme to ~/.local/share/icons ..."
mkdir -p "$HOME/.local/share/icons"
cp -r "$REPO_DIR/icons/SE98" "$HOME/.local/share/icons/"

msg "Installing Perfect DOS VGA 437 + BigBlue Terminal fonts ..."
mkdir -p "$HOME/.local/share/fonts"
# Remove stale copies first: older revisions shipped the CP1252 display-hack
# variant of the VGA font, which draws wrong glyphs for NBSP/accents/dashes.
rm -rf "$HOME/.local/share/fonts/perfect-dos-vga-437" \
       "$HOME/.local/share/fonts/bigblue-terminal"
cp -r "$REPO_DIR/fonts/perfect-dos-vga-437" \
      "$REPO_DIR/fonts/bigblue-terminal" "$HOME/.local/share/fonts/"
fc-cache -f "$HOME/.local/share/fonts" >/dev/null

msg "Installing fontconfig fallback rules ..."
mkdir -p "$HOME/.config/fontconfig/conf.d"
cp "$REPO_DIR/config/fontconfig/conf.d/50-nashville96-font-fallback.conf" \
   "$HOME/.config/fontconfig/conf.d/"

msg "Installing wallpaper and panel assets to $DATA_DIR ..."
mkdir -p "$DATA_DIR"
cp "$REPO_DIR/wallpapers/wallpaper_4k_23242f_tomo.png" "$DATA_DIR/"
cp "$REPO_DIR/assets/whisker-menu-icon.png" "$DATA_DIR/"

# ---------------------------------------------------------------------------
# 3. XFCE configuration
# ---------------------------------------------------------------------------
if [[ -d "$XFCE_CONF" ]]; then
    BACKUP="$XFCE_CONF.bak.$(date +%Y%m%d-%H%M%S)"
    msg "Backing up existing config to $BACKUP ..."
    cp -a "$XFCE_CONF" "$BACKUP"
fi

# Stop the xfconf daemon so it doesn't overwrite the files we are about to
# install with its in-memory state. It respawns on demand and rereads them.
if pgrep -x xfconfd >/dev/null 2>&1; then
    pkill -x xfconfd || true
    sleep 1
fi

msg "Installing XFCE configuration files ..."
mkdir -p "$CHANNEL_DIR" "$XFCE_CONF/terminal"

install_conf() { # <repo-relative source> <absolute destination>
    sed "s|@HOME@|$HOME|g" "$REPO_DIR/$1" > "$2"
}

for xml in "$REPO_DIR"/config/xfce4/xfconf/xfce-perchannel-xml/*.xml; do
    install_conf "${xml#"$REPO_DIR/"}" "$CHANNEL_DIR/$(basename "$xml")"
done
install_conf config/xfce4/terminal/terminalrc "$XFCE_CONF/terminal/terminalrc"
install_conf config/xfce4/xfce4-screenshooter "$XFCE_CONF/xfce4-screenshooter"

# ---------------------------------------------------------------------------
# 3a. Fish functions
# ---------------------------------------------------------------------------
msg "Installing fish functions ..."
mkdir -p "$HOME/.config/fish/functions" "$HOME/.config/fish/completions"
cp "$REPO_DIR"/config/fish/functions/*.fish "$HOME/.config/fish/functions/"
cp "$REPO_DIR"/config/fish/completions/*.fish "$HOME/.config/fish/completions/"

# ---------------------------------------------------------------------------
# 3b. Global dark theme (GTK3/GTK4 + desktop portal)
#
# XFCE's own settings don't reach portal-aware apps like Firefox — they read
# the dark preference from xdg-desktop-portal, which reads it from gsettings.
# Cover every channel: settings.ini for plain GTK, gsettings for the portal.
# ---------------------------------------------------------------------------
msg "Installing GTK3/GTK4 settings (global dark theme) ..."
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cp "$REPO_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
cp "$REPO_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

apply_gsettings() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' && \
    gsettings set org.gnome.desktop.interface gtk-theme 'Nashville96-Kanagawa' && \
    gsettings set org.gnome.desktop.interface icon-theme 'SE98' && \
    gsettings set org.gnome.desktop.interface font-name 'Perfect DOS VGA 437 12'
}

if command -v gsettings >/dev/null 2>&1; then
    msg "Setting portal color-scheme to prefer-dark ..."
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        apply_gsettings || warn "gsettings failed — set color-scheme manually after login."
    elif command -v dbus-run-session >/dev/null 2>&1; then
        # No session bus (e.g. running from a TTY) — dconf still writes to
        # the same ~/.config/dconf/user database under a throwaway bus.
        dbus-run-session -- bash -c "$(declare -f apply_gsettings); apply_gsettings" \
            || warn "gsettings failed — set color-scheme manually after login."
    else
        warn "No D-Bus session — run 'gsettings set org.gnome.desktop.interface color-scheme prefer-dark' after login."
    fi
fi

# ---------------------------------------------------------------------------
# 4. Apply live if an XFCE session is running
# ---------------------------------------------------------------------------
if [[ -n "${DISPLAY:-}" ]] && pgrep -x xfce4-session >/dev/null 2>&1 \
   && command -v xfconf-query >/dev/null 2>&1; then
    msg "Running XFCE session detected — applying settings live ..."

    xfconf-query -c xsettings -p /Net/ThemeName -s "Nashville96-Kanagawa" || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "SE98" || true
    xfconf-query -c xfwm4 -p /general/theme -s "Nashville96-Kanagawa" || true

    # The desktop channel keys the wallpaper by monitor name, so set it on
    # every monitor this machine actually has.
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$' | \
    while read -r prop; do
        xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" || true
    done

    nohup xfsettingsd --replace >/dev/null 2>&1 &
    nohup xfwm4 --replace >/dev/null 2>&1 &
    xfce4-panel -r >/dev/null 2>&1 || true
    xfdesktop --reload >/dev/null 2>&1 || true

    msg "Done. Log out and back in if anything looks off."
else
    msg "No running XFCE session — settings will take effect at next login."
    warn "The wallpaper is stored per monitor name. If it doesn't appear,"
    warn "re-run this script from inside the XFCE session or set it with:"
    warn "  xfdesktop-settings   (pick $WALLPAPER)"
fi

msg "Nashville96 Plus installed."
