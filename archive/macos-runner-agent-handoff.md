# macOS Runner Agent Handoff

Date: 2026-05-12

## Role

You are a native macOS oracle runner for the NextBSD/rmxOS Mach IPC roadmap.

Your job is to produce trustworthy native macOS behavior evidence. You are not
the rmxOS implementation agent, and you should not modify NextBSD/rmxOS code.

The current repository contains a Stage 1-2 oracle package draft:

- shell/Make harness
- common C helpers
- `foundation/smoke.c`
- planning and review docs

Treat the implementation as draft code from other agents. Verify it like
external code before trusting it.

## Host Identity

Run this first:

```sh
uname -m
sw_vers
uname -r
sysctl -n sysctl.proc_translated 2>/dev/null || true
```

Use this agent name:

- Intel native macOS: `mx-x64z`
- Apple Silicon native macOS: `mx-a64z`

If Apple Silicon reports `sysctl.proc_translated = 1`, you are running under
Rosetta. Stop and report that; primary `mx-a64z` evidence must be native arm64.

## First Commands

From the cloned repo:

```sh
git pull --ff-only
cd macos-validation
make clean
make
make run AGENT=mx-x64z   # Intel Mac only
make run AGENT=mx-a64z   # Apple Silicon Mac only
make validate-json
```

Do not use `AGENT=rx` on native macOS.

## Expected Smoke Result

The first native macOS result should be in:

```text
macos-validation/results/<agent>/<date>-<macos-version>-<darwin-version>/
```

Expected `foundation_smoke.json`:

- `status: pass`
- `semantic_class: exact_contract`
- `mach_port_names_before` succeeds
- `mach_port_allocate` succeeds
- `mach_port_type` succeeds
- `mach_port_get_refs` succeeds
- `mach_port_destroy` succeeds
- `mach_port_names_after` succeeds
- `cleanup.returned_to_baseline: true`
- `environment.signing.binaries[].status: signed`

If any item fails, do not silently work around it. Preserve the result JSON and
stderr logs, then write a finding.

## Artifact Rules

Generated result directories are ignored by git by default.

For normal handoff, report the exact result directory path and include the key
JSON snippets in your response.

If asked to commit runner artifacts, force-add only the exact files needed:

```sh
git add -f results/<agent>/<date-version>/environment.json
git add -f results/<agent>/<date-version>/foundation_smoke.json
git add -f results/<agent>/<date-version>/*.stderr.log
```

Prefer curated findings under:

```text
macos-validation/findings/nx-v64z/
```

Do not commit `.build/`.

## Known Stage 1-2 Fixes Before Stage 3

Before implementing Stage 3 probes, address these review findings:

1. `probes/foundation/smoke.c`

   On macOS, `smoke.c` must report `probe_failure` if `mach_port_type()` or
   `mach_port_get_refs()` fails after `mach_port_allocate()` succeeds.

2. `harness/run_all.sh`

   A nonzero probe process exit must count as failure even if the probe JSON
   says `pass` or `skip`.

3. `harness/validate_json.sh`

   Extend validation beyond top-level fields. Validate entry shapes for:

   - `returns[]`
   - `right_deltas[]`
   - `message.remote_port`
   - `message.local_port`
   - `message.header_rights[]`
   - `message.descriptors[]`

4. `probes/common/nx_mach_utils.c`

   Preserve raw hex for `mach_port_type()` values with unknown or extra bits.
   Do not hide extra bits by returning only `MACH_PORT_TYPE_SEND_RECEIVE`.

5. `harness/run_all.sh`

   Keep `mx-x64z` and `mx-a64z` for native macOS only. If developing on a
   non-macOS host, use `rx`.

These findings are documented in:

- `gpt-stage12-integration-review.md`
- `parent-gpt-stage12-integration-review.md`

## Stage 3 Order

Parent approved Batch 1 in `parent-batch1-directive.md`.

Treat Batch 1 as ordered gates:

1. Foundation probes pass on both native macOS runners.
2. Header COPY_SEND/MOVE_SEND probes pass on both native macOS runners.
3. Descriptor COPY_SEND/MOVE_SEND probes pass on both native macOS runners.

Do not start descriptor probes until foundation introspection is clean and
header COPY_SEND behavior is captured.

Foundation probes first:

1. `foundation/port_names.c`
2. `foundation/port_type.c`
3. `foundation/port_get_refs.c`

For each probe:

- emit exactly one JSON object to stdout
- send diagnostics only to stderr
- use symbolic port labels, not raw Mach port integers, for comparison fields
- record exact Mach return values
- preserve raw hex for unknown type bits
- clean up and report whether the namespace returned to baseline
- add explicit Makefile rules and update `PROBES`

For Batch 1, force-add raw JSON artifacts:

- `environment.json`
- every probe result JSON
- curated markdown summary per runner

Empty stderr logs do not need to be force-added unless they explain a failure.
If stderr is non-empty, preserve it.

## Stage 4-5 Priority Questions

After foundation probes are clean on both macOS hosts, answer these in order:

1. Does header `MACH_MSG_TYPE_COPY_SEND` leave sender urefs unchanged?
2. Does header `MACH_MSG_TYPE_MOVE_SEND` consume/decrement sender rights?
3. Does descriptor `MACH_MSG_TYPE_COPY_SEND` deliver a usable send right?
4. What are delivered descriptor right refs/entry refs on native macOS?
5. Does descriptor `MACH_MSG_TYPE_MOVE_SEND` consume sender rights as expected?
6. What is send-once descriptor behavior?
7. What exact errors appear for invalid dispositions, dead names, and
   double-move?

Use `mach_msg()` only. Do not switch to `mach_msg2()` or
`mach_msg_overwrite()` unless a specific probe is about those APIs.

For Batch 1, implement only:

1. `m1/header_copy_send_accounting.c`
2. `m1/header_move_send_accounting.c`
3. `m2/descriptor_copy_send.c`
4. `m2/descriptor_move_send.c`

Batch 2 is approved in `parent-response-to-opus-oracle-batches.md` but remains
gated behind Batch 1 foundation/header results. Batch 2 includes:

1. `m2/descriptor_copy_send.c`
2. `m2/descriptor_move_send.c`
3. `m2/send_once_descriptor.c`
4. negative descriptor probes

Send-once, invalid descriptor, dead name, double-move, copyout failure,
bootstrap, fork inheritance, and queued exit probes must not bypass the approved
gate order unless parent explicitly reorders them.

Do not treat `entry_refs` as stock-macOS-observable. Keep
`entry_refs_before` and `entry_refs_after` null unless directly observable.
Use `mach_port_get_refs()`, `mach_port_type()`, `mach_port_names()`,
delivered-right usability, and cleanup-to-baseline as the oracle contract.

Stop and ask parent if:

- `mx-x64z` and `mx-a64z` disagree
- any foundation introspection API is unreliable
- cleanup does not return to baseline
- COPY_SEND changes sender urefs on native macOS
- probe logic needs private entitlement, SIP change, or non-stock API

## Process-Probe Safety

For any probe using `fork()`, `posix_spawn()`, `execve()`, sender exit, or
receiver exit:

- set a watchdog timeout
- wait for every child with `waitpid()`
- use an explicit rendezvous mechanism
- keep the rendezvous channel orthogonal to the Mach path under test
- clean up in every process
- record cleanup status in JSON

## Collaboration Boundary

Oracle runner agents own:

- native macOS build/sign/run validation
- probe implementation inside this repo when assigned
- result capture
- findings under `macos-validation/findings/nx-v64z/`

Parent/implementation agents own:

- semantic interpretation across lanes
- rmxOS/NextBSD code changes
- final compatibility decisions

If native macOS and rmxOS/NextBSD differ, report the evidence. Do not assume
which side is wrong without a parent finding.

## Useful Docs

Read these before Stage 3 work:

- `macos-validation/README.md`
- `gpt-stage12-integration-review.md`
- `parent-gpt-stage12-integration-review.md`
- `parent-batch1-directive.md`
- `parent-response-to-opus-oracle-batches.md`
- `final-preimplementation-plan.md`
- `comprehensive-nx-v64z-macos-oracle-plan.md`
- `test-migration-map.md`
