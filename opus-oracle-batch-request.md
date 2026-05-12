# Oracle Batch Request: Opus Implementation Lane

Date: 2026-05-12
Author: Opus implementation lane
For: Oracle agent (nx-v64z)

## Context

The Opus lane uses oracle-driven development. We do not implement new Mach IPC
behaviors until the oracle has established the correct macOS behavior. This
document defines two oracle batches that cover the features we need to implement
next.

Oracle Batch 1 is the foundation. Oracle Batch 2 is the descriptor transfer
work that is our highest-priority implementation target.

## Oracle Batch 1: Foundation and Right Accounting

These probes establish baseline Mach port semantics. Our implementation already
has bhyve batches for most of these, but we need macOS ground truth to classify
our results as correct or divergent.

### OB1.1: port_names — Namespace Inventory

Probe: `foundation/port_names.c`
test_id: `macos_foundation_port_names`
cross_reference.nextbsd_test_id: `characterize_r6c_batch3_port_basics`

Questions to answer:
- Does `mach_port_names()` return a non-empty array for a fresh process?
- Does `mach_task_self()` appear in the name list?
- What type does `mach_task_self()` report? (We see `MACH_PORT_TYPE_SEND_RECEIVE`)
- When we allocate a receive right, does it appear in the next `mach_port_names()` call?
- When we destroy it, does it disappear?

Right deltas to record:
- allocate receive: before_count, after_count, delta = +1
- destroy receive: before_count, after_count, delta = -1

### OB1.2: port_type — Right Class Inspection

Probe: `foundation/port_type.c`
test_id: `macos_foundation_port_type`
cross_reference.nextbsd_test_id: null (new)

Questions to answer:
- Allocate receive right: `mach_port_type()` returns `MACH_PORT_TYPE_RECEIVE`?
- Insert send right on same name: type becomes `MACH_PORT_TYPE_SEND_RECEIVE`?
- Allocate port set: type is `MACH_PORT_TYPE_PORT_SET`?
- What is `mach_task_self()` type? (We see `MACH_PORT_TYPE_SEND_RECEIVE`, entry_refs=2)

Returns to record:
- Every `mach_port_type()` call with exact `kern_return_t`

Critical side-capture:
- `mach_port_get_refs(mach_task_self(), MACH_PORT_RIGHT_SEND)` — what is the
  send ref count on task_self? We see entry_refs=2 on NextBSD.

### OB1.3: port_get_refs — User Reference Accounting

Probe: `foundation/port_get_refs.c`
test_id: `macos_foundation_port_get_refs`
cross_reference.nextbsd_test_id: `characterize_r7_stage1c_batch5_send_right_mod_refs`

Questions to answer:
- Allocate receive right: `mach_port_get_refs(RECEIVE)` returns 1?
- `mach_port_insert_right(MAKE_SEND)`: `mach_port_get_refs(SEND)` returns 1?
- `mach_port_mod_refs(SEND, +1)`: send refs becomes 2?
- `mach_port_mod_refs(SEND, -1)`: send refs back to 1?
- After removing all send refs, type reverts to `MACH_PORT_TYPE_RECEIVE`?

Right deltas to record:
- Each mod_refs step: before_urefs, after_urefs, right_type

### OB1.4: header_copy_send_accounting — COPY_SEND Uref Stability

Probe: `m1/header_copy_send_accounting.c`
test_id: `macos_m1_header_copy_send_accounting`
cross_reference.nextbsd_test_id: `characterize_m2_batch21_copy_send_uref_accounting`
cross_reference.donor_equivalent_id: `ipc-hello` (partial)

This is the key accounting test. Same-process send-to-self.

Questions to answer:
- Create receive right, insert send right. Record entry_refs (expect 2 on
  NextBSD — combined SEND_RECEIVE).
- Send inline message with `MACH_MSG_TYPE_COPY_SEND` as remote_port disposition.
- After `mach_msg(SEND)`: are sender urefs/entry_refs UNCHANGED?
- After `mach_msg(RECEIVE)`: what are the urefs/entry_refs?
- Is the received port the same name (self-send case)?

Our NextBSD results (batch 21 test 1):
- entry_refs before send: 2
- entry_refs after send: 2 (stable — COPY_SEND does not inflate)
- entry_refs after receive: 2 (self-send, same name)

Right deltas to record:
- entry_refs_before send, entry_refs_after send
- entry_refs_before receive, entry_refs_after receive

### OB1.5: header_move_send_accounting — MOVE_SEND Consumption

Probe: `m1/header_move_send_accounting.c`
test_id: `macos_m1_header_move_send_accounting`
cross_reference.nextbsd_test_id: null (planned, our B23+)

We have NOT tested this on NextBSD yet. The oracle result will be our spec.

Questions to answer:
- Create receive right, insert send right. Record urefs.
- Send inline message with `MACH_MSG_TYPE_MOVE_SEND` as remote_port disposition.
- After send: is the sender's send right consumed? (urefs decremented or name
  gone from namespace?)
- If the name had SEND_RECEIVE, does it revert to RECEIVE only after the move?
- After receive: what right type does the received port have?

This is critical for our M2.2 implementation. We cannot write MOVE_SEND code
until we know the exact macOS consumption behavior.

Right deltas to record:
- sender entry_refs_before, entry_refs_after (expect decrement or removal)
- sender right_type before, right_type after
- receiver delivered right_type, delivered entry_refs

## Oracle Batch 2: Cross-Task Descriptor Transfer

These probes require two processes (parent + child via fork). They are our
highest-value oracle targets because they drive our M2 implementation directly.

Process safety requirements for all OB2 probes:
- `alarm(5)` watchdog in both parent and child
- Rendezvous via Unix pipe, NOT via Mach messages
- `waitpid()` with timeout handling
- Cleanup in both parent and child
- Baseline capture before/after in parent

### OB2.1: descriptor_copy_send — Cross-Task COPY_SEND Descriptor

Probe: `m2/descriptor_copy_send.c`
test_id: `macos_m2_descriptor_copy_send`
cross_reference.nextbsd_test_id: `characterize_m2_batch22_cross_task_copy_send_descriptor`

This is the single most important oracle probe for our current work.

Protocol:
1. Parent creates service_port (receive + send).
2. Parent sets service_port as bootstrap port, forks child.
3. Child retrieves bootstrap port, creates cargo_port (receive + send).
4. Child sends COMPLEX message to bootstrap carrying cargo send right as
   `MACH_MSG_TYPE_COPY_SEND` port descriptor.
5. Parent receives the message, extracts delivered port from descriptor.
6. Parent sends verification message through delivered port back to child.
7. Child confirms verification receipt.
8. Both clean up to baseline.

Questions to answer:
- After child sends COPY_SEND descriptor: are child's cargo_port urefs UNCHANGED?
- What type does the parent see for the delivered port? (We see `MACH_PORT_TYPE_SEND`, 0x10000)
- What are the delivered port's entry_refs? (We see entry_refs=2 on NextBSD — THIS IS THE KEY QUESTION)
- Is `mach_port_deallocate()` sufficient to clean up the delivered right, or
  is `mach_port_destroy()` required?
- Does the delivered send right actually work? (verified by sending a message through it)

Our NextBSD results (batch 22):
- Child cargo_port urefs stable after send (COPY_SEND does not inflate)
- Parent delivered port: `MACH_PORT_TYPE_SEND` (0x10000), entry_refs=2
- Single `deallocate_port_name` was insufficient for cleanup (entry_refs=2)
- `destroy_port_name` required, OR two deallocates
- Delivered send right is functional (verification message succeeds)

If macOS also shows entry_refs=2, this is universal Mach behavior and our
implementation is correct. If macOS shows entry_refs=1, we have a NextBSD
divergence to investigate.

Right deltas to record:
- child cargo_port: entry_refs_before send, entry_refs_after send
- parent delivered_port: right_type, entry_refs at delivery
- parent delivered_port: entry_refs after deallocate attempt
- cleanup: returned_to_baseline for both parent and child

### OB2.2: descriptor_move_send — Cross-Task MOVE_SEND Descriptor

Probe: `m2/descriptor_move_send.c`
test_id: `macos_m2_descriptor_move_send`
cross_reference.nextbsd_test_id: null (planned, our B23+)

Same protocol as OB2.1, but with `MACH_MSG_TYPE_MOVE_SEND` descriptor
disposition instead of COPY_SEND.

Questions to answer:
- After child sends MOVE_SEND descriptor: is the child's send right CONSUMED?
- Does the child's cargo_port name revert to RECEIVE only, or is the name removed?
- What type/entry_refs does the parent see for the delivered port?
- Is cleanup different from COPY_SEND delivery?

We have NO NextBSD data for this yet. The oracle result IS the spec.

### OB2.3: send_once_descriptor — Send-Once Right Descriptor

Probe: `m2/send_once_descriptor.c`
test_id: `macos_m2_send_once_descriptor`
cross_reference.nextbsd_test_id: null (planned)

Questions to answer:
- Create a send-once right. Send it as a descriptor with
  `MACH_MSG_TYPE_MOVE_SEND_ONCE`.
- Is the send-once right consumed from sender's namespace after send?
- What type does receiver see? Send-once, or converted to send?
- What are entry_refs on the received right?
- After receiver uses the send-once right (sends one message), does it
  auto-destruct?

### OB2.4: Negative Tests — Invalid Descriptor Operations

Probe: `m2/invalid_descriptor_disposition.c`
test_id: `macos_m2_invalid_descriptor_disposition`

Questions to answer:
- Send a message with an invalid descriptor disposition value: what
  `kern_return_t` / `mach_msg_return_t` is returned?
- Is the message silently dropped, or is there an explicit error?
- Are any rights consumed on failure?

Probe: `m2/dead_name_descriptor_right.c`
test_id: `macos_m2_dead_name_descriptor_right`

Questions to answer:
- Destroy a port, then try to send its (now dead) name as a COPY_SEND
  descriptor: what error?
- Try to send a non-existent name as a descriptor: what error?
- Record exact `mach_msg_return_t` values for both cases.

Probe: `m2/double_move_send_descriptor.c`
test_id: `macos_m2_double_move_send_descriptor`

Questions to answer:
- Create one send right. Put it in TWO descriptors both with MOVE_SEND
  disposition in the same message.
- Does `mach_msg()` reject this? What return code?
- Or does it succeed and only the first descriptor consumes the right?
- Are any rights leaked on failure?

## Implementation Dependency Map

```
Oracle Batch 1 (foundation)          Our Implementation
─────────────────────────────        ──────────────────
OB1.1 port_names          ────→     Retroactive comparison with our B3
OB1.2 port_type            ────→     Retroactive comparison, new baseline
OB1.3 port_get_refs        ────→     Retroactive comparison with our B5
OB1.4 header COPY_SEND     ────→     Confirm our B21 result is correct
OB1.5 header MOVE_SEND     ────→     Spec for our planned B23 header test

Oracle Batch 2 (descriptors)        Our Implementation
─────────────────────────────        ──────────────────
OB2.1 descriptor COPY_SEND ────→     Confirm our B22, spec entry_refs question
OB2.2 descriptor MOVE_SEND ────→     Spec for our M2.2 (BLOCKED until oracle)
OB2.3 send_once descriptor ────→     Spec for our M2.3 (BLOCKED until oracle)
OB2.4 negative tests       ────→     Spec for our M2.4 (BLOCKED until oracle)
```

## What We Will Do With the Results

For each oracle probe result:

1. **Read the JSON** from `results/mx-x64z/` and `results/mx-a64z/`.
2. **Compare against our NextBSD data** (batch serial logs).
3. **Write a finding** in `findings/nx-v64z/` with classification:
   - `exact_match` — our behavior matches macOS exactly
   - `equivalent_match` — semantically equivalent, minor difference in form
   - `intentional_divergence` — different by design, parent approved
   - `version_sensitive` — differs between Intel and Apple Silicon macOS
   - `bug` — our behavior is wrong, needs fix
4. **Implement or fix** our NextBSD code to match the oracle spec.
5. **Mirror the probe** into our bhyve test lane for regression.

## Suggested Execution Order for the Oracle Agent

Oracle Batch 1 can proceed immediately — all foundation probes are
single-process and straightforward.

Recommended order within OB1:
1. OB1.1 (port_names) — smallest, validates basic API
2. OB1.2 (port_type) — validates right class inspection
3. OB1.3 (port_get_refs) — validates uref accounting
4. OB1.4 (header COPY_SEND) — same-process, confirms our B21
5. OB1.5 (header MOVE_SEND) — same-process, new spec

Oracle Batch 2 requires process orchestration and should follow OB1.
The stage-gate is: OB1.1-OB1.3 must pass before starting OB2, because
if basic port operations are broken, descriptor transfer results are
meaningless.

Recommended order within OB2:
1. OB2.1 (descriptor COPY_SEND) — highest priority, confirms our B22
2. OB2.2 (descriptor MOVE_SEND) — second highest, new spec
3. OB2.3 (send-once) — after COPY_SEND and MOVE_SEND are clean
4. OB2.4 (negative tests) — last, establishes error surface

## Urgency

OB1.4 and OB2.1 are the most urgent. They validate our existing implementation
(batches 21-22) and determine whether we have a divergence to fix.

OB1.5 and OB2.2 are blocking our next implementation work (M2.2 MOVE_SEND).
We will not start M2.2 until the oracle has run these.

OB2.3 and OB2.4 block M2.3 and M2.4 respectively.

OB1.1-OB1.3 are retroactive validation — important but not blocking new work.
