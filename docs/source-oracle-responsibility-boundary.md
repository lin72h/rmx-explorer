# Implementer And Oracle Responsibility Boundary

Status: normative Oracle architecture and governance policy.

Source policy authority:

- repository: `/Users/me/wip-mach/wip-gpt`
- commit: `6ace1e51f76bf32156f7d39e57b4c41b404fc8c9`
- source documents:
  - `docs/role-governance.md`
  - `docs/source-oracle-responsibility-boundary.md`
  - `AGENTS.md`

This Oracle policy adopts the source-side role governance and responsibility
boundary. Canonical role names and escalation rules are defined by source
`docs/role-governance.md` at the commit above. If an Oracle document or task
conflicts with this boundary, this boundary and the source role-governance
authority win and the conflicting work stops for review.

## Core Boundary

The rmxOS source repository is owned by the Implementer.

Oracle has read-only access to `/Users/me/wip-mach/wip-gpt`. Oracle must never create, modify, delete, move, stage, or commit files in the rmxOS source repository.

All rmxOS source-repository writes are performed by the Implementer, including:

- kernel, runtime, userland, library, daemon, and command implementation;
- build-system, source-transform, harness-link, guest-staging, and integration
  changes;
- source-side probes, fixtures, scripts, tests, and documentation;
- donor import, extraction, adaptation, and source-side provenance records;
- source-side authorization and architecture decisions.

This remains true when Oracle identifies the required change, supplies a
reproducer, or proposes an exact patch. Oracle reports the requirement; the
Implementer reviews and implements it.

Oracle may validate only committed source pins. Uncommitted source bytes must
not be used as accepted runtime, parity, or gate evidence.

## Oracle Ownership

Oracle owns testing, feature exploration, and gate authority inside the Oracle
repository. Oracle Explorer mode owns read-only exploration and host readiness.
Oracle Gatekeeper mode owns guest attempts, evidence dispositions, marker
authority, preserved evidence, and closeouts.

Oracle may create and modify, inside the Oracle repository:

- gate designs and dependency classifications;
- host-side test probes, fixtures, validation modules, and falsifiers;
- marker manifests, ordering contracts, producer attribution, and no-copy
  checks;
- guest-run orchestration and evidence collection;
- preserved evidence, revalidation logic, disposition records, and closeout
  records;
- source-readiness checks that fail closed when rmxOS implementation or staging
  support is missing.

Oracle may read rmxOS and donor source, build committed rmxOS source, run
committed source-side tools, and report precise source blockers. These actions
do not grant Oracle authority to modify the rmxOS repository.

Oracle test probes, fixtures, stubs, and validators must never substitute for
rmxOS product implementation. This sentence uses `validators` as a mechanism
term for validation modules and evidence checkers, not as the Validator role.
Harness behavior may prove orchestration, but it must not satisfy a
product/runtime claim.

## Escalation Rule

When Oracle finds missing or incorrect product/runtime behavior:

1. Oracle stops before modifying rmxOS source.
2. Oracle preserves evidence.
3. Report the smallest falsifiable source requirement.
4. The Implementer makes and commits the rmxOS change.
5. Oracle updates its explicit source pin and validates the committed change.

An Oracle authorization to test, build, stage, or run a committed source pin
does not authorize source-repository writes.

## Repository Write And Access Policy

| Role | rmxOS source repository | Oracle repository | Evidence authority |
| --- | --- | --- | --- |
| Maestro | parent-access exception authority; doctrine and scope decisions | parent-access exception authority | may require supersession, not silent rewrite |
| Conductor | no standing write authority | no standing write authority | none |
| Implementer | read/write; sole product implementation authority | narrow host-only direct-fix exception when recorded | none |
| Oracle Explorer | read-only | read/write for host review and readiness work | no guest attempts or dispositions |
| Oracle Gatekeeper | read-only | read/write for guest evidence, marker authority, and closeouts | sole pass/fail disposition authority |
| Validator | no write authority | no write authority | none |
| Arbiter | no write authority | no write authority | cannot alter dispositions in either direction |

An explicit task authorization may permit Oracle to run a source-side command
or consume a committed source artifact. It does not permit Oracle to write to
the rmxOS source repository. Any exception to this boundary requires a separate
architecture decision that names the exact paths, duration, and reason.

Donor and reference repositories are read-only for all roles unless a separate
explicit decision authorizes maintenance.

Parent-access exceptions are governed by source `docs/role-governance.md`'s
one-way-door access rule. The one-way-window is read-only visibility; tree
position grants no repository writes by itself. Writable direct access requires
a recorded one-way-door exception.

The Implementer-to-Oracle host-only direct-fix exception in `AGENTS.md` is a
narrow standing one-way-door delegation for tooling, pin, formatting, and
documentation fixes. Pin fixes are limited to making a pin match an
already-committed record, such as typo or path-class corrections. Repointing
any evidence, authority, or authorization pin to a different commit is excluded
and goes through the normal Oracle pin-update flow. The direct-fix exception
also excludes marker manifests, contract checks, falsifiers, and
evidence-validation modules.

## Oracle Modes

Every Oracle output declares `mode: explorer` or `mode: gatekeeper`.

Explorer mode is read-only toward runtime evidence. Explorer outputs use this
vocabulary for gate and evidence-state assertions:

- ready;
- not ready;
- smallest source requirement;
- host readiness;
- suspected layer.

Explorer mode may inspect source, donor, build products, host preflight, and
preserved evidence. Explorer mode never runs a guest, never consumes attempts,
and never issues evidence dispositions.

Gatekeeper mode owns guest attempts, evidence, pass/fail dispositions, marker
authority, preserved evidence, and closeouts. Gatekeeper outputs use this
vocabulary for gate and evidence-state assertions:

- accepted;
- not accepted;
- consumed;
- disposition;
- marker authority;
- closeout.

Only Gatekeeper mode may consume or account guest attempts.

## Static Check

Run:

```text
mix oracle.source.boundary.check
```

The check:

- resolves an explicit source ref to a committed source commit;
- verifies source policy commit `6ace1e51f76bf32156f7d39e57b4c41b404fc8c9`
  remains in the current source history;
- validates required boundary wording in Oracle governance documents;
- emits a read-only source-worktree fingerprint for before/after comparison.

The check does not require a clean source worktree and does not mutate it.
Agents must still compare source state before and after work and report any
unexpected difference.

## Review Guardrails

Every Oracle task must confirm:

- no rmxOS source-repository files were modified, deleted, staged, or
  committed;
- any source blocker is reported rather than repaired in Oracle;
- test scaffolds remain in Oracle and are not represented as rmxOS product
  implementation;
- source commit pins identify the exact rmxOS implementation under test.

Every Implementer task responding to Oracle must confirm:

- the source change is independently reviewed as rmxOS implementation;
- the change does not weaken Oracle pass/fail authority;
- Oracle can validate the committed source change without writing to the source
  repository.
