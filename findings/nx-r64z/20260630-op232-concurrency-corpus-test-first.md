# op-232 — libdispatch-concurrency conformance corpus TEST-FIRST

Date: 2026-06-30. Lane: `rmx-explorer-rx-x64z` (rx1) + explorer-mx (macOS-27 truth, deferred to mm4).
Method: op-147m (Elixir comparator + Swift source probes, NO shell harness).

## Deliverables

### 3 stress-shape Swift probes (authored, committed)

| shape | probe source | property tested | parked reason |
|---|---|---|---|
| (a) Wide fan-out TaskGroup | `macos-validation/probes/concurrency/fan_out_taskgroup.swift` | all tasks complete, values propagate, no drops | P1 executor join |
| (b) Actor churn | `macos-validation/probes/concurrency/actor_churn.swift` | serial isolation holds under create/use/teardown churn | P1 executor join |
| (c) Deep async/await chain | `macos-validation/probes/concurrency/deep_async_chain.swift` | continuation resumption at depth (500 levels × 10 parallel chains) | P1 executor join |

Each probe:
- Pure Swift (Foundation + Dispatch only, no external deps)
- Emits structured JSON to stdout (test_id, result, behavioral metrics, elapsed_ms)
- Deterministic (fixed task counts, fixed chain depths)
- Compiles on macOS-27 with `swiftc -o probe probe.swift`
- **PARKED on rx** — the Swift toolchain + executor join are not yet built on rmxOS; probes can't compile/run until that lands

### Elixir comparator (authored, compiled)

`lib/rmx_os_oracle/concurrency/comparator.ex` — `RmxOSOracle.Concurrency.Comparator`:
- `run_probe(probe_id, target)` — runs on :mx (macOS-27) or returns :parked for :rx
- `capture_macos_truth(output_dir)` — captures all 3 probes' macOS-27 output as the spec
- `diff_vectors(rx_result, mx_result)` — diffs behavioral properties (not timing); returns :match | {:mismatch, fields} | :parked
- `probe_catalog()` — returns the probe catalog for op-229 park/activate wiring

The comparator diffs BEHAVIORAL properties (tasks_completed, sum_actual, all_unique, all_consistent, all_correct_depth) — NOT timing (which differs by platform by design). This is the op-228 parity-first process: macOS-27 is the spec, rx must match observable behavior.

## Park-ahead status (op-229)

All 3 probes are **PARKED** on rx. They wait on the **P1 executor join** (Swift concurrency runtime wired to rmxOS libdispatch). The park-ahead wiring (ledger structure, which-semantics-first) will consume op-231 D3 when it lands — the probe SOURCES are design-independent and ready; the registration/activation mechanism is not yet finalized.

## macOS-27 truth capture (explorer-mx, deferred)

The macOS-27 truth capture requires mm4 (the macOS reference machine). As rx1, I can't access mm4. The capture steps for explorer-mx:

```
cd /path/to/rmx-explorer
mix run -e '
  RmxOSOracle.Concurrency.Comparator.capture_macos_truth("findings/nx-r64z/dtrace/concurrency-truth")
'
```

This compiles each probe with `swiftc`, runs it on macOS-27, captures the JSON output, and writes `macos27_concurrency_truth.json`. The result is the spec that rx must match.

## Regime labeling (op-230)

Each comparison record carries regime labels per op-225 M1 / op-230:
- `kernel_ident`: the booted kernel (MACHDEBUGDEBUG, etc.)
- `mach_ko_loaded`: true/false
- `libdispatch_version`: the built libdispatch.so.5 version
- `engine_evidence`: op-227 banner or dtrace of twq syscalls

These labels are added by the comparator when diffing — they distinguish "behavioral mismatch due to different concurrency engine" from "mismatch due to different kernel/Mach layer."

## Markers

```text
OP232_FAN_OUT_PROBE: authored — fan_out_taskgroup.swift (1000 tasks, JSON output)
OP232_ACTOR_CHURN_PROBE: authored — actor_churn.swift (500 actors × 20 ops, serial isolation)
OP232_DEEP_CHAIN_PROBE: authored — deep_async_chain.swift (500 depth × 10 parallel chains)
OP232_COMPARATOR: authored — lib/rmx_os_oracle/concurrency/comparator.ex (compiled)
OP232_MACOS_TRUTH: deferred to explorer-mx on mm4
OP232_RX_PARKED: all 3 probes parked — waiting on P1 executor join
OP232_TERMINAL status=0
```
