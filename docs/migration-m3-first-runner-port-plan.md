STATUS: Draft / Awaiting Review
GATES: M3 implementation is blocked until this document is accepted.

# M3 First Runner Port Plan

Date: 2026-06-04

Oracle repo baseline: `34511d7`

Source parity repo baseline: `/Users/me/wip-mach/wip-gpt` at `a30ef3f`

Source parity tag: `oracle-parity-a30ef3f`

No `certification/claims/` ledger exists. Stable/15 update remains paused.

## Scope

M3 defines the first real migration slice and the parity method before porting
more tests from `wip-gpt` into the oracle repo.

This document is design only. It does not implement migrated tests, create
runtime artifacts, run guest gates, update stable/15, or delete source files.

## M3 Purpose

M3 proves a repeatable migration method for one narrow host-only slice before
attempting broader runner migration.

The core questions are:

- What exactly counts as a migrated slice?
- What legacy reference is immutable?
- How is parity recorded?
- What is the positive path?
- What is the negative control?
- What evidence ladder layer is being claimed?
- When, if ever, can source working-tree files be deleted?

## First Migration Slice

Decision: first slice is strictly `Phase08.SourceTransform`.

Included oracle files:

- `lib/phase08/source_transform.ex`
- `test/phase08/source_transform_test.exs`

Legacy reference files:

- `scripts/launchd/phase08_source_transform.exs`
- `test/phase08_source_transform_test.exs`

Excluded from first migrated status:

- `lib/phase08/marker_manifest.ex`

Reason:

- `lib/phase08/source_transform.ex` has focused ExUnit coverage.
- `lib/phase08/marker_manifest.ex` is imported but does not yet have dedicated
  parity coverage.
- Calling `marker_manifest` migrated now would overclaim.

Marker manifest is the next small host-only slice, but it needs its own parity
harness before it can be marked migrated.

## Legacy Parity Reference

The immutable legacy reference is:

```text
oracle-parity-a30ef3f
```

This tag points at source commit:

```text
a30ef3f
```

Rules:

- The tag and commit must never be rewritten.
- The tag and commit must never be deleted.
- Future source working-tree cleanup means deleting or moving files from the
  mutable source checkout only.
- Source cleanup never deletes the immutable parity tag/commit.
- M3 must compare against the tag/commit, not against drifting source working
  tree bytes.

## Evidence Ladder Classification

First slice:

| slice | layer | meaning |
| --- | --- | --- |
| `phase08.source_transform` | `L1_host_semantic_probe` | host semantic/source-transform validation |

The first slice makes no:

- L2 guest integration claim
- launchd behavior claim
- platform certification claim
- R0 claims-ledger claim

Later guest migration should start only after the first L1 host-only migration
pattern is accepted.

Recommended later guest order:

1. D14
2. D17
3. D18 after D14 and D17

D14 must include a negative control, such as malformed plist rejection or a
missing required marker.

## Parity Record Schema

M3 should introduce migration parity records in a later implementation step.
This document only defines the proposed shape.

Suggested future location:

```text
priv/migration/parity/
  phase08_source_transform_v1.json
```

This path is documented only for now. Do not add a migration ledger schema file
or parity record file during M3 implementation unless the first parity task
needs it.

Raw parity evidence should be generated under a gitignored run output path
first, such as:

```text
priv/runs/migration-parity/<timestamp>-phase08-source-transform/
```

Only curated parity records may be committed after review. Raw transient command
output is not committed by default.

Proposed schema:

```json
{
  "schema": "rmxos_oracle.migration.parity_record.v1",
  "slice_id": "phase08.source_transform",
  "status": "parity_passed",
  "comparison_axis": "legacy_vs_oracle",
  "observation_basis": "L1_host_semantic_probe",
  "equivalence_class": {
    "id": "phase08.source_transform.semantic_equivalence.v1",
    "normalization_rule_refs": [
      "docs/migration-m3-first-runner-port-plan.md"
    ]
  },
  "legacy": {
    "repo": "/Users/me/wip-mach/wip-gpt",
    "tag": "oracle-parity-a30ef3f",
    "commit": "a30ef3f",
    "file_hashes": [
      {
        "path": "scripts/launchd/phase08_source_transform.exs",
        "sha256": "<sha256>"
      },
      {
        "path": "test/phase08_source_transform_test.exs",
        "sha256": "<sha256>"
      }
    ]
  },
  "oracle": {
    "repo": "/Users/me/wip-mach/wip-gpt-oracle",
    "commit": "<oracle_commit>",
    "replacement_hashes": [
      {
        "path": "lib/phase08/source_transform.ex",
        "sha256": "<sha256>"
      },
      {
        "path": "test/phase08/source_transform_test.exs",
        "sha256": "<sha256>"
      }
    ]
  },
  "input_fixture_hashes": [],
  "evidence_hashes": [
    {
      "path": "<parity evidence path>",
      "sha256": "<sha256>"
    }
  ],
  "negative_control": {
    "description": "Intentional transform expectation violation fails.",
    "evidence_hashes": [
      {
        "path": "<negative-control evidence path>",
        "sha256": "<sha256>"
      }
    ]
  },
  "result": "parity_passed",
  "notes": [
    "ExUnit green alone is not migrated evidence; negative control evidence is required."
  ]
}
```

Allowed `result` values:

- `parity_passed`
- `parity_failed`
- `blocked`

Required parity fields:

- `comparison_axis: "legacy_vs_oracle"`
- `observation_basis`
- `equivalence_class`
- legacy tag and commit
- oracle commit
- legacy file paths and SHA256 hashes
- oracle replacement paths and SHA256 hashes
- input fixture hashes when fixtures are used
- evidence hashes
- negative-control evidence
- `result`

## First-Slice Parity Command Plan

M3 implementation should add explicit Mix tasks only after this design is
accepted. The command plan below is proposed behavior, not implemented behavior.

### Positive Path

Goal: prove the oracle source-transform implementation preserves the accepted
legacy semantics for the slice.

Proposed command:

```sh
mix oracle.migration.parity phase08.source_transform \
  --legacy-repo /Users/me/wip-mach/wip-gpt \
  --legacy-ref oracle-parity-a30ef3f \
  --oracle-repo /Users/me/wip-mach/wip-gpt-oracle
```

Proposed positive checks:

1. Resolve `oracle-parity-a30ef3f` to `a30ef3f`.
2. Hash legacy files from the tag:
   - `scripts/launchd/phase08_source_transform.exs`
   - `test/phase08_source_transform_test.exs`
3. Hash oracle replacement files:
   - `lib/phase08/source_transform.ex`
   - `test/phase08/source_transform_test.exs`
4. Run oracle focused test:

   ```sh
   mix test test/phase08/source_transform_test.exs
   ```

5. Run legacy behavior from the immutable ref only when needed, using a
   temporary checkout or `git show` materialization from
   `oracle-parity-a30ef3f`. This must not mutate the source repo working tree.
6. For the first `source_transform` slice, it is acceptable to compare file
   hashes plus oracle behavior if running legacy ExUnit materially complicates
   implementation. Record that limitation in the parity record.
7. Emit parity evidence under a gitignored run output path with command outputs,
   hashes, toolchain identity, and repo SHAs.

The focused ExUnit pass is harness evidence only. The migrated status requires
the negative control below as paired evidence.

### Negative Control

A slice cannot be marked migrated unless it has a demonstrated red path.

For `phase08.source_transform`, prefer a direct transform API negative control
over generating an ExUnit temporary file. This avoids filesystem/test-discovery
noise and proves the transform logic can go red directly.

Preferred negative controls:

- call `Phase08.SourceTransform.apply_transforms/2` directly with an invalid
  transform or known-bad source
- remove required context from the direct transform input
- alter an anchor so the transform finds zero or two matches
- intentionally assert the wrong generated output from a direct transform call

Generating a temporary ExUnit file is allowed only as a fallback if direct API
negative control cannot cover the intended red path.

Proposed command:

```sh
mix oracle.migration.parity phase08.source_transform \
  --legacy-repo /Users/me/wip-mach/wip-gpt \
  --legacy-ref oracle-parity-a30ef3f \
  --negative-control intentional_expected_output_violation
```

Required properties:

- The preferred negative control uses direct API calls or in-memory
  materialization.
- It does not edit tracked oracle files.
- It does not edit source repo files.
- It proves a red path by making the transform logic fail for the intended
  reason.
- The failure output is captured and hashed as evidence.

Do not accept:

- ExUnit green only
- no-op negative controls
- tests that always print PASS
- negative controls that rely on deleting source files
- negative controls that mutate the immutable tag/commit

## Marker Manifest Follow-Up Slice

`Phase08.MarkerManifest` is imported but not migrated.

To mark it migrated later, M3 or M3b must define and implement a dedicated
parity harness that covers:

- marker inventory stability
- ID/key uniqueness
- `emit_c/3` and `emit_c/4`
- static value policy validation
- C string literal escaping
- expected failure on unknown marker ID
- expected failure on invalid value expression
- negative control proving red path

Until then:

- `lib/phase08/marker_manifest.ex` remains imported support.
- It must not be marked migrated.
- It must not be used as evidence that marker manifest migration is complete.

## Later Guest Migration Order

Guest migration must wait until the L1 host-only migration pattern is accepted.

Recommended order:

1. D14
2. D17
3. D18

D14 requirements:

- L2 guest integration evidence
- guest boot identity evidence before accepting claim markers
- serial log evidence
- positive marker evidence
- hard-stop denylist scan
- negative control, such as malformed plist rejection or missing required marker
- no certification pass language until R0 claims ledger exists

## Migration Ledger

M3 should use mark-first, delete-later.

Suggested future ledger path:

```text
priv/migration/migration_ledger.json
```

This ledger shape remains documented only for M3 design acceptance. Do not add a
ledger schema file or ledger JSON file in M3 implementation unless the first
parity task needs it.

Proposed shape:

```json
{
  "schema": "rmxos_oracle.migration.ledger.v1",
  "source_parity_ref": {
    "repo": "/Users/me/wip-mach/wip-gpt",
    "tag": "oracle-parity-a30ef3f",
    "commit": "a30ef3f"
  },
  "oracle_repo": {
    "path": "/Users/me/wip-mach/wip-gpt-oracle",
    "commit": "<oracle_commit>"
  },
  "slices": [
    {
      "slice_id": "phase08.source_transform",
      "layer": "L1_host_semantic_probe",
      "migration_status": "migrated",
      "parity_record_ref": "priv/migration/parity/phase08_source_transform_v1.json",
      "deletion_status": "not_deleted",
      "source_paths": [
        "scripts/launchd/phase08_source_transform.exs",
        "test/phase08_source_transform_test.exs"
      ],
      "oracle_paths": [
        "lib/phase08/source_transform.ex",
        "test/phase08/source_transform_test.exs"
      ],
      "parent_decision_refs": [],
      "notes": []
    }
  ]
}
```

Allowed `migration_status` values:

- `not_started`
- `in_progress`
- `migrated`
- `blocked`

Allowed `deletion_status` values:

- `not_deleted`
- `approved_for_batch_delete`
- `deleted_from_working_tree`

The ledger is migration bookkeeping only. It is not a certification claims
ledger.

## Deletion Policy

Use mark-first, delete-later:

1. After slice parity passes, mark the slice migrated in the migration ledger.
2. Do not delete source working-tree files immediately.
3. Batch deletion only after the migration method is proven on the first few
   slices or at a natural checkpoint.
4. Every deletion requires parent approval.
5. Never delete or rewrite `oracle-parity-a30ef3f`.
6. Never delete or rewrite commit `a30ef3f`.

Deletion means mutable working-tree cleanup in `/Users/me/wip-mach/wip-gpt`.
Deletion never affects immutable Git history or the parity tag.

## Hard Stops

- no M3 implementation until this design is accepted
- no broad `scripts/` copy
- no shell/Python canonical runner
- no source deletion during M3
- no stable/15 update
- no certification pass language until R0 claims ledger exists
- no guest-gate migration before first L1 host-only migration pattern is accepted
- no migrated status without positive evidence and negative control
- no marker manifest migrated status without its own parity harness
- no mutation of `oracle-parity-a30ef3f`
- no mutation or deletion of commit `a30ef3f`
- no immutable-reference comparison against dirty source working-tree bytes
- no generated/transient evidence committed unless parent approves a durable
  fixture artifact
- no raw transient command output committed by default
- no legacy code execution from the mutable source working tree

## Acceptance Criteria

M3 design is accepted only when:

- first migration slice is clearly scoped to `phase08.source_transform`
- marker manifest is explicitly excluded until its own parity harness exists
- immutable legacy parity reference is `oracle-parity-a30ef3f`
- parity record schema is accepted
- parity record reuses M2 comparison/provenance vocabulary
- positive path command plan is accepted
- negative control plan is accepted
- evidence ladder classification is accepted as L1 host semantic only
- later guest order D14, D17, D18 is accepted
- deletion policy is mark-first, delete-later
- hard stops are accepted
- open questions are resolved in this document
- oracle worktree changes are docs-only

## Resolved Questions

1. Migration ledger schema:
   Do not add a migration ledger schema file in M3 implementation unless the
   first parity task needs it. For M3 design acceptance, the ledger shape remains
   documented only.
2. Parity evidence storage:
   Generate parity evidence under a gitignored run output path first. Only
   curated parity records may be committed after review. Do not commit raw
   transient command output by default.
3. Negative control mechanism:
   Prefer direct transform API negative control over generating an ExUnit
   temporary file.
4. Legacy execution:
   Use a temporary checkout or `git show` materialization from
   `oracle-parity-a30ef3f` for legacy parity when needed. Do not run legacy code
   from the mutable source working tree. For the first `source_transform` slice,
   comparing file hashes plus oracle behavior is acceptable if running legacy
   ExUnit materially complicates implementation, but that limitation must be
   recorded in the parity record.
