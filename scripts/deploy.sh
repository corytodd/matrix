#!/usr/bin/env bash
set -euo pipefail

set -a
source "$(dirname "$0")/../.env"
set +a

SHA=$(git rev-parse HEAD)

scp docker-compose.yml "${USER}@${HOST}:${DEST}/docker-compose.yml"
scp caddy/Caddyfile "${USER}@${HOST}:${DEST}/caddy/Caddyfile"
scp conduit/conduit.toml "${USER}@${HOST}:${DEST}/conduit/conduit.toml"

ssh "${USER}@${HOST}" "cd ${DEST} && GIT_SHA=${SHA} docker compose up -d --pull always"
