#!/usr/bin/env bash
# Wrapper that injects the host UID/GID before calling docker compose.
# Usage:  ./run.sh up -d
#         ./run.sh down
#         ./run.sh build
set -euo pipefail

if [ -n "${SUDO_USER:-}" ]; then
    HOST_USER="$SUDO_USER"
    HOST_UID=$(id -u "$SUDO_USER")
    HOST_GID=$(id -g "$SUDO_USER")
    HOST_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    HOST_USER=$(id -un)
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    HOST_HOME="$HOME"
fi
export HOST_USER HOST_UID HOST_GID HOST_HOME

exec docker compose "$@"
