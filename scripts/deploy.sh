#!/usr/bin/env bash
set -euo pipefail

set -a
source "$(dirname "$0")/../.env"
set +a

SHA=$(git rev-parse HEAD)

ssh "${USER}@${HOST}" "mkdir -p ${DEST}/caddy ${DEST}/tuwunel ${DEST}/coturn ${DEST}/livekit"
scp docker-compose.yml "${USER}@${HOST}:${DEST}/docker-compose.yml"
scp caddy/Caddyfile "${USER}@${HOST}:${DEST}/caddy/Caddyfile" 2>/dev/null || true
scp tuwunel/tuwunel.toml "${USER}@${HOST}:${DEST}/tuwunel/tuwunel.toml"
scp coturn/turnserver.conf "${USER}@${HOST}:${DEST}/coturn/turnserver.conf"
scp livekit/livekit.yaml "${USER}@${HOST}:${DEST}/livekit/livekit.yaml"

ssh "${USER}@${HOST}" "cd ${DEST} && GIT_SHA=${SHA} docker compose up -d --pull always --remove-orphans"
