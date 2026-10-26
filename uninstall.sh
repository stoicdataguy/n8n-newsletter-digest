#!/bin/sh
# Remove containers AND all data volumes (workflows, credentials, executions).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
echo "This deletes all n8n data (workflows, credentials, execution history)."
printf "Type 'delete' to confirm: "
read -r answer
[ "$answer" = "delete" ] || { echo "Aborted."; exit 1; }
docker compose --profile https down -v
echo "Removed. .env and backups/ were left in place."
