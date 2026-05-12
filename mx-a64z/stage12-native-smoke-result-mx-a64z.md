# mx-a64z Stage 1-2 Native macOS Smoke Result

Date: 2026-05-12

Agent: `mx-a64z`

## Host Identity

```text
uname -m: arm64
sw_vers:
  ProductName: macOS
  ProductVersion: 26.5
  BuildVersion: 25F71
uname -r: 25.5.0
sysctl.proc_translated: 0
```

This is native Apple Silicon macOS, not Rosetta.

## Local Hardening Applied Before Run

The checked-in Stage 1-2 draft still had the known review issues from
`macos-runner-agent-handoff.md`, so I applied these narrow fixes before
collecting evidence:

- `macos-validation/probes/foundation/smoke.c`: report `probe_failure` if
  `mach_port_type()` or `mach_port_get_refs()` fails after successful
  `mach_port_allocate()`.
- `macos-validation/harness/run_all.sh`: count any nonzero probe process exit
  as failure, regardless of JSON `status`.
- `macos-validation/harness/run_all.sh`: skip non-regular executable entries
  during probe discovery, preventing `.dSYM` directories from being signed as
  probes on macOS.
- `macos-validation/harness/validate_json.sh`: validate nested shapes for
  `returns[]`, `right_deltas[]`, `message.remote_port`,
  `message.local_port`, `message.header_rights[]`, and
  `message.descriptors[]`.
- `macos-validation/probes/common/nx_mach_utils.c`: preserve raw hex visibility
  for `mach_port_type()` values with extra bits by requiring exact equality
  before returning `MACH_PORT_TYPE_SEND_RECEIVE`.

## Commands Run

```sh
cd macos-validation
make clean
make
make run AGENT=mx-a64z
make validate-json
```

Combined rerun:

```sh
make clean && make && make run AGENT=mx-a64z && make validate-json
```

Build warning observed:

```text
probes/foundation/smoke.c:53:22: warning: 'mach_port_destroy' is deprecated:
first deprecated in macOS 12.0
```

The warning is expected for the current smoke probe contract and did not block
the run.

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-a64z/20260512-26.5-25.5.0
```

Files produced:

```text
environment.json
foundation_smoke.json
foundation_smoke.stderr.log
signing.stderr.log
```

Both stderr log files are empty.

## Harness Summary

```text
Summary: 1 probes, 1 pass, 0 fail, 0 skip
Validated: 1 files, 1 pass, 0 fail
```

## Environment Evidence

```json
{
  "os_name": "Darwin",
  "kernel_version": "25.5.0",
  "arch": "arm64",
  "machine": "arm64",
  "rosetta": "native",
  "ad_hoc_signed": true,
  "signing": {
    "binaries": [
      {
        "path": "/Users/linz/Local/wip-mach/mach-oracle/macos-validation/.build/bin/foundation/smoke",
        "status": "signed",
        "return_code": 0,
        "output": "signed: /Users/linz/Local/wip-mach/mach-oracle/macos-validation/.build/bin/foundation/smoke"
      }
    ]
  }
}
```

## Foundation Smoke Evidence

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_foundation_smoke",
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
      "call": "mach_port_allocate",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_type",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_get_refs",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    },
    {
      "call": "mach_port_destroy",
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
  ],
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

## Runner Finding

Native Apple Silicon macOS Stage 1-2 smoke evidence is clean after applying the
required harness/probe hardening fixes. The smoke probe proves the current
foundation floor on this host:

- `mach_port_names_before`: `KERN_SUCCESS`
- `mach_port_allocate`: `KERN_SUCCESS`
- `mach_port_type`: `KERN_SUCCESS`
- `mach_port_get_refs`: `KERN_SUCCESS`
- `mach_port_destroy`: `KERN_SUCCESS`
- `mach_port_names_after`: `KERN_SUCCESS`
- cleanup returned to baseline
- probe binary was ad-hoc signed

Next appropriate work for this runner is Stage 3 foundation probes:

1. `foundation/port_names.c`
2. `foundation/port_type.c`
3. `foundation/port_get_refs.c`
