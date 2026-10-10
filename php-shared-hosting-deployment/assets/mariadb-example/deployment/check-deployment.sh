#!/usr/bin/env bash

set -euo pipefail

readonly deployment_url="${1:?Usage: deployment/check-deployment.sh HTTPS_URL}"
readonly release_id="${RELEASE_ID:?Expected release ID is required}"
[[ "$deployment_url" == https://example.com/ ||
   "$deployment_url" == https://staging.example.com/ ]] || {
    echo 'The smoke URL is not a configured deployment environment.' >&2
    exit 1
}
[[ "$release_id" =~ ^[A-Za-z0-9._-]+$ && "$release_id" != '.' && "$release_id" != '..' ]] || exit 1

temporary_directory="$(mktemp -d)"
readonly temporary_directory
trap 'rm -rf -- "$temporary_directory"' EXIT
readonly -a curl_options=(
    --connect-timeout 15
    --max-time 30
    --proto '=https'
    --show-error
    --silent
)

request() {
    curl "${curl_options[@]}" --dump-header "$temporary_directory/headers" \
        --output "$temporary_directory/body" --write-out '%{http_code}' \
        "${deployment_url}${1}"
}

# Poll boundedly while PHP workers/cache pick up the new release.
for attempt in {1..36}; do
    status="$(request health)"
    if [[ "$status" == 200 ]] && python3 - "$temporary_directory/body" "$release_id" <<'PY'
import json
import sys
with open(sys.argv[1]) as stream:
    actual = json.load(stream)
expected = {"status": "ok", "release": sys.argv[2], "php": "8.4"}
sys.exit(0 if actual == expected else 1)
PY
    then
        break
    fi
    if (( attempt == 36 )); then
        echo "Deployment health failed: expected release=$release_id status=$status" >&2
        exit 1
    fi
    sleep 5
done

status="$(request '')"
[[ "$status" == 200 ]] || { echo "Test page returned HTTP $status" >&2; exit 1; }
grep -q -F "${EXPECTED_SMOKE_TEXT:?Set the expected application page marker}" "$temporary_directory/body" || {
    echo 'The expected test-page HTML is missing.' >&2
    exit 1
}
grep -q -F '/app/assets/' "$temporary_directory/body" || {
    echo 'The compiled frontend assets are missing.' >&2
    exit 1
}

for path in current/ current/.env releases/ private/ .htaccess .pending-release; do
    status="$(request "$path")"
    [[ "$status" == 403 || "$status" == 404 ]] || {
        echo "Private deployment path exposed: $path" >&2
        exit 1
    }
done
if [[ "$deployment_url" == https://example.com/ ]]; then
    status="$(request staging/)"
    [[ "$status" == 403 || "$status" == 404 ]] || exit 1
fi

echo "Deployment HTTP checks passed: release=$release_id url=$deployment_url"
