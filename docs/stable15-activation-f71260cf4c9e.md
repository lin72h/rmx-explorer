# Stable/15 Activation Record f71260cf4c9e

Activation commit:

- `15b5bdd04255 stable15: activate candidate env default`

Default profile:

- `NXPLATFORM_BASE_PROFILE` unset now resolves to `stable15-active`.
- `stable15-active` points to `/Users/me/wip-mach/freebsd-src-official-stable-15`.
- Required source commit: `f71260cf4c9e`.
- Required objdir prefix: `/Users/me/wip-mach/build/official-stable15-mach-obj`.
- `official-stable15-candidate` remains an alias for the same source, commit, and objdir.
- `releng151-current` remains an accepted explicit fallback.

## Env-Check Summary

Validation after activation:

- `mix compile --warnings-as-errors`: pass
- `mix test`: pass, 37 tests
- `mix format --check-formatted`: pass
- `git diff --check`: pass

Env matrix:

- default `stable15-active`: pass on `current-tree`, `launchd`, `dispatch`, `libthr`
- explicit `stable15-active`: pass
- `official-stable15-candidate` alias: pass
- explicit `releng151-current`: pass
- default profile with releng151 objdir: fail as expected
- default profile with `/usr/obj`: fail as expected
- `stable15-active` with releng source: fail as expected
- `stable15-active` with releng151 objdir: fail as expected
- `official-stable15-candidate` with releng151 objdir: fail as expected
- unknown profile: fail as expected

Default launchd env-check emitted:

- `accepted_source_profile=stable15-active`
- `source_pin_id=stable15-active`
- `freebsd_src=/Users/me/wip-mach/freebsd-src-official-stable-15`
- `freebsd_src_commit=f71260cf4c9e`
- `expected_freebsd_src_commit=f71260cf4c9e`
- `kernel_objdirprefix=/Users/me/wip-mach/build/official-stable15-mach-obj`

## Guardrails

- No guest runs were performed for activation.
- No certification claim is made.
- No `certification/` directory was created.
- No repo-local `artifacts/` directory was created.
- No source mutation or deletion was performed.
- No path rename was performed.
- `oracle-parity-a30ef3f` was not moved.
- Existing evidence under `priv/runs/` was not deleted or mutated.

## Rollback Path

Rollback remains:

- profile: `releng151-current`
- source: `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- required source HEAD, checked out-of-band before rollback use: `d4876c3fd9af`
- objdir: `/Users/me/wip-mach/build/releng151-mach-obj`

Rollback execution, if needed, must restage or rebuild the rollback guest image from the frozen nested source and rerun minimal D14. This activation record does not execute rollback.
