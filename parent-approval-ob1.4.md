# Oracle Instruction: Start OB1.4

Parent has accepted Batch 1A and approved OB1.4.

Before implementation, add this parent approval to the repo:

- `parent-approval-ob1.4.md`

Then implement:

- `macos-validation/probes/m1/header_copy_send_accounting.c`

Use same-process send/receive unless that proves insufficient.

## Required Observations

Record:

- sender send urefs before `mach_msg(SEND)`
- exact `msgh_bits`
- exact `mach_msg(SEND)` return
- sender send urefs immediately after successful `mach_msg(SEND)`
- port type immediately after successful `mach_msg(SEND)`
- exact `mach_msg(RECEIVE)` return
- sender send urefs after `mach_msg(RECEIVE)`
- port type after `mach_msg(RECEIVE)`
- received header fields
- cleanup-to-baseline

The key distinction is:

```text
before send
after SEND return
after RECEIVE return
```

Do not collapse these into one "after" measurement.

## Stop Condition

If `MACH_MSG_TYPE_COPY_SEND` changes sender send urefs on native macOS, stop
immediately.

Do not continue to OB1.5 or descriptor probes.

If `mx-x64z` and `mx-a64z` disagree, stop and report before proceeding.

## Runner Commit Protocol

Run and commit separately per runner:

1. First native runner produces implementation, raw JSON, and summary.
2. Second native runner pulls that implementation, runs it, and commits its raw
   JSON and summary.
3. Cross-runner comparison is updated only after both raw results exist.

## Parent Local Next Step

Parent local lane should only pull and process OB1.4 commits after the runners
publish them.

