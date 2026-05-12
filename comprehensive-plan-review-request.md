# Review Request: nx-v64z macOS Oracle Plan

Date: 2026-05-12

## Request

Please review the macOS oracle plan in this local repository and identify
technical gaps, contradictions, bad assumptions, missing gates, and ordering
problems before implementation starts.

Primary file to review:

```text
/Users/me/wip-mach/wip-gpt-oracle/comprehensive-nx-v64z-macos-oracle-plan.md
```

Supporting files:

```text
/Users/me/wip-mach/wip-gpt-oracle/rx-macos-oracle-plan-and-parent-questions.md
/Users/me/wip-mach/wip-gpt-oracle/elixir-test-migration-plan.md
/Users/me/wip-mach/wip-gpt-oracle/nextbsd-test-inventory-and-oracle-transfer-plan.md
/Users/me/wip-mach/wip-gpt-oracle/parent-agent-questions.md
```

Parent planning repo for context:

```text
/Users/me/wip-mach/wip-gpt/docs/macos-oracle-validation-agent-handoff.md
/Users/me/wip-mach/wip-gpt/docs/macos-semantic-validation-strategy.md
/Users/me/wip-mach/wip-gpt/docs/terminology.md
/Users/me/wip-mach/wip-gpt/docs/ROADMAP-0.5.md
/Users/me/wip-mach/wip-gpt/docs/test-plan.md
/Users/me/wip-mach/wip-gpt/docs/nextbsd-mach-tests.md
/Users/me/wip-mach/wip-gpt/docs/m1-completion-and-m2-directive.md
```

The reviewer must read files in both `wip-gpt-oracle` and `wip-gpt`. Both are
local filesystem paths accessible from the same host.

Donor test roots for context:

```text
/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

## Context

The goal is to create a cloneable macOS oracle package in:

```text
/Users/me/wip-mach/wip-gpt-oracle
```

The package will be run on:

- `mx-x64z`: native Intel macOS
- `mx-a64z`: native Apple Silicon macOS

The shared package/schema owner is:

- `nx-v64z`

`rx` / rmxOS is the local development lane and comparison consumer. It is not
the oracle source/schema lane.

Native macOS is a semantic oracle only. It must not become an implementation
source and must not require private entitlements, SIP changes, kernel debugging,
or XNU code import.

## Decisions Already Made

- First implementation is shell/Make plus native C probes.
- Existing donor tests stay native C/Make.
- Elixir is for orchestration, manifests, fixtures, result classification, and
  reports.
- Elixir comparison comes after both macOS result sets and the rxOS/NextBSD
  result set exist.
- Zig is only for new narrow ABI/descriptor probes when source sharing or exact
  binary layout control requires it.
- Queued sender/receiver-exit descriptor tests are first follow-ups, not
  blockers before basic `COPY_SEND` and `MOVE_SEND`.
- Commit curated summary JSON and findings notes.
- Keep raw logs outside git unless a raw fixture is specifically useful.
- Rosetta results are allowed only as non-primary supplemental artifacts.
- Primary `mx-a64z` must be native arm64/arm64e.
- The result schema has no separate architecture class. Intel versus Apple
  Silicon disagreement uses `version_sensitive` with explicit architecture
  notes.

## Settled Decisions To Validate

The following choices are already made by the parent planning flow. Please
validate that the plan follows them correctly; do not reopen them unless the
plan contradicts a higher-priority parent document.

- Header `MACH_MSG_TYPE_COPY_SEND` accounting is an M2 preflight before body
  descriptor `COPY_SEND`.
- Sender/receiver-exit queued descriptor probes are first follow-ups after core
  `COPY_SEND` / `MOVE_SEND` and negative M2 probes.
- macOS default validation is stock userland only: no private entitlements, SIP
  changes, or kernel debugging.
- Existing donor tests stay native C/Make.
- Broad inherited FreeBSD tests are inventory-only for this oracle package.

## Review Goals

Please assess whether the comprehensive plan is strong enough to start
implementation.

Focus on:

1. lane terminology correctness: `nx-v64z`, `mx-*`, `rx`, NextBSD
2. compatibility with the parent docs and Phase 0.5 roadmap
3. correctness of the first probe list
4. whether the M1/M2 probes answer the implementation-critical questions
5. whether the JSON schema is sufficient and stable
6. whether environment capture is complete
7. whether build/sign/run instructions are realistic for stock macOS
8. whether process-probe safety rules are strong enough
9. whether donor test transfer is scoped correctly
10. whether Elixir migration is staged at the right time
11. whether stop/skip classifications are precise enough
12. whether raw result/artifact policy is sane
13. whether any dependency on modern macOS behavior risks overfitting
14. whether the order of implementation stages should change

## Specific Questions

1. Is `mach_port_names()` plus `mach_port_get_refs()` plus `mach_port_type()`
   sufficient as the foundational introspection floor, or should another
   stock-userland API be validated before M1/M2 probes?

2. Does the plan correctly implement the settled decision that header
   `MACH_MSG_TYPE_COPY_SEND` accounting is an M2 preflight before descriptor
   `COPY_SEND`?

3. Does the plan's placement of `send_once_descriptor.c` after clean
   `COPY_SEND` / `MOVE_SEND` results satisfy M2.3, or should it be promoted
   into the core transfer probes?

4. Does the plan correctly implement the settled decision that sender-exit and
   receiver-exit queued descriptor probes are first follow-ups after the core
   M2 and negative probes?

5. Should bootstrap special-port validation require a read-only fallback probe
   if stock macOS blocks `task_set_special_port()`?

6. Should uref-sensitive tests be downgraded per host or globally if
   `mach_port_get_refs()` is unreliable on one macOS architecture?

7. Is the `nx-v64z.macos-oracle.v1` schema missing fields needed for later
   mechanical comparison against rxOS/NextBSD results, especially around
   `header_rights`, typed `returns`, typed `right_deltas`, and
   `cross_reference`?

8. Does the optional early `ipc-hello` stock-SDK compile check after
   foundational probes strike the right balance, or should more donor compile
   checks happen before M1/M2 custom probes?

9. Should `ipc-hello` runtime be attempted before core descriptor probes, or is
   compile-only the right early donor signal?

10. Should parser scripts be copied into the oracle repo for cloneability, or
    imported from the parent planning repo to avoid duplicate ownership?

11. Should `classify-donor.sh` and `nextbsd-history.sh` become oracle tools, or
    remain parent-only tools?

12. What Elixir/Erlang version floor should be used across `rx`, `mx-x64z`, and
    `mx-a64z`?

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
- ready to implement after minor edits
- needs parent decisions before implementation
- not ready; plan has blocking gaps
```

If you see no major issues, say that explicitly and list residual risks.

## Constraints For Reviewer

- Do not implement code as part of this review.
- Do not rewrite the plan wholesale unless there is a blocking structural issue.
- Do not suggest importing XNU or Apple implementation source.
- Do not suggest private entitlements or SIP-disabled behavior as the default
  oracle path.
- Do not suggest rewriting existing donor C tests into Elixir or Zig.
- Keep broad FreeBSD inherited tests out of the macOS oracle default lane.

## High-Risk Areas To Pressure-Test

- `COPY_SEND` sender uref accounting
- descriptor `MOVE_SEND` consumption timing
- invalid descriptor disposition cleanup
- dead/nonexistent descriptor right cleanup
- stock macOS bootstrap special-port observability
- process cleanup for fork/spawn/exec and queued-message exit cases
- schema stability before results are collected on real macOS hosts
- modern macOS 14/15 behavior versus donor-era 10.10-10.11 Darwin
- Intel versus Apple Silicon result synthesis
- Elixir/Erlang toolchain mismatch on `rx`

## Desired Outcome

The ideal review gives enough confidence to start Stage 1 implementation of the
oracle repo skeleton and foundational probes, or it identifies the exact parent
decisions needed before implementation begins.
