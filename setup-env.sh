#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"

SSH_PORT="${SSH_PORT:-2222}"

cat > "$ENV_FILE" <<EOF
# SSH port exposed on the host
SSH_PORT=${SSH_PORT}

# Host user mapped into the container
HOST_USER=$(id -un)
HOST_UID=$(id -u)
HOST_GID=$(id -g)
HOST_HOME=${HOME}
EOF

echo "Written to $ENV_FILE"
cat "$ENV_FILE"
