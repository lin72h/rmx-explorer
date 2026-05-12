# mx-a64z OB2.2 Descriptor MOVE_SEND Result

Date: 2026-05-13

Agent: `mx-a64z`

Probe: `m2/descriptor_move_send.c`

Test ID: `macos_m2_descriptor_move_send`

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
make clean all
make run AGENT=mx-a64z
make validate-json
```

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-a64z/20260513-26.5-25.5.0
```

Raw artifacts force-added for commit:

```text
macos-validation/results/mx-a64z/20260513-26.5-25.5.0/environment.json
macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m2_descriptor_move_send.json
```

Empty stderr logs were not force-added.

## Harness Summary

```text
Summary: 8 probes, 8 pass, 0 fail, 0 skip
Validated: 18 files, 18 pass, 0 fail
```

## Descriptor MOVE_SEND Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_m2_descriptor_move_send",
  "status": "pass",
  "semantic_class": "exact_contract",
  "message": {
    "msgh_bits": "0x80000013",
    "remote_port": {
      "name": "service_port",
      "disposition": "MACH_MSG_TYPE_COPY_SEND",
      "right_type": "MACH_PORT_TYPE_SEND"
    },
    "descriptor_count": 1,
    "descriptors": [
      {
        "name": "cargo_send_descriptor",
        "disposition": "MACH_MSG_TYPE_MOVE_SEND",
        "right_type_before": "MACH_PORT_TYPE_SEND",
        "right_type_after": "MACH_PORT_TYPE_SEND"
      }
    ]
  },
  "right_deltas": [
    {
      "operation": "descriptor MOVE_SEND child sender",
      "port_name": "cargo_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 1,
      "after_urefs": 0,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "consumed"
    },
    {
      "operation": "descriptor MOVE_SEND parent delivered",
      "port_name": "delivered_cargo_send",
      "right_type": "MACH_PORT_TYPE_SEND",
      "before_urefs": null,
      "after_urefs": 1,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "usable send right"
    },
    {
      "operation": "descriptor MOVE_SEND child after verification",
      "port_name": "cargo_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 0,
      "after_urefs": 0,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "consumed"
    }
  ],
  "observations": {
    "child_cargo_type_before_send": "MACH_PORT_TYPE_SEND_RECEIVE",
    "child_cargo_type_after_send": "MACH_PORT_TYPE_RECEIVE",
    "child_cargo_send_urefs_before_send": 1,
    "child_cargo_send_urefs_after_send": 0,
    "child_cargo_type_after_verify": "MACH_PORT_TYPE_RECEIVE",
    "child_cargo_send_urefs_after_verify": 0,
    "sent_descriptor_disposition": "MACH_MSG_TYPE_MOVE_SEND",
    "sent_msgh_bits_raw_hex": "0x80000013",
    "received_msgh_bits_raw_hex": "0x80001100",
    "delivered_descriptor_disposition_raw_hex": "0x11",
    "parent_delivered_port_type": "MACH_PORT_TYPE_SEND",
    "parent_delivered_send_refs": 1,
    "delivered_right_usable": true,
    "parent_delivered_deallocate_count": 1,
    "parent_delivered_one_deallocate_sufficient": true,
    "child_cleanup_delta": 0,
    "parent_cleanup_delta": 0
  },
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

## Finding

On native Apple Silicon macOS 26.5 / Darwin 25.5.0, descriptor
`MACH_MSG_TYPE_MOVE_SEND` consumes the child's observable cargo send right at
successful `mach_msg(SEND)` return and delivers a usable send right to the
parent:

- child cargo type before send: `MACH_PORT_TYPE_SEND_RECEIVE`
- child cargo send urefs before send: `1`
- child cargo type immediately after descriptor send: `MACH_PORT_TYPE_RECEIVE`
- child cargo send urefs immediately after descriptor send: `0`
- child cargo type after parent verification message: `MACH_PORT_TYPE_RECEIVE`
- child cargo send urefs after parent verification message: `0`
- parent delivered port type: `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- parent verification send: `MACH_MSG_SUCCESS`
- child verification receive: `MACH_MSG_SUCCESS`
- one parent `mach_port_deallocate()` of the delivered right was sufficient
- child cleanup returned exactly to baseline
- parent cleanup returned exactly to baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

No OB2.2 stop condition occurred on `mx-a64z`.

Cross-runner comparison is pending the `mx-x64z` OB2.2 run against this
implementation.

No OB2.3 probe was started.
