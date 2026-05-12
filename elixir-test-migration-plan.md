# Elixir Test Migration Plan

Date: 2026-05-12

## Purpose

Move the existing Elixir/ExUnit tests from the parent planning repository into
the oracle repository so the same harness-level checks can run on:

- `rx` / rmxOS local development lane
- `mx-x64z` Intel macOS oracle runner
- `mx-a64z` Apple Silicon macOS oracle runner

This migration is for harness, parser, fixture, and comparison tests. It is not
for low-level Mach message construction. Low-level Mach IPC probes remain native
C by default in the macOS oracle lane, with Zig used only when source sharing or
exact ABI/layout control is required.

## Parent Decisions Already Recorded

- The first oracle implementation remains shell/Make plus C probes.
- Elixir comparison/report generation comes after both macOS result sets and
  the NextBSD/rxOS result set exist.
- The result schema does not define a separate architecture class. Intel
  versus Apple Silicon disagreement uses `version_sensitive` with explicit
  architecture notes unless the parent later expands the schema.
- Curated summary JSON fixtures and findings notes may be committed. Raw logs
  stay outside git unless a raw fixture is specifically useful.
- macOS default test runs must not require bhyve, doas, FreeBSD guest images,
  SIP changes, private entitlements, or full donor checkouts.

## Current Source Tests

Existing Elixir tests in `/Users/me/wip-mach/wip-gpt`:

| Source | Current role | Migration class |
| --- | --- | --- |
| `mix.exs` | Minimal Mix project | Copy and adapt |
| `test/test_helper.exs` | Starts ExUnit | Copy |
| `test/bhyve_scripts_test.exs` | Tests serial parsers, characterization parser, bhyve dry-run scripts, crash collection, donor inventory scripts | Split into portable and `rx`-only groups |
| `test/donor_mach_tests_test.exs` | Checks donor NextBSD Mach test sources exist and contain expected APIs | Convert to optional donor-root integration tests plus portable fixture/manifest tests |

Current local problem:

- `mix test` fails on the current machine because the installed Elixir build
  requires newer Erlang/OTP than OTP 26.
- The first migration task must capture `elixir --version` and `erl -version`
  on every host and pin a working Elixir/Erlang pairing before treating failures
  as test failures.

## Target Repository Layout

Add this structure under `/Users/me/wip-mach/wip-gpt-oracle`:

```text
.
  mix.exs
  test/
    test_helper.exs
    support/
      host_capabilities.ex
      fixture_paths.ex
    harness/
      parse_serial_test.exs
      parse_characterize_test.exs
      oracle_json_schema_test.exs
      env_capture_test.exs
    rx/
      bhyve_script_contract_test.exs
      donor_inventory_script_test.exs
    donor/
      donor_mach_manifest_test.exs
      donor_root_integration_test.exs
  fixtures/
    serial/
      clean_probe.log
      malformed_probe.log
      failing_probe.log
      panic_probe.log
    characterize/
      matching_trap.log
      witness_diagnostic.log
      unmatched_result.log
    donor/
      donor-mach-required-paths.txt
      donor-mach-required-fragments.json
  tools/
    parsers/
      parse-serial.py
      parse-characterize.py
```

Do not copy large raw logs, VM images, crash dumps, or full donor trees into the
oracle repo.

## Test Classification

Use explicit ExUnit tags so macOS runners do not accidentally execute FreeBSD
or bhyve-specific checks.

| Tag | Meaning | Runs on `rx` | Runs on `mx-*` |
| --- | --- | --- | --- |
| `:portable` | Pure host-side parser/schema/fixture test | yes | yes |
| `:macos_oracle` | Validates macOS oracle package behavior | optional | yes |
| `:rx_only` | Requires rmxOS/FreeBSD local assumptions | yes | no |
| `:requires_bhyve` | Requires bhyve, doas, FreeBSD VM images, or guest staging | yes, when configured | no |
| `:requires_nextbsd_root` | Requires a real NextBSD donor checkout | yes, when configured | optional, normally no |
| `:fixture_only` | Uses curated fixtures instead of full donor checkout | yes | yes |

Default commands:

```sh
# portable oracle test floor, used by macOS runners
mix test --exclude rx_only --exclude requires_bhyve --exclude requires_nextbsd_root

# local development full-ish run, still dry-run unless env enables external deps
mix test

# explicit donor checkout integration
NX_NEXTBSD_ROOT=/path/to/NextBSD mix test --only requires_nextbsd_root
```

## Migration Stages

### Stage 0: Toolchain Gate

Before moving tests, add a short environment capture step:

- `elixir --version`
- `erl -version`
- `mix --version`
- host OS and architecture

Acceptance:

- The oracle repo records the Elixir/Erlang versions in test output or an
  environment JSON.
- The current OTP mismatch is treated as a toolchain blocker, not as a project
  test failure.

### Stage 1: Copy The Minimal Mix Skeleton

Copy and adapt:

- `mix.exs`
- `test/test_helper.exs`

The Mix project should remain dependency-free at first. Do not add JSON, YAML,
or CI dependencies until a standard-library path is proven insufficient.

Acceptance:

- `mix test --exclude rx_only --exclude requires_bhyve --exclude requires_nextbsd_root`
  starts cleanly on `rx`, `mx-x64z`, and `mx-a64z`.

### Stage 2: Move Portable Parser Tests

From `test/bhyve_scripts_test.exs`, migrate these as portable tests:

- `parse-serial accepts a clean probe section`
- `parse-serial rejects missing start marker`
- `parse-serial rejects malformed JSON inside complete probe section`
- `parse-serial reports failing probe records`
- `parse-characterize summarizes matching trap start and result records`
- `parse-characterize records witness diagnostics without failing the run`
- `parse-characterize reports pending trap-start records as panic when end marker is missing`
- `parse-characterize rejects unmatched trap-result records`

Copy the parser scripts into `tools/parsers/` or rewrite them only if the parent
explicitly approves. The first move should preserve behavior.

Acceptance:

- These tests pass on macOS with stock `python3`.
- If macOS lacks `python3`, tests report a clear skip or toolchain failure. They
  must not silently pass.

### Stage 3: Quarantine Bhyve-Specific Tests

From `test/bhyve_scripts_test.exs`, keep these as `rx`-only contract tests:

- `stage-guest dry-run works without build artifacts when installation is disabled`
- `stage-guest rejects unknown arguments`
- `run-guest dry-run emits the bhyve command sequence without launching a VM`
- `collect-crash dry-run reports explicit crash source and destination`

These tests should not run on macOS by default. macOS can still validate that the
test definitions are present, but not that bhyve exists.

Acceptance:

- `mx-*` runs exclude these tests.
- `rx` dry-run checks still pass when the original scripts are present.

### Stage 4: Split Donor Inventory And Donor Source Tests

From `test/bhyve_scripts_test.exs`, migrate:

- `classify-donor rejects a missing donor root`
- `classify-donor produces a Markdown inventory for a minimal donor fixture`
- `nextbsd-history rejects a missing git checkout`

These can run on macOS if the scripts avoid FreeBSD-specific utilities. If a
script is not portable, make the portability failure explicit and keep it
`rx_only` until fixed.

From `test/donor_mach_tests_test.exs`, do not require a full donor checkout for
the default macOS run. Instead:

1. Create fixture or manifest tests that verify the expected donor paths and
   required source fragments are tracked by the oracle package.
2. Keep the full donor checkout test behind `:requires_nextbsd_root`.
3. Use `NX_NEXTBSD_ROOT` instead of hard-coded `../nx/NextBSD`.

Acceptance:

- Portable donor manifest tests pass on macOS without a donor checkout.
- Full donor source tests run only when `NX_NEXTBSD_ROOT` is set.

### Stage 5: Add Oracle JSON Schema Tests

Add ExUnit tests for the `nx-v64z.macos-oracle.v1` result floor:

- required top-level fields exist
- `status` is one of the allowed values
- `semantic_class` is one of the allowed values
- `environment` contains SDK, compiler, signing, SIP/sandbox, and Zig fields
- C-only probe results set Zig fields to explicit `null` / `false`
- raw Mach port names are never used as comparison gates
- architecture-specific host disagreement is represented as `version_sensitive`
  plus explicit architecture notes

This is the first new oracle-specific Elixir work.

Acceptance:

- The schema test can validate sample JSON fixtures from both macOS runners.
- The schema classification set matches `nx-v64z.macos-oracle.v1`.

### Stage 6: Add Cross-Host Comparison Tests

After `mx-x64z` and `mx-a64z` produce real or fixture JSON:

- compare test IDs across both hosts
- detect missing host result files
- classify agreement, version-sensitive difference, privilege-sensitive
  difference, and probe failure
- record Intel versus Apple Silicon disagreement as `version_sensitive` with
  explicit architecture notes
- generate a concise Markdown finding for parent review

This is where Elixir becomes valuable: orchestration, classification, and report
generation. Do not use Elixir to build Mach messages.

Acceptance:

- A fixture pair can produce a deterministic comparison report.
- Real macOS result files can be dropped into `results/mx-x64z/` and
  `results/mx-a64z/` without changing test code.

## Migration Rules

1. Preserve behavior first. Do not rewrite parser logic while moving it.
2. MacOS runners must not require bhyve, doas, FreeBSD guest images, SIP changes,
   private entitlements, or donor checkouts for the default test floor.
3. Optional integration tests must be controlled by env vars and ExUnit tags.
4. Host-specific skips must be visible in test output.
5. Raw logs and bulky artifacts stay outside git. Commit curated fixtures only.
6. Existing donor C tests stay native. Elixir validates harness behavior and
   source coverage; it does not replace native C/Mach tests.
7. Low-level Mach IPC oracle probes stay C-first, Zig-only when justified.

## Parent Decisions Needed

1. Confirm whether the oracle repo should copy `parse-serial.py` and
   `parse-characterize.py`, or import them from the parent repo during local
   development.
2. Confirm whether `classify-donor.sh` and `nextbsd-history.sh` should become
   portable oracle tools or remain parent-only scripts tested from the parent.
3. Confirm the minimum supported Elixir/Erlang versions for `rx`, `mx-x64z`,
   and `mx-a64z`.

## First Implementation Order

1. Capture the current Elixir/Erlang toolchain mismatch, then fix or pin the
   toolchain so `mix test` can run.
2. Add `mix.exs`, `test/test_helper.exs`, and host capability helpers to the
   oracle repo.
3. Copy parser scripts and migrate parser tests with fixtures.
4. Add tags and skip policy.
5. Add oracle JSON schema tests.
6. Quarantine bhyve dry-run tests behind `:rx_only`.
7. Convert donor source checks to fixture/manifest plus optional
   `NX_NEXTBSD_ROOT` integration.
8. Run the portable floor on both macOS agents.
9. Only then add Elixir comparison/report generation for real oracle results.

## Completion Criteria

The migration is complete when:

- portable ExUnit tests pass on `rx`, `mx-x64z`, and `mx-a64z`
- `rx_only` and `requires_bhyve` tests are not run by default on macOS
- donor-root tests are optional and env-gated
- parser behavior is preserved from the parent repo
- oracle result schema fixtures are validated
- the test output clearly distinguishes pass, skip, toolchain failure, and
  unsupported host capability
