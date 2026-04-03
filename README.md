# matrix-server

Self-hosted Matrix chat server using tuwunel + Caddy on Docker Compose.

## Design

### Architecture decisions
- .well-known delegation (not SRV records)
- tuwunel (actively maintained Conduwit fork), not original Conduit
- SQLite backend, no Postgres
- Caddy for TLS + reverse proxy (auto Let's Encrypt)
- Docker Compose for reproducibility
- Digital Ocean droplet, nameservers on DO
- Firewall: DO cloud firewall + ufw, ports 22/80/443 open
- No Cloudflare, no IP masking for now
- Tailscale planned for SSH lockdown (not yet configured)

### Deployment
- Deploy from tagged GitHub release via GitHub Actions

## Config

Throughout this document:

**YOUR_DOMAIN** A valid domain name you own

## DNS records

Add these A records pointing to your VPS IP:

- `YOUR_DOMAIN` -> VPS IP
- `matrix.YOUR_DOMAIN` -> VPS IP

Add AAAA records if your VPS has IPv6.

## Setup

```bash
# Clone and configure
git clone git@github.com:corytodd/matrix.git /opt/matrix
echo "REGISTRATION_TOKEN=$(head -c 64 /dev/urandom | base64 -w 0)" > /opt/matrix/.envv
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
curl https://matrix.YOUR_DOMAIN/_matrix/client/versions
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

## Firewall

Run `server/firewall.sh` on a fresh server. It configures UFW and covers:

- 22/tcp SSH
- 80/tcp, 443/tcp HTTP/HTTPS
- 3478/tcp+udp, 5349/tcp+udp TURN/TURNS (coturn)
- 49152-65535/udp TURN relay + LiveKit WebRTC
- 7881/tcp LiveKit TURN TCP
- 172.16.0.0/12 -> 7880/tcp Docker bridge to LiveKit API (not exposed publicly)

Also configure matching rules in the DO cloud firewall except the Docker bridge rule, that's host-only.

## Key Rotation

All secrets live in `/opt/matrix/.env`. To rotate:

1. Update `COTURN_SECRET`, `LIVEKIT_KEY`, and/or `LIVEKIT_SECRET` in `.env`
2. `cd /opt/matrix && docker compose up -d`

No config files need to be touched.
