# block-073 rx parity catalog

Mode: explorer
Lane: parity capture, build-infra and catalog phase
Date: 2026-06-19

## Scope

This note records the first clean rmxOS guest capture for the nx-v64z Mach
probe set after isolating parity staging from evidence-gate staging. Oracle did
not edit the rmxOS source tree. Current rmxOS behavior is cataloged as the 1.0
baseline; gaps below are tracked ledger items, not fixes.

## Inputs

- rx image: `/Users/me/wip-mach/vm/runs/nxplatform-rx-parity-20260619T073000Z.img`
- rx work dir: `/Users/me/wip-mach/build/macos-validation-rx-parity-20260619T073000Z`
- rx result dir: `macos-validation/results/rx/20260619T161752Z-rmxos-mach-guest`
- rx serial: `rx-parity-final.serial.log`
- rx runtime source: `/Users/me/wip-mach/freebsd-src-official-stable-15`
- rx runtime branch: `rmx/official-stable15-mach`
- rx runtime commit: `524d71df420e7c22fcd8fb03e7e9939c808c8971`
- mx-a64z reference: `macos-validation/results/mx-a64z/20260619-27.0-27.0.0`

## Infra Results

- Distinct parity image used; evidence-gate image not touched.
- Stale rc paths disabled on the parity image:
  `nxplatform_phase07_*`, `nxplatform_phase095a_*`,
  `nxplatform_phase095b_*`, `nxplatform_phase1_launchd_harness`, and
  `twqprobe`.
- Startup path reduced to `/etc/rc.local -> /root/nxplatform/nxplatform-probe`.
- Staged wrapper present at `/root/nxplatform/nxplatform-probe`.
- All 12 probe binaries staged under
  `/root/nxplatform/macos-validation/.build/bin`.
- All 12 staged binaries compare equal to the host cross-built binaries.
- Kernel diagnostics are outside the `=== nxplatform probe start/end ===`
  serial JSON envelope.
- `parse-serial.py` produced valid JSON. It returned rc=1 because four probe
  records intentionally carry failure status, not because of malformed serial
  JSON.
- Result JSON validation passed for all 12 result files.
- Zero-byte JSON result files: 0.

## Positive Data

The full 12-probe set builds and links against the rmxOS Mach surface. The
guest run also proves real runtime success for these 8 probes:

| Probe | rx status | Notes |
| --- | --- | --- |
| `foundation/smoke` | pass | Allocate/type/get_refs/destroy works; `mach_port_names` baseline is unsupported but no longer blocks the probe. |
| `foundation/port_get_refs` | pass | Receive/send uref accounting works. |
| `foundation/port_type` | pass | Receive, send-receive, port-set, and task-self type observations work. |
| `m1/header_copy_send_accounting` | pass | Header `COPY_SEND` accounting works. |
| `m1/header_move_send_accounting` | pass | Header `MOVE_SEND` accounting works. |
| `m2/dead_name_descriptor_right` | pass | Dead-name descriptor accepted behavior matches the macOS contract. |
| `m2/double_move_send_descriptor` | pass | Duplicate MOVE_SEND descriptor failure/consumption behavior matches. |
| `m2/invalid_descriptor_disposition` | pass | Invalid descriptor disposition rejection behavior matches. |

## Cataloged rx Gaps

| ID | Probe(s) | Observed rx behavior | mx-a64z macOS 27 behavior | Classification | Intrusiveness | Smallest falsifiable requirement |
| --- | --- | --- | --- | --- | --- | --- |
| `rx-gap-mach-port-names` | `foundation/port_names`, baseline checks across most probes | `mach_port_names` returns `KERN_NOT_SUPPORTED` (`raw=46`). `foundation/port_names` fails because allocation/destroy visibility cannot be observed through names enumeration. | `mach_port_names` returns `KERN_SUCCESS` and observes the allocated port. | rmxOS-gap | medium | Implement task namespace enumeration for `mach_port_names`, including visibility of receive rights before/after allocate/destroy. |
| `rx-gap-descriptor-copy-send-child` | `m2/descriptor_copy_send` | Probe timed out under the 20s watchdog; structured fallback result emitted with rc=142. | pass | rmxOS-gap | high | Provide a bounded rmxOS reproducer for the two-process descriptor `COPY_SEND` path and determine whether the block is in descriptor transfer, child receive, or cleanup. |
| `rx-gap-descriptor-move-send-child` | `m2/descriptor_move_send` | Probe timed out under the 20s watchdog; structured fallback result emitted with rc=142. | pass | rmxOS-gap | high | Provide a bounded rmxOS reproducer for the two-process descriptor `MOVE_SEND` path and determine whether the block is in descriptor transfer, child receive, or cleanup. |
| `rx-gap-send-once-descriptor-child` | `m2/send_once_descriptor` | Probe timed out under the 20s watchdog; structured fallback result emitted with rc=142. | pass | rmxOS-gap | high | Provide a bounded rmxOS reproducer for send-once descriptor transfer and determine whether the block is in descriptor transfer, notification/deallocation, child receive, or cleanup. |

## Mismatch Summary

macOS 27 `mx-a64z` passes all 12 probes. rx matches the macOS-27 status for 8
probes, fails one `mach_port_names`-specific probe, and times out three
two-process descriptor probes. For the 8 passing rx probes, the only repeated
return-value delta against macOS is the weaker `mach_port_names` baseline:
macOS returns `KERN_SUCCESS`; rx returns `KERN_NOT_SUPPORTED`.

## Validation

- `sh -n macos-validation/harness/run_all.sh`
- `sh -n macos-validation/harness/collect_env.sh`
- `make -C macos-validation clean && make -C macos-validation`
- rmxOS guest run through the parity image
- `/Users/me/wip-mach/wip-gpt/scripts/bhyve/parse-serial.py rx-parity-final.serial.log`
- `macos-validation/harness/validate_json.sh macos-validation/results/rx/20260619T161752Z-rmxos-mach-guest`

## Guardrails

- No rmxOS source edits.
- No evidence-gate image mutation.
- No Oracle evidence disposition.
- No marker authority.
- No certification or parity-tag movement.
