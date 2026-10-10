#!/usr/bin/env bash

set -euo pipefail

readonly operation="${1:-}"

fail() {
    printf 'Production release control refused: %s\n' "$1" >&2
    exit 1
}

validate_release_id() {
    local release_id=$1

    if [[ ! "$release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
       [[ "$release_id" == '.' || "$release_id" == '..' ]]; then
        fail 'the release ID contains unsupported characters.'
    fi
}

validate_deployment_tree() {
    local deployment_root_argument=$1
    local allowed_deployment_root=$2
    local resolved_deployment_root
    local resolved_allowed_deployment_root
    local resolved_releases_directory

    if [[ "$deployment_root_argument" != /* || "$allowed_deployment_root" != /* ]] ||
       [[ "$deployment_root_argument" == *'/../'* || "$deployment_root_argument" == */.. ]] ||
       [[ "$allowed_deployment_root" == *'/../'* || "$allowed_deployment_root" == */.. ]]; then
        fail 'the deployment root is unsafe.'
    fi

    if [[ "$deployment_root_argument" == '/' || "$allowed_deployment_root" == '/' ]] ||
       [[ -L "$deployment_root_argument" || ! -d "$deployment_root_argument" ]] ||
       [[ -L "$allowed_deployment_root" || ! -d "$allowed_deployment_root" ]]; then
        fail 'the deployment root is not a real allowed directory.'
    fi

    resolved_deployment_root="$(realpath -e -- "$deployment_root_argument")" ||
        fail 'the deployment root cannot be resolved.'
    resolved_allowed_deployment_root="$(realpath -e -- "$allowed_deployment_root")" ||
        fail 'the allowed deployment root cannot be resolved.'

    if [[ "$resolved_deployment_root" != "$resolved_allowed_deployment_root" ]]; then
        fail 'the deployment root is outside the allowed production root.'
    fi

    deployment_root=$resolved_deployment_root
    releases_directory="$deployment_root/releases"

    if [[ -L "$releases_directory" || ! -d "$releases_directory" ]]; then
        fail 'the releases directory is not a real directory.'
    fi

    resolved_releases_directory="$(realpath -e -- "$releases_directory")" ||
        fail 'the releases directory cannot be resolved.'

    if [[ "$resolved_releases_directory" != "$deployment_root/releases" ]]; then
        fail 'the releases directory resolves outside the production root.'
    fi
}

validate_release_directory() {
    local release_id=$1
    local release_path="$releases_directory/$release_id"
    local resolved_release_path

    validate_release_id "$release_id"

    if [[ -L "$release_path" || ! -d "$release_path" ]]; then
        fail "release '$release_id' is not a real directory."
    fi

    resolved_release_path="$(realpath -e -- "$release_path")" ||
        fail "release '$release_id' cannot be resolved."

    if [[ "$resolved_release_path" != "$release_path" ]]; then
        fail "release '$release_id' is not a direct child of the releases directory."
    fi

    if [[ ! -f "$release_path/public/index.php" ||
          ! -f "$release_path/vendor/autoload.php" ]]; then
        fail "release '$release_id' is incomplete."
    fi
}

resolve_active_release_id() {
    local current_link="$deployment_root/current"
    local resolved_active_release
    local active_release_id

    if [[ ! -L "$current_link" ]]; then
        fail 'the active release path is not a symbolic link.'
    fi

    resolved_active_release="$(realpath -e -- "$current_link")" ||
        fail 'the active release symbolic link is broken.'
    active_release_id="$(basename -- "$resolved_active_release")"
    validate_release_id "$active_release_id"

    if [[ "$resolved_active_release" != "$releases_directory/$active_release_id" ]]; then
        fail 'the active release resolves outside the releases directory.'
    fi

    validate_release_directory "$active_release_id"
    printf '%s\n' "$active_release_id"
}

require_production_approval() {
    local release_id=$1
    local approval_marker="$releases_directory/$release_id/.production-approved"

    if [[ -L "$approval_marker" ]] ||
       { [[ -e "$approval_marker" ]] && [[ ! -f "$approval_marker" ]]; }; then
        fail "release '$release_id' has an inconsistent production approval marker."
    fi

    if [[ ! -f "$approval_marker" ]]; then
        fail "release '$release_id' is not approved for production rollback."
    fi
}

approve_release() {
    local release_id=$1
    local active_release_id
    local approval_marker="$releases_directory/$release_id/.production-approved"

    validate_release_directory "$release_id"
    active_release_id="$(resolve_active_release_id)"

    if [[ "$active_release_id" != "$release_id" ]]; then
        fail 'the requested approval release is not active.'
    fi

    if [[ -L "$approval_marker" ]] ||
       { [[ -e "$approval_marker" ]] && [[ ! -f "$approval_marker" ]]; }; then
        fail 'the production approval marker is inconsistent.'
    fi

    printf '%s\n' 'Post-deployment smoke checks passed.' > "$approval_marker"
    chmod 644 "$approval_marker"
    printf 'Approved production release: %s\n' "$release_id"
}

activate_rollback_release() {
    local release_id=$1
    local previous_active_release_id
    local temporary_link="$deployment_root/.rollback-$release_id-$$"

    validate_release_directory "$release_id"
    require_production_approval "$release_id"
    previous_active_release_id="$(resolve_active_release_id)"

    if [[ "$previous_active_release_id" == "$release_id" ]]; then
        fail 'the requested rollback release is already active.'
    fi

    if [[ -e "$temporary_link" || -L "$temporary_link" ]]; then
        fail 'the temporary rollback link already exists.'
    fi

    trap 'rm -f -- "$temporary_link"' EXIT
    ln -s "$releases_directory/$release_id" "$temporary_link"
    mv -Tf -- "$temporary_link" "$deployment_root/current"
    trap - EXIT

    if [[ "$(resolve_active_release_id)" != "$release_id" ]]; then
        fail 'the rollback release could not be activated atomically.'
    fi

    printf 'Previous active release: %s\n' "$previous_active_release_id"
    printf 'Active release: %s\n' "$release_id"
}

deployment_root=''
releases_directory=''

if (( $# != 4 )); then
    printf '%s\n' \
        'Usage: production-release-control.sh approve|rollback DEPLOYMENT_ROOT ALLOWED_ROOT RELEASE_ID' \
        >&2
    exit 2
fi

validate_deployment_tree "$2" "$3"
validate_release_id "$4"

case "$operation" in
    approve)
        approve_release "$4"
        ;;
    rollback)
        activate_rollback_release "$4"
        ;;
    *)
        printf '%s\n' \
            'Usage: production-release-control.sh approve|rollback DEPLOYMENT_ROOT ALLOWED_ROOT RELEASE_ID' \
            >&2
        exit 2
        ;;
esac
