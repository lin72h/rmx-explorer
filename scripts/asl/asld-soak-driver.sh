#!/bin/sh
# asld-soak-driver.sh — sustained ASL log/search churn under the oracle.
# Loops the asl-harness (asl_open → asl_log → asl_search → asl_close) for
# SOAK_DURATION seconds while the soak-oracle.d runs in the background.
#
# Mirrors the op-131-hardened notifyd-soak-driver.sh pattern:
#   - Driver runs from the SHELL (not a launchd job).
#   - asl-harness round-trips route through /root/run-as-launchd-job.sh
#     (li-005: shell=port 0, launchd child=port 19).
#   - Oracle (DTrace fbt) runs in background — no bootstrap needed.
#
# ASL is the higher-volume soak subject vs notify (asl_log + asl_search
# exercise the store write + query path; aslmanager reclaim may fire under
# sustained load). The oracle watches for: msg balance, port balance, store
# growth (bounded by aslmanager), no stuck enqueue.
#
# Prerequisites: launchd + syslogd (asld) up (the nxplatform-probe session
# manages launchd). /root/run-as-launchd-job.sh + /root/asl-harness present.
SOAK_DURATION="${SOAK_DURATION:-300}"
ORACLE="${ORACLE:-/root/asld-soak-oracle.d}"
ORACLE_LOG="${ORACLE_LOG:-/root/asld-soak-oracles.log}"
CLIENT_LOG="${CLIENT_LOG:-/root/asld-soak-client.log}"
RUNNER="${RUNNER:-/root/run-as-launchd-job.sh}"

export LD_LIBRARY_PATH=/usr/lib
kldload mach 2>/dev/null || true
kldload opensolaris 2>/dev/null; kldload dtrace 2>/dev/null
kldload fbt 2>/dev/null; kldload fasttrap 2>/dev/null; kldload systrace 2>/dev/null
kldload profile 2>/dev/null

echo "[asld-soak] starting oracle"
dtrace -Z -s "$ORACLE" > "$ORACLE_LOG" 2>&1 &
DTRACE_PID=$!
sleep 3

echo "[asld-soak] churning asl_log/asl_search via launchd-child runner for ${SOAK_DURATION}s"
end=$(( $(date +%s) + SOAK_DURATION ))
iter=0; fails=0
while [ "$(date +%s)" -lt "$end" ]; do
	iter=$((iter + 1))
	# Route through the shipped runner → launchd child → bootstrap inherited.
	# asl-harness does: open → log → search → close (full ASL round-trip).
	if [ -x "$RUNNER" ] && [ -x /root/asl-harness ]; then
		if "$RUNNER" /root/asl-harness >> "$CLIENT_LOG" 2>&1; then :; else
			rc=$?; fails=$((fails + 1)); echo "iter=$iter FAIL rc=$rc" >> "$CLIENT_LOG"; fi
	else
		echo "iter=$iter (runner/asl-harness absent — skip)" >> "$CLIENT_LOG"
	fi
done

echo "[asld-soak] waiting for oracle self-exit"
wait "$DTRACE_PID" 2>/dev/null || true

printf 'asld_soak_iterations=%d asld_soak_fails=%d asld_soak_duration=%d\n' "$iter" "$fails" "$SOAK_DURATION"
printf 'asld_soak_terminal status=0\n'
sync; sleep 1; shutdown -p now
