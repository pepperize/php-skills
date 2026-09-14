#!/usr/bin/env bash

set -euo pipefail

readonly deployment_url="${1:-}"

if [[ ! "$deployment_url" =~ ^https://[A-Za-z0-9.-]+(:([0-9]{1,5}))?(/[A-Za-z0-9._~/%+-]*)$ ]]; then
    printf '%s\n' 'Usage: deployment/smoke-test.sh https://example.com/health' >&2
    exit 2
fi

if [[ -n "${BASH_REMATCH[2]:-}" ]]; then
    readonly deployment_port="${BASH_REMATCH[2]}"
    if [[ ! "$deployment_port" =~ ^[1-9][0-9]{0,4}$ ]] ||
       (( 10#$deployment_port > 65535 )); then
        printf '%s\n' 'Deployment smoke URL has an invalid port.' >&2
        exit 2
    fi
fi

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/deployment-smoke.XXXXXX")"
readonly response_body="$temporary_directory/body"
readonly response_headers="$temporary_directory/headers"

cleanup() {
    rm -f -- "$response_body" "$response_headers"
    rmdir -- "$temporary_directory"
}

trap cleanup EXIT

status="$(
    curl \
        --connect-timeout 15 \
        --dump-header "$response_headers" \
        --max-time 45 \
        --output "$response_body" \
        --proto '=https' \
        --retry 3 \
        --retry-all-errors \
        --retry-delay 2 \
        --show-error \
        --silent \
        --tlsv1.2 \
        --write-out '%{http_code}' \
        "$deployment_url"
)"

if [[ "$status" != '200' ]]; then
    printf 'Deployment smoke test expected HTTP 200 and received %s.\n' "$status" >&2
    exit 1
fi

if [[ -n "${EXPECTED_SMOKE_TEXT:-}" ]] &&
   ! grep --fixed-strings --quiet -- "$EXPECTED_SMOKE_TEXT" "$response_body"; then
    printf '%s\n' 'Deployment smoke response is missing its expected marker.' >&2
    exit 1
fi

printf '%s\n' 'Deployment smoke test passed.'
