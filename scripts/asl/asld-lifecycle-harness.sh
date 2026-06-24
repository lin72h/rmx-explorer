#!/bin/sh
# asld-lifecycle-harness.sh — Gate C lifecycle driver for the Apple ASL syslogd
# (asld / com.apple.syslogd) under launchd.
# Drives: load → start → observe → restart → remove → reload.
#
# Mirrors the op-131-hardened notifyd-lifecycle-harness.sh pattern:
#   - Harness runs from the SHELL (rc.local / probe script context), NOT as a
#     launchd job. Killing asld in the restart rung can't cascade-kill this
#     driver.
#   - ASL round-trips (asl_open → asl_log → asl_search → asl_close) route
#     through /root/run-as-launchd-job.sh (li-005: shell=port 0, launchd
#     child=port 19). The asl client reaches asld via the
#     com.apple.system.logger Mach bootstrap service.
#   - Process detection via pgrep -x syslogd (exact name match, no
#     grep-self-match).
#
# Prerequisites (set by the nxplatform-probe before calling this script):
#   - launchd running (-u mode), LAUNCHD_SOCKET exported
#   - com.apple.syslogd.plist staged (or use the shipped /etc/launchd.d/ entry)
#   - /root/asl-harness present (the op-116 asl-harness binary)
#   - /root/run-as-launchd-job.sh present (the shipped runner)
#
# The asl-harness binary does: asl_open → asl_new → asl_set → asl_log →
# asl_get (kv round-trip) → asl_set_filter → asl_search → asl_close.
# A successful asl_search round-trip proves syslogd received + stored the
# message (Mach bootstrap → asld → ASL store → search response).
#
# Structured output: ASLD_LIFECYCLE_<rung> status=<0|1> markers.
set -u

# com.apple.syslogd may already be registered via /etc/launchd.d/ or need
# explicit plist load. Try /etc/launchd.d/ first; fall back to a staged plist.
PLIST_SYSLOGD="/etc/launchd.d/com.apple.syslogd.plist"
PLIST_STAGED="/root/com.apple.syslogd.plist"
LABEL="com.apple.syslogd"
RUNNER="/root/run-as-launchd-job.sh"
FAIL=0

emit() { printf '%s\n' "$1"; }

# ASL round-trip via the shipped runner (launchd child → bootstrap inherited).
# Sets $RT_OUT to the asl-harness stdout. Returns 0 if asl_search passes.
do_roundtrip() {
	RT_OUT=""
	if [ ! -x "$RUNNER" ] || [ ! -x /root/asl-harness ]; then
		echo "do_roundtrip: WARN: runner or asl-harness absent" >&2
		return 99
	fi
	RT_OUT=$("$RUNNER" /root/asl-harness 2>/dev/null)
	# asl_search_roundtrip is the load-bearing case: it proves asld received
	# the logged message + the store query returned results.
	if echo "$RT_OUT" | grep -q 'asl_search_roundtrip: PASS'; then
		return 0
	else
		return 1
	fi
}

emit "ASLD_LIFECYCLE_START"

# === Determine plist source ===
if [ -f "$PLIST_SYSLOGD" ]; then
	PLIST="$PLIST_SYSLOGD"
	emit "ASLD_LIFECYCLE_PLIST source=shipped_etc_launchd_d"
elif [ -f "$PLIST_STAGED" ]; then
	PLIST="$PLIST_STAGED"
	emit "ASLD_LIFECYCLE_PLIST source=staged_root"
else
	emit "ASLD_LIFECYCLE_PLIST source=ABSENT"
	emit "ASLD_LIFECYCLE_TERMINAL status=1 reason=no_syslogd_plist"
	exit 1
fi

# === RUNG 1: LOAD ===
/bin/launchctl load "$PLIST" > /tmp/asld-lc-load.out 2>&1
lc_load_rc=$?
emit "ASLD_LIFECYCLE_LOAD status=$lc_load_rc"
cat /tmp/asld-lc-load.out 2>/dev/null
[ "$lc_load_rc" -ne 0 ] && { emit "ASLD_LIFECYCLE_FIRST_BLOCKER rung=load rc=$lc_load_rc"; FAIL=1; }

# === RUNG 2: START ===
if [ "$lc_load_rc" -eq 0 ]; then
	/bin/launchctl start "$LABEL" > /tmp/asld-lc-start.out 2>&1
	lc_start_rc=$?
	emit "ASLD_LIFECYCLE_START_RUNG status=$lc_start_rc"
	cat /tmp/asld-lc-start.out 2>/dev/null
	[ "$lc_start_rc" -ne 0 ] && { emit "ASLD_LIFECYCLE_FIRST_BLOCKER rung=start rc=$lc_start_rc"; FAIL=1; }
fi

# === RUNG 3: OBSERVE (verify syslogd is up + serving ASL) ===
if [ "$FAIL" -eq 0 ]; then
	sleep 2
	# pgrep -x syslogd — exact name match (the process is named "syslogd" on
	# rmxOS because PROG=asld in the Makefile but the binary is installed as
	# /usr/sbin/syslogd; ps shows the binary name)
	if pgrep -x syslogd >/dev/null 2>&1; then
		emit "ASLD_LIFECYCLE_OBSERVE_PROC status=0"
	else
		emit "ASLD_LIFECYCLE_OBSERVE_PROC status=1 reason=syslogd_not_in_ps"
		FAIL=1
	fi
	# ASL round-trip via launchd-child runner (li-005: bootstrap inherited)
	if [ "$FAIL" -eq 0 ]; then
		if do_roundtrip; then
			emit "ASLD_LIFECYCLE_OBSERVE_ROUNDTRIP status=0"
		else
			emit "ASLD_LIFECYCLE_OBSERVE_ROUNDTRIP status=1 reason=asl_roundtrip_failed"
			echo "$RT_OUT" 2>/dev/null
			FAIL=1
		fi
	fi
fi

# === RUNG 4: RESTART (kill syslogd, verify launchd restarts OR manual restart) ===
if [ "$FAIL" -eq 0 ]; then
	syslogd_pid=$(pgrep -x syslogd 2>/dev/null | head -1)
	if [ -n "$syslogd_pid" ]; then
		kill "$syslogd_pid" 2>/dev/null || true
		sleep 3
		if pgrep -x syslogd >/dev/null 2>&1; then
			emit "ASLD_LIFECYCLE_RESTART status=0 reason=launchd_auto_restart"
		else
			/bin/launchctl start "$LABEL" > /tmp/asld-lc-restart.out 2>&1
			sleep 2
			if pgrep -x syslogd >/dev/null 2>&1; then
				emit "ASLD_LIFECYCLE_RESTART status=0 reason=manual_restart"
			else
				emit "ASLD_LIFECYCLE_RESTART status=1 reason=syslogd_down_after_restart"
				FAIL=1
			fi
		fi
	else
		emit "ASLD_LIFECYCLE_RESTART status=1 reason=syslogd_pid_not_found"
		FAIL=1
	fi
fi

# === RUNG 5: REMOVE (launchctl remove — syslogd should stop) ===
if [ "$FAIL" -eq 0 ]; then
	/bin/launchctl remove "$LABEL" > /tmp/asld-lc-remove.out 2>&1
	sleep 2
	if pgrep -x syslogd >/dev/null 2>&1; then
		emit "ASLD_LIFECYCLE_REMOVE status=1 reason=syslogd_still_running"
		FAIL=1
	else
		emit "ASLD_LIFECYCLE_REMOVE status=0"
	fi
fi

# === RUNG 6: RELOAD (load + start — syslogd should come back up) ===
if [ "$FAIL" -eq 0 ]; then
	/bin/launchctl load "$PLIST" > /tmp/asld-lc-reload.out 2>&1
	/bin/launchctl start "$LABEL" > /dev/null 2>&1
	sleep 2
	if pgrep -x syslogd >/dev/null 2>&1; then
		emit "ASLD_LIFECYCLE_RELOAD status=0"
		if do_roundtrip; then
			emit "ASLD_LIFECYCLE_RELOAD_ROUNDTRIP status=0"
		else
			emit "ASLD_LIFECYCLE_RELOAD_ROUNDTRIP status=1 reason=asl_roundtrip_failed_after_reload"
		fi
	else
		emit "ASLD_LIFECYCLE_RELOAD status=1 reason=syslogd_not_up_after_reload"
		FAIL=1
	fi
fi

emit "ASLD_LIFECYCLE_TERMINAL status=$FAIL"
exit "$FAIL"
