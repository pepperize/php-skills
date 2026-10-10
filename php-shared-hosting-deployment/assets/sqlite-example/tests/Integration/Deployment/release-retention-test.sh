#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly retention_script="$repository_root/deployment/release-retention.sh"
readonly recovery_wrapper_script="$repository_root/deployment/run-release-recovery.sh"
readonly production_control_script="$repository_root/deployment/production-release-control.sh"
readonly production_workflow="$repository_root/.github/workflows/deploy-production.yml"
readonly rollback_workflow="$repository_root/.github/workflows/rollback-production.yml"
readonly staging_workflow="$repository_root/.github/workflows/deploy-staging.yml"
readonly temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/release-retention-test.XXXXXX")"

assertion_count=0

cleanup() {
    rm -rf -- "$temporary_root"
}

trap cleanup EXIT

fail() {
    printf 'Release-retention integration test failed: %s\n' "$1" >&2
    exit 1
}

pass() {
    assertion_count=$((assertion_count + 1))
}

assert_exists() {
    [[ -e "$1" || -L "$1" ]] || fail "$2"
    pass
}

assert_not_exists() {
    [[ ! -e "$1" && ! -L "$1" ]] || fail "$2"
    pass
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "$3"
    pass
}

assert_not_contains() {
    [[ "$1" != *"$2"* ]] || fail "$3"
    pass
}

assert_equals() {
    [[ "$1" == "$2" ]] || fail "$3 (expected '$1', received '$2')"
    pass
}

expect_failure() {
    local description=$1
    shift

    if "$@" > "$temporary_root/expected-failure.out" 2>&1; then
        fail "$description"
    fi

    pass
}

create_environment() {
    mkdir -p "$1/releases"
}

create_release() {
    local deployment_root=$1
    local release_id=$2

    mkdir -p \
        "$deployment_root/releases/$release_id/public" \
        "$deployment_root/releases/$release_id/vendor"
    printf '<?php\n' > "$deployment_root/releases/$release_id/public/index.php"
    printf '<?php\n' > "$deployment_root/releases/$release_id/vendor/autoload.php"
    printf 'release=%s\n' "$release_id" > "$deployment_root/releases/$release_id/payload.txt"
}

mark_release_approved() {
    printf '%s\n' 'Post-deployment smoke checks passed.' \
        > "$1/releases/$2/.production-approved"
}

activate_release() {
    local deployment_root=$1
    local release_id=$2

    rm -f -- "$deployment_root/current"
    ln -s "releases/$release_id" "$deployment_root/current"
}

release_inventory() {
    find "$1/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort
}

first_root="$temporary_root/first"
create_environment "$first_root"
prepare_report="$(
    bash "$retention_script" prepare \
        "$first_root" "$first_root" candidate-first 1 staging
)"
assert_contains "$prepare_report" 'Active release: --none' \
    'first deployment must explicitly report that no predecessor exists'
assert_exists "$first_root/releases/candidate-first" \
    'capacity-approved first candidate was not prepared'

create_release "$first_root" candidate-first
bash "$retention_script" mark-activation \
    "$first_root" "$first_root" candidate-first staging \
    > "$temporary_root/first-activation.out"
activate_release "$first_root" candidate-first
first_report="$(
    bash "$retention_script" retain \
        "$first_root" "$first_root" candidate-first --none staging
)"
assert_equals 'candidate-first' "$(release_inventory "$first_root")" \
    'first deployment did not retain only its active release'
assert_contains "$first_report" 'Active release: candidate-first' \
    'first-deployment report omitted the active release'
assert_contains "$first_report" 'Rollback release: none' \
    'first-deployment report invented a rollback release'
assert_contains "$first_report" 'Removed releases: none' \
    'first-deployment report did not describe the empty removal set'
assert_contains "$first_report" 'Release tree before cleanup:' \
    'first-deployment report omitted the pre-cleanup size'
assert_contains "$first_report" 'Release tree after cleanup:' \
    'first-deployment report omitted the post-cleanup size'
assert_not_exists "$first_root/.pending-release" \
    'successful retention left the candidate marked as pending'

empty_pending_report="$(
    bash "$retention_script" inspect-pending \
        "$first_root" "$first_root" staging
)"
assert_contains "$empty_pending_report" 'Pending candidate: none' \
    'pending-candidate inspection invented recovery state'

expect_failure \
    'capacity preflight accepted an unavailable amount of space' \
    bash "$retention_script" prepare \
        "$first_root" "$first_root" impossible-candidate 9223372036854775807 staging
assert_not_exists "$first_root/releases/impossible-candidate" \
    'capacity failure prepared a candidate directory'

captured_root="$temporary_root/captured"
create_environment "$captured_root"
create_release "$captured_root" zzz-active
create_release "$captured_root" aaa-older
activate_release "$captured_root" zzz-active
captured_report="$(
    bash "$retention_script" prepare \
        "$captured_root" "$captured_root" middle-candidate 1 staging
)"
assert_contains "$captured_report" 'Active release: zzz-active' \
    'candidate preparation did not capture the resolved active identity explicitly'
assert_exists "$captured_root/releases/aaa-older" \
    'candidate preparation pruned an older release before smoke verification'
assert_exists "$captured_root/releases/zzz-active" \
    'candidate preparation removed the active predecessor'
assert_exists "$captured_root/releases/middle-candidate" \
    'candidate preparation did not allow three releases to coexist'
captured_pending_report="$(
    bash "$retention_script" inspect-pending \
        "$captured_root" "$captured_root" staging
)"
assert_contains "$captured_pending_report" 'Pending candidate: middle-candidate' \
    'pending-candidate inspection omitted the recorded candidate'
assert_contains "$captured_pending_report" 'Previous active release: zzz-active' \
    'pending-candidate inspection omitted the recorded predecessor'
assert_contains "$captured_pending_report" 'Pending candidate state: prepared' \
    'pending-candidate inspection omitted the recorded state'

second_root="$temporary_root/second"
create_environment "$second_root"
create_release "$second_root" release-one
activate_release "$second_root" release-one
bash "$retention_script" prepare \
    "$second_root" "$second_root" release-two 1 staging \
    > "$temporary_root/second-prepare.out"
create_release "$second_root" release-two
bash "$retention_script" mark-activation \
    "$second_root" "$second_root" release-two staging \
    > "$temporary_root/second-activation.out"
activate_release "$second_root" release-two
bash "$retention_script" retain \
    "$second_root" "$second_root" release-two release-one staging \
    > "$temporary_root/second-report.out"
assert_equals $'release-one\nrelease-two' "$(release_inventory "$second_root")" \
    'second deployment did not retain the candidate and captured predecessor'

rolling_root="$temporary_root/rolling"
create_environment "$rolling_root"
create_release "$rolling_root" aaa-obsolete
create_release "$rolling_root" zzz-former-active
touch -t 202001010000 "$rolling_root/releases/zzz-former-active"
touch -t 203001010000 "$rolling_root/releases/aaa-obsolete"
activate_release "$rolling_root" zzz-former-active
bash "$retention_script" prepare \
    "$rolling_root" "$rolling_root" middle-candidate 1 staging \
    > "$temporary_root/later-prepare.out"
create_release "$rolling_root" middle-candidate
create_release "$rolling_root" release-one
create_release "$rolling_root" release-two
bash "$retention_script" mark-activation \
    "$rolling_root" "$rolling_root" middle-candidate staging \
    > "$temporary_root/later-activation.out"
activate_release "$rolling_root" middle-candidate
later_report="$(
    bash "$retention_script" retain \
        "$rolling_root" "$rolling_root" middle-candidate zzz-former-active staging
)"
assert_equals $'middle-candidate\nzzz-former-active' "$(release_inventory "$rolling_root")" \
    'later deployment selected retained releases by ordering instead of explicit identity'
assert_contains "$later_report" 'Active release: middle-candidate' \
    'later-deployment report omitted the active release'
assert_contains "$later_report" 'Rollback release: zzz-former-active' \
    'later-deployment report omitted the captured predecessor'
assert_contains "$later_report" 'aaa-obsolete' \
    'later-deployment report omitted an obsolete release'
assert_contains "$later_report" 'release-one' \
    'later-deployment report omitted an extra obsolete release'
assert_contains "$later_report" 'release-two' \
    'later-deployment report omitted the former active release that became obsolete'

inventory_before_retry="$(release_inventory "$rolling_root")"
retry_report="$(
    bash "$retention_script" retain \
        "$rolling_root" "$rolling_root" middle-candidate zzz-former-active staging
)"
assert_equals "$inventory_before_retry" "$(release_inventory "$rolling_root")" \
    'repeated retention changed the retained pair'
assert_contains "$retry_report" 'Removed releases: none' \
    'idempotent retry reported a removal'

preparation_failure_root="$temporary_root/preparation-failure"
create_environment "$preparation_failure_root"
create_release "$preparation_failure_root" preparation-active
create_release "$preparation_failure_root" preparation-rollback
activate_release "$preparation_failure_root" preparation-active
bash "$retention_script" prepare \
    "$preparation_failure_root" \
    "$preparation_failure_root" \
    incomplete-upload \
    1 \
    staging \
    > "$temporary_root/preparation-failure.out"
assert_equals $'incomplete-upload\npreparation-active\npreparation-rollback' \
    "$(release_inventory "$preparation_failure_root")" \
    'candidate preparation displaced the previously successful pair'
expect_failure 'failed-candidate cleanup accepted the wrong release identity' \
    bash "$retention_script" cleanup-failed \
        "$preparation_failure_root" \
        "$preparation_failure_root" \
        another-candidate \
        preparation-active \
        not-required \
        staging
assert_exists "$preparation_failure_root/releases/incomplete-upload" \
    'mismatched candidate cleanup removed the recorded candidate'
expect_failure 'failed-candidate cleanup accepted a path outside releases' \
    bash "$retention_script" cleanup-failed \
        "$preparation_failure_root" \
        "$preparation_failure_root" \
        ../incomplete-upload \
        preparation-active \
        not-required \
        staging
assert_exists "$preparation_failure_root/releases/preparation-active" \
    'unsafe failed-candidate input removed the captured predecessor'
preparation_recovery_report="$(
    bash "$retention_script" recover \
        "$preparation_failure_root" \
        "$preparation_failure_root" \
        incomplete-upload \
        preparation-active \
        staging
)"
assert_contains "$preparation_recovery_report" 'Smoke verification required: no' \
    'pre-activation failure unexpectedly required restoration smoke verification'
bash "$retention_script" cleanup-failed \
    "$preparation_failure_root" \
    "$preparation_failure_root" \
    incomplete-upload \
    preparation-active \
    not-required \
    staging \
    > "$temporary_root/preparation-cleanup.out"
assert_equals $'preparation-active\npreparation-rollback' \
    "$(release_inventory "$preparation_failure_root")" \
    'preparation failure cleanup did not preserve the original release pair'
assert_not_exists "$preparation_failure_root/.pending-release" \
    'preparation failure cleanup left the candidate pending'

extraction_failure_root="$temporary_root/extraction-failure"
create_environment "$extraction_failure_root"
create_release "$extraction_failure_root" extraction-active
create_release "$extraction_failure_root" extraction-rollback
activate_release "$extraction_failure_root" extraction-active
bash "$retention_script" prepare \
    "$extraction_failure_root" \
    "$extraction_failure_root" \
    partial-extraction \
    1 \
    staging \
    > "$temporary_root/extraction-prepare.out"
mkdir "$extraction_failure_root/releases/partial-extraction/public"
printf '%s\n' 'partial archive contents' \
    > "$extraction_failure_root/releases/partial-extraction/public/index.php"
bash "$retention_script" recover \
    "$extraction_failure_root" \
    "$extraction_failure_root" \
    partial-extraction \
    extraction-active \
    staging \
    > "$temporary_root/extraction-recovery.out"
bash "$retention_script" cleanup-failed \
    "$extraction_failure_root" \
    "$extraction_failure_root" \
    partial-extraction \
    extraction-active \
    not-required \
    staging \
    > "$temporary_root/extraction-cleanup.out"
assert_equals $'extraction-active\nextraction-rollback' \
    "$(release_inventory "$extraction_failure_root")" \
    'partial extraction cleanup did not preserve the original release pair'

symbolic_candidate_root="$temporary_root/symbolic-failed-candidate"
create_environment "$symbolic_candidate_root"
create_release "$symbolic_candidate_root" symbolic-active
create_release "$symbolic_candidate_root" symbolic-rollback
activate_release "$symbolic_candidate_root" symbolic-active
bash "$retention_script" prepare \
    "$symbolic_candidate_root" \
    "$symbolic_candidate_root" \
    symbolic-candidate \
    1 \
    staging \
    > "$temporary_root/symbolic-candidate-prepare.out"
rm -rf -- "$symbolic_candidate_root/releases/symbolic-candidate"
symbolic_candidate_target="$temporary_root/symbolic-candidate-target"
mkdir "$symbolic_candidate_target"
printf '%s\n' 'outside release tree' > "$symbolic_candidate_target/evidence.txt"
ln -s "$symbolic_candidate_target" \
    "$symbolic_candidate_root/releases/symbolic-candidate"
expect_failure 'failed-candidate cleanup accepted a symbolic release directory' \
    bash "$retention_script" cleanup-failed \
        "$symbolic_candidate_root" \
        "$symbolic_candidate_root" \
        symbolic-candidate \
        symbolic-active \
        not-required \
        staging
assert_exists "$symbolic_candidate_target/evidence.txt" \
    'failed-candidate cleanup followed a symbolic release directory'
assert_exists "$symbolic_candidate_root/releases/symbolic-active" \
    'unsafe candidate cleanup removed the active release'
assert_exists "$symbolic_candidate_root/releases/symbolic-rollback" \
    'unsafe candidate cleanup removed the retained rollback release'

smoke_failure_root="$temporary_root/smoke-failure"
create_environment "$smoke_failure_root"
create_release "$smoke_failure_root" restored-active
create_release "$smoke_failure_root" retained-rollback
activate_release "$smoke_failure_root" restored-active
bash "$retention_script" prepare \
    "$smoke_failure_root" "$smoke_failure_root" failed-candidate 1 staging \
    > "$temporary_root/smoke-prepare.out"
create_release "$smoke_failure_root" failed-candidate
bash "$retention_script" mark-activation \
    "$smoke_failure_root" "$smoke_failure_root" failed-candidate staging \
    > "$temporary_root/smoke-activation.out"
activate_release "$smoke_failure_root" failed-candidate
expect_failure 'cleanup removed a candidate that was still active' \
    bash "$retention_script" cleanup-failed \
        "$smoke_failure_root" \
        "$smoke_failure_root" \
        failed-candidate \
        restored-active \
        not-required \
        staging
assert_exists "$smoke_failure_root/releases/failed-candidate" \
    'active failed candidate was removed before restoration'
expect_failure 'a later candidate replaced unresolved failed-candidate state' \
    bash "$retention_script" prepare \
        "$smoke_failure_root" "$smoke_failure_root" later-candidate 1 staging
assert_not_exists "$smoke_failure_root/releases/later-candidate" \
    'an unresolved failed candidate was selected as a later predecessor'
smoke_recovery_report="$(
    bash "$retention_script" recover \
        "$smoke_failure_root" \
        "$smoke_failure_root" \
        failed-candidate \
        restored-active \
        staging
)"
assert_equals "$smoke_failure_root/releases/restored-active" \
    "$(readlink -f "$smoke_failure_root/current")" \
    'post-activation recovery did not atomically restore the captured predecessor'
assert_contains "$smoke_recovery_report" 'Smoke verification required: yes' \
    'post-activation recovery did not require the normal external smoke gate'
assert_equals $'failed-candidate\nrestored-active\nretained-rollback' \
    "$(release_inventory "$smoke_failure_root")" \
    'recovery pruned a release before restored smoke verification'
expect_failure 'cleanup accepted an unverified restored release' \
    bash "$retention_script" cleanup-failed \
        "$smoke_failure_root" \
        "$smoke_failure_root" \
        failed-candidate \
        restored-active \
        not-required \
        staging
assert_equals $'failed-candidate\nrestored-active\nretained-rollback' \
    "$(release_inventory "$smoke_failure_root")" \
    'failed recovery verification pruned an available release'
bash "$retention_script" cleanup-failed \
    "$smoke_failure_root" \
    "$smoke_failure_root" \
    failed-candidate \
    restored-active \
    verified \
    staging \
    > "$temporary_root/smoke-cleanup.out"
assert_equals $'restored-active\nretained-rollback' \
    "$(release_inventory "$smoke_failure_root")" \
    'verified recovery did not restore the original successful pair'
retry_cleanup_report="$(
    bash "$retention_script" cleanup-failed \
        "$smoke_failure_root" \
        "$smoke_failure_root" \
        failed-candidate \
        restored-active \
        verified \
        staging
)"
assert_contains "$retry_cleanup_report" 'Removed failed candidate: none' \
    'idempotent recovery cleanup reported another removal'

restoration_failure_root="$temporary_root/restoration-failure"
create_environment "$restoration_failure_root"
create_release "$restoration_failure_root" unavailable-predecessor
create_release "$restoration_failure_root" preserved-rollback
activate_release "$restoration_failure_root" unavailable-predecessor
bash "$retention_script" prepare \
    "$restoration_failure_root" \
    "$restoration_failure_root" \
    active-failed-candidate \
    1 \
    staging \
    > "$temporary_root/restoration-prepare.out"
create_release "$restoration_failure_root" active-failed-candidate
bash "$retention_script" mark-activation \
    "$restoration_failure_root" \
    "$restoration_failure_root" \
    active-failed-candidate \
    staging \
    > "$temporary_root/restoration-activation.out"
activate_release "$restoration_failure_root" active-failed-candidate
rm "$restoration_failure_root/releases/unavailable-predecessor/vendor/autoload.php"
expect_failure 'recovery restored an incomplete predecessor' \
    bash "$retention_script" recover \
        "$restoration_failure_root" \
        "$restoration_failure_root" \
        active-failed-candidate \
        unavailable-predecessor \
        staging
assert_contains "$(< "$temporary_root/expected-failure.out")" \
    'Manual recovery required:' \
    'restoration failure did not identify the need for manual recovery'
assert_equals "$restoration_failure_root/releases/active-failed-candidate" \
    "$(readlink -f "$restoration_failure_root/current")" \
    'restoration failure changed the active symlink'
assert_equals $'active-failed-candidate\npreserved-rollback\nunavailable-predecessor' \
    "$(release_inventory "$restoration_failure_root")" \
    'restoration failure pruned an available release'

interrupted_cleanup_root="$temporary_root/interrupted-cleanup"
create_environment "$interrupted_cleanup_root"
create_release "$interrupted_cleanup_root" interrupted-active
create_release "$interrupted_cleanup_root" interrupted-rollback
activate_release "$interrupted_cleanup_root" interrupted-active
bash "$retention_script" prepare \
    "$interrupted_cleanup_root" \
    "$interrupted_cleanup_root" \
    interrupted-candidate \
    1 \
    staging \
    > "$temporary_root/interrupted-prepare.out"
rm -rf -- "$interrupted_cleanup_root/releases/interrupted-candidate"
bash "$retention_script" recover \
    "$interrupted_cleanup_root" \
    "$interrupted_cleanup_root" \
    interrupted-candidate \
    interrupted-active \
    staging \
    > "$temporary_root/interrupted-recovery.out"
bash "$retention_script" cleanup-failed \
    "$interrupted_cleanup_root" \
    "$interrupted_cleanup_root" \
    interrupted-candidate \
    interrupted-active \
    not-required \
    staging \
    > "$temporary_root/interrupted-cleanup.out"
assert_equals $'interrupted-active\ninterrupted-rollback' \
    "$(release_inventory "$interrupted_cleanup_root")" \
    'interrupted cleanup changed the original release pair'
assert_not_exists "$interrupted_cleanup_root/.pending-release" \
    'interrupted cleanup retry did not clear handled candidate state'

safety_root="$temporary_root/safety"
create_environment "$safety_root"
create_release "$safety_root" active
create_release "$safety_root" rollback
create_release "$safety_root" obsolete
activate_release "$safety_root" active

rm "$safety_root/current"
expect_failure 'retention accepted a missing active symlink' \
    bash "$retention_script" retain "$safety_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'missing active symlink allowed deletion'

ln -s releases/missing "$safety_root/current"
expect_failure 'retention accepted a broken active symlink' \
    bash "$retention_script" retain "$safety_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'broken active symlink allowed deletion'

external_environment="$temporary_root/external-environment"
create_environment "$external_environment"
create_release "$external_environment" external-active
external_active="$external_environment/releases/external-active"
rm "$safety_root/current"
ln -s "$external_active" "$safety_root/current"
expect_failure 'retention accepted an externally targeted active symlink' \
    bash "$retention_script" retain "$safety_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'external active symlink allowed deletion'

activate_release "$safety_root" active
expect_failure 'retention accepted an unexpectedly changed active identity' \
    bash "$retention_script" retain "$safety_root" "$safety_root" rollback active staging
assert_exists "$safety_root/releases/obsolete" \
    'unexpected active identity allowed deletion'

expect_failure 'retention accepted path traversal in an active release ID' \
    bash "$retention_script" retain "$safety_root" "$safety_root" ../active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'path-traversal input allowed deletion'

outside_release="$temporary_root/outside-release"
mkdir "$outside_release"
ln -s "$outside_release" "$safety_root/releases/symbolic-release"
expect_failure 'retention accepted a symbolic release directory' \
    bash "$retention_script" retain "$safety_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'symbolic release directory allowed another release to be deleted'
rm "$safety_root/releases/symbolic-release"

rm "$safety_root/releases/rollback/vendor/autoload.php"
expect_failure 'retention accepted an incomplete rollback release' \
    bash "$retention_script" retain "$safety_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'incomplete rollback validation allowed deletion'
printf '<?php\n' > "$safety_root/releases/rollback/vendor/autoload.php"

other_allowed_root="$temporary_root/other-environment"
create_environment "$other_allowed_root"
expect_failure 'retention accepted an external deployment root' \
    bash "$retention_script" retain \
        "$safety_root" "$other_allowed_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'external deployment root allowed deletion'

symbolic_root="$temporary_root/symbolic-root"
ln -s "$safety_root" "$symbolic_root"
expect_failure 'retention accepted a symbolic deployment root' \
    bash "$retention_script" retain "$symbolic_root" "$safety_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'symbolic deployment root allowed deletion'

symbolic_releases_root="$temporary_root/symbolic-releases-root"
mkdir "$symbolic_releases_root"
ln -s "$safety_root/releases" "$symbolic_releases_root/releases"
ln -s "$safety_root/releases/active" "$symbolic_releases_root/current"
expect_failure 'retention accepted a symbolic releases directory' \
    bash "$retention_script" retain \
        "$symbolic_releases_root" "$symbolic_releases_root" active rollback staging
assert_exists "$safety_root/releases/obsolete" \
    'symbolic releases directory allowed deletion'

isolation_root="$temporary_root/environments"
staging_root="$isolation_root/staging"
production_root="$isolation_root/production"
private_root="$isolation_root/private/staging"
create_environment "$staging_root"
create_environment "$production_root"
create_release "$staging_root" staging-rollback
create_release "$staging_root" staging-obsolete
create_release "$production_root" production-release
activate_release "$staging_root" staging-rollback
activate_release "$production_root" production-release
bash "$retention_script" prepare \
    "$production_root" "$production_root" production-candidate 1 production \
    > "$temporary_root/production-prepare.out"
assert_not_exists "$production_root/.pending-release" \
    'staging recovery state was applied to a production candidate'
bash "$retention_script" prepare \
    "$staging_root" "$staging_root" staging-active 1 staging \
    > "$temporary_root/isolation-prepare.out"
create_release "$staging_root" staging-active
bash "$retention_script" mark-activation \
    "$staging_root" "$staging_root" staging-active staging \
    > "$temporary_root/isolation-activation.out"
activate_release "$staging_root" staging-active
mkdir -p "$private_root/application" "$private_root/rate-limit/locks" "$private_root/log"
printf '%s\n' 'PRIVATE_SECRET=fixture-secret-value' > "$private_root/.env"
printf '%s\n' 'database-state' > "$private_root/application/application.sqlite"
printf '%s\n' 'rate-limit-state' > "$private_root/rate-limit/rate-limit.sqlite"
printf '%s\n' 'lock-state' > "$private_root/rate-limit/locks/request.lock"
printf '%s\n' 'log-state' > "$private_root/log/php-error.log"
private_state_before="$(find "$private_root" -type f -exec cksum {} \; | LC_ALL=C sort)"

external_target="$temporary_root/external-target.txt"
printf '%s\n' 'must survive' > "$external_target"
ln -s "$external_target" "$staging_root/releases/staging-obsolete/external-link"

isolation_report="$(
    bash "$retention_script" retain \
        "$staging_root" "$staging_root" staging-active staging-rollback staging
)"
assert_not_exists "$staging_root/releases/staging-obsolete" \
    'obsolete staging release was not removed'
assert_exists "$external_target" \
    'cleanup followed a symbolic link inside an obsolete release'
assert_exists "$production_root/releases/production-release" \
    'staging cleanup changed the production release tree'
assert_exists "$production_root/releases/production-candidate" \
    'staging cleanup removed a production candidate'
assert_equals "$private_state_before" \
    "$(find "$private_root" -type f -exec cksum {} \; | LC_ALL=C sort)" \
    'release cleanup changed persistent private state'
assert_not_contains "$isolation_report" 'fixture-secret-value' \
    'retention report exposed private contents'
assert_not_contains "$isolation_report" "$private_root" \
    'retention report exposed a private path'

production_first_root="$temporary_root/production-first"
create_environment "$production_first_root"
production_first_prepare_report="$(
    bash "$retention_script" prepare \
        "$production_first_root" \
        "$production_first_root" \
        production-first \
        1 \
        production
)"
assert_contains "$production_first_prepare_report" 'Active release: --none' \
    'first production deployment did not report the absent predecessor'
create_release "$production_first_root" production-first
activate_release "$production_first_root" production-first
bash "$production_control_script" approve \
    "$production_first_root" \
    "$production_first_root" \
    production-first \
    > "$temporary_root/production-first-approval.out"
assert_exists "$production_first_root/releases/production-first/.production-approved" \
    'production approval did not create the rollback marker'
production_first_report="$(
    bash "$retention_script" retain \
        "$production_first_root" \
        "$production_first_root" \
        production-first \
        --none \
        production
)"
assert_equals 'production-first' "$(release_inventory "$production_first_root")" \
    'first production deployment did not retain only the approved active release'
assert_contains "$production_first_report" 'Rollback release: none' \
    'first production retention invented a predecessor'

production_rolling_root="$temporary_root/production-rolling"
create_environment "$production_rolling_root"
create_release "$production_rolling_root" production-obsolete
create_release "$production_rolling_root" production-previous
mark_release_approved "$production_rolling_root" production-obsolete
mark_release_approved "$production_rolling_root" production-previous
activate_release "$production_rolling_root" production-previous
production_rolling_prepare_report="$(
    bash "$retention_script" prepare \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-candidate \
        1 \
        production
)"
assert_contains "$production_rolling_prepare_report" \
    'Active release: production-previous' \
    'production preparation did not capture the resolved predecessor'
assert_equals $'production-candidate\nproduction-obsolete\nproduction-previous' \
    "$(release_inventory "$production_rolling_root")" \
    'production preparation did not preserve both retained releases with the candidate'
create_release "$production_rolling_root" production-candidate
activate_release "$production_rolling_root" production-candidate
expect_failure 'production retention accepted an active candidate before approval' \
    bash "$retention_script" retain \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-candidate \
        production-previous \
        production
assert_exists "$production_rolling_root/releases/production-obsolete" \
    'missing candidate approval allowed an older production release to be deleted'
bash "$production_control_script" approve \
    "$production_rolling_root" \
    "$production_rolling_root" \
    production-candidate \
    > "$temporary_root/production-candidate-approval.out"
production_rolling_report="$(
    bash "$retention_script" retain \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-candidate \
        production-previous \
        production
)"
assert_equals $'production-candidate\nproduction-previous' \
    "$(release_inventory "$production_rolling_root")" \
    'successful production retention did not keep the approved rolling pair'
assert_contains "$production_rolling_report" \
    'Rollback release: production-previous' \
    'production retention report omitted the captured approved predecessor'
assert_contains "$production_rolling_report" \
    'Removed releases: production-obsolete' \
    'production retention report omitted the removed release'
production_inventory_before_retry="$(release_inventory "$production_rolling_root")"
production_retry_report="$(
    bash "$retention_script" retain \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-candidate \
        production-previous \
        production
)"
assert_equals "$production_inventory_before_retry" \
    "$(release_inventory "$production_rolling_root")" \
    'repeated production retention changed the approved pair'
assert_contains "$production_retry_report" 'Removed releases: none' \
    'repeated production retention reported another removal'

missing_approval_root="$temporary_root/production-missing-approval"
create_environment "$missing_approval_root"
create_release "$missing_approval_root" approved-active
create_release "$missing_approval_root" unapproved-rollback
create_release "$missing_approval_root" preserved-obsolete
mark_release_approved "$missing_approval_root" approved-active
activate_release "$missing_approval_root" approved-active
expect_failure 'production retention accepted an unapproved rollback release' \
    bash "$retention_script" retain \
        "$missing_approval_root" \
        "$missing_approval_root" \
        approved-active \
        unapproved-rollback \
        production
assert_exists "$missing_approval_root/releases/preserved-obsolete" \
    'missing rollback approval allowed production deletion'
ln -s ../payload.txt \
    "$missing_approval_root/releases/unapproved-rollback/.production-approved"
expect_failure 'production retention accepted an inconsistent approval marker' \
    bash "$retention_script" retain \
        "$missing_approval_root" \
        "$missing_approval_root" \
        approved-active \
        unapproved-rollback \
        production
assert_exists "$missing_approval_root/releases/preserved-obsolete" \
    'inconsistent approval state allowed production deletion'

failed_smoke_root="$temporary_root/production-failed-smoke"
create_environment "$failed_smoke_root"
create_release "$failed_smoke_root" approved-predecessor
create_release "$failed_smoke_root" approved-older
mark_release_approved "$failed_smoke_root" approved-predecessor
mark_release_approved "$failed_smoke_root" approved-older
activate_release "$failed_smoke_root" approved-predecessor
bash "$retention_script" prepare \
    "$failed_smoke_root" \
    "$failed_smoke_root" \
    failed-production-candidate \
    1 \
    production \
    > "$temporary_root/failed-production-prepare.out"
create_release "$failed_smoke_root" failed-production-candidate
activate_release "$failed_smoke_root" failed-production-candidate
assert_equals $'approved-older\napproved-predecessor\nfailed-production-candidate' \
    "$(release_inventory "$failed_smoke_root")" \
    'failed production smoke handling pruned a release before protected rollback'
production_rollback_report="$(
    bash "$production_control_script" rollback \
        "$failed_smoke_root" \
        "$failed_smoke_root" \
        approved-predecessor
)"
assert_contains "$production_rollback_report" \
    'Previous active release: failed-production-candidate' \
    'protected rollback did not report the deactivated failed candidate'
assert_equals "$failed_smoke_root/releases/approved-predecessor" \
    "$(readlink -f "$failed_smoke_root/current")" \
    'protected rollback did not activate the approved predecessor'
handled_failure_report="$(
    bash "$retention_script" retain-production-rollback \
        "$failed_smoke_root" \
        "$failed_smoke_root" \
        approved-predecessor \
        failed-production-candidate
)"
assert_equals $'approved-older\napproved-predecessor' \
    "$(release_inventory "$failed_smoke_root")" \
    'handled production failure did not restore the previously approved pair'
assert_contains "$handled_failure_report" \
    'Removed releases: failed-production-candidate' \
    'handled production failure did not report the removed candidate'
handled_failure_retry_report="$(
    bash "$retention_script" retain-production-rollback \
        "$failed_smoke_root" \
        "$failed_smoke_root" \
        approved-predecessor \
        failed-production-candidate
)"
assert_contains "$handled_failure_retry_report" 'Removed releases: none' \
    'handled production failure cleanup was not idempotent'

normal_rollback_report="$(
    bash "$production_control_script" rollback \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-previous
)"
assert_contains "$normal_rollback_report" \
    'Previous active release: production-candidate' \
    'explicit rollback did not capture the formerly active approved release'
bash "$retention_script" retain-production-rollback \
    "$production_rolling_root" \
    "$production_rolling_root" \
    production-previous \
    production-candidate \
    > "$temporary_root/normal-production-rollback-retention.out"
assert_equals $'production-candidate\nproduction-previous' \
    "$(release_inventory "$production_rolling_root")" \
    'successful explicit rollback did not retain the activated target and roll-forward release'
expect_failure 'protected rollback accepted an already active release' \
    bash "$production_control_script" rollback \
        "$production_rolling_root" \
        "$production_rolling_root" \
        production-previous

unapproved_target_root="$temporary_root/production-unapproved-target"
create_environment "$unapproved_target_root"
create_release "$unapproved_target_root" current-approved
create_release "$unapproved_target_root" target-unapproved
mark_release_approved "$unapproved_target_root" current-approved
activate_release "$unapproved_target_root" current-approved
expect_failure 'protected rollback accepted an unapproved target' \
    bash "$production_control_script" rollback \
        "$unapproved_target_root" \
        "$unapproved_target_root" \
        target-unapproved
assert_equals "$unapproved_target_root/releases/current-approved" \
    "$(readlink -f "$unapproved_target_root/current")" \
    'rejected unapproved rollback changed the active release'

ambiguous_recovery_root="$temporary_root/production-ambiguous-recovery"
create_environment "$ambiguous_recovery_root"
create_release "$ambiguous_recovery_root" recovered-active
create_release "$ambiguous_recovery_root" approved-option-one
create_release "$ambiguous_recovery_root" approved-option-two
create_release "$ambiguous_recovery_root" unresolved-candidate
mark_release_approved "$ambiguous_recovery_root" recovered-active
mark_release_approved "$ambiguous_recovery_root" approved-option-one
mark_release_approved "$ambiguous_recovery_root" approved-option-two
activate_release "$ambiguous_recovery_root" recovered-active
expect_failure 'ambiguous production recovery state allowed failed-candidate cleanup' \
    bash "$retention_script" retain-production-rollback \
        "$ambiguous_recovery_root" \
        "$ambiguous_recovery_root" \
        recovered-active \
        unresolved-candidate
assert_exists "$ambiguous_recovery_root/releases/unresolved-candidate" \
    'ambiguous production recovery state did not preserve the failed candidate'

production_isolation_root="$temporary_root/production-isolation"
production_cleanup_root="$production_isolation_root/production"
isolated_staging_root="$production_isolation_root/staging"
production_private_root="$production_isolation_root/private/production"
create_environment "$production_cleanup_root"
create_environment "$isolated_staging_root"
create_release "$production_cleanup_root" production-active
create_release "$production_cleanup_root" production-rollback
create_release "$production_cleanup_root" production-extra
create_release "$isolated_staging_root" staging-preserved
mark_release_approved "$production_cleanup_root" production-active
mark_release_approved "$production_cleanup_root" production-rollback
activate_release "$production_cleanup_root" production-active
activate_release "$isolated_staging_root" staging-preserved
mkdir -p \
    "$production_private_root/application" \
    "$production_private_root/rate-limit/locks" \
    "$production_private_root/log"
printf '%s\n' 'PRODUCTION_SECRET=private-value' > "$production_private_root/.env"
printf '%s\n' 'database-state' > "$production_private_root/application/application.sqlite"
printf '%s\n' 'rate-limit-state' > "$production_private_root/rate-limit/rate-limit.sqlite"
printf '%s\n' 'lock-state' > "$production_private_root/rate-limit/locks/request.lock"
printf '%s\n' 'log-state' > "$production_private_root/log/php-error.log"
production_private_state_before="$(
    find "$production_private_root" -type f -exec cksum {} \; | LC_ALL=C sort
)"
production_isolation_report="$(
    bash "$retention_script" retain \
        "$production_cleanup_root" \
        "$production_cleanup_root" \
        production-active \
        production-rollback \
        production
)"
assert_not_exists "$production_cleanup_root/releases/production-extra" \
    'production cleanup did not remove its obsolete release'
assert_exists "$isolated_staging_root/releases/staging-preserved" \
    'production cleanup changed the staging release tree'
assert_equals "$production_private_state_before" \
    "$(find "$production_private_root" -type f -exec cksum {} \; | LC_ALL=C sort)" \
    'production cleanup changed persistent private state'
assert_not_contains "$production_isolation_report" 'private-value' \
    'production retention report exposed private contents'
assert_not_contains "$production_isolation_report" "$production_private_root" \
    'production retention report exposed a private path'

sshpass() {
    while IFS= read -r ignored_line; do
        :
    done

    printf '%s\n' "$FAKE_RECOVERY_REPORT"
}
export -f sshpass

recovery_wrapper_environment=(
    DEPLOYMENT_NAME=staging
    DEPLOY_PATH=html/example.com/staging
    SSH_HOST=example.com
    'SSH_HOST_KEY=example.com ssh-ed25519 fixture'
    SSH_PASSWORD=fixture
    SSH_PORT=22
    SSH_USERNAME=fixture
    RUNNER_TEMP="$temporary_root/recovery-wrapper"
)

env "${recovery_wrapper_environment[@]}" \
    FAKE_RECOVERY_REPORT='Pending candidate: none' \
    GITHUB_OUTPUT="$temporary_root/no-pending-output" \
    bash "$recovery_wrapper_script" inspect \
    > "$temporary_root/no-pending-report"
assert_equals 'pending=false' "$(< "$temporary_root/no-pending-output")" \
    'release-recovery inspection did not report an empty journal'

env "${recovery_wrapper_environment[@]}" \
    FAKE_RECOVERY_REPORT=$'Pending candidate: failed-candidate\nPrevious active release: accepted-release\nPending candidate state: activation-started' \
    GITHUB_OUTPUT="$temporary_root/pending-output" \
    bash "$recovery_wrapper_script" inspect \
    > "$temporary_root/pending-report"
expected_pending_outputs=$'pending=true\nrelease_id=failed-candidate\nrollback_release_id=accepted-release\nstate=activation-started'
assert_equals "$expected_pending_outputs" "$(< "$temporary_root/pending-output")" \
    'release-recovery inspection did not expose the validated journal state'

unset -f sshpass

smoke_line="$(grep -n -F 'name: Run staging smoke test' "$staging_workflow" | cut -d: -f1)"
retention_line="$(grep -n -F 'name: Retain verified staging release pair' "$staging_workflow" | cut -d: -f1)"
recovery_line="$(grep -n -F 'name: Restore previous staging release after candidate failure' "$staging_workflow" | cut -d: -f1)"
recovery_smoke_line="$(grep -n -F 'name: Smoke-test restored staging release' "$staging_workflow" | cut -d: -f1)"
recovery_cleanup_line="$(grep -n -F 'name: Remove handled failed staging candidate' "$staging_workflow" | cut -d: -f1)"
[[ "$smoke_line" =~ ^[0-9]+$ &&
   "$retention_line" =~ ^[0-9]+$ &&
   "$recovery_line" =~ ^[0-9]+$ &&
   "$recovery_smoke_line" =~ ^[0-9]+$ &&
   "$recovery_cleanup_line" =~ ^[0-9]+$ ]] ||
    fail 'staging workflow is missing smoke, retention or recovery steps'
(( retention_line > smoke_line )) ||
    fail 'staging retention does not follow the complete smoke gate'
pass
(( recovery_smoke_line > recovery_line && recovery_cleanup_line > recovery_smoke_line )) ||
    fail 'staging recovery does not restore, verify and clean up in order'
pass
grep -q -F "steps.deploy.outputs.candidate_prepared == 'true'" "$staging_workflow" ||
    fail 'staging recovery is not limited to a prepared candidate'
grep -q -F "steps.recover.outputs.smoke_required == 'true'" "$staging_workflow" ||
    fail 'restored staging smoke verification is not gated by recovery state'
grep -q -F "steps.recovery_smoke.outcome == 'success'" "$staging_workflow" ||
    fail 'failed-candidate cleanup does not require successful recovery smoke verification'
pass
grep -q -F 'group: shared-hosting-account' "$staging_workflow" ||
    fail 'staging concurrency group was removed'
grep -q -F 'cancel-in-progress: false' "$staging_workflow" ||
    fail 'staging concurrency serialization was changed'
pass
stale_inspection_line="$(grep -n -F 'name: Inspect unfinished staging candidate' "$staging_workflow" | cut -d: -f1)"
stale_recovery_line="$(grep -n -F 'name: Restore unfinished staging candidate' "$staging_workflow" | cut -d: -f1)"
stale_smoke_line="$(grep -n -F 'name: Smoke-test restored release before deployment' "$staging_workflow" | cut -d: -f1)"
stale_cleanup_line="$(grep -n -F 'name: Remove handled unfinished staging candidate' "$staging_workflow" | cut -d: -f1)"
staging_deploy_line="$(grep -n -F 'name: Deploy release over SSH' "$staging_workflow" | cut -d: -f1)"
[[ "$stale_inspection_line" =~ ^[0-9]+$ &&
   "$stale_recovery_line" =~ ^[0-9]+$ &&
   "$stale_smoke_line" =~ ^[0-9]+$ &&
   "$stale_cleanup_line" =~ ^[0-9]+$ &&
   "$staging_deploy_line" =~ ^[0-9]+$ ]] ||
    fail 'staging workflow is missing unfinished-candidate recovery steps'
(( stale_recovery_line > stale_inspection_line &&
   stale_smoke_line > stale_recovery_line &&
   stale_cleanup_line > stale_smoke_line &&
   staging_deploy_line > stale_cleanup_line )) ||
    fail 'staging workflow does not resolve unfinished recovery before deployment'
pass
grep -q -F "steps.pending.outputs.pending == 'true'" "$staging_workflow" ||
    fail 'unfinished-candidate recovery is not gated by inspected remote state'
grep -q -F 'RELEASE_ID: ${{ steps.pending.outputs.release_id }}' "$staging_workflow" ||
    fail 'unfinished-candidate recovery does not use the inspected candidate identity'
grep -q -F 'ROLLBACK_RELEASE_ID: ${{ steps.pending.outputs.rollback_release_id }}' "$staging_workflow" ||
    fail 'unfinished-candidate recovery does not use the inspected predecessor identity'
pass
grep -q -F 'id: retention' "$staging_workflow" ||
    fail 'staging retention does not expose its outcome to candidate recovery'
grep -q -F "steps.retention.outcome == 'failure'" "$staging_workflow" ||
    fail 'staging recovery does not handle a failed retention step'
pass

production_deploy_line="$(grep -n -F 'name: Deploy approved release over SSH' "$production_workflow" | cut -d: -f1)"
production_smoke_line="$(grep -n -F 'name: Run production smoke test' "$production_workflow" | cut -d: -f1)"
production_approval_line="$(grep -n -F 'name: Mark release as approved for rollback' "$production_workflow" | cut -d: -f1)"
production_retention_line="$(grep -n -F 'name: Retain approved production release pair' "$production_workflow" | cut -d: -f1)"
[[ "$production_deploy_line" =~ ^[0-9]+$ &&
   "$production_smoke_line" =~ ^[0-9]+$ &&
   "$production_approval_line" =~ ^[0-9]+$ &&
   "$production_retention_line" =~ ^[0-9]+$ ]] ||
    fail 'production workflow is missing deployment, smoke, approval or retention steps'
(( production_smoke_line > production_deploy_line &&
   production_approval_line > production_smoke_line &&
   production_retention_line > production_approval_line )) ||
    fail 'production workflow does not deploy, smoke-test, approve and retain in order'
pass
grep -q -F 'group: shared-hosting-account' "$production_workflow" ||
    fail 'production deployment concurrency group was removed'
grep -q -F 'cancel-in-progress: false' "$production_workflow" ||
    fail 'production deployment concurrency serialization was changed'
pass

rollback_activation_line="$(grep -n -F 'name: Activate previously approved release' "$rollback_workflow" | cut -d: -f1)"
rollback_smoke_line="$(grep -n -F 'name: Run production smoke test' "$rollback_workflow" | cut -d: -f1)"
rollback_retention_line="$(grep -n -F 'name: Retain production release pair after rollback' "$rollback_workflow" | cut -d: -f1)"
[[ "$rollback_activation_line" =~ ^[0-9]+$ &&
   "$rollback_smoke_line" =~ ^[0-9]+$ &&
   "$rollback_retention_line" =~ ^[0-9]+$ ]] ||
    fail 'production rollback workflow is missing activation, smoke or retention steps'
(( rollback_smoke_line > rollback_activation_line &&
   rollback_retention_line > rollback_smoke_line )) ||
    fail 'production rollback workflow does not activate, smoke-test and retain in order'
pass
grep -q -F 'group: shared-hosting-account' "$rollback_workflow" ||
    fail 'production rollback concurrency group was removed'
grep -q -F 'cancel-in-progress: false' "$rollback_workflow" ||
    fail 'production rollback concurrency serialization was changed'
pass

if grep -q -E '[<>][(]' "$retention_script"; then
    fail 'remote release retention depends on unavailable /dev/fd process substitution'
fi
pass

bash -n \
    "$repository_root/deployment/deploy-release.sh" \
    "$repository_root/deployment/production-release-control.sh" \
    "$repository_root/deployment/release-control.sh" \
    "$repository_root/deployment/release-retention.sh" \
    "$repository_root/deployment/run-release-recovery.sh" \
    "$repository_root/deployment/run-release-retention.sh" \
    "$repository_root/tests/Integration/Deployment/release-retention-test.sh"
pass

printf 'Release-retention integration tests passed (%d assertions).\n' "$assertion_count"
