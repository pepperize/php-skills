#!/usr/bin/env bash

# $HOME in quoted command templates expands on the remote host.
# shellcheck disable=SC2016
set -euo pipefail

deployment_phase='validating deployment settings'

report_deployment_failure() {
    local exit_status=$?

    printf 'Deployment failed while %s (exit %d).\n' \
        "$deployment_phase" \
        "$exit_status" \
        >&2
}

trap report_deployment_failure ERR

readonly -a required_variables=(
    DEPLOYMENT_ARCHIVE
    DEPLOYMENT_NAME
    DEPLOY_PATH
    EXPECTED_COMMIT
    PRIVATE_PATH
    RELEASE_ID
    SSH_HOST
    SSH_HOST_KEY
    SSH_PASSWORD
    SSH_PORT
    SSH_USERNAME
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Missing deployment setting: %s\n' "$variable_name" >&2
        exit 1
    fi
done

if [[ "$DEPLOYMENT_NAME" != 'staging' && "$DEPLOYMENT_NAME" != 'production' ]]; then
    printf '%s\n' 'DEPLOYMENT_NAME must be staging or production.' >&2
    exit 1
fi

for remote_path in "$DEPLOY_PATH" "$PRIVATE_PATH"; do
    if [[ "$remote_path" == /* ||
          "$remote_path" == *..* ||
          "$remote_path" == *//* ||
          ! "$remote_path" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        printf 'Unsafe remote deployment path: %s\n' "$remote_path" >&2
        exit 1
    fi
done

case "$DEPLOYMENT_NAME" in
    staging)
        expected_deploy_path='html/example.com/staging'
        expected_private_path='files/example.com/staging'
        ;;
    production)
        expected_deploy_path='html/example.com'
        expected_private_path='files/example.com/production'
        ;;
esac

if [[ "$DEPLOY_PATH" != "$expected_deploy_path" ||
      "$PRIVATE_PATH" != "$expected_private_path" ]]; then
    printf '%s\n' 'Deployment paths do not match the configured environment roots.' >&2
    exit 1
fi

if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ || "$RELEASE_ID" == "." || "$RELEASE_ID" == ".." ]]; then
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

if [[ ! -f "$DEPLOYMENT_ARCHIVE" ]]; then
    printf 'Deployment archive does not exist: %s\n' "$DEPLOYMENT_ARCHIVE" >&2
    exit 1
fi

readonly release_retention_script='deployment/release-retention.sh'

if [[ ! -f "$release_retention_script" ]]; then
    printf 'Release-retention operation does not exist: %s\n' "$release_retention_script" >&2
    exit 1
fi

readonly ssh_directory="$RUNNER_TEMP/$DEPLOYMENT_NAME-ssh"
readonly known_hosts="$ssh_directory/known_hosts"
readonly remote="$SSH_USERNAME@$SSH_HOST"
install -d -m 700 "$ssh_directory"
printf '%s\n' "$SSH_HOST_KEY" > "$known_hosts"
chmod 600 "$known_hosts"

if [[ ! "$EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
   [[ "$(tar -xOf "$DEPLOYMENT_ARCHIVE" source-commit)" != "$EXPECTED_COMMIT" ]]; then
    printf '%s\n' 'The archive does not match the tested source commit.' >&2
    exit 1
fi
archive_digest="$(sha256sum -- "$DEPLOYMENT_ARCHIVE" | cut -d ' ' -f 1)"
readonly archive_digest

readonly -a ssh_options=(
    -o ConnectionAttempts=3
    -o ConnectTimeout=15
    -o NumberOfPasswordPrompts=1
    -o "PreferredAuthentications=password,keyboard-interactive"
    -o PubkeyAuthentication=no
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=$known_hosts"
    -p "$SSH_PORT"
)

readonly -a scp_options=(
    -o ConnectionAttempts=3
    -o ConnectTimeout=15
    -o NumberOfPasswordPrompts=1
    -o "PreferredAuthentications=password,keyboard-interactive"
    -o PubkeyAuthentication=no
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=$known_hosts"
    -P "$SSH_PORT"
)

export SSHPASS="$SSH_PASSWORD"

deployment_phase='calculating candidate capacity'

archive_size_bytes="$(wc -c < "$DEPLOYMENT_ARCHIVE")"
uncompressed_archive_size_bytes="$(gzip -dc -- "$DEPLOYMENT_ARCHIVE" | wc -c)"
readonly archive_size_bytes
readonly uncompressed_archive_size_bytes
readonly capacity_safety_margin_kib=10240
readonly candidate_required_capacity_kib=$((
    (archive_size_bytes + uncompressed_archive_size_bytes + 1023) / 1024
    + capacity_safety_margin_kib
))

deployment_phase='initializing the remote deployment directories'

printf -v initialize_command \
    'bash -s -- %q %q' \
    "$DEPLOY_PATH" \
    "$PRIVATE_PATH"

sshpass -e ssh "${ssh_options[@]}" "$remote" "$initialize_command" <<'INITIALIZE_DEPLOYMENT'
set -euo pipefail

deploy_path="$HOME/$1"
private_path="$HOME/$2"
releases_directory="$deploy_path/releases"

if [[ -L "$deploy_path" ]]; then
    printf '%s\n' 'The deployment root must not be a symbolic link.' >&2
    exit 1
fi

mkdir -p "$deploy_path"

if [[ -L "$releases_directory" ]]; then
    printf '%s\n' 'The releases directory must not be a symbolic link.' >&2
    exit 1
fi

umask 022
mkdir -p "$releases_directory"
install -d -m 700 "$private_path"
INITIALIZE_DEPLOYMENT

deployment_phase='capturing the active release and checking capacity'

printf -v prepare_command \
    'bash -s -- prepare "$HOME"/%q "$HOME"/%q %q %q %q' \
    "$DEPLOY_PATH" \
    "$DEPLOY_PATH" \
    "$RELEASE_ID" \
    "$candidate_required_capacity_kib" \
    "$DEPLOYMENT_NAME"

prepare_report="$(
    sshpass -e ssh "${ssh_options[@]}" "$remote" "$prepare_command" \
        < "$release_retention_script"
)"
readonly prepare_report
printf '%s\n' "$prepare_report"

captured_active_release_id="$(
    sed -n 's/^Active release: //p' <<< "$prepare_report"
)"
readonly captured_active_release_id

if [[ "$captured_active_release_id" == '--none' ]]; then
    rollback_release_id=''
elif [[ "$captured_active_release_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
    rollback_release_id=$captured_active_release_id
else
    printf '%s\n' 'The captured active release report is invalid.' >&2
    exit 1
fi

readonly rollback_release_id

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'rollback_release_id=%s\n' "$rollback_release_id" >> "$GITHUB_OUTPUT"
    printf '%s\n' 'candidate_prepared=true' >> "$GITHUB_OUTPUT"
fi

deployment_phase='uploading the release archive'

sshpass -e scp "${scp_options[@]}" \
    "$DEPLOYMENT_ARCHIVE" \
    "$remote:$DEPLOY_PATH/releases/$RELEASE_ID/application.tar.gz"

deployment_phase='activating the remote release'

printf -v activate_command \
    'bash -s -- %q %q %q %q %q' \
    "$DEPLOY_PATH" \
    "$RELEASE_ID" \
    "$PRIVATE_PATH" \
    "$DEPLOYMENT_NAME" \
    "$archive_digest"

sshpass -e ssh "${ssh_options[@]}" "$remote" "$activate_command" <<'ACTIVATE_RELEASE'
set -euo pipefail

deployment_phase='initializing release activation'

report_deployment_failure() {
    local exit_status=$?

    printf 'Remote deployment failed while %s (exit %d).\n' \
        "$deployment_phase" \
        "$exit_status" \
        >&2
}

trap report_deployment_failure ERR

deploy_path="$HOME/$1"
release_id=$2
private_path="$HOME/$3"
deployment_name=$4
archive_digest=$5
php_bin=php
release_path="$deploy_path/releases/$release_id"
archive="$release_path/application.tar.gz"
dispatcher="$deploy_path/.htaccess"
temporary_dispatcher="$deploy_path/.htaccess.$release_id"
dispatcher_source="$release_path/deployment/apache/$deployment_name.htaccess"
release_guard_source="$release_path/deployment/apache/release.htaccess"
php_configuration="$release_path/.user.ini"
environment_file="$private_path/.env"
log_directory="$private_path/log"
php_error_log="$log_directory/php-error.log"
temporary_link="$deploy_path/.current-$release_id"
managed_dispatcher_marker="# Managed by application $deployment_name deployment"

cleanup() {
    rm -f \
        "$temporary_dispatcher" \
        "$temporary_link"
}

trap cleanup EXIT

deployment_phase='extracting the release archive'
[[ "$(sha256sum -- "$archive" | cut -d ' ' -f 1)" == "$archive_digest" ]] || {
    echo 'The uploaded archive digest differs from the tested archive.' >&2
    exit 1
}
tar -xzf "$archive" -C "$release_path"
rm "$archive"

deployment_phase='validating the public entry point'
test -f "$release_path/backend/public/index.php"

deployment_phase='validating the Composer autoloader'
test -f "$release_path/vendor/autoload.php"

deployment_phase='validating the deployment dispatcher'
test -f "$dispatcher_source"

deployment_phase='validating the release access guard'
test -f "$release_guard_source"

deployment_phase='validating the private environment'
test -f "$environment_file"
test ! -L "$environment_file"
chmod 600 "$environment_file"

deployment_phase='validating the managed deployment dispatcher'
if [[ -e "$dispatcher" ]] &&
   ! grep -q -F -x "$managed_dispatcher_marker" "$dispatcher"; then
    echo "Refusing to replace unmanaged file: $dispatcher" >&2
    exit 1
fi

umask 077
install -d -m 700 "$private_path"

deployment_phase='provisioning the PHP error log'
install -d -m 700 "$log_directory"
touch "$php_error_log"
chmod 600 "$php_error_log"
test -w "$php_error_log"

deployment_phase='writing the release PHP configuration'
{
    printf '%s\n' 'display_errors=Off'
    printf '%s\n' 'log_errors=On'
    printf 'error_log="%s"\n' "$php_error_log"
} > "$php_configuration"
chmod 644 "$php_configuration"

deployment_phase='checking PHP runtime and production dependencies'
"$php_bin" -r 'if (PHP_MAJOR_VERSION !== 8 || PHP_MINOR_VERSION !== 4) exit(1); foreach (["intl", "mbstring", "pdo_mysql", "xml", "zip", "gd"] as $extension) if (!extension_loaded($extension)) exit(1);'
APPLICATION_ENV_FILE="$environment_file" "$php_bin" "$release_path/vendor/composer/platform_check.php"

deployment_phase='preparing the application'
(
    cd "$release_path"
    APPLICATION_ENV_FILE="$environment_file" PRIVATE_PATH="$private_path" \
        DEPLOYMENT_NAME="$deployment_name" RELEASE_ID="$release_id" PHP_BIN="$php_bin" \
        bash deployment/prepare.sh
)

deployment_phase='preparing the release switch'
install -m 644 "$release_guard_source" "$release_path/.htaccess"
install -m 644 "$dispatcher_source" "$temporary_dispatcher"
printf '\nSetEnv APPLICATION_ENV_FILE %s\n' \
    "$environment_file" >> "$temporary_dispatcher"

deployment_phase='switching to the new release'
if [[ "$deployment_name" == 'staging' ]]; then
    bash "$release_path/deployment/release-retention.sh" \
        mark-activation \
        "$deploy_path" \
        "$deploy_path" \
        "$release_id" \
        staging
fi

ln -s "$release_path" "$temporary_link"
mv -Tf "$temporary_link" "$deploy_path/current"
mv -f "$temporary_dispatcher" "$dispatcher"

ACTIVATE_RELEASE
