# Oracle Instruction: Mach IPC Compatibility Validation Batch

OB1.4 passed on both native macOS runners. Proceed with the next
compatibility-validation batch, using strict gates and stock public macOS APIs
only.

Both runners must start with:

```sh
git pull --ff-only
```

Read these files before implementation:

- `parent-batch1-directive.md`
- `parent-response-to-opus-oracle-batches.md`
- `macos-runner-agent-handoff.md`
- `findings/nx-v64z/ob1.4-header-copy-send-comparison.md`

## Scope

Validate observable Mach IPC behavior in this order:

1. OB1.5 `m1/header_move_send_accounting.c`
2. OB2.1 `m2/descriptor_copy_send.c`
3. OB2.2 `m2/descriptor_move_send.c`
4. OB2.3 `m2/send_once_descriptor.c`
5. OB2.4 descriptor error-handling cases

## Safety Boundary

Use only public Mach APIs available to normal userland programs.

Do not use:

- private entitlements
- SIP changes
- sandbox escapes
- privileged helper tools
- kernel introspection
- private Apple headers
- exploit-style techniques

If a behavior cannot be observed through stock public APIs, record it as
`not_observable` and stop that case.

## Gate Rules

Do not start OB2 until OB1.5 passes on both `mx-a64z` and `mx-x64z`.

Do not start OB2.2 until OB2.1 passes on both runners.

Do not start OB2.3 or OB2.4 until OB2.1 and OB2.2 pass on both runners.

Stop and report if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- a case would require non-stock macOS privileges or private APIs
- a result contradicts prior Batch 1 expectations

## Runner Protocol

Use the same two-runner protocol as OB1.4:

1. `mx-a64z` implements the probe and commits implementation, raw JSON, and
   summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Only after both runners agree may the next gated probe begin.

## Required Fields For Every Probe

Record:

- exact public API call sequence
- exact return values
- exact `msgh_bits`
- sender and receiver right types
- observable user-reference deltas
- received message, header, or descriptor fields
- delivered-right usability where applicable
- cleanup-to-baseline result
- `entry_refs_*: null` unless directly observable through stock public APIs

## OB1.5 Header MOVE_SEND

Question: how does header `MACH_MSG_TYPE_MOVE_SEND` affect the sender's
observable send right?

Measure separately:

```text
before send
after mach_msg(SEND) returns
after mach_msg(RECEIVE) returns
```

## OB2.1 Descriptor COPY_SEND

Question: does descriptor `MACH_MSG_TYPE_COPY_SEND` preserve sender send urefs
and deliver a usable send right?

Record sender urefs before and after send, descriptor disposition and type,
receiver-side type, receiver-side refs, delivered-right usability, and cleanup.

## OB2.2 Descriptor MOVE_SEND

Question: how does descriptor `MACH_MSG_TYPE_MOVE_SEND` affect sender send
rights, and what usable right is delivered?

Record sender post-send state, receiver descriptor state, delivered-right
usability, and cleanup.

## OB2.3 Send-Once Descriptor

Question: what is the stock macOS behavior for send-once descriptor transfer?

Record accepted dispositions, exact return codes, delivered right type,
consumption behavior, and cleanup.

## OB2.4 Descriptor Error Handling

Validate normal API error behavior for malformed or invalid descriptor use,
without attempting to bypass platform protections.

Cover only cases safely expressible through public APIs, such as:

- invalid descriptor disposition
- duplicate movement of the same right in one message
- receiver-side delivery limitation if it can be produced safely through stock
  userland APIs

If a case cannot be produced safely and normally, classify it as
`not_observable`.
