#!/usr/bin/env bash

set -euo pipefail

readonly operation="${1:-}"

if [[ "$operation" != 'approve' && "$operation" != 'rollback' ]]; then
    printf '%s\n' 'Usage: deployment/release-control.sh approve|rollback' >&2
    exit 2
fi

readonly -a required_variables=(
    DEPLOY_PATH
    RELEASE_ID
    SSH_HOST
    SSH_HOST_KEY
    SSH_PASSWORD
    SSH_PORT
    SSH_USERNAME
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Missing release-control setting: %s\n' "$variable_name" >&2
        exit 1
    fi
done

if [[ "$DEPLOY_PATH" == /* ||
      "$DEPLOY_PATH" == *..* ||
      "$DEPLOY_PATH" == *//* ||
      ! "$DEPLOY_PATH" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    printf '%s\n' 'DEPLOY_PATH is unsafe.' >&2
    exit 1
fi

if [[ "$DEPLOY_PATH" != 'html/example.com' ]]; then
    printf '%s\n' 'DEPLOY_PATH is not the configured production environment root.' >&2
    exit 1
fi

if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
   [[ "$RELEASE_ID" == '.' || "$RELEASE_ID" == '..' ]]; then
    printf '%s\n' 'RELEASE_ID contains unsupported characters.' >&2
    exit 1
fi

if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]]; then
    printf '%s\n' 'SSH_PORT must be numeric.' >&2
    exit 1
fi

if [[ ! "$SSH_HOST" =~ ^[A-Za-z0-9.-]+$ ||
      ! "$SSH_USERNAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf '%s\n' 'SSH host or username contains unsupported characters.' >&2
    exit 1
fi

if [[ "$SSH_HOST_KEY" != "$SSH_HOST ssh-ed25519 "* ]]; then
    printf '%s\n' 'SSH_HOST_KEY must be the pinned ED25519 key for SSH_HOST.' >&2
    exit 1
fi

readonly production_release_control_script='deployment/production-release-control.sh'

if [[ ! -f "$production_release_control_script" ]]; then
    printf 'Production release-control operation does not exist: %s\n' \
        "$production_release_control_script" \
        >&2
    exit 1
fi

readonly ssh_directory="$RUNNER_TEMP/production-release-control-ssh"
readonly known_hosts="$ssh_directory/known_hosts"
readonly remote="$SSH_USERNAME@$SSH_HOST"

install -d -m 700 "$ssh_directory"
printf '%s\n' "$SSH_HOST_KEY" > "$known_hosts"
chmod 600 "$known_hosts"

readonly -a ssh_options=(
    -o ConnectionAttempts=3
    -o ConnectTimeout=15
    -o NumberOfPasswordPrompts=1
    -o PreferredAuthentications=password,keyboard-interactive
    -o PubkeyAuthentication=no
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=$known_hosts"
    -p "$SSH_PORT"
)

export SSHPASS="$SSH_PASSWORD"

printf -v remote_command \
    'bash -s -- %q "$HOME"/%q "$HOME"/%q %q' \
    "$operation" \
    "$DEPLOY_PATH" \
    "$DEPLOY_PATH" \
    "$RELEASE_ID"

control_report="$(
    sshpass -e ssh "${ssh_options[@]}" "$remote" "$remote_command" \
        < "$production_release_control_script"
)"
readonly control_report
printf '%s\n' "$control_report"

if [[ "$operation" == 'rollback' ]]; then
    previous_active_release_id="$(
        sed -n 's/^Previous active release: //p' <<< "$control_report"
    )"

    if [[ ! "$previous_active_release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
       [[ "$previous_active_release_id" == '.' ||
          "$previous_active_release_id" == '..' ]]; then
        printf '%s\n' 'The production rollback report is invalid.' >&2
        exit 1
    fi

    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf 'previous_active_release_id=%s\n' \
            "$previous_active_release_id" \
            >> "$GITHUB_OUTPUT"
    fi
fi
