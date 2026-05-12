# mx-a64z OB2.3 Send-Once Descriptor Result

Date: 2026-05-13

Agent: `mx-a64z`

Probe: `m2/send_once_descriptor.c`

Test ID: `macos_m2_send_once_descriptor`

## Host

```text
hostname: mm4.local
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
macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m2_send_once_descriptor.json
```

Empty stderr logs were not force-added.

## Harness Summary

```text
Summary: 9 probes, 9 pass, 0 fail, 0 skip
Validated: 20 files, 20 pass, 0 fail
```

## Send-Once Descriptor Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_m2_send_once_descriptor",
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
        "name": "cargo_send_once_descriptor",
        "disposition": "MACH_MSG_TYPE_MOVE_SEND_ONCE",
        "right_type_before": "MACH_PORT_TYPE_SEND_ONCE",
        "right_type_after": "MACH_PORT_TYPE_SEND_ONCE"
      }
    ]
  },
  "right_deltas": [
    {
      "operation": "send-once descriptor child sender",
      "port_name": "send_once_port",
      "right_type": "MACH_PORT_RIGHT_SEND_ONCE",
      "before_urefs": 1,
      "after_urefs": null,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "consumed"
    },
    {
      "operation": "send-once descriptor parent delivered",
      "port_name": "delivered_send_once",
      "right_type": "MACH_PORT_TYPE_SEND_ONCE",
      "before_urefs": null,
      "after_urefs": 1,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "usable send right"
    },
    {
      "operation": "send-once descriptor parent after first use",
      "port_name": "delivered_send_once",
      "right_type": "MACH_PORT_RIGHT_SEND_ONCE",
      "before_urefs": 1,
      "after_urefs": null,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "consumed"
    }
  ],
  "observations": {
    "send_once_create_api": "mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)",
    "child_cargo_type_before_send_once_create": "MACH_PORT_TYPE_RECEIVE",
    "child_extract_acquired_type": "MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE",
    "child_send_once_type_before_send": "MACH_PORT_TYPE_SEND_ONCE",
    "child_send_once_refs_before_send": 1,
    "child_send_once_right_consumed_after_send": true,
    "delivered_descriptor_disposition_raw_hex": "0x12",
    "parent_delivered_port_type": "MACH_PORT_TYPE_SEND_ONCE",
    "parent_delivered_send_once_refs": 1,
    "delivered_right_usable_once": true,
    "parent_second_use_result": "MACH_SEND_INVALID_DEST",
    "parent_second_use_blocked": true,
    "child_verify_first_receive_result": "MACH_MSG_SUCCESS",
    "child_verify_second_receive_result": "MACH_RCV_TIMED_OUT",
    "child_received_second_verification": false,
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
`MACH_MSG_TYPE_MOVE_SEND_ONCE` consumes the child's send-once right at
successful `mach_msg(SEND)` return and delivers a usable one-shot right to the
parent:

- send-once creation API: `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child cargo type before send-once creation: `MACH_PORT_TYPE_RECEIVE`
- child send-once type before send: `MACH_PORT_TYPE_SEND_ONCE`
- child send-once refs before send: `1`
- child send-once type/refs after descriptor send: `KERN_INVALID_NAME`
- parent delivered port type: `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs: `1`
- first parent verification send: `MACH_MSG_SUCCESS`
- child first verification receive: `MACH_MSG_SUCCESS`
- parent delivered type/refs after first use: `KERN_INVALID_NAME`
- second parent verification send: `MACH_SEND_INVALID_DEST`
- child second verification receive: `MACH_RCV_TIMED_OUT`
- child received no second verification message
- child cleanup returned exactly to baseline
- parent cleanup returned exactly to baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

No OB2.3 stop condition occurred on `mx-a64z`.

Cross-runner comparison is pending the `mx-x64z` OB2.3 run against this
implementation.

No OB2.4 probe was started.
