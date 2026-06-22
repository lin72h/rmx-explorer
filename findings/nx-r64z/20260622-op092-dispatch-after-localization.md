# op-092 — dispatch_after localization: break is in libdispatch's manager timer path, NOT the kernel/shim/fflags

Date: 2026-06-22

Lane: `explorer-rx-x64z` (+ rmxOS source)

Op: op-092 (localize WHY `dispatch_after` doesn't fire on rmxOS). **Localization
only — no fix.** Out of scope: `dispatch_mach_recv_source` (bl-003 backlog,
kernel `EVFILT_MACHPORT` is `null_filtops`); kqueue core.

## Pins

```text
explorer-rx source head: c8e05c7
rmxOS source tree:        /Users/me/wip-mach/wip-gpt/wip-rmxos  (alpha)
rmxOS source head:        82d68c8e9c99
diag run dir:             block-078-runtime-smoke/runs/20260622T025107Z-op092-diag
diag serial sha256:       0023987f3701cb87237528bd3a411f84b078e673c9506ebc732824e79c0e9e8a
```

## Deliverable — exact failing call + layer

**Exact call (the arming site):** `_dispatch_kq_update`, `lib/libdispatch/src/source.c:2170`:

```c
r = dispatch_assume(kevent64(_dispatch_get_kq(), &kev_copy, 1,
        &kev_copy, 1, 0, NULL));
```

submitting the manager timeout kevent `_dispatch_kevent_timeout[qos]`
(source.c:1380-1384: `EVFILT_TIMER`, `EV_ONESHOT`, `fflags=NOTE_ABSOLUTE|NOTE_NSECONDS|NOTE_LEEWAY|note`,
`ident=DISPATCH_KEVENT_TIMEOUT_IDENT_MASK|qos`), with `ke->data = walltime_now + delay`
set in `_dispatch_timers_program2` (source.c:1691-1702).

**Layer that drops it:** ABOVE the kevent submission — inside **libdispatch's
timer management** (the manager timeout-arming / manager-kq fire-back path).
Every layer at or below the `kevent64()` call is exonerated (see below). The
drop is either (a) `dispatch_after`'s programming never reaches the
`_dispatch_kq_update` submission for `_dispatch_kevent_timeout[qos]`, or
(b) the manager kq receives the timer fire but does not process/invoke the
block. **Disambiguating (a) vs (b) needs a libdispatch-internal trace** (the
Implementer op-093 first step), not a kernel fix.

## Suspects RULED OUT (first-hand)

### Suspect #1 — `freebsd_kevent64.c` `flags != 0 → ENOTSUP`

Present at `lib/libdispatch/src/freebsd_kevent64.c:45-48`:

```c
if (flags != 0) { errno = ENOTSUP; return -1; }
```

But this is the **syscall-level** `flags` (6th arg). `_dispatch_kq_update`
(source.c:2170-2171) passes `0`:

```c
kevent64(_dispatch_get_kq(), &kev_copy, 1, &kev_copy, 1, 0, NULL)
```

So the shim accepts it, converts `kevent64_s → kevent`, and calls `kevent()`.
**Ruled out.** (The per-event `EV_RECEIPT` flag set at source.c:2168 is a
kevent.flags bit, not the syscall flags arg, and is handled by the kernel.)

### Suspect #2a — fflag bits (`NOTE_ABSOLUTE` / `NOTE_LEEWAY`)

rmxOS does not define `NOTE_ABSOLUTE` natively; libdispatch's compat layer
aliases it correctly:

```c
// lib/libdispatch/src/freebsd_compat.h:43-47
#ifndef NOTE_ABSOLUTE
#ifdef NOTE_ABSTIME
#define NOTE_ABSOLUTE NOTE_ABSTIME          // rmxOS: NOTE_ABSTIME = 0x10
#else
#define NOTE_ABSOLUTE 0x00000010
#endif
```

and `NOTE_LEEWAY` is compiled to `0` where undefined:

```c
// lib/libdispatch/src/internal.h:603-604
#undef  NOTE_LEEWAY
#define NOTE_LEEWAY 0
```

So the manager timeout `fflags` resolve to `NOTE_ABSTIME|NOTE_NSECONDS|note`
(`note=0` for NORMAL QoS — `DISPATCH_KEVENT_TIMEOUT_INIT(NORMAL, 0)`). The
kernel `filt_timervalidate` (kern_event.c:914) accepts exactly
`(NOTE_TIMER_PRECMASK | NOTE_ABSTIME)`; NORMAL QoS is within the mask.
**Ruled out.** (CRITICAL/BACKGROUND QoS carry `NOTE_CRITICAL`/`NOTE_BACKGROUND`
XNU bits that WOULD trip `filt_timervalidate`'s EINVAL — but `dispatch_after`
on the default queue uses NORMAL, so this doesn't bite here. Flagged for the
Implementer as a latent gap for non-NORMAL QoS timers.)

### Suspect #2b — clock-base / `data` units

libdispatch writes `data = _dispatch_get_nanoseconds() + delay`, where
`_dispatch_get_nanoseconds` (time.c:32) uses **`gettimeofday`** → epoch
wall-time ns. The kernel's `NOTE_ABSTIME` handler (kern_event.c:920-924)
subtracts `getboottimebin` (also epoch) → `to = epoch_target − epoch_boottime =
uptime + delay` → correct positive sbintime. **Ruled out** (bases match).

### The kernel substrate — CONFIRMED WORKING (first-hand)

A minimal pure-libc probe (`kqueue` + `EVFILT_TIMER` + `NOTE_ABSTIME|NOTE_NSECONDS`
+ `data = gettimeofday_ns + 1s` + `EV_ONESHOT`, wait 5s) was run in the rmxOS
guest. It **FIRED** (ident=1, filter=-7), identical to the FreeBSD host:

```text
armed_ok: EVFILT_TIMER NOTE_ABSTIME(0x10)|NOTE_NSECONDS(0x8) data=epoch_ns+1s
result: FIRED — ident=1 filter=-7 data=1 flags=0x10
```

So the kernel `timer_filtops` handles the exact arming libdispatch uses. The
dispatch context's premise ("Kernel EVFILT_TIMER is a REAL filter — the
substrate works — the break is above it") is **confirmed first-hand**.

## Conclusion + recommended op-093 first step

The op-091 `dispatch_after_fired=false` is caused by a drop **inside
libdispatch's timer management**, above the `kevent64()` submission — NOT by
the kevent shim, the fflags, the clock base, or the kernel timer. Recommended
first step for the op-093 Implementer fix: add a trace in `_dispatch_kq_update`
(is it reached for `_dispatch_kevent_timeout[qos]` when `dispatch_after` is
called?) and in the manager kq loop (does the timer event come back? is
`_dispatch_timer_expired` set + the due block invoked?). That pins (a)
submission-never-reached vs (b) fire-back-not-processed and identifies the
exact libdispatch function to fix.

A latent, separate gap surfaced: CRITICAL/BACKGROUND QoS timers carry XNU
`NOTE_CRITICAL`/`NOTE_BACKGROUND` fflags that `filt_timervalidate` rejects
(EINVAL); NORMAL QoS is unaffected, so it does not explain this op-091 gap, but
it should be tracked for non-NORMAL timer parity.

## Diagnostic probe source (reproducible)

Embedded for the Implementer; ran FIRED on rmxOS (run dir above):

```c
#include <sys/event.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <errno.h>
#include <string.h>
int main(void) {
    int kq = kqueue();
    struct timeval tv; gettimeofday(&tv, NULL);
    int64_t now_ns = (int64_t)tv.tv_sec*1000000000LL + (int64_t)tv.tv_usec*1000LL;
    int64_t fire_ns = now_ns + 1000000000LL;          /* epoch ns + 1s */
    struct kevent chg;
    EV_SET(&chg, 1, EVFILT_TIMER, EV_ADD|EV_ONESHOT, NOTE_ABSTIME|NOTE_NSECONDS, fire_ns, NULL);
    if (kevent(kq, &chg, 1, NULL, 0, NULL) < 0) { printf("arm_fail errno=%d\n", errno); return 3; }
    printf("armed_ok\n");
    struct timespec w={5,0}; struct kevent out;
    int n = kevent(kq, NULL, 0, &out, 1, &w);
    if (n==0) { printf("result: TIMEOUT\n"); return 1; }
    printf("result: FIRED data=%ld\n", (long)out.data); return 0;
}
```
