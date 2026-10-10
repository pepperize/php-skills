#!/usr/bin/env bash
set -euo pipefail

# Project-owned preparation: adapt these existing Doctrine commands if needed.
readonly php_bin="${PHP_BIN:-php}"
: "${APPLICATION_ENV_FILE:?Private application configuration is required}"

"$php_bin" vendor/bin/doctrine-migrations migrate --no-interaction
"$php_bin" vendor/bin/doctrine-migrations up-to-date --fail-on-unregistered --no-interaction
