# Parent Directive: Batch 1 Oracle Feature Validation

Date: 2026-05-12

Status: approved

Related addendum:

- `parent-response-to-opus-oracle-batches.md` approves the OPUS two-batch
  dependency model and extends this directive with Batch 2 requirements. Where
  the OPUS proposal asks for stock-macOS `entry_refs`, the parent response
  supersedes it: record `entry_refs_*` as null unless directly observable.

## Decision

Proceed with Batch 1, but treat it as three ordered gates, not one flat probe
set.

Approved Batch 1:

1. `foundation/port_names.c`
2. `foundation/port_type.c`
3. `foundation/port_get_refs.c`
4. `m1/header_copy_send_accounting.c`
5. `m1/header_move_send_accounting.c`
6. `m2/descriptor_copy_send.c`
7. `m2/descriptor_move_send.c`

Required ordering:

1. Batch 1A foundation must pass on both native macOS runners first.
2. Then implement header COPY_SEND/MOVE_SEND.
3. Then implement descriptor COPY_SEND/MOVE_SEND.

Do not start descriptor probes until foundation introspection is clean and
header COPY_SEND behavior is captured.

## Batch Gates

### Gate 1A: Foundation Introspection

Approved probes:

- `foundation/port_names.c`
- `foundation/port_type.c`
- `foundation/port_get_refs.c`

Gate requirement:

- both `mx-x64z` and `mx-a64z` pass
- cleanup returns to baseline
- no foundation introspection API is unreliable
- raw JSON artifacts are committed for both runners

### Gate 1B: Header Right Accounting

Approved probes:

- `m1/header_copy_send_accounting.c`
- `m1/header_move_send_accounting.c`

Gate requirement:

- both native macOS runners pass or produce a parent-reviewed classified
  difference
- COPY_SEND source-side uref behavior is captured before descriptor COPY_SEND
- MOVE_SEND source-side post-send state is captured before descriptor MOVE_SEND

### Gate 1C: Descriptor Transfer Minimum

Approved probes:

- `m2/descriptor_copy_send.c`
- `m2/descriptor_move_send.c`

Gate requirement:

- descriptor behavior is compared explicitly against the header behavior from
  Gate 1B
- delivered-right usability and cleanup-to-baseline are recorded
- `entry_refs` remain null unless directly observable from stock macOS userland

## Direct Answers

1. First rmxOS feature batch:

   Foundation introspection plus header COPY_SEND/MOVE_SEND, followed by minimum
   descriptor COPY_SEND/MOVE_SEND.

2. Descriptor transfer:

   Include it in Batch 1, but not as the first work. It is gated behind
   foundation and header accounting.

3. Top implementation risk:

   COPY_SEND source-side uref stability remains the top risk. The prior M1 leak
   was in this area. MOVE_SEND consumption is second. Send-once, fork
   inheritance, and bootstrap special ports are Batch 2 unless implementation
   hits them earlier.

4. `entry_refs`:

   Record stock-macOS-unobservable `entry_refs_before` and `entry_refs_after` as
   null. Do not invent a proxy value and do not infer kernel entry refs from
   urefs.

   Use observable proxies separately:

   - `mach_port_get_refs`
   - `mach_port_type`
   - port namespace baseline
   - delivered-right usability
   - cleanup-to-baseline

5. Raw JSON artifacts:

   Force-add raw JSON for Batch 1. Include at minimum:

   - `environment.json`
   - every probe result JSON
   - curated markdown summary per runner

   Empty stderr logs do not need to be force-added unless they explain a
   failure. If stderr is non-empty, preserve it.

6. Runner gates:

   Both `mx-x64z` and `mx-a64z` are mandatory gates for Batch 1. If they differ,
   classify the result as `version_sensitive` or `architecture_sensitive` and
   stop for parent decision before using it as an rmxOS target.

7. Minimum rmxOS comparison output:

   Required floor:

   - exact call sequence
   - exact return values
   - sender/receiver right types
   - uref deltas where observable
   - delivered right usability
   - cleanup status
   - semantic classification against macOS

## Required Infrastructure Fix Before Batch 1

Fix the Rosetta/agent guard before collecting Batch 1 evidence.

`mx-x64z` evidence must be rejected if it is running as translated x86_64 on
Apple Silicon. `mx-x64z` means native Intel macOS, not Rosetta. The existing
`mx-a64z` Rosetta guard is not enough.

## Probe Guidance

For `foundation/port_names.c`:

- make cleanup-to-baseline a hard pass condition

For `foundation/port_type.c`:

- preserve raw hex type values
- do not collapse unknown extra bits into friendly names

For `foundation/port_get_refs.c`:

- make it the authority for user-reference observations
- later probes needing urefs should use this helper pattern

For header COPY_SEND:

- measure sender send urefs before send
- send using `MACH_MSG_TYPE_COPY_SEND` in `msgh_bits`
- measure sender send urefs after successful send
- verify receiver gets a usable send right
- clean up both sides to baseline

For header MOVE_SEND:

- verify source right is consumed/decremented after successful send
- verify receiver gets the usable right
- record the exact source-side post-send state

For descriptor COPY_SEND/MOVE_SEND:

- do not start until header behavior is known
- compare descriptor behavior explicitly against header behavior
- keep `entry_refs` null unless directly observable

## Stop Conditions

Stop and ask parent if:

- `mx-x64z` and `mx-a64z` disagree
- any foundation introspection API is unreliable
- cleanup does not return to baseline
- COPY_SEND changes sender urefs on native macOS
- probe logic needs private entitlement, SIP change, or non-stock API

## Expected Deliverable

For Batch 1, produce:

1. One runner summary for `mx-x64z`.
2. One runner summary for `mx-a64z`.
3. Force-added raw JSON artifacts for both runners.
4. A short cross-runner comparison table.
5. A parent-facing finding: what rmxOS must match for each probe.

## Parent Criticism To Preserve

Descriptor transfer is useful, but only after source-side header behavior is
nailed down. The oracle lane should not blur "we can write M2 probes" with "M2
evidence is safe to interpret." Foundation and header accounting are the
guardrails.

Batch 2 remains approved only as a gated follow-up. Do not start M2.2/M2.3/M2.4
rmxOS implementation until the matching oracle probes in
`parent-response-to-opus-oracle-batches.md` exist and have run on both native
macOS runners.
