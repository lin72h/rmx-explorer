STATUS: Draft / Awaiting Review
GATES: M2 authority implementation is blocked until this document is accepted.

# M2 Authority-Layer Design

Date: 2026-06-04

Oracle repo: `/Users/me/wip-mach/wip-gpt-oracle`

Accepted M1 scaffold commit: `389e6eb`

Source parity reference: `/Users/me/wip-mach/wip-gpt` at `a30ef3f`

Producing host: `bdw-fx15-x64z`

## Scope

M2 designs the oracle authority layer that will organize feature inventory,
rx-vs-mx behavior deltas, and future UI JSON view models.

M2 design does not implement runtime behavior. It does not create the authority
directories yet.

M2 authority remains entirely inside Oracle. Oracle has read-only access to
`/Users/me/wip-mach/wip-gpt`, validates only committed source pins, and reports
the smallest falsifiable source requirement when product/runtime, build,
staging, source-test, or source-documentation behavior is missing. Oracle
catalog, mismatch, probe, fixture, validator, and evidence assets must never
substitute for rmxOS product implementation. See
[`source-oracle-responsibility-boundary.md`](source-oracle-responsibility-boundary.md).

M2 must not:

- run guest gates
- update stable/15
- mutate `/Users/me/wip-mach/wip-gpt`
- create `certification/`, `catalog/`, `mismatches/`, or `artifacts/`
- add Phoenix, routes, controllers, LiveView, assets, or UI runtime files
- import Python or shell as canonical backend logic
- make UI snapshot state authoritative evidence
- create certification claims

## Authority Split

The oracle repo has three planned authority areas, but M2 only designs the first
two:

| authority | M2 status | responsibility |
| --- | --- | --- |
| `catalog/` | design only | feature collection, exploration, availability, probe/source references |
| `mismatches/` | design only | meaningful rx-vs-mx behavior deltas and lifecycle tracking |
| `certification/claims/` | deferred | accepted rx regression claims and hard-stop ledger |

The key rule is separation:

- catalog records what exists or is being explored
- mismatches records meaningful differences
- certification claims record accepted rx regression gates

No record moves automatically between these authorities.

## Canonical IDs

All new M2 schemas use canonical platform and surface IDs:

| ID | meaning |
| --- | --- |
| `rx-x64` | rmxOS on x86-64 / amd64 |
| `rx-a64` | rmxOS on arm64 |
| `mx-x64` | macOS on Intel x86-64 |
| `mx-a64` | macOS on Apple Silicon arm64 |
| `nx-r64` | shared NextStep-style behavior across rx/mx and x64/a64 evidence lanes |

Historical runner IDs such as `mx-a64z`, `mx-x64z`, and `nx-v64z` remain valid
only as provenance references to existing artifacts.

## Proposed Directory Layout

These directories are proposed for a later implementation step. This document
does not create them.

```text
catalog/
  README.md
  features/
    mach/
    launchd/
    dispatch/
    libthr/
    xpc/
  probes/
    mach/
    launchd/
    dispatch/
    libthr/
    macos/

mismatches/
  README.md
  active/
  deferred/
  resolved/

priv/runs/ui-snapshots/      # generated, gitignored UI cache if chosen later
tmp/oracle-ui/               # alternative generated UI cache if chosen later
```

`certification/` remains absent until the R0 claims-ledger contract is accepted.

## Catalog Authority

`catalog/` is the feature collection and exploration authority.

It tracks:

- features that exist in rx, mx, or the shared nx surface
- platform-specific availability
- source references
- probe references
- observed status
- notes and open questions

It does not:

- certify behavior
- create rx regression claims
- block certification
- imply implementation priority
- promote a candidate port into active implementation work

### Catalog Feature Schema

Proposed file naming:

```text
catalog/features/<domain>/<feature_id>.json
```

Example:

```json
{
  "schema": "rmxos_oracle.catalog.feature.v1",
  "feature_id": "mach.ipc.descriptor.copy_send",
  "domain": "mach",
  "title": "Mach descriptor COPY_SEND transfer",
  "surface": "nx-r64",
  "status": "observed",
  "platforms": {
    "rx-x64": {
      "availability": "implemented",
      "evidence_refs": [],
      "source_refs": [
        {
          "repo": "wip-gpt",
          "sha": "a30ef3f",
          "path": "freebsd-src-stable-15/sys/compat/mach"
        }
      ],
      "notes": []
    },
    "rx-a64": {
      "availability": "unknown",
      "evidence_refs": [],
      "source_refs": [],
      "notes": []
    },
    "mx-x64": {
      "availability": "observed",
      "evidence_refs": [
        "mx-x64z/ob2.1-descriptor-copy-send-result-mx-x64z.md"
      ],
      "source_refs": [],
      "notes": [
        "historical runner ID preserved as artifact provenance"
      ]
    },
    "mx-a64": {
      "availability": "observed",
      "evidence_refs": [
        "mx-a64z/ob2.1-descriptor-copy-send-result-mx-a64z.md"
      ],
      "source_refs": [],
      "notes": [
        "historical runner ID preserved as artifact provenance"
      ]
    }
  },
  "probe_refs": [
    "macos-validation/probes/m2/descriptor_copy_send.c"
  ],
  "finding_refs": [
    "findings/nx-v64z/ob2-core-descriptor-transfer-spec.md"
  ],
  "mismatch_refs": [],
  "certification_claim_refs": [],
  "notes": [
    "Catalog entry is inventory only; it is not a certification claim."
  ],
  "updated_at": "2026-06-04"
}
```

### Catalog Field Rules

Required fields:

- `schema`
- `feature_id`
- `domain`
- `title`
- `surface`
- `status`
- `platforms`
- `probe_refs`
- `finding_refs`
- `mismatch_refs`
- `certification_claim_refs`
- `notes`
- `updated_at`

Allowed `status` values:

- `unknown`
- `exploring`
- `observed`
- `implemented`
- `blocked`
- `deferred`
- `retired`

Feature `status` and per-platform `availability` are deliberately separate:

- `status` is the overall catalog state for the feature record.
- per-platform `availability` describes what is known for each concrete
  platform or surface.
- `status` is not automatically derived from platform availability.
- `implemented` is inventory language only. It means source exists and/or
  behavior has been observed. It is not a certification claim.

Allowed platform `availability` values:

- `unknown`
- `not_applicable`
- `not_observed`
- `observed`
- `implemented`
- `missing`
- `partial`
- `blocked`

`certification_claim_refs` remains an empty array until the future claims ledger
exists. A catalog entry may reference future claims, but it must not create them.

`finding_refs` must be repo-relative paths from the oracle repo root. This is
required because both `findings/` and `macos-validation/findings/` may exist and
must not be confused.

### Catalog Probe Schema

Proposed file naming:

```text
catalog/probes/<domain>/<probe_id>.json
```

Example:

```json
{
  "schema": "rmxos_oracle.catalog.probe.v1",
  "probe_id": "macos.m2.descriptor_copy_send",
  "domain": "mach",
  "language": "c",
  "role": "macos_oracle_probe",
  "source_path": "macos-validation/probes/m2/descriptor_copy_send.c",
  "platforms": ["mx-a64", "mx-x64"],
  "runner_artifact_ids": ["mx-a64z", "mx-x64z"],
  "feature_refs": ["mach.ipc.descriptor.copy_send"],
  "result_refs": [
    "macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m2_descriptor_copy_send.json",
    "macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m2_descriptor_copy_send.json"
  ],
  "notes": []
}
```

Probe catalog records describe the probe and its evidence references. They do
not make a probe canonical certification evidence by themselves.

`role` replaces any canonical-flavored probe status vocabulary. The word
`canonical` is reserved for the accepted Elixir/Zig oracle framework assets and
must not be used to imply that a C macOS oracle probe is a certification probe.

Allowed probe `role` values:

- `macos_oracle_probe`
- `rx_guest_probe`
- `rx_host_probe`
- `host_semantic_probe`
- `reference_probe`
- `compatibility_shim`

## Mismatch Authority

`mismatches/` is the rx-vs-mx behavior delta authority.

It records only meaningful deltas:

- missing feature
- behavior mismatch
- intentional design choice
- cannot observe on macOS
- intrusive kernel work required
- candidate port
- regression

It does not:

- record every feature
- replace the catalog
- block certification directly
- create certification claims
- automatically become implementation work

### Mismatch Lifecycle

Proposed lifecycle directories:

```text
mismatches/active/
mismatches/deferred/
mismatches/resolved/
```

Lifecycle meanings:

| lifecycle | meaning |
| --- | --- |
| `active` | meaningful delta needs triage, implementation decision, or evidence |
| `deferred` | meaningful delta exists but is intentionally not active work |
| `resolved` | delta was fixed, accepted as design choice, or proven not to be a delta |

State transition rules:

- `lifecycle` field must match the containing directory.
- `history` is append-only.
- Every lifecycle transition must append a history event containing `at`,
  `event`, `from`, `to`, `reason`, and optional `parent_decision_ref`.
- `active -> deferred` requires a reason and parent decision reference.
- `active -> resolved` requires evidence or parent decision reference.
- `deferred -> active` requires a trigger reason.
- `resolved -> active` is allowed only for regression or new contradictory evidence.
- Moving records between lifecycle dirs must preserve record history.
- `candidate_port` must not auto-promote to implementation work, certification
  claim, or certification block.
- Moving `candidate_port` from `deferred` to `active` requires a parent decision
  reference.
- `unknown` active records require either an explicit review owner/deadline or
  `flags_ledger_review: true`.

### Mismatch Classification

Required classification vocabulary:

| classification | meaning |
| --- | --- |
| `match` | no meaningful delta remains; allowed mainly for resolved closure records |
| `acceptable_difference` | behavior differs but is accepted without implementation work |
| `design_choice` | rx intentionally differs from mx by parent decision |
| `unsupported_feature` | rx does not support the feature |
| `candidate_port` | feature or behavior may be ported later |
| `intrusive_kernel_required` | matching requires intrusive kernel work |
| `cannot_observe` | macOS public APIs cannot expose enough behavior |
| `unknown` | delta exists but is not yet classified |
| `regression` | rx behavior moved away from an accepted baseline over time |

`mismatches/active/` should generally not contain `classification: "match"`
unless it is a short-lived triage record awaiting move to `resolved/`.

### Mismatch Record Schema

Proposed file naming:

```text
mismatches/<lifecycle>/<mismatch_id>.json
```

Example:

```json
{
  "schema": "rmxos_oracle.mismatch.v1",
  "mismatch_id": "mach.ipc.descriptor.dead_name_source",
  "title": "Dead-name descriptor source delivery semantics",
  "domain": "mach",
  "lifecycle": "active",
  "classification": "unknown",
  "comparison_axis": "semantic_behavior",
  "equivalence_class": {
    "id": "mach.ipc.descriptor.dead_name_source.external_contract.v1",
    "normalization_rule_refs": [
      "findings/nx-v64z/ob2-core-descriptor-transfer-spec.md"
    ]
  },
  "probe_spec_refs": [
    "macos-validation/probes/m2/dead_name_descriptor_right.c"
  ],
  "observation_basis": {
    "rx": "L2_guest_integration",
    "mx": "L3_macos_semantic_oracle"
  },
  "platforms": {
    "rx-x64": {
      "behavior": "unknown",
      "evidence_layer": "L2",
      "base_ref": {
        "repo": "wip-gpt",
        "sha": "a30ef3f",
        "base_profile": null,
        "freebsd_src": "/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15"
      },
      "build_validity": "not_observed",
      "evidence_refs": [],
      "notes": []
    },
    "mx-a64": {
      "behavior": "mach_msg succeeds, message is delivered, dead-name entry is consumed",
      "evidence_layer": "L3",
      "base_ref": {
        "platform": "mx-a64",
        "macos_version": "26.5",
        "darwin_version": "25.5.0",
        "runner_artifact_id": "mx-a64z"
      },
      "build_validity": "native_macos_runner_validated",
      "evidence_refs": [
        "mx-a64z/ob2.4-negative-descriptor-result-mx-a64z.md"
      ],
      "notes": [
        "historical runner ID preserved as provenance"
      ]
    },
    "mx-x64": {
      "behavior": "mach_msg succeeds, message is delivered, dead-name entry is consumed",
      "evidence_layer": "L3",
      "base_ref": {
        "platform": "mx-x64",
        "macos_version": "26.4",
        "darwin_version": "25.4.0",
        "runner_artifact_id": "mx-x64z"
      },
      "build_validity": "native_macos_runner_validated",
      "evidence_refs": [
        "mx-x64z/ob2.4-negative-descriptor-result-mx-x64z.md"
      ],
      "notes": [
        "historical runner ID preserved as provenance"
      ]
    }
  },
  "feature_refs": [
    "mach.ipc.descriptor.dead_name_source"
  ],
  "finding_refs": [
    "findings/nx-v64z/ob2-core-descriptor-transfer-spec.md"
  ],
  "source_refs": [],
  "probe_refs": [
    "macos-validation/probes/m2/dead_name_descriptor_right.c"
  ],
  "rx_base_commit": "a30ef3f",
  "macos_build_validity": {
    "mx-a64": "native_macos_runner_validated",
    "mx-x64": "native_macos_runner_validated"
  },
  "probe_source_hashes": [
    {
      "path": "macos-validation/probes/m2/dead_name_descriptor_right.c",
      "sha256": "<sha256>"
    }
  ],
  "evidence_hashes": [
    {
      "path": "mx-a64z/ob2.4-negative-descriptor-result-mx-a64z.md",
      "sha256": "<sha256>"
    },
    {
      "path": "mx-x64z/ob2.4-negative-descriptor-result-mx-x64z.md",
      "sha256": "<sha256>"
    }
  ],
  "review": {
    "owner": null,
    "deadline": null
  },
  "flags_ledger_review": true,
  "certification_claim_refs": [],
  "parent_decision_refs": [],
  "history": [
    {
      "at": "2026-06-04",
      "event": "created",
      "from": null,
      "to": "active",
      "reason": "Initial mismatch record proposed from OB2.4 surprise behavior.",
      "parent_decision_ref": null,
      "note": "Initial mismatch record proposed from OB2.4 surprise behavior."
    }
  ],
  "notes": [
    "Mismatch record does not block certification directly and does not create a claim."
  ]
}
```

### Mismatch Field Rules

Required fields:

- `schema`
- `mismatch_id`
- `title`
- `domain`
- `lifecycle`
- `classification`
- `comparison_axis`
- `equivalence_class`
- `probe_spec_refs`
- `observation_basis`
- `platforms`
- `feature_refs`
- `finding_refs`
- `source_refs`
- `probe_refs`
- `rx_base_commit`
- `macos_build_validity`
- `probe_source_hashes`
- `evidence_hashes`
- `review`
- `flags_ledger_review`
- `certification_claim_refs`
- `parent_decision_refs`
- `history`
- `notes`

Rules:

- `comparison_axis` describes what is being compared, such as
  `semantic_behavior`, `api_return_surface`, `cleanup_semantics`,
  `availability`, or `layout_same_arch`.
- `equivalence_class` records the normalization policy or accepted-contract
  reference that makes the comparison meaningful.
- `probe_spec_refs` point to the probe or probe plan that defines the observed
  behavior.
- `observation_basis` must distinguish rx L2 guest evidence from mx L3 macOS
  oracle evidence when both are present.
- `platforms.<platform>.base_ref` is required when evidence exists for that
  platform.
- `macos_build_validity` is required when mx evidence is referenced.
- `rx_base_commit` or an equivalent rx platform base reference is required when
  rx evidence is referenced.
- `probe_source_hashes` must include hashes for probe sources when probe refs
  are present and hashable.
- `evidence_hashes` must include hashes for evidence/source artifacts when
  evidence refs are present and hashable.
- `flags_ledger_review` may be `true` when a human should decide whether a
  future claims-ledger change is needed.
- `flags_ledger_review` is a review flag only. It does not block certification.
- `certification_claim_refs` remains empty until the R0 claims ledger exists.
- A mismatch may reference a certification claim later, but never creates one.
- A mismatch classified as `regression` still requires certification machinery
  to decide whether a certification run fails.

## Certification Claims Deferred

`certification/claims/` remains deferred.

M2 may describe future linkage, but must not create:

- `certification/`
- `certification/claims/`
- `certification/tiers.yml`
- claim JSON/YAML files
- run evidence under `certification/runs/`

Certification claims are blocked until the R0 claims-ledger contract is
accepted.

Future linkage rules:

- catalog entries may include `certification_claim_refs`
- mismatch entries may include `certification_claim_refs`
- claims may reference catalog and mismatch records once claims exist
- no back-reference creates a claim automatically
- no mismatch classification directly blocks certification
- no macOS-only mismatch directly fails rx certification

## UI JSON View-Model Boundary

Future UI work uses JSON snapshots as an interchange format. M2 designs the
boundary only; it does not add Phoenix or UI runtime files.

If `docs/oracle-ui-design.md` exists or is later accepted as the UI authority,
that document owns the final UI envelope, rendering model, Phoenix dependency
boundary, and route/page design. M2 must not fork or supersede that UI design.

Snapshot output path options:

```text
priv/runs/ui-snapshots/
tmp/oracle-ui/
```

The chosen path must be gitignored when implemented.

UI snapshots are generated outputs. They are not evidence.

If a snapshot and an evidence artifact disagree, the evidence artifact wins.
Authoritative artifacts include raw serial logs, raw probe JSON, findings
documents, accepted manifest JSON, dependency-edge JSON, and parent approval
documents.

### Snapshot Boundary

Every UI JSON object should include, at minimum:

- schema
- generated timestamp
- repo provenance
- dirty status
- source references
- data payload

M2 does not define the final envelope shape. Phoenix/UI design owns that final
contract.

### Proposed UI View Models

M2-compatible view models:

| snapshot | M2 data source | availability |
| --- | --- | --- |
| `overview.json` | aggregate repo, M0/M1/M2 docs, manifest, dependency edges | partial |
| `migration.json` | M0/M1 docs, manifest JSON, dependency edges | available |
| `catalog.json` | future `catalog/` records | design only until catalog exists |
| `mismatches.json` | future `mismatches/` records | design only until mismatches exist |
| `canonicalization.json` | M0 manifest classifications | available |
| `platforms.json` | env validator model plus historical evidence refs | partial |
| `oracle_batches.json` | macOS result summaries/findings | needs parser/audit |
| `findings.json` | `findings/` and root approval docs | needs parser/audit |
| `evidence_ladder.json` | M1 evidence model | available as schema/model only |

### UI Snapshot Hard Rules

- snapshots must include repo SHA and dirty status
- snapshots must include `source_refs`
- stale snapshot age must be visible in any future UI
- dirty repo status must be visible in any future UI
- snapshots must not be committed as evidence
- snapshots must not be used as certification inputs
- snapshot generation must not mutate evidence
- snapshot generation must not run guest gates or probes by default
- M2 must not implement UI export

## M2 Implementation Model

If this design is accepted, a later M2 implementation may create only owned,
non-empty authority scaffolding:

- `catalog/README.md`
- `mismatches/README.md`
- schema examples or schemas under a chosen non-runtime location

M2 implementation still must not create certification claims.

Recommended first implementation order after design acceptance:

1. Add catalog and mismatch README files explaining authority boundaries.
2. Add schema examples or schema validation modules if approved.
3. Add zero or one seed catalog record only if parent approves concrete content.
4. Add zero mismatch records unless parent approves a specific delta.
5. Defer UI snapshot generator until the UI design track is accepted.

## Hard Stops

- no M2 implementation until this design is accepted
- no creation of `catalog/`, `mismatches/`, `certification/`, or `artifacts/`
  while drafting this document
- no certification claims until the R0 claims-ledger contract is accepted
- no mismatch accepted without `observation_basis` and `comparison_axis`
- no lifecycle transition without an appended history event
- no automatic `candidate_port` promotion
- no canonical-flavored vocabulary for catalog probe role or status fields
- no mismatch record may directly block certification
- no mismatch record may automatically create a certification claim
- no catalog record may automatically create a certification claim
- no macOS mismatch may directly fail rx certification
- no UI snapshot may become authoritative evidence
- no UI snapshot may be treated as evidence
- no Phoenix dependency or UI runtime file in this M2 design step
- no guest gates
- no stable/15 update
- no source repo mutation
- no shell/Python canonical backend logic
- no generated/transient runtime artifacts committed

## Acceptance Criteria

M2 authority design is accepted only when:

- `catalog/` authority purpose and non-goals are clear
- `mismatches/` authority purpose and non-goals are clear
- canonical platform IDs are used
- historical runner IDs are limited to provenance
- catalog feature schema is accepted
- catalog probe schema is accepted
- mismatch schema is accepted
- mismatch comparison provenance fields are accepted
- mismatch lifecycle rules are accepted
- mismatch classifications include the required vocabulary
- `flags_ledger_review` is defined as review-only
- certification claims remain deferred
- future claim linkage is described without creating claims
- UI JSON snapshot boundary is defined as generated non-evidence output
- hard stops are accepted
- no forbidden directories or runtime files were created
- oracle worktree changes are docs-only

## Current Layout Conflicts

No blocking conflicts found with the current oracle repo layout.

Observed current state:

- `catalog/` does not exist
- `mismatches/` does not exist
- `certification/` does not exist
- `artifacts/` does not exist
- `findings/` already exists and remains the historical findings authority
- `macos-validation/` already exists and remains the macOS oracle probe/result area
- `mx-a64z/` and `mx-x64z/` already exist and remain historical runner artifact dirs
- `priv/runs/` is gitignored by M1, so it can hold future generated UI snapshots
  without becoming evidence

The only naming risk is conceptual: `findings/` contains historical accepted
oracle findings, while future `mismatches/` would contain actionable delta
records. M2 implementation must keep this split explicit and avoid moving
historical findings during authority scaffolding.

## Open Questions

1. Should catalog and mismatch records be JSON only, or should each JSON record
   have a paired Markdown summary for human review?
2. Should schema validation live in Elixir modules under `RmxOSOracle.Catalog`
   and `RmxOSOracle.Mismatch`, or remain file-schema-only until records exist?
3. Should the first M2 implementation seed records for accepted OB2 descriptor
   contracts, or should it start with README/schema-only scaffolding?
4. Should UI snapshot generation wait for the separate Phoenix/UI design to be
   accepted, or can a non-Phoenix JSON export task be designed first?
