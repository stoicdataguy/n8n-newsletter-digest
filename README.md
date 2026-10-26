# n8n self-hosted demo: Gmail newsletter digest

A self-hosted [n8n](https://n8n.io) stack (n8n + Postgres, optional Caddy for HTTPS) that ships with one demo workflow:

**Every morning at 7:00 → fetch yesterday's newsletters from Gmail → summarise them with an LLM via OpenRouter → email you one digest.**

```
Schedule / Run now → Config → Gmail: get newsletters → Build prompt → OpenRouter → Format email → Gmail: send digest
```

## What's in here

| File | Purpose |
|---|---|
| `docker-compose.yml` | Postgres 17, n8n (pinned to `N8N_VERSION`), one-shot `n8n-init` importer, Caddy (`https` profile) |
| `.env.example` | All settings; `start.sh` copies it to `.env` and generates secrets |
| `workflows/newsletter-digest.json` | The demo workflow |
| `init/import-demo.sh` | Imports the workflow + credentials on **first boot only** (later restarts keep your UI edits) |
| `start.sh` / `stop.sh` | Start / stop the stack |
| `backup.sh` | `pg_dump` + export of workflows and encrypted credentials into `backups/` |
| `uninstall.sh` | Removes containers **and all data** (asks first) |
| `caddy/Caddyfile` | Reverse proxy with automatic Let's Encrypt HTTPS |

## Prerequisites

- Docker with Compose v2
- An [OpenRouter API key](https://openrouter.ai/keys)
- A Google Cloud OAuth client for Gmail (steps below)

### Create the Google OAuth client (one time, ~5 minutes)

1. In [Google Cloud Console](https://console.cloud.google.com/), create or pick a project.
2. **APIs & Services → Library**: enable the **Gmail API**.
3. **APIs & Services → OAuth consent screen**: choose *External*, fill in the app name and your email, and add yourself under **Test users**. You can leave the app in *Testing* mode for personal use.
4. **Credentials → Create credentials → OAuth client ID**: choose *Web application*.
   - Authorised redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`
     (on a server: `https://<your-domain>/rest/oauth2-credential/callback`)
5. Copy the **Client ID** and **Client secret**.

> In *Testing* mode Google expires refresh tokens after 7 days, so you'll need to click **Reconnect** on the credential weekly. Publish the consent screen to stop that.

## Quick start (local)

```bash
cd n8n-newsletter-digest
./start.sh            # first run creates .env, then pauses
```

When it pauses, open `.env` and fill in the following before pressing Enter:

```env
OPENROUTER_API_KEY=sk-or-...
GOOGLE_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
```

These are read **only on first boot** to pre-create two n8n credentials ("OpenRouter API key" and "Gmail account"). You can also skip them and create the credentials in the UI later.

Then:

1. Open http://localhost:5678 and create the owner account.
2. **Overview → Credentials → Gmail account → Sign in with Google**, and approve access.
3. Open the **Newsletter Digest** workflow and edit the **Config** node:

   | Field | Default | Notes |
   |---|---|---|
   | `digestRecipient` | `you@example.com` | **Change this** to your address |
   | `gmailQuery` | `newer_than:1d unsubscribe -from:me -in:chats` | Any Gmail search. Tighter alternatives: `label:newsletters newer_than:1d`, `from:(tldr.tech OR substack.com) newer_than:1d` |
   | `maxEmails` | `30` | |
   | `maxCharsPerEmail` | `12000` | Very long newsletters are trimmed to this length; the digest header says how many were trimmed |
   | `model` | `anthropic/claude-opus-5.5` | Any [OpenRouter model ID](https://openrouter.ai/models), e.g. `anthropic/claude-sonnet-5.5`, `google/gemini-3.8-flash` |

4. Click **Execute workflow** to run it now, then check your inbox.
5. Click **Publish** (activate) so the 7:00 schedule runs every day. The timezone is `GENERIC_TIMEZONE` in `.env`.

If nothing matches the Gmail query, the workflow stops after the Gmail step and no email is sent.

## Running on a server (HTTPS)

1. Point a DNS A record (e.g. `n8n.example.com`) at the server and open ports 80/443.
2. In `.env`, switch to the "Server with a domain" block:
   ```env
   N8N_HOST=n8n.example.com
   N8N_PROTOCOL=https
   N8N_PUBLIC_PORT_SUFFIX=
   N8N_SECURE_COOKIE=true
   ```
3. `docker compose --profile https up -d`

Caddy obtains the certificate automatically. n8n stays bound to `127.0.0.1`, so it is only reachable through Caddy. Remember to add the HTTPS redirect URI to your Google OAuth client.

## Day-2 operations

```bash
./backup.sh                                  # DB dump + workflow/credential export → backups/<timestamp>/
docker compose logs -f n8n                   # logs
# upgrade: bump N8N_VERSION in .env (read the n8n release notes first), then
./backup.sh && docker compose pull && docker compose up -d
```

**Back up `N8N_ENCRYPTION_KEY`.** Stored credentials can't be decrypted without it, including the ones in your backups.

To re-import the demo workflow from scratch, run `./uninstall.sh` and then `./start.sh`. This wipes all data.

## Notes

- Email contents are sent to OpenRouter and on to the model provider you choose, so check that provider's data policy before pointing this at sensitive mail.
- The prompt tells the model to treat newsletter text as content only and to ignore any instructions inside it.
- Telemetry (`N8N_DIAGNOSTICS_ENABLED`) is off, and execution history is pruned after 14 days.
