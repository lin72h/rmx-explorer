# Second-Round Review Request: nx-v64z macOS Oracle Plan

Date: 2026-05-12

## Request

Please perform a second-round technical review of the macOS oracle plan after
the first review feedback from GLM and KIMI was incorporated.

Authoritative file to review:

```text
/Users/me/wip-mach/wip-gpt-oracle/comprehensive-nx-v64z-macos-oracle-plan.md
```

Supporting local files:

```text
/Users/me/wip-mach/wip-gpt-oracle/parent-agent-questions.md
/Users/me/wip-mach/wip-gpt-oracle/comprehensive-plan-review-request.md
/Users/me/wip-mach/wip-gpt-oracle/elixir-test-migration-plan.md
/Users/me/wip-mach/wip-gpt-oracle/nextbsd-test-inventory-and-oracle-transfer-plan.md
/Users/me/wip-mach/wip-gpt-oracle/rx-macos-oracle-plan-and-parent-questions.md
```

Parent context files, also available locally:

```text
/Users/me/wip-mach/wip-gpt/docs/macos-oracle-validation-agent-handoff.md
/Users/me/wip-mach/wip-gpt/docs/macos-semantic-validation-strategy.md
/Users/me/wip-mach/wip-gpt/docs/terminology.md
/Users/me/wip-mach/wip-gpt/docs/ROADMAP-0.5.md
/Users/me/wip-mach/wip-gpt/docs/test-plan.md
/Users/me/wip-mach/wip-gpt/docs/nextbsd-mach-tests.md
/Users/me/wip-mach/wip-gpt/docs/m1-completion-and-m2-directive.md
```

Donor roots for context:

```text
/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

The reviewer should read both `wip-gpt-oracle` and `wip-gpt` files. They are
local filesystem paths on the same host.

## Context

The repository `/Users/me/wip-mach/wip-gpt-oracle` is the planned cloneable
macOS oracle package.

Roles:

- `nx-v64z`: shared portable oracle/schema/comparison owner
- `mx-x64z`: native Intel macOS runner
- `mx-a64z`: native Apple Silicon macOS runner
- `rx`: local rmxOS development lane and comparison consumer, not oracle owner

Native macOS is a semantic oracle only. The plan must not require XNU code
import, private entitlements, SIP changes, kernel debugging, or broad inherited
FreeBSD test transfer into the macOS default lane.

## Settled Decisions

Please validate that the plan follows these decisions. Do not reopen them unless
the plan contradicts a higher-priority parent document.

- First implementation is shell/Make plus native C probes.
- Existing donor tests stay native C/Make.
- Elixir is for parser/schema/fixture tests, manifests, comparison, and reports.
- Zig is not required for Stages 1-5. Zig fields remain explicit null/false in
  C-only JSON per parent artifact contract.
- Header `MACH_MSG_TYPE_COPY_SEND` accounting is an M2 preflight.
- Sender/receiver-exit queued descriptor probes are first follow-ups, not
  blockers before core `COPY_SEND` / `MOVE_SEND` and M2.4 negative probes.
- Intel versus Apple Silicon disagreement uses `version_sensitive` with
  explicit architecture notes. There is no separate architecture class.
- Results use `results/<agent>/<date>-<macos-version>-<darwin-version>/`.
- Raw logs stay outside git unless a raw fixture is specifically useful.

## Round-One Feedback Incorporated

### GLM Findings Addressed

- Added `m2/send_once_descriptor.c` for M2.3.
- Added `m2/double_move_send_descriptor.c` for the double `MOVE_SEND` M2.4 gate.
- Added `m2/receiver_copyout_failure.c` with a `not_observable` fallback if
  stock macOS cannot induce receiver copyout failure.
- Aligned result directory layout with the handoff date/version convention.
- Added explicit Apple Silicon environment capture for `hw.optional.arm64` and
  arm64e/pointer-auth sysctls when present.
- Added optional early `ipc-hello` stock-SDK compile-only check after
  foundational probes.
- Added schema evolution rule.
- Updated review prompt severity scale to include `info`.
- Added settled-decisions section to review prompt.

### KIMI Findings Addressed

- Added `foundation/port_type.c`.
- Added `m1/header_move_send_accounting.c`.
- Expanded schema to distinguish header-carried rights from body descriptors:
  `remote_port`, `local_port`, and `header_rights`.
- Typed `returns` as call/returned/raw/errno objects.
- Typed `right_deltas` as operation/port/right/before/after/expected objects.
- Added optional `cross_reference.nextbsd_test_id` and
  `cross_reference.donor_equivalent_id`.
- Added explicit process rendezvous requirement for fork/spawn/exec and queued
  message choreography.
- Clarified bootstrap special-port behavior: read-only get/inheritance first;
  set attempt only under stock capability, recording exact blocked
  `kern_return_t`.
- Clarified Zig is not a Stage 1-5 dependency while keeping explicit Zig JSON
  fields.
- Added helper executable ad-hoc signing requirement.
- Documented `m1/` and `m2/` as roadmap package names, not Apple hardware.
- Defined concrete `mach_port_names()` unusable criteria.

## OPUS Second-Round Feedback Incorporated

- Reframed `COPY_SEND` from suspected bug to confirmed NextBSD baseline that
  macOS should verify.
- Closed artifact path and NextBSD probe-ID questions with the Opus M2 lane
  paths and batch IDs.
- Added optional `entry_refs_before` and `entry_refs_after` to `right_deltas`.
- Replaced literal `"opaque"` examples with symbolic port labels.
- Added a schema supersession note because the parent handoff has an older flat
  message schema example.
- Added rendezvous orthogonality to the process-probe safety rule.
- Added unknown `mach_port_type()` bit guidance.
- Added delivered-right `entry_refs` and cleanup characterization to descriptor
  probe expectations.

## Specific Second-Round Review Questions

1. Does the revised foundational floor, now including `mach_port_type()`, cover
   the introspection needed for all planned M1/M2 probes?

2. Is the expanded JSON schema sufficient for mechanical comparison, especially
   `header_rights`, typed `returns`, typed `right_deltas`, and
   `cross_reference`?

3. Should `cross_reference` be required in v1 with nullable fields as planned,
   or should it be optional until parent IDs exist?

4. Is `send_once_descriptor.c` correctly conditional after clean `COPY_SEND` and
   `MOVE_SEND`, or should send-once descriptor behavior be promoted into the
   core transfer probes?

5. Is the `receiver_copyout_failure.c` plan realistic for stock macOS userland,
   or should it be pre-classified as `not_observable` unless the parent provides
   a known method?

6. Does the plan need a narrower `MACH_MSG_TYPE_MOVE_SEND_ONCE` probe name
   instead of the generic `send_once_descriptor.c`?

7. Is the process rendezvous rule strong enough for sender-exit,
   receiver-exit, spawn, exec, and queued-message cases?

8. Should helper executable signing be recorded per helper in the environment
   object, or in each probe's `api_sequence` / result notes?

9. Is the optional early `ipc-hello` compile-only check at the right point, or
   should `ipc-hello` runtime be attempted earlier too?

10. Are any remaining parent questions blocking Stage 1-2 implementation, or
    only Stage 3+?

11. Is keeping `m1/` and `m2/` directory names acceptable now that the plan
    defines them as roadmap package names, or should implementation still rename
    the directories to avoid hardware-name confusion?

12. Are there missing stop/skip rules for `mach_port_type()`, send-once
    descriptor availability, helper signing, or copyout-failure attempts?

## Expected Review Output

Please report findings first, ordered by severity.

Use this format:

```text
Findings

1. [severity: blocker|major|minor|info] file:line
   Problem.
   Why it matters.
   Recommended change.

Open Questions

1. Question that needs parent decision.

Suggested Plan Changes

1. Concrete edit or reordering recommendation.

Verdict

One of:
- ready to implement Stage 1-2 now
- ready to implement after minor edits
- needs parent decisions before implementation
- not ready; plan has blocking gaps
```

If there are no blockers, explicitly say which stages can begin safely.

## Constraints

- Do not implement code as part of this review.
- Do not suggest XNU import or Apple implementation-source use.
- Do not suggest private entitlements or SIP-disabled behavior as default.
- Do not suggest rewriting existing donor C tests into Elixir or Zig.
- Keep broad inherited FreeBSD tests out of the macOS oracle default lane.

## Desired Outcome

The ideal second-round review tells us whether Stage 1-2 can begin while the
remaining parent questions are resolved, and whether any plan edits are required
before Stage 3 foundational probes or Stage 5 M2 descriptor probes.
