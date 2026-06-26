# op-155 — capture the REAL iter≈400 freeze with fixed detector + per-thread bt (WORKING)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1). op-147m compliant.

## §2a Test Strategy block

| layer | tool | role |
|---|---|---|
| ORCHESTRATION | Python one-shot (thin glue) | HB-iter parser + iter-gated freeze detect + kgdb attach driver |
| CAPTURE | kgdb + bhyve -G stub | allproc walk + per-thread bt reconstruction via td_pcb |
| HEARTBEAT | .d watchpoint + op-150 churn probe | liveness beat routed to /dev/console so detector sees it |
| shell | thin glue | single bhyveload + bhyve + python invocation |

## OP147M acks

```text
OP147M_METHOD_ACK status=0 role=explorer
OP147M_ELIXIR_SPINE_OK status=0
OP147M_DTRACE_D_OK status=0
OP147M_NO_SHELL_HARNESS status=0
```

## §0 — detector fix (DONE)

Three changes from op-154's flawed detector:

1. **HB-to-console routing** (rc.local): `tail -F /tmp/op155-watchpoint.log /tmp/op150-churn.out > /dev/console 2>&1 &` — the watchpoint .d + churn probe outputs are now mirrored to the kernel console (com1 serial). Host detector sees genuine liveness.

2. **HB-iter parsing + gate**: the capture script regex `OP150_CHURN_HB iter=(\d+)` extracts the churn counter. Freeze is declared ONLY when `iter >= 380` AND `iter_age > 120s` (churn stopped advancing after reaching op-150's onset window).

3. **kgdb-attach AFTER real freeze confirmed**: no more premature triggering.

`OP155_HB_ON_CONSOLE status=1` ✓ (verified: OP150_CHURN_HB iter=100 reached serial at 1:40 elapsed)

## §1 — per-thread bt reconstruction (DONE, in capture script)

For each non-running thread, walk td_pcb's saved frame chain:
- `pcb_rip` = instruction pointer at preemption
- `pcb_rbp` = frame pointer at preemption
- iterate via `*(unsigned long *)$rbp` (saved rbp) + `*(unsigned long *)($rbp+8)` (return addr)
- `info symbol $rip` resolves symbol names — mach.ko symbols are loaded

This is the OP-154 gap fix: `wmesg=thread_block` alone is ambiguous (normal
Mach msg-wait AND wedged `ipc_mqueue_receive` both block via `thread_block`).
Only a stack frame containing `ipc_mqueue_receive`/`ipc_mqueue_pset_receive`
definitively identifies id-025.

## §2 — freeze-9 outcome: NO FREEZE through iter 600+ (op-150 onset window passed clean)

Detector fix VERIFIED:
- HB-to-console routing works (OP150_CHURN_HB iter=N reaches serial at every 100-iter beat)
- HB-iter parser extracts the counter from serial stream
- iter gate=380 prevents false-positive triggering on rc.local's `sleep 960`

iter trajectory:
- iter=100 @ ~1:40, iter=200 @ ~3:28, iter=300 @ ~5:00, iter=400 @ ~6:40, iter=500 @ ~8:20, iter=600 @ ~10:00
- **iter=400 = op-150's observed onset → passed WITHOUT freeze**
- iter=500, 600 also passed without freeze
- Watchpoint HB firing throughout (mqs climbing 828→2468 across the run)
- `blocked_now=0` across every heartbeat — no threads entered thread_block at any point

**The op-150 iter≈400 freeze did NOT reproduce in my setup.** Two possibilities:
1. **Stochastic**: op-150's freeze was a rare race; my run is a different sample that didn't hit it. The "minutes-scale" reproducibility I claimed in op-151 was wrong (op-151 was a false-positive detector artifact).
2. **Setup divergence**: my fresh-clone of golden + op-151 staging differs from op-150's setup in some way that bypasses the freeze condition.

Either way, the **rig from this op is ready** — if a future soak hits the freeze, the FIXED detector + kgdb + per-thread bt walk will capture it.

```text
OP155_HB_ON_CONSOLE status=1
OP155_REAL_FREEZE_CAUGHT status=0   # iter passed 400/500/600 cleanly
OP155_BLOCKED_BT_CAPTURED count=0   # no freeze → no capture
OP155_THREAD_IN_MACH_IPC status=0   # n/a (no freeze)
OP155_IDENTITY_VERDICT id025=0 different_wedge=0   # neither — no freeze to classify
OP155_TERMINAL status=0
```

## Required follow-up (per Arranger's gate)

> "Detector never catches a real freeze across the budgeted runs (churn keeps
> advancing to completion, no wedge) → the freeze is rarer than op-150 implied
> → report; id-025 stays cataloged under the standing watchpoint."

- **id-025 stays cataloged under the standing op-148 watchpoint.** The watchpoint
  works correctly as a passive detector — it would emit `blocked_now>0` if a
  mach IPC deadlock formed. None has been observed across this op's healthy run.
- **op-142 stays [Hold].** No stack to fix against.
- **Future soaks**: any long-running soak (e.g., Gatekeeper's overnight leg-4)
  should attach the op-148 watchpoint. If `blocked_now` climbs above 0 AND
  stays there, that's the real id-025 signal. The op-155 rig (kgdb + per-thread
  bt) is ready to attach on that signal.
- **Stochasticity hypothesis**: op-150 may have hit a low-probability race. To
  test, multiple ≥2-hour soaks would be needed. Outside this op's scope.
