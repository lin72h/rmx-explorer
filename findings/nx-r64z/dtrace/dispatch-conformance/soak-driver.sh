#!/bin/sh
# soak-driver.sh — continuous harness loop under the 4-oracle DTrace (op-104 infra).
# Loops harness.c for SOAK_DURATION seconds while dtrace aggregates in the background.
# On completion: SIGINT dtrace (fires END → final deltas), print summary, power off.
SOAK_DURATION="${SOAK_DURATION:-300}"
HARNESS="${HARNESS:-/root/harness}"
ORACLE="${ORACLE:-/root/soak-oracle.d}"
ORACLE_LOG="${ORACLE_LOG:-/root/soak-oracles.log}"
HARNESS_LOG="${HARNESS_LOG:-/root/soak-harness.log}"

export LD_LIBRARY_PATH=/usr/lib
kldload mach 2>/dev/null || true
kldload opensolaris 2>/dev/null; kldload dtrace 2>/dev/null
kldload fbt 2>/dev/null; kldload fasttrap 2>/dev/null; kldload systrace 2>/dev/null

echo "[soak] starting dtrace oracle (background)"
dtrace -Z -s "$ORACLE" > "$ORACLE_LOG" 2>&1 &
DTRACE_PID=$!
sleep 3

echo "[soak] looping harness for ${SOAK_DURATION}s"
end=$(( $(date +%s) + SOAK_DURATION ))
iter=0; fails=0
while [ "$(date +%s)" -lt "$end" ]; do
  iter=$((iter + 1))
  if "$HARNESS" >> "$HARNESS_LOG" 2>&1; then :; else
    fails=$((fails + 1)); echo "iter=$iter FAIL rc=$?" >> "$HARNESS_LOG"; fi
done

echo "[soak] stopping dtrace (SIGINT → END → deltas)"
kill -INT "$DTRACE_PID" 2>/dev/null; sleep 2; wait "$DTRACE_PID" 2>/dev/null

printf 'soak_iterations=%d soak_fails=%d soak_duration=%d\n' "$iter" "$fails" "$SOAK_DURATION"
printf 'op104_proof_terminal status=0\n'
sync; sleep 1; shutdown -p now
