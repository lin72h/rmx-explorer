# op-100 Task 3 — USDT flag-flip is NOT clean: rebuild fails on callout const-qualifier

Date: 2026-06-22. Base rmxOS alpha `129ee3ce8d52`. All work reverted (product
Makefile + obj_root back to clean 129ee3c) — observation-only.

## Outcome

Coordinator approved the scope (Task 1 intact + Task 2 flag flip `-DDISPATCH_USE_DTRACE=0`→`=1` + provider.h generation rule). Task 3 (rebuild + prove a probe fires): the **clean rebuild fails to compile**. Acceptance (a `dispatch:::timer-*` probe firing) **NOT met**. Net: **libdispatch USDT is NOT a clean flag-flip — it needs a source-level re-wire** (Implementer op), exactly the "don't flip blindly" contingency.

## The build break

With `-DDISPATCH_USE_DTRACE=1` + the provider.h rule (`dtrace -h -s src/provider.d`), `make -C lib/libdispatch clean all` fails at:

```text
src/trace.h:68:2: error: passing 'const char *' to parameter of type 'char *'
  discards qualifiers [-Werror,-Wincompatible-pointer-types-discards-qualifiers]
./provider.h:19:43: note: DISPATCH_CALLOUT_ENTRY macro
./provider.h:92:72: note: passing argument to parameter here
src/trace.h:78:2: error: (same) DISPATCH_CALLOUT_RETURN
```

This is in `_dispatch_trace_client_callout` / `_dispatch_trace_client_callout2` (trace.h:63-81, the `#if DISPATCH_USE_DTRACE_INTROSPECTION || DISPATCH_INTROSPECTION` block). That block is being compiled because **`DISPATCH_INTROSPECTION` is auto-enabled** (via the `-D__APPLE__` config path), even though the Makefile doesn't set it explicitly. The Apple-authored `DISPATCH_CALLOUT_ENTRY/RETURN` macros (provider.h) declare `char *` parameters; the rmxOS port's `_dispatch_trace_callout` passes `const char *` (label) → `-Werror` rejects the qualifier drop.

## Diagnosis (two-layer)

1. **Compile:** the callout macros' `char *` vs the port's `const char *` mismatch — a real source-level disagreement introduced by the NextBSD port's const-ification of the label argument. Needs a one-line cast OR a macro/signature reconcile in trace.h.
2. **Link/emit (not yet reached — blocked by #1):** even after the compile is fixed, USDT probe EMISSION into the binary needs a `dtrace -G -s src/provider.d -o provider.o` step (generates the DOF section + the `__dtrace_dispatch___*` symbol definitions) + linking provider.o. `-h` alone gives compile-able macros; `-G` is what actually embeds the probes. (Confirmed: the incremental build linked but had no DOF / no `__dtrace_*` refs — stale `.pico` + missing `-G`.)

## What's intact (from Task 1, unchanged)

- provider.d declarations: verbatim (queue__push/pop, callout__entry/return, timer__*).
- trace.h timer firing path: gated by `DISPATCH_USE_DTRACE` (the flip's target); source.c call sites intact.
- provider.h generation: `dtrace -h` works (header generates).

## Net

The flag flip compiles the timer path cleanly BUT the auto-enabled callout/queue path hits a `const`-qualifier `-Werror` break. So:
- **Timer-only USDT** is achievable by EITHER fixing the const cast (one-line Implementer source edit in trace.h) OR guarding the callout macros off when only DTRACE (not INTROSPECTION) is intended.
- **Full Apple USDT** additionally needs the `dtrace -G` step + provider.o link (ABI-neutral observation infra, but a real build-rule addition beyond `-h`).
- The "USDT-on by default vs debug-build variant" decision (Coordinator-held) should factor in that the const-cast fix is a prerequisite for either.

**Recommendation:** spawn a scoped Implementer op to (a) reconcile the `const char *`/`char *` in trace.h's callout macros, (b) add the `dtrace -G` rule + provider.o link. Then re-issue op-100 Task 3 against that; the firing evidence (a real `dispatch:::timer-fire`) follows directly. No product-tree change was committed here (reverted; observation-only).
