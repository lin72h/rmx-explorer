# OB1.4 header COPY_SEND accounting result - mx-x64z

Runner: `mx-x64z`
Host: Intel macOS, `x86_64`
Result directory: `macos-validation/results/mx-x64z/20260513-26.4-25.4.0`

## Scope

Implemented and ran:

- `macos-validation/probes/m1/header_copy_send_accounting.c`
- test_id: `macos_m1_header_copy_send_accounting`
- batch 21 comparison target:
  `characterize_m2_batch21_copy_send_uref_accounting`

No OB1.5 or later probes were started.

## Commands

```sh
git pull --ff-only
cd macos-validation
make clean all
make run AGENT=mx-x64z
make validate-json
```

## Raw Deliverables

- `macos-validation/results/mx-x64z/20260513-26.4-25.4.0/environment.json`
- `macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m1_header_copy_send_accounting.json`

## Result

Status: `pass`
Semantic class: `exact_contract`

Key observations:

- send header disposition: `MACH_MSG_TYPE_COPY_SEND`
- sent `msgh_bits` raw: `0x13`
- `mach_msg(SEND)` returned: `MACH_MSG_SUCCESS` / raw `0`
- `mach_msg(RECEIVE)` returned: `MACH_MSG_SUCCESS` / raw `0`
- sender send urefs: `1 -> 1 -> 1`
- port type: `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_SEND_RECEIVE`
- received `msgh_bits` raw: `0x1100`
- received remote/local labels: `MACH_PORT_NULL` / `service_port`
- received remote/local dispositions: `0` / `MACH_MSG_TYPE_MOVE_SEND`
- received message size: `24`
- cleanup delta: `0`
- cleanup returned to baseline: `true`

The stop condition did not trigger: `MACH_MSG_TYPE_COPY_SEND` did not change
the sender send urefs after `mach_msg(SEND)` or after receive.

## Batch 21 Comparison

NextBSD batch 21 recorded stable header `COPY_SEND` accounting:
`entry_refs=2->2->2`.

The macOS OB1.4 result matches the source-side stability finding at the
observable user-ref level: sender send urefs stayed `1->1->1`. macOS does not
expose entry refs through these stock APIs, so `entry_refs_before` and
`entry_refs_after` remain `null` in the raw JSON.

Finding: on `mx-x64z`, native macOS confirms the batch 21 conclusion that
header `MACH_MSG_TYPE_COPY_SEND` is non-inflating for the sender.

## Cross-Runner Status

The `mx-a64z` OB1.4 raw JSON now exists in
`macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m1_header_copy_send_accounting.json`.
Cross-runner comparison is recorded in
`mx-x64z/ob1.4-cross-runner-comparison.md`.
