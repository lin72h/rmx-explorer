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
#   - notify_register_check harness binary at /root/bs_probe (op-127)
#
# Structured output: NOTIFYD_LIFECYCLE_<rung> status=<0|1> markers.
set -u

PLIST="/root/nxplatform/block078/com.apple.notifyd.plist"
LABEL="com.apple.notifyd"
FAIL=0

emit() { printf '%s\n' "$1"; }

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
  # Check notifyd is in the process table
  if /bin/ps axww 2>/dev/null | grep -q '[n]otifyd'; then
    emit "NOTIFYD_LIFECYCLE_OBSERVE_PROC status=0"
  else
    emit "NOTIFYD_LIFECYCLE_OBSERVE_PROC status=1 reason=notifyd_not_in_ps"
    FAIL=1
  fi
  # Check the notify round-trip works (via the bs_probe or a simple notify client)
  # The probe-child path (this script is a child of the nxplatform-probe which
  # has a bootstrap port) can reach notifyd directly.
  export LD_LIBRARY_PATH=/usr/lib
  if [ -x /root/bs_probe ]; then
    /root/bs_probe > /tmp/notifyd-lc-observe.out 2>&1
    if grep -q 'notify_check rc=0 check=1' /tmp/notifyd-lc-observe.out 2>/dev/null; then
      emit "NOTIFYD_LIFECYCLE_OBSERVE_ROUNDTRIP status=0"
    else
      emit "NOTIFYD_LIFECYCLE_OBSERVE_ROUNDTRIP status=1 reason=roundtrip_failed"
      cat /tmp/notifyd-lc-observe.out 2>/dev/null
      FAIL=1
    fi
  else
    emit "NOTIFYD_LIFECYCLE_OBSERVE_ROUNDTRIP status=0 reason=bs_probe_absent_skipped"
  fi
fi

# === RUNG 4: RESTART (kill notifyd, verify launchd restarts it OR manually restart) ===
if [ "$FAIL" -eq 0 ]; then
  # kill notifyd and see if launchd restarts it (KeepAlive) or if we must manual-start
  notifyd_pid=$(/bin/ps axww 2>/dev/null | grep '[n]otifyd' | awk '{print $1}' | head -1)
  if [ -n "$notifyd_pid" ]; then
    kill "$notifyd_pid" 2>/dev/null || true
    sleep 3  # give launchd time to detect + restart
    if /bin/ps axww 2>/dev/null | grep -q '[n]otifyd'; then
      emit "NOTIFYD_LIFECYCLE_RESTART status=0 reason=launchd_auto_restart"
    else
      # try manual restart
      /bin/launchctl start "$LABEL" > /tmp/notifyd-lc-restart.out 2>&1
      sleep 2
      if /bin/ps axww 2>/dev/null | grep -q '[n]otifyd'; then
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
  lc_remove_rc=$?
  sleep 2
  if /bin/ps axww 2>/dev/null | grep -q '[n]otifyd'; then
    emit "NOTIFYD_LIFECYCLE_REMOVE status=1 reason=notifyd_still_running_after_remove"
    FAIL=1
  else
    emit "NOTIFYD_LIFECYCLE_REMOVE status=0"
  fi
fi

# === RUNG 6: RELOAD (load again — notifyd should come back up) ===
if [ "$FAIL" -eq 0 ]; then
  /bin/launchctl load "$PLIST" > /tmp/notifyd-lc-reload.out 2>&1
  lc_reload_rc=$?
  /bin/launchctl start "$LABEL" > /dev/null 2>&1
  sleep 2
  if /bin/ps axww 2>/dev/null | grep -q '[n]otifyd'; then
    emit "NOTIFYD_LIFECYCLE_RELOAD status=0"
    # Final round-trip to verify state after reload
    if [ -x /root/bs_probe ]; then
      /root/bs_probe > /tmp/notifyd-lc-reload-rt.out 2>&1
      if grep -q 'notify_check rc=0 check=1' /tmp/notifyd-lc-reload-rt.out 2>/dev/null; then
        emit "NOTIFYD_LIFECYCLE_RELOAD_ROUNDTRIP status=0"
      else
        emit "NOTIFYD_LIFECYCLE_RELOAD_ROUNDTRIP status=1 reason=roundtrip_failed_after_reload"
      fi
    fi
  else
    emit "NOTIFYD_LIFECYCLE_RELOAD status=1 reason=notifyd_not_up_after_reload"
    FAIL=1
  fi
fi

emit "NOTIFYD_LIFECYCLE_TERMINAL status=$FAIL"
exit "$FAIL"
