# op-089 — field-level rx dispatch parity; libthr missing pthread_attr_set_qos_class_np

Date: 2026-06-21

Lane: `explorer-rx-x64z`

Op: op-089 (field-level rmxOS dispatch parity — close the op-085 field-coverage gap).
Deepens op-085 (servicing-invariant parity via the block-078 smoke); does not re-open it.

## Scope

Stage and run the three op-082 macos-validation dispatch probes IN the rmxOS
guest, capture rx-x64z `dispatch_*.json`, and diff field-by-field vs the ferried
macOS-27 `mx-a64z` reference. Evidence-lane, catalog-mode (no attempt spent).

## Pins

```text
explorer-rx source head: 115c56f
rmxOS source tree:        /Users/me/wip-mach/wip-gpt/wip-rmxos  (alpha)
rmxOS source head:        5675145df333  (dispatch: service Mach receive through TWQ workqueues)
alpha obj_root:           build/block-075-alpha-final-obj/.../wip-rmxos/amd64.amd64
base image:               block-078-runtime-smoke/runs/20260619T112919Z-clean-check-token-smoke/block078-userland-smoke.img
run dir:                  block-078-runtime-smoke/runs/20260621T064244Z-op089-dispatch-field
serial log sha256:        73f16f750b6283df7e21b74e92cbc60e6e821de473aa9b74586d5818d79d4a9b
```

Disposable image copy; original parity image untouched. Probes built on the
host against the alpha userland (`-I wip-rmxos/{include,sys,lib/libdispatch}`,
`-ldispatch -lmach -lBlocksRuntime`, linked to the alpha `libdispatch.so.5` /
`libmach.so.5` / `libBlocksRuntime.so.0`); `DT_NEEDED` matches what
`stage-userland.sh` installs to the guest `/usr/lib`. No probe source edited
(one-source-two-targets).

## rx results

| Probe | rx result | mx-a64z | classification |
|---|---|---|---|
| `dispatch_global_queue_service` | **pass** (64 blocks dispatched + completed via workers) | pass | **match** — parity-confirmed |
| `dispatch_mach_recv_source` | **crash** (no JSON) | pass | **mismatch / rmxOS-missing-X** |
| `dispatch_primitives` | **crash** (no JSON) | pass | **mismatch / rmxOS-missing-X** |

## Field-diff: dispatch_global_queue_service (match)

Servicing-invariant fields (the comparison axis) — **identical on rx and mx**:

```text
                       rx-x64z        mx-a64z
dispatched_block_count   64             64
dispatch_available       true           true
all_blocks_completed     true           true
completed_block_count    64             64
```

Divergent fields (expected-divergence, NOT mismatch):

```text
threads_before/after     -1 / -1        1 / 3        kern.twq.threads_created absent on rmxOS (probe's kwq_signal_note)
elapsed_ns               0              147375       timing — non-deterministic
names_before/after       4294967295(*)  11 / 13      (*) mach_port_names returns KERN_FAILURE on rmxOS (known, non-gating)
cleanup_delta            0              2            libdispatch leaves internal Mach ports (non-gating)
```

The global-queue servicing contract (dispatch N blocks, complete all via
workers) holds on rmxOS as on macOS-27. rx JSON validates (`validate_json`
PASS).

## Field-diff: dispatch_mach_recv_source + dispatch_primitives (rmxOS-gap)

Both probes crashed at process start with identical stderr:

```text
ld-elf.so.1: /usr/lib/libdispatch.so.5: Undefined symbol "pthread_attr_set_qos_class_np"
```

Root cause (verified first-hand, `nm -D`):

```text
libdispatch.so.5   :  U pthread_attr_set_qos_class_np          (needs it)
libthr.so.3 (alpha):  ABSENT                                        (only private _pthread_*_qos_class_* present)
libsys.so.7        :  no qos symbols
libc.so.7          :  no qos symbols
```

`dispatch_source_create` / `dispatch_queue_create` with a QoS attribute call
`pthread_attr_set_qos_class_np`. rmxOS `libthr` does not export that public
symbol, so the lazy bind fails and the process dies before emitting any JSON
(global_queue_service avoids the path: it uses the pre-created global queue,
which doesn't set a QoS attr). This is a genuine **rmxOS gap**, not a probe
defect and not a staging omission — the alpha-built `libthr.so.3` itself lacks
the symbol.

Consequence: field-level parity for `dispatch_mach_recv_source` (the
DISPATCH_SOURCE_TYPE_MACH_RECV contract — op-081-R's fix) and for
`dispatch_primitives` is **not establishable** until libthr provides
`pthread_attr_set_qos_class_np`. The block-078 smoke (op-084/op-085) proved
rmxOS services Mach-recv through TWQ at the notifyd level; this op shows that
victory does not yet extend to the `dispatch_source` MACH_RECV API path,
because the QoS pthread-attr API libdispatch needs is missing.

## Classification summary

- `dispatch_global_queue_service` → **match** (parity-confirmed, servicing fields identical).
- `dispatch_mach_recv_source` → **mismatch (rmxOS-missing-X)**: `pthread_attr_set_qos_class_np` absent from libthr.
- `dispatch_primitives` → **mismatch (rmxOS-missing-X)**: same root cause.

## Version-sensitive flags

None beyond the gap above.

## Next hop

The missing-symbol gap is a single, well-localized Implementer target: export
`pthread_attr_set_qos_class_np` (and likely the companion QoS pthread-attr API
surface) from rmxOS `libthr`. Once fixed, re-run op-089's mach_recv_source +
primitives to capture their field vectors and complete the field-level parity
claim. A Gatekeeper disposition op should be issued for this mismatch.

## Artifacts

```text
results/rx-x64z/20260621T064244Z-op089-dispatch-field/dispatch_global_queue_service.json   (rx vector, valid)
results/rx-x64z/20260621T064244Z-op089-dispatch-field/dispatch_mach_recv_source.stderr     (crash evidence)
results/rx-x64z/20260621T064244Z-op089-dispatch-field/dispatch_primitives.stderr           (crash evidence)
```
