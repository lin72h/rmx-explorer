# Catalog Authority

`catalog/` is the oracle feature collection and exploration authority.

Accepted design:

- `docs/migration-m2-authority-design.md`

This authority records what exists, what has been observed, and what still needs
exploration across canonical platform IDs:

- `rx-x64`
- `rx-a64`
- `mx-x64`
- `mx-a64`
- `nx-r64`

Historical runner IDs such as `mx-a64z` and `mx-x64z` may appear only as
artifact provenance for existing evidence.

## Scope

Catalog records may track:

- feature availability
- source references
- probe references
- findings references
- platform-specific notes
- exploration status

Catalog records must not:

- create certification claims
- block certification
- imply implementation priority
- promote `candidate_port` work
- replace mismatch records
- make UI snapshots or summaries authoritative evidence

## Schemas

Initial schema files:

- `priv/schemas/catalog_feature_v1.schema.json`
- `priv/schemas/catalog_probe_v1.schema.json`

Feature `status` and per-platform `availability` are separate fields. The
overall `status` is inventory language only and is not automatically derived
from platform availability. `implemented` means source exists and/or behavior
has been observed; it is not a certification claim.

Probe records use `role`, not `canonical_status`, to avoid confusing cataloged
reference probes with canonical certification probes.

## Future Records

No feature or probe records are seeded in this M2 scaffold. Future records need
parent-approved content.
