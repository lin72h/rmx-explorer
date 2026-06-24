#!/bin/sh
# op-130 id-015 step-3 notify smoke recipe — reworked: reuse-shipped.
# Runs on the booted op-128 dev-preview image.
#
# The image SHIPS (verified first-hand by mounting dev-preview-memstick.img):
#   /sbin/launchd, /bin/launchctl, /usr/sbin/notifyd, /usr/sbin/syslogd
#   /usr/lib/{libdispatch,libnotify,libmach,liblaunch}.so.5
#   /root/bs_probe (op-127 binary — bootstrap_port + notify round-trip)
#   /root/run-as-launchd-job.sh (the shipped runner: takes a program path,
#     renders the plist template, loads + starts it as a launchd child so it
#     inherits TASK_BOOTSTRAP_PORT, captures stdout/stderr, prints them)
#   /root/run-as-launchd-job.plist.template
#   /boot/modules/mach.ko (loader.conf: mach_load="YES")
#   /etc/launchd.d/com.apple.syslogd.plist + .json
#   /root/PREVIEW-README.md (documents the li-005 launch-model gap)
#
# NOTHING is staged — the recipe uses ONLY shipped artifacts. This is the honest
# "can a developer run notify on the shipped preview image" test.
#
# Expected marker chain:
#   NOTIFY_SMOKE_SHIPPED_CHECK status=0
#   NOTIFY_SMOKE_RUNNER_INVOKED status=0
#   TASK_BOOTSTRAP_PORT kr=0 port=<non-zero>   ← from bs_probe inside launchd
#   bootstrap_look_up(notify) kr=0 port=<non-zero>
#   notify_register_check rc=0
#   notify_post rc=0
#   notify_check rc=0 check=1
#   NOTIFY_SMOKE_TERMINAL status=0|1            ← gated on the parsed values
set -u

echo "NOTIFY_SMOKE_START"

# === 1. Verify shipped artifacts exist (detect, don't stage) ===
SHIPPED_OK=1
for f in /sbin/launchd /bin/launchctl /usr/sbin/notifyd /usr/lib/libnotify.so.5 \
         /usr/lib/libmach.so.5 /usr/lib/liblaunch.so.5 /root/bs_probe \
         /root/run-as-launchd-job.sh; do
  if [ ! -e "$f" ]; then
    echo "NOTIFY_SMOKE_MISSING_SHIPPED file=$f"
    SHIPPED_OK=0
  fi
done
echo "NOTIFY_SMOKE_SHIPPED_CHECK status=$SHIPPED_OK"
[ "$SHIPPED_OK" -eq 0 ] && { echo "NOTIFY_SMOKE_TERMINAL status=1 reason=missing_shipped"; exit 1; }

# === 2. Invoke the shipped runner to run bs_probe as a launchd child ===
# run-as-launchd-job.sh: loads bs_probe as a launchd job (bootstrap inherited),
# waits for output, prints stdout + stderr, cleans up the job.
SMOKE_OUT=$(/root/run-as-launchd-job.sh /root/bs_probe 2>/dev/null)
RUNNER_RC=$?
echo "NOTIFY_SMOKE_RUNNER_INVOKED status=$RUNNER_RC"
[ "$RUNNER_RC" -ne 0 ] && { echo "NOTIFY_SMOKE_TERMINAL status=1 reason=runner_failed rc=$RUNNER_RC"; exit 1; }

# === 3. Parse the bs_probe output + gate TERMINAL on the actual values ===
echo "=== NOTIFY SMOKE OUTPUT (from shipped bs_probe via shipped runner) ==="
echo "$SMOKE_OUT"
echo "=== NOTIFY SMOKE END ==="

# Parse each critical line
BP_PORT=$(echo "$SMOKE_OUT" | grep 'TASK_BOOTSTRAP_PORT' | grep -oE 'port=[0-9]+' | cut -d= -f2)
BLU_KR=$(echo "$SMOKE_OUT" | grep 'bootstrap_look_up' | grep -oE 'kr=[0-9]+' | cut -d= -f2)
NRC_RC=$(echo "$SMOKE_OUT" | grep 'notify_register_check' | grep -oE 'rc=[0-9]+' | cut -d= -f2)
NP_RC=$(echo "$SMOKE_OUT" | grep 'notify_post' | grep -oE 'rc=[0-9]+' | cut -d= -f2)
NC_CHECK=$(echo "$SMOKE_OUT" | grep 'notify_check' | grep -oE 'check=[0-9]+' | cut -d= -f2)

echo "NOTIFY_SMOKE_BS_PORT value=$BP_PORT"
echo "NOTIFY_SMOKE_BOOTSTRAP_LOOK_UP kr=$BLU_KR"
echo "NOTIFY_SMOKE_NOTIFY_REGISTER rc=$NRC_RC"
echo "NOTIFY_SMOKE_NOTIFY_POST rc=$NP_RC"
echo "NOTIFY_SMOKE_NOTIFY_CHECK check=$NC_CHECK"

# Gate: all five must be correct
FAIL=0
[ -z "$BP_PORT" ] || [ "$BP_PORT" = "0" ] && { echo "FAIL: bootstrap_port=$BP_PORT"; FAIL=1; }
[ -z "$BLU_KR" ] || [ "$BLU_KR" != "0" ] && { echo "FAIL: bootstrap_look_up kr=$BLU_KR"; FAIL=1; }
[ -z "$NRC_RC" ] || [ "$NRC_RC" != "0" ] && { echo "FAIL: notify_register_check rc=$NRC_RC"; FAIL=1; }
[ -z "$NP_RC" ] || [ "$NP_RC" != "0" ] && { echo "FAIL: notify_post rc=$NP_RC"; FAIL=1; }
[ -z "$NC_CHECK" ] || [ "$NC_CHECK" != "1" ] && { echo "FAIL: notify_check check=$NC_CHECK"; FAIL=1; }

echo "NOTIFY_SMOKE_TERMINAL status=$FAIL"
exit "$FAIL"
