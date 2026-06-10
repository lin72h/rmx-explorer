STATUS: Draft / Awaiting Review
GATES: M1 implementation is blocked until this design is accepted.

# M1 Oracle Migration Design

Date: 2026-06-04

M0 is accepted as the migration gate at `docs/migration-m0-inventory.md`.

M1 remains design-only until this document is accepted. This document does not approve implementation, does not approve source import, and does not resolve the open provenance decision.

## Scope

M1 is the first implementation step for making the oracle repository the canonical Elixir + Zig test home.

### Source Responsibility Boundary

Oracle is the test, exploration, gate-contract, validator, falsifier, evidence,
and marker-authority repository. It has read-only access to
`/Users/me/wip-mach/wip-gpt` and may validate only committed source pins.
Oracle must never create, modify, delete, move, stage, or commit source-repo
files.

Missing product/runtime, build, staging, source-test, or source-documentation
behavior is a source requirement, not an Oracle implementation task. Oracle
must stop and report the smallest falsifiable source requirement for the source
implementation agent. Oracle probes, fixtures, stubs, and validators must
never substitute for rmxOS product implementation.

The normative policy is
[`source-oracle-responsibility-boundary.md`](source-oracle-responsibility-boundary.md).

M1 must not:

- copy `scripts/` wholesale
- import Python or shell as canonical code
- start a stable/15 base update
- add new feature gates
- delete anything from `wip-gpt`
- treat `wip-gpt` as obsolete before Elixir/Zig parity exists
- migrate C/Zig probes before the canonical Zig layout is accepted
- introduce BEAM native-extension or in-process native helper dependencies
- create BEAM native-extension or in-process native helper scaffolding
- add a deferred native-extension spike to M1

M1 must support either provenance path:

- Path A, preferred: commit pending `pending_fix` test/framework changes in `wip-gpt`, refresh M0 against the committed SHA, then implement M1.
- Path B, historical exception: explicitly approve exact uncommitted working-tree bytes by the accepted M0 manifest SHA, then implement M1.

Path A was selected and completed for M1. Source responsibility policy commit
`e6dfa40` now supersedes Path B: Oracle may validate only committed source
pins, and `manifest-approved` dirty source bytes are no longer an available
provenance path.

Current M0 manifest SHA:

```text
e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298
```

## Native Integration Boundary

M1 and M6 use a strict out-of-process native integration model.

Canonical split:

- standalone Zig binaries are the canonical native probe format
- Elixir owns orchestration, verification, manifests, artifact parsing, and certification logic
- Zig probes run as standalone executables under Elixir orchestration
- probe results are exchanged through explicit process output, result files, or future documented artifact contracts

Out of scope for M1:

- BEAM NIFs
- dirty NIFs
- BEAM port drivers
- linked-in shared libraries loaded by BEAM
- in-process native helper dependencies
- in-process native helper scaffolds
- deferred BEAM native-extension spikes

Any host-side native helper outside standalone probe binaries requires a separate future design decision before it can be added.

## Evidence Ladder Test Strategy

rmxOS low-level testing uses an evidence ladder, not a web-app test pyramid. ExUnit validates the Elixir harness itself, but ExUnit green is table stakes, not platform evidence.

### L0 - Compile-Time ABI/Layout

Zig comptime checks validate structs and message layouts that cross ABI boundaries.

Rules:

- same-arch only
- same source tree, headers, compiler, and build flags as the artifact under test
- emit a hashable ABI snapshot artifact containing offsets, sizes, alignments, compiler identity, and header/source hashes
- cross-arch layout comparison is invalid

### L1 - Host Semantic Probes

Standalone Zig binaries run as separate host processes.

Rules:

- used for cheap parser, encoder, and normalizer checks
- explicit exit code and structured output
- does not certify kernel behavior

### L2 - Guest Integration Probes

L2 is the authoritative rx-x64 behavior proof inside bhyve against real `mach.ko`, launchd, libdispatch, and libthr.

Rules:

- center of gravity for accepted platform claims
- guest boot identity must be proven first: kernel/module/version/hash marker before claim markers are trusted
- serial log, guest return code, positive markers, and artifacts are authoritative
- exit 0 alone is never PASS
- panic, WITNESS, KASSERT, fatal trap, and timeout are hard stops
- donor-C probes are provisional unless corroborated by Zig parity or explicitly approved as donor reference evidence

### L3 - macOS Semantic Oracle

L3 is semantic comparison against `mx-a64` and lower-cadence `mx-x64`.

Rules:

- flags mismatch; never directly blocks certification
- semantic-only across architectures
- layout and absolute timing are non-authoritative
- mismatches trigger human review only
- regression is temporal and belongs to golden baseline history, not L3 classification alone

### L4 - Fuzz / Property / Soak

L4 is used after deterministic gates exist.

Rules:

- fuzz parsers and decoders, and minimize artifacts
- stress concurrency through invariants, not exact interleaving
- critical-gate flakes are red, not quarantine candidates
- soak repeats L2 gates to find timing bugs, leaks, hangs, and nondeterminism

### Cross-Layer Requirements

Every accepted claim must declare:

- minimum satisfying layer
- positive markers
- negative control or known-bad case
- golden baseline artifact or approved-diff policy
- required hard-stop denylist version
- provenance fields
- whether donor-C evidence is sole, provisional, or corroborated

Certification PASS requires:

- positive evidence on the good path
- paired negative control has been shown to fail
- no hard-stop patterns
- baseline match or approved diff
- artifact provenance keyed by rx base commit, harness hash, ledger hash, env values, guest image hash, probe hash, and compiler identity where relevant

### Evidence Anti-Patterns

Refuse:

- mocking the primitive under test
- exit-0-only PASS
- silence-as-success
- harness-only green
- cross-arch layout oracle
- in-process native helpers in certification paths
- tautological probes that always print PASS
- exact interleaving assertions for concurrent behavior
- guest, objdir, serial, or VM-sharing gates run concurrently when they share state
- donor-C as sole authority without explicit provisional status or parity plan

### M1 Evidence Scope Boundary

M1 scaffolds this model; it does not implement every layer.

M1 should provide:

- Elixir project and env/path validation
- manifest and dependency-edge files
- claim/evidence schema fields needed later for layer binding, negative controls, baselines, and provenance
- canonical Zig probe layout
- no shell/Python canonical runner
- no stable/15 update
- no source deletion
- no new feature gates

M1 still does not create `certification/` or `certification/claims/`. Claim/evidence schema fields introduced during M1 are schema scaffolding only, not accepted certification claims.

## 1. Oracle Mix Project Shape

Decision: create an oracle-owned `mix.exs`. Do not copy the existing `wip-gpt/mix.exs` as-is.

Reason:

- the source Mix app is `:nxplatform_wip`
- the oracle repo is becoming a separate test/probe/certification home
- copying the source app name would carry source-workspace identity into the oracle workspace

Proposed app:

```elixir
app: :rmxos_oracle
```

Toolchain baseline:

```elixir
elixir: "~> 1.20"
```

Required toolchain:

```text
Elixir 1.20.0
OTP 29
```

No backward compatibility with older Elixir/OTP is required unless parent later asks.

Proposed top-level namespace:

```text
RmxOSOracle
```

Initial module areas:

| namespace | responsibility |
| --- | --- |
| `RmxOSOracle.Manifest` | M0/M1 manifest hashing, drift reports, target-action policy |
| `RmxOSOracle.Env` | environment loading and lane-sensitive validation |
| `RmxOSOracle.Paths` | repo/workspace/source/objdir path resolution |
| `RmxOSOracle.Fixtures` | fixture inventory and fixture validation |
| `RmxOSOracle.Dependency` | verifier dependency-edge tracking |
| `RmxOSOracle.Evidence` | evidence ladder schema fields for future claims and run artifacts |
| `RmxOSOracle.Guest` | future guest staging/running, after shell ports |
| `RmxOSOracle.Zig` | future Zig probe build/run orchestration |

Mix task namespace:

```text
Mix.Tasks.Oracle.Manifest.Check
Mix.Tasks.Oracle.Env.Check
Mix.Tasks.Oracle.Dependency.Derive
Mix.Tasks.Oracle.Dependency.Audit
```

Handling `:nxplatform_wip`:

- `:nxplatform_wip` remains the source repo app identity during migration.
- The oracle repo does not use `:nxplatform_wip` as its app name.
- Old verifier file names, gate names, and observable labels are not broadly renamed during M1.
- Imported self-contained modules may keep existing module names such as `Phase08.SourceTransform` during M1 to avoid gate churn.

Hard rule: no broad verifier/gate renames during M1. Rename work, if any, is a later mechanical cleanup after parity.

## 2. Manifest Preflight

M1 must implement an Elixir-owned manifest preflight before any source import or canonical import work.

Bootstrap order:

1. Create the minimal oracle Mix scaffold needed to run Mix tasks.
2. Create `priv/manifests/m0_legacy_source_test_manifest.json` from the accepted M0 snapshot, or from a refreshed parent-accepted Path A manifest.
3. Implement the manifest preflight task.
4. Run the manifest preflight against the source tree.
5. Import fixtures or self-contained Elixir only after preflight passes.

This exception is only for minimal oracle-owned scaffolding and the machine-readable manifest. It does not permit copying source tests, fixtures, scripts, probes, or donor payloads before preflight passes.

The preflight must not scrape Markdown as its primary data source. M1 creates and uses:

```text
priv/manifests/m0_legacy_source_test_manifest.json
```

The M0 Markdown file remains the human review artifact. The JSON file is the machine preflight source.

Proposed command:

```sh
mix oracle.manifest.check --source /Users/me/wip-mach/wip-gpt --expected-sha e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298
```

Optional flags:

```text
--mode committed
--mode manifest-approved
--manifest priv/manifests/m0_legacy_source_test_manifest.json
--format text|json
```

Design behavior:

1. Read `priv/manifests/m0_legacy_source_test_manifest.json`.
2. Recompute the manifest from the supplied source path.
3. Exclude generated/runtime artifacts unconditionally:
   - `__pycache__/`
   - `*.pyc`
4. Hash exactly:
   - `mix.exs`
   - `test/`
   - `scripts/`
   - `fixtures/`
5. Compare the recomputed manifest SHA with `--expected-sha`.
6. Report drift per path:
   - added
   - removed
   - modified
   - mode/type change if observable
7. Join each path with M0 classification:
   - language
   - role
   - target action
   - canonical
   - dirty classification when applicable
   - complexity
   - contains embedded awk
8. Apply M0 drift policy.
9. Exit nonzero before any source import or canonical import if drift violates policy.

Mode enforcement:

- `--mode committed` implements Path A. It requires `source_sha` in the manifest to match `git -C <source> rev-parse --short HEAD`, and every imported/canonical file must match committed source bytes or explicitly approved generated output. Relevant copy-set drift must fail before import.
- `--mode manifest-approved` documents the superseded Path B design only. It
  must not be used after source responsibility policy commit `e6dfa40`.
- Oracle import and validation use `--mode committed` only.

Required manifest JSON fields per file:

```json
{
  "path": "scripts/bhyve/compare-m2-oracle.py",
  "size": 17396,
  "sha256": "02b63062306eed8b9ab0c37d77b49ea68aa1635929fee04dd5013bbf59c3eef8",
  "lines": 484,
  "language": "python",
  "role": "legacy oracle comparison tool",
  "target_action": "port_to_elixir",
  "canonical": false,
  "dirty_classification": null,
  "complexity": "medium",
  "contains_embedded_awk": false
}
```

The manifest JSON top level should include:

```json
{
  "schema": "rmxos_oracle.legacy_source_test_manifest.v1",
  "source_root": "/Users/me/wip-mach/wip-gpt",
  "source_sha": "a30ef3f",
  "manifest_sha256": "e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298",
  "files": []
}
```

Canonical manifest digest recipe:

- Per-file `sha256` is SHA-256 over the exact raw file bytes on disk, with no newline, encoding, or line-ending normalization.
- Generated/runtime artifacts are excluded before manifest construction.
- Directory traversal is deterministic: file paths are sorted lexicographically by UTF-8 byte sequence using `/` separators.
- Manifest JSON is canonicalized before computing `manifest_sha256`.
- The digest input is the canonical JSON object with the top-level `manifest_sha256` field omitted.
- Object keys are sorted lexicographically at every level.
- Arrays keep semantic order; `files` is sorted by `path`.
- JSON is UTF-8, compact, and has no insignificant whitespace.
- The canonical JSON digest input has no trailing newline.
- Hash function is SHA-256.
- Hex digest uses lowercase hexadecimal.

The original M0 digest method is not independently recoverable from this Markdown document alone. M1 must therefore perform a discovery step:

1. Try to reproduce the accepted M0 digest from the accepted M0 snapshot and any generator notes or scripts available in history.
2. If reproduction fails, replace it with the stable canonical recipe above.
3. If the digest is replaced, parent must approve the new canonical manifest digest before any import.

Manifest preflight must include a round-trip self-test: read the committed JSON file, remove/ignore `manifest_sha256`, canonicalize it with the recipe above, recompute SHA-256, and require the result to match the expected digest.

Drift policy implemented by M1:

| path class/action | drift behavior |
| --- | --- |
| `keep_fixture` | blocks M1 unless reclassified and approved |
| `keep_elixir` | blocks M1 unless reclassified and approved |
| `keep_donor_payload_reference` | blocks M1 unless reclassified and approved |
| `pending_fix` | allowed only after it is committed and the manifest is refreshed |
| `docs_only` | does not block M1 |
| `transient` | does not block M1, but must not be imported |
| `unknown` | blocks M1 |
| `exclude_generated` | never imported; ignored for manifest hash |
| added file with no M0 classification | blocks M1 until classified and approved |
| removed `keep_elixir`, `keep_fixture`, or `keep_donor_payload_reference` | blocks M1 |
| removed `docs_only` or `transient` | does not block unless referenced by an import or dependency edge |

Preflight output should include a machine-readable JSON option. Proposed shape:

```json
{
  "status": "pass",
  "source": "/Users/me/wip-mach/wip-gpt",
  "expected_sha": "e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298",
  "actual_sha": "e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298",
  "drift": [],
  "policy_failures": []
}
```

The preflight must make clear whether it is validating a committed source SHA or explicitly approved working-tree bytes.

## 3. Environment Model

Decision: use a pure Elixir-owned environment validator.

M1 must not create `certification/`. Certification authority scaffolding remains deferred until the certification claims/evidence contract is defined.

Proposed M1 files, not implemented yet:

```text
lib/rmx_os_oracle/env.ex           # RmxOSOracle.Env
lib/rmx_os_oracle/paths.ex         # RmxOSOracle.Paths
lib/mix/tasks/oracle.env.check.ex
priv/env/
  env.example
  env.local                         # gitignored, not committed
priv/runs/
  m1-env-check/                     # generated env-check JSON output, not certification evidence
```

No canonical shell runner is introduced. A shell compatibility shim may be considered later only if parent explicitly needs shell interop, and it must remain non-canonical.

`priv/env/env.local`:

- machine-specific
- gitignored
- not copied from source
- may be shell-like `KEY=VALUE` lines if parsed by Elixir

Required variables:

```sh
NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach
NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15
```

Donor/reference roots, required only when donor or reference material is consumed:

```sh
NXPLATFORM_DONOR_MACH_TESTS_ROOT=/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
NXPLATFORM_DONOR_LIBMACH_TEST_ROOT=/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
NXPLATFORM_DONOR_XPC_TESTS_ROOT=/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

Donor/root validation rules:

- path is absolute
- path exists
- no silent fallback to source-repo-relative or oracle-repo-relative donor paths
- symlinks are rejected unless parent explicitly approves the symlink; when approved, both literal path and resolved realpath are recorded
- any used donor/reference root is recorded in future run artifact provenance

Lane-specific objdir prefix is a configured input, not a canonical M1 default. Values must come from `priv/env/env.local`, caller environment, or an explicit lane configuration record.

Required lane configuration keys:

```sh
NXPLATFORM_KERNEL_OBJDIRPREFIX_CURRENT_TREE=<absolute objdir prefix for current-tree lane>
NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD=<absolute objdir prefix for launchd lane>
NXPLATFORM_KERNEL_OBJDIRPREFIX_DISPATCH=<absolute objdir prefix for dispatch lane>
NXPLATFORM_KERNEL_OBJDIRPREFIX_LIBTHR=<absolute objdir prefix for libthr lane>
```

Observed legacy defaults, recorded only as provenance:

| lane | observed legacy default | canonical? |
| --- | --- | --- |
| `launchd` | `${NXPLATFORM_WORKSPACE_ROOT}/build/releng151-mach-obj` | no |
| `current-tree` | `${NXPLATFORM_WORKSPACE_ROOT}/build/releng151-rc1-mach-obj` | no |
| `dispatch` | `/usr/obj` | no |
| `libthr` | `/usr/obj` | no |

These values document the current legacy verifier behavior. They must not be treated as future canonical values, because M1 must be stable/15-ready by configuration while the actual stable/15 base update remains a later Base-Certification Lane step after the harness is frozen.

Legacy env projection:

- `RmxOSOracle.Env` resolves the lane-specific prefix from `--lane`.
- `RmxOSOracle.Paths` validates the resolved lane prefix.
- Any runner that invokes a legacy verifier passes the resolved value to that process as `NXPLATFORM_KERNEL_OBJDIRPREFIX`.
- The lane-suffixed variables are oracle configuration inputs; `NXPLATFORM_KERNEL_OBJDIRPREFIX` is the legacy runtime projection consumed by existing verifiers.
- M1 does not call a legacy verifier unless this projection is explicit in the invocation plan.

M1 validator command:

```sh
mix oracle.env.check --lane launchd
mix oracle.env.check --lane current-tree
mix oracle.env.check --lane dispatch
mix oracle.env.check --lane libthr
```

Validation requirements:

- `NXPLATFORM_WORKSPACE_ROOT` is absolute and exists.
- `NXPLATFORM_FREEBSD_SRC` is absolute.
- `NXPLATFORM_FREEBSD_SRC` exists.
- `NXPLATFORM_FREEBSD_SRC` is not a symlink.
- `NXPLATFORM_FREEBSD_SRC` equals the canonical local path `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` unless parent explicitly approves an override.
- `NXPLATFORM_FREEBSD_SRC` does not default to `wip-gpt-oracle/freebsd-src-stable-15`.
- lane-specific `NXPLATFORM_KERNEL_OBJDIRPREFIX_*` is selected by `--lane`.
- selected lane objdir prefix is absolute after `${NXPLATFORM_WORKSPACE_ROOT}` expansion.
- selected lane objdir prefix must come from explicit configuration; there is no built-in fallback to observed legacy defaults.
- selected lane objdir prefix is projected to `NXPLATFORM_KERNEL_OBJDIRPREFIX` for any legacy verifier invocation.
- objdir-sensitive checks reject missing or ambiguous lane prefix.
- resolved values are emitted as JSON for future run artifacts.
- no silent fallback to oracle-root source paths.

Future run artifacts should embed:

```json
{
  "workspace_root": "/Users/me/wip-mach",
  "freebsd_src": "/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15",
  "lane": "launchd",
  "kernel_objdirprefix": "/configured/objdir/prefix",
  "projected_env": {
    "NXPLATFORM_KERNEL_OBJDIRPREFIX": "/configured/objdir/prefix"
  },
  "base_profile": "stable15-candidate",
  "rmxos_source_commit": "<git sha>",
  "freebsd_src_is_symlink": false,
  "donor_roots": {}
}
```

## 4. Canonical Directory Layout

M1 should establish only directories it owns immediately. Do not create empty authority directories.

Proposed post-M1 shape:

```text
oracle-repo/
  mix.exs                         oracle-owned Mix project
  lib/
    rmx_os_oracle/
      manifest.ex
      env.ex
      paths.ex
      dependency.ex
      evidence.ex
      fixtures.ex
    mix/tasks/
      oracle.manifest.check.ex
      oracle.env.check.ex
      oracle.dependency.derive.ex
      oracle.dependency.audit.ex
    phase08/
      source_transform.ex          if imported
      marker_manifest.ex           if imported
      d23_core_generator.ex         if imported as candidate/reference
  test/
    phase08/
      source_transform_test.exs     if imported
  fixtures/
    launchd/
      *.plist
      *.json
  priv/
    env/
      env.example
      env.local                    gitignored, not committed
    manifests/
      m0_legacy_source_test_manifest.json
    dependencies/
      m0_dependency_edges.json
    runs/
      m1-env-check/                generated env-check JSON output
  zig/
    build.zig
    README.md
    probes/
      mach/
      dispatch/
      launchd/
      libthr/
```

Existing directories remain in place:

```text
macos-validation/
mx-a64z/
mx-x64z/
findings/
docs/
```

M2-only authorities:

```text
catalog/
mismatches/
certification/
certification/claims/
certification/tiers.yml
```

`certification/` is not created in M1. Env-check output under `priv/runs/m1-env-check/` is M1 validation output only; it is not certification evidence and does not seed the future certification authority namespace.

## 5. Fixture Import Scope

M1 may import safe fixture data after manifest preflight passes and provenance path A or B is approved.

Approved fixture patterns:

```text
fixtures/launchd/*.plist
fixtures/launchd/*.json
```

Expected fixture files from M0:

```text
fixtures/launchd/com.apple.notifyd.plist
fixtures/launchd/com.apple.syslogd.plist
fixtures/launchd/org.freebsd.devd.plist
fixtures/launchd/org.rmxos.phase08.d14.noop.plist
fixtures/launchd/org.rmxos.phase08.d15.json-rejected.json
fixtures/launchd/org.rmxos.phase08.d15.malformed.plist
fixtures/launchd/org.rmxos.phase08.d16.runatload.plist
fixtures/launchd/org.rmxos.phase08.d17.fast-exit.plist
fixtures/launchd/org.rmxos.phase08.d18.sigkill.plist
fixtures/launchd/org.rmxos.phase08.d18.sigterm.plist
fixtures/launchd/org.rmxos.phase08.d19.keepalive.plist
fixtures/launchd/org.rmxos.phase08.d20.successful-exit.plist
fixtures/launchd/org.rmxos.phase08.d21.remove.plist
fixtures/launchd/org.rmxos.phase08.d22.keepalive-remove.plist
fixtures/launchd/org.rmxos.phase08.d22.running-remove.plist
fixtures/launchd/org.rmxos.phase08.d23.inert-reload.plist
fixtures/launchd/org.rmxos.phase08.d23.keepalive-reload.plist
```

Fixture import rules:

- no generated/runtime artifacts
- no binaries in M1
- untracked fixture imports are blocked until committed and included in a refreshed manifest
- fixture validators belong in Elixir

## 6. Elixir Canonical Import Scope

M1 may import only self-contained Elixir modules/tests or Elixir modules whose non-canonical dependencies are explicitly tracked as blockers.

Recommended immediate canonical imports:

| source path | target path | dependency status | M1 status |
| --- | --- | --- | --- |
| `scripts/launchd/phase08_source_transform.exs` | `lib/phase08/source_transform.ex` | self-contained; standard library only | canonical after import and compile |
| `scripts/launchd/phase08_marker_manifest.exs` | `lib/phase08/marker_manifest.ex` | self-contained; standard library only | canonical after import and compile |
| `test/phase08_source_transform_test.exs` | `test/phase08/source_transform_test.exs` | depends only on imported `Phase08.*` modules | canonical after removing `Code.require_file` path coupling |
| `test/test_helper.exs` | `test/test_helper.exs` | trivial | canonical if still needed |

Candidate imports, not fully canonical in M1 without parity:

| source path | target path | dependency status | M1 status |
| --- | --- | --- | --- |
| `scripts/launchd/generate-phase08-d23-core.exs` | `lib/phase08/d23_core_generator.ex` or `lib/mix/tasks/oracle.phase08.d23.generate.ex` | depends on imported `Phase08.*`; reads/writes C donor source | parity/reference until output parity is proven |
| `test/donor_mach_tests_test.exs` | `test/donor/mach_tests_test.exs` | depends on external NextBSD donor tree | donor-reference verifier only after env path is explicit |

Defer from canonical M1:

| source path/group | reason |
| --- | --- |
| `test/bhyve_scripts_test.exs` | calls Python parsers and shell runners |
| `scripts/launchd/verify-phase08-d22-instrumentation-parity.exs` | depends on `link-launchd-harness.sh` |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | depends on shell build/stage/run pipeline |
| `scripts/dispatch/verify-phase07-*.exs` | needs dependency audit and shell convention removal |

A `keep_elixir` file is not fully canonical if it still calls shell/Python. Such files may be kept as parity/reference only until dependency edges are removed.

## 7. Shell/Python Port Plan

Shell and Python are not implemented in M1 as canonical code. They are grouped for future Elixir ports.

### Batch P1: Oracle Comparison And Parsers

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/bhyve/parse-serial.py` | `RmxOSOracle.Serial.Parser` | serial fixture logs | medium | golden log fixtures match Python output |
| `scripts/bhyve/parse-characterize.py` | `RmxOSOracle.Serial.CharacterizeParser` | serial fixture logs | medium | golden characterization fixtures match Python output |
| `scripts/bhyve/compare-m2-oracle.py` | `RmxOSOracle.Compare.M2` | OB2 JSON contract, rmxOS logs | high | compare same inputs against Python and accepted OB2 findings |
| `scripts/launchd/check-plist-fixtures.py` | `RmxOSOracle.Fixtures.PlistCheck` | plist/json fixtures | low | same pass/fail cases as Python |

### Batch P2: Simple Shell Wrappers

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/test` | Mix-native test aliases/tasks | Mix project | low | same ExUnit test set runs |
| `scripts/launchd/verify-phase1-plist.sh` | `Mix.Tasks.Oracle.Launchd.VerifyPlist` | fixtures | medium | same dry-run/output assertions |
| `scripts/launchd/verify-phase1-bootstrap.sh` | `Mix.Tasks.Oracle.Launchd.VerifyBootstrap` | build artifacts | medium | same validation-only output |
| `scripts/launchd/verify-phase1-liblaunch-ownership.sh` | `Mix.Tasks.Oracle.Launchd.VerifyLiblaunchOwnership` | source tree paths | medium | same checks on fixture/source inputs |

### Batch P3: Guest Runner And Staging

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/bhyve/run-guest.sh` | `RmxOSOracle.Guest.Runner` / `mix oracle.guest.run` | bhyve, doas, VM image, serial log | high | dry-run command sequence exactly matches legacy |
| `scripts/bhyve/stage-guest.sh` | `RmxOSOracle.Guest.Stage` | objdir, guest root | high | dry-run install plan matches legacy |
| `scripts/bhyve/stage-phase1-*.sh` | `RmxOSOracle.Guest.Stage.Phase1` | build outputs, launchd harness | high | staged file manifest parity |
| `scripts/bhyve/collect-crash.sh` | `RmxOSOracle.Guest.CrashCollect` | artifact paths | medium | same source/dest behavior on fixture tree |

### Batch P4: Launchd Harness Build/Link

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/launchd/build-bootstrap-donor-tests.sh` | `RmxOSOracle.Launchd.BuildDonorTests` | donor source, compiler | high | build plan and outputs match legacy |
| `scripts/launchd/build-phase08-d14-launchctl.sh` | `RmxOSOracle.Launchd.BuildD14Launchctl` | source transform, fixtures | high | build plan/output parity |
| `scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh` | `RmxOSOracle.Launchd.BuildD15Launchctl` | source transform, fixtures | high | build plan/output parity |
| `scripts/launchd/link-launchd-harness.sh` | `RmxOSOracle.Launchd.LinkHarness` | many object files, embedded awk | very_high | manifest of linked inputs and resulting binary parity |

### Batch P5: Dispatch/Libthr Runners

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/dispatch/compile-libdispatch-build-lane.sh` | `RmxOSOracle.Dispatch.BuildLane` | dispatch source/build tree, embedded awk | high | build plan parity |
| `scripts/dispatch/compile-libdispatch-object-gate.sh` | `RmxOSOracle.Dispatch.ObjectGate` | compiler, object paths | medium | object gate parity |
| `scripts/dispatch/verify-phase07-*.sh` | `RmxOSOracle.Dispatch.VerifyPhase07` | Zig/C probes, dispatch build artifacts | high | dry-run and serial-result parity |
| `scripts/libthr/verify-phase07-*.sh` | `RmxOSOracle.Libthr.VerifyPhase07` | libthr probes, embedded awk | high | dry-run and serial-result parity |

### Batch P6: Inventory Scripts

| legacy files | target Elixir module/task | dependencies | risk | parity proof |
| --- | --- | --- | --- | --- |
| `scripts/inventory/classify-donor.sh` | `RmxOSOracle.Inventory.ClassifyDonor` | donor source tree, embedded awk | medium | same classification table |
| `scripts/inventory/nextbsd-history.sh` | `RmxOSOracle.Inventory.NextBSDHistory` | git history | low | same commit list |

Embedded-awk-heavy scripts are sequenced after the simpler parser/wrapper ports unless they block a selected gate. `link-launchd-harness.sh` is the highest-risk shell port.

## 8. C/Zig Probe Plan

M1 must define the canonical Zig layout before any probe migration.

Standalone Zig binaries are the canonical native probe format. They are built and run as out-of-process executables; M1 does not design, depend on, or scaffold BEAM native extensions, port drivers, linked shared libraries, or in-process native helpers.

Recommended layout:

```text
zig/
  build.zig
  README.md
  probes/
    mach/
    dispatch/
    launchd/
    libthr/
```

`zig/build.zig` is part of the canonical layout because standalone Zig binaries are the probe build artifact. A future shared probe contract, if needed, should live at `zig/probes/contract.zig`; M1 may reserve/document that path but does not need to implement shared contract logic.

Existing Zig files are already in the canonical language, so they are `relocate_zig`, not `port_to_zig`:

| source path | target path |
| --- | --- |
| `scripts/dispatch/libdispatch-phase07-qos-twq-smoke.zig` | `zig/probes/dispatch/qos_twq_smoke.zig` |
| `scripts/dispatch/libthr-phase07-sched-pri-smoke.zig` | `zig/probes/libthr/sched_pri_smoke.zig` |

C probes remain references until Zig parity:

| source group | action |
| --- | --- |
| `scripts/bhyve/nxplatform-mach-probe.c` | retain as very-high-complexity reference until Zig parity |
| `scripts/bhyve/*-test.c`, `*-proof.c`, `*-runner.c` | retain C reference until Zig parity |
| `scripts/dispatch/*-smoke.c` | retain C reference until Zig parity |
| `scripts/libthr/*-probe.c` | retain C reference until Zig parity |
| `scripts/launchd/test-plist-parser.c` | retain C reference until Zig parity or Elixir fixture parser replaces need |

C support/glue classification:

| source path | action |
| --- | --- |
| `scripts/bhyve/m5-kqueue-compat.c` | evaluate C support |
| `scripts/bhyve/m5-kqueue-compat.h` | keep C support if still needed |
| `scripts/dispatch/libdispatch-phase07-compat.h` | keep C support if still needed |
| `scripts/dispatch/libdispatch-phase07-kevent64.c` | evaluate C support |
| `scripts/dispatch/libdispatch-phase07-voucher-stubs.c` | evaluate C support |
| `scripts/dispatch/libdispatch-phase07-workqueue-compat.c` | evaluate C support |

Parity rule:

- no C-to-Zig port is accepted until parity against original C passes
- original C remains reference until parity passes
- compatibility C is not a semantic probe and must not be treated as one
- Zig migration does not begin until layout is accepted
- standalone Zig executable integration is the only native probe integration model accepted for M1

## 9. Dependency Edge Handling

M1 must track verifier dependencies explicitly.

Dependency edges must be persisted machine-readably, not only described in Markdown.

`priv/dependencies/m0_dependency_edges.json` is not handed over by M0. M1 derives the initial dependency edges and writes this file before treating it as authoritative.

Derivation task:

- scan selected imports and canonical candidates for `Code.require_file`
- scan Elixir code for `System.cmd`, `Port.open`, and other process invocation patterns
- scan shell/Python references in verifier command strings
- scan fixture reads
- scan C/donor payload reads and writes
- scan probe source/build/run references
- scan source-tree and artifact path references

`RmxOSOracle.Dependency` owns derivation and policy classification. `mix oracle.dependency.audit` validates the derived JSON shape and blocks canonical status when unresolved non-canonical dependencies remain.

Proposed location:

```text
priv/dependencies/m0_dependency_edges.json
```

Proposed dependency record fields:

```json
{
  "consumer": "scripts/launchd/verify-phase08-launchd-dispatch-bootstrap.exs",
  "dependency": "scripts/bhyve/run-guest.sh",
  "dependency_language": "shell",
  "dependency_action": "port_to_elixir",
  "edge_type": "exec",
  "canonical_status": "blocked"
}
```

The dependency JSON top level should include:

```json
{
  "schema": "rmxos_oracle.dependency_edges.v1",
  "source": "docs/migration-m0-inventory.md",
  "generated_by": "mix oracle.dependency.derive",
  "derived_from_manifest_sha256": "e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298",
  "edges": []
}
```

Dependency edge types:

| edge type | example |
| --- | --- |
| `exec` | Elixir verifier runs shell/Python with `System.cmd` |
| `require_file` | Elixir verifier loads another `.exs` by path |
| `payload` | Elixir verifier/generator reads or writes C/donor payload |
| `fixture` | verifier depends on fixture data |
| `source_tree` | verifier depends on external source tree |
| `artifact` | verifier depends on build/serial/output artifact |

Canonical status rules:

| status | meaning |
| --- | --- |
| `canonical` | Elixir/Zig/fixture only; no unported non-canonical dependencies |
| `canonical_candidate` | canonical language but needs path/namespace cleanup or parity proof |
| `blocked` | depends on shell/Python/C reference or unresolved env |
| `reference_only` | intentionally retained for parity/history |

M1 must not label a verifier `canonical` while it has an unresolved `exec` edge to shell/Python. `require_file` edges between imported Elixir modules are acceptable only after they become normal compiled modules or Mix task dependencies.

## 10. M1 Acceptance Criteria

M1 is complete only when all of these are true:

- M1 design accepted.
- Provenance path A or B selected by parent.
- Manifest preflight implemented.
- Manifest preflight includes a round-trip self-test that recomputes the manifest digest from committed JSON and matches the expected digest.
- Manifest preflight passes before any source import or canonical import.
- Oracle-owned Mix project scaffolded with `app: :rmxos_oracle`.
- Top-level namespace is `RmxOSOracle`.
- Elixir 1.20.0 / OTP 29 baseline recorded.
- `mix.exs` targets `elixir: "~> 1.20"`.
- Native integration boundary recorded.
- Standalone Zig binaries are the canonical probe format.
- No BEAM native-extension dependency or scaffold exists.
- No in-process native helper dependency or scaffold exists.
- Machine-readable manifest JSON created at `priv/manifests/m0_legacy_source_test_manifest.json`.
- Evidence ladder strategy recorded.
- Claim/evidence schema fields needed for future layer binding, negative controls, baselines, and provenance are defined without creating accepted claims.
- No broad verifier/gate renames.
- Environment validation scaffolded.
- Env validator implemented as `RmxOSOracle.Env` / `RmxOSOracle.Paths` plus `mix oracle.env.check`.
- Lane-specific objdir prefix handling exists.
- Lane-specific objdir prefixes are explicit configured inputs, not hardcoded releng151/releng151-rc1 defaults.
- Legacy verifier invocations receive the selected lane prefix as `NXPLATFORM_KERNEL_OBJDIRPREFIX`.
- Run provenance records selected lane, resolved `NXPLATFORM_KERNEL_OBJDIRPREFIX`, resolved `NXPLATFORM_FREEBSD_SRC`, FreeBSD/rmxOS source commit, and base profile name when present.
- No silent fallback to oracle-root `freebsd-src-stable-15`.
- `priv/env/env.local` is gitignored if local env config is used.
- `certification/` is not created.
- Donor/reference roots are validated and recorded when consumed.
- Selected fixtures imported.
- Selected self-contained Elixir modules imported.
- Imported Elixir tests pass under oracle Mix project.
- Dependency-edge data recorded at `priv/dependencies/m0_dependency_edges.json`.
- Dependency-edge data is derived by M1 before audit.
- Dependency-edge tracker exists for imported/candidate verifiers.
- No canonical imported Elixir module depends on `require_file` path coupling.
- No Python canonical code.
- No shell canonical runner.
- No wholesale `scripts/` copy.
- No C/Zig probe migration unless Zig layout is accepted.
- Original C references retained for parity.
- No deletion from source repo.
- No stable/15 base update.
- No new feature gates.
- Oracle worktree ends in a reviewable clean commit or clearly staged patchset.

M1 does not require:

- full guest smoke
- launchd D1-D23 baseline
- C-to-Zig parity
- shell/Python port completion
- BEAM native-extension spike
- host-side native helper design outside standalone probe binaries
- M2 authority directories, including `certification/`

## 11. Hard Stops

- no M1 implementation until this design is accepted
- no source import or canonical import if manifest preflight fails
- no manifest preflight implementation that scrapes Markdown as its primary data source
- no manifest preflight without canonical JSON digest round-trip self-test
- no canonical import from untracked source without parent approval or source commit
- no import if provenance path A/B is unresolved
- no env.check lane validation unless the selected lane objdir prefix is projected to `NXPLATFORM_KERNEL_OBJDIRPREFIX` for the verifier/runtime that consumes it, or the command is explicitly validation-only and invokes no verifier
- no lane may silently fall back to `releng151*`, `releng151-rc1*`, `/usr/obj`, or repo-root-derived objdir paths unless that value is explicitly pinned in `priv/env/env.local` or lane configuration
- no shell/Python canonical code
- no wholesale `scripts/` copy
- no generated/runtime artifacts in canonical tree
- no BEAM native-extension or in-process native helper dependency in M1
- no BEAM native-extension or in-process native helper scaffold in M1
- no deferred native-extension spike in M1
- no host-side native helper outside standalone probe binaries without a separate future design decision
- no C/Zig migration before canonical Zig layout is defined
- no C-to-Zig accepted without parity against original C
- original C reference retained until Zig parity passes
- no guest/objdir gate until lane-specific objdir prefix handling exists
- no verifier marked canonical while depending on unported shell/Python
- no canonical imported Elixir module may depend on `require_file` path coupling; `require_file` edges must either become compiled module dependencies or remain blocking legacy dependencies
- no source repo deletion
- no stable/15 base update
- no new feature gates
- no `certification/` creation in M1
- no empty/unowned top-level authority directories
- no M6/certification-pass language until claims ledger exists
- no certification PASS from ExUnit-only or harness-only evidence
- no exit-0-only PASS in certification paths
- no cross-arch ABI/layout oracle
- no donor-C-only accepted claim without explicit provisional status or parent-approved donor reference exception
- no shared guest/objdir/serial/VM gates run concurrently when they share state

## Blockers And Ambiguities

Historical provenance decision, resolved by selecting Path A:

- Path A: commit pending `pending_fix` test/framework changes in `wip-gpt`, then refresh M0.
- Path B: superseded by source responsibility policy commit `e6dfa40`; Oracle
  validates only committed source pins.

Accepted design decisions recorded here:

- app name `:rmxos_oracle`
- top-level namespace `RmxOSOracle`
- Elixir 1.20.0 / OTP 29 baseline
- pure Elixir env validator: `RmxOSOracle.Env`, `RmxOSOracle.Paths`, and `mix oracle.env.check`
- `certification/` creation deferred beyond M1
- Zig layout includes `build.zig` and `libthr/`
- objdir prefixes are lane-specific configured inputs; releng151 values are observed legacy defaults only
- M1 is stable/15-ready by configuration, but does not start the stable/15 base update
- native integration boundary: standalone Zig binaries plus Elixir orchestration only
- no BEAM native-extension or in-process native helper scope in M1
- evidence ladder model: L0 ABI, L1 host probes, L2 guest integration, L3 macOS oracle, L4 fuzz/property/soak
- ExUnit green is harness evidence only, not platform certification evidence

Known risks:

- many Elixir verifiers are currently only canonical candidates because they execute shell runners
- `link-launchd-harness.sh` is very high complexity and awk-heavy
- lane-specific objdir prefixes must be solved before any guest gate
- source `pending_fix` changes are dirty, so a manifest refresh may be required before implementation

## Review State

Historical review note: M1 selected Path A and was implemented from committed
source pin `a30ef3f`. Path B is no longer available under the source
responsibility boundary.
