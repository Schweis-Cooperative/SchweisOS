#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Exercise the live Plymouth watchdog state machine with disposable command
# stubs. The runtime helper is copied verbatim except for its four absolute
# paths, so an early exit or fail-open branch in the real control flow fails.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'Plymouth watchdog behavior tests: FAIL (%s)\n' "$*" >&2
    exit 1
}

for tool in bash cat chmod cp grep mkdir mktemp rm sed timeout touch; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/.." && pwd -P)"
source_helper="${project_root}/iso/profiles/kde/airootfs/usr/lib/schweisos-live/plymouth-watchdog"
[[ -f "$source_helper" && ! -L "$source_helper" && -x "$source_helper" ]] || \
    fail 'runtime watchdog helper is missing or unsafe'
bash -n "$source_helper"

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

systemctl_stub="${tmp_dir}/systemctl"
sleep_stub="${tmp_dir}/sleep"
health_stub="${tmp_dir}/health"

cat >"$systemctl_stub" <<'EOF'
#!/usr/bin/bash
set -u
state_dir=${SCHWEISOS_WATCHDOG_TEST_STATE:?}
if [[ "${1-}" == show ]]; then
    if [[ -r "${state_dir}/show-exit" ]]; then
        IFS= read -r status <"${state_dir}/show-exit"
        exit "$status"
    fi
    IFS= read -r state <"${state_dir}/quit-state"
    IFS= read -r result <"${state_dir}/quit-result"
    IFS= read -r status <"${state_dir}/quit-status"
    printf 'ActiveState=%s\nResult=%s\nExecMainStatus=%s\n' \
        "$state" "$result" "$status"
    exit 0
fi
if [[ "${1-}" == --no-block && "${2-}" == start \
    && "${3-}" == schweisos-boot-debug-fallback.service ]]; then
    printf 'fallback\n' >>"${state_dir}/fallback.log"
    if [[ -r "${state_dir}/fallback-exit" ]]; then
        IFS= read -r status <"${state_dir}/fallback-exit"
        exit "$status"
    fi
    exit 0
fi
exit 64
EOF

cat >"$sleep_stub" <<'EOF'
#!/usr/bin/bash
set -u
state_dir=${SCHWEISOS_WATCHDOG_TEST_STATE:?}
count=0
if [[ -r "${state_dir}/sleep-count" ]]; then
    IFS= read -r count <"${state_dir}/sleep-count"
fi
(( count += 1 ))
printf '%s\n' "$count" >"${state_dir}/sleep-count"
if [[ "$count" -eq 1 && -r "${state_dir}/next-quit-state" ]]; then
    cp -- "${state_dir}/next-quit-state" "${state_dir}/quit-state"
fi
if [[ "$count" -eq 1 && -r "${state_dir}/next-quit-result" ]]; then
    cp -- "${state_dir}/next-quit-result" "${state_dir}/quit-result"
fi
if [[ "$count" -eq 1 && -r "${state_dir}/next-quit-status" ]]; then
    cp -- "${state_dir}/next-quit-status" "${state_dir}/quit-status"
fi
EOF

cat >"$health_stub" <<'EOF'
#!/usr/bin/bash
set -u
state_dir=${SCHWEISOS_WATCHDOG_TEST_STATE:?}
IFS= read -r mode <"${state_dir}/health-mode"
case "$mode" in
    stopped)
        exit 0
        ;;
    live-then-stopped)
        count=0
        if [[ -r "${state_dir}/health-count" ]]; then
            IFS= read -r count <"${state_dir}/health-count"
        fi
        (( count += 1 ))
        printf '%s\n' "$count" >"${state_dir}/health-count"
        (( count == 1 )) && exit 1
        exit 0
        ;;
    error)
        exit 7
        ;;
    *)
        exit 64
        ;;
esac
EOF

chmod 0755 -- "$systemctl_stub" "$sleep_stub" "$health_stub"

pass_count=0
case_root=''

prepare_case() {
    local name=$1
    case_root="${tmp_dir}/${name}"
    mkdir -- "$case_root"
    printf 'stopped\n' >"${case_root}/health-mode"
    printf 'inactive\n' >"${case_root}/quit-state"
    printf 'success\n' >"${case_root}/quit-result"
    printf '0\n' >"${case_root}/quit-status"
    sed \
        -e "s#^marker=.*#marker=${case_root}/normal-marker#" \
        -e "s#^health=.*#health=${health_stub}#" \
        -e "s#/usr/bin/systemctl#${systemctl_stub}#g" \
        -e "s#/usr/bin/sleep#${sleep_stub}#g" \
        "$source_helper" >"${case_root}/watchdog"
    chmod 0755 -- "${case_root}/watchdog"
    bash -n "${case_root}/watchdog"
}

expect_status() {
    local name=$1
    local expected=$2
    local status
    set +e
    SCHWEISOS_WATCHDOG_TEST_STATE="$case_root" \
        timeout 2s "${case_root}/watchdog" \
        >"${case_root}/stdout" 2>"${case_root}/stderr"
    status=$?
    set -e
    [[ "$status" -eq "$expected" ]] || \
        fail "${name}: expected status ${expected}, got ${status}"
    (( pass_count += 1 ))
    printf '[PASS] %s\n' "$name"
}

expect_fallback() {
    local name=$1
    [[ -f "${case_root}/fallback.log" ]] || \
        fail "${name}: diagnostic fallback was not requested"
    [[ "$(<"${case_root}/fallback.log")" == fallback ]] || \
        fail "${name}: diagnostic fallback was not requested exactly once"
}

expect_no_fallback() {
    local name=$1
    [[ ! -e "${case_root}/fallback.log" ]] || \
        fail "${name}: diagnostic fallback was requested unexpectedly"
}

prepare_case marker-inactive-success
touch "${case_root}/normal-marker"
expect_status 'completed normal handoff exits cleanly' 0
expect_no_fallback marker-inactive-success

prepare_case marker-activating
touch "${case_root}/normal-marker"
printf 'activating\n' >"${case_root}/quit-state"
printf 'inactive\n' >"${case_root}/next-quit-state"
printf 'success\n' >"${case_root}/next-quit-result"
printf '0\n' >"${case_root}/next-quit-status"
expect_status 'in-progress normal handoff waits for success' 0
expect_no_fallback marker-activating

prepare_case marker-failed
touch "${case_root}/normal-marker"
printf 'failed\n' >"${case_root}/quit-state"
printf 'exit-code\n' >"${case_root}/quit-result"
printf '1\n' >"${case_root}/quit-status"
expect_status 'failed normal handoff reveals diagnostics' 0
expect_fallback marker-failed

prepare_case marker-inactive-failed-result
touch "${case_root}/normal-marker"
printf 'inactive\n' >"${case_root}/quit-state"
printf 'exit-code\n' >"${case_root}/quit-result"
printf '1\n' >"${case_root}/quit-status"
expect_status 'inactive failed handoff reveals diagnostics' 0
expect_fallback marker-inactive-failed-result

prepare_case stopped-daemon
expect_status 'absent or stopped daemon reveals diagnostics' 0
expect_fallback stopped-daemon

prepare_case fallback-start-error
printf '19\n' >"${case_root}/fallback-exit"
expect_status 'diagnostic fallback request never marks watchdog failed' 0
expect_fallback fallback-start-error

prepare_case live-then-stopped
printf 'live-then-stopped\n' >"${case_root}/health-mode"
expect_status 'live daemon is tolerated until it stops' 0
expect_fallback live-then-stopped
[[ "$(<"${case_root}/health-count")" == 2 ]] || \
    fail 'live daemon scenario did not perform both health transitions'

prepare_case health-error
printf 'error\n' >"${case_root}/health-mode"
expect_status 'health helper error propagates to systemd' 7
expect_no_fallback health-error

prepare_case systemctl-error
touch "${case_root}/normal-marker"
printf '5\n' >"${case_root}/show-exit"
expect_status 'systemctl state-query error propagates to systemd' 5
expect_no_fallback systemctl-error

printf 'Plymouth watchdog behavior tests: PASS (%d checks)\n' "$pass_count"
