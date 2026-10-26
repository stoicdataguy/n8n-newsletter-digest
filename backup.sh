#!/bin/sh
# Back up the Postgres database and export workflows + (encrypted) credentials.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
. ./.env

stamp=$(date +%Y%m%d-%H%M%S)
dest="backups/${stamp}"
mkdir -p "${dest}"

docker compose exec -T postgres pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${dest}/n8n-db.sql.gz"
docker compose exec -T n8n sh -c 'rm -rf /tmp/export && mkdir -p /tmp/export/workflows /tmp/export/credentials &&
  n8n export:workflow --all --separate --output=/tmp/export/workflows >/dev/null &&
  n8n export:credentials --all --separate --output=/tmp/export/credentials >/dev/null'
docker compose cp n8n:/tmp/export/. "${dest}/"

echo "✅ Backup written to ${dest} (credentials are encrypted with N8N_ENCRYPTION_KEY)"
