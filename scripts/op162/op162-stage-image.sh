#!/bin/sh
# op162-stage-image.sh — THIN GLUE (per op-147m).
# Stages an image for op-162 asl leg-2 traced conformance.
# Base: golden leg4-soak.img (op-123 lineage, launchd + overlay libs).
# Overlays (mirror op-124 staging pattern):
#   - /usr/sbin/asld                 (op-144 fixed binary)
#   - /usr/lib/libasl.so.1           (op-144 fixed)
#   - /etc/launchd.d/com.apple.syslogd.plist  (op-138 syslogd-asld plist)
#   - /etc/rc.d/syslogd → .disabled  (op-145 pattern)
#   - /root/asl-harness              (built for op-124)
#   - /root/op162-trace.d.tmpl       (the .d template — pid substituted at runtime)
#   - /root/com.rmxos.op162.asl-harness.plist  (launchd-JOB plist)
#   - /etc/rc.local                  (op-162 thin glue)
set -eu

repo_root=/Users/me/wip-mach/rmx-explorer
golden=/Users/me/wip-mach/build/op123-leg4/leg4-soak.img
image_guard=/Users/me/wip-mach/wip-gpt/scripts/bhyve/image-staging-guard.sh
obj_root=/Users/me/wip-mach/build/block-075-alpha-final-obj/Users/me/wip-mach/wip-gpt/wip-rmxos/amd64.amd64

asld_src="$obj_root/usr.sbin/asl/asld"
libasl_src="$obj_root/lib/libasl/libasl.so.1"
plist_src="$repo_root/fixtures/launchd/com.apple.syslogd.plist"
harness_src="$repo_root/findings/nx-r64z/dtrace/asl-conformance/asl-harness"
trace_d_src="$repo_root/findings/nx-r64z/dtrace/asl-leg2-traced/op162-trace.d.tmpl"
harness_plist_src="$repo_root/findings/nx-r64z/dtrace/asl-leg2-traced/com.rmxos.op162.asl-harness.plist"
rclocal_src="$repo_root/scripts/op162/op162-rc.local.template"

for f in "$golden" "$image_guard" "$asld_src" "$libasl_src" "$plist_src" \
         "$harness_src" "$trace_d_src" "$harness_plist_src" "$rclocal_src"; do
	[ -e "$f" ] || { echo "missing: $f" >&2; exit 64; }
done

out_image="${1:-/Users/me/wip-mach/build/op162-leg2/op162-leg2.img}"
mkdir -p "$(dirname "$out_image")"

echo "[op162-stage] cp golden → $out_image"
cp "$golden" "$out_image"

. "$image_guard"
lock="${out_image}.lock"
guest_root="$(dirname "$out_image")/guest-root"
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
root_part="/dev/${mddev}p4"
doas fsck -p "$root_part" 2>/dev/null || true
doas mount -o rw -t ufs "$root_part" "$guest_root"

doas install -m 755 "$asld_src" "$guest_root/usr/sbin/asld"
doas install -m 755 "$libasl_src" "$guest_root/usr/lib/libasl.so.1"
doas install -m 644 "$plist_src" "$guest_root/etc/launchd.d/com.apple.syslogd.plist"
if [ -e "$guest_root/etc/rc.d/syslogd" ] && [ ! -e "$guest_root/etc/rc.d/syslogd.disabled" ]; then
	doas mv "$guest_root/etc/rc.d/syslogd" "$guest_root/etc/rc.d/syslogd.disabled"
fi
doas install -m 755 "$harness_src" "$guest_root/root/asl-harness"
doas install -m 644 "$trace_d_src" "$guest_root/root/op162-trace.d.tmpl"
doas install -m 644 "$harness_plist_src" "$guest_root/root/com.rmxos.op162.asl-harness.plist"
doas install -m 755 "$rclocal_src" "$guest_root/etc/rc.local"

doas umount "$guest_root"
nxplatform_image_guard_cleanup "$mddev" "$lock"
mddev=
trap - EXIT INT TERM

printf 'op162_stage_status=0 image=%s\n' "$out_image"
