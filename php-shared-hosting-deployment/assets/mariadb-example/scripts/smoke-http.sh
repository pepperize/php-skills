#!/usr/bin/env bash
set -euo pipefail

base_url="${1:?Usage: scripts/smoke-http.sh BASE_URL}"
body="$(curl --fail --silent --show-error --max-time 10 "${base_url%/}/health")"

python3 -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1]).get("status") == "ok" else 1)' "$body"

echo "Health check passed: ${base_url%/}/health"
