#!/bin/sh
# op134-stage-image.sh — stage the op-134 cold-boot image.
#
# Copies the op-128 dev-preview image (which already ships launchd, launchctl,
# notifyd, bs_probe, run-as-launchd-job.sh, libs) and overlays THREE files:
#   1. /etc/launchd.d/com.apple.notifyd.plist  — clean notifyd autostart plist
#   2. /etc/launchd.d/com.apple.notifyd.json   — clean notifyd autostart json
#   3. /etc/rc.local                           — op-134 cold-boot probe
#
# The op-128 image ships syslogd + devd in /etc/launchd.d/ but NOT notifyd (the
# op-134 gap). This overlay closes it. On boot, rc.local starts launchd (the
# rmxOS boot mechanism — launchd is not PID 1, bl-016) and reports whether
# notifyd auto-started from /etc/launchd.d/ with no manual launchctl load.
#
# Usage: op134-stage-image.sh [OUT_IMAGE]
#   OUT_IMAGE defaults to a run-dir under build/op134-coldboot/.
set -eu

repo_root=/Users/me/wip-mach/rmx-explorer
src_image=/Users/me/wip-mach/build/op128-dev-preview/dev-preview-memstick.img
image_guard=/Users/me/wip-mach/wip-gpt/scripts/bhyve/image-staging-guard.sh

plist_src="$repo_root/fixtures/launchd/com.apple.notifyd.plist"
json_src="$repo_root/fixtures/launchd/com.apple.notifyd.json"
rclocal_src="$repo_root/scripts/op134/op134-coldboot-probe.sh"

for f in "$src_image" "$image_guard" "$plist_src" "$json_src" "$rclocal_src"; do
	[ -e "$f" ] || { echo "missing: $f" >&2; exit 64; }
done

outdir=/Users/me/wip-mach/build/op134-coldboot
mkdir -p "$outdir"
out_image="${1:-$outdir/op134-coldboot.img}"
lock="${out_image}.lock"
guest_root="$outdir/guest-root"

echo "[op134-stage] copying base image → $out_image"
cp "$src_image" "$out_image"

. "$image_guard"

mddev=
cleanup() {
	if doas mount | awk '{print $3}' | grep -Fxq "$guest_root"; then
		doas umount "$guest_root" || true
	fi
	if [ -n "${mddev:-}" ]; then
		nxplatform_image_guard_cleanup "$mddev" "$lock"
	else
		nxplatform_image_guard_release_lock "$lock"
	fi
}
trap cleanup EXIT INT TERM

doas mkdir -p "$guest_root"
guest_root=$(CDPATH= cd -- "$guest_root" && pwd)
nxplatform_image_guard_attach "$out_image" "$lock" mddev

# op-128 image is MBR: ${mddev}s2 = freebsd slice, ${mddev}s2a = freebsd-ufs root
root_part="/dev/${mddev}s2a"
doas fsck -p "$root_part" 2>/dev/null || true
doas mount -o rw -t ufs "$root_part" "$guest_root"

echo "[op134-stage] overlaying notifyd plist + json into /etc/launchd.d/"
doas install -m 644 "$plist_src" "$guest_root/etc/launchd.d/com.apple.notifyd.plist"
doas install -m 644 "$json_src"  "$guest_root/etc/launchd.d/com.apple.notifyd.json"

echo "[op134-stage] overlaying op-134 cold-boot probe → /etc/rc.local"
doas install -m 755 "$rclocal_src" "$guest_root/etc/rc.local"

echo "[op134-stage] /etc/launchd.d/ contents after overlay:"
doas ls -la "$guest_root/etc/launchd.d/" | sed 's/^/  /'

# Sanity: confirm the runtime artifacts the rc.local expects are present on the
# op-128 base (bs_probe, run-as-launchd-job.sh, notifyd, launchd, launchctl).
for check in root/bs_probe root/run-as-launchd-job.sh usr/sbin/notifyd \
             sbin/launchd bin/launchctl; do
	if [ ! -e "$guest_root/$check" ]; then
		echo "[op134-stage] WARN: missing on base image: /$check" >&2
	fi
done

doas umount "$guest_root"
mddev_snapshot="$mddev"
nxplatform_image_guard_cleanup "$mddev" "$lock"
mddev=
# guard cleanup ran; release lock consumed. Reset trap so EXIT doesn't double-run.
trap - EXIT INT TERM

printf 'op134_stage_status=0 image=%s\n' "$out_image"
