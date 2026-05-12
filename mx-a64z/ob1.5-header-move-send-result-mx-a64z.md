# mx-a64z OB1.5 Header MOVE_SEND Result

Date: 2026-05-13

Agent: `mx-a64z`

Probe: `m1/header_move_send_accounting.c`

Test ID: `macos_m1_header_move_send_accounting`

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
macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m1_header_move_send_accounting.json
```

Empty stderr logs were not force-added.

## Harness Summary

```text
Summary: 6 probes, 6 pass, 0 fail, 0 skip
Validated: 14 files, 14 pass, 0 fail
```

## Header MOVE_SEND Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_m1_header_move_send_accounting",
  "status": "pass",
  "semantic_class": "exact_contract",
  "message": {
    "msgh_bits": "0x11",
    "remote_port": {
      "name": "service_port",
      "disposition": "MACH_MSG_TYPE_MOVE_SEND",
      "right_type": "MACH_PORT_TYPE_SEND"
    },
    "local_port": {
      "name": null,
      "disposition": null,
      "right_type": null
    },
    "header_rights": [
      {
        "field": "msgh_remote_port",
        "disposition": "MACH_MSG_TYPE_MOVE_SEND",
        "right_type_before": "MACH_PORT_TYPE_SEND",
        "right_type_after": "MACH_PORT_TYPE_RECEIVE"
      }
    ],
    "descriptor_count": 0,
    "descriptors": []
  },
  "right_deltas": [
    {
      "operation": "header MOVE_SEND at SEND return",
      "port_name": "service_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 1,
      "after_urefs": 0,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "consumed"
    },
    {
      "operation": "header MOVE_SEND after RECEIVE",
      "port_name": "service_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 0,
      "after_urefs": 0,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "recorded"
    }
  ],
  "observations": {
    "send_urefs_before_send": 1,
    "send_urefs_after_send": 0,
    "send_urefs_consumed_at_send_return": true,
    "send_urefs_after_receive": 0,
    "port_type_before_send": "MACH_PORT_TYPE_SEND_RECEIVE",
    "port_type_after_send": "MACH_PORT_TYPE_RECEIVE",
    "port_type_after_receive": "MACH_PORT_TYPE_RECEIVE",
    "delivered_right_usability_attempted": false,
    "delivered_right_usable": false,
    "send_urefs_after_usability": -1,
    "sent_msgh_bits_raw_hex": "0x11",
    "sent_remote_disposition": "MACH_MSG_TYPE_MOVE_SEND",
    "sent_local_disposition": "0",
    "received_msgh_bits_raw_hex": "0x1100",
    "received_remote_disposition": "0",
    "received_local_disposition": "MACH_MSG_TYPE_MOVE_SEND",
    "received_remote_port": "MACH_PORT_NULL",
    "received_local_port": "service_port",
    "received_msgh_size": 24,
    "received_msgh_id": 1329738037,
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

On native Apple Silicon macOS 26.5 / Darwin 25.5.0, header
`MACH_MSG_TYPE_MOVE_SEND` consumes the sender's observable send right at
`mach_msg(SEND)` return:

- send urefs before `mach_msg(SEND)`: `1`
- send urefs immediately after successful `mach_msg(SEND)`: `0`
- send urefs after successful `mach_msg(RECEIVE)`: `0`
- port type before send: `MACH_PORT_TYPE_SEND_RECEIVE`
- port type after send: `MACH_PORT_TYPE_RECEIVE`
- port type after receive: `MACH_PORT_TYPE_RECEIVE`
- sent `msgh_bits`: `0x11`
- received `msgh_bits`: `0x1100`
- received header labels: remote `MACH_PORT_NULL`, local `service_port`
- no delivered send right is observable after receive, so usability was not
  attempted
- cleanup returned exactly to baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

No OB1.5 stop condition occurred on `mx-a64z`.

No OB2 probe was started.
