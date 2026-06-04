STATUS: Draft / Awaiting Parent Approval
GATES: Activation is blocked until this plan is accepted. This document does not execute activation.

# Stable/15 Candidate Adoption Plan f71260cf4c9e

This plan defines how the accepted stable/15 candidate becomes the future default oracle base profile. It is plan-only: no env defaults are changed, no guests are run, no source paths are renamed, and no evidence is deleted or rewritten.

## Candidate To Adopt

Future profile:

- `stable15-active`

Profile target:

- source: `/Users/me/wip-mach/freebsd-src-official-stable-15`
- commit: `f71260cf4c9e`
- objdir: `/Users/me/wip-mach/build/official-stable15-mach-obj`
- kernel conf: `MACHDEBUGDEBUG`

Activation policy:

- Future default profile changes from `releng151-current` to `stable15-active`.
- `releng151-current` remains an accepted explicit fallback.
- `official-stable15-candidate` remains an accepted alias for the same source path, commit, and objdir as `stable15-active`.
- The unpinned canonical releng profile is not repointed to the candidate.
- Source paths are not renamed during activation.

Future activation must wire `stable15-active` through every env assertion that protects source and objdir provenance:

- `source_profile` allowlist
- `require_profile_freebsd_src`
- `expected_freebsd_src_commit`
- `require_profile_objdirprefix`

`stable15-active` and `official-stable15-candidate` must derive from the same shared source, commit, and objdir constants. The alias must not duplicate literals that can drift from `stable15-active`. If the alias is no longer needed by existing `env.local` files or scripts, it may be removed only in a separate compatibility review, not during activation.

## Accepted Evidence

Accepted candidate evidence is preserved under ignored `priv/runs/` paths.

| Gate | Result | Evidence path | Notes |
| --- | --- | --- | --- |
| S3 staging | pass | `priv/runs/stable15-base-update/20260604T120142Z-s3-official-stable15-minor-rebase-stage/` | Candidate kernel/module/image staging evidence. |
| D14 | pass | `priv/runs/migration-parity/20260604T120612.655593Z-phase08-d14-launchctl-plist/` | L2 guest evidence for inert plist load. Boot identity records guest image hash `44f001b4834123033e27180225744895d4586e120bc482df04b94588d766383d`. |
| D17 | pass | `priv/runs/stable15-base-update/20260604T123146Z-d17-official-stable15-fast-exit-stdin-null-timeout180/` | Accepted stdin-isolated run. Candidate remained `f71260cf4c9e` between failed and passed D17 attempts. |
| D18 | pass | `priv/runs/stable15-base-update/20260604T123428Z-d18-official-stable15-signal-exit-stdin-null-timeout180/` | Accepted stdin-isolated run. |

D17/D18 note: `run-guest.rc=1` is non-authoritative only under marker-pass plus clean hard-stop conditions. The accepted D17/D18 runs also require `validate-only` success, required markers, clean hard-stop scan, and harness end `rc=0`.

## Accepted Artifact Tuple

The accepted candidate tuple is valid only for candidate source commit `f71260cf4c9e`.

| Artifact | SHA256 | Size | Path |
| --- | --- | ---: | --- |
| kernel | `39031adb1267455043f6b04f4e073dbb975e8aa91d80a7808fd9b92a2ec63fb5` | `31404792` | `/Users/me/wip-mach/build/official-stable15-mach-obj/Users/me/wip-mach/freebsd-src-official-stable-15/amd64.amd64/sys/MACHDEBUGDEBUG/kernel` |
| kernel.full | `845982055bd8be6989ec63e84ba0c23e5ab851212a919a73c1e1dcc9830584c8` | `133231776` | `/Users/me/wip-mach/build/official-stable15-mach-obj/Users/me/wip-mach/freebsd-src-official-stable-15/amd64.amd64/sys/MACHDEBUGDEBUG/kernel.full` |
| mach.ko | `f9c871ce59742dcda7d8fabb7e211177f84af5c9083cfa1e70023de1d80e625e` | `345360` | `/Users/me/wip-mach/build/official-stable15-mach-obj/Users/me/wip-mach/freebsd-src-official-stable-15/amd64.amd64/sys/modules/mach/mach.ko` |
| S3 post-stage guest image | `d427e61c526469e4e6712bdf0313e1f997cbc9c7999b71b615262d2e9578ed3e` | `6476638720` | `/Users/me/wip-mach/vm/runs/nxplatform-dev.img` |

Changing any single artifact invalidates this accepted tuple.

Guest image hash semantics:

- The `d427e61c...` guest image hash is the S3 post-stage image hash from `s3-stage-result.json`.
- The accepted D14 boot identity records `/Users/me/wip-mach/vm/runs/nxplatform-dev.img` with hash `44f001b4834123033e27180225744895d4586e120bc482df04b94588d766383d`.
- These are distinct lifecycle points for a mutable live VM image path. The S3 post-stage hash must not be treated as the universal booted image hash for D14/D17/D18.
- Future activation checks must preserve both meanings: S3 verifies staged bytes, while each guest evidence record verifies the image hash observed for that run.

## Durable Provenance

- Oracle provenance commit: `71b60fef4093 stable15: record minor rebase candidate provenance`
- Source policy/docs repo: `/Users/me/wip-mach/wip-gpt`
- Source policy/docs commit: `f89bcadde4d1 docs: require stdin isolation for minor rebase gates`
- Candidate source branch: `rmx/official-stable15-mach`
- Candidate source commit: `f71260cf4c9e`
- Oracle parity tag remains: `oracle-parity-a30ef3f -> a30ef3f`

The source policy/docs commit `f89bcadde4d1` is not an Oracle repo commit. It records the stdin isolation policy for minor rebase gates.

## Rollback Source And Tuple

Rollback source:

- path: `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- commit: `d4876c3fd9af`
- objdir: `/Users/me/wip-mach/build/releng151-mach-obj`
- profile: `releng151-current`

Rollback tuple source evidence:

- `priv/runs/migration-parity/20260604T090700.280459Z-phase08-d14-launchctl-plist/boot_identity.json`
- `priv/runs/migration-parity/20260604T090700.280459Z-phase08-d14-launchctl-plist/env_resolved.json`

Verified rollback tuple from existing evidence:

| Artifact | SHA256 | Size | Path |
| --- | --- | ---: | --- |
| kernel | `c6f0d3eb12498504243c60694969790893e397fcfb367e10f39ddf12d4a680eb` | `31398456` | `/Users/me/wip-mach/build/releng151-mach-obj/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/amd64.amd64/sys/MACHDEBUGDEBUG/kernel` |
| mach.ko | `e529ff107eaa49fa780aabd9487fc04dd20069ccec72a48cb939d88ab626d0c8` | `345360` | `/Users/me/wip-mach/build/releng151-mach-obj/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/amd64.amd64/sys/modules/mach/mach.ko` |
| guest image | `1d8245bb7f4e1bfca0462dd2e4f489d89ec992aaa58fedbce4f4f36920a16f72` | `6476638720` | `/Users/me/wip-mach/vm/runs/nxplatform-dev.img` |

Rollback evidence limitation:

- `kernel.full` is not recorded in the existing rollback D14 boot identity evidence.
- This plan does not compute or add a replacement `kernel.full` rollback hash because the requested rollback tuple must be sourced from existing evidence before writing the plan.
- Rollback guest image bytes are not retained as an archived immutable image in this plan. The path `/Users/me/wip-mach/vm/runs/nxplatform-dev.img` is a single live image path and may have been overwritten by later staging.
- Rollback must therefore restage or rebuild the guest image from frozen nested source `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` before D14 rollback validation, unless an archived copy is separately found and verified by content hash.
- Rollback must not reuse `/Users/me/wip-mach/vm/runs/nxplatform-dev.img` as the old rollback image unless its current hash is explicitly verified to match `1d8245bb7f4e1bfca0462dd2e4f489d89ec992aaa58fedbce4f4f36920a16f72`.

## Future Activation Commit

Actual activation is a separate future commit after parent approval. The activation commit is limited to env/default profile policy.

Required activation changes:

- Add `stable15-active` profile.
- Make `stable15-active` the default when `NXPLATFORM_BASE_PROFILE` is unset.
- Keep `releng151-current` as an explicit fallback profile.
- Keep `official-stable15-candidate` as an alias for the same candidate source path, commit, and objdir.
- Keep the candidate source path `/Users/me/wip-mach/freebsd-src-official-stable-15`.
- Keep the candidate objdir `/Users/me/wip-mach/build/official-stable15-mach-obj`.
- Validate `oracle.env.check` with no `NXPLATFORM_BASE_PROFILE` set.

When `NXPLATFORM_BASE_PROFILE` is unset after activation, env resolution must produce:

- `accepted_source_profile=stable15-active`
- `source_pin_id=stable15-active`
- `freebsd_src=/Users/me/wip-mach/freebsd-src-official-stable-15`
- `freebsd_src_commit=f71260cf4c9e`
- `expected_freebsd_src_commit=f71260cf4c9e`
- `kernel_objdirprefix=/Users/me/wip-mach/build/official-stable15-mach-obj`

The activation commit must align `env.local` and lane defaults so `oracle.env.check --lane launchd` with no `NXPLATFORM_BASE_PROFILE` fails closed if any selected launchd lane value still points to:

- `/Users/me/wip-mach/build/releng151-mach-obj`
- `/Users/me/wip-mach/build/releng151-rc1-mach-obj`
- `/usr/obj`

The same no-silent-releng rule applies to other lane prefixes when they are selected for a stable15-active run.

Activation must not:

- Repoint the unpinned canonical releng profile to the candidate.
- Rename or move source paths.
- Mutate either source tree.
- Rebuild artifacts unless parent explicitly expands scope.

## Rollback Procedure

Rollback is only executed if the future activation is applied and then needs to be reverted.

Allowed rollback paths:

- Set `NXPLATFORM_BASE_PROFILE=releng151-current`, or
- Revert the future activation commit.

Rollback rules:

- Keep frozen nested tree `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` untouched.
- Keep `oracle-parity-a30ef3f` untouched.
- Rerun minimal D14 only if rollback is actually executed.
- Do not delete candidate evidence or rollback evidence.
- Do not create certification claims from rollback execution.

## Guardrails

- No source mutation.
- No source deletion.
- No certification claim.
- No `certification/`.
- No repo-local `artifacts/`.
- No `oracle-parity-a30ef3f` movement.
- No path rename.
- No guest reruns for this plan doc.
- No evidence deletion or mutation.
- No activation before parent approval.

## Non-Goals

- This plan does not activate stable/15.
- This plan does not change env defaults.
- This plan does not run S3, D14, D17, or D18.
- This plan does not create certification claims or seed catalog/mismatch records.
- This plan does not authorize stable/16 work.
