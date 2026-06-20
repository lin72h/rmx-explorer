# Second-Round Review: nx-v64z macOS Oracle Plan

Reviewer: Opus agent (Phase 0.5 M2 implementation lane)
Date: 2026-05-12

## Reviewer Context

I am the Opus agent currently implementing Phase 0.5 M2 on the NextBSD/FreeBSD
side. I have direct evidence from batches 21 and 22 that is immediately relevant
to this plan. This review incorporates findings from active M2 work that the
plan's authors did not have when the plan was written.

---

## Findings

### 1. [major] COPY_SEND uref hypothesis is resolved — plan still treats it as open

The plan's open question #1 asks for "the canonical path to current NextBSD M1
batch 17-20 artifacts, especially the logs or JSON showing the suspected
COPY_SEND uref bug."

**This is no longer a suspected bug.** Batch 21 (M2.0 preflight) ran three
dedicated accounting tests and disproved the hypothesis:

- Header COPY_SEND: `entry_refs=2->2->2` (stable)
- Body descriptor COPY_SEND: `cargo_entry_refs=2->2->3->2` (stable on source;
  +1 on delivered right is expected receive-side insertion)
- MIG RPC COPY_SEND accumulation: `entry_refs=2->2->2->2` (stable across 3
  consecutive RPCs)

The original M1 batch 20 cleanup leak was caused by `task_self_trap()` returning
a combined SEND_RECEIVE right with `entry_refs=2`, which
`deallocate_port_name()` (one uref decrement) cannot remove. The fix was
`destroy_port_name()` — correct for cleanup but for a different reason than
the suspected COPY_SEND inflation.

**Why it matters**: The plan frames COPY_SEND uref accounting as the central
open question driving the oracle. The oracle probes should still verify this on
macOS, but the comparison target is now "confirm NextBSD matches macOS" rather
than "determine whether NextBSD has a bug."

**Recommended change**: Update the plan's framing from "suspected COPY_SEND uref
bug" to "COPY_SEND uref accounting confirmed stable on NextBSD; macOS oracle
should verify identical behavior." Update open question #1 to provide the
artifact paths rather than ask for them (see finding #2).

### 2. [minor] Open questions #1 and #2 are answerable now

The plan asks for canonical artifact paths and probe IDs. These exist:

**Artifact paths** (relative to `/Users/me/wip-mach-opus/wip-opus/`):

| Artifact | Path |
| --- | --- |
| Full probe source (batches 1-22) | `scripts/bhyve/nxplatform-mach-probe.c` |
| Batch 17-20 regression log | `reports/batch17-20-regression-serial.log` |
| Batch 21 COPY_SEND accounting log | `reports/batch21-serial.log` |
| Batch 22 cross-task descriptor log | `reports/batch22-serial.log` |
| M1 completion report | `reports/m1-completion-report.md` |
| MIG build script | `scripts/mig/build-migcom.sh` |
| MIG regeneration diffs | `reports/mig-regen-diffs/` |

**NextBSD probe IDs/batch names**:

| Batch | ID | Test count |
| --- | --- | --- |
| 17 | `characterize_batch17_mach_msg_inline_self` | 2 |
| 18 | `characterize_batch18_mach_msg_complex_descriptor` | 2 |
| 19 | `characterize_batch19_mach_msg_complex_ool` | 3 |
| 20 | `characterize_batch20_cross_task_inline_mach_msg` | 1 |
| 21 | `characterize_m2_batch21_copy_send_uref_accounting` | 3 |
| 22 | `characterize_m2_batch22_cross_task_copy_send_descriptor` | 1 |

**Recommended change**: Close open questions #1 and #2 by incorporating these
paths and IDs directly. Add them to the `cross_reference` field documentation
as concrete examples.

### 3. [minor] Schema missing `entry_refs` in `right_deltas`

The `right_deltas` schema has `before_urefs` and `after_urefs`. Our NextBSD
findings show that `entry_refs` (the kernel-level per-name reference count) can
differ from user-visible urefs and is the actual value that determines whether
`deallocate_port_name` suffices vs `destroy_port_name` is needed.

Key evidence:

- `task_self_trap()` returns a name with `entry_refs=2`, type SEND_RECEIVE
- Cross-task COPY_SEND descriptor delivery creates a name with `entry_refs=2`,
  type SEND (0x10000)
- Single `deallocate_port_name` cannot remove either of these

The macOS probes should capture `entry_refs` (via `mach_port_get_refs` with
appropriate right types) to enable direct comparison.

**Recommended change**: Add optional `entry_refs_before` and `entry_refs_after`
fields to the `right_deltas` object. These can be null when introspection is
unavailable, but when present they enable the most precise comparison with
NextBSD behavior.

### 4. [minor] Schema `remote_port` / `local_port` correlation with `right_deltas`

The schema has structured `remote_port` and `local_port` objects inside
`message`, and a separate `right_deltas` array with `port_name: "opaque"`. There
is no explicit way to correlate a `right_delta` entry with the port it describes
across the probe lifecycle.

**Recommended change**: Use a symbolic port label (e.g., `"cargo_port"`,
`"service_port"`, `"task_port"`) instead of the literal string `"opaque"` in
`right_deltas[].port_name`. The label should be probe-defined and consistent
within a single result. The `remote_port.name` and `local_port.name` should use
the same symbolic labels. This makes mechanical cross-field correlation possible
without comparing raw port integers.

### 5. [minor] Parent handoff document has older flat schema

`macos-oracle-validation-agent-handoff.md` (line ~286) shows a flat `message`
object with only `msgh_bits`, `descriptor_count`, and `descriptors`. The
comprehensive plan adds `remote_port`, `local_port`, and `header_rights`.

If `mx-x64z` or `mx-a64z` agents read the parent handoff first and use its
schema example as a template, they will produce results missing the header
rights fields.

**Recommended change**: Either update the parent handoff schema to match the
comprehensive plan, or add a clear note in the handoff that the comprehensive
plan schema supersedes the handoff example.

### 6. [minor] Process rendezvous orthogonality not specified

The global process-probe safety rule requires "an explicit rendezvous mechanism,
such as a pipe or Mach sync port." For probes that test Mach IPC behavior on
process exit, the rendezvous mechanism must be orthogonal to the Mach channel
under test.

Example: if testing whether a queued Mach message survives sender exit, the
parent must learn that the child has finished sending via a Unix pipe — not via
a second Mach message, which would couple the rendezvous to the subsystem being
tested.

**Recommended change**: Add one sentence: "The rendezvous mechanism must be
orthogonal to the IPC channel being tested — use a Unix pipe or signal, not a
separate Mach port, when the probe tests Mach message delivery on exit."

### 7. [minor] Unknown type bits from `mach_port_type()`

The plan specifies stop rules for `mach_port_type()` being unavailable or
unreliable, but not for the case where it returns type bits not defined in the
SDK headers being used.

Modern macOS may expose type bits (e.g., guarded port types, duct-taped
notification types) that the donor-era headers do not define. If a probe reads
back unexpected bits, it should record them as raw hex rather than silently
masking to known constants.

**Recommended change**: Add to the `port_type.c` probe specification: "Record
any type bits not covered by SDK header constants as raw hex in the result. Do
not silently mask to known values."

### 8. [info] Cross-task descriptor delivery creates `entry_refs=2` on NextBSD

This is a key comparison point the macOS oracle should verify. When a COPY_SEND
port descriptor is delivered cross-task on NextBSD, the received name has:

- `type = 0x10000` (MACH_PORT_TYPE_SEND)
- `entry_refs = 2`

A single `deallocate_port_name` is insufficient; `destroy_port_name` is
required for clean baseline return.

The macOS probes should record the delivered right's `entry_refs` to determine
whether this is a universal Mach behavior or a NextBSD-specific artifact.

### 9. [info] `task_self_trap()` combined right has `entry_refs=2`

On NextBSD, `task_self_trap()` returns a name with type SEND_RECEIVE and
`entry_refs=2`. This is relevant to the `m1/header_copy_send_accounting.c` and
`m1/header_move_send_accounting.c` probes, which will use the task port.

The macOS probes should record `mach_port_get_refs(mach_task_self(), ...)` for
both SEND and RECEIVE right flavors to establish the macOS baseline for this
combined right.

### 10. [info] `send_once_descriptor.c` naming and ordering are correct

The probe name `send_once_descriptor.c` is better than a narrower
`MACH_MSG_TYPE_MOVE_SEND_ONCE` name because the probe should discover which
send-once dispositions the SDK defines. The ordering — conditional after clean
COPY_SEND and MOVE_SEND — is correct and matches our M2 implementation order.

### 11. [info] `receiver_copyout_failure.c` should default to `not_observable`

From our kernel-side work, inducing receiver copyout failure from stock
userland is difficult without control over the receiver's IPC space limits.
The plan's approach — attempt and fall back to `not_observable` — is correct.

### 12. [info] `ipc-hello` compile-only check is at the right position

Runtime should not be attempted before foundational probes establish that
introspection APIs work. Compile-only after Stage 3 foundational probes is the
right sequencing.

### 13. [info] Helper signing in environment object is the right approach

Ad-hoc signing status rarely varies per-helper within a single run. Recording
it once in the environment object is cleaner than per-probe. If a specific
helper has different signing requirements, that can be noted in the probe's
`notes` field.

---

## Answers to Specific Review Questions

### Q1: Does the foundational floor cover introspection needs?

**Yes.** `mach_port_names()` + `mach_port_get_refs()` + `mach_port_type()`
together provide namespace inventory, uref accounting, and right-class
validation. This covers all planned M1/M2 probes.

One addition: the foundational probes should also characterize
`mach_port_get_refs()` with MACH_PORT_RIGHT_SEND vs MACH_PORT_RIGHT_RECEIVE
on the task self port, since our NextBSD findings show the combined
SEND_RECEIVE right has `entry_refs=2` and this affects cleanup strategy.

### Q2: Is the expanded JSON schema sufficient?

**Mostly.** The `header_rights`, typed `returns`, typed `right_deltas`, and
`cross_reference` additions are good. Two gaps:

1. Missing `entry_refs` in `right_deltas` (finding #3 above)
2. Missing symbolic port labels for cross-field correlation (finding #4 above)

### Q3: `cross_reference` required with nullable fields or optional?

**Required with nullable is correct.** Making it optional forces every consumer
to check existence. Nullable fields in a required object are simpler and the
schema shape is stable from v1.

### Q4: Is `send_once_descriptor.c` correctly conditional?

**Yes.** Promoting it into core transfer probes would risk blocking M2
completion on a secondary transfer type. The current ordering is correct.

### Q5: Is `receiver_copyout_failure.c` realistic?

**Pre-classify as `not_observable` unless the parent provides a known method.**
The plan's approach is correct. Attempting and documenting the method is
valuable even if the result is `not_observable`.

### Q6: Narrower `MACH_MSG_TYPE_MOVE_SEND_ONCE` probe name?

**No.** The broader name is better. The probe should discover which send-once
dispositions the SDK actually defines rather than assuming one.

### Q7: Is the process rendezvous rule strong enough?

**Yes, with one addition**: specify orthogonality to the channel under test
(finding #6 above).

### Q8: Helper signing — environment or per-probe?

**Environment object**, with per-probe `notes` for exceptions.

### Q9: Is `ipc-hello` at the right point?

**Yes.** Compile-only after Stage 3, runtime only after M1/M2 facts.

### Q10: Are remaining parent questions blocking Stage 1-2?

**No.** Questions 1-2 are now answerable (finding #2 above). Question 3
(schema name confirmation) is low-risk since the constant is centralized.
Questions 4-10 affect Stage 3+ only. **Stage 1-2 can begin immediately.**

### Q11: Are `m1/` and `m2/` directory names acceptable?

**Yes.** The documentation clarification already in the plan is sufficient.
The roadmap package context is clear.

### Q12: Missing stop/skip rules?

One addition: add a skip rule for `mach_port_type()` returning type bits not
covered by SDK headers (finding #7 above). Also add guidance that when
`mach_port_get_refs()` returns values that don't match expected patterns
(e.g., `entry_refs > 1` for a fresh send right), the probe should record the
raw value rather than failing.

---

## Open Questions

1. **Delivered right entry_refs**: Should the macOS probes have an explicit
   sub-test that checks `mach_port_get_refs()` on a cross-task delivered send
   right? Our NextBSD finding of `entry_refs=2` for a COPY_SEND delivered right
   is either universal Mach behavior or a NextBSD-specific artifact. The oracle
   should disambiguate this.

2. **`destroy_port_name` vs `deallocate_port_name` characterization**: Should
   the macOS probes include an explicit sub-test showing whether single
   `mach_port_deallocate()` suffices to clean up a cross-task delivered send
   right, or whether `mach_port_destroy()` / `mach_port_mod_refs(..., -N)` is
   needed? This directly informs the cleanup strategy for both the NextBSD
   implementation and the comparison policy.

3. **Schema name `nx-v64z.macos-oracle.v1`**: This is pending parent
   confirmation per open question #3. Stage 1-2 can proceed with the constant
   centralized, but the name should be confirmed before Stage 8 host result
   collection.

---

## Suggested Plan Changes

1. Close open questions #1 and #2 by incorporating the NextBSD artifact paths
   and probe IDs listed in finding #2.

2. Reframe the COPY_SEND uref narrative from "suspected bug to investigate" to
   "confirmed stable; oracle verifies macOS matches."

3. Add optional `entry_refs_before` / `entry_refs_after` to the `right_deltas`
   schema object.

4. Use symbolic port labels instead of literal `"opaque"` strings in
   `right_deltas[].port_name` and `message.remote_port.name` /
   `message.local_port.name`.

5. Update the parent handoff document schema example to include `remote_port`,
   `local_port`, and `header_rights`, or add a supersession note.

6. Add rendezvous orthogonality sentence to the global process-probe safety
   rule.

7. Add guidance for unknown `mach_port_type()` bits: record as raw hex.

8. Add explicit sub-tests for delivered right `entry_refs` in both
   `descriptor_copy_send.c` and `descriptor_move_send.c`.

---

## Verdict

**Ready to implement Stage 1-2 now.** Stage 3+ can begin after minor edits
(suggestions 3-8 above). No blocking gaps.

The plan is well-structured, the probe ordering is correct, the schema is
nearly complete, and the settled decisions are internally consistent. The
main update needed is reframing the COPY_SEND uref question from an open
investigation to a confirmed comparison baseline, and adding `entry_refs`
to the schema so the most precise comparison is mechanically possible.
