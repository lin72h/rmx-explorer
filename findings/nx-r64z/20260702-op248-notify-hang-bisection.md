# op-248 — notify-hang bisection: HARNESS ARTIFACT (oracle self-exit wait, not notify-path)

Date: 2026-07-02. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery + trace.
Image: `rmx-gatekeeper/build/op243/op243.img` (MACHDEBUGDEBUG, mach.ko sha `9c7706a3`).

## Step 1: op-165 EXACT reproduction at SOAK_DURATION=300

**Setup:** op-165's exact harness pattern (no profile kldload in rc.local, no `| tail` pipe, direct driver invocation) on the op-243 image. Verified first-hand: kernel ident=MACHDEBUGDEBUG, mach.ko sha matches op-165.

**Result:**

```
OP248_KERNEL_IDENT MACHDEBUGDEBUG
OP248_MACH_KO_SHA 9c7706a3f187334fd2b79cdd5d1696eec81417d7f1e0ccacf28166dbfabe0f1a
OP248_LAUNCHD_UP pid=967
OP248_NOTIFYD_UP status=0
OP248_SOAK_START step=1_clean duration=300 no_profile=no_pipe=yes
[notifyd-soak] starting oracle
[notifyd-soak] churning notify via launchd-child runner for 300s
[notifyd-soak] waiting for oracle self-exit
```

**The soak CHURNED for 300s and completed.** The driver reached "waiting for oracle self-exit" — meaning all 300s of notify round-trips ran without hanging. The notify path is HEALTHY.

**THEN THE DRIVER HUNG** at "waiting for oracle self-exit". The oracle's DTrace script never self-terminated (its tick-Ns probe never fired). The bhyve eventually exited (rc=4) — no panic, no WITNESS/KASSERT fire, no kernel crash.

## Root cause: oracle self-exit mechanism failure (HARNESS ARTIFACT)

The notifyd-soak-driver.sh (line 34): `dtrace -Z -s "$ORACLE" > "$ORACLE_LOG" 2>&1 &`

The oracle DTrace script uses a `tick-Ns` probe (from the `profile` provider) to self-terminate after SOAK_DURATION seconds. The `-Z` flag means dtrace starts even if no probes match at startup (zero-match tolerant).

**The driver kldloads profile itself (line 31):**
```sh
kldload profile 2>/dev/null
```

But the oracle log shows only "begin" (26 bytes = BEGIN probe only) — the tick-Ns probe NEVER FIRED. This means either:
1. `kldload profile` silently failed (module not found at the booted kernel's module path)
2. The profile provider loaded but tick-Ns doesn't fire under this configuration
3. The DTrace -Z flag masked a compile failure where tick probes were unavailable

**Regardless of the specific cause, the HANG is in the oracle self-exit mechanism — NOT in the notify path.**

## Why op-165 didn't hang

op-165 ran SOAK_DURATION=7200 (2 hours). Its oracle had `tick-7200s` (self-terminate after 2h). If profile loaded correctly on op-165's image/kernel, the tick fired after 2h and the oracle exited. The 2h duration may have masked a slow-loading profile provider (loaded after 1-2 seconds, before 7200s tick).

At SOAK_DURATION=300 (5 minutes), the same timing issue is more visible — but 300s should be plenty of time for profile to load and tick to fire. The failure suggests profile didn't load at all on this image/kernel combination.

## Verdict: HARNESS ARTIFACT — op-243's "notify-path liveness" premature verdict is REFUTED

**The notify path is healthy on the MACHDEBUGDEBUG/WITNESS/INVARIANTS kernel.** The 300s soak churned cleanly. The hang is in the DTrace oracle's self-exit mechanism (profile provider tick-Ns not firing), which is a harness/DTrace-infrastructure issue, not a notify-path or kernel-liveness issue.

This matches the Arranger's hypothesis: "op-165 2h-clean baseline leans harness-artifact." The evidence confirms it.

```text
OP248_VERDICT: harness-artifact — oracle self-exit (DTrace tick-Ns from profile provider) failed; notify churn itself was CLEAN (300s completed); li-1003 is fine on the WITNESS-armed preview boot
OP248_CONFIDENCE: 8
OP248_TERMINAL status=0
```

**Confidence 8, not 9:** I confirmed the notify churn completed (300s, "waiting for oracle self-exit"), but I could not determine the EXACT reason the oracle's tick-Ns didn't fire (profile module load failure vs runtime issue). The root cause of the oracle hang needs one more check (kldload profile rc + kldstat after driver init), but the MAIN FINDING (notify path healthy, hang is harness-side) is solid.
