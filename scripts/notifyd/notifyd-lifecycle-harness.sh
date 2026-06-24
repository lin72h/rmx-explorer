#!/bin/sh
# notifyd-lifecycle-harness.sh — Gate C lifecycle driver for notifyd under launchd.
# Drives: load → start → observe → restart → remove → reload.
# Accounts for notifyd's name-table state across restart/reload (notifyd has
# state a fixture job doesn't — registered tokens survive restarts within a
# session, but the Mach service port may re-register).
#
# Adapted from the D23 launchd lifecycle suite pattern (wip-gpt/scripts/launchd/
# verify-phase08-launchd-dispatch-lifecycle.exs) but targets the real notifyd
# daemon (com.apple.notifyd) instead of a dispatch fixture.
#
# Prerequisites (set by the nxplatform-probe before calling this script):
#   - launchd running (-u mode), LAUNCHD_SOCKET exported
#   - com.apple.notifyd.plist staged at /root/nxplatform/block078/
#   - /root/bs_probe present (op-127 binary)
#   - /root/run-as-launchd-job.sh present (shipped runner)
#
# DESIGN (op-131 hardening):
#   This harness runs from the SHELL (rc.local / probe script context), NOT as
#   a launchd job. If it ran as a launchd job, killing notifyd in the restart
#   rung could cascade-kill this harness (launchd child cleanup). Running from
#   the shell insulates us.
#   bs_probe round-trips are routed through run-as-launchd-job.sh (launchd
#   child) so they inherit TASK_BOOTSTRAP_PORT (li-005: shell=port 0, launchd
#   child=port 19). Direct /root/bs_probe from here would get port=0 → fail.
#
# Structured output: NOTIFYD_LIFECYCLE_<rung> status=<0|1> markers.
set -u

PLIST="/root/nxplatform/block078/com.apple.notifyd.plist"
LABEL="com.apple.notifyd"
RUNNER="/root/run-as-launchd-job.sh"
FAIL=0

emit() { printf '%s\n' "$1"; }

# notifyd round-trip via the shipped runner (launchd child → bootstrap inherited).
# Sets $RT_OUT to the bs_probe stdout. Returns 0 if notify_check=check=1 found.
do_roundtrip() {
	RT_OUT=""
	if [ ! -x "$RUNNER" ] || [ ! -x /root/bs_probe ]; then
		echo "do_roundtrip: WARN: runner or bs_probe absent" >&2
		return 99
	fi
	RT_OUT=$("$RUNNER" /root/bs_probe 2>/dev/null)
	if echo "$RT_OUT" | grep -q 'notify_check rc=0 check=1'; then
		return 0
	else
		return 1
	fi
}

emit "NOTIFYD_LIFECYCLE_START"

# === RUNG 1: LOAD ===
/bin/launchctl load "$PLIST" > /tmp/notifyd-lc-load.out 2>&1
lc_load_rc=$?
emit "NOTIFYD_LIFECYCLE_LOAD status=$lc_load_rc"
cat /tmp/notifyd-lc-load.out 2>/dev/null
[ "$lc_load_rc" -ne 0 ] && { emit "NOTIFYD_LIFECYCLE_FIRST_BLOCKER rung=load rc=$lc_load_rc"; FAIL=1; }

# === RUNG 2: START ===
if [ "$lc_load_rc" -eq 0 ]; then
  /bin/launchctl start "$LABEL" > /tmp/notifyd-lc-start.out 2>&1
  lc_start_rc=$?
  emit "NOTIFYD_LIFECYCLE_START_RUNG status=$lc_start_rc"
  cat /tmp/notifyd-lc-start.out 2>/dev/null
  [ "$lc_start_rc" -ne 0 ] && { emit "NOTIFYD_LIFECYCLE_FIRST_BLOCKER rung=start rc=$lc_start_rc"; FAIL=1; }
fi

# === RUNG 3: OBSERVE (verify notifyd is up + serving) ===
if [ "$FAIL" -eq 0 ]; then
  sleep 2
  # pgrep -x (exact match) — avoids self-match on this script's name
  if pgrep -x notifyd >/dev/null 2>&1; then
    emit "NOTIFYD_LIFECYCLE_OBSERVE_PROC status=0"
  else
    emit "NOTIFYD_LIFECYCLE_OBSERVE_PROC status=1 reason=notifyd_not_in_ps"
    FAIL=1
  fi
  # Round-trip via launchd-child runner (li-005: shell=port 0, launchd child=port 19)
  if [ "$FAIL" -eq 0 ]; then
    if do_roundtrip; then
      emit "NOTIFYD_LIFECYCLE_OBSERVE_ROUNDTRIP status=0"
    else
      emit "NOTIFYD_LIFECYCLE_OBSERVE_ROUNDTRIP status=1 reason=roundtrip_failed"
      echo "$RT_OUT" 2>/dev/null
      FAIL=1
    fi
  fi
fi

# === RUNG 4: RESTART (kill notifyd, verify launchd restarts it OR manually restart) ===
if [ "$FAIL" -eq 0 ]; then
  notifyd_pid=$(pgrep -x notifyd 2>/dev/null | head -1)
  if [ -n "$notifyd_pid" ]; then
    kill "$notifyd_pid" 2>/dev/null || true
    sleep 3  # give launchd time to detect + restart
    if pgrep -x notifyd >/dev/null 2>&1; then
      emit "NOTIFYD_LIFECYCLE_RESTART status=0 reason=launchd_auto_restart"
    else
      # try manual restart
      /bin/launchctl start "$LABEL" > /tmp/notifyd-lc-restart.out 2>&1
      sleep 2
      if pgrep -x notifyd >/dev/null 2>&1; then
        emit "NOTIFYD_LIFECYCLE_RESTART status=0 reason=manual_restart"
      else
        emit "NOTIFYD_LIFECYCLE_RESTART status=1 reason=notifyd_down_after_restart"
        FAIL=1
      fi
    fi
  else
    emit "NOTIFYD_LIFECYCLE_RESTART status=1 reason=notifyd_pid_not_found"
    FAIL=1
  fi
fi

# === RUNG 5: REMOVE (unload the plist — notifyd should stop) ===
if [ "$FAIL" -eq 0 ]; then
  /bin/launchctl remove "$LABEL" > /tmp/notifyd-lc-remove.out 2>&1
  sleep 2
  if pgrep -x notifyd >/dev/null 2>&1; then
    emit "NOTIFYD_LIFECYCLE_REMOVE status=1 reason=notifyd_still_running_after_remove"
    FAIL=1
  else
    emit "NOTIFYD_LIFECYCLE_REMOVE status=0"
  fi
fi

# === RUNG 6: RELOAD (load again — notifyd should come back up) ===
if [ "$FAIL" -eq 0 ]; then
  /bin/launchctl load "$PLIST" > /tmp/notifyd-lc-reload.out 2>&1
  /bin/launchctl start "$LABEL" > /dev/null 2>&1
  sleep 2
  if pgrep -x notifyd >/dev/null 2>&1; then
    emit "NOTIFYD_LIFECYCLE_RELOAD status=0"
    # Final round-trip to verify state after reload
    if do_roundtrip; then
      emit "NOTIFYD_LIFECYCLE_RELOAD_ROUNDTRIP status=0"
    else
      emit "NOTIFYD_LIFECYCLE_RELOAD_ROUNDTRIP status=1 reason=roundtrip_failed_after_reload"
    fi
  else
    emit "NOTIFYD_LIFECYCLE_RELOAD status=1 reason=notifyd_not_up_after_reload"
    FAIL=1
  fi
fi

emit "NOTIFYD_LIFECYCLE_TERMINAL status=$FAIL"
exit "$FAIL"
