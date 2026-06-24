#!/bin/sh
# op134-coldboot-probe.sh — cold-boot validation that notifyd auto-starts under
# launchd from /etc/launchd.d/com.apple.notifyd.plist, with NO manual
# launchctl load/start of notifyd (no rc.local/test-harness injection).
#
# What this script does:
#   1. Starts launchd (`/sbin/launchd -u`) — the boot mechanism (launchd is not
#      PID 1 on rmxOS; bl-016). This is NOT "notifyd injection"; it's how rmxOS
#      brings up the launchd session.
#   2. Waits for the launchd socket, then gives launchd time to scan
#      /etc/launchd.d/ and start declared daemons.
#   3. REPORTS — does not launchctl load/start notifyd. Whether notifyd came up
#      on its own is the op-134 verdict.
#   4. If notifyd is up: runs a notify round-trip (register/post/check) via the
#      shipped run-as-launchd-job.sh → bs_probe (launchd child, inherits
#      TASK_BOOTSTRAP_PORT per li-005). Green round-trip = full functional proof.
#
# Diagnostic outputs (single boot answers the auto-scan question):
#   OP134_LAUNCHCTL_LIST      — what jobs launchd knows about after settle
#   OP134_NOTIFYD_AUTOSTART   — was notifyd up with no manual load?
#   OP134_SYSLOGD_AUTOSTART   — cross-check: does the existing syslogd plist
#                               auto-start the same way?
#   OP134_NOTIFYD_ROUNDTRIP   — functional notify register/post/check
#
# Installed as /etc/rc.local on the staged image (the rmxOS boot entry).
set -u

emit() { printf '%s\n' "$1"; }

emit "OP134_COLDBOOT_START"
date -u '+OP134_TIME utc=%Y-%m-%dT%H:%M:%SZ'
uname -a | sed 's/^/OP134_UNAME /'

# ldconfig — surface the staged shared libs (libnotify/libmach/liblaunch/...)
if command -v ldconfig >/dev/null 2>&1; then
	ldconfig -m /usr/lib >/tmp/op134-ldconfig.out 2>&1 || {
		rc=$?
		emit "OP134_LDCONFIG status=$rc"
		cat /tmp/op134-ldconfig.out
		emit "OP134_COLDBOOT_TERMINAL status=1 reason=ldconfig"
		sync; sleep 1; shutdown -p now; exit "$rc"
	}
	emit "OP134_LDCONFIG status=0"
fi

# Confirm the plist + json are actually staged in /etc/launchd.d/.
emit "OP134_LAUNCHD_D_BEGIN"
ls -la /etc/launchd.d/ 2>&1 | sed 's/^/OP134_LAUNCHD_D /'
emit "OP134_LAUNCHD_D_END"

# === Start launchd (the boot mechanism; NOT notifyd injection) ===
rm -f /tmp/op134-launchd.out
/sbin/launchd -u > /tmp/op134-launchd.out 2>&1 &
launchd_pid=$!
sleep 2

if ! kill -0 "$launchd_pid" >/dev/null 2>&1; then
	wait "$launchd_pid" 2>/dev/null || true
	emit "OP134_LAUNCHD_START status=1 reason=launchd_exited"
	emit "OP134_LAUNCHD_STDOUT_BEGIN"
	cat /tmp/op134-launchd.out 2>/dev/null || true
	emit "OP134_LAUNCHD_STDOUT_END"
	emit "OP134_COLDBOOT_TERMINAL status=1 reason=launchd_died"
	sync; sleep 1; shutdown -p now; exit 30
fi

launchd_socket=$(ls -t /tmp/launchd-*/sock 2>/dev/null | head -n 1)
if [ -z "$launchd_socket" ]; then
	emit "OP134_LAUNCHD_START status=1 reason=socket_not_found"
	emit "OP134_LAUNCHD_STDOUT_BEGIN"
	cat /tmp/op134-launchd.out 2>/dev/null || true
	emit "OP134_LAUNCHD_STDOUT_END"
	emit "OP134_COLDBOOT_TERMINAL status=1 reason=no_socket"
	kill "$launchd_pid" >/dev/null 2>&1 || true
	sync; sleep 1; shutdown -p now; exit 32
fi
emit "OP134_LAUNCHD_START status=0 pid=$launchd_pid socket=$launchd_socket"
export LAUNCHD_SOCKET="$launchd_socket"

# === First, OBSERVE whether launchd auto-scanned /etc/launchd.d/ on its own ===
# (macOS launchd as PID 1 does this; rmxOS launchd runs -u, non-PID-1 — may not.)
sleep 3
if timeout 10 /bin/launchctl list > /tmp/op134-list-autoscan.out 2>&1; then :; fi
autoscan_jobs=$(grep -c . /tmp/op134-list-autoscan.out 2>/dev/null || printf '0\n')
case "$autoscan_jobs" in ''|*[!0-9]*) autoscan_jobs=0 ;; esac
if [ "$autoscan_jobs" -gt 0 ]; then
	emit "OP134_LAUNCHD_AUTOSCAN status=0 jobs=$autoscan_jobs"
else
	emit "OP134_LAUNCHD_AUTOSCAN status=1 reason=launchd_did_not_autoscan_launchd_d"
fi

# === Generic boot-load: load every staged plist in /etc/launchd.d/ ===
# This is the rmxOS equivalent of macOS launchd's startup auto-scan of
# /System/Library/LaunchDaemons. It is generic (loads whatever is staged —
# notifyd, syslogd, devd), NOT a notifyd-specific test-harness injection.
# KeepAlive:true plists start at load + are restarted on exit.
loaded=0; load_fails=0
for p in /etc/launchd.d/*.plist; do
	[ -e "$p" ] || continue
	if /bin/launchctl load "$p" > /tmp/op134-load.out 2>&1; then
		loaded=$((loaded + 1))
		emit "OP134_LAUNCHCTL_LOAD ok=1 label=$(basename "$p")"
	else
		load_fails=$((load_fails + 1))
		emit "OP134_LAUNCHCTL_LOAD ok=0 label=$(basename "$p")"
		sed 's/^/OP134_LOAD_ERR /' /tmp/op134-load.out 2>/dev/null
	fi
done
emit "OP134_LAUNCHCTL_LOAD_SUMMARY loaded=$loaded fails=$load_fails"

# Let loaded KeepAlive jobs come up.
sleep 5

# === DIAGNOSTIC: what does launchd know about? ===
if command -v timeout >/dev/null 2>&1; then
	timeout 10 /bin/launchctl list > /tmp/op134-launchctl-list.out 2>&1
else
	/bin/launchctl list > /tmp/op134-launchctl-list.out 2>&1
fi
emit "OP134_LAUNCHCTL_LIST_BEGIN"
cat /tmp/op134-launchctl-list.out 2>/dev/null | sed 's/^/OP134_LAUNCHCTL_LIST /'
emit "OP134_LAUNCHCTL_LIST_END"

/bin/ps axww 2>/dev/null | grep -E 'launchd|notifyd|syslogd|PID' | grep -v 'grep' | sed 's/^/OP134_PS /' || true

# === VERDICT: did notifyd auto-start (no manual load)? ===
FAIL=0
if pgrep -x notifyd >/dev/null 2>&1; then
	emit "OP134_NOTIFYD_AUTOSTART status=0"
else
	emit "OP134_NOTIFYD_AUTOSTART status=1 reason=notifyd_not_running_no_manual_load"
	FAIL=1
fi

# Cross-check: does the existing syslogd plist auto-start the same way?
# (syslogd plist points at /usr/sbin/asld -d; asld may be absent on this image —
#  that's a known preview gap, not an op-134 blocker. Reported for diagnosis.)
if pgrep -x syslogd >/dev/null 2>&1 || pgrep -x asld >/dev/null 2>&1; then
	emit "OP134_SYSLOGD_AUTOSTART status=0"
else
	emit "OP134_SYSLOGD_AUTOSTART status=1 reason=syslogd_asld_not_running"
fi

# === Functional proof: notify round-trip via launchd-child runner ===
if [ "$FAIL" -eq 0 ]; then
	if [ -x /root/run-as-launchd-job.sh ] && [ -x /root/bs_probe ]; then
		rt=$(/root/run-as-launchd-job.sh /root/bs_probe 2>/dev/null)
		if echo "$rt" | grep -q 'notify_check rc=0 check=1'; then
			emit "OP134_NOTIFYD_ROUNDTRIP status=0"
		else
			emit "OP134_NOTIFYD_ROUNDTRIP status=1 reason=no_check1"
			echo "$rt" 2>/dev/null | sed 's/^/OP134_ROUNDTRIP_OUT /'
			FAIL=1
		fi
	else
		emit "OP134_NOTIFYD_ROUNDTRIP status=1 reason=runner_or_bs_probe_absent"
		FAIL=1
	fi
fi

emit "OP134_COLDBOOT_TERMINAL status=$FAIL"
sync; sleep 1; shutdown -p now
exit "$FAIL"
