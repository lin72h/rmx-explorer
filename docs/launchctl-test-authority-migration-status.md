STATUS: Current launchctl test-authority migration checkpoint

# Launchctl Test Authority Migration Status

This tracker records the post-D20/D21 Oracle authority checkpoint for Phase 0.8 launchctl tests. It is a routing document for future ASL, D24+, and launchctl work: it names what is Oracle-owned, what remains deferred, and what must be checked before new launchctl consumers are authored.

## Current Closed State

Source durable policy:

- Source repo commit: `b8ef1bc`
- Policy document: `docs/test-migration-hardening-plan.md`

Oracle authority commits:

- `56f631077bca` `phase08: port D19 launchctl verifier authority`
- `39d56b34e6cc` `phase08: add D19 launchctl marker manifest`
- `59a36a24d1f6` `phase08: add D20 D21 launchctl verifier authority`

D19-D21 launchctl authority is now Oracle-owned and cross-checked:

- Helper-to-manifest binding tests cover the owned D19-D21 contracts.
- No-copy/static checks reject copied D19/D20 order literals outside the Oracle helper owner.
- Preserved serial positive fixtures cover accepted D19, D20, and D21 evidence.
- Falsifiers cover missing markers, wrong values, invalid order, duplicate-rescue attempts, and truncated serials.
- Generator anchor drift guards bind D19-D21 marker literals to checked-in frozen source-text anchors.
- Source-side launchctl verifier/helper files are `transitional_reference` only, not live Oracle runtime authority.

## Ordering Decision

Option B remains active: the Oracle helper owns ordering.

No manifest `must_precede` or `must_follow` implementation exists yet. Do not add ordering primitives by default.

Revisit the ordering model only when one of these is true:

- Ordering becomes non-flat or conditional.
- A new consumer cannot import the Oracle helper.
- Full D22/D23 migration requires manifest-owned ordering.

## D22/D23 State

D22/D23 are audited, but not fully migrated.

Current state:

- D22/D23 manifest entries exist.
- D22 inherited D19/D20 order participation is consistent with the current helper audit.
- D23 remains not applicable for direct inherited D19/D20 order in this checkpoint.
- D22/D23 producer values are constrained to `:donor` or `:harness`.

Deferred:

- D22/D23 `producer_detail` and `role` normalization.
- Arm-isolated D22/D23 positive fixtures.
- Arm-contamination falsifiers.
- Source-side wrapper/deletion decision.

No current `must_fix` finding blocks ASL or other non-launchctl work.

Source-side verifier deletion or wrapper retirement remains deferred until full D22/D23 parity is proven and parent explicitly authorizes deletion.

## Trigger Conditions

D22/D23 full migration is required before authoring any new launchctl gate that:

- consumes D22/D23 markers or ordering,
- inherits D19/D20 ordering through D22, or
- adds a multi-arm launchctl pattern.

D22/D23 full migration is not required for ASL or other non-launchctl work.

Before any new launchctl consumer is authored, require:

- helper-to-manifest cross-check green,
- no-copy/static contract check green,
- `mix oracle.stable15.env_matrix` green,
- this tracker reviewed for deferred launchctl ownership gaps.

## Guest Policy

No guest run is required for this tracker.

Guest runs are warranted only when a runtime claim changes, including:

- new launchctl gate,
- kernel, donor, or probe behavior change,
- plist fixture change,
- preserved serial suspected invalid.

Host-only authority and documentation updates must not be treated as runtime evidence.

## Guardrails

- Docs-only tracker.
- No guest runs.
- No source-side edits or deletion.
- No `certification/`.
- No `artifacts/`.
- No `oracle-parity-a30ef3f` movement.
- No certification claim.
