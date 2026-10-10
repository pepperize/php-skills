#!/usr/bin/env bash
set -euo pipefail
# Project-owned runtime allowlist; adapt to the existing application's layout.
readonly output="${1:?Usage: deployment/build.sh OUTPUT_DIRECTORY}"
mkdir -p "$output"
cp -R bin bootstrap.php cli-config.php composer.json composer.lock migrations migrations.php public resources src vendor "$output/"
mkdir -p "$output/deployment"
cp deployment/*.sh "$output/deployment/"
cp -R deployment/apache "$output/deployment/"
