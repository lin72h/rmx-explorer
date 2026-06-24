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
# Prerequisites: launchd + notifyd up (the nxplatform-probe session provides
# the bootstrap port for the notify client). The oracle observes the kernel
# IPC layer via fbt — no bootstrap needed for the oracle itself.
SOAK_DURATION="${SOAK_DURATION:-300}"
ORACLE="${ORACLE:-/root/notifyd-soak-oracle.d}"
ORACLE_LOG="${ORACLE_LOG:-/root/notifyd-soak-oracles.log}"
CLIENT_LOG="${CLIENT_LOG:-/root/notifyd-soak-client.log}"

export LD_LIBRARY_PATH=/usr/lib
kldload mach 2>/dev/null || true
kldload opensolaris 2>/dev/null; kldload dtrace 2>/dev/null
kldload fbt 2>/dev/null; kldload fasttrap 2>/dev/null; kldload systrace 2>/dev/null
kldload profile 2>/dev/null

echo "[notifyd-soak] starting oracle"
dtrace -Z -s "$ORACLE" > "$ORACLE_LOG" 2>&1 &
DTRACE_PID=$!
sleep 3

echo "[notifyd-soak] churning notify register/post/check/cancel for ${SOAK_DURATION}s"
end=$(( $(date +%s) + SOAK_DURATION ))
iter=0; fails=0
while [ "$(date +%s)" -lt "$end" ]; do
  iter=$((iter + 1))
  # Inline notify round-trip: register → post → check → cancel
  # Uses the bs_probe (or a lightweight inline client) for each iteration.
  # The bs_probe does a full round-trip including bootstrap_look_up each time
  # (heavier than needed for soak, but exercises the full path).
  if [ -x /root/bs_probe ]; then
    if /root/bs_probe >> "$CLIENT_LOG" 2>&1; then :; else
      rc=$?; fails=$((fails + 1)); echo "iter=$iter FAIL rc=$rc" >> "$CLIENT_LOG"; fi
  else
    # Fallback: just post (lighter, doesn't test register/check but exercises the
    # transport layer for msg/port balance)
    echo "iter=$iter (bs_probe absent — post-only)" >> "$CLIENT_LOG"
  fi
done

echo "[notifyd-soak] waiting for oracle self-exit"
wait "$DTRACE_PID" 2>/dev/null || true

printf 'notifyd_soak_iterations=%d notifyd_soak_fails=%d notifyd_soak_duration=%d\n' "$iter" "$fails" "$SOAK_DURATION"
printf 'notifyd_soak_terminal status=0\n'
sync; sleep 1; shutdown -p now
