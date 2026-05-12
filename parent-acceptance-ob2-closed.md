# Parent Acceptance: OB2.4 Accepted, Core OB2 Closed

OB2.4 is accepted as the macOS negative descriptor/error contract.

Both native runners agree, so this is now the oracle contract for rmxOS M2
descriptor error behavior.

## Accepted OB2.4 Contract

### Invalid Descriptor Disposition `0xff`

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- no message delivery
- no rights consumed
- cleanup returns to baseline

### Nonexistent Descriptor Source

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- no message delivery
- source remains invalid
- cleanup returns to baseline

### Dead-Name Descriptor Source

- `mach_msg(SEND)` returns `MACH_MSG_SUCCESS`
- message is delivered
- dead-name entry is consumed
- cleanup returns to baseline

This is expected macOS behavior. Reclassify the probe result from failure to
accepted behavior. The original expectation was wrong.

### Duplicate `MOVE_SEND` Descriptors For Same Right

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- no message delivery
- sender send right is fully consumed
- cleanup returns to baseline

This is also important: failure does not imply no mutation. rmxOS must match
the observed failure side effect unless parent later approves an intentional
divergence.

## Required Follow-Up

1. Update `dead_name_descriptor_right` expected outcome so future runs report
   pass when macOS behavior is reproduced.
2. Preserve the original note that the old expectation was wrong.
3. Keep raw JSON artifacts for both runners.
4. Add or update a consolidated OB2 finding that lists accepted descriptor
   contracts:
   - OB2.1 COPY_SEND descriptor
   - OB2.2 MOVE_SEND descriptor
   - OB2.3 MOVE_SEND_ONCE descriptor
   - OB2.4 negative/error behavior

## Core OB2 Status

Core OB2 is closed.

The descriptor-transfer oracle spec is now ready to drive rmxOS M2
implementation.

## Implementation Implications For rmxOS

rmxOS should now target these descriptor semantics:

- COPY_SEND descriptor:
  - sender send urefs remain stable
  - receiver gets usable `MACH_PORT_TYPE_SEND`
  - delivered send refs observable as `1`
  - one deallocate cleans up receiver right
- MOVE_SEND descriptor:
  - sender send right consumed at successful send return
  - sender cargo type changes `SEND_RECEIVE -> RECEIVE`
  - receiver gets usable `MACH_PORT_TYPE_SEND`
  - delivered send refs observable as `1`
  - one deallocate cleans up receiver right
- MOVE_SEND_ONCE descriptor:
  - receiver gets `MACH_PORT_TYPE_SEND_ONCE`
  - first use succeeds
  - second use fails with `MACH_SEND_INVALID_DEST`
  - receiver gets only one message
- Invalid descriptor disposition:
  - send fails with `MACH_SEND_INVALID_RIGHT`
  - no delivery
  - no right consumption
- Nonexistent descriptor source:
  - send fails with `MACH_SEND_INVALID_RIGHT`
  - no delivery
  - source remains invalid
- Dead-name descriptor source:
  - send succeeds
  - message is delivered
  - dead-name entry is consumed
- Duplicate MOVE_SEND descriptors for the same right:
  - send fails with `MACH_SEND_INVALID_RIGHT`
  - no delivery
  - sender send right is fully consumed

Do not proceed by assumption for any descriptor behavior outside this list. New
behavior needs a new oracle probe.

The two most important surprises are dead-name delivery and duplicate-MOVE
failure consuming the sender right. Those should be highlighted to the
implementation agent because they are easy to implement more logically and
still be wrong against macOS.
