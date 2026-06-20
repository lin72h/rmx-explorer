# Opus Lane Review: Stage 1-2 Completion and Stage 3+ Handoff

Date: 2026-05-12
Author: Opus implementation lane
For: Oracle agent (nx-v64z) and parent

Integration note: `gpt-stage12-integration-review.md` supersedes this handoff
where the two documents disagree. In particular, the "Known Limitations" section
below reflects an earlier implementation state and is no longer fully accurate.

## What Was Delivered

Stage 1-2 of the oracle package is implemented and verified end-to-end on
FreeBSD 15.0. All files are in `macos-validation/`. The pipeline builds, runs,
and produces valid `nx-v64z.macos-oracle.v1` JSON.

### Stage 1: Skeleton and Harness

| File | Status | Notes |
| --- | --- | --- |
| `Makefile` | done | BSD make compatible, explicit rules (no GNU patsubst) |
| `harness/collect_env.sh` | done | awk-based json_escape for BSD/macOS portability |
| `harness/run_all.sh` | done | --agent, --list, skip-aware counting |
| `harness/sign_probe.sh` | done | graceful fallback when codesign unavailable |
| `harness/validate_json.sh` | done | python3 schema checks, all required fields |
| `README.md` | done | quick start, make targets, role definitions |

### Stage 2: Common C Helpers and Smoke Probe

| File | Status | Notes |
| --- | --- | --- |
| `probes/common/nx_json.h/c` | done | zero-dependency, FILE*-based, proper escaping |
| `probes/common/nx_result.h/c` | done | schema constant, status/class enums, all emitters |
| `probes/common/nx_env.h/c` | done | popen-based environment capture, macOS/non-macOS |
| `probes/common/nx_mach_utils.h/c` | done | baseline snapshot, string formatters, __APPLE__ stubs |
| `probes/foundation/smoke.c` | done | exercises all helpers, full schema JSON output |

### Verified Pipeline

```
make clean && make         # builds on FreeBSD and macOS
harness/run_all.sh --agent mx-x64z
harness/validate_json.sh results/mx-x64z/.../foundation_smoke.json
```

On FreeBSD: status=skip, semantic_class=not_observable, exit code 0.
On macOS (expected): status=pass, real Mach port allocation/inspection data.

## Design Decisions Made During Implementation

These are locked in. The oracle agent should preserve them unless the parent
overrides.

1. **BSD make only.** No GNU make extensions. The Makefile uses explicit rules
   for each probe, not pattern substitution. When adding a new probe, add its
   object and binary rules explicitly.

2. **`__APPLE__` conditional compilation.** All Mach API calls are wrapped in
   `#ifdef __APPLE__`. Non-macOS builds get stub types from `nx_mach_utils.h`.
   This means the oracle code compiles and runs on FreeBSD for development, but
   real Mach data only comes from macOS hosts.

3. **awk for json_escape.** The original sed-based `json_escape()` in
   `collect_env.sh` broke on BSD sed (cannot handle literal newlines in
   substitute patterns). Replaced with awk. Do not revert to sed.

4. **Skip is not failure.** Probes return exit code 0 for both `pass` and
   `skip`. The harness parses the JSON status field for classification, not the
   exit code.

5. **Static buffers in string formatters.** `nx_kern_return_str()`,
   `nx_msg_return_str()`, and `nx_port_type_str()` use static buffers for the
   fallback hex format. This is fine for single-threaded probes but means the
   returned pointer is invalidated by the next call. Do not use them in
   multi-threaded contexts.

6. **Baseline compare is count-only.** `nx_baseline_compare()` currently only
   compares name counts (before vs after). A future enhancement could diff the
   actual name sets to identify leaked ports by name. This is sufficient for
   Stage 1-5.

## Technical Advice for Stage 3+ Probes

### Foundation Probes (Stage 3)

These are straightforward single-process probes. Use `smoke.c` as the template.

**`foundation/port_names.c`**: Call `mach_port_names()`, verify the returned
arrays are non-empty, check that `mach_task_self()` appears in the name list
with type `MACH_PORT_TYPE_SEND_RECEIVE`. Allocate a port, verify it appears,
destroy it, verify it disappears.

**`foundation/port_get_refs.c`**: Allocate a receive right. Check
`mach_port_get_refs(MACH_PORT_RIGHT_RECEIVE)` returns 1. Insert a send right
with `mach_port_insert_right()`. Check send refs = 1. Call
`mach_port_mod_refs()` to add another send ref. Verify send refs = 2. Clean up.

**`foundation/port_type.c`**: Allocate receive right, verify type is
`MACH_PORT_TYPE_RECEIVE`. Insert send right, verify type becomes
`MACH_PORT_TYPE_SEND_RECEIVE`. Allocate a port set, verify
`MACH_PORT_TYPE_PORT_SET`. Destroy a send-once right, verify
`MACH_PORT_TYPE_DEAD_NAME` appears when appropriate.

### M1 Probes (Stage 4) — Process Orchestration

This is where it gets harder. Every M1 probe that uses `fork()` or
`posix_spawn()` needs:

1. **`alarm(5)` watchdog** — prevents zombie hangs if IPC deadlocks.
2. **`waitpid()` on all children** — with timeout, not blocking forever.
3. **Rendezvous orthogonal to the IPC channel** — use a Unix pipe or signal for
   synchronization, not the Mach message path being tested. If you use Mach
   messages for rendezvous you cannot distinguish IPC bugs from rendezvous bugs.
4. **Cleanup in both parent and child** — the child must destroy any ports it
   allocated before `_exit()`. The parent must destroy any ports it holds after
   `waitpid()` returns.

**`m1/fork_port_inheritance.c`**: After `fork()`, the child inherits port
rights. Verify the child can see the parent's receive right name in its
namespace (it will have the same name but NOT a usable right — only send rights
are inherited as usable). The child should inspect with `mach_port_type()`.

**`m1/bootstrap_special_port.c`**: This is privilege-sensitive on stock macOS.
Get the current bootstrap port, attempt to set a new one, and restore the
original. On macOS this may fail with `KERN_NO_ACCESS` — that's a valid
`privilege_sensitive` result, not a probe failure.

**`m1/header_copy_send_accounting.c`**: This is the key uref accounting test.
Create a send right, record urefs. Send it via `MACH_MSG_TYPE_COPY_SEND` in
the header. Record urefs after. They must be unchanged. Receive the message.
The received port must be a valid send right. Our NextBSD result: sender urefs
stay at 2 (entry_refs=2), matching what we expect from macOS.

### M2 Probes (Stage 5) — Cross-Task Descriptor Transfer

These are the highest-value probes. Each requires two processes: a sender and
a receiver.

**`m2/descriptor_copy_send.c`**: This is the most important probe. It must
verify:

- Sender creates a send right, records `entry_refs` and urefs.
- Sender sends a message with a `MACH_MSG_TYPE_COPY_SEND` port descriptor.
- After send: sender's urefs must be UNCHANGED. This is the critical assertion.
- Receiver receives the message, extracts the descriptor port.
- Receiver's delivered port has type `MACH_PORT_TYPE_SEND` and is usable.
- Receiver must call `mach_port_deallocate()` or `mach_port_destroy()` on the
  delivered right. A single `deallocate` may not be enough if `entry_refs > 1`.

Our NextBSD finding: the delivered send right has `entry_refs=2`. We need the
oracle to confirm whether macOS also creates `entry_refs=2` for a received
COPY_SEND descriptor right, or whether this is NextBSD-specific.

**`m2/descriptor_move_send.c`**: Similar to COPY_SEND but the sender's right
must be consumed (urefs decremented or right removed from namespace) after the
send.

**Negative probes**: Test invalid dispositions, dead names, and double-move.
These should return specific `kern_return_t` values. Record the exact return
codes — they are the oracle evidence.

## What We Need From the Oracle

These are the specific questions the Opus lane needs answered by running probes
on real macOS. Prioritize these.

### Priority 1: COPY_SEND Descriptor Delivery (Stage 5)

**Question**: When a COPY_SEND port descriptor is delivered cross-task on
macOS, what is `entry_refs` on the received send right?

Our NextBSD result is `entry_refs=2`, type `MACH_PORT_TYPE_SEND` (0x10000).
We need to know if macOS matches. If it does, this is universal Mach behavior.
If not, we have a divergence to investigate.

**Why it matters**: This determines whether `mach_port_deallocate()` (removes 1
uref) is sufficient to clean up a received descriptor right, or whether
`mach_port_destroy()` (removes the name entirely) is needed.

### Priority 2: COPY_SEND Source Uref Stability (Stage 4)

**Question**: Does header-level COPY_SEND on macOS leave the sender's urefs
unchanged?

Our NextBSD batch 21 proves it does. We expect macOS to match. Confirmation
closes this topic for both implementation lanes.

### Priority 3: task_self_trap Combined Right

**Question**: Does `mach_task_self()` on macOS return a `MACH_PORT_TYPE_SEND_RECEIVE`
right with `entry_refs=2`?

Our NextBSD result shows this. The foundation probes should capture it as a
side-effect when inspecting `mach_task_self()` in `port_names.c` or
`port_type.c`.

### Priority 4: Bootstrap Port Mutation

**Question**: Does stock macOS permit `task_set_special_port()` on the
bootstrap port, or does it return `KERN_NO_ACCESS`?

This determines the semantic class for `m1/bootstrap_special_port.c`. Either
`exact_contract` (if it works) or `privilege_sensitive` (if blocked).

### Priority 5: MOVE_SEND Consumption Timing

**Question**: After `mach_msg()` with `MACH_MSG_TYPE_MOVE_SEND` in the header,
is the sender's send right immediately consumed (name removed from namespace)
or only decremented?

We haven't reached this test on NextBSD yet (planned B23+). The oracle running
it first on macOS establishes the baseline we'll match.

## Collaboration Protocol

### How Results Flow

```
Oracle agent writes probe  →  runs on mx-x64z / mx-a64z
                           →  captures JSON in results/<agent>/<date>/
                           →  commits results to wip-gpt-oracle repo

Opus lane reads results    →  compares against NextBSD batch findings
                           →  writes findings in findings/nx-v64z/
                           →  or adjusts NextBSD implementation to match
```

### What the Oracle Agent Should NOT Do

- Do not modify our NextBSD code in `wip-mach-opus/` or `wip-mach/`.
- Do not interpret NextBSD divergences as bugs without discussion. A difference
  might be intentional, or it might indicate a real issue — flag it and we'll
  resolve it together.
- Do not attempt to run oracle probes inside bhyve. The oracle runs on native
  macOS only.
- Do not require Zig for C-only probes. The Zig fields exist in the schema for
  future use but must remain null/false until Zig probes are actually written.

### What We Commit To

- We will read oracle results and compare them against our NextBSD batch logs.
- We will report divergences as findings in `findings/nx-v64z/`.
- We will update our NextBSD implementation if the oracle reveals our semantics
  diverge from macOS.
- We will provide batch evidence (serial logs, probe source) when the oracle
  needs to know what NextBSD does for a given operation.

## Recommended Stage 3 Implementation Order

1. `foundation/port_names.c` — simplest, validates mach_port_names() works
2. `foundation/port_type.c` — validates type inspection on all right classes
3. `foundation/port_get_refs.c` — validates uref accounting basics

These three are independent of each other and can be implemented in any order,
but `port_names` is the smallest and validates the most basic API.

For each probe:
- Copy `smoke.c` as template
- Replace the Mach API calls inside `#ifdef __APPLE__`
- Update the test_id, cross_reference, and notes
- Add the probe to the Makefile (explicit rules, following the smoke pattern)
- Build with `make`, run with `run_all.sh`, validate with `validate_json.sh`

## Makefile Extension Pattern

When adding `foundation/port_names.c`:

```make
# After the existing smoke rules, add:

$(BIN_DIR)/foundation/port_names: probes/foundation/port_names.c $(COMMON_OBJS)
	$(CC) $(CFLAGS) -Iprobes/common -o $@ $< $(COMMON_OBJS)
```

And add `foundation/port_names` to the `PROBES` list. The harness discovery
in `run_all.sh` scans `.build/bin/{foundation,m1,m2}/` automatically.

## Known Limitations

1. **No per-binary signing metadata in probe JSON.** The plan calls for
   `environment.signing.binaries[]` with `{path, status, return_code, output}`
   per binary. Currently `nx_env.c` emits `ad_hoc_signed: true` and
   `hardened_runtime: false` as constants. Full per-binary signing status
   should be captured by a future enhancement to `collect_env.sh` or a new
   helper that `run_all.sh` invokes after signing.

2. **No `cpu_features` or `raw_sysctls` in environment.** The comprehensive
   plan lists these as optional sub-objects. They are not emitted by
   `nx_env.c` currently. The oracle agent should add them when needed for
   Apple Silicon differentiation.

3. **`result_dir_name` not in probe JSON.** The harness captures it in
   `environment.json` via `collect_env.sh`, but the C-emitted environment in
   each probe JSON does not include it. This is fine — the harness creates the
   directory before probes run.

4. **Baseline compare is count-only.** As noted above, a name-set diff would
   give more diagnostic power. Not needed for Stage 3-5 correctness.
