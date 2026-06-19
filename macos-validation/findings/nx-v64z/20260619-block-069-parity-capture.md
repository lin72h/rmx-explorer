# block-069 parity capture

Date: 2026-06-19
Owner lane: nx-v64z
Mode: explorer parity capture

## Scope

This note records the first attempt to sync `mach-oracle`, capture fresh
`mx-a64z` macOS 27 vectors, capture fresh `rx` vectors, and synthesize the
first mismatch view. It is non-blocking and is not an Oracle evidence gate.

## GitHub Sync

- Repository: `git@github.com:lin72h/mach-oracle.git`
- Local branch pushed: `main`
- Pushed commit: `359e7d78b00af9ff2fa9a47a713f90581b1f8f2d`
- Push result: success

## mx-a64z macOS 27 Capture

Status: blocked before clone/build/run.

The requested host `mm4.local` was not resolvable from this Oracle host:

```text
ssh: Could not resolve hostname mm4.local: Name does not resolve
```

No macOS 27 environment was captured. No `mx-a64z` vectors were generated, and
no macOS 27 probe was classified as pass, fail, version-sensitive, or
not-observable. No reference vector was invented from older committed
`mx-a64z` results.

Smallest requirement to continue: provide a resolvable SSH target for the
macOS 27 machine, or repair DNS/mDNS for `mm4.local`, then rerun:

```sh
cd macos-validation
make
make run AGENT=mx-a64z
```

## Local rx Schema Capture

Status: captured on the current non-Darwin host as the package-defined `rx`
lane only. This is not real rmxOS Mach behavior. This host identity was
recorded in the generated environment:

```text
FreeBSD bdw-fx15-x64z 15.0-RELEASE FreeBSD 15.0-RELEASE releng/15.0-n280995-7aedc8de6446 GENERIC amd64
```

Result directory:

```text
macos-validation/results/rx/20260619-FreeBSD-15.0-RELEASE
```

Fresh probe summary:

- Total probes: 12
- Pass: 0
- Fail: 0
- Skip: 12

This is consistent with `macos-validation/README.md`: the non-macOS `rx` lane
proves the harness and schema only, and Mach probes are expected to report
`skip` without a supported Mach environment.

Validation:

```text
make validate-json
Validated: 50 files, 50 pass, 0 fail
```

## rmxOS Mach Guest rx Capture

Status: stopped before real rx vectors were produced.

Build method:

- Host-built the 12 `macos-validation` probes as real Mach probes with the
  staged rmxOS libmach prefix:
  `/Users/me/wip-mach/build/m7a-libmach-prefix`.
- Build flags enabled the probe code's Mach path and linked
  `libmach.a` plus `libmach-traps.a`.
- Build output:
  `/Users/me/wip-mach/build/macos-validation-rx-real-mach/bin`.
- Result: all 12 probe binaries built.

Guest staging method:

- Reused the existing bhyve image and source staging path.
- Runtime source:
  `/Users/me/wip-mach/freebsd-src-official-stable-15`
  `rmx/official-stable15-mach @ 524d71df420e7c22fcd8fb03e7e9939c808c8971`.
- Kernel:
  `39031adb1267455043f6b04f4e073dbb975e8aa91d80a7808fd9b92a2ec63fb5`.
- `mach.ko`:
  `49ac3d8970449817ebca964e0005ea05bfb2294b341425d9f54f8fcdadfeccc5`.
- Installed a temporary `/root/nxplatform/nxplatform-probe` wrapper plus the
  12 built probe binaries under `/root/nxplatform/macos-validation/bin`.

Guest run result:

- Serial:
  `/Users/me/wip-mach/build/macos-validation-rx-real-mach/rx-guest.serial.log`.
- Raw `run-guest` rc: `1`.
- No `=== nxplatform probe start ===` envelope appeared.
- No `nx-v64z.macos-oracle.v1` rx result JSON appeared.
- No real rx probe vector was produced.

The guest instead ran a stale notifyd N2C2B service path and shut down:

```text
=== phase095b notifyd n2c2b client-death start ===
...
NOTIFYD_N2C2B_TERMINAL status=0
phase095b_notifyd_n2c2b_exit=0
=== phase095b notifyd n2c2b client-death end rc=0 ===
Shutdown NOW!
```

Read-only image inspection identified the stale enabled path:

```text
/etc/rc.d/nxplatform_phase095b_notifyd_n2c2b_client_death
```

That rc script defaults itself to enabled:

```sh
: ${nxplatform_phase095b_notifyd_n2c2b_client_death_enable:=YES}
```

It launches the old N2C2B harness path:

```text
/root/nxplatform/phase1/launchd-harness
/root/nxplatform/notifyd/notifyd-n2-server
/root/nxplatform/notifyd/notifyd-n2c2b-client-death
/root/nxplatform/phase1/org.rmxos.notifyd.n2.concurrency.plist
```

Smallest requirement to produce real rx vectors: add a fail-closed rx parity
staging path that proves the staged root has only the `macos-validation` rx
probe runner enabled, or explicitly disables/removes stale
`nxplatform_phase095b_*`, notifyd, ASL, Phase07, and Phase1 rc paths before the
guest boot. The host preflight must verify the staged rc state, the exact
`/root/nxplatform/nxplatform-probe` wrapper, and the 12 staged probe binaries
before running the guest.

## Mismatch View

Status: not produced.

Reason: the requested fresh `mx-a64z` macOS 27 reference vector does not exist
because `mm4.local` was unreachable. The real rmxOS guest rx vector also does
not exist yet because stale rc state preempted the parity runner. Comparing the
local skip-only lane against older macOS 26.x committed vectors would not
answer this request and would risk presenting stale references as macOS 27
data.

Mismatch count: 0 generated.

## Next Hop

First fix rx guest staging exclusivity so the bhyve guest runs only the
`macos-validation` probe wrapper. In parallel, resolve `mm4.local` SSH
reachability and capture fresh `mx-a64z` macOS 27 vectors. Then synthesize the
first mismatch list from fresh `mx-a64z` and real guest `rx` result JSON.
