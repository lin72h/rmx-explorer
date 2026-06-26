# op-147m — activation record (Explorer ack)

Date: 2026-06-25. Role: Explorer (`rmx-explorer-rx-x64z`).
Source dispatch: op-147m (META methodology directive, standing, no expiry).
Doctrine ref: `wip-claude/test-pillar-partition.md` (not present on this host;
working from the dispatch text as authoritative).

## §2a Test Strategy block (per the enforcement clause — applies to every
guest-run op activation from this point forward)

| layer | tool | owns |
|---|---|---|
| ORCHESTRATION | **Elixir** | run-driver; lifecycle/soak sequencing; env capture; normalize; diff vs macOS reference; classify; findings/nx-r64z ledger. **Never owns the metal assertion.** |
| LOW PROBE | **Zig** | C ABI / syscalls / Mach traps / struct & wire layout / port ops / substrate. The metal assertion (liveness, PID identity across restart/reload, round-trip correctness, wire/ABI facts). One source runs on both targets. |
| OBSERVATION | **DTrace .d** | slope/leak ticks; fbt/pid correlation; signal/exec tracing. Feeds observation to conductor/probe; **not** the orchestrator. |
| (deferred) | swift-testing | HIGH tier — waits on Lane B (rmxOS Swift runtime solid). macOS may pre-capture reference-ahead only. |

**Shell usage rule (boundary):** direct CLI at the prompt or as a couple of
glue lines (grep, pgrep, ls, nm, readelf, kldstat, single launchctl invocation)
stays FINE. The rule is "don't grow shell INTO the harness" — a multi-step
.rc/.sh that drives a lifecycle/soak and emits verdicts is banned, regardless
of size.

## Ack markers

```text
OP147M_METHOD_ACK status=0 role=explorer
OP147M_ELIXIR_SPINE_OK status=0      # run-driver/lifecycle/soak in Elixir
OP147M_ZIG_PROBE_OK status=0         # metal assertions in Zig
OP147M_DTRACE_D_OK status=0          # runtime observation via .d (where used)
OP147M_NO_SHELL_HARNESS status=0     # zero committed multi-step .rc/.sh harness
OP147M_TERMINAL status=0
```

## What I'm leaving behind (anti-patterns from pre-op-147m work)

These were committed/created BEFORE this ack. They are FLAGGED as
methodology-violations and DO NOT count as valid PASS per the Gatekeeper
retirement criterion:

| artifact | why flagged | re-authoring owner |
|---|---|---|
| `scripts/op124/op124-lifecycle-probe.rc` (~250 lines) | big shell harness doing orchestration + verdicts in sh | Explorer (next asl lifecycle op) |
| `scripts/op139/op139-auxv-probe.rc` (~140 lines) | big shell harness (two-perspective auxv dump + launchd-up sequencing) | Explorer (or retire: op-139 verdict is already in; shell can be archived, not committed) |
| `scripts/op134/op134-coldboot-probe.sh` (~165 lines) | big shell harness (cold-boot lifecycle + round-trip) | Explorer (next notifyd lifecycle op) |
| `scripts/asl/asld-lifecycle-harness.sh` (~170 lines) | big shell harness (op-137 asld lifecycle driver) | Explorer (asl lifecycle source-of-truth re-author) |
| `scripts/notifyd/notifyd-lifecycle-harness.sh` + `asld-soak-driver.sh` + `notifyd-soak-driver.sh` | big shell harnesses (op-131 linage) | Explorer (notifyd/asld lifecycle re-author) |
| `scripts/op134/op134-coldboot-probe.sh` and `op134-stage-image.sh` | the staging shell is THIN GLUE (mdconfig/mount/install) — stays; the probe.sh is the harness — goes | split: staging stays as glue, probe.sh → Elixir+Zig |

The C harnesses (`asl-harness.c`, `xpc-harness.c`, `auxv-probe.c`,
`block078-notify-roundtrip.c`, `block078-dlopen-smoke.c`, dispatch/conformance
matrix `harness.c`) are ZIG-equivalent metal probes in C — they pre-date the
Zig preference but are categorically correct (metal assertions in a compiled
language). They will be re-authored to Zig when next touched for a substantive
change; touching them just to translate C→Zig without a behavior change is
NOT required by op-147m.

## op-124 specific consequence

**op-124's PASS does NOT retire the op** per the binding Gatekeeper retirement
criterion. The lifecycle evidence (7 rungs green, asl round-trip at
observe/restart/reload) was produced by a banned shell harness. The DATA is
still useful as evidence that the op-144 fix holds across the lifecycle (no
regression), but the op itself needs re-authoring in Elixir + Zig before it
counts toward id-011.

Re-authoring scope (estimate, not committed until dispatched):
- **Elixir scenario module** (probably `test/rmx_os_oracle/scenarios/asl_leg1_lifecycle.ex`
  or similar) — drives bhyve, captures serial, parses Zig output, owns the
  findings/nx-r64z ledger entry.
- **Zig probe** (`macos-validation/probes/asl/asl_lifecycle.zig` or similar)
  — one source, runs in the guest, owns: launchctl load/start/remove/reload
  invocations via posix_spawn (NOT shell); asld liveness via `kinfo_proc`
  sysctl; asl round-trip via libasl direct linkage; returns structured
  per-rung results to serial.
- **No DTrace .d needed for leg-1** (no observation required for lifecycle
  PASS; observation is for soak leg-4 / regression diagnosis).
- The existing op-124 evidence (v1+v2 serial logs, the asld-no-crash proof)
  can be retained as appendix material; the re-authoring produces the
  retireable artifact.

## Standing commitments (this role, going forward)

1. **Before authoring any new test/automation harness**: state the §2a
   partition explicitly. If the answer is "shell .rc with N steps and echo
   verdicts", STOP and re-plan as Elixir + Zig (+ .d for observation).
2. **Shell usage stays thin**: 1–3 lines of glue at the prompt, or a
   straight-line staging script (mdconfig/mount/install) that doesn't emit
   verdicts — fine. Multi-step shell that emits `OP_NNN_* status=` markers
   — banned.
3. **Elixir conductor** lives in the existing `rmx-explorer` Mix project
   (`lib/rmx_os_oracle/` + `test/rmx_os_oracle/`); **Zig probes** live under
   `macos-validation/probes/` alongside the existing C probes (same target
   matrix).
4. **DTrace .d** scripts continue under `findings/nx-r64z/dtrace/` per the
   op-1041 soak-oracle lineage.
5. **Every guest-run activation record** carries a §2a Test Strategy block
   naming the partition + a retirement criterion.
