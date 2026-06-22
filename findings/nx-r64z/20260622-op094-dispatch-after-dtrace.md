# op-094 — DTrace adjudication: BRANCH (a). dispatch_after kevent submitted+delivered; op-093 poll is REDUNDANT

Date: 2026-06-22

Lane: `rmx-explorer-rx-x64z` (+ rmxOS source). DTrace-first, no printf fallback, no source edits to observe.

## Verdict

**Branch (a): with op-093's manager poll DISABLED, `dispatch_after` fires through the EVFILT_TIMER kevent path — submitted, kernel-fired, and delivered. The op-093 `_dispatch_mgr_timer_timeout*` + `_dispatch_mgr_invoke` nanosleep+fire fallback (source.c) is REDUNDANT.** The "FreeBSD may not report the EVFILT_TIMER event" premise behind op-093's poll is falsified first-hand.

The fix that makes dispatch_after work is **op-093's other three files** — `freebsd_kevent64.c` (stack-backed kevent64 shim for the manager-kqueue paths), `semaphore.c` (POSIX-semaphore timed-wait bounded against dispatch_time_t), and `freebsd_compat.h` — not the poll. op-091's `dispatch_after_fired=false` was against `82d68c8e9c99` (pre-op-093 entirely, no shim/semaphore); this run (pre-op-093 `source.c` + op-093's three other files) fires.

## Pins

```text
explorer-rx source head: c8e05c7
rmxOS source:             wip-gpt/wip-rmxos (alpha); source.c reverted to 82d68c8e9c99 for the run, restored after
                          (freebsd_kevent64.c + semaphore.c + freebsd_compat.h kept at op-093 9a903c33e7e7)
guest kernel:             MACHDEBUGDEBUG (KDTRACE_HOOKS via GENERIC)
run dir:                  block-078-runtime-smoke/runs/20260622T081707Z-op094-dtrace
serial8 sha256:           9f9be0cff1a5ebf8d756860eed06e2b7c5ee3ae1c61b811c31edba9be0a91352
trace.log sha256:         3d564c73719cf07831ebb29bff913d6e3ea8f3616b0f10999b2c90ce01bb4bbd
probe JSON (serial):      status=pass, dispatch_after_fired=true
```

## DTrace setup (one-time, reusable)

Built the dtrace kernel modules from `freebsd-src-official-stable-15` against the MACHDEBUGDEBUG kernel obj; staged `dtrace.ko`/`fbt.ko`/`sdt.ko`/`fasttrap.ko`/`systrace.ko`/`opensolaris.ko` (+ dtaudit/dtmalloc/dtnfscl/profile) into the test-guest `/boot/kernel`, and the host `dtrace(1)` + its DT_NEEDED libs into `/usr/sbin` + `/usr/lib`. Built `opensolaris.ko` separately (a hidden dep dtraceall declares).

**`kldload dtraceall` does NOT succeed** — dtraceall also depends on `kinst` and `systrace_freebsd32`, which are absent (not built). But loading the **specific providers** the script needs works cleanly:

```text
opensolaris_rc=0  dtrace_rc=0  fbt_rc=0  fasttrap_rc=0  systrace_rc=0
```

So for `testing-dtrace.md`'s precondition: flip to "dtrace providers load individually (opensolaris+dtrace+fbt+fasttrap+systrace); `dtraceall` needs kinst+systrace_freebsd32 built too." pid-provider probes against libdispatch statics don't resolve (those helpers are `-O2`-inlined — no symbols; only exported symbols resolve, and even those hit a `-c` timing quirk), so the decisive evidence is the syscall+fbt kernel boundary.

## Decisive evidence — the two lines

From `trace.log` (poll disabled; probe pid 970):

**Submission + kernel accept** (the kevent IS submitted to the kernel):
```text
SYSCALL kevent ENTRY kq=4 nchanges=1 nevents=1   <- EV_ADD of the timer kevent
FBT filt_timerattach ENTRY                         <- kernel attached the timer knote
FBT filt_timervalidate ENTRY                       <- kernel validated it
```

**Kernel fire + delivery to the manager** (the timer fires AND the manager receives it):
```text
FBT filt_timerexpire ENTRY                         <- KERNEL TIMER FIRE
FBT filt_timerexpire_l ENTRY
FBT filt_timerdetach ENTRY                         <- EV_ONESHOT consumed
SYSCALL kevent RETURN rc=1 (nchanges was 1)        <- manager kevent returned 1 event (the fire)
```

And the probe's own result JSON on serial confirms the end-to-end outcome:
```text
"status":"pass"   "dispatch_after_fired":true
```

So dispatch_after fires through the kevent path with the poll disabled — branch (a), not (b).

## Why op-091 said false (reconciliation)

op-091 ran against `82d68c8e9c99` — pre-op-093 entirely (no kevent64 shim, no semaphore fix). With the shim+semaphore absent, the manager-kqueue path broke (the standalone kernel substrate fired in op-092, but libdispatch's manager couldn't get the event through). op-093's `freebsd_kevent64.c` shim + `semaphore.c` fix that — *those* are the load-bearing changes; the `source.c` poll just papers over the same path that the shim already fixed.

## Next hop

op-096 (scoped Implementer fix): **drop the `_dispatch_mgr_timer_timeout*` + `_dispatch_mgr_invoke` nanosleep+fire fallback from `source.c` entirely**; keep `freebsd_kevent64.c`, `semaphore.c`, `freebsd_compat.h`. Then re-run `dispatch_primitives` — should stay `dispatch_after_fired=true` purely via the kevent. op-093's poll should NOT be retired as "the dispatch_after fix" — it was masking nothing; the fix lives in the shim+semaphore.

## Artifacts

```text
findings/nx-r64z/20260622-op094-dispatch-after-dtrace.md   (this finding)
findings/nx-r64z/dtrace/op094-script.d                     (the D script, v4 — syscall+fbt, type-safe)
trace.log + serial8.log: run dir above (external; sha256 pinned)
```
