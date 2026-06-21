#!/usr/bin/env bash
set -euo pipefail

DIR="$(dirname "$0")"
ENV_FILE="$DIR/.env"

SSH_PORT="${SSH_PORT:-2222}"

cat > "$ENV_FILE" <<EOF
# SSH port exposed on the host
SSH_PORT=${SSH_PORT}

# Host user mapped into the container
HOST_USER=$(id -un)
HOST_UID=$(id -u)
HOST_GID=$(id -g)
EOF

echo "Written to $ENV_FILE"
cat "$ENV_FILE"

chmod 600 "$DIR/authorized_keys" 2>/dev/null && echo "Set authorized_keys permissions to 600" || true

if [ ! -f "$DIR/authorized_keys" ]; then
    PUB_KEY=$(ls ~/.ssh/id_*.pub 2>/dev/null | head -1)
    if [ -n "$PUB_KEY" ]; then
        cp "$PUB_KEY" "$DIR/authorized_keys"
        chmod 600 "$DIR/authorized_keys"
        echo "Copied $PUB_KEY -> authorized_keys"
    else
        echo "No public key found in ~/.ssh — add one manually to authorized_keys"
    fi
fi
