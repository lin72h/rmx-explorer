# Agent Collaboration Rules

## Direct Source-Agent Fixes

- The source agent has explicit permission to edit this Oracle worktree directly
  when the fix is obvious, host-only, and the back-and-forth request loop would
  add avoidable latency.
- Allowed direct fixes include typo/pin corrections, validator/tooling bugs,
  formatting failures, missing host-only checks, and documentation that records
  already-known state.
- This exception does not authorize guest runs, evidence curation, marker
  authority, certification/artifact promotion, parity-tag movement, or any
  change that expands or judges a runtime claim.
- Any direct fix must be reported to both the user and Oracle with the exact
  changed files, reason, validation commands, and commit hash when committed.

## Testing Discipline

- New test logic, validators, negative-control generators, and evidence checkers
  should be written in Elixir or Zig.
- Shell may orchestrate existing build systems and guest invocation, but it must
  delegate substantive evidence validation to Elixir or Zig.
- Host preflight must exercise the same build, command-generation, staging,
  timeout, stdin, and rc-capture paths that a guest activation will use.
