# op-102 resume — rx vs mx conformance diff: MATCH (9/9, zero mismatch) + data/io gap catalog

Date: 2026-06-23. Lane: `rmx-explorer-rx-x64z`.

## Conformance diff result

| case | rx-x64z | mx-a64z (op-103 truth) | verdict |
|---|---|---|---|
| async (block + _f) | PASS | PASS | match |
| sync (block + _f) | PASS | PASS | match |
| apply (block + _f) | PASS | PASS | match |
| once (block + _f) | PASS | PASS | match |
| barrier (block + _f) | PASS | PASS | match |
| group (block + _f) | PASS | PASS | match |
| semaphore (block + _f) | PASS | PASS | match |
| source-timer (NORMAL) | PASS | PASS | match |
| source-MACH_RECV | PASS | PASS | match |

**VERDICT: MATCH — 9/9, zero semantic mismatch.** Both sides `op102_matrix_fails=0`.

rx serial sha: `a1b4e7c0ae61eefab5fb9f421b769d21e9934b9201d9d1a0a45834ab7b9819ce`.
mx truth: op-103 (commit 6d02846, `macos-truth-op102-matrix.json`).

## Harness fix applied (op-103 finding 1)

`dispatch_once_f` was passed `cb_add` (`void(*)(void*,size_t)`) — incompatible with
`dispatch_function_t` (`void(*)(void*)`). macOS clang 17 rejects under
`-Werror=incompatible-function-pointer-types`; the pass was incidental UB. Split a
dedicated `cb_once(void *c)` (1-arg). Confirmed: rx once=block=PASS f=PASS after fix.

## Data/io matrix gap (op-103 finding 2 — cataloged)

`dispatch_data` and `dispatch_io` are **absent on both sides** (rx + mx). They are
**not-yet-covered**, not implied-green. The conformance truth scopes to the 9-case
core subset. A future pass-2 op would add data/io coverage.

## bl-009 note

The single-shot run did not trigger the bl-009 kernel panic (use-after-free in
`ipc_mqueue_pset_receive` via `filt_machport`). bl-009 is intermittent — manifests
under sustained create/destroy cycles (the op-105 soak hit it on iteration 1; the
op-104 proof ran 451 iterations without). Single-shot MACH_RECV is green here.
