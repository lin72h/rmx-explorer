# op-100 Task 1 — libdispatch USDT firing sites: INTACT, but two-flag gating

Date: 2026-06-22. Read-only verification (no gate needed). Base rmxOS alpha `129ee3ce8d52`.

## Verdict

The Apple USDT firing sites survived the NextBSD port **intact** (not stripped).
BUT the dispatch's premise — that flipping `Makefile:15 -DDISPATCH_USE_DTRACE=0`
lights up the whole provider — is **half right**: trace.h gates the queue/callout
probes behind a *separate* flag (`DISPATCH_USE_DTRACE_INTROSPECTION`) the Makefile
does not set. The one-line flip activates the **timer** probes only.

## Evidence (file:line)

**provider.d** — Apple's declarations, verbatim (lib/libdispatch/src/provider.d):
- `queue__push` :46, `queue__pop` :49
- `callout__entry` :59, `callout__return` :61
- `timer__configure` :75, `timer__program` :77, `timer__wake` :93, `timer__fire` :94

**trace.h — provider.h inclusion** (lib/libdispatch/src/trace.h):
- `:32  #if DISPATCH_USE_DTRACE || DISPATCH_USE_DTRACE_INTROSPECTION` → `:37 #include "provider.h"`. Either flag pulls in the probe macros.

**Timer firing path — gated by `DISPATCH_USE_DTRACE`** (the flag the flip touches):
- trace.h `:210 #if DISPATCH_USE_DTRACE` … `:322 #endif` defines `_dispatch_trace_timer_function` / `_dispatch_trace_timer_params` (the wrappers that fire the timer__* probes).
- source.c call sites intact:
  - `:1079 _dispatch_trace_timer_program(...)`
  - `:1081 _dispatch_trace_timer_wake(...)`
  - `:1095-1096 _dispatch_trace_timer_configure_enabled()` / `_dispatch_trace_timer_configure(...)`
  - `:1105` (telemetry guard)
  - `:1599 _dispatch_trace_timer_fire(dr, data, missed)`
- → flipping `-DDISPATCH_USE_DTRACE=0`→`1` activates the timer probes end-to-end (declaration + macros + call sites all intact).

**Queue/callout firing path — gated by `DISPATCH_USE_DTRACE_INTROSPECTION` (separate flag):**
- trace.h `:40 #if DISPATCH_USE_DTRACE_INTROSPECTION` → `_dispatch_trace_callout` (fires callout__entry/return).
- trace.h `:60/86/130 #if DISPATCH_USE_DTRACE_INTROSPECTION || DISPATCH_INTROSPECTION` → `_dispatch_trace_queue_push`/`_pop`/`_continuation_*` wrappers (fire queue__push/pop). These `#define`-replace `_dispatch_queue_push` etc., so the queue.c call sites fire the probes only when INTROSPECTION is on.
- The Makefile sets **neither** `DISPATCH_USE_DTRACE_INTROSPECTION` **nor** `DISPATCH_INTROSPECTION`. The one-line `DISPATCH_USE_DTRACE` flip does **not** activate these.

**Makefile** (lib/libdispatch/Makefile):
- `:15 CFLAGS+= -D__APPLE__ -DDISPATCH_USE_DTRACE=0` — only `DISPATCH_USE_DTRACE` is set (=0). No INTROSPECTION flag.

## Implication for the flag flip

The "one-line flip" (`-DDISPATCH_USE_DTRACE=0` → `=1`) is **genuine and clean for the timer probes** — `dispatch:::timer-fire` / `-configure` / `-program` / `-wake` will light up. It is **not** a re-wire (no stripped sites to repair).

But it leaves `queue__push/pop` + `callout__entry/return` dark. Full Apple-USDT coverage needs a **second** flag: `-DDISPATCH_USE_DTRACE_INTROSPECTION=1`. That's a slightly bigger change — it `#define`-replaces `_dispatch_client_callout` / `_dispatch_queue_push` with trace wrappers (per-call probe-enabled check, observation-only, no logic change) — so it adds a small per-callout/push overhead. The "USDT-on by default vs debug-build variant" decision (Coordinator-held) should weigh: timer-only (cheap, one flag) vs full provider (richer, two flags, minor overhead).

## Net

Clean flag-flip territory — sites are intact, no re-wiring needed. The scope
question is **timer-only (one flag) vs full Apple USDT (two flags)**, not
"flip blindly vs repair." Coordinator decision held at Task 2.
