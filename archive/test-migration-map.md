# Test Migration Map: Shared Oracle Coverage

Date: 2026-05-12

## Purpose

Map existing test cases from both implementations (Opus and GPT) plus donor
tests to the shared oracle agent, enabling both lanes to validate against the
same macOS baseline.

Authority note: `comprehensive-nx-v64z-macos-oracle-plan.md` is the
authoritative implementation order and schema contract. This file is a coverage
map. If staging differs, follow the comprehensive plan.

## The Portability Problem

Our bhyve probes (both Opus and GPT copies) use FreeBSD-specific interfaces:

```c
/* FreeBSD-only — these won't compile on macOS */
syscall(SYS_mach_port_allocate, ...);
syscall(SYS_mach_msg, ...);
```

The oracle probes use standard Mach APIs:

```c
/* Portable — compiles on both macOS and FreeBSD/NextBSD */
mach_port_allocate(mach_task_self(), ...);
mach_msg(&header, ...);
```

The donor tests (`ipc-hello`, `set-bport`, etc.) already use the portable API
surface. They are the most directly migratable source.

## Three Migration Tiers

### Tier 1: Donor Tests (Directly Portable)

These compile on both macOS and FreeBSD/NextBSD with no code changes. They need
wrapping to produce oracle JSON output and cleanup verification.

| Donor Test | Oracle Probe | Coverage | Migration Work |
| --- | --- | --- | --- |
| `ipc-hello` | `m1/fork_port_inheritance.c` (partial) | same-process mach_msg, COPY_SEND header, inline payload | Add JSON output, remove interactive stdin loop, add cleanup baseline |
| `set-bport` | `m1/bootstrap_special_port.c` | task_set/get_bootstrap_port | Add JSON output, save/restore, classify `privilege_sensitive` on macOS |

**Migration method**: Fork the donor source into `macos-validation/probes/donor/`,
add the oracle JSON harness, keep the original Mach API calls unchanged.

### Tier 2: Semantic Equivalents (New Shared C Probes)

These are new C probes written to the oracle schema that test the same semantic
questions our bhyve batches answer. They use the portable `mach/mach.h` API so
they compile on both platforms.

| Our Batch | Semantic Question | Oracle Probe | Status |
| --- | --- | --- | --- |
| B3 (port_basics) | allocate/destroy/inspect ports | `foundation/port_names.c` | New probe needed |
| B5 (send_right_mod_refs) | mach_port_mod_refs / get_refs | `foundation/port_get_refs.c` | New probe needed |
| — | mach_port_type right classes | `foundation/port_type.c` | New probe needed |
| B7 (fork_exit) | fork port inheritance / cleanup | `m1/fork_port_inheritance.c` | New probe needed |
| — | posix_spawn / execve inheritance | `m1/spawn_exec_port_inheritance.c` | New probe needed |
| B20 (cross_task_inline) | bootstrap set/get, cross-task msg | `m1/bootstrap_special_port.c` | New probe needed |
| B21 test 1 (header COPY_SEND uref) | header COPY_SEND does not inflate urefs | `m1/header_copy_send_accounting.c` | New probe needed |
| B21 test 3 (MIG RPC COPY_SEND) | MIG RPC COPY_SEND accumulation | (covered by header_copy_send) | Merge into header probe |
| B21 test 2 (body descriptor uref) | body COPY_SEND does not inflate urefs | `m2/descriptor_copy_send.c` | New probe needed |
| B22 (cross_task descriptor) | cross-task COPY_SEND descriptor usable | `m2/descriptor_copy_send.c` | New probe needed |
| B17 (mach_msg self inline) | basic self-send roundtrip | (foundational, covered by header probes) | Covered |
| B18 (complex descriptor) | COPY_SEND / MOVE_SEND body descriptor | `m2/descriptor_copy_send.c`, `m2/descriptor_move_send.c` | New probes needed |
| B19 (OOL data/ports) | OOL data and port arrays | (future, not in first oracle package) | Deferred |

### Tier 3: Bhyve-Only Tests (Not Migratable)

These test FreeBSD kernel-specific behavior and are not candidates for the
shared oracle.

| Our Batch | Why Not Migratable |
| --- | --- |
| B0-B2 (syscall discovery) | Tests FreeBSD syscall table presence |
| B4 (port churn) | Stress test, not semantic oracle material |
| B8 (concurrent churn) | Stress test with FreeBSD thread model |
| B9-B10 (space stability) | Tests FreeBSD IPC space implementation |
| B12a-d (teardown variants) | Tests FreeBSD-specific cleanup paths |
| B13 (concurrent teardown) | Stress test |
| B15 (implicit close) | Tests FreeBSD fd/port close coupling |
| B16 (kernel send release) | Tests FreeBSD kernel-side send right release |

These remain valuable for verifying our FreeBSD kernel module but the macOS
oracle cannot reproduce them — the kernel implementation differs.

## Cross-Reference ID Mapping

The oracle `cross_reference` schema field should map as follows:

## Key Shared Coverage Table

| Oracle probe | Opus batch | GPT batch | Donor test |
| --- | --- | --- | --- |
| `foundation/port_names.c` | B3 | B3 | null |
| `foundation/port_get_refs.c` | B5 | B5 | null |
| `foundation/port_type.c` | new | new | null |
| `m1/fork_port_inheritance.c` | B7 | B7 | null |
| `m1/bootstrap_special_port.c` | B20 | B19 partial | `set-bport` |
| `m1/header_copy_send_accounting.c` | B21 test 1 | null | `ipc-hello` partial |
| `m1/header_move_send_accounting.c` | planned B23+ | null | null |
| `m2/descriptor_copy_send.c` | B21 test 2 plus B22 | null | null |
| `m2/descriptor_move_send.c` | planned B23+ | null | null |
| `m2/send_once_descriptor.c` | planned | null | null |
| `m2/invalid_descriptor_disposition.c` | planned | null | null |
| `m2/dead_name_descriptor_right.c` | planned | null | null |
| `m2/double_move_send_descriptor.c` | planned | null | null |
| `m2/receiver_copyout_failure.c` | planned or not observable | null | null |

| Oracle `test_id` | `nextbsd_test_id` (our batch) | `donor_equivalent_id` |
| --- | --- | --- |
| `macos_foundation_port_names` | `characterize_r6c_batch3_port_basics` | null |
| `macos_foundation_port_get_refs` | `characterize_r7_stage1c_batch5_send_right_mod_refs` | null |
| `macos_foundation_port_type` | null (new) | null |
| `macos_m1_fork_port_inheritance` | `characterize_r7_stage1c_batch7_fork_exit` | null |
| `macos_m1_spawn_exec_port_inheritance` | null (new) | null |
| `macos_m1_bootstrap_special_port` | `characterize_r8_batch20_cross_task_inline` | `set-bport` |
| `macos_m1_header_copy_send_accounting` | `characterize_m2_batch21_copy_send_uref_accounting` | `ipc-hello` (partial) |
| `macos_m1_header_move_send_accounting` | null (planned, our B23+) | null |
| `macos_m2_descriptor_copy_send` | `characterize_m2_batch22_cross_task_copy_send_descriptor` | null |
| `macos_m2_descriptor_move_send` | (planned, our B23+) | null |
| `macos_m2_send_once_descriptor` | (planned) | null |
| `macos_m2_invalid_descriptor_disposition` | (planned) | null |
| `macos_m2_dead_name_descriptor_right` | (planned) | null |
| `macos_m2_double_move_send_descriptor` | (planned) | null |
| `macos_m2_receiver_copyout_failure` | (planned) | null |

## What Both Implementations Get From the Oracle

When the macOS oracle probes run on Intel and Apple Silicon, both
implementations receive:

1. **Confirmed COPY_SEND semantics**: macOS does/doesn't inflate sender urefs
   (we expect "doesn't" — matching our batch 21 finding)
2. **Confirmed MOVE_SEND semantics**: sender loses right at send time or later
3. **Cross-task delivered right entry_refs**: macOS creates entry_refs=N for
   COPY_SEND delivered rights (we found entry_refs=2 on NextBSD)
4. **Bootstrap port behavior**: stock macOS permits/blocks set_special_port
5. **fork/spawn/exec inheritance**: which rights survive across each
6. **Cleanup contracts**: whether deallocate suffices or destroy is needed
7. **Failure surfaces**: exact kern_return_t for invalid dispositions, dead
   names, double MOVE_SEND

Both the Opus and GPT implementations compare their bhyve probe results against
these shared macOS facts. Neither implementation needs to run macOS probes
itself.

## Coverage Implementation Order

Follow the comprehensive plan's stage order:

1. repository skeleton
2. common C helpers
3. foundational probes
4. M1 probes
5. core M2 probes
6. donor manifest and compile matrix
7. portable Elixir tests
8. native macOS runs
9. cross-host/rxOS comparison
10. rmxOS donor runs

The donor wrapping below belongs to Stage 6+; it is not the first code to
implement.

### Donor Test Wrapping (Stage 6+ in oracle plan)

1. Fork `ipc-hello.c` into `macos-validation/probes/donor/ipc-hello.c`
   - Remove interactive stdin loop, make it a single-shot request/reply
   - Add oracle JSON output wrapper
   - Add cleanup baseline verification
   - Add ad-hoc signing in Makefile
   - Test on macOS first, then on FreeBSD/NextBSD

2. Fork `set-bport.c` into `macos-validation/probes/donor/set-bport.c`
   - Add save/restore of original bootstrap port
   - Add oracle JSON output wrapper
   - Classify as `privilege_sensitive` if stock macOS blocks mutation
   - Test on macOS first

### New Shared Foundational Probes (Stage 2-3 in oracle plan)

Write these as new portable C that compiles on both platforms:

1. `foundation/port_names.c` — mach_port_names inventory and create/destroy
2. `foundation/port_get_refs.c` — mach_port_get_refs for send/receive
3. `foundation/port_type.c` — mach_port_type for known right classes

### New Shared M1 Probes (Stage 4)

1. `m1/header_copy_send_accounting.c` — the exact same test as our batch 21
   test 1, but using portable mach_msg() instead of syscall()
2. `m1/header_move_send_accounting.c` — new, needed by both lanes
3. `m1/fork_port_inheritance.c` — portable version of our batch 7
4. `m1/bootstrap_special_port.c` — portable version of our batch 20

### New Shared M2 Probes (Stage 5)

1. `m2/descriptor_copy_send.c` — portable version of our batch 22
2. `m2/descriptor_move_send.c` — both lanes need this next
3. `m2/send_once_descriptor.c` — after COPY_SEND/MOVE_SEND clean
4. `m2/invalid_descriptor_disposition.c` — negative test
5. `m2/dead_name_descriptor_right.c` — negative test
6. `m2/double_move_send_descriptor.c` — negative test

## Shared Code: `common/` Helpers

Both implementations benefit from shared C helpers in
`macos-validation/probes/common/`:

| Helper | Purpose | Used By |
| --- | --- | --- |
| `nx_result.h/c` | Oracle JSON schema emission | All probes |
| `nx_env.h/c` | Environment capture | All probes |
| `nx_mach_utils.h/c` | Port inventory, baseline snapshot/compare | All probes |
| `nx_json.h/c` | Minimal JSON emitter (no dependencies) | All helpers |

These are the oracle agent's code. Both implementation lanes consume the
results, not the helper source.

## What Does NOT Migrate

- Bhyve staging scripts (`stage-guest.sh`, `run-guest.sh`)
- FreeBSD kernel module build/load
- Serial output format (the oracle uses JSON, not serial log parsing)
- Serial parsing as a macOS runtime dependency. Portable parser/schema fixture
  tests may migrate later under the Elixir migration plan.
- FreeBSD-specific syscall numbers and calling conventions
- Batch numbering scheme (oracle uses named `test_id` values)

## Result Flow

```
macOS hosts (mx-x64z, mx-a64z)
  → run oracle probes
  → produce nx-v64z.macos-oracle.v1 JSON

FreeBSD bhyve guest (Opus lane)
  → run nxplatform-mach-probe.c batches
  → produce serial log → parse → compare against oracle JSON

FreeBSD bhyve guest (GPT lane)
  → run nxplatform-mach-probe.c batches
  → produce serial log → parse → compare against oracle JSON
```

Both lanes compare against the same macOS ground truth. The oracle agent
owns the probes and schema. Neither implementation lane modifies the oracle
probes — they consume the results.
