#!/usr/bin/env bash

set -euo pipefail

readonly recovery_operation="${1:-}"

if [[ "$recovery_operation" != 'inspect' &&
      "$recovery_operation" != 'restore' &&
      "$recovery_operation" != 'cleanup' ]]; then
    printf '%s\n' 'Usage: deployment/run-release-recovery.sh inspect|restore|cleanup' >&2
    exit 2
fi

readonly -a required_variables=(
    DEPLOYMENT_NAME
    DEPLOY_PATH
    SSH_HOST
    SSH_HOST_KEY
    SSH_PASSWORD
    SSH_PORT
    SSH_USERNAME
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Missing release-recovery setting: %s\n' "$variable_name" >&2
        exit 1
    fi
done

if [[ "$DEPLOYMENT_NAME" != 'staging' ]]; then
    printf '%s\n' 'Only staging release recovery is currently supported.' >&2
    exit 1
fi

if [[ "$DEPLOY_PATH" != 'html/example.com/staging' ]]; then
    printf '%s\n' 'DEPLOY_PATH is not the configured staging environment root.' >&2
    exit 1
fi

previous_active_release_id=''

if [[ "$recovery_operation" != 'inspect' ]]; then
    if [[ -z "${RELEASE_ID:-}" ]]; then
        printf '%s\n' 'Missing release-recovery setting: RELEASE_ID' >&2
        exit 1
    fi

    if [[ ! -v ROLLBACK_RELEASE_ID ]]; then
        printf '%s\n' 'Missing release-recovery setting: ROLLBACK_RELEASE_ID' >&2
        exit 1
    fi

    if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
       [[ "$RELEASE_ID" == '.' || "$RELEASE_ID" == '..' ]]; then
        printf '%s\n' 'RELEASE_ID contains unsupported characters.' >&2
        exit 1
    fi

    previous_active_release_id=${ROLLBACK_RELEASE_ID:---none}

    if [[ "$previous_active_release_id" != '--none' ]] &&
       { [[ ! "$previous_active_release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
         [[ "$previous_active_release_id" == '.' || "$previous_active_release_id" == '..' ]]; }; then
        printf '%s\n' 'ROLLBACK_RELEASE_ID contains unsupported characters.' >&2
        exit 1
    fi
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

readonly ssh_directory="$RUNNER_TEMP/$DEPLOYMENT_NAME-recovery-ssh"
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

case "$recovery_operation" in
    inspect)
        printf -v remote_command \
            'bash -s -- inspect-pending "$HOME"/%q "$HOME"/%q %q' \
            "$DEPLOY_PATH" \
            "$DEPLOY_PATH" \
            "$DEPLOYMENT_NAME"
        ;;
    restore)
        printf -v remote_command \
            'bash -s -- recover "$HOME"/%q "$HOME"/%q %q %q %q' \
            "$DEPLOY_PATH" \
            "$DEPLOY_PATH" \
            "$RELEASE_ID" \
            "$previous_active_release_id" \
            "$DEPLOYMENT_NAME"
        ;;
    cleanup)
        if [[ "${RECOVERY_SMOKE_REQUIRED:-}" == 'true' ]]; then
            if [[ "${RECOVERY_SMOKE_VERIFIED:-}" != 'true' ]]; then
                printf '%s\n' \
                    'Manual recovery required: restored staging smoke verification did not pass.' \
                    >&2
                exit 1
            fi

            recovery_verification='verified'
        elif [[ "${RECOVERY_SMOKE_REQUIRED:-}" == 'false' ]]; then
            recovery_verification='not-required'
        else
            printf '%s\n' 'Missing or invalid release-recovery setting: RECOVERY_SMOKE_REQUIRED' >&2
            exit 1
        fi

        printf -v remote_command \
            'bash -s -- cleanup-failed "$HOME"/%q "$HOME"/%q %q %q %q %q' \
            "$DEPLOY_PATH" \
            "$DEPLOY_PATH" \
            "$RELEASE_ID" \
            "$previous_active_release_id" \
            "$recovery_verification" \
            "$DEPLOYMENT_NAME"
        ;;
esac

recovery_report="$(
    sshpass -e ssh "${ssh_options[@]}" "$remote" "$remote_command" \
        < "$release_retention_script"
)"
readonly recovery_report
printf '%s\n' "$recovery_report"

case "$recovery_operation" in
    inspect)
        pending_candidate_release_id="$(
            sed -n 's/^Pending candidate: //p' <<< "$recovery_report"
        )"

        if [[ "$pending_candidate_release_id" == 'none' ]]; then
            if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
                printf '%s\n' 'pending=false' >> "$GITHUB_OUTPUT"
            fi

            exit 0
        fi

        inspected_previous_active_release_id="$(
            sed -n 's/^Previous active release: //p' <<< "$recovery_report"
        )"
        inspected_pending_release_state="$(
            sed -n 's/^Pending candidate state: //p' <<< "$recovery_report"
        )"

        if [[ ! "$pending_candidate_release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
           [[ "$pending_candidate_release_id" == '.' ||
              "$pending_candidate_release_id" == '..' ]] ||
           { [[ "$inspected_previous_active_release_id" != '--none' ]] &&
             { [[ ! "$inspected_previous_active_release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
               [[ "$inspected_previous_active_release_id" == '.' ||
                  "$inspected_previous_active_release_id" == '..' ]]; }; } ||
           [[ "$inspected_pending_release_state" != 'prepared' &&
              "$inspected_pending_release_state" != 'activation-started' &&
              "$inspected_pending_release_state" != 'recovery-pending-smoke' ]]; then
            printf '%s\n' 'The release-recovery inspection report is invalid.' >&2
            exit 1
        fi

        if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
            printf '%s\n' 'pending=true' >> "$GITHUB_OUTPUT"
            printf 'release_id=%s\n' "$pending_candidate_release_id" >> "$GITHUB_OUTPUT"
            printf 'rollback_release_id=%s\n' \
                "$inspected_previous_active_release_id" >> "$GITHUB_OUTPUT"
            printf 'state=%s\n' "$inspected_pending_release_state" >> "$GITHUB_OUTPUT"
        fi
        ;;
    restore)
        smoke_verification_required="$(
            sed -n 's/^Smoke verification required: //p' <<< "$recovery_report"
        )"

        case "$smoke_verification_required" in
            yes)
                smoke_required='true'
                ;;
            no)
                smoke_required='false'
                ;;
            *)
                printf '%s\n' 'The release-recovery report is invalid.' >&2
                exit 1
                ;;
        esac

        if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
            printf 'smoke_required=%s\n' "$smoke_required" >> "$GITHUB_OUTPUT"
        fi
        ;;
esac
