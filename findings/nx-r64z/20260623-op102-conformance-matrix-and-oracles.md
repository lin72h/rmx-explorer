# op-102 — libdispatch runtime conformance: matrix ALL GREEN; oracles authored

Date: 2026-06-23. Lane: `rmx-explorer-rx-x64z`. Base rmxOS alpha `129ee3ce8d52`.

## Deliverable 1 — functional matrix: ALL GREEN

Harness: `findings/nx-r64z/dtrace/dispatch-conformance/harness.c`. Built against
129ee3c libdispatch; run in-guest (serial sha `42298f1f70f2f9f127cef51142441943663a4a90ecd721026cd7a31055b826f0`).

```text
async:            block=PASS  f=PASS
sync:             block=PASS  f=PASS
apply:            block=PASS  f=PASS
once:             block=PASS  f=PASS
barrier:          block=PASS  f=PASS
group:            block=PASS  f=PASS   (enter/leave/wait + notify)
semaphore:        block=PASS  f=PASS   (signal/wait + timeout)
source-timer(NORMAL): PASS
source-MACH_RECV:    PASS
op102_matrix_fails=0
```

Every core-subset primitive passes on rx-x64z. Block + `_f` variants both green (the `_f` path = Zig/CoRT Tier-1 binding surface). source-MACH_RECV PASS confirms op-098 T1's finding (standard EVFILT_MACHPORT path via mach.ko's real filt_machport).

## Deliverable 2 — conformance diff vs mx-a64z (partial; needs ferry for full)

The overlapping primitives (group, semaphore, source-MACH_RECV, source-timer) have mx-a64z reference vectors from op-082/op-097 — all PASS on both sides → **MATCHED** (zero semantic mismatch). The non-overlapping primitives (async, sync, apply, once, barrier) have no mx-a64z vectors yet — **pending the mx-a64z ferry** (the user runs the same harness on mm4/macOS-27; the diff then completes). No mismatches laddered to bl-NNN.

## Deliverable 3 — invariant-oracle scripts (foundation; soak staged)

Four DTrace assertion scripts authored under `findings/nx-r64z/dtrace/dispatch-conformance/`:
- `msg-balance.d` — mach_msg_send vs mach_msg_receive count balance (exit nonzero on imbalance = leaked messages).
- `port-balance.d` — ipc_port_alloc vs ipc_port_destroy (flags unbounded growth).
- `kmsg-balance.d` — ipc_kmsg_alloc vs ipc_kmsg_destroy (exit nonzero on imbalance = stuck work).
- `queue-balance.d` — ipc_mqueue_send vs ipc_mqueue_receive (exit nonzero on imbalance = stuck queue work).

Each uses the op-099 fbt anchors. The **2-hour soak run** (continuous harness loop under the four oracles) is staged but not yet executed — it needs a long-running bhyve boot (beyond the bounded ~180s pattern) + continuous DTrace. That's a follow-up phase.

## Net

- **Matrix: ALL GREEN** on rx-x64z at 129ee3c. The harness is the template for notifyd/asl/libxpc.
- **Conformance: MATCHED** for the overlapping primitives; the mx ferry completes the diff for async/sync/apply/once/barrier.
- **Soak: oracle scripts authored; the 2-hour run is staged** (follow-up: long-running bhyve + continuous DTrace assertions).

Truly-green bar (per the dispatch): matrix green (✓), conformance diff zero-mismatch for the overlapping set (✓; mx ferry completes), soak 2h zero-violations (pending). The foundation is in place; the ferry + the soak complete it.
