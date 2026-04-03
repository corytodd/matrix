#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:?Usage: $0 <domain>}"

cat > caddy/Caddyfile << EOF
# Generatate with ./scripts/gen-caddyfile.sh YOUR_DOMAINs
${DOMAIN} {
    header /.well-known/matrix/* Content-Type application/json
    header /.well-known/matrix/* Access-Control-Allow-Origin *

    respond /.well-known/matrix/server \`{"m.server":"matrix.${DOMAIN}:443"}\`
    respond /.well-known/matrix/client \`{
        "m.homeserver": {
            "base_url": "https://matrix.${DOMAIN}"
        },
        "org.matrix.msc4143.rtc_foci": [
            {
                "type": "livekit",
                "livekit_service_url": "https://livekit.${DOMAIN}"
            }
        ]
    }\`

    respond 404
}

matrix.${DOMAIN} {
    respond /_version \`{"sha":"{env.GIT_SHA}"}\`
    respond / 404
    reverse_proxy tuwunel:6167
}

livekit.${DOMAIN} {
    handle /sfu/* {
        reverse_proxy lk-jwt-service:8080
    }
    handle {
        reverse_proxy host.docker.internal:7880
    }
}
EOF

echo "Caddyfile written for domain: ${DOMAIN}"
