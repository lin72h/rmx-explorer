# mx-a64z OB1.4 Header COPY_SEND Result

Date: 2026-05-13

Agent: `mx-a64z`

Probe: `m1/header_copy_send_accounting.c`

Test ID: `macos_m1_header_copy_send_accounting`

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
macos-validation/results/mx-a64z/20260513-26.5-25.5.0/m1_header_copy_send_accounting.json
```

Empty stderr logs were not force-added:

```text
foundation_port_get_refs.stderr.log: 0 bytes
foundation_port_names.stderr.log: 0 bytes
foundation_port_type.stderr.log: 0 bytes
foundation_smoke.stderr.log: 0 bytes
m1_header_copy_send_accounting.stderr.log: 0 bytes
signing.stderr.log: 0 bytes
```

## Harness Summary

```text
Summary: 5 probes, 5 pass, 0 fail, 0 skip
Validated: 12 files, 12 pass, 0 fail
```

Validation included previously committed foundation raw JSON artifacts for both
native macOS runners.

## Header COPY_SEND Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_m1_header_copy_send_accounting",
  "status": "pass",
  "semantic_class": "exact_contract",
  "message": {
    "msgh_bits": "0x13",
    "remote_port": {
      "name": "service_port",
      "disposition": "MACH_MSG_TYPE_COPY_SEND",
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
        "disposition": "MACH_MSG_TYPE_COPY_SEND",
        "right_type_before": "MACH_PORT_TYPE_SEND",
        "right_type_after": "MACH_PORT_TYPE_SEND"
      }
    ],
    "descriptor_count": 0,
    "descriptors": []
  },
  "returns": [
    {
      "call": "mach_msg_send_copy_send",
      "returned": "MACH_MSG_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_msg_receive",
      "returned": "MACH_MSG_SUCCESS",
      "raw": 0,
      "errno": null
    }
  ],
  "right_deltas": [
    {
      "operation": "header COPY_SEND at SEND return",
      "port_name": "service_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 1,
      "after_urefs": 1,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "unchanged"
    },
    {
      "operation": "header COPY_SEND after RECEIVE",
      "port_name": "service_port",
      "right_type": "MACH_PORT_RIGHT_SEND",
      "before_urefs": 1,
      "after_urefs": 1,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "recorded"
    }
  ],
  "observations": {
    "send_urefs_before_send": 1,
    "send_urefs_after_send": 1,
    "send_urefs_unchanged_at_send_return": true,
    "send_urefs_after_receive": 1,
    "port_type_before_send": "MACH_PORT_TYPE_SEND_RECEIVE",
    "port_type_after_send": "MACH_PORT_TYPE_SEND_RECEIVE",
    "port_type_after_receive": "MACH_PORT_TYPE_SEND_RECEIVE",
    "sent_msgh_bits_raw_hex": "0x13",
    "sent_remote_disposition": "MACH_MSG_TYPE_COPY_SEND",
    "sent_local_disposition": "0",
    "received_msgh_bits_raw_hex": "0x1100",
    "received_remote_disposition": "0",
    "received_local_disposition": "MACH_MSG_TYPE_MOVE_SEND",
    "received_remote_port": "MACH_PORT_NULL",
    "received_local_port": "service_port",
    "received_msgh_size": 24,
    "received_msgh_id": 1329738036,
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

On native Apple Silicon macOS 26.5 / Darwin 25.5.0, header
`MACH_MSG_TYPE_COPY_SEND` does not change source send urefs:

- send urefs before `mach_msg(SEND)`: `1`
- send urefs immediately after successful `mach_msg(SEND)`: `1`
- send urefs after successful `mach_msg(RECEIVE)`: `1`
- port type before send, after send, and after receive:
  `MACH_PORT_TYPE_SEND_RECEIVE`
- sent `msgh_bits`: `0x13`
- received `msgh_bits`: `0x1100`
- received header labels: remote `MACH_PORT_NULL`, local `service_port`
- cleanup returned exactly to baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

The OB1.4 stop condition did not occur on `mx-a64z`.

No OB1.5 or descriptor probe was started.
