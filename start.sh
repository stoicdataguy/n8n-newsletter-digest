#!/bin/sh
# Start the self-hosted n8n stack. On first run, creates .env with generated secrets.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

if [ ! -f .env ]; then
  cp .env.example .env
  key=$(openssl rand -hex 32)
  pw=$(openssl rand -hex 16)
  sed -i.bak "s/^N8N_ENCRYPTION_KEY=CHANGE_ME/N8N_ENCRYPTION_KEY=${key}/; s/^POSTGRES_PASSWORD=CHANGE_ME/POSTGRES_PASSWORD=${pw}/" .env
  rm -f .env.bak
  echo "Created .env with generated secrets. Back up N8N_ENCRYPTION_KEY somewhere safe."
  echo "Optional: add OPENROUTER_API_KEY / GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET to .env"
  echo "now (before the first boot) to pre-create the demo credentials."
  echo "Press ENTER to continue, or Ctrl+C to edit .env first."
  # shellcheck disable=SC2034
  read -r line
fi

. ./.env
docker compose up -d --wait n8n
echo
echo "✅ n8n is running at ${N8N_PROTOCOL}://${N8N_HOST}${N8N_PUBLIC_PORT_SUFFIX}"
