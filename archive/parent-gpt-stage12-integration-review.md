# Parent GPT Stage 1-2 Integration Review and Oracle-Agent Advice

Date: 2026-05-12
Reviewer: GPT oracle planning lane

## Context

Parent GPT also implemented Stage 1-2 code directly in this repository. That was
outside the intended division of labor.

Use the same containment strategy as for the OPUS implementation:

- treat the code as third-party draft work
- review it against the agreed plan
- keep the pieces that are correct
- fix the contract issues before relying on native macOS results
- do not let Parent GPT continue implementing oracle probe code in this repo

## Verdict

Accept with edits.

The current `macos-validation/` implementation is a useful Stage 1-2 baseline
for harness, common helpers, and smoke-probe plumbing. It is not yet native
macOS behavioral evidence.

Local FreeBSD/rx verification:

```sh
cd macos-validation
make clean && make
make run AGENT=rx
make validate-json
```

Observed result:

```text
Summary: 1 probes, 0 pass, 0 fail, 1 skip
Validated: 1 files, 1 pass, 0 fail
```

The skip is expected on this host because Mach APIs are not observable here.

## What Is Acceptable

- `macos-validation/Makefile` builds the Stage 1-2 smoke pipeline with
  `-Wall -Wextra -O0 -g`.
- Build outputs stay under `.build/`.
- `collect_env.sh` emits the current environment floor, including non-macOS
  fallback result naming, signing placeholders, Apple-Silicon fields, and Zig
  metadata.
- `run_all.sh` creates dated result directories, captures signing status,
  embeds harness environment into probe JSON, and passes `NX_ORACLE_AGENT`.
- `validate_json.sh` uses `python3` and validates the top-level schema floor.
- `foundation/smoke.c` is a real C probe on macOS and correctly reports
  `skip` on FreeBSD/rx.
- `.gitignore` excludes `.build/` and generated dated result directories.

## Findings

1. [severity: major] `macos-validation/probes/foundation/smoke.c:80`

   `smoke.c` can report pass on macOS even if `mach_port_type()` or
   `mach_port_get_refs()` fails after `mach_port_allocate()` succeeds.

   Why it matters: Stage 3 depends on those introspection APIs. The first macOS
   smoke PASS must prove the inspection floor is working, not only that a port
   can be allocated and destroyed.

   Recommended change: on `__APPLE__`, if `kr_type != KERN_SUCCESS` or
   `kr_refs != KERN_SUCCESS`, set status to `probe_failure` and keep the exact
   return codes in `returns`.

2. [severity: major] `macos-validation/harness/run_all.sh:196`

   `run_all.sh` ignores a nonzero probe exit when JSON says `pass` or `skip`.

   Why it matters: the probe contract says pass and skip return 0. Nonzero
   process exit should always be a harness failure signal, even if a stale or
   partial JSON file says otherwise.

   Recommended change: after parsing JSON, if `probe_rc != 0`, count the probe
   as failure regardless of JSON status. Preserve the JSON and stderr log.

3. [severity: major] `macos-validation/harness/validate_json.sh:119`

   Validation currently checks only that `returns` and `right_deltas` are
   arrays, not that their entries have the required typed shape.

   Why it matters: M1/M2 comparison needs mechanical fields inside those arrays.
   A malformed probe could pass validation and later break comparison or hide a
   missing Mach return code.

   Recommended change: before Stage 3, validate each `returns[]` entry for
   `{call, returned, raw, errno}` and each `right_deltas[]` entry for
   `{operation, port_name, right_type, before_urefs, after_urefs,
   entry_refs_before, entry_refs_after, expected}`. Also validate
   `message.remote_port`, `message.local_port`, `message.header_rights`, and
   `message.descriptors` entry shapes.

4. [severity: minor] `macos-validation/probes/common/nx_mach_utils.c:138`

   `nx_port_type_str()` reports `MACH_PORT_TYPE_SEND_RECEIVE` when those bits
   are present, even if additional known or unknown bits are also present.

   Why it matters: the plan requires modern/unknown `mach_port_type()` bits to
   remain visible as raw hex. Current formatting can hide extra bits.

   Recommended change: use exact equality for named composite strings, or emit
   both decoded labels and raw hex for port types in Stage 3+ results.

5. [severity: minor] `macos-validation/harness/run_all.sh:72`

   The harness allows `--agent mx-x64z` and `--agent mx-a64z` on non-Darwin
   hosts.

   Why it matters: local development can accidentally write FreeBSD/rx evidence
   under macOS runner names. The environment JSON exposes the true OS, but the
   path can mislead later result consumers.

   Recommended change: use `AGENT=rx` for non-macOS development. Consider an
   explicit override before allowing mx-* agent names on non-Darwin hosts.

## Advice To The Oracle Agent

Your role is oracle evidence, not rmxOS implementation.

Treat the current Stage 1-2 code as a draft baseline from another agent. Audit
it, apply the findings above, then validate on real macOS.

First native macOS task:

```sh
cd macos-validation
make clean
make
make run AGENT=mx-x64z   # Intel Mac only
make run AGENT=mx-a64z   # Apple Silicon Mac only
make validate-json
```

Return these artifacts for each host:

- `results/<agent>/<date>-<macos-version>-<darwin-version>/environment.json`
- `results/<agent>/<date>-<macos-version>-<darwin-version>/foundation_smoke.json`
- `results/<agent>/<date>-<macos-version>-<darwin-version>/*.stderr.log`

The first macOS smoke result should show:

- `status: pass`
- `semantic_class: exact_contract`
- successful `mach_port_names_before`
- successful `mach_port_allocate`
- successful `mach_port_type`
- successful `mach_port_get_refs`
- successful `mach_port_destroy`
- successful `mach_port_names_after`
- `cleanup.returned_to_baseline: true`
- signing record status `signed`

If any of those fail, do not silently work around it. Preserve the JSON and
write a finding.

## Next Work After Stage 1-2 Fixes

Do not jump straight to descriptor transfer. First prove the foundation floor on
both macOS runners:

1. `foundation/port_names.c`
2. `foundation/port_type.c`
3. `foundation/port_get_refs.c`

Then move to the currently important behavior questions:

1. `m1/header_copy_send_accounting.c`
2. `m1/header_move_send_accounting.c`
3. `m2/descriptor_copy_send.c`
4. `m2/descriptor_move_send.c`
5. `m2/send_once_descriptor.c`
6. `m2/double_move_send_descriptor.c`
7. negative descriptor/failure probes

For fork/spawn/process probes, enforce watchdogs, `waitpid()`, cleanup in all
processes, and a rendezvous channel orthogonal to the Mach path under test.

## Collaboration Rule

Parent GPT should stop implementing code in `wip-gpt-oracle`.

Future Parent GPT work should be:

- review
- semantic interpretation
- comparison against rmxOS/NextBSD behavior
- written findings and directives

The oracle agent owns macOS probe implementation and runner collection. The
implementation lanes own rmxOS/NextBSD changes after oracle evidence exists.
