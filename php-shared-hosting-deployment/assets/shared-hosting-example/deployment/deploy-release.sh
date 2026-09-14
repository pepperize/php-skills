#!/usr/bin/env bash

set -euo pipefail

readonly -a required_variables=(
    DEPLOYMENT_ARCHIVE
    DEPLOYMENT_ARCHIVE_DIGEST
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
    printf 'Deployment refused: %s\n' "$1" >&2
    exit 1
}

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

for variable_name in "${required_variables[@]}"; do
    [[ -n "${!variable_name:-}" ]] || fail "missing setting: $variable_name"
done

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

[[ -f "$DEPLOYMENT_ARCHIVE" ]] || fail 'release archive is missing'
[[ -f "$DEPLOYMENT_ARCHIVE_DIGEST" ]] || fail 'release digest is missing'
(
    cd "$(dirname "$DEPLOYMENT_ARCHIVE")"
    sha256sum --check "$(basename "$DEPLOYMENT_ARCHIVE_DIGEST")"
) || fail 'release digest verification failed'

readonly capacity_margin_kib="${CAPACITY_MARGIN_KIB:-10240}"
[[ "$capacity_margin_kib" =~ ^[1-9][0-9]*$ ]] || fail 'capacity margin must be positive KiB'

archive_size_bytes="$(wc -c < "$DEPLOYMENT_ARCHIVE")"
expanded_size_bytes="$(gzip -dc -- "$DEPLOYMENT_ARCHIVE" | wc -c)"
readonly required_capacity_kib=$((
    (archive_size_bytes + expanded_size_bytes + 1023) / 1024
    + capacity_margin_kib
))

readonly ssh_directory="$(mktemp -d "${RUNNER_TEMP:-/tmp}/shared-host-ssh.XXXXXX")"
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

readonly remote="$SSH_USERNAME@$SSH_HOST"
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
readonly -a scp_options=(
    -i "$private_key_file"
    -o BatchMode=yes
    -o ConnectionAttempts=3
    -o ConnectTimeout=15
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=$known_hosts_file"
    -P "$SSH_PORT"
)

printf -v prepare_command \
    'bash -s -- %q %q %q %q' \
    "$DEPLOY_PATH" \
    "$PRIVATE_PATH" \
    "$RELEASE_ID" \
    "$required_capacity_kib"

prepare_report="$(
    ssh "${ssh_options[@]}" "$remote" "$prepare_command" <<'PREPARE_RELEASE'
set -euo pipefail

requested_deploy_root="$HOME/$1"
requested_private_root="$HOME/$2"
release_id=$3
required_capacity_kib=$4

home_root="$(realpath -e -- "$HOME")"
[[ ! -L "$requested_deploy_root" ]] || { echo 'Deployment root is symbolic.' >&2; exit 1; }
[[ ! -L "$requested_private_root" ]] || { echo 'Private root is symbolic.' >&2; exit 1; }
deploy_root="$(realpath -m -- "$requested_deploy_root")"
private_root="$(realpath -m -- "$requested_private_root")"
[[ "$deploy_root" == "$home_root/"* ]] || {
    echo 'Deployment root resolves outside the SSH home.' >&2
    exit 1
}
[[ "$private_root" == "$home_root/"* ]] || {
    echo 'Private root resolves outside the SSH home.' >&2
    exit 1
}

mkdir -p -- "$deploy_root"
resolved_deploy_root="$(realpath -e -- "$deploy_root")"
[[ "$resolved_deploy_root" == "$home_root/"* ]] || {
    echo 'Deployment root resolves outside the SSH home.' >&2
    exit 1
}
deploy_root=$resolved_deploy_root
releases_directory="$deploy_root/releases"
candidate="$releases_directory/$release_id"

[[ ! -L "$releases_directory" ]] || { echo 'Releases path is symbolic.' >&2; exit 1; }
mkdir -p -- "$releases_directory"
if [[ -e "$private_root" ]]; then
    [[ -d "$private_root" && ! -L "$private_root" ]] || {
        echo 'Private root is not a real directory.' >&2
        exit 1
    }
else
    install -d -m 700 -- "$private_root"
fi
resolved_private_root="$(realpath -e -- "$private_root")"
[[ "$resolved_private_root" == "$home_root/"* ]] || {
    echo 'Private root resolves outside the SSH home.' >&2
    exit 1
}
private_root=$resolved_private_root
[[ "$private_root" != "$deploy_root" &&
   "$private_root" != "$deploy_root/"* &&
   "$deploy_root" != "$private_root/"* ]] || {
    echo 'Deployment and private roots must be separate.' >&2
    exit 1
}

previous_release_id='--none'
if [[ -e "$deploy_root/current" || -L "$deploy_root/current" ]]; then
    [[ -L "$deploy_root/current" ]] || { echo 'Current release is not a symlink.' >&2; exit 1; }
    active_path="$(realpath -e -- "$deploy_root/current")"
    previous_release_id="$(basename -- "$active_path")"
    [[ "$active_path" == "$releases_directory/$previous_release_id" ]] || {
        echo 'Current release resolves outside the release tree.' >&2
        exit 1
    }
    [[ -f "$active_path/public/index.php" && -f "$active_path/vendor/autoload.php" ]] || {
        echo 'Current release is incomplete.' >&2
        exit 1
    }
elif find -P "$releases_directory" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo 'A non-empty release tree has no active release.' >&2
    exit 1
fi

[[ ! -e "$candidate" && ! -L "$candidate" ]] || { echo 'Candidate already exists.' >&2; exit 1; }
available_capacity_kib="$(df -Pk "$releases_directory" | awk 'NR == 2 {print $4}')"
[[ "$available_capacity_kib" =~ ^[0-9]+$ ]] || { echo 'Capacity is unavailable.' >&2; exit 1; }
(( available_capacity_kib >= required_capacity_kib )) || {
    printf 'Candidate needs %s KiB; %s KiB is available.\n' \
        "$required_capacity_kib" "$available_capacity_kib" >&2
    exit 1
}

mkdir -- "$candidate"
printf 'Previous active release: %s\n' "$previous_release_id"
PREPARE_RELEASE
)"
printf '%s\n' "$prepare_report"

previous_release_id="$(sed -n 's/^Previous active release: //p' <<< "$prepare_report")"
if [[ "$previous_release_id" != '--none' &&
      ! "$previous_release_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    fail 'invalid previous-release report'
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'previous_release_id=%s\n' "$previous_release_id" >> "$GITHUB_OUTPUT"
fi

scp "${scp_options[@]}" \
    "$DEPLOYMENT_ARCHIVE" \
    "$DEPLOYMENT_ARCHIVE_DIGEST" \
    "$remote:$DEPLOY_PATH/releases/$RELEASE_ID/"

printf -v activate_command \
    'bash -s -- %q %q %q' \
    "$DEPLOY_PATH" \
    "$PRIVATE_PATH" \
    "$RELEASE_ID"

ssh "${ssh_options[@]}" "$remote" "$activate_command" <<'ACTIVATE_RELEASE'
set -euo pipefail

deploy_root="$HOME/$1"
private_root="$HOME/$2"
release_id=$3

[[ ! -L "$deploy_root" && ! -L "$private_root" ]] || {
    echo 'Deployment tree changed before activation.' >&2
    exit 1
}
home_root="$(realpath -e -- "$HOME")"
deploy_root="$(realpath -e -- "$deploy_root")"
private_root="$(realpath -e -- "$private_root")"
[[ "$deploy_root" == "$home_root/"* && "$private_root" == "$home_root/"* ]] || {
    echo 'Deployment path escaped the SSH home before activation.' >&2
    exit 1
}
[[ "$private_root" != "$deploy_root" &&
   "$private_root" != "$deploy_root/"* &&
   "$deploy_root" != "$private_root/"* ]] || {
    echo 'Deployment and private roots overlap before activation.' >&2
    exit 1
}
releases_directory="$deploy_root/releases"
release_path="$releases_directory/$release_id"
temporary_link="$deploy_root/.current-$release_id-$$"
cleanup() {
    rm -f -- "$temporary_link" "$release_path/.archive-entries"
}
trap cleanup EXIT

[[ ! -L "$releases_directory" && ! -L "$release_path" ]] || {
    echo 'Release tree changed before activation.' >&2
    exit 1
}
resolved_release_path="$(realpath -e -- "$release_path")"
[[ "$resolved_release_path" == "$release_path" ]] || {
    echo 'Candidate is not a direct release directory.' >&2
    exit 1
}

cd "$release_path"
sha256sum --check application.tar.gz.sha256
tar -tzf application.tar.gz > .archive-entries
while IFS= read -r entry; do
    case "$entry" in
        /*|../*|*/../*|*/..)
            echo 'Archive contains an unsafe path.' >&2
            exit 1
            ;;
    esac
done < .archive-entries
if tar -tvzf application.tar.gz |
   awk 'substr($1, 1, 1) != "-" && substr($1, 1, 1) != "d" { found=1 } END { exit(found ? 0 : 1) }'; then
    echo 'Archive contains a symbolic link, hard link, or special file.' >&2
    exit 1
fi
tar -xzf application.tar.gz
rm -- application.tar.gz application.tar.gz.sha256 .archive-entries

[[ -f public/index.php && -f vendor/autoload.php ]] || {
    echo 'Candidate is missing its entry point or Composer autoloader.' >&2
    exit 1
}
[[ -f "$private_root/.env" && ! -L "$private_root/.env" ]] || {
    echo 'Private environment configuration is missing.' >&2
    exit 1
}
[[ ! -e .env && ! -L .env ]] || {
    echo 'The artifact must not contain a root environment file.' >&2
    exit 1
}
ln -s -- "$private_root/.env" .env

# Projects may provide one executable that performs runtime preflight, forward
# migrations, and cache preparation before the active pointer changes.
if [[ -x bin/deploy-prepare ]]; then
    APPLICATION_ENV_FILE="$private_root/.env" bin/deploy-prepare
fi

ln -s -- "$release_path" "$temporary_link"
mv -Tf -- "$temporary_link" "$deploy_root/current"
trap - EXIT
printf 'Active release: %s\n' "$release_id"
ACTIVATE_RELEASE
