# Post-Final Parent GPT Review Resolution

Date: 2026-05-12

## Scope

This note records the cleanup applied after the parent GPT review of
`final-preimplementation-plan.md`.

Implementation is still limited to Stage 1-2:

- Stage 1: repository skeleton and shell/Make harness
- Stage 2: common C helpers and schema-emitting `foundation/smoke.c`

## Resolved Findings

1. Result directory naming now has a non-macOS development fallback.

   - macOS hosts use:
     `macos-validation/results/<agent>/<date>-<macos-version>-<darwin-version>/`
   - rx/rmxOS or other non-macOS development hosts use:
     `macos-validation/results/<agent>/<date>-<os-name>-<kernel-version>/`
   - `collect_env.sh` may emit `result_dir_name` so `run_all.sh` does not
     duplicate OS parsing logic.

2. The required environment floor is now explicit in the final JSON example.

   It includes host identity, compiler, SDK, SIP/sandbox/root status, signing,
   architecture/CPU feature details, Apple-Silicon-specific fields, Rosetta
   status, result-directory naming fields, and null/false Zig fields for C-only
   probes.

3. JSON validation now requires `python3` for Stage 1-2.

   `validate_json.sh` must parse JSON and check required fields with `python3`.
   `jq` may be used only for optional diagnostics. If `python3` is unavailable,
   validation reports an explicit toolchain failure or skip and exits
   non-success.

4. Probe output is pinned to stdout JSON plus stderr diagnostics.

   Every probe emits exactly one JSON object to stdout. Diagnostics, progress,
   and errors go to stderr or a separate harness log. `run_all.sh` captures
   stdout into result files.

5. Build outputs now have a defined location.

   Binaries and objects live under `macos-validation/.build/`. Source
   directories are not used for compiled or signed binaries. `make clean`
   removes only `.build/`.

6. Signing records now have a concrete format.

   `sign_probe.sh <binary>` returns 0 on success and 1 on failure, printing
   exactly one stdout line:

   - `signed: <path>`
   - `sign_failed: <path>`

   Once `nx_env` exists, the harness records per-binary signing status as
   `{path, status, return_code, output}`.

## Files Updated

- `final-preimplementation-plan.md`
- `comprehensive-nx-v64z-macos-oracle-plan.md`
- `implementation-readiness-summary.md`

## Current Go/No-Go

Go for Stage 1-2.

The remaining open questions are Stage 3+ probe semantics or later Elixir
migration concerns and do not block the repository skeleton, harness, common C
helpers, or smoke pipeline.
