# op-098 — mach_recv GREEN paradox (Task 1) + primitive-surface coverage (Task 2)

Date: 2026-06-22. Lane: `rmx-explorer-rx-x64z` (in-guest, DTrace-first, no product-source edits). Base rmxOS alpha `129ee3ce8d52`.

## Task 1 — mach_recv GREEN paradox: NEITHER (a) NOR (b). It's the standard EVFILT_MACHPORT path.

op-097 reported `dispatch_mach_recv_source` GREEN at 129ee3c, contradicting the dispatch's premise that `kern_event.c:391 [~EVFILT_MACHPORT]=&null_filtops` (a null filter can't wake a kqueue).

**The premise was wrong for the running kernel.** `kern_event.c` does declare `null_filtops` as the *static* default, but **mach.ko dynamically registers real `filt_machport` ops at boot** — defined in the compat/mach layer (`sys/compat/mach/ipc/ipc_pset.c`, registered via `sys/compat/mach/mach_module.c`). So at runtime EVFILT_MACHPORT is a live kqueue filter.

Correlated DTrace (`fbt::filt_machport*` + `fbt::mach_msg*` + `pid$target::dmrs_handler`), probe = the existing `dispatch_mach_recv_source` (body: allocate receive right → `dispatch_source_create(MACH_RECV)` → handler does `mach_msg(MACH_RCV_MSG)` → resume → `mach_msg(MACH_SEND_MSG)` a real message → wait on handler-serviced flag — a genuine round-trip, NOT shallow):

```text
-> mach_msg_overwrite_trap -> mach_msg_send          (probe SENDS the message)
-> filt_machportattach -> filt_machport (x3)         (kernel machport filter ATTACHES + FIRES)
-> dmrs_handler                                      (libdispatch invokes the handler)
   -> mach_msg_overwrite_trap -> mach_msg_receive    (handler RECEIVES the message)
-> filt_machportdetach                               (EV_DISPATCH consume)
```

`filt_machport` entries: 5. `dmrs_handler`: 1. So the message is delivered through the **standard kqueue EVFILT_MACHPORT path** with real (mach.ko-provided) filter ops.

- **(a) non-kqueue manager drain:** NO — the kernel machport filter IS entered.
- **(b) shallow probe:** NO — the probe does a real send+receive round-trip (body confirmed) and the trace shows filt_machport → handler → mach_msg_receive end-to-end.
- **Conclusion:** the standard path works. **bl-003 ("filt_machport null_filtops") is misframed** — null only statically; mach.ko makes it real at runtime. bl-003 should close (or be re-scoped to "pre-mach.ko-load only").

Pins: run dir `block-078-runtime-smoke/runs/20260622T095139Z-op098-t1-machport`; serial sha `e8df2503544b43febb671a08751fe83fb7743c59daa3bb1ba0c1268792a06ff6`; trace sha `401e1ab497c389f3b232f3866e859d773e3d13e2b5af5af09d882fa2bddd03aa`.

## Task 2 — primitive-surface coverage: ALL GREEN (exit-code); bl-004 latent.

Authored a single multi-primitive probe (`findings/nx-r64z/dtrace/op098-t2-primitives.c`) testing block + `_f` variants, run in-guest at 129ee3c. Per-primitive result (serial, sha `9e6f098132f05424dd6e305ecce7f3cef7170e76ac1169d02601d927b49f70fa`):

```text
dispatch_async: PASS        dispatch_async_f: PASS
dispatch_sync:  PASS        dispatch_sync_f:  PASS
dispatch_apply(8): PASS     dispatch_apply_f(8): PASS
dispatch_once:  PASS        dispatch_once_f:  PASS
dispatch_barrier_async: PASS   dispatch_barrier_sync: PASS
timer_QOS_NORMAL: PASS (fired)
timer_QOS_HIGH(CRITICAL): PASS (fired)
timer_QOS_LOW(BACKGROUND): PASS (fired)
op098_t2_fails=0
```

Both block and `_f` variants pass for every primitive. The `_f` path (the Zig/CoRT Tier-1 binding surface) is at parity with block.

**DTrace-per-primitive not run** (session-scope decision — the op-094/op-098-T1 DTrace already showed the dispatch manager-kqueue + timer-fire + machport-delivery machinery working end-to-end; per-primitive exit-code parity on top of that is strong evidence). If a validator wants per-primitive fbt/USDT, it's a bounded follow-up — but note USDT is OFF (libdispatch built `-DDISPATCH_USE_DTRACE=0`), so it would be pid/fbt only.

**bl-004 (non-NORMAL QoS timer fflags):** the HIGH/LOW QoS timers in my probe **FIRED** (PASS) — but this is **inconclusive for bl-004**. The probe's user-facing timer sources most likely routed through libdispatch's NORMAL timer slot (fflags `NOTE_ABSOLUTE|NOTE_NSECONDS`), not the CRITICAL/BACKGROUND slots that carry `NOTE_CRITICAL`/`NOTE_BACKGROUND`. The kernel-side rejection is source-confirmed first-hand (op-092, kern_event.c `filt_timervalidate` line 914: `(kn->kn_sfflags & ~(NOTE_TIMER_PRECMASK|NOTE_ABSTIME)) != 0 → EINVAL`) — i.e. the kernel WOULD reject `NOTE_CRITICAL`/`NOTE_BACKGROUND`. The probe didn't drive those slots, so bl-004 is **latent**: real for any code path that routes a timer into the CRITICAL/BACKGROUND slot, but not exercised here. To definitively close bl-004, DTrace `filt_timervalidate` capturing `kn_sfflags` while forcing a CRITICAL/BACKGROUND timer slot is needed.

## Net

**"libdispatch basic-working parity for the primitive surface" IS defensible at 129ee3c.** Every tested primitive (async/sync/apply/once/barrier, block + `_f`), the NORMAL-QoS timer, and the MACH_RECV source pass. Residuals:
- **bl-004 (non-NORMAL-QoS timer)** — latent kernel-side rejection (`filt_timervalidate` EINVAL on `NOTE_CRITICAL`/`NOTE_BACKGROUND`); not triggered by user-facing timer patterns in this probe; needs a slot-forcing DTrace to close.
- **bl-003 (mach_recv "null filt_machport")** — should close/re-scope: the running kernel has real `filt_machport` (mach.ko dynamic registration); the standard kqueue MACH_RECV path works (Task 1).

No product-source edits made (observation only). Probe + DTrace scripts committed under `findings/nx-r64z/dtrace/`.
