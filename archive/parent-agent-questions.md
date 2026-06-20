# Parent Agent Questions

Date: 2026-05-12

These are the remaining specific questions this `nx-v64z` macOS-oracle package
needs answered before implementation starts.

## Parent Decisions Already Recorded

- `wip-gpt-oracle` owns the cloneable probe source package.
- `../wip-gpt` remains the planning/docs repository.
- First implementation is shell/Make plus C probes.
- Use Zig only when source sharing with the NextBSD guest lane or exact
  ABI/layout control requires it.
- Add Elixir comparison only after both macOS result sets and the NextBSD/rxOS
  result set exist.
- Queued sender/receiver-exit descriptor tests are first follow-ups, not
  mandatory before basic `COPY_SEND` / `MOVE_SEND`.
- Commit curated summary JSON and findings notes. Keep raw logs outside git
  unless a raw fixture is specifically useful.
- Rosetta results are allowed only as non-primary supplemental artifacts.
  Primary `mx-a64z` must be native arm64/arm64e.
- Intel versus Apple Silicon disagreement uses `version_sensitive` with
  explicit architecture notes, not a separate architecture class.
- NextBSD batch 21 resolved the earlier `COPY_SEND` uref suspicion; macOS
  probes now verify native macOS matches the confirmed NextBSD baseline.
- Stage 1-2 implementation is unblocked while the remaining questions are
  resolved.

## Resolved Evidence Inputs

Base path:

```text
/Users/me/wip-mach-opus/wip-opus
```

| Artifact | Path |
| --- | --- |
| Full probe source, batches 1-22 | `scripts/bhyve/nxplatform-mach-probe.c` |
| Batch 17-20 regression log | `reports/batch17-20-regression-serial.log` |
| Batch 21 `COPY_SEND` accounting log | `reports/batch21-serial.log` |
| Batch 22 cross-task descriptor log | `reports/batch22-serial.log` |
| M1 completion report | `reports/m1-completion-report.md` |
| MIG build script | `scripts/mig/build-migcom.sh` |
| MIG regeneration diffs | `reports/mig-regen-diffs/` |

| Batch | ID |
| --- | --- |
| 17 | `characterize_batch17_mach_msg_inline_self` |
| 18 | `characterize_batch18_mach_msg_complex_descriptor` |
| 19 | `characterize_batch19_mach_msg_complex_ool` |
| 20 | `characterize_batch20_cross_task_inline_mach_msg` |
| 21 | `characterize_m2_batch21_copy_send_uref_accounting` |
| 22 | `characterize_m2_batch22_cross_task_copy_send_descriptor` |

## Artifact Policy Questions

1. Is `nx-v64z.macos-oracle.v1` the final schema name for the first result
   package?

   Why it matters: changing schema names after host collection creates avoidable
   migration work.

## Semantic Policy Questions

2. For bootstrap special-port replacement, is stock macOS failure enough to
   classify the replacement path as `privilege_sensitive`, or should a weaker
   read-only bootstrap inheritance probe remain mandatory?

   Why it matters: this controls whether bootstrap validation blocks on
   mutation or still captures read-only inheritance facts.

3. If `mach_port_get_refs()` is reliable on one macOS host but unreliable or
   restricted on the other, should uref-sensitive probes be downgraded globally
   or only for the affected host?

   Why it matters: the `COPY_SEND` and `MOVE_SEND` probes depend on exact uref
   accounting, but usability and cleanup can still be validated without it.

4. Is receiver-side descriptor copyout failure practically observable from
   stock macOS userland, or should `receiver_copyout_failure` normally classify
   as `not_observable` after documenting the attempted method?

   Why it matters: M2.4 requires proving failed copyout does not silently
   consume sender rights, but the failure may be hard to induce without private
   control over the receiver IPC space.

5. Should `ipc-hello` runtime be attempted on macOS before core descriptor
   probes, or is the early donor check compile-only until M2 facts land?

   Why it matters: early runtime success is useful sanity evidence, but
   `ipc-hello` is a broad donor test and may distract from narrower M1/M2
   semantic probes.

## Elixir Migration Questions

6. Should the oracle repo copy `parse-serial.py` and `parse-characterize.py`, or
   import them from the parent repo during local development?

   Why it matters: copying makes the oracle repo cloneable on macOS, while
   importing avoids duplicated parser ownership.

7. Should `classify-donor.sh` and `nextbsd-history.sh` become portable oracle
   tools, or remain parent-only scripts tested from the parent repository?

   Why it matters: these scripts touch donor-history assumptions that may not
   belong in the cloneable macOS oracle package.

8. What minimum Elixir/Erlang versions should be supported on `rx`, `mx-x64z`,
   and `mx-a64z`?

   Why it matters: the current local toolchain has an Elixir/Erlang mismatch,
   so version policy needs to be fixed before `mix test` failures are treated
   as project failures.
