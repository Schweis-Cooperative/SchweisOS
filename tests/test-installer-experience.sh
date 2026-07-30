#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
launcher="${project_root}/packages/schweisos-calamares-config/schweisos-installer"
autostart="${project_root}/packages/schweisos-calamares-config/schweisos-installer-autostart"
live_session_helper="${project_root}/packages/schweisos-calamares-config/schweisos-installer-live-session"
test_root="$(mktemp -d)"
cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

export HOME="${test_root}/home"
export XDG_STATE_HOME="${test_root}/state"
mkdir -p -- "$HOME" "$XDG_STATE_HOME"

# Exercise the real live-session predicate independently of bootloader-specific
# paths. Archiso intentionally removes /run/archiso/bootmnt after copy-to-RAM,
# while /run/archiso/airootfs remains mounted for the live system.
source "$live_session_helper"
live_marker="${test_root}/live-session"
kernel_cmdline="${test_root}/cmdline"
printf 'SCHWEISOS_LIVE_SESSION=1\n' >"$live_marker"
printf 'quiet archisobasedir=schweis archisosearchuuid=test-marker\n' >"$kernel_cmdline"
current_user() {
  printf 'live\n'
}
live_marker_path() {
  printf '%s\n' "$live_marker"
}
kernel_cmdline_path() {
  printf '%s\n' "$kernel_cmdline"
}
mock_mountpoint_status=0
mountpoint_log="${test_root}/mountpoint-path"
mountpoint_is_mounted() {
  printf '%s\n' "$1" >"$mountpoint_log"
  return "$mock_mountpoint_status"
}

is_schweisos_live_session || \
  fail 'live-session predicate rejected a valid copy-to-RAM Archiso session'
[[ "$(<"$mountpoint_log")" == /run/archiso/airootfs ]] || \
  fail 'live-session predicate checked the wrong Archiso mountpoint'
[[ ! -e "${test_root}/bootmnt" ]] || \
  fail 'live-session test unexpectedly created a bootmnt dependency'

current_user() {
  printf 'installed-user\n'
}
if is_schweisos_live_session 2>/dev/null; then
  fail 'live-session predicate accepted a non-live user'
fi
current_user() {
  printf 'live\n'
}

mock_mountpoint_status=1
if is_schweisos_live_session 2>/dev/null; then
  fail 'live-session predicate accepted a missing Archiso airootfs mount'
fi
mock_mountpoint_status=0

printf 'quiet root=UUID=installed-system\n' >"$kernel_cmdline"
if is_schweisos_live_session 2>/dev/null; then
  fail 'live-session predicate accepted a non-Archiso kernel command line'
fi
printf 'quiet archisobasedir=schweis archisosearchuuid=test-marker\n' >"$kernel_cmdline"

printf 'SCHWEISOS_LIVE_SESSION=0\n' >"$live_marker"
if is_schweisos_live_session 2>/dev/null; then
  fail 'live-session predicate accepted an invalid live profile marker'
fi
printf 'SCHWEISOS_LIVE_SESSION=1\nUNEXPECTED=1\n' >"$live_marker"
if is_schweisos_live_session 2>/dev/null; then
  fail 'live-session predicate accepted extra marker content'
fi
printf 'SCHWEISOS_LIVE_SESSION=1\n' >"$live_marker"

# Exercise the real public launcher state machine while replacing only the
# live-environment preflight, privileged process, and desktop-dialog boundary.
source "$launcher"
is_live_session() {
  printf 'live-session check failed: test diagnostic\n' >&2
  return 1
}
preflight_error="$(preflight || true)"
[[ "$preflight_error" == *'live-session check failed: test diagnostic'* ]] || \
  fail 'launcher preflight did not preserve the live-session diagnostic'

launch_count=0
dialog_log="${test_root}/dialogs"
preflight() {
  return 0
}
invoke_privileged_installer() {
  launch_count=$((launch_count + 1))
  printf 'mock Calamares launch %d\n' "$launch_count"
  return 0
}
show_error() {
  printf 'error:%s\n' "$1" >>"$dialog_log"
}
show_already_running() {
  printf 'already-running\n' >>"$dialog_log"
}

main || fail 'manual launcher success path failed'
[[ "$launch_count" -eq 1 ]] || fail 'manual launcher did not invoke Calamares exactly once'
installer_state="$(state_directory)"
[[ -f "${installer_state}/launched" ]] || fail 'manual launcher did not create the launch marker'
[[ -s "${installer_state}/launch.log" ]] || fail 'manual launcher did not create a diagnostic log'
[[ "$(stat -c %a -- "$installer_state")" == 700 ]] || fail 'installer state directory is not mode 0700'
[[ "$(stat -c %a -- "${installer_state}/launch.log")" == 600 ]] || fail 'installer launch log is not private'

main || fail 'manual launcher could not be reopened'
[[ "$launch_count" -eq 2 ]] || fail 'manual reopening was blocked by the launch marker'

exec 8>"${installer_state}/launch.lock"
flock -n 8 || fail 'test could not acquire the installer lock'
main || fail 'concurrent launcher handling returned failure'
[[ "$launch_count" -eq 2 ]] || fail 'concurrent launcher started another Calamares process'
grep -Fxq 'already-running' "$dialog_log" || fail 'concurrent launcher did not report the existing window'
flock -u 8
exec 8>&-

invoke_privileged_installer() {
  printf 'mock privileged failure\n'
  return 23
}
set +e
main
privileged_status=$?
set -e
[[ "$privileged_status" -eq 23 ]] || fail 'privileged installer failure status was not preserved'
grep -Fq 'exited with an error' "$dialog_log" || \
  fail 'privileged installer failure was not shown to the user'
grep -Fq 'launcher failed with exit status 23' "${installer_state}/launch.log" || \
  fail 'privileged installer failure was not written to the diagnostic log'

preflight() {
  printf 'mock preflight failure'
  return 1
}
set +e
main
preflight_status=$?
set -e
[[ "$preflight_status" -eq 1 ]] || fail 'preflight failure did not stop the launcher'
grep -Fq 'mock preflight failure' "$dialog_log" || fail 'preflight failure was not shown to the user'

# Exercise first-session autostart separately so its function names and state
# can be replaced without changing production code.
(
  export XDG_STATE_HOME="${test_root}/autostart-state"
  source "$autostart"
  autostart_launches="${test_root}/autostart-launches"
  is_live_session() {
    return 0
  }
  wait_for_desktop() {
    printf 'waited\n' >>"${test_root}/autostart-events"
  }
  launch_installer() {
    printf 'launched\n' >>"$autostart_launches"
  }

  main || fail 'first live-session autostart failed'
  main || fail 'second live-session autostart returned failure'
  [[ "$(wc -l <"$autostart_launches")" -eq 1 ]] || \
    fail 'autostart did not remain once-only'
  [[ "$(wc -l <"${test_root}/autostart-events")" -eq 1 ]] || \
    fail 'second autostart repeated the desktop delay'
)

(
  export XDG_STATE_HOME="${test_root}/manual-before-autostart-state"
  source "$autostart"
  is_live_session() {
    return 0
  }
  wait_for_desktop() {
    local state
    state=$(state_directory)
    : >"${state}/launched"
  }
  launch_installer() {
    fail 'autostart relaunched after a manual launch during the delay'
  }

  main || fail 'manual-before-autostart state handling failed'
)

(
  export XDG_STATE_HOME="${test_root}/autostart-preflight-failure-state"
  source "$autostart"
  autostart_failure_log="${test_root}/autostart-failure"
  current_user() {
    printf 'live\n'
  }
  is_live_session() {
    printf 'live-session check failed: test autostart diagnostic\n' >&2
    return 1
  }
  report_autostart_failure() {
    printf '%s\n' "$1" >"$autostart_failure_log"
  }

  if main; then
    fail 'live-session contract failure returned autostart success'
  fi
  grep -Fq 'test autostart diagnostic' "$autostart_failure_log" || \
    fail 'autostart hid the live-session contract diagnostic'
)

(
  export XDG_STATE_HOME="${test_root}/installed-session-autostart-state"
  source "$autostart"
  current_user() {
    printf 'installed-user\n'
  }
  is_live_session() {
    printf 'not a live session\n' >&2
    return 1
  }
  report_autostart_failure() {
    fail 'installed-session suppression displayed a live-only error'
  }
  wait_for_desktop() {
    fail 'installed-session suppression waited for the desktop'
  }
  launch_installer() {
    fail 'installed-session suppression launched the installer'
  }

  main || fail 'installed-session autostart suppression returned failure'
)

printf 'Installer experience tests passed.\n'
