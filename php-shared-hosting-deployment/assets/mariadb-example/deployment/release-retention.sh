#!/usr/bin/env bash

set -euo pipefail

readonly operation="${1:-}"

fail() {
    printf 'Release retention refused: %s\n' "$1" >&2
    exit 1
}

require_manual_recovery() {
    printf 'Manual recovery required: %s\n' "$1" >&2
    exit 1
}

validate_release_id() {
    local release_id=$1

    if [[ ! "$release_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
       [[ "$release_id" == '.' || "$release_id" == '..' ]]; then
        fail 'a release ID contains unsupported characters.'
    fi
}

validate_optional_release_id() {
    if [[ "$1" != '--none' ]]; then
        validate_release_id "$1"
    fi
}

validate_staging_policy() {
    if [[ "$1" != 'staging' ]]; then
        fail 'the requested environment policy is not supported.'
    fi
}

validate_environment_policy() {
    if [[ "$1" != 'staging' && "$1" != 'production' ]]; then
        fail 'the requested environment policy is not supported.'
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
        fail 'the deployment root is outside the allowed environment root.'
    fi

    deployment_root=$resolved_deployment_root
    releases_directory="$deployment_root/releases"
    pending_release_file="$deployment_root/.pending-release"

    if [[ -L "$releases_directory" || ! -d "$releases_directory" ]]; then
        fail 'the releases directory is not a real directory.'
    fi

    resolved_releases_directory="$(realpath -e -- "$releases_directory")" ||
        fail 'the releases directory cannot be resolved.'

    if [[ "$resolved_releases_directory" != "$deployment_root/releases" ]]; then
        fail 'the releases directory resolves outside the deployment root.'
    fi
}

validate_release_directory() {
    local release_id=$1
    local require_complete_release=$2
    local release_path="${releases_directory:?}/$release_id"
    local resolved_release_path

    validate_release_id "$release_id"

    if [[ -L "$release_path" || ! -d "$release_path" ]]; then
        fail "release '$release_id' is not a real directory."
    fi

    resolved_release_path="$(realpath -e -- "$release_path")" ||
        fail "release '$release_id' cannot be resolved."

    if [[ "$resolved_release_path" != "$releases_directory/$release_id" ]]; then
        fail "release '$release_id' is not a direct child of the releases directory."
    fi

    if [[ "$require_complete_release" == 'yes' ]] &&
       { [[ ! -f "$release_path/backend/public/index.php" ]] ||
         [[ ! -f "$release_path/vendor/autoload.php" ]]; }; then
        fail "release '$release_id' is incomplete."
    fi
}

has_production_approval_marker() {
    local release_id=$1
    local approval_marker="$releases_directory/$release_id/.production-approved"

    if [[ -L "$approval_marker" ]] ||
       { [[ -e "$approval_marker" ]] && [[ ! -f "$approval_marker" ]]; }; then
        fail "release '$release_id' has an inconsistent production approval marker."
    fi

    [[ -f "$approval_marker" ]]
}

require_production_approval() {
    local release_id=$1

    if ! has_production_approval_marker "$release_id"; then
        fail "release '$release_id' is not approved for production rollback."
    fi
}

resolve_active_release_id() {
    local current_link="$deployment_root/current"
    local resolved_active_release
    local active_release_id

    if [[ ! -L "$current_link" ]]; then
        if [[ -e "$current_link" ]]; then
            fail 'the active release path is not a symbolic link.'
        fi

        printf '%s\n' '--none'
        return
    fi

    resolved_active_release="$(realpath -e -- "$current_link")" ||
        fail 'the active release symbolic link is broken.'
    active_release_id="$(basename -- "$resolved_active_release")"
    validate_release_id "$active_release_id"

    if [[ "$resolved_active_release" != "$releases_directory/$active_release_id" ]]; then
        fail 'the active release resolves outside the releases directory.'
    fi

    validate_release_directory "$active_release_id" yes
    printf '%s\n' "$active_release_id"
}

capture_active_release_id() {
    local active_release_id
    local first_release_entry

    active_release_id="$(resolve_active_release_id)"

    if [[ "$active_release_id" == '--none' ]]; then
        first_release_entry="$(
            find -P "$releases_directory" -mindepth 1 -maxdepth 1 -print -quit
        )"

        if [[ -n "$first_release_entry" ]]; then
            fail 'the active release symbolic link is missing from a non-empty release tree.'
        fi
    fi

    printf '%s\n' "$active_release_id"
}

release_tree_size_kib() {
    local size_kib

    size_kib="$(du -sk -- "$releases_directory" | awk '{print $1}')"
    [[ "$size_kib" =~ ^[0-9]+$ ]] || fail 'release-tree disk use could not be measured.'
    printf '%s\n' "$size_kib"
}

pending_release_exists() {
    [[ -e "$pending_release_file" || -L "$pending_release_file" ]]
}

read_pending_release() {
    local -a pending_release_lines=()

    if [[ -L "$pending_release_file" || ! -f "$pending_release_file" ]]; then
        require_manual_recovery 'the pending-candidate record is not a real file.'
    fi

    mapfile -t pending_release_lines < "$pending_release_file"

    if (( ${#pending_release_lines[@]} != 3 )) ||
       [[ "${pending_release_lines[0]}" != candidate=* ]] ||
       [[ "${pending_release_lines[1]}" != previous-active=* ]] ||
       [[ "${pending_release_lines[2]}" != state=* ]]; then
        require_manual_recovery 'the pending-candidate record is malformed.'
    fi

    pending_candidate_release_id=${pending_release_lines[0]#candidate=}
    pending_previous_active_release_id=${pending_release_lines[1]#previous-active=}
    pending_release_state=${pending_release_lines[2]#state=}

    validate_release_id "$pending_candidate_release_id"
    validate_optional_release_id "$pending_previous_active_release_id"

    case "$pending_release_state" in
        prepared|activation-started|recovery-pending-smoke)
            ;;
        *)
            require_manual_recovery 'the pending-candidate state is unsupported.'
            ;;
    esac

    if [[ "$pending_candidate_release_id" == "$pending_previous_active_release_id" ]]; then
        require_manual_recovery 'the pending candidate and previous active release are identical.'
    fi
}

inspect_pending_candidate() {
    local environment_policy=$3

    validate_deployment_tree "$1" "$2"
    validate_staging_policy "$environment_policy"

    if ! pending_release_exists; then
        printf '%s\n' 'Pending candidate: none'
        return
    fi

    read_pending_release
    printf 'Pending candidate: %s\n' "$pending_candidate_release_id"
    printf 'Previous active release: %s\n' "$pending_previous_active_release_id"
    printf 'Pending candidate state: %s\n' "$pending_release_state"
}

store_pending_release() {
    local candidate_release_id=$1
    local previous_active_release_id=$2
    local release_state=$3
    local temporary_pending_release_file="$deployment_root/.pending-release.$candidate_release_id.$$"

    validate_release_id "$candidate_release_id"
    validate_optional_release_id "$previous_active_release_id"

    if [[ -e "$temporary_pending_release_file" || -L "$temporary_pending_release_file" ]]; then
        fail 'the temporary pending-candidate record already exists.'
    fi

    if pending_release_exists &&
       [[ -L "$pending_release_file" || ! -f "$pending_release_file" ]]; then
        require_manual_recovery 'the pending-candidate record is not a real file.'
    fi

    (
        umask 077
        printf 'candidate=%s\nprevious-active=%s\nstate=%s\n' \
            "$candidate_release_id" \
            "$previous_active_release_id" \
            "$release_state" \
            > "$temporary_pending_release_file"
    )
    mv -Tf -- "$temporary_pending_release_file" "$pending_release_file"
}

require_pending_release() {
    local expected_candidate_release_id=$1
    local expected_previous_active_release_id=$2

    if ! pending_release_exists; then
        require_manual_recovery 'the pending-candidate record is missing.'
    fi

    read_pending_release

    if [[ "$pending_candidate_release_id" != "$expected_candidate_release_id" ]] ||
       [[ "$pending_previous_active_release_id" != "$expected_previous_active_release_id" ]]; then
        require_manual_recovery 'the pending-candidate record does not match the requested recovery state.'
    fi
}

require_expected_active_release() {
    local expected_active_release_id=$1
    local actual_active_release_id

    actual_active_release_id="$(resolve_active_release_id)"

    if [[ "$actual_active_release_id" != "$expected_active_release_id" ]]; then
        require_manual_recovery 'the active release does not match the expected recovery state.'
    fi

    if [[ "$expected_active_release_id" != '--none' ]]; then
        validate_release_directory "$expected_active_release_id" yes
    fi
}

prepare_candidate() {
    local candidate_release_id=$3
    local required_capacity_kib=$4
    local environment_policy=$5
    local candidate_path
    local active_release_id
    local available_capacity_kib

    validate_deployment_tree "$1" "$2"
    validate_release_id "$candidate_release_id"

    validate_environment_policy "$environment_policy"

    if [[ ! "$required_capacity_kib" =~ ^[1-9][0-9]*$ ]]; then
        fail 'required candidate capacity must be a positive KiB value.'
    fi

    if [[ "$environment_policy" == 'staging' ]] && pending_release_exists; then
        require_manual_recovery 'a previous staging candidate is still pending.'
    fi

    active_release_id="$(capture_active_release_id)"
    candidate_path="${releases_directory:?}/$candidate_release_id"

    if [[ -e "$candidate_path" || -L "$candidate_path" ]]; then
        fail "candidate release '$candidate_release_id' already exists."
    fi

    available_capacity_kib="$(df -Pk "$releases_directory" | awk 'NR == 2 {print $4}')"

    if [[ ! "$available_capacity_kib" =~ ^[0-9]+$ ]]; then
        fail 'available release capacity could not be measured.'
    fi

    if (( available_capacity_kib < required_capacity_kib )); then
        fail "candidate requires ${required_capacity_kib} KiB but only ${available_capacity_kib} KiB is available."
    fi

    if [[ "$environment_policy" == 'staging' ]]; then
        store_pending_release "$candidate_release_id" "$active_release_id" prepared
    fi

    if ! mkdir -- "$candidate_path"; then
        if [[ "$environment_policy" == 'staging' ]]; then
            rm -f -- "$pending_release_file"
        fi

        fail "candidate release '$candidate_release_id' could not be prepared."
    fi

    printf 'Active release: %s\n' "$active_release_id"
    printf 'Candidate capacity: %s KiB required, %s KiB available\n' \
        "$required_capacity_kib" \
        "$available_capacity_kib"
    printf 'Prepared candidate release: %s\n' "$candidate_release_id"
}

mark_candidate_activation() {
    local candidate_release_id=$3
    local environment_policy=$4
    local actual_active_release_id

    validate_deployment_tree "$1" "$2"
    validate_staging_policy "$environment_policy"
    validate_release_id "$candidate_release_id"

    if ! pending_release_exists; then
        require_manual_recovery 'the pending-candidate record is missing.'
    fi

    read_pending_release

    if [[ "$pending_candidate_release_id" != "$candidate_release_id" ]]; then
        require_manual_recovery 'the pending-candidate record identifies another release.'
    fi

    if [[ "$pending_release_state" == 'recovery-pending-smoke' ]]; then
        require_manual_recovery 'the candidate is already awaiting recovery smoke verification.'
    fi

    validate_release_directory "$candidate_release_id" yes
    actual_active_release_id="$(resolve_active_release_id)"

    if [[ "$actual_active_release_id" != "$pending_previous_active_release_id" ]]; then
        require_manual_recovery 'the active release changed before candidate activation.'
    fi

    store_pending_release \
        "$candidate_release_id" \
        "$pending_previous_active_release_id" \
        activation-started
    printf 'Candidate activation recorded: %s\n' "$candidate_release_id"
}

retain_release_pair() {
    local expected_active_release_id=$3
    local expected_rollback_release_id=$4
    local environment_policy=$5
    local actual_active_release_id
    local release_path
    local release_id
    local before_size_kib
    local after_size_kib
    local removed_release_report='none'
    local has_pending_release='no'
    local -a obsolete_release_ids=()

    validate_deployment_tree "$1" "$2"
    validate_environment_policy "$environment_policy"
    validate_release_id "$expected_active_release_id"
    validate_optional_release_id "$expected_rollback_release_id"

    if [[ "$expected_rollback_release_id" == "$expected_active_release_id" ]]; then
        fail 'the active and rollback releases must be different.'
    fi

    actual_active_release_id="$(capture_active_release_id)"

    if [[ "$actual_active_release_id" != "$expected_active_release_id" ]]; then
        fail 'the active release changed unexpectedly.'
    fi

    validate_release_directory "$expected_active_release_id" yes

    if [[ "$expected_rollback_release_id" != '--none' ]]; then
        validate_release_directory "$expected_rollback_release_id" yes
    fi

    if [[ "$environment_policy" == 'production' ]]; then
        require_production_approval "$expected_active_release_id"

        if [[ "$expected_rollback_release_id" != '--none' ]]; then
            require_production_approval "$expected_rollback_release_id"
        fi
    fi

    if pending_release_exists; then
        require_pending_release "$expected_active_release_id" "$expected_rollback_release_id"

        if [[ "$pending_release_state" != 'activation-started' ]]; then
            require_manual_recovery 'the candidate was not recorded as activated.'
        fi

        has_pending_release='yes'
    fi

    # Include dot-prefixed entries without relying on /dev/fd process substitution.
    for release_path in \
        "$releases_directory"/* \
        "$releases_directory"/.[!.]* \
        "$releases_directory"/..?*; do
        if [[ ! -e "$release_path" && ! -L "$release_path" ]]; then
            continue
        fi

        release_id="$(basename -- "$release_path")"
        validate_release_directory "$release_id" no

        if [[ "$release_id" != "$expected_active_release_id" &&
              "$release_id" != "$expected_rollback_release_id" ]]; then
            obsolete_release_ids+=("$release_id")
        fi
    done

    if [[ "$environment_policy" == 'staging' &&
          "$has_pending_release" == 'no' ]] &&
       (( ${#obsolete_release_ids[@]} > 0 )); then
        require_manual_recovery 'release pruning has no matching pending-candidate record.'
    fi

    before_size_kib="$(release_tree_size_kib)"

    if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
        fail 'the active release changed before cleanup.'
    fi

    for release_id in "${obsolete_release_ids[@]}"; do
        if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
            fail 'the active release changed during cleanup.'
        fi

        validate_release_directory "$release_id" no
        rm -rf -- "${releases_directory:?}/$release_id"
    done

    if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
        fail 'the active release changed during cleanup.'
    fi

    if [[ "$has_pending_release" == 'yes' ]]; then
        require_pending_release "$expected_active_release_id" "$expected_rollback_release_id"
        rm -f -- "$pending_release_file"
    fi

    after_size_kib="$(release_tree_size_kib)"

    if (( ${#obsolete_release_ids[@]} > 0 )); then
        removed_release_report="$(IFS=,; printf '%s' "${obsolete_release_ids[*]}")"
    fi

    printf 'Active release: %s\n' "$expected_active_release_id"

    if [[ "$expected_rollback_release_id" == '--none' ]]; then
        printf '%s\n' 'Rollback release: none'
    else
        printf 'Rollback release: %s\n' "$expected_rollback_release_id"
    fi

    printf 'Removed releases: %s\n' "$removed_release_report"
    printf 'Release tree before cleanup: %s KiB\n' "$before_size_kib"
    printf 'Release tree after cleanup: %s KiB\n' "$after_size_kib"
}

retain_after_production_rollback() {
    local expected_active_release_id=$3
    local deactivated_release_id=$4
    local actual_active_release_id
    local release_path
    local release_id
    local rollback_release_id='--none'
    local before_size_kib
    local after_size_kib
    local removed_release_report='none'

    validate_deployment_tree "$1" "$2"
    validate_release_id "$expected_active_release_id"
    validate_release_id "$deactivated_release_id"

    if [[ "$expected_active_release_id" == "$deactivated_release_id" ]]; then
        fail 'the active and deactivated releases must be different.'
    fi

    actual_active_release_id="$(capture_active_release_id)"

    if [[ "$actual_active_release_id" != "$expected_active_release_id" ]]; then
        fail 'the active production rollback release changed unexpectedly.'
    fi

    validate_release_directory "$expected_active_release_id" yes
    require_production_approval "$expected_active_release_id"

    if [[ -e "$releases_directory/$deactivated_release_id" ||
          -L "$releases_directory/$deactivated_release_id" ]]; then
        validate_release_directory "$deactivated_release_id" yes

        if has_production_approval_marker "$deactivated_release_id"; then
            retain_release_pair \
                "$1" \
                "$2" \
                "$expected_active_release_id" \
                "$deactivated_release_id" \
                production
            return
        fi
    fi

    # Include dot-prefixed entries without relying on /dev/fd process substitution.
    for release_path in \
        "$releases_directory"/* \
        "$releases_directory"/.[!.]* \
        "$releases_directory"/..?*; do
        if [[ ! -e "$release_path" && ! -L "$release_path" ]]; then
            continue
        fi

        release_id="$(basename -- "$release_path")"
        validate_release_directory "$release_id" no

        if [[ "$release_id" == "$expected_active_release_id" ||
              "$release_id" == "$deactivated_release_id" ]]; then
            continue
        fi

        validate_release_directory "$release_id" yes
        require_production_approval "$release_id"

        if [[ "$rollback_release_id" != '--none' ]]; then
            require_manual_recovery 'the production rollback state contains more than one possible retained predecessor.'
        fi

        rollback_release_id=$release_id
    done

    before_size_kib="$(release_tree_size_kib)"

    if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
        fail 'the active production rollback release changed before cleanup.'
    fi

    if [[ -e "$releases_directory/$deactivated_release_id" ||
          -L "$releases_directory/$deactivated_release_id" ]]; then
        validate_release_directory "$deactivated_release_id" yes

        if has_production_approval_marker "$deactivated_release_id"; then
            require_manual_recovery 'the deactivated production release approval state changed before cleanup.'
        fi

        if [[ "$rollback_release_id" != '--none' ]]; then
            validate_release_directory "$rollback_release_id" yes
            require_production_approval "$rollback_release_id"
        fi

        if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
            fail 'the active production rollback release changed during cleanup.'
        fi

        rm -rf -- "${releases_directory:?}/$deactivated_release_id"
        removed_release_report=$deactivated_release_id
    fi

    if [[ "$(capture_active_release_id)" != "$expected_active_release_id" ]]; then
        fail 'the active production rollback release changed during cleanup.'
    fi

    after_size_kib="$(release_tree_size_kib)"

    printf 'Active release: %s\n' "$expected_active_release_id"

    if [[ "$rollback_release_id" == '--none' ]]; then
        printf '%s\n' 'Rollback release: none'
    else
        printf 'Rollback release: %s\n' "$rollback_release_id"
    fi

    printf 'Removed releases: %s\n' "$removed_release_report"
    printf 'Release tree before cleanup: %s KiB\n' "$before_size_kib"
    printf 'Release tree after cleanup: %s KiB\n' "$after_size_kib"
}

recover_failed_candidate() {
    local candidate_release_id=$3
    local previous_active_release_id=$4
    local environment_policy=$5
    local actual_active_release_id
    local temporary_link
    local smoke_verification_required='no'

    validate_deployment_tree "$1" "$2"
    validate_staging_policy "$environment_policy"
    validate_release_id "$candidate_release_id"
    validate_optional_release_id "$previous_active_release_id"
    require_pending_release "$candidate_release_id" "$previous_active_release_id"

    if [[ -e "$releases_directory/$candidate_release_id" ||
          -L "$releases_directory/$candidate_release_id" ]]; then
        validate_release_directory "$candidate_release_id" no
    fi

    actual_active_release_id="$(resolve_active_release_id)"

    if [[ "$previous_active_release_id" == '--none' ]]; then
        if [[ "$actual_active_release_id" == "$candidate_release_id" ]]; then
            require_manual_recovery 'the failed first candidate is active and has no predecessor to restore.'
        fi

        if [[ "$actual_active_release_id" != '--none' ]]; then
            require_manual_recovery 'the active release does not match the first-deployment recovery state.'
        fi

        if [[ "$pending_release_state" != 'prepared' ]]; then
            require_manual_recovery 'candidate activation began without a predecessor to restore.'
        fi
    else
        validate_release_directory "$previous_active_release_id" no

        if [[ ! -f "$releases_directory/$previous_active_release_id/backend/public/index.php" ]] ||
           [[ ! -f "$releases_directory/$previous_active_release_id/vendor/autoload.php" ]]; then
            require_manual_recovery 'the captured predecessor is incomplete and cannot be restored.'
        fi

        if [[ "$actual_active_release_id" == "$candidate_release_id" ]]; then
            temporary_link="$deployment_root/.recovery-current-$candidate_release_id-$$"

            if [[ -e "$temporary_link" || -L "$temporary_link" ]]; then
                require_manual_recovery 'the temporary recovery link already exists.'
            fi

            if ! ln -s "$releases_directory/$previous_active_release_id" "$temporary_link"; then
                require_manual_recovery 'the temporary recovery link could not be created.'
            fi

            if ! mv -Tf -- "$temporary_link" "$deployment_root/current"; then
                rm -f -- "$temporary_link"
                require_manual_recovery 'the captured predecessor could not be activated atomically.'
            fi

            require_expected_active_release "$previous_active_release_id"
            smoke_verification_required='yes'
        elif [[ "$actual_active_release_id" == "$previous_active_release_id" ]]; then
            if [[ "$pending_release_state" != 'prepared' ]]; then
                smoke_verification_required='yes'
            fi
        else
            require_manual_recovery 'neither the failed candidate nor its captured predecessor is active.'
        fi
    fi

    if [[ "$smoke_verification_required" == 'yes' ]]; then
        store_pending_release \
            "$candidate_release_id" \
            "$previous_active_release_id" \
            recovery-pending-smoke
    fi

    printf 'Failed candidate: %s\n' "$candidate_release_id"
    printf 'Restored active release: %s\n' "$previous_active_release_id"
    printf 'Smoke verification required: %s\n' "$smoke_verification_required"
}

cleanup_failed_candidate() {
    local candidate_release_id=$3
    local previous_active_release_id=$4
    local recovery_verification=$5
    local environment_policy=$6
    local before_size_kib
    local after_size_kib
    local removed_release_report='none'

    validate_deployment_tree "$1" "$2"
    validate_staging_policy "$environment_policy"
    validate_release_id "$candidate_release_id"
    validate_optional_release_id "$previous_active_release_id"

    if [[ "$recovery_verification" != 'not-required' &&
          "$recovery_verification" != 'verified' ]]; then
        fail 'the recovery verification result is unsupported.'
    fi

    if ! pending_release_exists; then
        if [[ -e "$releases_directory/$candidate_release_id" ||
              -L "$releases_directory/$candidate_release_id" ]]; then
            require_manual_recovery 'the failed candidate exists without its pending-candidate record.'
        fi

        require_expected_active_release "$previous_active_release_id"
        printf 'Active release: %s\n' "$previous_active_release_id"
        printf 'Failed candidate: %s\n' "$candidate_release_id"
        printf '%s\n' 'Removed failed candidate: none'
        return
    fi

    require_pending_release "$candidate_release_id" "$previous_active_release_id"

    case "$pending_release_state" in
        prepared)
            if [[ "$recovery_verification" != 'not-required' ]]; then
                fail 'pre-activation cleanup must not claim a recovery smoke result.'
            fi
            ;;
        recovery-pending-smoke)
            if [[ "$recovery_verification" != 'verified' ]]; then
                require_manual_recovery 'the restored release has not passed its external smoke gate.'
            fi
            ;;
        activation-started)
            require_manual_recovery 'the candidate recovery step has not restored and classified the active release.'
            ;;
    esac

    require_expected_active_release "$previous_active_release_id"
    before_size_kib="$(release_tree_size_kib)"

    if [[ -e "$releases_directory/$candidate_release_id" ||
          -L "$releases_directory/$candidate_release_id" ]]; then
        validate_release_directory "$candidate_release_id" no
        require_expected_active_release "$previous_active_release_id"
        rm -rf -- "${releases_directory:?}/$candidate_release_id"
        removed_release_report=$candidate_release_id
    fi

    require_expected_active_release "$previous_active_release_id"
    require_pending_release "$candidate_release_id" "$previous_active_release_id"
    rm -f -- "$pending_release_file"
    after_size_kib="$(release_tree_size_kib)"

    printf 'Active release: %s\n' "$previous_active_release_id"
    printf 'Failed candidate: %s\n' "$candidate_release_id"
    printf 'Removed failed candidate: %s\n' "$removed_release_report"
    printf 'Release tree before cleanup: %s KiB\n' "$before_size_kib"
    printf 'Release tree after cleanup: %s KiB\n' "$after_size_kib"
}

deployment_root=''
releases_directory=''
pending_release_file=''
pending_candidate_release_id=''
pending_previous_active_release_id=''
pending_release_state=''

case "$operation" in
    inspect-pending)
        if (( $# != 4 )); then
            printf '%s\n' \
                'Usage: release-retention.sh inspect-pending DEPLOYMENT_ROOT ALLOWED_ROOT staging' \
                >&2
            exit 2
        fi

        inspect_pending_candidate "$2" "$3" "$4"
        ;;
    prepare)
        if (( $# != 6 )); then
            printf '%s\n' \
                'Usage: release-retention.sh prepare DEPLOYMENT_ROOT ALLOWED_ROOT CANDIDATE_ID REQUIRED_KIB staging|production' \
                >&2
            exit 2
        fi

        prepare_candidate "$2" "$3" "$4" "$5" "$6"
        ;;
    mark-activation)
        if (( $# != 5 )); then
            printf '%s\n' \
                'Usage: release-retention.sh mark-activation DEPLOYMENT_ROOT ALLOWED_ROOT CANDIDATE_ID staging' \
                >&2
            exit 2
        fi

        mark_candidate_activation "$2" "$3" "$4" "$5"
        ;;
    retain)
        if (( $# != 6 )); then
            printf '%s\n' \
                'Usage: release-retention.sh retain DEPLOYMENT_ROOT ALLOWED_ROOT ACTIVE_ID ROLLBACK_ID|--none staging|production' \
                >&2
            exit 2
        fi

        retain_release_pair "$2" "$3" "$4" "$5" "$6"
        ;;
    retain-production-rollback)
        if (( $# != 5 )); then
            printf '%s\n' \
                'Usage: release-retention.sh retain-production-rollback DEPLOYMENT_ROOT ALLOWED_ROOT ACTIVE_ID DEACTIVATED_ID' \
                >&2
            exit 2
        fi

        retain_after_production_rollback "$2" "$3" "$4" "$5"
        ;;
    recover)
        if (( $# != 6 )); then
            printf '%s\n' \
                'Usage: release-retention.sh recover DEPLOYMENT_ROOT ALLOWED_ROOT CANDIDATE_ID PREVIOUS_ACTIVE_ID|--none staging' \
                >&2
            exit 2
        fi

        recover_failed_candidate "$2" "$3" "$4" "$5" "$6"
        ;;
    cleanup-failed)
        if (( $# != 7 )); then
            printf '%s\n' \
                'Usage: release-retention.sh cleanup-failed DEPLOYMENT_ROOT ALLOWED_ROOT CANDIDATE_ID PREVIOUS_ACTIVE_ID|--none not-required|verified staging' \
                >&2
            exit 2
        fi

        cleanup_failed_candidate "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    *)
        printf '%s\n' \
            'Usage: release-retention.sh inspect-pending|prepare|mark-activation|retain|retain-production-rollback|recover|cleanup-failed ...' \
            >&2
        exit 2
        ;;
esac
