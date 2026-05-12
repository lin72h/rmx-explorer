# mx-x64z OB1.2 Port Type Result

Date: 2026-05-12

Agent: `mx-x64z`

Probe: `foundation/port_type.c`

Test ID: `macos_foundation_port_type`

Scope: OB1.2 only. No `port_get_refs`, header, or descriptor probes were
started.

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
macos-validation/results/mx-x64z/20260512-26.4-25.4.0/foundation_port_type.json
```

Stderr logs were empty:

```text
foundation_port_type.stderr.log: 0 bytes
foundation_port_names.stderr.log: 0 bytes
foundation_smoke.stderr.log: 0 bytes
signing.stderr.log: 0 bytes
```

## Build And Validation Result

```text
Running: foundation/port_names ...
  PASS: foundation/port_names
Running: foundation/port_type ...
  PASS: foundation/port_type
Running: foundation/smoke ...
  PASS: foundation/smoke

Summary: 3 probes, 3 pass, 0 fail, 0 skip
Validated: 5 files, 5 pass, 0 fail
```

Build warning observed:

```text
mach_port_destroy is deprecated in macOS 12.0
```

This did not prevent build, signing, execution, cleanup, or JSON validation.

## Port Type Result

Top-level fields from `foundation_port_type.json`:

```text
schema: nx-v64z.macos-oracle.v1
agent: mx-x64z
test_id: macos_foundation_port_type
status: pass
semantic_class: exact_contract
cleanup.returned_to_baseline: true
cleanup.notes:
notes:
```

Mach return sequence:

```text
mach_port_names_before: KERN_SUCCESS (0)
mach_port_allocate_receive: KERN_SUCCESS (0)
mach_port_type_receive: KERN_SUCCESS (0)
mach_port_insert_right_make_send: KERN_SUCCESS (0)
mach_port_type_send_receive: KERN_SUCCESS (0)
mach_port_allocate_port_set: KERN_SUCCESS (0)
mach_port_type_port_set: KERN_SUCCESS (0)
mach_port_type_task_self: KERN_SUCCESS (0)
mach_port_destroy_receive: KERN_SUCCESS (0)
mach_port_destroy_port_set: KERN_SUCCESS (0)
mach_port_names_after: KERN_SUCCESS (0)
```

Observed type values:

| Label | Type | Raw Dec | Raw Hex | Expected | Match |
| --- | --- | ---: | --- | --- | --- |
| receive right | `MACH_PORT_TYPE_RECEIVE` | 131072 | `0x20000` | `MACH_PORT_TYPE_RECEIVE` | true |
| receive + send right | `MACH_PORT_TYPE_SEND_RECEIVE` | 196608 | `0x30000` | `MACH_PORT_TYPE_SEND_RECEIVE` | true |
| port set | `MACH_PORT_TYPE_PORT_SET` | 524288 | `0x80000` | `MACH_PORT_TYPE_PORT_SET` | true |
| `mach_task_self()` | `MACH_PORT_TYPE_SEND` | 65536 | `0x10000` | observed only | n/a |

Right deltas:

```json
[
  {
    "operation": "allocate receive right",
    "port_name": "port_type_receive_port",
    "right_type": "MACH_PORT_TYPE_RECEIVE",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "MACH_PORT_TYPE_RECEIVE"
  },
  {
    "operation": "insert send right",
    "port_name": "port_type_receive_port",
    "right_type": "MACH_PORT_TYPE_SEND_RECEIVE",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "MACH_PORT_TYPE_SEND_RECEIVE"
  },
  {
    "operation": "allocate port set",
    "port_name": "port_type_port_set",
    "right_type": "MACH_PORT_TYPE_PORT_SET",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "MACH_PORT_TYPE_PORT_SET"
  },
  {
    "operation": "inspect task self",
    "port_name": "mach_task_self",
    "right_type": "MACH_PORT_TYPE_SEND",
    "before_urefs": null,
    "after_urefs": null,
    "entry_refs_before": null,
    "entry_refs_after": null,
    "expected": "observed"
  }
]
```

`entry_refs_before` and `entry_refs_after` are intentionally `null`; stock
macOS does not expose kernel entry refs.

Cleanup observation:

```json
{
  "names_before": 12,
  "names_after": 12,
  "cleanup_delta": 0
}
```

## Parent-Facing Finding

For OB1.2 on native Intel macOS, rmxOS should match this observable contract:

```text
mach_port_type() on a freshly allocated receive right returns MACH_PORT_TYPE_RECEIVE.
mach_port_insert_right(..., MACH_MSG_TYPE_MAKE_SEND) succeeds.
mach_port_type() on the same name then returns exactly MACH_PORT_TYPE_SEND_RECEIVE.
mach_port_type() on an allocated port set returns MACH_PORT_TYPE_PORT_SET.
mach_port_type() on mach_task_self() is observable and returns MACH_PORT_TYPE_SEND.
All raw type values are preserved in decimal and hex.
Cleanup returns exactly to baseline with cleanup_delta 0.
```

The `mx-x64z` lane did not hit a stop condition: type bits matched the expected
controlled values, no unknown extra bits appeared, and cleanup returned to
baseline.
