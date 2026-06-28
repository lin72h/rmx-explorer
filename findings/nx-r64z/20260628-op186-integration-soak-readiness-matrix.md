# op-186 — integration-soak probe/harness readiness matrix (READ-ONLY)

Date: 2026-06-28. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery only.

## Readiness matrix

| # | workload | status | source path | binary | what it drives |
|---|---|---|---|---|---|
| 1 | **notify churn** | **RUNNABLE** | `findings/nx-r64z/dtrace/id025-watchpoint/op150-probe/op150-notify-churn-probe.c` | `notify-churn-probe` (ELF FreeBSD x86-64, 11648 B) | `notify_register_check → notify_post → notify_check → notify_cancel` @ ~1 iter/sec. Links libnotify. Built host-cross. Verified in op-151. |
| 2 | **asl lifecycle** | **RUNNABLE** | `findings/nx-r64z/dtrace/asl-conformance/asl-harness.c` | `asl-harness` (ELF FreeBSD x86-64, 12880 B) | `asl_open → asl_new → asl_set → asl_log → asl_get → asl_set_filter → asl_search → asl_close` (9-case). Links libasl. Built host-cross. Verified in op-124/op-162. |
| 3 | **libdispatch churn** | **NEEDS-BUILD** | `findings/nx-r64z/dtrace/dispatch-conformance/harness.c` | NOT BUILT (no binary on disk) | 9-case dispatch matrix: async/sync/apply/once/barrier/group/semaphore block+_f, source-timer NORMAL, source-MACH_RECV. Links libdispatch + libBlocksRuntime. Source verified (op-102). Build needs `-fblocks -D__APPLE__` flags. |
| 4 | **mach-IPC oracle** | **RUNNABLE** (.d) | `findings/nx-r64z/dtrace/dispatch-conformance/soak-oracle.d` + `port-balance.d` + `msg-balance.d` + `queue-balance.d` + `kmsg-balance.d` | .d scripts (no compilation needed — loaded via `dtrace -s`) | Substrate invariants: port alloc/dealloc balance, send/recv balance, kmsg alloc/destroy balance, queue enqueue/dequeue balance, combined self-terminating oracle. Uses global-int counters + tick-Ns. fbt provider. Verified in op-104 (120s proof PASSED). |
| 5 | **libxpc workload** | **NEEDS-BUILD** | `findings/nx-r64z/dtrace/xpc-conformance/xpc-harness.c` (substrate only — op-121 version on main; plane-extended version on `op-122-xpc-plane` branch) | NOT BUILT (no binary on main) | Substrate 14-case: dictionary create/encode/decode, int64/string/data primitives, hash identity, connection lifecycle. Plane cases (send/reply, cancel→XPC_ERROR) blocked by `xpc_dictionary_create_reply` gap (li-1008). |

## Long pole analysis

**#3 libdispatch churn (NEEDS-BUILD) is the heaviest lift.** The harness.c source (op-102 era, 9-case matrix) has never been compiled into a standalone binary. Building requires:
- Host-cross compile against rmxOS libdispatch headers
- `-fblocks -D__APPLE__` + include paths (same pattern as xpc/asl harnesses)
- Links: `-ldispatch -lBlocksRuntime -lpthread`
- The source is verified correct (op-102 ran it in-guest)

**#5 libxpc workload (NEEDS-BUILD) is the second lift.** Two variants:
- **Substrate** (op-121, on main): 14-case matrix, proven PASS in prior runs. Just needs building.
- **Plane** (op-122, on `op-122-xpc-plane` branch): send/reply + cancel→XPC_ERROR. Blocked by `xpc_dictionary_create_reply` returning NULL on rmxOS (li-1008). The PLANE IS LIVE (responder connects, messages exchange), but the reply-correlation path is broken.

For a pre-1.0 integration soak, the substrate version suffices (classification-only, per the Arranger's note "libxpc is classification-only pre-1.0").

## Orchestration

**No Elixir multi-workload concurrent orchestrator exists.** NEEDS-AUTHORING.

Existing Elixir modules:
- `lib/rmx_os_oracle/id025/repro_conductor.ex` — single-workload driver (op-151: stage → boot → detect freeze → capture)
- `lib/rmx_os_oracle/id025/watchpoint_conductor.ex` — single-workload detector (op-148: kldload + dtrace + heartbeat + flat-slope)
- `lib/rmx_os_oracle/id025/freeze_surviving_capture.ex` — capture rig (op-153: bhyve -G + kgdb)
- Various `marker_manifest.ex` modules (per-component, not orchestration)

**None of these compose multiple workloads concurrently.** Composing notify-churn + asl-harness + dispatch-churn + mach-IPC oracle into ONE integration soak requires a new Elixir module (per id-006/id-007 design + op-147m methodology: Elixir = orchestration).

The banned shell soak-drivers (asld-soak-driver.sh, notifyd-soak-driver.sh, dispatch soak-driver.sh) are RETIRED (op-147m methodology ban). They were the prior single-workload drivers; they cannot be composed either.

## OP186 markers

```text
OP186_NOTIFY_CHURN: RUNNABLE (binary + source verified)
OP186_ASL_LIFECYCLE: RUNNABLE (binary + source verified)
OP186_LIBDISPATCH_CHURN: NEEDS-BUILD (source present, unbuilt — heaviest lift)
OP186_MACH_IPC_ORACLE: RUNNABLE (.d scripts, no build needed — fbt provider, op-104 proven)
OP186_LIBXPC_WORKLOAD: NEEDS-BUILD (substrate source on main; plane source on op-122 branch; blocked by li-1008)
OP186_ORCHESTRATOR: NEEDS-AUTHORING (no multi-workload concurrent composer exists)
OP186_LONG_POLE: libdispatch-churn (NEEDS-BUILD) + orchestrator (NEEDS-AUTHORING)
OP186_TERMINAL status=0
```
