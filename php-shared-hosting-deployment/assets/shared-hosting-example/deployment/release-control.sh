#!/usr/bin/env bash

set -euo pipefail

readonly operation="${1:-}"

if [[ "$operation" != 'approve' && "$operation" != 'rollback' ]]; then
    printf '%s\n' 'Usage: deployment/release-control.sh approve|rollback' >&2
    exit 2
fi

readonly -a required_variables=(
    DEPLOY_PATH
    PRIVATE_PATH
    RELEASE_ID
    SSH_HOST
    SSH_HOST_KEY
    SSH_PORT
    SSH_PRIVATE_KEY
    SSH_USERNAME
)

fail() {
    printf 'Release control refused: %s\n' "$1" >&2
    exit 1
}

for variable_name in "${required_variables[@]}"; do
    [[ -n "${!variable_name:-}" ]] || fail "missing setting: $variable_name"
done

validate_relative_path() {
    local path=$1

    if [[ -z "$path" ||
          "$path" == '.' ||
          "$path" == /* ||
          "$path" == *..* ||
          "$path" == *//* ||
          ! "$path" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        fail "unsafe remote path: $path"
    fi
}

validate_relative_path "$DEPLOY_PATH"
validate_relative_path "$PRIVATE_PATH"
[[ "$DEPLOY_PATH" != "$PRIVATE_PATH" ]] || fail 'public and private paths must differ'
[[ "$PRIVATE_PATH" != "$DEPLOY_PATH"/* ]] || fail 'private path must be outside the deployment root'
[[ "$DEPLOY_PATH" != "$PRIVATE_PATH"/* ]] || fail 'deployment root must be outside the private path'

[[ "$RELEASE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'invalid release ID'
(( ${#RELEASE_ID} <= 160 )) || fail 'release ID is too long'
[[ "$SSH_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || fail 'invalid SSH host'
[[ "$SSH_PORT" =~ ^[1-9][0-9]{0,4}$ ]] || fail 'invalid SSH port'
(( 10#$SSH_PORT <= 65535 )) || fail 'SSH port is outside the valid range'
[[ "$SSH_USERNAME" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid SSH username'

if [[ "$SSH_HOST_KEY" == *$'\r'* || "$SSH_HOST_KEY" == *$'\n'* ]]; then
    fail 'the pinned host key must contain exactly one entry'
fi

if [[ "$SSH_HOST_KEY" != "$SSH_HOST "* &&
      "$SSH_HOST_KEY" != "[$SSH_HOST]:$SSH_PORT "* ]]; then
    fail 'the pinned host key does not identify the configured SSH host'
fi

readonly ssh_directory="$(mktemp -d "${RUNNER_TEMP:-/tmp}/shared-host-control.XXXXXX")"
readonly private_key_file="$ssh_directory/id"
readonly known_hosts_file="$ssh_directory/known_hosts"

cleanup() {
    rm -f -- "$private_key_file" "$known_hosts_file"
    rmdir -- "$ssh_directory"
}

trap cleanup EXIT
umask 077
printf '%s\n' "$SSH_PRIVATE_KEY" > "$private_key_file"
printf '%s\n' "$SSH_HOST_KEY" > "$known_hosts_file"

readonly -a ssh_options=(
    -i "$private_key_file"
    -o BatchMode=yes
    -o ConnectionAttempts=3
    -o ConnectTimeout=15
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=$known_hosts_file"
    -p "$SSH_PORT"
)

printf -v remote_command \
    'bash -s -- %q %q %q %q' \
    "$operation" \
    "$DEPLOY_PATH" \
    "$PRIVATE_PATH" \
    "$RELEASE_ID"

ssh "${ssh_options[@]}" "$SSH_USERNAME@$SSH_HOST" "$remote_command" <<'CONTROL_RELEASE'
set -euo pipefail

operation=$1
deploy_root="$HOME/$2"
private_root="$HOME/$3"
release_id=$4
releases_directory="$deploy_root/releases"
release_path="$releases_directory/$release_id"
approval_marker="$release_path/.production-approved"

fail() {
    printf 'Remote release control refused: %s\n' "$1" >&2
    exit 1
}

[[ ! -L "$deploy_root" && -d "$deploy_root" ]] || fail 'invalid deployment root'
[[ ! -L "$releases_directory" && -d "$releases_directory" ]] || fail 'invalid releases directory'
[[ ! -L "$private_root" && -d "$private_root" ]] || fail 'invalid private root'
home_root="$(realpath -e -- "$HOME")"
resolved_deploy_root="$(realpath -e -- "$deploy_root")"
resolved_releases_directory="$(realpath -e -- "$releases_directory")"
resolved_private_root="$(realpath -e -- "$private_root")"
[[ "$resolved_deploy_root" == "$home_root/"* ]] || fail 'deployment root escaped the SSH home'
[[ "$resolved_private_root" == "$home_root/"* ]] || fail 'private root escaped the SSH home'
[[ "$resolved_private_root" != "$resolved_deploy_root" &&
   "$resolved_private_root" != "$resolved_deploy_root/"* &&
   "$resolved_deploy_root" != "$resolved_private_root/"* ]] || fail 'deployment and private roots overlap'
[[ "$resolved_releases_directory" == "$resolved_deploy_root/releases" ]] || fail 'releases path escaped its root'
[[ ! -L "$release_path" && -d "$release_path" ]] || fail 'release is not a real directory'
resolved_release_path="$(realpath -e -- "$release_path")"
[[ "$resolved_release_path" == "$resolved_releases_directory/$release_id" ]] || fail 'release escaped its root'
[[ -f "$release_path/public/index.php" && -f "$release_path/vendor/autoload.php" ]] || fail 'release is incomplete'
[[ -L "$release_path/.env" ]] || fail 'release environment link is missing'
[[ "$(realpath -e -- "$release_path/.env")" == "$resolved_private_root/.env" ]] || fail 'release environment link has the wrong target'
[[ -L "$deploy_root/current" ]] || fail 'active release is not a symlink'
active_path="$(realpath -e -- "$deploy_root/current")"
active_release_id="$(basename -- "$active_path")"
[[ "$active_release_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'active release ID is invalid'
[[ "$active_path" == "$resolved_releases_directory/$active_release_id" ]] || fail 'active release is not a direct release directory'
[[ -f "$active_path/public/index.php" && -f "$active_path/vendor/autoload.php" ]] || fail 'active release is incomplete'
[[ -L "$active_path/.env" ]] || fail 'active release environment link is missing'
[[ "$(realpath -e -- "$active_path/.env")" == "$resolved_private_root/.env" ]] || fail 'active release environment link has the wrong target'

case "$operation" in
    approve)
        [[ "$active_path" == "$resolved_release_path" ]] || fail 'only the active release can be approved'
        [[ ! -L "$approval_marker" ]] || fail 'approval marker is symbolic'
        printf '%s\n' 'External production smoke test passed.' > "$approval_marker"
        chmod 644 "$approval_marker"
        printf 'Approved release: %s\n' "$release_id"
        ;;
    rollback)
        [[ -f "$approval_marker" && ! -L "$approval_marker" ]] || fail 'release is not approved for rollback'
        [[ "$active_path" != "$resolved_release_path" ]] || fail 'release is already active'
        temporary_link="$deploy_root/.rollback-$release_id-$$"
        [[ ! -e "$temporary_link" && ! -L "$temporary_link" ]] || fail 'temporary rollback link exists'
        trap 'rm -f -- "$temporary_link"' EXIT
        ln -s -- "$resolved_release_path" "$temporary_link"
        mv -Tf -- "$temporary_link" "$deploy_root/current"
        trap - EXIT
        [[ "$(realpath -e -- "$deploy_root/current")" == "$resolved_release_path" ]] || fail 'rollback activation failed'
        printf 'Active release: %s\n' "$release_id"
        ;;
esac
CONTROL_RELEASE
