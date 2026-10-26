#!/bin/sh
# Runs once (n8n-init service) before n8n starts. Imports the demo credentials
# and workflow on first boot, then leaves a marker so later restarts never
# overwrite edits you make in the UI.
set -eu

MARKER=/home/node/.n8n/.demo-imported
if [ -f "$MARKER" ]; then
  echo "Demo already imported; skipping."
  exit 0
fi

# Build credentials JSON with node so secrets are JSON-escaped correctly.
# Only credentials whose secrets are present in .env are created.
node -e '
const creds = [];
const env = process.env;
if (env.OPENROUTER_API_KEY) creds.push({
  id: "openRouterHeaderAuth", name: "OpenRouter API key", type: "httpHeaderAuth",
  data: { name: "Authorization", value: `Bearer ${env.OPENROUTER_API_KEY}` },
});
if (env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET) creds.push({
  id: "gmailOAuth2Demo", name: "Gmail account", type: "gmailOAuth2",
  data: { clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET },
});
require("fs").writeFileSync("/tmp/demo-credentials.json", JSON.stringify(creds));
console.log(`Prepared ${creds.length} credential(s).`);
'

if [ "$(cat /tmp/demo-credentials.json)" != "[]" ]; then
  n8n import:credentials --input=/tmp/demo-credentials.json
fi
rm -f /tmp/demo-credentials.json

n8n import:workflow --separate --input=/demo/workflows

touch "$MARKER"
echo "Demo import complete."
