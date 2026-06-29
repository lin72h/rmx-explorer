# op-213 — op-198 v5 reclaim PRE-FLIGHT SMOKE — BLOCKED (fixed binary absent)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery smoke.
Expected artifact: `build/op204-aslmanager-link-fix/aslmanager.op204` (sha `301bfb1d…`).

## VERDICT: BLOCKED — the op-204 fixed aslmanager binary is NOT on disk

### Artifact identity check (first-hand, the GATE)

The dispatch specifies the op-204 fixed aslmanager at `build/op204-aslmanager-link-fix/aslmanager.op204` with sha `301bfb1d…`. **This file does not exist.** Exhaustive search across the host:

```
find /Users/me/wip-mach -name "*aslmanager*" -type f → no match for sha 301bfb1d
sha-checked every built aslmanager binary → only the STATIC variants found:
  block-075-alpha-final-obj/.../aslmanager  sha=7644d6cc...  NEEDED=[libc.so.7]
  block-075-alpha-clean-obj/.../aslmanager  sha=7644d6cc...  NEEDED=[libc.so.7]
  block-068-clean-obj/.../aslmanager        sha=7f9ff81c...  NEEDED=[libc.so.7]
```

ALL available aslmanager binaries are the **static-link variants** (NEEDED libc.so.7-only, `__elf_aux_vector` present) that **SIGSEGV before main** (op-204/op-205 confirmed). The dynamically-linked fixed variant (NEEDED libdispatch.so.5, sha 301bfb1d) was built by the Implementer under op-204 but the artifact is **not present on this host**.

### What's missing

| expected | status |
|---|---|
| `build/op204-aslmanager-link-fix/aslmanager.op204` (sha 301bfb1d) | **ABSENT** — directory doesn't exist |
| Any aslmanager binary with NEEDED libdispatch.so.5 | **ABSENT** — all variants are static |
| A staged image carrying the fixed aslmanager | **ABSENT** |

### Why I can't proceed

Per boundaries: "No source edits, no build (build_is_implementer)." I cannot rebuild the op-204 fixed binary. The Implementer's op-204 artifact must be re-staged to this host before the pre-flight smoke can run.

### What's needed to unblock

1. **Implementer re-stages** the op-204 fixed aslmanager binary to `build/op204-aslmanager-link-fix/aslmanager.op204` (or any path accessible to rx1)
2. **Or**: the Coordinator routes a COMBINED image (op-204 + op-210 integrated) that already carries the fixed aslmanager

Once the fixed binary is available, the smoke is a ~5 minute boot+kickstart+reclaim cycle.

```text
OP213_ASLMGR_RUNS: BLOCKED — fixed binary (sha 301bfb1d) absent from host; only static variants available (SIGSEGV)
OP213_RECLAIM_FIRES: BLOCKED — cannot arm without the fixed binary reaching main
OP213_PREFLIGHT: blocked — Implementer must re-stage the op-204 fixed aslmanager artifact
OP213_VERDICT: blocked (fixed binary sha 301bfb1d absent — all host aslmanager binaries are static SIGSEGV variants)
OP213_TERMINAL status=0
```
