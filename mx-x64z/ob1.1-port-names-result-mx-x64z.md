# mx-x64z OB1.1 Port Names Result

Date: 2026-05-12

Agent: `mx-x64z`

Probe: `foundation/port_names.c`

Test ID: `macos_foundation_port_names`

Scope: OB1.1 only. No `port_type`, `port_get_refs`, header, or descriptor
probes were started.

## Directive Inputs Followed

- `parent-response-to-opus-oracle-batches.md`
- `parent-batch1-directive.md`
- `macos-runner-agent-handoff.md`

## Host Identity

```text
uname -m: x86_64
ProductName: macOS
ProductVersion: 26.4
BuildVersion: 25E246
Darwin kernel: 25.4.0
Runner class: native Intel macOS
Agent: mx-x64z
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

From repo root and `macos-validation/`:

```sh
git pull --ff-only
cd macos-validation
make clean
make
make run AGENT=mx-x64z
make validate-json
```

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-x64z/20260512-26.4-25.4.0
```

Raw artifacts selected for force-add:

```text
macos-validation/results/mx-x64z/20260512-26.4-25.4.0/environment.json
macos-validation/results/mx-x64z/20260512-26.4-25.4.0/foundation_port_names.json
```

Stderr logs were empty:

```text
foundation_port_names.stderr.log: 0 bytes
foundation_smoke.stderr.log: 0 bytes
signing.stderr.log: 0 bytes
```

## Build And Validation Result

Final run summary:

```text
Running: foundation/port_names ...
  PASS: foundation/port_names
Running: foundation/smoke ...
  PASS: foundation/smoke

Summary: 2 probes, 2 pass, 0 fail, 0 skip
PASS: foundation_port_names.json
PASS: foundation_smoke.json
Validated: 3 files, 3 pass, 0 fail
```

Build warning observed:

```text
mach_port_destroy is deprecated in macOS 12.0
```

This is the same Stage 1-2 warning already seen in the smoke probe path. It did
not prevent build, signing, execution, cleanup, or JSON validation.

## Signing Evidence

```text
foundation/port_names: signed rc=0
foundation/smoke: signed rc=0
```

## Port Names Result

Top-level fields from `foundation_port_names.json`:

```text
schema: nx-v64z.macos-oracle.v1
agent: mx-x64z
test_id: macos_foundation_port_names
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
mach_port_names_after_allocate: KERN_SUCCESS (0)
mach_port_destroy: KERN_SUCCESS (0)
mach_port_names_after_destroy: KERN_SUCCESS (0)
```

Observed namespace deltas:

```json
[
  {
    "operation": "allocate receive right observed by mach_port_names",
    "port_name": "port_names_probe_port",
    "right_type": "MACH_PORT_TYPE_RECEIVE",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "present"
  },
  {
    "operation": "destroy receive right observed by mach_port_names",
    "port_name": "port_names_probe_port",
    "right_type": "MACH_PORT_TYPE_RECEIVE",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "removed"
  }
]
```

`entry_refs_before` and `entry_refs_after` are intentionally `null`; stock
macOS does not expose kernel entry refs.

Additional observations from the raw result:

```json
{
  "names_before": 12,
  "names_after_allocate": 13,
  "names_after_destroy": 12,
  "allocation_delta": 1,
  "cleanup_delta": 0,
  "probe_port_seen": true,
  "probe_port_label": "port_names_probe_port"
}
```

## Parent-Facing Finding

For OB1.1 on native Intel macOS, rmxOS should match this observable contract:

```text
mach_port_names() succeeds before allocation.
mach_port_allocate(MACH_PORT_RIGHT_RECEIVE) succeeds.
mach_port_names() succeeds after allocation.
The allocated symbolic port is observable as MACH_PORT_TYPE_RECEIVE.
The namespace count increases by exactly one after allocation.
mach_port_destroy() succeeds.
mach_port_names() succeeds after cleanup.
The namespace returns exactly to the baseline snapshot with cleanup_delta 0.
```

The `mx-x64z` lane did not hit a stop condition: `mach_port_names()` was
reliable for this probe, and cleanup returned to baseline.
