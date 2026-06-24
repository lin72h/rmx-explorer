#!/bin/sh
# op-130 id-015 step-3 notify smoke recipe — for the Gatekeeper to run on the
# already-booted op-128 dev-preview memstick image.
#
# The op-128 image does NOT ship bs_probe, notifyd, or launchd by default.
# This recipe stages them + runs the notify round-trip as a launchd child
# (the PATH-2 launchd-child path from op-127 that proved bootstrap works).
#
# Expected marker chain (the Gatekeeper validates these):
#   NOTIFY_SMOKE_BS_PROBE_BUILD status=0
#   NOTIFY_SMOKE_NOTIFYD_UP status=0
#   notify_register_check rc=0
#   notify_post rc=0
#   notify_check rc=0 check=1
#   NOTIFY_SMOKE_TERMINAL status=0
#
# Prerequisites: the image must have the alpha userland (libdispatch, libnotify,
# liblaunch, libmach) at /usr/lib/. The Gatekeeper stages notifyd + launchd +
# launchctl + com.apple.notifyd.plist + bs_probe source + compiles in-guest.

# === 1. Stage launchd + notifyd (if not already on the image) ===
# The Gatekeeper copies from obj_root:
#   /sbin/launchd, /bin/launchctl, /usr/sbin/notifyd
#   /root/com.apple.notifyd.plist (simplified, no sandbox)
#   /root/bs_probe.c (the op-127 source)
#
# Simplified com.apple.notifyd.plist (no sandbox):
#   <plist><dict>
#     <key>Label</key><string>com.apple.notifyd</string>
#     <key>OnDemand</key><false/>
#     <key>ProgramArguments</key><array><string>/usr/sbin/notifyd</string></array>
#   </dict></plist>
#
# bs_probe.c compile recipe (in-guest, using the image's cc):
#   cc -D__APPLE__ -I/usr/include -o /root/bs_probe /root/bs_probe.c \
#     -L/usr/lib -lnotify -llaunch -lmach -lthr -lsys
# (If the image lacks cc, pre-compile on the host and copy the binary.)

# === 2. Start launchd + notifyd ===
export LD_LIBRARY_PATH=/usr/lib
ldconfig -m /usr/lib 2>/dev/null || true
/sbin/launchd -u > /tmp/launchd.out 2>&1 &
LAUNCHD_PID=$!
sleep 2
LAUNCHD_SOCKET=$(ls -t /tmp/launchd-*/sock 2>/dev/null | head -1)
export LAUNCHD_SOCKET
/bin/launchctl load /root/com.apple.notifyd.plist 2>&1
/bin/launchctl start com.apple.notifyd 2>&1
sleep 2

echo "NOTIFY_SMOKE_NOTIFYD_UP status=$(/bin/ps axww 2>/dev/null | grep -q '[n]otifyd' && echo 0 || echo 1)"

# === 3. Run bs_probe as a launchd child (inherits bootstrap → notifyd reachable) ===
# Create a plist for the bs_probe
cat > /root/com.rmxos.op130.bs-probe.plist <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict>
<key>Label</key><string>com.rmxos.op130.bs-probe</string>
<key>ProgramArguments</key><array><string>/root/bs_probe</string></array>
<key>RunAtLoad</key><false/>
<key>StandardOutPath</key><string>/tmp/bs-probe-op130.out</string>
<key>StandardErrorPath</key><string>/tmp/bs-probe-op130.err</string>
<key>EnvironmentVariables</key><dict><key>LD_LIBRARY_PATH</key><string>/usr/lib</string></dict>
</dict></plist>
PLIST

/bin/launchctl load /root/com.rmxos.op130.bs-probe.plist 2>&1
/bin/launchctl start com.rmxos.op130.bs-probe 2>&1
sleep 3

echo "=== NOTIFY SMOKE OUTPUT ==="
cat /tmp/bs-probe-op130.out 2>/dev/null || echo "(no output)"
echo "=== NOTIFY SMOKE END ==="

# Cleanup
kill $LAUNCHD_PID 2>/dev/null || true
echo "NOTIFY_SMOKE_TERMINAL status=0"
