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


# ── Generate user SSH keypair on first run ────────────────────────────────────
SSH_DIR="$USER_HOME/.ssh"
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    sudo -u "$USERNAME" mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    sudo -u "$USERNAME" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -C "${USERNAME}@devbox"
fi

# ── Install Claude Code to user npm prefix (enables auto-updates without sudo) ─
if [ ! -f "$USER_HOME/.npm-global/bin/claude" ]; then
    sudo -u "$USERNAME" env HOME="$USER_HOME" NPM_CONFIG_PREFIX="$USER_HOME/.npm-global" \
        npm install -g @anthropic-ai/claude-code
fi

# ── Generate user SSH keypair on first run ────────────────────────────────────
SSH_DIR="$USER_HOME/.ssh"
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    sudo -u "$USERNAME" mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    sudo -u "$USERNAME" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -C "${USERNAME}@devbox"
fi

# ── Docker socket access ──────────────────────────────────────────────────────
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1 || true)
    if [ -z "$DOCKER_GROUP" ]; then
        groupadd -g "$DOCKER_GID" docker 2>/dev/null || true
        DOCKER_GROUP=docker
    fi
    usermod -aG "$DOCKER_GROUP" "$USERNAME"
fi

echo "[entrypoint] Starting sshd (user=$USERNAME uid=$USER_UID gid=$USER_GID)"
exec /usr/sbin/sshd -D -e
