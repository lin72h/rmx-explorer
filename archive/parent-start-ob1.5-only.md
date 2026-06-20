# Oracle Instruction: Start OB1.5 Only

The larger OB1.5/OB2 compatibility-validation batch is approved in
`parent-approval-ob1.5-ob2.md`, but the only active runner task now is OB1.5:

- `macos-validation/probes/m1/header_move_send_accounting.c`
- test_id: `macos_m1_header_move_send_accounting`

Do not start OB2.1, OB2.2, OB2.3, or OB2.4 yet.

## Runner Startup

Both runners must start with:

```sh
git pull --ff-only
```

Read these files before implementation:

- `parent-start-ob1.5-only.md`
- `parent-approval-ob1.5-ob2.md`
- `findings/nx-v64z/ob1.4-header-copy-send-comparison.md`
- `parent-batch1-directive.md`
- `parent-response-to-opus-oracle-batches.md`
- `macos-runner-agent-handoff.md`

## OB1.5 Question

How does header `MACH_MSG_TYPE_MOVE_SEND` affect the sender's observable send
right?

Measure separately:

```text
before send
after mach_msg(SEND) returns
after mach_msg(RECEIVE) returns
```

## Required Observations

Record:

- exact public API call sequence
- exact return values and raw `kern_return_t` / `mach_msg_return_t` values
- exact `msgh_bits`
- sender send urefs before send
- sender send urefs immediately after successful `mach_msg(SEND)`
- sender send urefs after `mach_msg(RECEIVE)`
- sender port type before send
- sender port type immediately after successful `mach_msg(SEND)`
- sender port type after `mach_msg(RECEIVE)`
- received header fields
- delivered right usability, if a usable right is delivered
- cleanup-to-baseline result
- `entry_refs_before: null` and `entry_refs_after: null` unless directly
  observable through stock public macOS APIs

## Safety Boundary

Use only public Mach APIs available to normal userland programs.

Do not use private entitlements, SIP changes, sandbox escapes, privileged
helper tools, kernel introspection, private Apple headers, or exploit-style
techniques.

If a behavior cannot be observed through stock public APIs, record it as
`not_observable` and stop that case.

## Gate Rules

Do not start OB2 until OB1.5 passes on both `mx-a64z` and `mx-x64z`.

Stop and report if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- a case would require non-stock macOS privileges or private APIs
- the result contradicts prior Batch 1 expectations

## Runner Protocol

Use the same two-runner protocol as OB1.4:

1. `mx-a64z` implements `m1/header_move_send_accounting.c` and commits
   implementation, raw JSON, and summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Only after both runners agree may OB2.1 begin.
