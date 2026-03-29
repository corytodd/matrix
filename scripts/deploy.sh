#!/usr/bin/env bash
set -euo pipefail

set -a
source "$(dirname "$0")/../.env"
set +a

SHA=$(git rev-parse HEAD)

ssh "${USER}@${HOST}" "mkdir -p ${DEST}/caddy ${DEST}/tuwunel"
scp docker-compose.yml "${USER}@${HOST}:${DEST}/docker-compose.yml"
scp caddy/Caddyfile "${USER}@${HOST}:${DEST}/caddy/Caddyfile"
scp tuwunel/tuwunel.toml "${USER}@${HOST}:${DEST}/tuwunel/tuwunel.toml"
rsync -a --delete bots/ "${USER}@${HOST}:${DEST}/bots/"

ssh "${USER}@${HOST}" "cd ${DEST} && GIT_SHA=${SHA} docker compose up -d --pull always --remove-orphans --build"
