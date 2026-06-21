#!/usr/bin/env bash
set -euo pipefail

USERNAME="${HOST_USER:-devuser}"
USER_UID="${HOST_UID:-1000}"
USER_GID="${HOST_GID:-1000}"
USER_HOME="/home/${USERNAME}"

# ── Evict any pre-existing user that owns the target UID ─────────────────────
# Ubuntu 24.04 ships an 'ubuntu' user at UID 1000; remove it before touching
# groups so the group removal that userdel triggers gets recreated cleanly.
EXISTING_BY_UID=$(getent passwd "$USER_UID" | cut -d: -f1 || true)
if [ -n "$EXISTING_BY_UID" ] && [ "$EXISTING_BY_UID" != "$USERNAME" ]; then
    userdel "$EXISTING_BY_UID" 2>/dev/null || true
fi

# ── Create group ──────────────────────────────────────────────────────────────
if ! getent group "$USER_GID" >/dev/null 2>&1; then
    groupadd -g "$USER_GID" "$USERNAME"
fi

# ── Create or update user ─────────────────────────────────────────────────────
if ! getent passwd "$USERNAME" >/dev/null 2>&1; then
    useradd -m -d "$USER_HOME" -u "$USER_UID" -g "$USER_GID" -s /bin/zsh "$USERNAME"
else
    # Align UID/shell in case the image user differs from requested
    usermod -u "$USER_UID" -g "$USER_GID" -d "$USER_HOME" -s /bin/zsh "$USERNAME" 2>/dev/null || true
fi
# Allow key-based SSH login: useradd locks accounts by default ('!' in shadow),
# which sshd rejects even for pubkey auth. '*' disables password login without locking.
usermod -p '*' "$USERNAME"

# ── Fix home directory ownership (bind mount starts as root:root) ─────────────
chown "$USER_UID:$USER_GID" "$USER_HOME"

# ── Dotfiles ──────────────────────────────────────────────────────────────────
DOTFILES_DIR="$USER_HOME/.dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    sudo -u "$USERNAME" git clone --depth 1 https://github.com/garulf/dotfiles "$DOTFILES_DIR"
fi
sudo -u "$USERNAME" "$DOTFILES_DIR/activate.sh"


# ── LazyVim ───────────────────────────────────────────────────────────────────
NVIM_CONFIG="$USER_HOME/.config/nvim-lazyvim"
if [ ! -d "$NVIM_CONFIG" ]; then
    echo "[entrypoint] Cloning LazyVim starter into $NVIM_CONFIG …"
    if git clone --depth 1 https://github.com/LazyVim/starter "$NVIM_CONFIG"; then
        chown -R "$USER_UID:$USER_GID" "$NVIM_CONFIG"
    else
        echo "[entrypoint] LazyVim clone failed — skipping."
    fi
fi

echo "[entrypoint] Starting sshd (user=$USERNAME uid=$USER_UID gid=$USER_GID)"
exec /usr/sbin/sshd -D -e
