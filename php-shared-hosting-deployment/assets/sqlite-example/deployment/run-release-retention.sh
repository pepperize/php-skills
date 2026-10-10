#!/usr/bin/env bash

set -euo pipefail

readonly retention_operation="${1:-deployment}"

if [[ "$retention_operation" != 'deployment' &&
      "$retention_operation" != 'rollback' ]]; then
    printf '%s\n' 'Usage: deployment/run-release-retention.sh [deployment|rollback]' >&2
    exit 2
fi

readonly -a required_variables=(
    DEPLOYMENT_NAME
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
        printf 'Missing release-retention setting: %s\n' "$variable_name" >&2
        exit 1
    fi
done

if [[ ! -v ROLLBACK_RELEASE_ID ]]; then
    printf '%s\n' 'Missing release-retention setting: ROLLBACK_RELEASE_ID' >&2
    exit 1
fi

if [[ "$DEPLOYMENT_NAME" != 'staging' && "$DEPLOYMENT_NAME" != 'production' ]]; then
    printf '%s\n' 'DEPLOYMENT_NAME must be staging or production.' >&2
    exit 1
fi

case "$DEPLOYMENT_NAME" in
    staging)
        expected_deploy_path='html/example.com/staging'
        ;;
    production)
        expected_deploy_path='html/example.com'
        ;;
esac

if [[ "$DEPLOY_PATH" != "$expected_deploy_path" ]]; then
    printf '%s\n' 'DEPLOY_PATH is not the configured environment root.' >&2
    exit 1
fi

if [[ "$retention_operation" == 'rollback' && "$DEPLOYMENT_NAME" != 'production' ]]; then
    printf '%s\n' 'Rollback retention is supported only for production.' >&2
    exit 1
fi

if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
   [[ "$RELEASE_ID" == '.' || "$RELEASE_ID" == '..' ]]; then
    printf '%s\n' 'RELEASE_ID contains unsupported characters.' >&2
    exit 1
fi

rollback_release_id=${ROLLBACK_RELEASE_ID:---none}

if [[ "$rollback_release_id" != '--none' ]] &&
   { [[ ! "$rollback_release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
     [[ "$rollback_release_id" == '.' || "$rollback_release_id" == '..' ]]; }; then
    printf '%s\n' 'ROLLBACK_RELEASE_ID contains unsupported characters.' >&2
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

readonly release_retention_script='deployment/release-retention.sh'

if [[ ! -f "$release_retention_script" ]]; then
    printf 'Release-retention operation does not exist: %s\n' "$release_retention_script" >&2
    exit 1
fi

readonly ssh_directory="$RUNNER_TEMP/$DEPLOYMENT_NAME-retention-ssh"
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

case "$retention_operation" in
    deployment)
        printf -v remote_command \
            'bash -s -- retain "$HOME"/%q "$HOME"/%q %q %q %q' \
            "$DEPLOY_PATH" \
            "$DEPLOY_PATH" \
            "$RELEASE_ID" \
            "$rollback_release_id" \
            "$DEPLOYMENT_NAME"
        ;;
    rollback)
        if [[ "$rollback_release_id" == '--none' ]]; then
            printf '%s\n' 'Rollback retention requires the deactivated release ID.' >&2
            exit 1
        fi

        printf -v remote_command \
            'bash -s -- retain-production-rollback "$HOME"/%q "$HOME"/%q %q %q' \
            "$DEPLOY_PATH" \
            "$DEPLOY_PATH" \
            "$RELEASE_ID" \
            "$rollback_release_id"
        ;;
esac

sshpass -e ssh "${ssh_options[@]}" "$remote" "$remote_command" \
    < "$release_retention_script"
