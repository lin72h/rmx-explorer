#!/bin/sh
# op124-stage-image.sh — stage the op-124 asl leg-1 lifecycle image.
#
# Throwaway copy of build/op123-leg4/leg4-soak.img (proven launchd + overlay libs
# + asld-harness base per op-145 v3 PASS). Overlays:
#   1. /usr/sbin/asld                       — op-144 FIXED binary (161120 B, no __elf_aux_vector)
#   2. /usr/lib/libasl.so.1                 — op-144 FIXED (219688 B; already on base, idempotent overlay)
#   3. /etc/launchd.d/com.apple.syslogd.plist — op-138 syslogd-asld plist (rmx-explorer fixture)
#   4. /etc/rc.d/syslogd → /etc/rc.d/syslogd.disabled — prevent stock FreeBSD syslogd collision
#   5. /root/asl-harness                    — built asl round-trip probe (findings/nx-r64z/dtrace/asl-conformance/)
#   6. /etc/rc.local                        — op124-lifecycle-probe.rc
#
# leg4-soak.img is GPT-partitioned: /dev/${mddev}p4 = freebsd-ufs root.
set -eu

repo_root=/Users/me/wip-mach/rmx-explorer
src_image=/Users/me/wip-mach/build/op123-leg4/leg4-soak.img
image_guard=/Users/me/wip-mach/wip-gpt/scripts/bhyve/image-staging-guard.sh
obj_root=/Users/me/wip-mach/build/block-075-alpha-final-obj/Users/me/wip-mach/wip-gpt/wip-rmxos/amd64.amd64

asld_src="$obj_root/usr.sbin/asl/asld"
libasl_src="$obj_root/lib/libasl/libasl.so.1"
plist_src="$repo_root/fixtures/launchd/com.apple.syslogd.plist"
harness_src="$repo_root/findings/nx-r64z/dtrace/asl-conformance/asl-harness"
rclocal_src="$repo_root/scripts/op124/op124-lifecycle-probe.rc"

for f in "$src_image" "$image_guard" "$asld_src" "$libasl_src" "$plist_src" "$harness_src" "$rclocal_src"; do
	[ -e "$f" ] || { echo "missing: $f" >&2; exit 64; }
done

outdir=/Users/me/wip-mach/build/op124-leg1
mkdir -p "$outdir"
out_image="${1:-$outdir/op124-leg1.img}"
lock="${out_image}.lock"
guest_root="$outdir/guest-root"

echo "[op124-stage] copying base image → $out_image"
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

# leg4-soak.img is GPT: /dev/${mddev}p4 = freebsd-ufs root
root_part="/dev/${mddev}p4"
doas fsck -p "$root_part" 2>/dev/null || true
doas mount -o rw -t ufs "$root_part" "$guest_root"

echo "[op124-stage] overlaying op-144 FIXED asld (161120 B) → /usr/sbin/asld"
doas install -m 755 "$asld_src" "$guest_root/usr/sbin/asld"

echo "[op124-stage] overlaying op-144 FIXED libasl.so.1 (219688 B) → /usr/lib/libasl.so.1"
doas install -m 755 "$libasl_src" "$guest_root/usr/lib/libasl.so.1"

echo "[op124-stage] overlaying op-138 syslogd-asld plist → /etc/launchd.d/com.apple.syslogd.plist"
doas install -m 644 "$plist_src" "$guest_root/etc/launchd.d/com.apple.syslogd.plist"

echo "[op124-stage] renaming /etc/rc.d/syslogd → .disabled (prevent stock syslogd collision)"
if [ -e "$guest_root/etc/rc.d/syslogd" ] && [ ! -e "$guest_root/etc/rc.d/syslogd.disabled" ]; then
	doas mv "$guest_root/etc/rc.d/syslogd" "$guest_root/etc/rc.d/syslogd.disabled"
fi

echo "[op124-stage] overlaying asl round-trip probe → /root/asl-harness"
doas install -m 755 "$harness_src" "$guest_root/root/asl-harness"

echo "[op124-stage] overlaying op-124 lifecycle probe → /etc/rc.local"
doas install -m 755 "$rclocal_src" "$guest_root/etc/rc.local"

echo
echo "[op124-stage] post-overlay sanity (the 6 files Arranger requires):"
for f in sbin/launchd bin/launchctl usr/sbin/asld usr/lib/libasl.so.1 \
         usr/lib/libmach.so.5 usr/lib/libdispatch.so.5 usr/lib/liblaunch.so.5 \
         root/run-as-launchd-job.sh root/asl-harness etc/rc.local; do
	if [ -e "$guest_root/$f" ]; then
		sz=$(stat -f "%z" "$guest_root/$f" 2>/dev/null)
		printf '  /%-40s size=%s PRESENT\n' "$f" "$sz"
	else
		printf '  /%-40s ABSENT (setup-fail — not consumed)\n' "$f"
	fi
done

echo
echo "[op124-stage] rc.d/syslogd state after rename:"
doas ls -la "$guest_root/etc/rc.d/" 2>&1 | grep -E "syslogd" | sed 's/^/  /'

doas umount "$guest_root"
nxplatform_image_guard_cleanup "$mddev" "$lock"
mddev=
trap - EXIT INT TERM

printf 'op124_stage_status=0 image=%s\n' "$out_image"
