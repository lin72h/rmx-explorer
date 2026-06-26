#!/bin/sh
# op151-stage-image.sh — THIN GLUE (per op-147m), NOT a harness.
# Stages a fresh throwaway clone of the golden leg4-soak.img with:
#   - op-150 C churn probe (binary) at /root/notify-churn-probe
#   - op-150 churn plist at /root/com.rmxos.op150.churn.plist
#   - op-148 watchpoint .d at /root/op148-freeze-watchpoint.d
#   - op-151 thin-glue rc.local at /etc/rc.local
#   - rc.d/syslogd renamed to .disabled (op-145 pattern)
#
# The rc.local does NOT emit OP151_ verdicts (those come from the Elixir
# conductor parsing serial). It just kldloads + starts launchd + starts
# the watchpoint + starts the churn probe. Pure setup, no assertions.
#
# Usage: op151-stage-image.sh OUT_IMAGE SOAK_DURATION
#   OUT_IMAGE   — path to write the staged image (caller chooses).
#   SOAK_DURATION — passed to the rc.local as the env value for the churn probe.
set -eu

out_image="$1"
soak_duration="${2:-900}"

repo_root=/Users/me/wip-mach/rmx-explorer
golden=/Users/me/wip-mach/build/op123-leg4/leg4-soak.img
image_guard=/Users/me/wip-mach/wip-gpt/scripts/bhyve/image-staging-guard.sh

probe_bin="$repo_root/findings/nx-r64z/dtrace/id025-watchpoint/op150-probe/notify-churn-probe"
probe_plist_template="$repo_root/scripts/op151/op151-churn-probe.plist.tmpl"
watchpoint_d="$repo_root/findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d"
rclocal_template="$repo_root/scripts/op151/op151-rc.local.template"

for f in "$golden" "$image_guard" "$probe_bin" "$probe_plist_template" "$watchpoint_d" "$rclocal_template"; do
	[ -e "$f" ] || { echo "missing: $f" >&2; exit 64; }
done

# Render the rc.local + plist with the SOAK_DURATION substituted in.
# (launchctl uses the plist's EnvironmentVariables, not the parent shell's —
# must substitute in both.)
rclocal_rendered="$(mktemp)"
plist_rendered="$(mktemp)"
trap 'rm -f "$rclocal_rendered" "$plist_rendered"' EXIT
sed "s|@@SOAK_DURATION@@|$soak_duration|g" "$rclocal_template" > "$rclocal_rendered"
sed "s|@@SOAK_DURATION@@|$soak_duration|g" "$probe_plist_template" > "$plist_rendered"

# Copy golden → out_image.
echo "[op151-stage] cp golden → $out_image"
mkdir -p "$(dirname "$out_image")"
cp "$golden" "$out_image"

. "$image_guard"

lock="${out_image}.lock"
guest_root="$(dirname "$out_image")/guest-root-$(basename "$out_image")"
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

# leg4-soak.img is GPT: /dev/${mddev}p4 = freebsd-ufs root.
root_part="/dev/${mddev}p4"
doas fsck -p "$root_part" 2>/dev/null || true
doas mount -o rw -t ufs "$root_part" "$guest_root"

doas install -m 755 "$probe_bin" "$guest_root/root/notify-churn-probe"
doas install -m 644 "$plist_rendered" "$guest_root/root/com.rmxos.op150.churn.plist"
doas install -m 644 "$watchpoint_d" "$guest_root/root/op148-freeze-watchpoint.d"
doas install -m 755 "$rclocal_rendered" "$guest_root/etc/rc.local"

# rc.d/syslogd rename (op-145 pattern — prevent stock syslogd collision).
if [ -e "$guest_root/etc/rc.d/syslogd" ] && [ ! -e "$guest_root/etc/rc.d/syslogd.disabled" ]; then
	doas mv "$guest_root/etc/rc.d/syslogd" "$guest_root/etc/rc.d/syslogd.disabled"
fi

doas umount "$guest_root"
nxplatform_image_guard_cleanup "$mddev" "$lock"
mddev=
trap - EXIT INT TERM

printf 'op151_stage_status=0 image=%s soak_duration=%s\n' "$out_image" "$soak_duration"
