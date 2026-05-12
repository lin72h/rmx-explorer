# nx-v64z macOS Oracle Validation Package

This package captures observable native macOS Mach IPC behavior and compares
it against rxOS/NextBSD behavior.

macOS is a semantic oracle only. This package does not import XNU code, require
private entitlements, require SIP changes, or use macOS internals as an
implementation source.

## Roles

- `nx-v64z`: owns probe contract, schema, comparison policy, findings
- `mx-x64z`: runs probes on native Intel macOS
- `mx-a64z`: runs probes on native Apple Silicon macOS
- `rx`: rmxOS development/comparison lane (not oracle owner)

## Quick Start

```sh
cd macos-validation
make
make run AGENT=mx-a64z
```

For local non-macOS development, use `make run AGENT=rx`. That lane proves the
harness and schema only; Mach probes are expected to report `skip`.

## Make Targets

| Target | Purpose |
| --- | --- |
| `all` | build every enabled probe |
| `clean` | remove `.build/` only |
| `list` | list known probes without running |
| `env` | run environment capture |
| `run` | run all probes through harness |
| `validate-json` | validate result JSON with python3 |

## Result Schema

Schema: `nx-v64z.macos-oracle.v1`

Results are stored under:

```
results/<agent>/<date>-<macos-version>-<darwin-version>/
```

For non-macOS development runs, the directory is:

```
results/<agent>/<date>-<os-name>-<kernel-version>/
```

Each probe emits one JSON object to stdout. The harness captures it to a file
in the result directory.

## Constraints

- Probes use `mach_msg()` only (not `mach_msg2()` or `mach_msg_overwrite()`)
- No private entitlements or SIP changes required
- No XNU code import
- No kernel debugging required
- Ad-hoc signed probes with `codesign -s -`
- Process probes must set watchdog timeouts and clean up
- Zig 0.16 is the default Zig toolchain when Zig probes are added; `zig015`
  exists only as a last-resort fallback and must be reported as fallback use.

## Directory Layout

```
probes/common/     — shared C helpers (JSON, env, Mach utils)
probes/foundation/ — foundational introspection probes
probes/m1/         — M1 cross-task foundation probes (roadmap package name)
probes/m2/         — M2 descriptor transfer probes (roadmap package name)
harness/           — shell scripts for build/run/validate
manifests/         — donor test manifests
results/           — per-agent result directories
findings/          — synthesized comparison findings
```

Note: `m1/` and `m2/` are roadmap package names, not Apple hardware references.
