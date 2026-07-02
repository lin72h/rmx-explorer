# op-252 — macOS-27 thread-pool / governor seam recon (public API vs SPI vs internal)

Date: 2026-07-03. Lane: `explorer-mx-a64z` (macOS parity recon). READ-ONLY discovery.
Seat: mm4 (macOS 27.0, arm64, Apple M4, XNU 13361.0.0.501.1). Feeds op-251 SCOPE-6 (the Oracle design consult — the mimic target for a kernel-load-informed concurrency governor).

## F1 — pthread_workqueue SPI on macOS 27 (still shipped; headers gone private)

**Hypothesis**: the 2017-era `_pthread_workqueue_*` SPI is still the runtime↔kernel thread-pool seam on macOS 27, but the private headers are no longer in the SDK (ABI-only).

**Evidence**:
- `pthread/workqueue_private.h` and `pthread/qos_private.h`: **NOT FOUND** in `MacOSX27.0.sdk/usr/include/` (searched). Apple removed the private headers from the SDK.
- **19 `_pthread_workqueue_*` symbols STILL EXPORTED** in `MacOSX.sdk/usr/lib/system/libsystem_pthread.tbd`:
  - **Width/seam**: `_pthread_workqueue_should_narrow` (the narrow-down hint), `_pthread_workqueue_addthreads` + `_pthread_workqueue_add_cooperativethreads` (the scale-up "call me"), `_pthread_workqueue_supported`.
  - **QoS-override family**: `_pthread_workqueue_override_start_direct`, `_override_start_direct_check_owner`, `_asynchronous_override_add`, `_asynchronous_override_reset_all_self`, `_asynchronous_override_reset_self`, `_override_reset`.
  - **Init/lifecycle**: `_pthread_workqueue_init`, `_pthread_workqueue_init_with_kevent`, `_pthread_workqueue_init_with_workloop`, `_pthread_workqueue_setup`, `_pthread_workqueue_setdispatch_np`, `_pthread_workqueue_setdispatchoffset_np`, `_pthread_workqueue_set_event_manager_priority`, `_pthread_workqueue_setkill`, `_pthread_workqueue_allow_send_signals`.
- The kernel ABI: `workq_kernreturn` (the syscall for thread requests — visible in open-source xnu `kern/kern_workqueue.c`). Still the kernel↔libpthread thread-request mechanism.

**Verdict**: the SPI is ALIVE (ABI) but HEADER-PRIVATE. It's the implementation seam libdispatch/libpthread uses to drive the kernel workqueue. Our ported `include/pthread/workqueue_private.h` (2017, SPI_VERSION 20170201) matches this surface — the ported SPI is current enough as the INTERNAL mechanism. But it is NOT the public face macOS ships.

## F2 — os_workgroup: the PUBLIC width-sizing abstraction (the mimic target)

**Hypothesis**: `os_workgroup_parallel` + `os_workgroup_max_parallel_threads` is Apple's PUBLIC abstraction for "a runtime declares a cooperating thread set the kernel schedules/sizes as a unit" with WIDTH SIZING.

**Evidence** (all in `MacOSX.sdk/usr/include/os/`, `API_AVAILABLE(macos(11.0))`):
- `os/workgroup.h` — umbrella (includes object/interval/parallel).
- `os/workgroup_parallel.h:64-69` — `os_workgroup_parallel_create(name, attr)` → an `os_workgroup_parallel_t` for tracking parallel work.
- `os/workgroup_object.h:175-178` — `os_workgroup_join(wg, token_out)` — joins the CURRENT THREAD to the workgroup (cooperating set). `os_workgroup_leave(wg, token)` — leaves. **A thread explicitly joins/leaves** the workgroup.
- `os/workgroup_object.h:329-336` — **`os_workgroup_max_parallel_threads(wg, attr)`**: *"Returns the system's recommendation for maximum number of threads the client should make for a multi-threaded workload in a given workgroup. Takes into consideration the current hardware."* — **THIS IS THE WIDTH-SIZING QUERY**.
- `os/workgroup_interval.h` — `os_workgroup_interval_start/finish/update` with a **deadline** param — scheduling-INTERVAL/deadline tracking (a SEPARATE concern from width; it's about timing/deadlines, not concurrency sizing).

**Verdict**: `os_workgroup_parallel` + `max_parallel_threads` IS the PUBLIC mimic target. It gives: (a) a cooperating thread set (`join`/`leave`), (b) width sizing (`max_parallel_threads` — the hardware-aware recommended concurrency), (c) a create-with-attributes shape. The interval family is orthogonal (scheduling, not width) — NOT the governor shape op-251 wants.

## F3 — The dynamic-width signal (public + private)

**Hypothesis**: macOS exposes BOTH a public "recommended concurrency" query AND a private "should-narrow" hint. Width is kernel-internal (workqueue calls you up) + userspace-queryable.

**Evidence**:
- **PUBLIC width query**: `os_workgroup_max_parallel_threads(wg, attr)` — polls the kernel's recommendation. A foreign runtime calls this to size its pool to `hw.activecpu`/`hw.ncpu` + the workgroup's attributes.
- **PRIVATE scale-up**: `_pthread_workqueue_add_cooperativethreads` / `_addthreads` — the kernel asks the runtime to add threads (the "call you up"). The runtime's event-loop calls these when the kernel signals more concurrency is needed.
- **PRIVATE narrow-down**: `_pthread_workqueue_should_narrow` — the kernel's hint to reduce thread count (thermal/contention pressure). The runtime polls this to decide whether to shrink.

**Verdict**: the width signal is BIDIRECTIONAL — (1) runtime→kernel: "how many threads should I run?" (max_parallel_threads, public); (2) kernel→runtime: "add more" (add_cooperativethreads) / "narrow down" (should_narrow). A foreign governor mimics the PUBLIC max_parallel_threads query + the PRIVATE add/narrow signals.

## F4 — Precedent: Swift concurrency IS a non-GCD runtime consuming os_workgroup as a governor

**Hypothesis**: a known Apple runtime (other than GCD) already drives its thread count from the os_workgroup/workqueue signal — the governor pattern op-251 wants.

**Evidence**:
- `os/workgroup_object.h`: `os_workgroup_join`, `os_workgroup_leave`, `os_workgroup_max_parallel_threads`, and the join-token are all marked **`OS_REFINED_FOR_SWIFT`** — Swift is a first-class consumer. The Swift concurrency cooperative thread pool (the Swift runtime's executor) uses os_workgroup to size its pool to max_parallel_threads + join/leave its cooperative threads.
- **libdispatch/GCD**: uses the pthread_workqueue SPI DIRECTLY (it's the primary consumer — `_addthreads`/`_add_cooperativethreads`/`_should_narrow`/override family). GCD's worker-pool thread count is driven by the workqueue signal (add = scale up, should_narrow = scale down). This is the governor pattern in its original form.

**Verdict**: the precedent EXISTS at two levels. GCD = the SPI-level governor (thread count driven by add/narrow signals). Swift concurrency = the os_workgroup-level governor (cooperative pool sized by max_parallel_threads). op-251 wants the latter shape (a foreign runtime — our ported thread-pool / ERTS — drives its own thread count from the workgroup signal). **Swift concurrency is the closest precedent.**

## RECOMMENDATION for op-251 SCOPE-6

**Mimic `os_workgroup_parallel`'s PUBLIC shape** as the governor seam — NOT extend the old `_addthreads` SPI as the public face:

| mimic-target (public shape) | macOS source | op-251 analog |
|---|---|---|
| create a parallel workgroup | `os_workgroup_parallel_create` (workgroup_parallel.h:64) | the runtime declares a cooperating thread set |
| join/leave (thread enters/exits the set) | `os_workgroup_join`/`_leave` (workgroup_object.h:175) | the runtime's worker threads join/leave the kernel-sized set |
| width query (recommended concurrency) | `os_workgroup_max_parallel_threads` (workgroup_object.h:329) | the runtime polls "how many threads should I run?" → sizes to `hw.activecpu` |
| scale-up (kernel→runtime: add threads) | `_pthread_workqueue_add_cooperativethreads` (SPI, exported) | the kernel signals "add more concurrency" |
| narrow-down (kernel→runtime: reduce) | `_pthread_workqueue_should_narrow` (SPI, exported) | the kernel signals "reduce concurrency" |

**Internal implementation**: use the ported pthread_workqueue SPI (2017, still ABI-current on macOS 27 — 19 symbols exported) as the kernel mechanism. The SPI is the INTERNAL seam; the os_workgroup shape is the PUBLIC face. This saves op-251 from inventing a shape Apple already shipped — and the ported SPI is current enough to implement it.

**Do NOT mimic `os_workgroup_interval`** — that's scheduling-deadline tracking, not width governance. Keep it separate.

## Citations

- `MacOSX.sdk/usr/include/os/workgroup.h` (umbrella, public)
- `MacOSX.sdk/usr/include/os/workgroup_parallel.h:42-69` (os_workgroup_parallel_t, create)
- `MacOSX.sdk/usr/include/os/workgroup_object.h:114-178` (create_with_port, join); `:314-336` (max_parallel_threads)
- `MacOSX.sdk/usr/include/os/workgroup_interval.h:62-96` (interval_start/finish — scheduling, not width)
- `MacOSX.sdk/usr/lib/system/libsystem_pthread.tbd` — 19 `_pthread_workqueue_*` symbols (still exported; should_narrow, add_cooperativethreads, override family, init_with_kevent/workloop)
- Our ported baseline: `include/pthread/workqueue_private.h` (2017, SPI_VERSION 20170201) — in the rmxOS tree (not this repo); matches the exported SPI surface.
- Open-source XNU cross-check: `kern/kern_workqueue.c` (workq_kernreturn ABI) — available at opensource.apple.com if the macOS seat lacks a source.

## Boundaries honored

Discovery/recon ONLY — no product-write, no build, no harness. Public headers + open-source XNU + published docs; no protected-binary RE. Every "macOS 27 exposes X" cited with header path + symbol. Staged in the Explorer's own dir (findings/mx-a64z/). Feeds op-251; does NOT decide the design — supplies the mimic target as a hypothesis.
