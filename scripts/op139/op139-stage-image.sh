#!/bin/sh
# op139-stage-image.sh — stage the op-139 auxv-confirm image.
#
# Copies the op-128 dev-preview base image (which already ships launchd,
# launchctl, run-as-launchd-job.sh, libs) and overlays THREE files:
#   1. /root/auxv-probe              — the op-139 C probe (built host-cross)
#   2. /etc/rc.local                 — op-139 auxv two-way probe (rc + launchd)
#   3. (no plist — run-as-launchd-job.sh generates a transient one at boot)
#
# Same base image as op-134 cold-boot — keeps the runtime surface identical
# so the auxv comparison reflects "launchd child vs FreeBSD-init child", not
# "different images".
#
# Usage: op139-stage-image.sh [OUT_IMAGE]
set -eu

repo_root=/Users/me/wip-mach/rmx-explorer
src_image=/Users/me/wip-mach/build/op128-dev-preview/dev-preview-memstick.img
image_guard=/Users/me/wip-mach/wip-gpt/scripts/bhyve/image-staging-guard.sh
auxv_probe_src="$repo_root/findings/nx-r64z/dtrace/auxv-confirm/auxv-probe"
rclocal_src="$repo_root/scripts/op139/op139-auxv-probe.rc"

for f in "$src_image" "$image_guard" "$auxv_probe_src" "$rclocal_src"; do
	[ -e "$f" ] || { echo "missing: $f" >&2; exit 64; }
done

outdir=/Users/me/wip-mach/build/op139-auxv-confirm
mkdir -p "$outdir"
out_image="${1:-$outdir/op139-auxv.img}"
lock="${out_image}.lock"
guest_root="$outdir/guest-root"

echo "[op139-stage] copying base image → $out_image"
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

echo "[op139-stage] overlaying auxv-probe → /root/auxv-probe"
doas install -m 755 "$auxv_probe_src" "$guest_root/root/auxv-probe"

echo "[op139-stage] overlaying op-139 rc.local → /etc/rc.local"
doas install -m 755 "$rclocal_src" "$guest_root/etc/rc.local"

echo "[op139-stage] /root/ contents after overlay (auxv-probe + run-as-launchd-job.sh):"
doas ls -la "$guest_root/root/" 2>&1 | sed 's/^/  /'

# Sanity: confirm the runtime artifacts the rc.local expects are present on the
# op-128 base.
for check in root/run-as-launchd-job.sh root/auxv-probe \
             sbin/launchd bin/launchctl; do
	if [ ! -e "$guest_root/$check" ]; then
		echo "[op139-stage] WARN: missing on staged image: /$check" >&2
	fi
done

doas umount "$guest_root"
mddev_snapshot="$mddev"
nxplatform_image_guard_cleanup "$mddev" "$lock"
mddev=
trap - EXIT INT TERM

printf 'op139_stage_status=0 image=%s\n' "$out_image"
