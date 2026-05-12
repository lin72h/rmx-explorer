# GPT Integration Review: OPUS Stage 1-2 Oracle Implementation

Date: 2026-05-12
Reviewer: GPT oracle planning lane

## Verdict

Accept the OPUS Stage 1-2 implementation as the working baseline for the
`macos-validation/` oracle package.

It is not yet macOS semantic evidence. It is a harness/common-helper baseline
that must be smoke-tested on both real macOS runners before Stage 3 probes are
trusted.

Local verification on this FreeBSD/rx development host:

```sh
cd macos-validation
make clean && make
make run AGENT=rx
make validate-json
```

Result:

```text
Summary: 1 probes, 0 pass, 0 fail, 1 skip
Validated: 1 files, 1 pass, 0 fail
```

The skip is expected on non-macOS because Mach APIs are not observable here.

## Findings

1. [severity: major] `macos-validation/probes/foundation/smoke.c:80`

   `smoke.c` does not fail if `mach_port_type()` or
   `mach_port_get_refs()` fails after `mach_port_allocate()` succeeds.
   It records those return values, but the status logic only checks allocation,
   destroy, and baseline cleanup.

   Why it matters: on a real Mac, the first smoke PASS must prove the common
   introspection helpers work. A PASS with failed type/ref inspection would
   make Stage 3 probes look trustworthy when the inspection floor is broken.

   Recommended change: on macOS, treat non-success `kr_type` or `kr_refs` as
   `probe_failure` before accepting `macos_foundation_smoke` as pass.

2. [severity: major] `macos-validation/harness/run_all.sh:196`

   The harness classifies a probe only from JSON `status` and ignores
   non-zero process exit status if the JSON says `pass` or `skip`.

   Why it matters: the probe contract says pass and skip return 0. A probe that
   emits partial/stale JSON and exits non-zero should be counted as failure, not
   pass/skip.

   Recommended change: if `probe_rc != 0`, count the probe as failed regardless
   of JSON status, while preserving the result JSON and stderr log for
   debugging.

3. [severity: major] `macos-validation/harness/validate_json.sh:119`

   The validator only checks that `returns` and `right_deltas` are arrays. It
   does not validate typed entries such as `{call, returned, raw, errno}` or
   `{operation, port_name, right_type, before_urefs, after_urefs,
   entry_refs_before, entry_refs_after, expected}`.

   Why it matters: Stage 3+ comparison will depend on mechanical fields inside
   those arrays. A malformed M1/M2 probe could pass validation and later fail in
   the comparison layer.

   Recommended change: before adding Stage 3 probes, extend
   `validate_json.sh` to validate entry shapes for `returns`, `right_deltas`,
   `message.remote_port`, `message.local_port`, `message.header_rights`, and
   `message.descriptors`.

4. [severity: minor] `macos-validation/probes/common/nx_mach_utils.c:138`

   `nx_port_type_str()` returns `MACH_PORT_TYPE_SEND_RECEIVE` whenever those
   two bits are present, even if other known or unknown bits are also present.

   Why it matters: the plan requires unknown modern `mach_port_type()` bits to
   be preserved as raw hex. The current formatter can hide extra bits on modern
   macOS.

   Recommended change: either use exact equality for named composite strings or
   emit both decoded labels and raw hex in Stage 3+ result fields.

5. [severity: minor] `macos-validation/harness/run_all.sh:72`

   `run_all.sh` allows `--agent mx-x64z` and `--agent mx-a64z` on non-Darwin
   hosts.

   Why it matters: local development can accidentally create FreeBSD/rx results
   under mx-* runner names. The environment JSON still exposes the true OS, but
   this can confuse result handoff.

   Recommended change: use `AGENT=rx` for local non-macOS development. Reserve
   `mx-x64z` and `mx-a64z` for native macOS runs, or add an explicit override
   gate for mx-* on non-Darwin.

6. [severity: info] `opus-stage12-review-and-handoff.md:274`

   The OPUS handoff's "Known Limitations" section is stale. The current code
   now includes per-binary signing metadata, `cpu_features`, `raw_sysctls`,
   `result_dir_name`, and a name/type baseline comparison rather than
   count-only comparison.

   Recommended change: treat this GPT integration review as superseding that
   section where the documents disagree.

## Integration Notes

- `.gitignore` excludes `.build/` and run result directories. Generated files
  are acceptable in the local workspace but should not be treated as source.
- Before copying this tree outside git, run `make clean` under
  `macos-validation/` and avoid packaging local `results/rx/` runs as oracle
  evidence.
- The root `.gitignore` is useful and should stay.
- The `.gitkeep` files are harmless, even though the final plan preferred
  `mkdir -p` on demand.
- The Makefile currently uses `CFLAGS = -Wall -Wextra -O0 -g`, which avoids
  FreeBSD make's built-in `CFLAGS` overriding the debug-friendly default.

## What To Send To The Oracle Agent

Use `macos-validation/` as the Stage 1-2 package baseline.

First task on real macOS runners:

```sh
cd macos-validation
make clean
make
make run AGENT=mx-x64z   # Intel Mac only
make run AGENT=mx-a64z   # Apple Silicon Mac only
make validate-json
```

The oracle agent should return these files for each runner:

- `results/<agent>/<date>-<macos-version>-<darwin-version>/environment.json`
- `results/<agent>/<date>-<macos-version>-<darwin-version>/foundation_smoke.json`
- stderr logs from the same result directory

Expected first macOS result:

- `macos_foundation_smoke` should be `pass`
- `semantic_class` should be `exact_contract`
- `mach_port_allocate`, `mach_port_type`, `mach_port_get_refs`, and
  `mach_port_destroy` should all return success
- cleanup should return to baseline
- signing should be `signed` for the smoke binary

## Stage 3 Continuation Advice

Do not jump straight to M2 descriptor transfer. First harden the foundation
floor:

1. Fix the smoke/harness/validator findings above.
2. Add `foundation/port_names.c`.
3. Add `foundation/port_type.c`.
4. Add `foundation/port_get_refs.c`.

For every new probe:

- follow the one-JSON-object-to-stdout contract
- keep diagnostics on stderr
- use symbolic port labels for comparison fields
- include exact return codes in `returns`
- preserve raw hex for unknown Mach type bits
- clean up to the baseline and report cleanup status
- add explicit Makefile rules and add the probe to `PROBES`

## Stage 4-5 Priorities

After Stage 3 is clean on both mx hosts, implement M1/M2 in this order:

1. `m1/header_copy_send_accounting.c`
2. `m1/header_move_send_accounting.c`
3. `m2/descriptor_copy_send.c`
4. `m2/descriptor_move_send.c`
5. `m2/send_once_descriptor.c`
6. `m2/double_move_send_descriptor.c`
7. negative/error probes

For fork/spawn/process probes, use watchdogs, `waitpid()`, and an explicit
rendezvous channel that is orthogonal to the Mach path being tested.

## Collaboration Rule

OPUS should stop implementing code in this repository. Future OPUS interaction
should be review, comparison against NextBSD batch evidence, and written
findings only.

The oracle agent owns macOS probe implementation and runner collection. The
parent lane owns final semantic interpretation and rx/rmxOS implementation
decisions.
