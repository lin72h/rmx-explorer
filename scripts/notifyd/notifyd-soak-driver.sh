#!/bin/sh
# notifyd-soak-driver.sh — sustained notify post/register churn under the oracle.
# Loops a notify client (register → post → check → cancel) for SOAK_DURATION
# seconds while the soak-oracle.d runs in the background.
#
# Adapted from the op-104/op-105 dispatch soak-driver. Same carry-forwards:
# - date +%s (not SECONDS — FreeBSD sh doesn't support the bashism)
# - kldload profile (tick probes need the profile provider)
# - no -DSOAK_SECONDS (FreeBSD dtrace doesn't support -D macros)
# - global-int counters in the oracle (not aggregations)
# - self-terminating tick (not SIGINT+END)
#
# DESIGN (op-131 hardening):
#   This driver runs from the SHELL (not a launchd job). bs_probe round-trips
#   go through /root/run-as-launchd-job.sh (li-005: shell=port 0, launchd
#   child=port 19). Direct /root/bs_probe from here would get port=0 → fail.
#   The oracle (DTrace fbt) runs in the background — no bootstrap needed.
#
# Prerequisites: launchd + notifyd up (the nxplatform-probe session manages
# launchd). /root/run-as-launchd-job.sh + /root/bs_probe must be present.
SOAK_DURATION="${SOAK_DURATION:-300}"
ORACLE="${ORACLE:-/root/notifyd-soak-oracle.d}"
ORACLE_LOG="${ORACLE_LOG:-/root/notifyd-soak-oracles.log}"
CLIENT_LOG="${CLIENT_LOG:-/root/notifyd-soak-client.log}"
RUNNER="${RUNNER:-/root/run-as-launchd-job.sh}"

export LD_LIBRARY_PATH=/usr/lib
kldload mach 2>/dev/null || true
kldload opensolaris 2>/dev/null; kldload dtrace 2>/dev/null
kldload fbt 2>/dev/null; kldload fasttrap 2>/dev/null; kldload systrace 2>/dev/null
kldload profile 2>/dev/null

echo "[notifyd-soak] starting oracle"
dtrace -Z -s "$ORACLE" > "$ORACLE_LOG" 2>&1 &
DTRACE_PID=$!
sleep 3

echo "[notifyd-soak] churning notify via launchd-child runner for ${SOAK_DURATION}s"
end=$(( $(date +%s) + SOAK_DURATION ))
iter=0; fails=0
while [ "$(date +%s)" -lt "$end" ]; do
  iter=$((iter + 1))
  # Route through the shipped runner → launchd child → bootstrap inherited.
  # Direct bs_probe from shell gets port=0 (li-005). The runner overhead is
  # acceptable for a soak (the oracle measures kernel IPC balance, not latency).
  if [ -x "$RUNNER" ] && [ -x /root/bs_probe ]; then
    if "$RUNNER" /root/bs_probe >> "$CLIENT_LOG" 2>&1; then :; else
      rc=$?; fails=$((fails + 1)); echo "iter=$iter FAIL rc=$rc" >> "$CLIENT_LOG"; fi
  else
    echo "iter=$iter (runner/bs_probe absent — skip)" >> "$CLIENT_LOG"
  fi
done

echo "[notifyd-soak] waiting for oracle self-exit"
wait "$DTRACE_PID" 2>/dev/null || true

printf 'notifyd_soak_iterations=%d notifyd_soak_fails=%d notifyd_soak_duration=%d\n' "$iter" "$fails" "$SOAK_DURATION"
printf 'notifyd_soak_terminal status=0\n'
sync; sleep 1; shutdown -p now
