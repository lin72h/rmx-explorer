# op-084 — rx dispatch servicing-invariant parity (block-078 runtime smoke)

Date: 2026-06-21

Lane: `explorer-rx-x64z`

Op: op-084 (run the libdispatch/dispatch source on the rmxOS-Mach guest,
diff vs macOS-27)

## Scope

This entry records the rx-side dispatch/Mach-recv servicing evidence captured
by executing the op-087 rmxOS-Mach bhyve guest runbook verbatim
(`wip-gpt/docs/rmxos-bhyve-guest-runbook.md`), and its comparison against the
ferried macOS-27 `mx-a64z` dispatch reference (op-082).

It is a **runtime-smoke** capture (catalog-mode), not an evidence-lane
activation: it spent no attempts, updated no marker authority, and disposed no
preserved evidence (per the runbook).

## Pins

```text
explorer-rx source head: 115c56f (op-086: mx-ref + Mach-aware nx_mach_utils.h + <stdatomic.h>)
rmxOS source tree:        /Users/me/wip-mach/wip-gpt/wip-rmxos  (branch alpha)
rmxOS source head:        5675145df333  (dispatch: service Mach receive through TWQ workqueues)
base image:               block-078-runtime-smoke/runs/20260619T112919Z-clean-check-token-smoke/block078-userland-smoke.img
run dir:                  block-078-runtime-smoke/runs/20260621T033825Z-rx-op084-dispatch-smoke
serial log sha256:        27999f61a4d77ffca06a8cb93e7738a003f5c7e842128a10934bebb796070d98
```

The run used a disposable image copy of the pinned base; the original
evidence/parity image was not touched.

## Run result

```text
stage_rc = 0      (marker block078_stage_userland_status=0)
run_rc   = 0      (success marker BLOCK078_TERMINAL status=0 normalized the poweroff rc)
```

All five expected markers hit `status=0`:

```text
BLOCK078_LINK_LOAD        status=0
BLOCK078_NOTIFYD_ROUNDTRIP status=0
BLOCK078_NOTIFYD_TWQ_TRACE status=0   <- load-bearing for op-081-R
BLOCK078_LAUNCHD_CHECKIN  status=0
BLOCK078_TERMINAL         status=0
```

`BLOCK078_NOTIFYD_TWQ_TRACE status=0` is present (count 1) — i.e. notifyd
emitted libthr TWQ trace lines under `LIBDISPATCH_DISABLE_KWQ` unset, proving
dispatch services a Mach-receive event through TWQ workqueues on rmxOS.

Hard-stop scan (`panic:|Fatal trap|KASSERT|lock order reversal|dispatch assert|
Bad system call|Signal 12|BUG in libdispatch|...`): **clean**.

Teardown: **clean** — no leftover bhyve VM, md device, mount, or image lock.

## macOS-27 reference (mx-a64z, op-082)

```text
results/mx-a64z/20260621-27.0-27.0.0/dispatch_dispatch_mach_recv_source.json
results/mx-a64z/20260621-27.0-27.0.0/dispatch_dispatch_global_queue_service.json
results/mx-a64z/20260621-27.0-27.0.0/dispatch_dispatch_primitives.json
```

These define the macOS-27 servicing invariants: a `DISPATCH_SOURCE_TYPE_MACH_RECV`
source fires on port readiness and its handler services (receives) the message
via `mach_msg(MACH_RCV_MSG)`; the global queue completes work via TWQ workers;
dispatch primitives are serviced.

## Comparison + classification

**Classification: `match` at the servicing-invariant level.**

rmxOS services a Mach-receive event through dispatch + TWQ workqueues
(`BLOCK078_NOTIFYD_TWQ_TRACE` + `BLOCK078_NOTIFYD_ROUNDTRIP` + clean
hard-stop), which matches the macOS-27 servicing invariant recorded in the
mx-a64z dispatch reference. This validates op-081-R's MACH_RECV sub-fix on the
rmxOS runtime.

Arch/load-divergent fields (`kern.twq.threads_created` counts, `elapsed_ns`,
port-delta) are treated as expected-divergence, not mismatch (no such fields
are compared here — the smoke emits status markers, not those counters).

## Coverage caveat (important for op-085 / the Gatekeeper)

This is **runtime-smoke evidence** (block-078 status markers), not field-level
`nx-r64z.macos-oracle.v1` JSON vectors for the three macos-validation dispatch
probes (`dispatch_mach_recv_source`, `dispatch_global_queue_service`,
`dispatch_primitives`). The block-078 runbook does not stage or run those
probes, so:

- No rx-x64z `dispatch_*` JSON result files were produced in-guest.
- A field-by-field JSON diff vs the mx-a64z `dispatch_*.json` was therefore
  **not** performed.

The servicing invariant itself is proven on rx; the JSON-level coverage is
pending a macos-validation-dispatch in-guest staging (a separate procedure from
the block-078 runbook). If op-085 requires the rx `dispatch_*.json` vectors, that
staging must be issued as its own op.

## Version-sensitive flags

None from this run.
