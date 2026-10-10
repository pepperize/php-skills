#!/usr/bin/env bash
set -euo pipefail

# Project-owned preparation: adapt these existing Doctrine commands if needed.
readonly php_bin="${PHP_BIN:-php}"
: "${APPLICATION_ENV_FILE:?Private application configuration is required}"
# Provision once and reuse the database directory, including WAL/journal files.
: "${PRIVATE_PATH:?Private persistent root is required}"
install -d -m 700 "$PRIVATE_PATH/application"
test -w "$PRIVATE_PATH/application"
# The private .env sets APPLICATION_DATABASE_PATH to this directory's application.sqlite.

"$php_bin" vendor/bin/doctrine-migrations migrate --no-interaction
"$php_bin" vendor/bin/doctrine-migrations up-to-date --fail-on-unregistered --no-interaction
