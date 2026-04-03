# matrix-server

Self-hosted Matrix chat server using tuwunel + Caddy on Docker Compose with LiveKit and TURN.

## Design

### Architecture decisions
- .well-known delegation (not SRV records)
- tuwunel (actively maintained Conduwit fork), not original Conduit
- SQLite backend, no Postgres
- Caddy for TLS + reverse proxy
- Docker Compose for reproducibility
- Firewall: DO cloud firewall + ufw, ports 22/80/443 open
- WebRTC and TURN relay via coturn
- LiveKit stack for Element calls

#### TODO
- Tailscale planned for SSH lockdown (not yet configured)


### Deployment
- Deploy from tagged GitHub release via GitHub Actions

## Config

Throughout this document:

**YOUR_DOMAIN** A valid domain name you own
***YOUR_VPS_IPU** Public IP of your server

## DNS records

Add these A records pointing to your VPS IP:

- `YOUR_DOMAIN` -> YOUR_VPS_IPU
- `livekit` -> YOUR_VPS_IPU
- `matrix` -> YOUR_VPS_IPU
- `turn` -> YOUR_VPS_IPU

Add AAAA records if your VPS has IPv6.

## Setup

```bash
# Clone and configure
export YOUR_DOMAIN=!!!SET_ME!!!
export YOUR_VPS_IP=!!!SET_ME!!!

sudo mkdir -p /opt/matrix && sudo chown $USER:$USER /opt/matrix
git clone git@github.com:corytodd/matrix.git /opt/matrix'

pushd /opt/matrix
./scripts/gen-caddyfile.sh $YOUR_DOMAIN

cat >> /opt/matrix/.env << EOF
# Copy to .env and fill in values
# NEVER commit .env to git
HOST=$YOUR_DOMAIN
USER=$USER
DEST=/opt/matrix
COTURN_SECRET=$(head -c 64 /dev/urandom | base64 -w 0)
COTURN_REALM=TURN.${YOURDOMAIN}
EXTERNAL_IP=${YOUR_VPS_IP}
TUWUNEL_SERVER_NAME="YOUR_DOMAIN"
TUWUNEL_TURN_URIS='["turn:turn.YOUR_DOMAIN:3478?transport=udp", "turn:turn.YOUR_DOMAIN:3478?transport=tcp"]'
LIVEKIT_URL=wss://livekit.$YOUR_DOMAIN
LIVEKIT_KEY=$(head -c 64 /dev/urandom | base64 -w 0)
LIVEKIT_SECRET=$(head -c 64 /dev/urandom | base64 -w 0)
EOF
chmod 600 /opt/matrix/.env
```

## Run

```bash
docker compose up -d
docker compose logs -f
```

## Verify

```bash
curl https://matrix.YOUR_DOMAIN/_version
curl https://YOUR_DOMAIN/.well-known/matrix/server
curl https://YOUR_DOMAIN/.well-known/matrix/client
curl https://livekit.YOUR_DOMAIN/_matrix/client/versions
curl https://matrix.YOUR_DOMAIN/_matrix/client/versions
nc -zvu turn.YOUR_DOMAIN 3478
```

Database is on a Docker volume

```bash
docker volume inspect matrix_tuwunel-data
```

## Voice/Video

Matrix supports two calling modes. Know which one you want before you start.

**1:1 calls** use WebRTC with TURN relay (coturn). The homeserver hands the client a
short-lived HMAC-SHA1 credential derived from a shared secret. The client uses that to
allocate a relay port on coturn. coturn forwards UDP between the two peers. The secret
never leaves the server tuwunel generates credentials on-the-fly via `TUWUNEL_TURN_SECRET`.

**Voice rooms** (group calls) use Element Call, which requires LiveKit. LiveKit is a
media server that handles SFU routing. It receives everyone's streams and forwards only
what each participant needs. A small JWT service (`lk-jwt-service`) sits in front: it
validates your Matrix access token, calls LiveKit's API to create the room, then hands
the client a signed JWT so it can connect directly to LiveKit over WebRTC.

The `.well-known/matrix/client` response tells Element where the JWT service lives
(`livekit_service_url`). Without it Element Call refuses to start. With a bad URL it
hangs at "Waiting for media...".

Both coturn and LiveKit run in host network mode to avoid Docker mapping thousands of
UDP ports (which exhausts iptables memory). Caddy reaches LiveKit's HTTP API via
`host.docker.internal` allowed through UFW only from Docker bridge subnets.

## Server

```
# Configure sysctl to allow for larger QUIC buffers:
sudo cp server/99-matrix.conf /etc/sysctl.d/
sudo sysctl --system

# Configure local firewall
sudo ./setver/firewall.sh

#!! Consider adding a firewall on your VPS in addition to this one!
```

## Key Rotation

All secrets live in `/opt/matrix/.env`. To rotate:

1. Update `COTURN_SECRET`, `LIVEKIT_KEY`, and/or `LIVEKIT_SECRET` in `.env`
2. `cd /opt/matrix && docker compose up -d`

No config files need to be touched.
