#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${1:-docker-compose.yml}"
TIMEOUT="${2:-15}"

mapfile -t images < <(docker compose -f "${COMPOSE_FILE}" config --format json 2>/dev/null \
    | jq -r '.services[].image // empty')

for image in "${images[@]}"; do
    ref="${image%%@sha256:*}"

    inspect=$(timeout "${TIMEOUT}" docker buildx imagetools inspect "${ref}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "image: ${image} ... TIMEOUT/ERROR"
        continue
    fi

    digest=$(echo "${inspect}" | awk '/^Digest:/{print $2; exit}')
    mediatype=$(echo "${inspect}" | awk '/^MediaType:/{print $2; exit}')
    base="${ref%%:*}"
    pinned="${base}@${digest}"

    case "${mediatype}" in
        *manifest.list* | *image.index*) type_note="index" ;;
        *) type_note="SINGLE-ARCH" ;;
    esac

    if [[ "${image}" == *"${digest}" ]]; then
        echo "image: ${image} ... OK (${type_note})"
    else
        echo "image: ${image} ... UPDATE (${type_note})"
        echo "    image: ${pinned}"
    fi
done