# Implementation Readiness Summary

Date: 2026-05-12

## Verdict

Stage 1-2 can begin now.

Stage 3+ should wait for the remaining minor parent decisions or carry explicit
`not_observable` / per-host downgrade behavior where noted.

Use `final-preimplementation-plan.md` as the concrete Stage 1-2 checklist.

## Ready Now

Stage 1: repository skeleton

- `README.md`
- `macos-validation/Makefile`
- harness shell scripts
- results/findings/manifests directory layout
- `.build/` as the only build-output root
- macOS date/version result subdirectories, with `<date>-<os-name>-<kernel-version>`
  fallback for rx/rmxOS or other non-macOS development hosts

Stage 2: common C helpers

- JSON emission with centralized schema constant
- environment capture
- ad-hoc signing helper, including helper executables and per-binary signing
  records
- common Mach return/right formatting helpers
- process cleanup/rendezvous helper conventions
- `foundation/smoke.c` as the first end-to-end compile/sign/run/capture/validate
  pipeline check
- `validate_json.sh` using mandatory `python3` parsing/checks, not fragile
  shell-only parsing

## Coordination Recommendation

OPUS should continue the M2.1 batch 22 rerun in its lane while this oracle repo
starts Stage 1-2. These tracks do not block each other:

- OPUS rerun validates the latest NextBSD cleanup fix in the guest.
- Oracle Stage 1-2 creates the cloneable repo skeleton and common helpers.
- Stage 3+ oracle probes can incorporate any new OPUS batch 22 evidence before
  macOS host collection.

## Confirmed NextBSD Baseline

Base path:

```text
/Users/me/wip-mach-opus/wip-opus
```

Relevant artifacts:

- `scripts/bhyve/nxplatform-mach-probe.c`
- `reports/batch21-serial.log`
- `reports/batch22-serial.log`

Batch 21 resolved the earlier `COPY_SEND` uref suspicion. The macOS oracle
should now confirm native macOS matches the proven NextBSD baseline:

- header `COPY_SEND` accounting is stable
- descriptor `COPY_SEND` source-side accounting is stable
- repeated MIG RPC `COPY_SEND` accounting is stable

Batch 22 adds a key comparison point:

- cross-task `COPY_SEND` descriptor delivery creates a received send right with
  `entry_refs=2` on NextBSD
- macOS should verify whether that delivered-right entry-ref and cleanup
  behavior is universal Mach behavior or NextBSD-specific

## Schema Changes To Carry Into Implementation

Use `nx-v64z.macos-oracle.v1` unless the parent renames it before host result
collection.

The schema now includes:

- `cross_reference.nextbsd_test_id`
- `cross_reference.donor_equivalent_id`
- `message.remote_port`
- `message.local_port`
- `message.header_rights`
- typed `returns`
- typed `right_deltas`
- optional `entry_refs_before`
- optional `entry_refs_after`

Use symbolic port labels such as `service_port`, `cargo_port`, `task_port`, and
`reply_port`. Do not put raw Mach port-name integers in comparison fields.

## Stage 3+ Decisions Still Open

1. Confirm schema name before real macOS host result collection.
2. Decide whether bootstrap read-only inheritance is mandatory when set/restore
   is blocked.
3. Decide per-host versus global downgrade if `mach_port_get_refs()` is
   reliable on only one macOS host.
4. Treat `receiver_copyout_failure` as likely `not_observable` unless a stock
   macOS method is provided.
5. Keep early `ipc-hello` as compile-only unless the parent requests runtime
   before descriptor probes.
6. Decide parser script ownership before Elixir migration.
7. Decide donor history script ownership before Elixir migration.
8. Set minimum Elixir/Erlang versions before Stage 7.

## Safety Rules To Preserve

- Process probes need watchdogs, `waitpid()`, cleanup, and explicit rendezvous.
- Rendezvous must be orthogonal to the channel under test.
- Helper executables must be ad-hoc signed by the same harness path.
- Unknown `mach_port_type()` bits must be recorded as raw hex.
- Zig is not required for Stages 1-5; C-only results still include null/false
  Zig fields.
