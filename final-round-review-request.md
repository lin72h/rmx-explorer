# Final Round Review Request: nx-v64z Oracle Stage 1-2

Date: 2026-05-12

## Request

Please perform the final review before implementation begins.

Primary file:

```text
/Users/me/wip-mach/wip-gpt-oracle/final-preimplementation-plan.md
```

Supporting files:

```text
/Users/me/wip-mach/wip-gpt-oracle/comprehensive-nx-v64z-macos-oracle-plan.md
/Users/me/wip-mach/wip-gpt-oracle/implementation-readiness-summary.md
/Users/me/wip-mach/wip-gpt-oracle/post-final-parent-gpt-resolution.md
/Users/me/wip-mach/wip-gpt-oracle/test-migration-map.md
/Users/me/wip-mach/wip-gpt-oracle/parent-agent-questions.md
/Users/me/wip-mach/wip-gpt-oracle/second-round-review-opus.md
```

Parent docs:

```text
/Users/me/wip-mach/wip-gpt/docs/macos-oracle-validation-agent-handoff.md
/Users/me/wip-mach/wip-gpt/docs/macos-semantic-validation-strategy.md
/Users/me/wip-mach/wip-gpt/docs/terminology.md
/Users/me/wip-mach/wip-gpt/docs/ROADMAP-0.5.md
/Users/me/wip-mach/wip-gpt/docs/test-plan.md
/Users/me/wip-mach/wip-gpt/docs/m1-completion-and-m2-directive.md
```

## Review Goal

Give a final go/no-go for implementing Stage 1-2:

- Stage 1: repository skeleton and shell/Make harness
- Stage 2: common C helpers and schema-emitting smoke path

Do not re-review the entire long-range oracle program unless it reveals a
Stage 1-2 blocker.

## Settled Inputs

- Stage 1-2 can begin according to OPUS review.
- The earlier `COPY_SEND` uref concern is resolved by NextBSD batch 21.
- macOS oracle should verify native macOS matches the confirmed NextBSD
  baseline.
- OPUS should continue the M2.1 batch 22 rerun independently.
- Zig is not required for Stages 1-5; C-only JSON still includes null/false Zig
  fields.
- `python3` is the required Stage 1-2 JSON validator.
- Build outputs live under `macos-validation/.build/`; source directories must
  not contain compiled or signed binaries.
- macOS results use `<date>-<macos-version>-<darwin-version>`; non-macOS
  development hosts use `<date>-<os-name>-<kernel-version>`.
- Signing status is recorded per binary as `{path, status, return_code, output}`
  once helpers exist.
- The schema has no separate architecture class. Intel versus Apple Silicon
  differences use `version_sensitive` with architecture notes.
- Raw Mach port integers are never comparison keys; symbolic labels are used.

## Please Check

1. Is `final-preimplementation-plan.md` concrete enough for an implementation
   agent to create Stage 1-2 files without asking more questions?

2. Are the proposed Make targets and harness contracts sufficient?

3. Are any required files missing from the Stage 1-2 layout?

4. Is the schema floor sufficient for the common helpers, especially:
   - `cross_reference`
   - `message.remote_port`
   - `message.local_port`
   - `message.header_rights`
   - typed `returns`
   - typed `right_deltas`
   - `entry_refs_before`
   - `entry_refs_after`
   - null/false Zig fields

5. Should `cross_reference` be required with nullable fields, as planned?

6. Should helper signing status be in environment only, or do Stage 1-2 helpers
   need per-helper result details immediately?

7. Does the Stage 1-2 plan keep macOS default execution free of bhyve, donor
   checkout, private entitlements, SIP changes, and Zig dependency?

8. Are any remaining parent questions actually blockers for Stage 1-2?

9. Is the coordination recommendation correct: OPUS continues batch 22 rerun
   while this repo starts Stage 1-2?

10. Is anything in the final plan inconsistent with the parent handoff or test
    methodology lock?

## Expected Output

Use this format:

```text
Findings

1. [severity: blocker|major|minor|info] file:line
   Problem.
   Why it matters.
   Recommended change.

Open Questions

1. Question that must be answered before Stage 1-2, if any.

Go/No-Go

One of:
- go for Stage 1-2
- go after minor doc edits
- no-go; blocker remains

Implementation Notes

1. Concrete note for the implementation agent.
```

## Constraints

- Do not implement code in this review.
- Do not suggest XNU import, private entitlements, SIP-disabled behavior, or
  broad inherited FreeBSD test transfer.
- Do not suggest rewriting donor C tests into Elixir or Zig.
- Focus on final readiness for Stage 1-2.
