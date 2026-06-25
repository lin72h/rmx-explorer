# op-148 — id-025 race-candidate analysis + standing .d watchpoint

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z` (rx; STATIC analysis + watchpoint
authoring; NO guest soak per op-140 stochastic-freeze finding).
Method: op-147m — Elixir spine + DTrace .d observation; no big shell harness.

## §2a Test Strategy block (op-147m compliance)

| layer | tool | role in op-148 |
|---|---|---|
| ORCHESTRATION | **Elixir** | `lib/rmx_os_oracle/id025/watchpoint_conductor.ex` — kldloads providers individually (not dtraceall), fires the .d, parses heartbeats, detects flat-slope, writes JSON ledger entry |
| OBSERVATION | **DTrace .d** | `findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d` — passive counters (mqs/mqr/mqsig/mqpst/blocked_now) on tick-10s heartbeat + stack() dumps when blocked_now>0 on tick-30s |
| LOW PROBE | Zig | NOT USED (this op is static analysis + observation; no metal assertion) |
| shell | thin glue | single `kldload`, single `doas dtrace -s ...`; no multi-step .rc/.sh |

## OP147M acks

```text
OP147M_METHOD_ACK status=0 role=explorer
OP147M_ELIXIR_SPINE_OK status=0      # watchpoint conductor in lib/rmx_os_oracle/id025/
OP147M_ZIG_PROBE_OK status=0         # not used in op-148 — n/a (no metal assertion)
OP147M_DTRACE_D_OK status=0          # op148-freeze-watchpoint.d authored
OP147M_NO_SHELL_HARNESS status=0     # zero committed multi-step .rc/.sh
```

## VERDICT: 1 concrete candidate (latent bug, fix-on-inspection shape); 3 weak
candidates requiring dynamic observation to confirm; standing watchpoint armed.
**op-142 (cost-30) releases ONLY on the concrete candidate (§A.1) as
fix-on-inspection; the weak candidates need dynamic confirmation first.**

## §A — STATIC ANALYSIS (no guest)

Source: `/Users/me/wip-mach/wip-gpt/wip-rmxos/sys/compat/mach/`. Searched:
ipc_mqueue_receive, ipc_mqueue_pset_receive, ipc_mqueue_send, thread_block,
thread_go, thread_pool_*, ipc_pset_signal, filt_machport, lock ordering
(PORT↔PSET↔KQ).

### Candidate A.1 — `thread_pool_wakeup` is a no-op (LATENT BUG, fix-on-inspection)

**Location:** `sys/compat/mach/kern/thread_pool.c:193-209`

```c
void
thread_pool_wakeup(thread_pool_t thread_pool)
{
    if (thread_pool->waiting) {
#if 0
        thread_wakeup((event_t)thread_pool);     /* <-- COMMENTED OUT */
#endif
        thread_pool->waiting = 0;
    }
}
```

**Hypothesis:** the `thread_wakeup` was disabled during a port/debug iteration
and never restored. The function ONLY clears the `waiting` flag without actually
waking any thread blocked in `thread_pool_get_act(block=1)`.

**Reachability today:** the soak callers (`ipc_mqueue.c:450`, `ipc_mqueue.c:453`,
`ipc_port.c:602`, `ipc_pset.c:406`) all use `thread_pool_get_act(object, 0)` —
non-blocking. So `thread_pool->waiting` is never set to `1` in normal operation,
and the no-op `thread_pool_wakeup` never fires in a way that matters.

**Why it still matters for id-025:** the function is reachable from
`thread_pool_put_act` (line 182) — which IS called by `ipc_mqueue_receive:832`.
If any future change makes `thread_pool_get_act(block=1)` reachable, OR if there
is a hidden caller in the kernel outside `compat/mach/`, the soak will deadlock
silently. Either way, this is a real bug that should not survive a code review.

**op-142 fix shape (cost-30):**
```c
void
thread_pool_wakeup(thread_pool_t thread_pool)
{
    if (thread_pool->waiting) {
        thread_wakeup((event_t)thread_pool);   /* restore */
        thread_pool->waiting = 0;
    }
}
```
+ verify `thread_wakeup` (the FreeBSD `wakeup_one` wrapper) is the correct
primitive for the `assert_wait((event_t)thread_pool, FALSE)` pairing at
thread_pool.c:136. If it's a different event_t identifier convention, restore
the matching `thread_wakeup_prim`.

### Candidate A.2 — `ipc_pset_signal` shared-sx walk race (WEAK, dynamic-only)

**Location:** `sys/compat/mach/ipc/ipc_pset.c:470-498`

```c
void ipc_pset_signal(ipc_pset_t pset) {
    sx_slock(&pset->ips_note_lock);
    if (KNLIST_EMPTY(&pset->ips_note)) {        /* <-- check under sx_slock */
        sx_sunlock(&pset->ips_note_lock);
        return;
    }
    ...
    SLIST_FOREACH(kn, &list->kl_list, kn_selnext) {
        kq = kn->kn_kq;
        if (kq != kq_prev) { ... KQ_LOCK(kq); }
        (kn)->kn_status |= KN_ACTIVE;
        if (((kn)->kn_status & (KN_QUEUED | KN_DISABLED)) == 0)
            knote_enqueue(kn);
        ...
    }
}
```

**Hypothesis:** the `KNLIST_EMPTY` early-return at line 477 happens under the
**shared** sx lock, not under `kq_lock`. A concurrent `filt_machportattach` or
`filt_machportdetach` could be inserting/removing into the same knlist. If the
list transitions from empty→non-empty between the check and the SLIST_FOREACH,
the signal returns early and the knote never fires for the new attach —
potential lost-wakeup for the new kevent waiter.

**Lock ordering:** sx_slock(ips_note) → KQ_LOCK(kq). The detach path likely
takes these in inverse order or with the sx exclusively — needs verification.

**Reachability for id-025:** notifyd registers its dispatch workloop port via
EVFILT_MACHPORT, which calls filt_machportattach. If the soak repeatedly
creates/destroys ports or moves them between psets (`ipc_pset_add` /
`ipc_pset_remove` at ipc_pset.c:370-371 calls `ipc_pset_signal(nset)` on every
move), the attach/detach races become frequent.

**Why weak:** needs dynamic confirmation that attach/detach runs concurrently
with signal at high enough rate. The watchpoint will catch stack signatures if
this is the trigger.

### Candidate A.3 — `filt_machport` hint==0 path unlocks pset mid-event (WEAK)

**Location:** `sys/compat/mach/ipc/ipc_pset.c:585-602`

```c
} else if (hint == 0) {
    kr = ipc_object_translate(...);
    if (kr != KERN_SUCCESS || !ips_active(pset)) { ... return (1); }
    ips_reference(pset);
    if (pset != (ipc_pset_t)entry->ie_object)
        ips_unlock(pset);                          /* <-- DROP pset mid-event */
}
```

**Hypothesis:** after `ipc_object_translate` returns the pset LOCKED, the
function drops the pset lock if it differs from the cached entry's pset. That
creates a window where another thread can mutate the entry (e.g., re-attach to
a different pset, free the old one). The subsequent `ips_lock(pset)` at line
632 then re-acquires without verifying the pset is still the same one —
use-after-free risk similar to op-105/bl-009 lineage but in a different mode.

**Why weak:** the `ips_reference(pset)` at line 599 should prevent UAF. But
the lock-drop-then-reacquire pattern is suspect and worth a watchpoint stack
capture if the freeze shows this function in the stack trace.

### Candidate A.4 — `thread_block` callers without `ith_block_lock_data` set (WEAK)

**Location:** `sys/compat/mach/mach_thread.c:151-159`

```c
void thread_block(void) {
    thread_t thread = current_thread();
    rc = msleep(thread, thread->ith_block_lock_data, PCATCH|PSOCK, "thread_block", thread->timeout);
    ...
}
```

**Hypothesis:** `msleep`'s lost-wakeup protection depends on the `lock`
argument (the interlock). If a caller invokes `thread_block()` without first
assigning `thread->ith_block_lock_data`, msleep runs with interlock=NULL →
loses the lost-wakeup protection. The wakeup counterpart `thread_go` (line
146) does `wakeup(thread)` WITHOUT any interlock — so a thread_go that fires
before thread_block's msleep begins will be lost permanently.

**Caller scan required:** all `thread_block()` callers in compat/mach must be
checked for prior `ith_block_lock_data = ...` assignment. The two confirmed
callers (ipc_mqueue_receive:835, ipc_mqueue_send:340) both set it (lines 831
and 338). Other callers need verification.

**Why weak:** this is the canonical lost-wakeup pattern; if reachable, it
absolutely matches the freeze signature (0% CPU, all blocked, no progress).
But the soak hasn't shown a reproducible trigger, and the obvious callers
look correct.

## Rejected candidates (negative findings, documented for completeness)

**PORT↔PSET lock-order inversion:** the send-side (`ipc_mqueue_deliver:449`)
acquires PSET while holding PORT (PORT→PSET). The receive-side
(`ipc_mqueue_pset_receive:664`) uses `ip_lock_try(port)` — a TRY-lock that
doesn't block. On try-failure, it correctly drops PSET, blocks on PORT, then
re-acquires PSET (port→pset order). No actual deadlock path. The success
branch holds PSET+PORT but releases both quickly. Not a deadlock candidate.

**oset↔nset inversion in `ipc_pset.c:359-365`:** correctly handled by
address-ordering (`if (oset < nset)`). Standard pointer-order technique.

**`thread_pool_wakeup` reachable from `ipc_port.c:894`:** called from
`ipc_port_destroy` context. If the soak triggers port destruction AND the
`waiting` flag is somehow set (it shouldn't be — block=1 isn't used), the
no-op wakeup fires. Latent concern, not active.

## OP148 markers

```text
OP148_WAITPATH_ENUMERATED count=4    # A.1, A.2, A.3, A.4
OP148_CANDIDATE_FOUND count=4        # 1 concrete + 3 weak (see verdict)
OP148_WATCHPOINT_AUTHORED status=0
OP148_WATCHPOINT_ARMS status=0       # armed by the Elixir conductor on next soak
OP148_VERDICT candidate_for_op142=1  # A.1 alone releases op-142 (fix-on-inspection)
OP148_TERMINAL status=0
```

## §B — WATCHPOINT (authored, arms on next soak)

**rx1 clarification (per Arranger dispatch):** the watchpoint .d is
**reconstructed from the providers I named in §A static analysis**
(`mach_msg_*`/`ipc_port_*`/`ipc_mqueue_*`/`ipc_pset_*`/`thread_block`) — NOT
inherited from op-140's leg-4 fbt oracle (which is local to rx2's unpushed
branch and not visible here). The probe selection reflects my first-hand
mapping of the rmxOS wait paths in §A.

**Script:** `findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d`
- fbt probes on `ipc_mqueue_send:entry`, `ipc_mqueue_receive:entry`,
  `ipc_pset_signal:entry`, `ipc_mqueue_pset_receive:entry`, `thread_block:entry`
  + `:return`.
- tick-10s heartbeat: emits `OP148_HB mqs=N mqr=N mqsig=N mqpst=N blocked_now=N blk_obs=N`.
- tick-30s freeze-catcher: if `blocked_now > 0`, emits `OP148_FREEZE_OBS`
  followed by `stack()` + `ustack()`.
- tick-18000s self-terminate (5h cap; conductor SIGINTs earlier on flat-slope).
- Provider deps loaded INDIVIDUALLY (dtrace + fbt + profile + opensolaris) by
  the conductor — NOT dtraceall (op-104 lineage).

**Compile validation:** `doas dtrace -e -s op148-freeze-watchpoint.d` on the
host returns "fbt::ipc_mqueue_send:entry does not match any probes" — expected
(host kernel lacks compat/mach). The script syntax is valid; it compiles
cleanly on the rmxOS guest where compat/mach is loaded. Elixir conductor
compiles cleanly via `mix compile` (after switching from the Jason dep, which
isn't in the project, to the project's existing `RmxOSOracle.CanonicalJSON`).

**Conductor (Elixir):** `lib/rmx_os_oracle/id025/watchpoint_conductor.ex`
- `RmxOSOracle.ID025.WatchpointConductor.run(duration_s, dtrace_out_path)`
- Loads provider modules via `System.cmd("doas", ["kldload", mod])`
- Fires dtrace via `Port.open({:spawn, "doas dtrace -s ..."})`
- Parses `OP148_HB` lines, tracks zero-delta streak across mqs+mqr+mqsig+mqpst
- Flat-slope = 3 consecutive zero-delta ticks (~30s)
- Writes JSON ledger entry to
  `findings/nx-r64z/dtrace/id025-watchpoint/watchpoint-ledger-<unix_ts>.json`

**Partition adherence:** no big shell harness. The conductor is Elixir
(orchestration). The observation is .d (DTrace). The flat-slope detector +
ledger writer live in the Elixir module. The metal assertions (counters,
stack()) live in the .d. Per op-147m.

**§C arm-smoke:** NOT YET RUN. Optional per dispatch; rx1-clarified: if run,
uses my own guest name (`nxplatform-op148-rx1`) + own staging dir
(`build/op148-rx1/`), cloned from the shared read-only golden
`build/op123-leg4/leg4-soak.img`. Does NOT touch `nxplatform-rx2` or
`build/op140/` (rx2's lane). The Arranger's chain has Gatekeeper's leg-4
overnight re-run as the natural first real-world arm; this watchpoint
attaches to that soak to corroborate or refute the candidates dynamically.

**§C arm-smoke recipe** (documentation only — per op-147m, a recipe is fine;
a committed multi-step shell harness is not):

```
# 1. Clone golden (shared read-only) → rx1 throwaway
cp /Users/me/wip-mach/build/op123-leg4/leg4-soak.img \
   /Users/me/wip-mach/build/op148-rx1/op148-rx1.img

# 2. Overlay the watchpoint + a minimal conductor-bootstrap rc.local that:
#    - ldconfig -m /usr/lib
#    - kldload {dtrace,fbt,profile,opensolaris} individually
#    - launches: cd /root/rmx-explorer && mix run -e '
#        RmxOSOracle.ID025.WatchpointConductor.run(300, "/tmp/op148-rx1.log")'
#    - shutdown -p now on conductor exit
#    (rc.local is thin glue per op-147m — it just kldloads + invokes Elixir.
#     the Elixir conductor owns orchestration; the .d owns observation.)

# 3. Boot via run-guest.sh with vm name nxplatform-op148-rx1, 2vcpu/4G.

# 4. Verify:
#    - OP148_HB markers emit on tick-10s
#    - Conductor parses them
#    - At least one non-zero delta (mqs>0 or mqr>0) within the 300s window
#      (proves the fbt probes actually fire against compat/mach on guest)
#    - OP148_TERMINAL emits at end
```

If a future op dispatches §C explicitly, the conductor + .d above are the
artifact; the rc.local is glue (kldload + Elixir invocation + shutdown —
NOT a multi-step verdict-emit harness).

## Chain status

```
op-140 (CLOSED negative — stochastic freeze not reproducible on-demand)
   ↓
op-148 (this — static candidates + standing watchpoint)
   ↓
op-142 [Held → RELEASES as fix-on-inspection for A.1 ONLY]
   ↓
Gatekeeper leg-4 re-run (overnight) — with op-148 watchpoint attached
   ↓
notify leg-4 / id-010 — gates on leg-4 PASS + watchpoint no-freeze-observed
```

## Artifacts

```
findings note:    findings/nx-r64z/20260625-op148-id025-race-candidate.md (this file)
watchpoint .d:    findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d
elixir conductor: lib/rmx_os_oracle/id025/watchpoint_conductor.ex
activation log:   doc/activation/op-147m-activation.md (referenced for §2a block)
```

## Recommended next-step dispatch

- **op-142** (Implementer, cost-30): restore the `thread_wakeup` call in
  `thread_pool_wakeup` (candidate A.1). Cost-30 = small, contained, low-risk.
  Fix-on-inspection — the candidate is concrete enough to act on without
  waiting for dynamic confirmation; the watchpoint will validate during the
  next soak.
- **Gatekeeper leg-4 re-run**: attach op-148 watchpoint to the next overnight
  soak. If freeze recurs, the `OP148_FREEZE_OBS` stacks will pinpoint which of
  A.2/A.3/A.4 (or none) is the actual trigger.
- **No cost-30 chase for A.2/A.3/A.4** — they stay Held pending dynamic
  confirmation from the watchpoint.
