STATUS: Draft / Awaiting Review
GATES: No stable/15 base update starts until this plan is accepted by parent.

# Stable/15 Base-Update Plan

This plan defines the first FreeBSD stable/15 candidate validation after the
oracle M4 D14 guest slice became green from the oracle repo. It is a plan only.
It does not update any source tree, rebuild the kernel, run guests, create
certification claims, or delete source tests.

## 1. Current-State Provenance

Oracle repo:

- path: `/Users/me/wip-mach/wip-gpt-oracle`
- current SHA: `a27c00c`
- current commit: `m4: add d14 launchctl plist parity task`

Source parity repo:

- path: `/Users/me/wip-mach/wip-gpt`
- current SHA: `a30ef3f`
- parity tag: `oracle-parity-a30ef3f`
- parity tag dereferenced commit: `a30ef3f`
- rule: the parity tag is immutable for this update and must not move.

Current FreeBSD/rmxOS source:

- path: `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- current SHA recorded by latest D14 evidence: `d4876c3fd9af`
- local current SHA at drafting time: `d4876c3fd9af`
- role: current active releng/15.1 source root for the accepted D14 baseline
- first stable/15 validation rule: do not mutate this nested source root during
  the first candidate pass.

First stable/15 candidate source root:

- path: `/Users/me/wip-mach/freebsd-src-official-stable-15`
- role: first candidate source root for stable/15 validation
- expected handling: update/fetch this external official source root, not the
  nested `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` root.

First stable/15 candidate objdir:

- path: `/Users/me/wip-mach/build/official-stable15-mach-obj`
- role: first candidate launchd lane objdir prefix
- rule: this value is explicit candidate configuration, not a releng151 fallback
  and not an oracle/source repo-root-derived path.

Current launchd lane environment from latest D14 evidence:

- `NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach`
- `NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- `NXPLATFORM_KERNEL_OBJDIRPREFIX=/Users/me/wip-mach/build/releng151-mach-obj`
- `MAKEOBJDIRPREFIX=/Users/me/wip-mach/build/releng151-mach-obj`
- `NXPLATFORM_ARTIFACTS_DIR=/Users/me/wip-mach/artifacts/nxplatform`
- `NXPLATFORM_PHASE1_LAUNCHD_HARNESS_WORKDIR=/Users/me/wip-mach/build/phase1-launchd-harness-link`
- `NXPLATFORM_PHASE07_LIBDISPATCH_DIR=/Users/me/wip-mach/build/phase07-libdispatch`
- `NXPLATFORM_KERNEL_CONF=MACHDEBUGDEBUG`
- base profile in evidence: `null`

Latest green D14 evidence:

- path:
  `priv/runs/migration-parity/20260604T090700.280459Z-phase08-d14-launchctl-plist/`
- `parity.json` result: `parity_passed`
- `oracle_commit`: `a27c00c`
- `legacy_test_commit`: `a30ef3f`
- `freebsd_src_commit`: `d4876c3fd9af`
- boot identity: passed
- marker comparison: passed
- hard-stop scan: passed
- negative control: passed

Latest D14 boot artifact hashes:

- kernel:
  `c6f0d3eb12498504243c60694969790893e397fcfb367e10f39ddf12d4a680eb`
- `mach.ko`:
  `e529ff107eaa49fa780aabd9487fc04dd20069ccec72a48cb939d88ab626d0c8`
- guest image:
  `1d8245bb7f4e1bfca0462dd2e4f489d89ec992aaa58fedbce4f4f36920a16f72`

## 2. Candidate Validation Boundary

The first stable/15 pass validates an external official stable/15 candidate
source root. It does not mutate the current nested active source root.

Allowed in the candidate validation lane after this plan is accepted:

- fetch/update `/Users/me/wip-mach/freebsd-src-official-stable-15`
- record current active source SHA and candidate source SHA
- use the explicit candidate objdir prefix
  `/Users/me/wip-mach/build/official-stable15-mach-obj`
- rebuild kernel/module/guest image as needed
- run oracle checks against the candidate base

Not allowed in the candidate validation lane:

- moving or rewriting `oracle-parity-a30ef3f`
- mutating `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- deleting source repo tests
- creating `certification/` or certification claims
- committing raw artifacts or guest output
- mixing D17/D18 migration into the base update
- changing oracle test harness code in the same commit as the base update unless a
  harness break is proven and separately justified

After candidate D14 passes, parent decides one of:

1. keep `/Users/me/wip-mach/freebsd-src-official-stable-15` as the external
   active stable/15 source root
2. rebase or move nested `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` to
   the accepted stable/15 SHA
3. keep releng/15.1 active and leave stable/15 as candidate-only

If the oracle harness needs a fix to run against the candidate base, split it:

1. base update evidence showing the failure
2. separate harness-fix review and commit
3. rerun post-update verification

## 3. Pre-Update Baseline

Before touching the official candidate source root, rerun or explicitly
reference the latest accepted baseline from the current active nested source
root.

Required host-only checks:

```sh
mix oracle.migration.parity phase08.source_transform
mix oracle.migration.parity phase08.marker_manifest
```

Required L2 guest check:

```sh
env \
  NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach \
  NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15 \
  NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD=/Users/me/wip-mach/build/releng151-mach-obj \
  NXPLATFORM_ARTIFACTS_DIR=/Users/me/wip-mach/artifacts/nxplatform \
  NXPLATFORM_PHASE1_LAUNCHD_HARNESS_WORKDIR=/Users/me/wip-mach/build/phase1-launchd-harness-link \
  NXPLATFORM_PHASE07_LIBDISPATCH_DIR=/Users/me/wip-mach/build/phase07-libdispatch \
  mix oracle.migration.parity phase08.d14.launchctl_plist_inert_load
```

The pre-update baseline record must capture:

- oracle SHA
- source parity SHA/tag
- FreeBSD source SHA
- selected lane
- resolved `NXPLATFORM_FREEBSD_SRC`
- resolved `NXPLATFORM_KERNEL_OBJDIRPREFIX`
- resolved `MAKEOBJDIRPREFIX`
- kernel path and SHA256
- `mach.ko` path and SHA256
- guest image path and SHA256
- marker comparison result
- hard-stop scan result
- negative control result

The latest green D14 evidence listed in section 1 may be used as the initial
pre-update baseline if parent accepts it as fresh enough. Otherwise rerun it
immediately before the update.

## 4. Candidate Update Steps

The update must use explicit configured inputs. Do not rely on releng151,
releng151-rc1, `/usr/obj`, or repo-root-derived objdir fallbacks as canonical
stable/15 values.

Proposed candidate validation sequence:

1. Confirm oracle and source state:

   ```sh
   git -C /Users/me/wip-mach/wip-gpt-oracle rev-parse --short HEAD
   git -C /Users/me/wip-mach/wip-gpt rev-parse --short HEAD
   git -C /Users/me/wip-mach/wip-gpt rev-parse --short oracle-parity-a30ef3f^{commit}
   git -C /Users/me/wip-mach/wip-gpt/freebsd-src-stable-15 rev-parse --short HEAD
   git -C /Users/me/wip-mach/freebsd-src-official-stable-15 rev-parse --short HEAD
   ```

2. Record current active and candidate FreeBSD SHAs:

   ```sh
   active_releng151_sha=$(git -C /Users/me/wip-mach/wip-gpt/freebsd-src-stable-15 rev-parse --short HEAD)
   old_candidate_sha=$(git -C /Users/me/wip-mach/freebsd-src-official-stable-15 rev-parse --short HEAD)
   ```

3. Fetch/update `/Users/me/wip-mach/freebsd-src-official-stable-15` using the
   parent-approved stable/15 target ref. The exact remote/ref must be recorded in
   the update evidence. Do not fetch/update the nested
   `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` tree in this pass.

4. Record new candidate FreeBSD SHA:

   ```sh
   new_candidate_sha=$(git -C /Users/me/wip-mach/freebsd-src-official-stable-15 rev-parse --short HEAD)
   ```

5. Use the first candidate profile name and objdir prefix explicitly:

   ```sh
   NXPLATFORM_BASE_PROFILE=official-stable15-candidate
   NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/freebsd-src-official-stable-15
   NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD=/Users/me/wip-mach/build/official-stable15-mach-obj
   ```

   These exact values must be pinned in `env.local` or the caller environment.
   They must not be silently derived from the oracle repo root, source repo root,
   releng151 defaults, releng151-rc1 defaults, or `/usr/obj`.

6. Rebuild kernel/module as needed using the selected explicit objdir prefix.
   The expected string-keyed paths are:

   ```text
   kernel:
   ${NXPLATFORM_KERNEL_OBJDIRPREFIX}${NXPLATFORM_FREEBSD_SRC}/amd64.amd64/sys/${KERNEL_CONF}/kernel

   mach.ko:
   ${NXPLATFORM_KERNEL_OBJDIRPREFIX}${NXPLATFORM_FREEBSD_SRC}/amd64.amd64/sys/modules/mach/mach.ko
   ```

7. Rebuild or refresh the guest image if the base update requires it. Any guest
   image used for verification must be hashable and recorded in boot identity.

8. Do not commit raw build output, VM images, serial logs, or `priv/runs/`
   evidence.

## 5. Post-Update Verification

First verify the launchd lane environment against the explicit candidate
configuration:

```sh
env \
  NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach \
  NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/freebsd-src-official-stable-15 \
  NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD=/Users/me/wip-mach/build/official-stable15-mach-obj \
  NXPLATFORM_ARTIFACTS_DIR=/Users/me/wip-mach/artifacts/nxplatform \
  NXPLATFORM_PHASE1_LAUNCHD_HARNESS_WORKDIR=/Users/me/wip-mach/build/phase1-launchd-harness-link \
  NXPLATFORM_PHASE07_LIBDISPATCH_DIR=/Users/me/wip-mach/build/phase07-libdispatch \
  NXPLATFORM_BASE_PROFILE=official-stable15-candidate \
  mix oracle.env.check --lane launchd
```

Then run D14 first:

```sh
env \
  NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach \
  NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/freebsd-src-official-stable-15 \
  NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD=/Users/me/wip-mach/build/official-stable15-mach-obj \
  NXPLATFORM_ARTIFACTS_DIR=/Users/me/wip-mach/artifacts/nxplatform \
  NXPLATFORM_PHASE1_LAUNCHD_HARNESS_WORKDIR=/Users/me/wip-mach/build/phase1-launchd-harness-link \
  NXPLATFORM_PHASE07_LIBDISPATCH_DIR=/Users/me/wip-mach/build/phase07-libdispatch \
  NXPLATFORM_BASE_PROFILE=official-stable15-candidate \
  mix oracle.migration.parity phase08.d14.launchctl_plist_inert_load
```

Compare post-update D14 against the pre-update D14 baseline:

- `freebsd_src_commit`: must be the official stable/15 candidate SHA.
- `legacy_test_commit`: must remain `a30ef3f`.
- `oracle_commit`: should remain the accepted oracle harness SHA unless a
  separate harness-fix commit was approved.
- `NXPLATFORM_FREEBSD_SRC`: must be
  `/Users/me/wip-mach/freebsd-src-official-stable-15`.
- `NXPLATFORM_KERNEL_OBJDIRPREFIX`: must be
  `/Users/me/wip-mach/build/official-stable15-mach-obj`.
- kernel, `mach.ko`, and guest image hashes must be present.
- `mach_module=loaded` must be present.
- D14 marker comparison must pass.
- hard-stop scan must pass.
- negative control must pass.

After D14 passes, parent decides whether D17/D18 are required before broader
adoption. D17/D18 must not be migrated or executed as part of this base-update
commit unless parent explicitly expands scope.

## 5.1 S3/D14 Candidate Result

The first official stable/15 candidate S3/D14 attempt is preserved as ignored
evidence:

- S3 staging evidence:
  `priv/runs/stable15-base-update/20260604T095633Z-s3-official-stable15-stage/s3-stage-result.json`
- D14 evidence:
  `priv/runs/migration-parity/20260604T095950.862739Z-phase08-d14-launchctl-plist/`

Observed result:

- S3 staging: pass.
- D14 verification: fail.
- Failure class: `candidate_source_runtime_gap`.
- This was not a staging/path mixup: boot identity passed with the official
  stable/15 candidate source, `MACHDEBUGDEBUG` kernel, candidate `mach.ko`, and
  candidate guest image hashes.
- Candidate source commit: `63ce90100a4e`.
- First hard stop: `nosys 468`.
- Second hard stop: WITNESS `lock order reversal`.

Current interpretation:

- The candidate tree has `THRWORKQ` config plumbing, but syscall 468 is still
  reserved/nosys in the official stable/15 candidate.
- The active nested releng tree defines syscall 468 as `twq_kernreturn`.
- THRWORKQ source/libthr workqueue support appears incomplete in the official
  stable/15 candidate.

Required next source-side fix:

- Restore THRWORKQ syscall 468 and workqueue/libthr support in the official
  stable/15 candidate before another D14 acceptance attempt.
- Do not broaden stable/15 validation until D14 passes again.
- After syscall 468 no longer stops the run, classify the WITNESS lock-order
  result separately.

## 6. Failure Policy

If D14 fails on the candidate source root, stop and classify the failure before
continuing.

Allowed classifications:

- `candidate_base_regression`: official stable/15 candidate source/base changed
  behavior or broke the D14 path.
- `env_objdir_issue`: selected objdir prefix, `MAKEOBJDIRPREFIX`,
  `NXPLATFORM_FREEBSD_SRC`, kernel path, module path, or guest image path is
  wrong.
- `harness_issue`: oracle runner or transitional shell path cannot operate
  against the new base without a harness change.

Failure handling rules:

- Do not mutate `oracle-parity-a30ef3f` to fix a post-update failure.
- Do not mutate `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` to fix a
  candidate failure.
- Do not delete source tests.
- Do not create certification claims.
- Do not classify a macOS mismatch or oracle comparison as an rx certification
  failure; no claims ledger exists yet.
- Do not make D17/D18 part of the diagnosis unless parent explicitly approves
  widening scope.
- Preserve raw evidence under ignored `priv/runs/`.
- Commit only curated docs or source/base changes that parent accepts.

If the failure is an env/objdir issue, fix configuration and rerun D14. If the
failure is a harness issue, produce a separate harness-fix request. If the
failure is a candidate-base regression, hand the evidence to parent for an
implementation decision before further base adoption.

## 7. Hard Stops

- No stable/15 update without explicit parent acceptance of this plan.
- No source deletion.
- No `certification/` creation.
- No certification claims.
- No raw artifacts committed.
- No D17/D18 migration mixed into the base update.
- No mutation of `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` during the
  first candidate validation pass.
- No repo-root `freebsd-src-stable-15` fallback.
- No oracle-root `freebsd-src-stable-15` fallback.
- No unpinned objdir prefix.
- No silent fallback to releng151, releng151-rc1, or `/usr/obj`.
- No oracle test harness change in the same base-update commit unless separately
  justified and approved.
- No parity tag movement or rewrite.

## Acceptance Criteria For Starting The Update

Parent may authorize the update only after this plan is accepted and the
operator can state:

- accepted oracle SHA
- current active releng/15.1 source SHA
- current and intended official stable/15 candidate source SHA/ref
- intended stable/15 target ref
- intended base profile name: `official-stable15-candidate`
- intended launchd objdir prefix:
  `/Users/me/wip-mach/build/official-stable15-mach-obj`
- whether the latest D14 evidence is accepted as pre-update baseline or must be
  rerun
- expected rebuild commands and artifact locations
