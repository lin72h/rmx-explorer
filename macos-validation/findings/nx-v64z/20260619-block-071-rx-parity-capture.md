# Block 071 rx parity capture

mode: explorer
date: 2026-06-19
lane: parity capture
scope: rx-side only, read-only toward rmxOS source

## Findings

1. The 12 macOS Mach probes build and link against the rmxOS Mach surface.
   This is a positive API-surface parity datum. The build used the staged
   rmxOS libmach prefix at `/Users/me/wip-mach/build/m7a-libmach-prefix`.

2. A dedicated parity image was used, separate from Oracle evidence-gate
   staging. Stale evidence rc entries were disabled on that parity copy, and
   the final run used an explicit `/etc/rc.local` probe launcher.

3. The guest executed all 12 probes, but the run is not a clean rx vector
   baseline. All 12 probes returned failure/error, three descriptor result
   JSON files are zero bytes, and `parse-serial.py` failed closed because Mach
   kernel diagnostics appeared inside the `nxplatform probe` serial envelope.

4. No fresh macOS 27 `mx-a64z` reference was available in GitHub at this run.
   The only committed `mx-a64z` references remain the older macOS 26.5
   directories. No macOS-27-vs-rx mismatch table was produced.

## Parity Staging

- Work directory:
  `/Users/me/wip-mach/build/macos-validation-rx-parity-20260619T033244Z`
- Dedicated image:
  `/Users/me/wip-mach/vm/runs/nxplatform-rx-parity-20260619T033244Z.img`
- Source image copied from:
  `/Users/me/wip-mach/vm/runs/nxplatform-dev.img`
- Runtime source tree:
  `/Users/me/wip-mach/freebsd-src-official-stable-15`
- Runtime branch/commit:
  `rmx/official-stable15-mach @ 524d71df420e7c22fcd8fb03e7e9939c808c8971`
- Kernel config:
  `MACHDEBUGDEBUG`
- Kernel SHA256:
  `39031adb1267455043f6b04f4e073dbb975e8aa91d80a7808fd9b92a2ec63fb5`
- `mach.ko` SHA256:
  `49ac3d8970449817ebca964e0005ea05bfb2294b341425d9f54f8fcdadfeccc5`

Stale rc entries disabled on the parity image:

- `nxplatform_phase07_*`
- `nxplatform_phase095a_notifyd_n2_concurrency`
- `nxplatform_phase095b_notifyd_n2c2b_client_death`
- `nxplatform_phase1_launchd_harness`
- `twqprobe`
- `nxplatform_probe` rc.d entry, replaced by explicit `/etc/rc.local`

The final active custom rc scan was empty. The final `/etc/rc.local` ran
`/root/nxplatform/nxplatform-probe`, printed the start/end envelope, recorded
`rx_parity_probe_exit=1`, then shut down the parity guest.

## Build And Stage Verification

Build status:

| Probe | Status |
| --- | --- |
| `foundation/smoke` | `build_ok` |
| `foundation/port_names` | `build_ok` |
| `foundation/port_type` | `build_ok` |
| `foundation/port_get_refs` | `build_ok` |
| `m1/header_copy_send_accounting` | `build_ok` |
| `m1/header_move_send_accounting` | `build_ok` |
| `m2/descriptor_copy_send` | `build_ok` |
| `m2/descriptor_move_send` | `build_ok` |
| `m2/send_once_descriptor` | `build_ok` |
| `m2/invalid_descriptor_disposition` | `build_ok` |
| `m2/dead_name_descriptor_right` | `build_ok` |
| `m2/double_move_send_descriptor` | `build_ok` |

Stage verification:

- Staged binary count: `12`
- All 12 staged probe binaries compared equal to the host-built binaries.
- The serial run confirms all 12 staged probes executed.

## Runtime Capture

- Serial:
  `/Users/me/wip-mach/build/macos-validation-rx-parity-20260619T033244Z/rx-parity.serial.log`
- Host log:
  `/Users/me/wip-mach/build/macos-validation-rx-parity-20260619T033244Z/rx-parity.host.log`
- Raw guest rc:
  `/Users/me/wip-mach/build/macos-validation-rx-parity-20260619T033244Z/run-guest.rc`
  contains `1`.
- Extracted local result directory:
  `macos-validation/results/rx/20260619T154124Z-rmxos-mach-guest`
- Guest result path:
  `/root/nxplatform/macos-validation/results/rx/20260619T154124Z-rmxos-mach-guest`

The result directory is intentionally not committed as a baseline because it is
not parse-clean. It contains 9 valid probe JSON files and 3 zero-byte `.json`
files.

`macos-validation/harness/validate_json.sh` result:

- `12` probe JSON paths inspected
- `9` pass
- `3` fail as invalid JSON:
  - `m2_descriptor_copy_send.json`
  - `m2_descriptor_move_send.json`
  - `m2_send_once_descriptor.json`

`parse-serial.py` failed closed with `status=error` and
`reason=malformed_json`. The malformed lines were raw kernel/probe diagnostics,
including:

- `ipc_right_lookup failed: msgt=17 kr=15`
- `ipc_entry_lookup failed on 16 /usr/src/sys/compat/mach/ipc/ipc_kmsg.c:1318`
- `Alarm clock`
- `/usr/src/sys/compat/mach/ipc/ipc_right.c:1528 bits: 00020000`

## Probe Outcome Summary

| Probe | Runtime result | Notes |
| --- | --- | --- |
| `foundation/port_get_refs` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `foundation/port_names` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `foundation/port_type` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `foundation/smoke` | `fail` | port namespace did not return to baseline; before/after `mach_port_names` returned `KERN_0x2e` (`46`) |
| `m1/header_copy_send_accounting` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `m1/header_move_send_accounting` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `m2/dead_name_descriptor_right` | `fail` | dead/nonexistent descriptor source behavior differs from accepted macOS contract |
| `m2/descriptor_copy_send` | `error`, rc `142` | zero-byte JSON; `Alarm clock`; repeated `ipc_entry_lookup` diagnostics |
| `m2/descriptor_move_send` | `error`, rc `142` | zero-byte JSON; `Alarm clock`; repeated `ipc_entry_lookup` diagnostics |
| `m2/double_move_send_descriptor` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`); kernel diagnostic at `ipc_right.c:1528` |
| `m2/invalid_descriptor_disposition` | `probe_failure` | `mach_port_names_before` returned `KERN_0x2e` (`46`) |
| `m2/send_once_descriptor` | `error`, rc `142` | zero-byte JSON; `Alarm clock`; repeated `ipc_entry_lookup` diagnostics |

## Current Classification

- API/header/lib surface: `exact` enough to build all 12 probes against rmxOS
  libmach.
- Runtime parity: `rmxOS-gap`.
- Intrusiveness tag: `kernel-mach-ipc`, because the earliest shared failure is
  `mach_port_names(...) -> KERN_0x2e`, and the descriptor probes expose Mach IPC
  kernel diagnostics and timeouts.
- Serial contract: `capture-gap`, because non-JSON diagnostics appeared inside
  the JSON serial envelope.

## Smallest Requirements

1. For a clean rx vector baseline, the rx parity runner must keep raw kernel
   diagnostics out of the `=== nxplatform probe start/end ===` JSON envelope,
   or emit them as structured JSON diagnostic records that `parse-serial.py`
   accepts. The parser correctly failed closed for the current malformed
   envelope.

2. For foundational Mach parity, rmxOS must satisfy the `mach_port_names`
   contract used by the foundation probes: `mach_port_names(mach_task_self(),
   ...)` must return `KERN_SUCCESS` and allow before/after namespace comparison.

3. For descriptor parity, the M2 descriptor probes need the relevant send,
   receive, right-transfer, dead-name, and timeout behavior to complete without
   SIGALRM and without zero-byte result files. The earliest descriptor-specific
   diagnostics in this run are the `ipc_entry_lookup` failures in
   `ipc_kmsg.c:1318`.

4. For macOS-vs-rx comparison, a fresh macOS 27 `mx-a64z` reference still needs
   to be pushed. Until then, the mismatch list is intentionally absent.
