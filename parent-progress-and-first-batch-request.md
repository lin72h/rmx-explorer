# Progress Report and First-Batch Feature Request

Date: 2026-05-12

For: parent GPT agent and implementation lanes

## Current Status

The `mach-oracle` repository is now usable as the native macOS semantic oracle
lane.

Repository:

```text
git@github.com:lin72h/mach-oracle.git
```

Current verified runner evidence:

| Runner | Host | Status | Evidence File |
| --- | --- | --- | --- |
| `mx-x64z` | native Intel macOS, Darwin 25.4.0, macOS 26.4 | Stage 1-2 smoke pass | `mx-x64z/stage12-smoke-result-mx-x64z.md` |
| `mx-a64z` | native Apple Silicon macOS, Darwin 25.5.0, macOS 26.5, Rosetta inactive | Stage 1-2 smoke pass | `mx-a64z/stage12-native-smoke-result-mx-a64z.md` |
| `rx` | local FreeBSD/rmxOS development host | expected smoke skip, schema pass | local ignored result only |

Both native macOS runners prove the Stage 1-2 infrastructure can:

- build the C smoke probe
- ad-hoc sign the probe
- capture environment JSON
- run the probe through the harness
- emit one schema-valid JSON result
- validate nested JSON result structure
- report cleanup back to baseline

The smoke evidence is only infrastructure/foundation evidence. It does not yet
answer the Mach IPC feature questions needed for rmxOS implementation.

## Known Infrastructure Follow-Up

Before broad Stage 3 collection, fix this remaining guard:

- `harness/run_all.sh` should reject `mx-x64z` evidence when running under
  Rosetta on Apple Silicon. The current guard rejects Rosetta for `mx-a64z`, but
  `mx-x64z:x86_64` could still be a translated process.

Optional cleanup:

- simplify `validate_json.sh` integer/null helper to avoid a confusing boolean
  rejection expression.

These do not invalidate the current `mx-a64z` evidence because it explicitly
reports `sysctl.proc_translated: 0`. They should be fixed before future runner
collection expands.

## What The Oracle Lane Can Now Do

The macOS runner agents can add portable C probes, run them on both native macOS
architectures, and produce reusable regression evidence for rmxOS.

The intended validation loop is:

1. Parent chooses the first rmxOS feature batch.
2. Oracle agents add macOS probes for those behaviors.
3. `mx-x64z` and `mx-a64z` run the probes and commit curated result summaries,
   plus raw JSON artifacts if requested.
4. rmxOS/NextBSD implementation runs matching local probes.
5. Parent compares behavior and decides whether rmxOS matches, diverges, or
   needs implementation changes.
6. The same probes stay as regression tests.

## Recommended First Oracle Batch

I recommend the first batch focus on the smallest foundation needed for correct
Mach IPC right accounting, then immediately answer COPY_SEND/MOVE_SEND behavior.

### Batch 1A: Foundation Introspection

These should run first because later M1/M2 probes depend on reliable inspection.

1. `foundation/port_names.c`

   Goals:

   - prove `mach_port_names()` is reliable on both macOS hosts
   - capture baseline namespace count/types
   - verify an allocated receive right appears
   - verify destroyed right disappears
   - inspect `mach_task_self()` presence/type when observable

2. `foundation/port_type.c`

   Goals:

   - classify receive, send, send-receive, send-once, port-set, and dead-name
     states when stock userland can create them
   - preserve raw hex for unknown or extra type bits
   - establish whether Intel and Apple Silicon differ

3. `foundation/port_get_refs.c`

   Goals:

   - verify receive right refs
   - insert send rights and verify send urefs
   - use `mach_port_mod_refs()` / deallocate paths to verify accounting
   - record unavailable kernel-only `entry_refs` as null rather than inventing
     values

### Batch 1B: Header Right Accounting

These are the first feature-level probes I recommend for rmxOS implementation
alignment.

1. `m1/header_copy_send_accounting.c`

   Main question:

   - Does `MACH_MSG_TYPE_COPY_SEND` in `msgh_bits` leave sender urefs unchanged?

   Required evidence:

   - sender urefs before send
   - sender urefs after send
   - received header right type
   - cleanup result
   - exact `mach_msg()` return

2. `m1/header_move_send_accounting.c`

   Main question:

   - Does `MACH_MSG_TYPE_MOVE_SEND` in `msgh_bits` consume/decrement the
     sender right immediately on successful send?

   Required evidence:

   - sender right state before send
   - sender right state after send
   - received right type/usability
   - cleanup result
   - exact `mach_msg()` return

### Batch 1C: Descriptor Transfer Minimum

Start descriptor transfer only after Batch 1A is clean and at least header
COPY_SEND is understood.

1. `m2/descriptor_copy_send.c`

   Main questions:

   - Does descriptor `MACH_MSG_TYPE_COPY_SEND` leave sender urefs unchanged?
   - Does the receiver get a usable send right?
   - Is delivered-right cleanup a single deallocate or stronger cleanup?
   - Are delivered `entry_refs` observable from stock macOS userland? If not,
     record null and compare against rmxOS through observable cleanup behavior.

2. `m2/descriptor_move_send.c`

   Main questions:

   - Does descriptor `MACH_MSG_TYPE_MOVE_SEND` consume sender rights as header
     MOVE_SEND does?
   - What exact receiver right type is delivered?
   - What cleanup is required?

## Defer Until Batch 2 Unless Parent Needs Them First

These are important but should follow the above unless the parent has an
immediate implementation dependency:

- `m2/send_once_descriptor.c`
- `m2/double_move_send_descriptor.c`
- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/receiver_copyout_failure.c`
- `m1/fork_port_inheritance.c`
- `m1/bootstrap_special_port.c`
- queued sender-exit / receiver-exit descriptor probes

## Questions For Parent Agent

Please answer these before the macOS runner agents start Batch 1 implementation.

1. What is the first rmxOS feature batch you want to implement against native
   macOS evidence?

   Recommended answer:

   ```text
   Batch 1 = foundation introspection + header COPY_SEND/MOVE_SEND + descriptor
   COPY_SEND/MOVE_SEND minimum.
   ```

2. Should Batch 1 include descriptor transfer immediately, or should it stop
   after foundation plus header right accounting?

3. Is the most urgent implementation risk still COPY_SEND source-side uref
   stability, or has priority shifted to MOVE_SEND consumption, send-once, fork
   inheritance, or bootstrap special ports?

4. For macOS stock userland where kernel `entry_refs` are not directly
   observable, should the oracle record `entry_refs_*: null` and compare
   cleanup/usability behavior, or do you want an alternate observable proxy?

5. Do you want raw JSON result artifacts force-added for Batch 1, or are
   curated markdown summaries enough?

   Recommendation:

   ```text
   Force-add raw JSON for Batch 1 so comparison agents can mechanically parse
   the macOS baseline.
   ```

6. Should `mx-x64z` and `mx-a64z` both be mandatory gates for every Batch 1
   probe before rmxOS implementation changes are accepted?

   Recommendation:

   ```text
   Yes. If they differ, classify as version_sensitive with architecture notes
   and ask parent before choosing an rmxOS behavior.
   ```

7. What is the minimum rmxOS comparison output you want for each probe?

   Recommended floor:

   - exact call sequence
   - exact return values
   - sender/receiver right types
   - uref deltas where observable
   - cleanup status
   - semantic classification against macOS

## Copy/Paste Prompt For Parent Agent

```text
The macOS oracle infrastructure is working on both native runners:

- mx-x64z: Intel macOS smoke pass
- mx-a64z: Apple Silicon native smoke pass
- rx local path: expected skip, schema pass

We are ready to add the first feature/regression probe batch.

Please choose the first rmxOS feature batch to implement against native macOS
evidence. Recommended Batch 1 is:

1. foundation/port_names.c
2. foundation/port_type.c
3. foundation/port_get_refs.c
4. m1/header_copy_send_accounting.c
5. m1/header_move_send_accounting.c
6. m2/descriptor_copy_send.c
7. m2/descriptor_move_send.c

Please confirm, reorder, or reduce this batch. Also answer:

- Should descriptor transfer be included in Batch 1 or deferred?
- Is COPY_SEND source uref stability still the top implementation risk?
- Should raw JSON artifacts be force-added for Batch 1?
- Are both mx-x64z and mx-a64z mandatory gates for each probe?
- How should stock-macOS-unobservable entry_refs be represented: null plus
  cleanup/usability comparison, or another proxy?
```

## Recommendation

Proceed with Batch 1A immediately after the parent confirms the batch boundary.

Do not start descriptor transfer probes until foundation introspection passes on
both native macOS hosts. Once foundation is clean, implement header COPY_SEND
before descriptor COPY_SEND so rmxOS has a simple baseline for source-side uref
behavior.
