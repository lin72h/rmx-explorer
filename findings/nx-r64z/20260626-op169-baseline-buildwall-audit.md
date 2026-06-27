# op-169 — baseline-buildworld header-staging wall batch-audit (READ-ONLY)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY — no builds.
Source trees: `wip-gpt/wip-rmxos` (alpha), `nx/NextBSD`, `freebsd-src-official-stable-15` (op-149 base).

## Q1 (GATE): build-base tree recommendation

### Candidate trees identified

| tree | path | Darwin-compat BSD.include.dist entries | status |
|---|---|---|---|
| **wip-rmxos** (alpha) | `/Users/me/wip-mach/wip-gpt/wip-rmxos` | **5** | BUILT the alpha obj — PROVEN clean for alpha target |
| **NextBSD** | `/Users/me/wip-mach/nx/NextBSD` | **8** | Most complete Darwin-compat staging; 488-line diff from wip-rmxos |
| **stable-15** | `/Users/me/wip-mach/freebsd-src-official-stable-15` | **2** | Minimal staging; op-149 keeps hitting walls |

### Spot-check: 3 wall-class files

All 3 files exist in ALL trees (source is present everywhere):
- `etc/mtree/BSD.include.dist` — present everywhere
- `sys/sys/thrworkq.h` — present everywhere
- `include/iconv.h` with `__iconv_bool` typedef (lines 43/45/47) — present everywhere, identical conditional typedef pattern

**The walls are NOT about source-file existence — they're about STAGING COMPLETENESS in BSD.include.dist.**

### Recommendation: SWITCH to NextBSD for the v3 tryout

Rationale:
1. **NextBSD has 4× the Darwin-compat entries** (8 vs stable-15's 2). The gap is large.
2. **wip-rmxos (5 entries) is proven for alpha** but may lack entries needed for v3 buildworld.
3. **stable-15 (2 entries) is farthest behind** — each missing entry = one full buildworld cycle to discover + fix. At least 3+ confirmed remaining (dispatch/private/xpc).
4. **Each buildworld cycle costs hours.** 3+ walls × hours/cycle = significant time. NextBSD potentially moats the grind entirely.
5. NextBSD's 488-line diff from wip-rmxos suggests it's a MORE EVOLVED staging — it may have fixed walls that wip-rmxos hasn't hit yet.

**Coordinator decision**: tree-choice is yours. If NextBSD builds clean → skip the grind. If it has its own walls → at least the starting point is farther along.

## Q2: wall batch enumeration (assuming stable-15 stays)

### CONFIRMED walls (diff-backed against wip-rmxos)

| # | wall | evidence | proposed fix |
|---|---|---|---|
| 1 | **dispatch** dir missing from BSD.include.dist | diff wip-rmxos:stable-15 lines 282-283 | Add `dispatch` + `..` stanza to `etc/mtree/BSD.include.dist` under the lib/ section |
| 2 | **private** dir missing | diff lines 458-459 | Add `private` + `..` stanza |
| 3 | **xpc** dir missing | diff lines 509-510 | Add `xpc` + `..` stanza |

All 3 are in `etc/mtree/BSD.include.dist`. Each is a 2-line addition matching the wip-rmxos pattern. The Implementer can batch all 3 in one edit.

### DOCUMENTED wall (from op-149 handoff)

| # | wall | evidence | proposed fix |
|---|---|---|---|
| 4 | **pthread/ dir-create race** during includes phase | `rmx-explorer-2/findings/.../20260626-op149-build-failure-handoff.md`: `install: target directory '.../tmp/usr/include/pthread/' does not exist` | Build-infra issue (NOT staging). Options: (a) lower `-j` for includes phase; (b) pre-seed mtree before includes; (c) reuse existing buildworld objdir instead of fresh MAKEOBJDIRPREFIX. NOT a BSD.include.dist fix. |

### SUSPECTED wall (pattern-matched, not diff-confirmed)

| # | wall | evidence | status |
|---|---|---|---|
| 5 | **iconv `__iconv_bool` staging** | `iconv-internal.h` references `__iconv_bool` without `#include <iconv.h>` in BOTH trees. If includes-phase ordering installs `iconv.h` to staging before `libc/iconv/` compiles → works. If not → fails. | **LIKELY A NON-ISSUE** — both trees have the same pattern and wip-rmxos builds clean. The iconv wall may be an includes-phase ORDERING artifact under the fresh MAKEOBJDIRPREFIX (same root cause as wall #4). If the build-infra ordering is fixed (wall #4), iconv may resolve automatically. |

### Non-walls (verified clean)

- `*-internal.h` headers in `lib/libc/` — **identical between trees**. No missing-include defect class found.
- `iconv/` directory listing — **identical between trees**. Same files, same structure.
- `_startup_libs` — **not found in either tree** (may be a different name or doesn't exist in stable-15).

## OP169 markers

```text
OP169_BUILD_BASE: switch-recommended (NextBSD has 8 Darwin-compat entries vs stable-15's 2; 488-line BSD.include.dist diff from alpha; grind would cost 3+ buildworld cycles)
OP169_ICONV_FIX: likely-non-issue (same source pattern in both trees; may resolve with build-infra ordering fix from wall #4)
OP169_WALL_BATCH: 3 confirmed (dispatch/private/xpc BSD.include.dist entries) + 1 documented (pthread dir-create race) + 1 suspected-non-issue (iconv __iconv_bool)
OP169_VERDICT: batch-ready 3 confirmed walls / switch-base-recommended to NextBSD
OP169_TERMINAL status=0
```
