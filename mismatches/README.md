# Mismatch Authority

`mismatches/` is the rx-vs-mx behavior delta authority.

Accepted design:

- `docs/migration-m2-authority-design.md`

This authority records meaningful deltas only. It is not a feature inventory,
not a certification ledger, and not an implementation queue.

## Scope

Mismatch records may track:

- missing features
- behavior mismatches
- intentional design choices
- cannot-observe cases
- intrusive-kernel-required cases
- candidate ports
- regressions

Mismatch records must not:

- directly block certification
- automatically create certification claims
- automatically become implementation work
- make macOS-only mismatches fail rx certification
- treat UI snapshots as evidence

`flags_ledger_review: true` means human review is requested for a future claims
ledger decision. It does not block certification by itself.

## Lifecycle

Future lifecycle directories are:

- `mismatches/active/`
- `mismatches/deferred/`
- `mismatches/resolved/`

They are not created by this README/schema-only M2 scaffold.

Rules:

- `lifecycle` field must match the containing directory.
- `history` is append-only by policy.
- Every lifecycle transition must append a history event with `at`, `event`,
  `from`, `to`, `reason`, and optional `parent_decision_ref`.
- `candidate_port` must not auto-promote to implementation work, certification
  claim, or certification block.
- Moving `candidate_port` from `deferred` to `active` requires a parent decision
  reference.
- `unknown` active records require either an explicit review owner/deadline or
  `flags_ledger_review: true`.

## Classifications

Allowed classifications:

- `match`
- `acceptable_difference`
- `design_choice`
- `unsupported_feature`
- `candidate_port`
- `intrusive_kernel_required`
- `cannot_observe`
- `unknown`
- `regression`

## Schema

Initial schema file:

- `priv/schemas/mismatch_v1.schema.json`

Mismatch records must capture how the comparison was made, including
comparison axis, equivalence class, probe spec references, observation basis,
platform base references, build validity, and source/evidence hashes where
hashable.

## Future Records

No mismatch records are seeded in this M2 scaffold. Future records need
parent-approved content.
