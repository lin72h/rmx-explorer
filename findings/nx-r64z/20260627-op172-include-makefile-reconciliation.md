# op-172 — NextBSD-faithful include/Makefile reconciliation (READ-ONLY)

Date: 2026-06-27. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY.
Donor: `nx/NextBSD/include/Makefile` (424 lines, @236c336).
Target: `wip-gpt/wip-rmxos/include/Makefile` (529 lines, branch `op-149-x86-64-v3-alpha`).

## Q1: failing consumer + build phase

**The attempt-8 build log** is not in my workspace (likely in rx2's). The build log I DO have (`build/op149/buildworld-kernel.log`) shows the pthread dir-create race:
```
install: target directory `.../tmp/usr/include/pthread/' does not exist
*** [_INCSINS] Error code 64
```
This is an includes-phase dir-create issue, NOT an Availability.h consumer.

**Source-level phase determination** (verify-first, not from the missing log):
The Darwin-compat headers that include `<Availability.h>` — `<os/object.h>`, `<dispatch/base.h>`, `<xpc/base.h>` — are consumed during the **libraries phase** (lib/libdispatch, lib/libxpc, lib/libosl etc. compile AFTER the includes phase stages headers). The includes phase stages headers via `include/Makefile`; the libraries phase compiles against the staged headers.

**Q1 VERDICT: consumer in libraries phase (after staging)** → staging-structure fix applies → the include/Makefile port IS sufficient. **No phase inversion.**

```text
OP172_FAIL_CONSUMER_PHASE: libraries-phase consumer (os/object.h→Availability.h via lib/libdispatch/lib/libxpc); includes-phase staging fix applies
```

## Q2: exact NextBSD→wip-rmxos reconciliation diff

### Edit 1 (CONFIRMED): Restore `mach_debug` to SUBDIR
- **Donor**: NextBSD `include/Makefile:21`: `SUBDIR+= apple gen libkern mach mach_debug os servers`
- **Target**: wip-rmxos `include/Makefile:7`: `SUBDIR= apple arpa gen libkern mach os protocols pthread rpcsvc rpc servers ssp xlocale`
- **Fix**: Add `mach_debug` to the SUBDIR list (between `mach` and `os`)
- **FB-15 conflict**: None — mach_debug is a Darwin-compat subdir, absent from vanilla FB-15

### Edit 2 (CONFIRMED): Restore `sys/mach_debug` to LSUBDIRS
- **Donor**: NextBSD `include/Makefile:82-83`: `... sys/mach sys/mach_debug`
- **Target**: wip-rmxos `include/Makefile:75-78`: `... sys/mach \` (no `sys/mach_debug`)
- **Fix**: Add `sys/mach_debug` after `sys/mach` in LSUBDIRS

### Edit 3 (CONFIRMED): Restore sys/mach + sys/mach_debug staging blocks in `includes` target
- **Donor**: NextBSD `include/Makefile:251-293` — four `.if exists(...)` blocks:
  ```makefile
  .if exists(${.CURDIR}/../sys/sys/mach)
      ${INSTALL} -d ... ${DESTDIR}${INCLUDEDIR}/sys/mach
      cd ${.CURDIR}/../sys/sys/mach ; \
      ${INSTALL} -C ... *.h *.defs ${DESTDIR}${INCLUDEDIR}/sys/mach
  .endif
  .if exists(${.CURDIR}/../sys/sys/mach/ipc)
      ... (same pattern for sys/mach/ipc)
  .endif
  .if exists(${.CURDIR}/../sys/sys/mach_debug)
      ... (same pattern for sys/mach_debug)
  .endif
  .if exists(${.CURDIR}/../sys/sys/mach/device)
      ... (same pattern for sys/mach/device)
  .endif
  ```
- **Target**: wip-rmxos has NONE of these blocks — they were dropped during the port.
- **Fix**: Port the 4 blocks from NextBSD, adapting `${.CURDIR}/../sys` → `${SRCTOP}/sys` and `${DESTDIR}` → `${SDESTDIR}` (FB-15 style used in wip-rmxos's other staging blocks).
- **FB-15 conflict**: PATH variable style — wip-rmxos uses `${SRCTOP}/sys` (FB-15 convention) vs NextBSD's `${.CURDIR}/../sys`. Use FB-15 style for consistency.

### Edit 4 (CONFIRMED): Restore WRONGLY_ADDED_AS_FILES logic
- **Donor**: NextBSD `include/Makefile:87-89`:
  ```makefile
  WRONGLY_ADDED_AS_FILES= gen apple/uuid
  ```
  Plus the staging loop at lines 287-293:
  ```makefile
  .for _F in ${WRONGLY_ADDED_AS_FILES}
      if [ -f ${DESTDIR}${INCLUDEDIR}/${_F} ]; then \
          rm -f ${DESTDIR}${INCLUDEDIR}/${_F}; \
          mkdir ${DESTDIR}${INCLUDEDIR}/${_F}; \
      fi
  .endfor
  ```
- **Target**: wip-rmxos REMOVED both the variable and the loop.
- **Fix**: Restore both, adapting `${DESTDIR}` → `${SDESTDIR}`.
- **Purpose**: Handles a staging hazard where `gen` and `apple/uuid` exist as FILES (from the base image) but need to be DIRECTORIES for the staging. Without this, the includes phase fails when trying to install into a file path.

### Edit 5 (CONFIRMED): Restore apple/System symlink
- **Donor**: NextBSD `include/Makefile:298-299`:
  ```makefile
  mkdir -p ${DESTDIR}${INCLUDEDIR}/apple/System
  ln -fs ../sys ${DESTDIR}${INCLUDEDIR}/apple/System/sys
  ```
- **Target**: wip-rmxos MISSING.
- **Fix**: Add the mkdir + ln -fs lines, adapting `${DESTDIR}` → `${SDESTDIR}`.
- **Purpose**: Creates the Apple-style `apple/System/sys` symlink that Darwin-compat consumers expect.

### Edit 6 (NEEDS-CARE): APSL headers block ordering
- **Donor**: NextBSD `include/Makefile:32-51` — coherent `# APSL headers` INCS+= block with 16 headers (Availability.h, ..., utmp.h)
- **Target**: wip-rmxos DISSOLVED these into the main INCS list (lines 17-37)
- **Status**: The SAME headers ARE listed in wip-rmxos's INCS — the staging effect is IDENTICAL. This is a COSMETIC/documentation difference, not a functional one.
- **NEEDS-CARE**: If NextBSD's build system relies on the SEPARATE block for ordering or variable expansion, dissolving it might cause subtle issues. But since both lists install the same headers via the same `INCS+=` mechanism, this is likely a non-issue. **Do NOT port unless a functional difference is demonstrated.**

### Edit count
- **5 CONFIRMED** (donor-line-backed, clean on FB-15 with SRCTOP adaptation)
- **1 NEEDS-CARE** (cosmetic, likely non-functional)
- Total: **6 edits**

```text
OP172_RECONCILE_DIFF: 5 confirmed + 1 needs-care (cosmetic)
OP172_EDIT_CONFIRMED_COUNT: 5 confirmed / 1 needs-care
```

## Q3: class coverage

**Does this ONE reconciliation clear the header-staging wall class?**

**YES for the include/Makefile staging walls.** The 5 confirmed edits restore:
- mach_debug SUBDIR + LSUBDIRS (missing mach_debug headers)
- sys/mach staging blocks (the 18→2 gap — restores the 4 `.if exists()` install blocks)
- WRONGLY_ADDED_AS_FILES (gen/apple/uuid staging hazard)
- apple/System symlink

**Residual non-include-Makefile walls:**
1. **pthread/ dir-create race** (from the build log I have): `install: target directory '.../tmp/usr/include/pthread/' does not exist`. This is a build-infra includes-phase ordering issue under fresh MAKEOBJDIRPREFIX, NOT an include/Makefile staging defect. Fix: lower `-j` for includes phase OR pre-seed mtree. Independent of this reconciliation.
2. **iconv `__iconv_bool`**: already fixed (op-149 commit 91f7a2f: `libc_nonshared: use source public headers for iconv`). Independent.
3. **thrworkq.h**: already fixed (op-149 commit ca9eb67). Independent.

**These 3 residuals are NOT include/Makefile walls — they're build-infra + already-fixed siblings.**

```text
OP172_CLASS_COVERAGE: clears include/Makefile staging wall class (5 edits); residual: pthread dir-create race (build-infra, not staging) + iconv/thrworkq (already fixed)
```

## OP172 markers

```text
OP172_FAIL_CONSUMER_PHASE: libraries-phase (os/object.h→Availability.h); staging fix applies
OP172_RECONCILE_DIFF: 5 confirmed edits (mach_debug SUBDIR/LSUBDIRS + sys/mach staging blocks + WRONGLY_ADDED_AS_FILES + apple/System symlink) + 1 needs-care (APSL block cosmetic)
OP172_EDIT_CONFIRMED_COUNT: 5 confirmed / 1 needs-care
OP172_CLASS_COVERAGE: clears include/Makefile wall class; 3 residual siblings (pthread race + iconv/thrworkq already fixed)
OP172_VERDICT: reconciliation-plus-residual (diff covers staging class; pthread dir-create race remains as build-infra residual)
OP172_TERMINAL status=0
```
