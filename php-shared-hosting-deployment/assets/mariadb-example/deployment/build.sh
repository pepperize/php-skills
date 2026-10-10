#!/usr/bin/env bash
set -euo pipefail
# Project-owned runtime allowlist; adapt to the existing application's layout.
readonly output="${1:?Usage: deployment/build.sh OUTPUT_DIRECTORY}"
mkdir -p "$output"
mkdir -p "$output/backend/public/app"
cp bootstrap.php cli-config.php migrations.php composer.json composer.lock "$output/"
cp -R backend/src backend/migrations "$output/backend/"
cp -R backend/public/. "$output/backend/public/"
cp -R frontend/dist/. "$output/backend/public/app/"
mkdir -p "$output/deployment"
cp deployment/*.sh "$output/deployment/"
cp -R deployment/apache "$output/deployment/"
docker cp "$(docker compose ps -q app):/var/www/html/vendor" "$output/vendor"
