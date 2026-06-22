# op-097 — dispatch matrix at 129ee3c: all GREEN; libdispatch basic-working DONE (for the tested set)

Date: 2026-06-22

Lane: `rmx-explorer-rx-x64z` (in-guest). rmxOS alpha HEAD `129ee3ce8d52` (op-096 dropped the redundant manager timer poll; op-093's kevent64 shim + semaphore + freebsd_compat.h retained).

## Run

Three op-082 dispatch probes run in-guest at 129ee3c (NORMAL QoS), diffed vs mx-a64z/20260621-27.0-27.0.0:

```text
run dir: block-078-runtime-smoke/runs/20260622T092054Z-op097-matrix-129ee3c
serial sha256: 7c9f388ecf86caa72f99e276c3579ca76a4ccac2df8fd4299a837fd930cabee3
rx vectors: results/rx-x64z/20260622T092054Z-op097-matrix-129ee3c/dispatch_*.json (3/3 validate)
```

## Bucketed matrix

GREEN (bucket 1) — all servicing fields match mx-a64z:
- `dispatch_primitives` — dispatch_available, group_enter_leave_wait (count 1), semaphore_timeout_observed, semaphore_signal_then_wait_ok, **dispatch_after_fired=true**. All GREEN. (mach_port_names KERN_FAILURE / names=4294967295 + cleanup_delta 0 on rx = known expected-divergence, non-gating.)
- `dispatch_global_queue_service` — 64 blocks dispatched + completed via workers (matches mx exactly on the servicing fields; threads_*/elapsed_ns divergent = expected).
- `dispatch_mach_recv_source` — **handler_fired_and_serviced=true** (matches mx).

RED localized (bucket 2): **none.**

RED parked-kernel (bucket 3): **none.** `dispatch_mach_recv_source` was the expected parked item (op-091 RED, op-094 cited bl-003 filt_machport null_filtops). At 129ee3c it is **GREEN** — the op-093 kevent64 shim + semaphore fixes (retained through op-096) resolved the dispatch_source MACH_RECV event-delivery path too, not just dispatch_after. bl-003's "filt_machport null_filtops" framing needs re-examination: it does not block the `dispatch_source` MACH_RECV API contract on rmxOS at this revision.

## Coverage caveat (not a defect — a probe gap)

`dispatch_primitives` exercises only: group (enter/leave/wait), semaphore (timeout/signal+wait), and dispatch_after. The op-097 dispatch's stated full matrix — async/sync, apply, once, barrier, source-timer (non-MACH_RECV) — is **not** exercised by the current probe. One-source-two-targets: I did not extend the probe (author side). Those matrix elements are unverified; a probe-extension op would be needed to claim DONE across the full matrix.

## Outcome

**libdispatch basic-working DONE** for the tested set (group, semaphore, after, global_queue, mach_recv_source) at 129ee3c — only bucket 1 remains; no bucket-2 localized defect; the expected bucket-3 (mach_recv) is GREEN. The untested matrix elements (async/sync/apply/once/barrier/source-timer) are a coverage gap, not a defect.

## Next hop

- Coordinator decision: accept "basic-working DONE" for the tested set, OR commission a probe-extension op (author side) to cover async/sync/apply/once/barrier/source-timer before claiming DONE across the full matrix.
- Re-examine bl-003: at 129ee3c the dispatch_source MACH_RECV contract holds; bl-003 should be updated or closed.
