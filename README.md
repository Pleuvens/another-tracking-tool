# AnotherTrackingTool

A self-hosted, French-first movie & TV tracker for a small household — invite-only,
with live watch syncing from Plex.

## Local development

* `mix setup` to install and set up dependencies
* `mix phx.server` (or `iex -S mix phx.server`) to start the server

Then visit [`localhost:4000`](http://localhost:4000). Set `TMDB_ACCESS_TOKEN` (a TMDB
v4 read token) for catalog search to work — locally you can put it in
`config/dev.secrets.exs`.

## Self-hosting with Docker

A published image is available at `ghcr.io/pleuvens/another-tracking-tool`. Copy the
provided `docker-compose.yml`, set the environment below, and run
`docker compose up -d`. It runs migrations on start; the first account created becomes
the admin.

Put a TLS-terminating reverse proxy in front and point `PHX_HOST` at your public host —
that hostname must be reachable for magic-link logins and for Plex to deliver webhooks.

| Variable | Required | Description |
| --- | --- | --- |
| `PHX_HOST` | yes | Public hostname, e.g. `track.example.com` |
| `SECRET_KEY_BASE` | yes | Generate with `mix phx.gen.secret` |
| `DB_PASSWORD` | yes | Postgres password (used by app and db) |
| `RESEND_API_KEY` | yes | Resend API key; magic-link/invite emails won't send without it |
| `MAILER_FROM_EMAIL` | yes | Sender address, verified with your mail provider |
| `MAILER_FROM_NAME` | no | Sender display name (default `AnotherTrackingTool`) |
| `TMDB_ACCESS_TOKEN` | yes | TMDB v4 read access token for the catalog |

### Plex sync

Admins get an `/integrations` page with a webhook URL to paste into Plex → Settings →
Account → Webhooks (requires Plex Pass). Watches then sync automatically; each Plex
account is mapped to an app user from that page.
