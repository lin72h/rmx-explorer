# op-172 addendum — nlist collision coverage analysis

Date: 2026-06-27. READ-ONLY. Continuation of op-172.

## OP172A_NLIST_WINNER

**The described nlist collision CANNOT be reproduced from source analysis.**

### Source verification (verify-first)

| tree | `sys/sys/nlist_aout.h` struct nlist fields | Darwin/Mach-O nlist.h variant? |
|---|---|---|
| wip-rmxos | n_name (const char*) + n_type + n_other + n_desc + n_value — **ALL PRESENT** | **NONE** (find returned zero) |
| stable-15 | identical (diff empty) | **NONE** |
| NextBSD | identical (only SPDX/comment diffs) | **NONE** |

`include/nlist.h:40` includes `<sys/nlist_aout.h>` — that's where `struct nlist` lives. The struct in ALL trees has `n_other` (char) and `n_desc` (short). `n_name` is `const char *` (not mutable).

No `mach-o/nlist.h` exists anywhere in any tree. No `apple/nlist.h` shadow exists. The apple/System/sys symlink (NextBSD edit 5) points to `../sys` (the real sys directory), not a shadow.

### Pre vs post reconciliation

The 5-edit reconciliation does NOT change which nlist.h wins because:
- All edits affect mach/mach_debug/apple staging blocks
- None touch nlist paths or introduce a competing nlist.h
- The apple/ subdir has NO nlist.h in either tree
- The INCS list in both trees already includes `nlist.h` at the same position

**v3-independent: YES.** A header collision is v3-neutral. But more importantly: no collision EXISTS in the source — the struct is correctly defined everywhere.

```text
OP172A_NLIST_WINNER: FreeBSD <sys/nlist_aout.h> is the ONLY variant; all 5 fields present in all trees; no Darwin competitor; v3-independent=YES
```

## OP172A_COVERAGE

**NOT applicable — no source-level nlist collision found.**

The 5-edit reconciliation doesn't address nlist because nlist doesn't need addressing from the source perspective. The struct is correct in both trees.

The described error ("struct nlist lacks n_other/n_desc") must originate from one of:
1. **A stale staged header** in `tmp/usr/include/` from a previous build attempt (build-env artifact, not source)
2. **An imprecise error description** (the actual attempt-9 error may differ from the summary)
3. **A different include path** (some header conditionally defining a partial nlist)

**Recommendation:** the Implementer should capture the EXACT compiler invocation + error from attempt-9's build log and check what `struct nlist` looks like in the staged `tmp/usr/include/sys/nlist_aout.h` at the point of failure. If the staged header differs from the source, it's a build-env stale-cache issue (clean MAKEOBJDIRPREFIX + rebuild). If it matches, the error is something else entirely.

```text
OP172A_COVERAGE: n/a — no source-level collision found; reconciliation neither covers nor fails to cover a non-existent defect
```

## OP172A_SIBLING_EDIT

**N/A.** No edit proposed because no source-level defect exists. The nlist_aout.h is correct in all three trees.

If the Implementer finds a staged-header divergence (stale tmp/usr/include/), the fix is `rm -rf MAKEOBJDIRPREFIX && make buildworld` (clean rebuild), not an include/Makefile edit.

```text
OP172A_SIBLING_EDIT: n/a — no donor edit needed; source is correct
OP172A_TERMINAL status=0
```

## Summary

The Arranger's nlist wall description ("struct nlist lacks n_other/n_desc, n_name treated as mutable char *") does NOT match the source in ANY of the three trees. All trees have `struct nlist` with all 5 fields, `n_name` as `const char *`. No Darwin/Mach-O nlist.h variant exists to cause a collision. The 5-edit reconciliation is unaffected (nlist paths untouched by the mach/apple staging edits).

The most likely explanation: a **stale staged header** from a previous build attempt, or an **imprecise error summary**. The Implementer should capture the exact compiler error + inspect the staged header before proposing any fix.
