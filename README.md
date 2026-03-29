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

### Federation (TODO)
- Currently disabled, plan to federate with another server later


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

## Bots

Bots live under `bots/{name}/` and are built as Docker Compose services on the `internal` network.

Each bot uses a prefixed set of env vars in `.env` to avoid collisions:

| Variable               | Description                           |
| ---------------------- | ------------------------------------- |
| `BOT_HOMESERVER`       | `https://matrix.YOUR_DOMAIN` (shared) |
| `{NAME}_USERNAME`      | `@botname:YOUR_DOMAIN`                |
| `{NAME}_PASSWORD`      | Bot account password                  |
| `{NAME}_ALLOWED_USERS` | Comma-separated Matrix user IDs       |

The service maps these to the generic `BOT_*` names the bot code expects. For example, `pingbot` uses `PINGBOT_USERNAME`, `PINGBOT_PASSWORD`, `PINGBOT_ALLOWED_USERS`.

Register a bot account from the admin room in your Matrix client (`#admins:YOUR_DOMAIN`):

```
!admin users create-user {NAME} {PASSWORD}
```

Run `!admin help` to see all available admin commands.

### Available bots

| Name    | Trigger | Response |
| ------- | ------- | -------- |
| pingbot | `!ping` | `pong`   |

### Adding a bot

1. Create `bots/{name}/` with a `Dockerfile` and your bot code
2. Add a service to `docker-compose.yml` pointing to `./bots/{name}`
3. Register the bot account (see above)
4. Add its env vars to `.env`

## Firewall

Open these ports:
- 22 (SSH)
- 80 (HTTP Let's Encrypt ACME)
- 443 (HTTPS Matrix + .well-known)
