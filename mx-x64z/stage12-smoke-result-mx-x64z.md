# mx-x64z Stage 1-2 Native macOS Runner Report

Date: 2026-05-12

Agent: `mx-x64z`

Role: native Intel macOS oracle runner for `nx-v64z`.

## Host Identity

```text
uname -m: x86_64
ProductName: macOS
ProductVersion: 26.4
BuildVersion: 25E246
Darwin kernel: 25.4.0
Runner class: native Intel macOS
```

Environment JSON reported:

```text
os_name: Darwin
arch: x86_64
machine: x86_64
rosetta: unknown
sip_enabled: true
sandboxed: false
run_as_root: false
ad_hoc_signed: true
hardened_runtime: false
sdk_version: 26.5
sdk_path: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
xcode_select_path: /Applications/Xcode.app/Contents/Developer
```

## Commands Run

From `macos-validation/`:

```sh
git pull --ff-only
make clean
make
make run AGENT=mx-x64z
make validate-json
```

The first attempted `make run AGENT=mx-x64z` failed before running probes because
the harness discovered the generated `.dSYM` bundle as if it were a probe
binary and attempted to sign it. That exposed a Stage 1-2 harness defect, which
was fixed before the final evidence run.

## Final Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-x64z/20260512-26.4-25.4.0
```

Files generated there:

```text
environment.json
foundation_smoke.json
foundation_smoke.stderr.log
signing.stderr.log
```

## Build And Validation Result

Final run summary:

```text
Running: foundation/smoke ...
  PASS: foundation/smoke

Summary: 1 probes, 1 pass, 0 fail, 0 skip
PASS: foundation_smoke.json
Validated: 1 files, 1 pass, 0 fail
```

Build warning observed:

```text
mach_port_destroy is deprecated in macOS 12.0
```

This warning is expected for the current Stage 1-2 smoke probe. It did not
prevent build, signing, execution, or JSON validation.

## Signing Evidence

```text
path: /Users/linz/Local/wip-mach/mach-oracle/macos-validation/.build/bin/foundation/smoke
status: signed
return_code: 0
output: signed: /Users/linz/Local/wip-mach/mach-oracle/macos-validation/.build/bin/foundation/smoke
```

## Smoke Probe Result

Top-level fields from `foundation_smoke.json`:

```text
schema: nx-v64z.macos-oracle.v1
agent: mx-x64z
test_id: macos_foundation_smoke
status: pass
semantic_class: exact_contract
cleanup.returned_to_baseline: true
cleanup.notes:
notes:
```

Mach return sequence:

```text
mach_port_names_before: KERN_SUCCESS (0)
mach_port_allocate: KERN_SUCCESS (0)
mach_port_type: KERN_SUCCESS (0)
mach_port_get_refs: KERN_SUCCESS (0)
mach_port_destroy: KERN_SUCCESS (0)
mach_port_names_after: KERN_SUCCESS (0)
```

Right deltas:

```json
[
  {
    "operation": "allocate receive right",
    "port_name": "smoke_port",
    "right_type": "MACH_PORT_TYPE_RECEIVE",
    "before_urefs": null,
    "after_urefs": 1,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "created"
  },
  {
    "operation": "destroy receive right",
    "port_name": "smoke_port",
    "right_type": "MACH_PORT_TYPE_RECEIVE",
    "before_urefs": 1,
    "after_urefs": 0,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "destroyed"
  }
]
```

## Stage 1-2 Fixes Applied Before Trusting Evidence

The handoff listed five fixes required before Stage 3. This runner applied the
following changes:

```text
macos-validation/harness/run_all.sh
- Ignore non-file build artifacts during probe discovery. This prevents .dSYM
  bundles from being signed or run as probes.
- Enforce native macOS agent identity:
  - mx-x64z only on Darwin x86_64.
  - mx-a64z only on Darwin arm64, and not under active Rosetta.
  - rx only on non-macOS development/comparison lanes.
- Count any nonzero probe process exit as a harness failure even when the probe
  JSON says pass or skip.

macos-validation/probes/foundation/smoke.c
- Report probe_failure if mach_port_type() fails after mach_port_allocate()
  succeeds.
- Report probe_failure if mach_port_get_refs() fails after mach_port_allocate()
  succeeds.

macos-validation/harness/validate_json.sh
- Validate nested result shapes for:
  - returns[]
  - right_deltas[]
  - message.remote_port
  - message.local_port
  - message.header_rights[]
  - message.descriptors[]
- Validate descriptor_count against the actual descriptors[] length.

macos-validation/probes/common/nx_mach_utils.c
- Preserve raw hex output for mach_port_type() values with extra or unknown
  bits by only returning MACH_PORT_TYPE_SEND_RECEIVE on an exact match.
```

## Current Working Tree Files Changed By mx-x64z

```text
macos-validation/harness/run_all.sh
macos-validation/harness/validate_json.sh
macos-validation/probes/common/nx_mach_utils.c
macos-validation/probes/foundation/smoke.c
mx-x64z/stage12-smoke-result-mx-x64z.md
```

Raw result directories under `macos-validation/results/` remain ignored by git
unless the parent explicitly asks to force-add exact artifacts.

## Conclusion

The native Intel macOS `mx-x64z` Stage 1-2 smoke evidence is passing after the
required harness/probe trust fixes. The result is suitable for parent-agent
review and for deciding whether to proceed to Stage 3 foundation probes on this
runner lane.
