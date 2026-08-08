#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
helper="${project_root}/packages/schweisos-calamares-config/schweisos-calamares-network-status"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -r -- "$tmp_dir"
}
trap cleanup EXIT

mock_bin="${tmp_dir}/bin"
state_dir="${tmp_dir}/state"
install -d -- "$mock_bin" "$state_dir"

cat >"${mock_bin}/ip" <<'EOF'
#!/usr/bin/bash
case "${SCHWEISOS_TEST_ROUTE:-no}" in
  yes) exit 0 ;;
  no) exit 1 ;;
  *) exit 2 ;;
esac
EOF

cat >"${mock_bin}/nmcli" <<'EOF'
#!/usr/bin/bash
if [[ "$*" == "-t -f CONNECTIVITY general" ]]; then
  printf '%s\n' "${SCHWEISOS_TEST_NMCLI:-none}"
  exit 0
fi
exit 2
EOF

cat >"${mock_bin}/curl" <<'EOF'
#!/usr/bin/bash
case "${SCHWEISOS_TEST_CURL:-fail}" in
  success) exit 0 ;;
  fail) exit 22 ;;
  *) exit 2 ;;
esac
EOF

chmod 0755 -- "${mock_bin}/ip" "${mock_bin}/nmcli" "${mock_bin}/curl"

run_case() {
  local name=$1
  local route=$2
  local nm_state=$3
  local curl_state=$4
  local expected_state=$5
  local expected_reason=$6
  local expected_source=${7:-}

  rm -f -- "${state_dir}/network-state"
  PATH="${mock_bin}:/usr/bin:/bin" \
  SCHWEISOS_INSTALLER_STATE_DIR="$state_dir" \
  SCHWEISOS_TEST_ROUTE="$route" \
  SCHWEISOS_TEST_NMCLI="$nm_state" \
  SCHWEISOS_TEST_CURL="$curl_state" \
    bash "$helper"

  state_file="${state_dir}/network-state"
  [[ -f "$state_file" && ! -L "$state_file" ]] || \
    fail "${name}: state file was not created"
  grep -Fxq "STATE=${expected_state}" "$state_file" || \
    fail "${name}: unexpected network state"
  grep -Fxq "REASON=${expected_reason}" "$state_file" || \
    fail "${name}: unexpected network reason"
  grep -Fxq "SOURCE=${expected_source}" "$state_file" || \
    fail "${name}: unexpected network source"
  grep -Eq '^CHECKED_AT=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    "$state_file" || fail "${name}: timestamp is not canonical UTC"
}

run_case no_route no none fail offline no-route ''
run_case networkmanager_full yes full fail connected networkmanager-connectivity nmcli
run_case https_probe yes limited success connected https-probe https://schweisos.org/
run_case probe_failure yes limited fail offline https-probe-failed ''

if PATH="${mock_bin}:/usr/bin:/bin" SCHWEISOS_INSTALLER_STATE_DIR="$state_dir" \
    bash "$helper" --watch 0 >/dev/null 2>&1; then
  fail 'watch mode accepted an invalid zero duration'
fi

printf 'Installer network-status tests passed.\n'
