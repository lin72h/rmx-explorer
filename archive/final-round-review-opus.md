# Final Round Review: nx-v64z Oracle Stage 1-2

Reviewer: Opus agent
Date: 2026-05-12

---

## Findings

### 1. [minor] final-preimplementation-plan.md:192-253

The schema example truncates the `environment` object to only Zig fields. The
implementation agent building `nx_env.c` needs the full field list.

Why it matters: The comprehensive plan (lines 256-276) has the full environment
field list, but an implementation agent given only the pre-implementation plan
may emit an incomplete environment object.

Recommended change: Add a one-line reference: "For the complete `environment`
field list, see `comprehensive-nx-v64z-macos-oracle-plan.md` section
'Environment Capture'." Or inline the full environment object in the schema
example.

### 2. [minor] final-preimplementation-plan.md:111-133

`run_all.sh` must create a `<date>-<macos-version>-<darwin-version>` result
directory, but the plan doesn't specify how it discovers the macOS version and
Darwin version. This is what `collect_env.sh` produces.

Why it matters: The implementation agent needs to know whether `run_all.sh`
calls `collect_env.sh` first and parses its output, or discovers the version
independently.

Recommended change: Add: "`run_all.sh` calls `collect_env.sh` first to obtain
the macOS version and Darwin version for directory naming. The environment JSON
is written as the first file in the result directory."

### 3. [minor] final-preimplementation-plan.md:129-133

`validate_json.sh` is described as "lightweight shell check" but the schema has
deeply nested objects (`message.remote_port.disposition`,
`right_deltas[].entry_refs_before`). A pure-shell JSON validator would be
fragile.

Why it matters: If the implementation agent writes a shell validator that only
checks field presence with `grep`, it will silently accept malformed JSON.

Recommended change: Specify the tool dependency: "Uses `python3 -m json.tool`
for syntax validation and a small Python or `jq` script for field-presence
checks. If neither `python3` nor `jq` is available, emit a warning and skip
validation rather than silently accepting." Both `python3` and `jq` are
available on stock macOS.

### 4. [minor] final-preimplementation-plan.md:136-163

The common C helpers section doesn't specify the output contract. The
comprehensive plan says probes emit "one JSON file and one JSON object to
stdout." Stage 2 helpers need to know this from the start.

Why it matters: If `nx_result_emit()` writes to a file only, the harness
can't capture output from stdout. If it writes to stdout only, the harness
must redirect to a file.

Recommended change: Add: "Each probe writes its result JSON to stdout as a
single line. The harness captures stdout to a file in the result directory.
Diagnostic/error output goes to stderr."

### 5. [minor] final-preimplementation-plan.md:117-120

`sign_probe.sh` says "records signing success/failure" but doesn't specify
the recording format.

Why it matters: The implementation agent needs to know whether signing status
is a return code, a JSON field, or a log line.

Recommended change: Add: "`sign_probe.sh <binary>` returns 0 on success, 1 on
failure, and prints `signed: <path>` or `sign_failed: <path>` to stdout. The
harness records the signing outcome in the environment object's `ad_hoc_signed`
field."

### 6. [minor] final-preimplementation-plan.md:67-87

No `.gitkeep` or `.gitignore` guidance for empty directories. Git does not
track empty directories, so `results/mx-x64z/`, `results/mx-a64z/`,
`findings/nx-v64z/`, and `manifests/` will not exist after clone.

Why it matters: `run_all.sh` will fail with "directory not found" on first
clone if it doesn't `mkdir -p` before writing results.

Recommended change: Either add `.gitkeep` files in the Stage 1 layout, or
specify that `run_all.sh` creates result directories on demand with `mkdir -p`.
The second option is simpler.

### 7. [info] final-preimplementation-plan.md:156-160

`nx_json.c` must handle JSON string escaping (backslash, double-quote,
control characters). Dependency-free C JSON emitters commonly get this wrong.

Recommended note for implementation: At minimum, escape `\`, `"`, `\n`, `\t`,
and `\r`. Use `\uXXXX` for other control characters below 0x20. Test with a
sysctl value that contains spaces or special characters.

### 8. [info] final-preimplementation-plan.md:186-190

Symbolic port labels are specified but the plan doesn't define whether labels
are freeform or from a recommended vocabulary.

Recommended note for implementation: Use descriptive freeform strings like
`"service_port"`, `"cargo_port"`, `"task_port"`, `"reply_port"`,
`"bootstrap_port"`, `"delivered_port"`. Labels must be consistent within a
single probe result but are not required to match across different probes.

### 9. [info] Stage 2 smoke probe

The plan says "a trivial schema-emitting smoke probe if needed" but doesn't
specify whether this should be a real compiled binary in the Makefile or just a
source demonstration.

Recommended note for implementation: Create
`macos-validation/probes/foundation/smoke.c` as a real binary that allocates
one port, inspects it, destroys it, and emits a complete `nx-v64z.macos-oracle.v1`
JSON result. Include it in the Makefile as the first build/run target. This
proves the full pipeline: compile, sign, run, capture JSON, validate schema.

### 10. [info] Compiler flags

The comprehensive plan specifies `clang -Wall -Wextra -O0 -g` for probes. The
pre-implementation plan doesn't repeat this.

Recommended note for implementation: Use `CFLAGS ?= -Wall -Wextra -O0 -g` in
the Makefile so probes build with debug info by default and the flags are
overridable.

---

## Open Questions

None blocking Stage 1-2.

All 8 remaining decisions listed in `final-preimplementation-plan.md` lines
342-352 affect Stage 3+ only.

---

## Go/No-Go

**Go for Stage 1-2.**

The plan is concrete enough to implement. The findings above are minor
clarifications that an implementation agent can resolve inline — none require
design changes or parent decisions.

---

## Implementation Notes

1. Start with `macos-validation/Makefile` and `harness/collect_env.sh` as the
   first two files. `collect_env.sh` exercises the most host-specific behavior
   and will surface any stock macOS surprises early.

2. For `nx_json.c`, keep the implementation under 200 lines. Only emit JSON —
   do not parse it. The emitter needs: `nx_json_begin_object`,
   `nx_json_end_object`, `nx_json_begin_array`, `nx_json_end_array`,
   `nx_json_key_string`, `nx_json_key_int`, `nx_json_key_null`,
   `nx_json_key_bool`, and a string-escaping helper. Write to a `FILE *`.

3. For `nx_mach_utils.c`, the most important function is a baseline
   snapshot/compare: call `mach_port_names()` before and after the probe body,
   diff the name sets, and emit `cleanup.returned_to_baseline` based on the
   delta. This is the single most reused pattern across all future probes.

4. The Stage 2 smoke probe (`foundation/smoke.c`) should exercise every common
   helper at least once so that build/link errors surface before Stage 3.

5. `run_all.sh` should call `collect_env.sh` first, parse the macOS version
   from its output, then create the result directory and proceed. Environment
   JSON becomes the first file in every result directory.

6. For `validate_json.sh`, use `python3 -c "import json, sys; json.load(sys.stdin)"` 
   for syntax validation, then check required top-level keys with a
   second `python3` one-liner. This avoids requiring `jq` while working on
   every stock macOS install.

7. The Makefile should have a `PROBES` variable listing discovered `.c` files
   under `probes/foundation/`, `probes/m1/`, `probes/m2/`. Use a wildcard
   or explicit list — explicit is safer for Stage 1-2 since only the smoke
   probe exists.

8. Remember to add the authority note from the user's edit to
   `test-migration-map.md`: this file is a coverage map, not the
   implementation order. Follow `comprehensive-nx-v64z-macos-oracle-plan.md`
   for staging.

9. The coordination plan is correct: Opus continues the M2.1 batch 22 rerun
   independently. These tracks do not block each other. Any new Opus batch 22
   evidence feeds into Stage 3+ before macOS host collection.
