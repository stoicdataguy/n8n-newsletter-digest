#!/bin/sh
# Stop the stack (data is kept in Docker volumes).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
docker compose --profile https stop
