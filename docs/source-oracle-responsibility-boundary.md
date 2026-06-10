# Source And Oracle Responsibility Boundary

Status: normative Oracle architecture and governance policy.

Source policy authority:

- repository: `/Users/me/wip-mach/wip-gpt`
- commit: `e6dfa40c1823adc73b5962e6503a904472a85f52`
- source document: `docs/source-oracle-responsibility-boundary.md`

This Oracle policy adopts the source-side responsibility boundary. If an
Oracle document or task conflicts with this boundary, this boundary wins and
the conflicting work stops for review.

## Repository Boundary

Oracle has read-only access to `/Users/me/wip-mach/wip-gpt`.

Oracle must never create, modify, delete, move, stage, or commit files in the
rmxOS source repository. This remains true when Oracle can identify the exact
source patch or when an Oracle gate is blocked on missing source behavior.

The source implementation agent owns and commits all rmxOS source-repository
changes, including:

- product, kernel, runtime, library, daemon, and command implementation;
- build, link, staging, and integration behavior;
- source-side tests, probes, fixtures, scripts, and documentation;
- donor import or adaptation performed inside the source repository.

Oracle may validate only committed source pins. Uncommitted source bytes must
not be used as accepted runtime, parity, or gate evidence.

## Oracle Ownership

Inside the Oracle repository, Oracle owns:

- testing and feature exploration;
- gate contracts, validators, falsifiers, and marker authority;
- Oracle-owned probes, fixtures, stubs, and test orchestration;
- evidence collection, preservation, revalidation, and disposition;
- source-readiness checks that fail closed on missing source capability.

Oracle test probes, fixtures, stubs, and validators must never substitute for
rmxOS product implementation. Harness behavior can prove harness behavior; it
cannot satisfy a product/runtime claim.

## Source Requirement Escalation

When Oracle finds missing product/runtime, build, staging, source-test, or
source-documentation behavior:

1. Stop before modifying the source repository.
2. Preserve the relevant Oracle evidence.
3. Report the smallest falsifiable source requirement.
4. Wait for the source implementation agent to implement and commit the source
   change.
5. Update the Oracle source pin and validate only the committed source change.

An Oracle authorization to test, build, stage, or run a committed source pin
does not authorize source-repository writes.

## Static Check

Run:

```text
mix oracle.source.boundary.check
```

The check:

- resolves an explicit source ref to a committed source commit;
- verifies source policy commit `e6dfa40c1823adc73b5962e6503a904472a85f52`
  remains in the current source history;
- validates required boundary wording in Oracle governance documents;
- emits a read-only source-worktree fingerprint for before/after comparison.

The check does not require a clean source worktree and does not mutate it.
Agents must still compare source state before and after work and report any
unexpected difference.

## Review Guardrails

Every Oracle implementation or guest-run task must confirm:

- the source repository was not modified, deleted from, staged, or committed;
- every source input was identified by an explicit committed pin;
- missing source capability was reported rather than repaired by Oracle;
- Oracle scaffolds were not represented as rmxOS product implementation;
- no source deletion or parity-tag movement occurred.
