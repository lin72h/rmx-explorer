# mx-a64z OB1.2 Port Type Result

Date: 2026-05-12

Agent: `mx-a64z`

Probe: `foundation/port_type.c`

Test ID: `macos_foundation_port_type`

## Host

```text
uname -m: arm64
sw_vers:
  ProductName: macOS
  ProductVersion: 26.5
  BuildVersion: 25F71
uname -r: 25.5.0
sysctl.proc_translated: 0
```

Native Apple Silicon. Rosetta is not active.

## Commands

```sh
git pull --ff-only
cd macos-validation
make clean
make
make run AGENT=mx-a64z
make validate-json
```

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-a64z/20260512-26.5-25.5.0
```

Raw artifacts force-added for commit:

```text
macos-validation/results/mx-a64z/20260512-26.5-25.5.0/environment.json
macos-validation/results/mx-a64z/20260512-26.5-25.5.0/foundation_port_type.json
```

Empty stderr logs were not force-added:

```text
foundation_port_names.stderr.log: 0 bytes
foundation_port_type.stderr.log: 0 bytes
foundation_smoke.stderr.log: 0 bytes
signing.stderr.log: 0 bytes
```

## Harness Summary

```text
Summary: 3 probes, 3 pass, 0 fail, 0 skip
Validated: 4 files, 4 pass, 0 fail
```

Validation included the previously committed `mx-x64z` OB1.1 raw JSON in
addition to this runner's current result directory.

## Port Type Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_foundation_port_type",
  "status": "pass",
  "semantic_class": "exact_contract",
  "returns": [
    {
      "call": "mach_port_names_before",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_allocate_receive",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_type_receive",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_insert_right_make_send",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_type_send_receive",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_allocate_port_set",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_type_port_set",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_type_task_self",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_destroy_receive",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_destroy_port_set",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_names_after",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    }
  ],
  "right_deltas": [
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
  ],
  "observations": {
    "receive_type": "MACH_PORT_TYPE_RECEIVE",
    "receive_type_raw_hex": "0x20000",
    "receive_type_exact": true,
    "send_receive_type": "MACH_PORT_TYPE_SEND_RECEIVE",
    "send_receive_type_raw_hex": "0x30000",
    "send_receive_type_exact": true,
    "port_set_type": "MACH_PORT_TYPE_PORT_SET",
    "port_set_type_raw_hex": "0x80000",
    "port_set_type_exact": true,
    "task_self_observed": true,
    "task_self_type": "MACH_PORT_TYPE_SEND",
    "task_self_type_raw_hex": "0x10000",
    "names_before": 11,
    "names_after": 11,
    "cleanup_delta": 0
  },
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

## Finding

On native Apple Silicon macOS 26.5 / Darwin 25.5.0, `mach_port_type()` matches
the OB1.2 foundation contract:

- allocated receive right type is exactly `MACH_PORT_TYPE_RECEIVE` (`0x20000`)
- after `MACH_MSG_TYPE_MAKE_SEND`, the same port type is exactly
  `MACH_PORT_TYPE_SEND_RECEIVE` (`0x30000`)
- allocated port set type is exactly `MACH_PORT_TYPE_PORT_SET` (`0x80000`)
- `mach_task_self()` is observable and reports `MACH_PORT_TYPE_SEND`
  (`0x10000`)
- all type observations include raw hex fields
- `entry_refs_before` and `entry_refs_after` remain `null`
- cleanup returned exactly to baseline

No OB1.2 stop condition occurred on `mx-a64z`.
