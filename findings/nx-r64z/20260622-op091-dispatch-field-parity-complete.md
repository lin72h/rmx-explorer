# op-091 — dispatch field parity re-run: QoS gap closed; MACH_RECV-fire + dispatch_after-fire gaps surface

Date: 2026-06-22

Lane: `explorer-rx-x64z`

Op: op-091 (re-run `dispatch_mach_recv_source` + `dispatch_primitives` after op-090
exported the libthr QoS-attr pair). Closes the field-coverage gap op-089 deferred.

## Pins

```text
explorer-rx source head: 12df134
rmxOS source tree:        /Users/me/wip-mach/wip-gpt/wip-rmxos  (alpha)
rmxOS source head:        82d68c8e9c99  (libthr: export pthread attr QoS accessors)  [ON origin/alpha]
base image:               block-078-runtime-smoke/runs/20260619T112919Z-clean-check-token-smoke/block078-userland-smoke.img
run dir:                  block-078-runtime-smoke/runs/20260622T020329Z-op091-dispatch-qos
serial log sha256:        cfecc22ef989763de81358f95b8c095239e019669398c2f132d6e206d3b85da4
```

## op-089 QoS-symbol gap: CLOSED (running-image verified)

The staged guest `libthr.so.3` exports both QoS-attr accessors as `T@@FBSD_1.0`
(first-hand `nm -D` of the image, recorded in `staged-libthr-qos.txt`):

```text
T pthread_attr_get_qos_class_np@@FBSD_1.0
T pthread_attr_set_qos_class_np@@FBSD_1.0
```

Both probes ran to completion with **empty stderr** (no `ld-elf ... Undefined
symbol` crash) and emitted full `nx-r64z.macos-oracle.v1` JSON. The op-089
blocker is gone on the running image, not just at the source.

## Field-diff: dispatch_mach_recv_source — MISMATCH (core servicing invariant)

| field | rx-x64z | mx-a64z |
|---|---|---|
| `mach_recv_source_created` | true | true |
| `send_succeeded` | true | true |
| **`handler_fired_and_serviced`** | **false** | **true** |
| `mach_msg_receive_in_handler` | KERN_FAILURE | KERN_SUCCESS |
| `source_type` | DISPATCH_SOURCE_TYPE_MACH_RECV | (same) |
| `mach_port_names_before/after` | KERN_FAILURE (4294967295) | KERN_SUCCESS (11 / 13) |
| status | **fail** | pass |

rx note: "DISPATCH_SOURCE_TYPE_MACH_RECV did not fire + service the message".

On rmxOS the source is created and the message is sent, but the MACH_RECV
source's event handler never fires, so the message is never serviced through
dispatch. This is a genuine behavioral gap in dispatch_source MACH_RECV
event-delivery.

**Relation to op-081-R:** the block-078 smoke (op-084/op-085) proved rmxOS
services Mach-receive through TWQ at the notifyd level. This op shows that
victory does NOT extend to the `dispatch_source` MACH_RECV API path — the
source-firing machinery is not wired. So op-081-R's MACH_RECV fix is validated
at the notifyd/TWQ level but unproven (and currently failing) at the
`dispatch_source` API level. This is the single most load-bearing gap surfaced
in the op-082 field sweep.

## Field-diff: dispatch_primitives — MIXED (5/6 match, 1 gap)

| field | rx-x64z | mx-a64z |
|---|---|---|
| `dispatch_available` | true ✓ | true |
| `group_enter_leave_wait_ok` | true ✓ | true |
| `group_work_count` | 1 ✓ | 1 |
| `semaphore_timeout_observed` | true ✓ | true |
| `semaphore_signal_then_wait_ok` | true ✓ | true |
| **`dispatch_after_fired`** | **false** | **true** |
| status | **fail** | pass |

rx note: "dispatch_after_f handler did not fire within the bound".

Dispatch groups + semaphores are at field parity. The `dispatch_after` **timer**
handler does not fire on rmxOS within the probe's bound. This is a distinct
gap from mach_recv (timer event-delivery vs Mach-receive event-delivery) and
is NOT bl-002 (the known QoS-class-DEFAULT deviation) — it is a fresh
timer-source gap.

## Expected-divergence (non-gating)

`mach_port_names` returns KERN_FAILURE on rmxOS vs KERN_SUCCESS on macOS — the
known baseline-unsupported observable (see `nx_mach_utils.h`,
`nx_baseline_is_unsupported_gap`); `names_before/after` carry the 4294967295
sentinel and `cleanup_delta` reads 0 on rx for that reason. Not a mismatch.

## Classification summary

- `dispatch_global_queue_service` → match (op-089, unchanged).
- `dispatch_mach_recv_source` → **mismatch** — MACH_RECV source handler does not fire (op-081-R contract unmet at the dispatch_source API level).
- `dispatch_primitives` → **mixed** — groups + semaphores match; `dispatch_after` timer does not fire (fresh gap, not bl-002).

## Next hop

Per op-091 dispatch: mismatch → back to Coordinator with this diff for
adjudication. Two distinct Implementer targets surface:
1. wire `DISPATCH_SOURCE_TYPE_MACH_RECV` event-firing (the dispatch kevent↔Mach-receive hook) so the source handler fires on message arrival;
2. wire the `dispatch_after` timer-source event-firing.

No Gatekeeper disposition op yet (that path is for field-parity PASS, which
this is not).

## Artifacts

```text
results/rx-x64z/20260622T020329Z-op091-dispatch-qos/dispatch_mach_recv_source.json   (rx vector, validates)
results/rx-x64z/20260622T020329Z-op091-dispatch-qos/dispatch_primitives.json         (rx vector, validates)
```
