# mx-a64z OB1.1 Port Names Result

Date: 2026-05-12

Agent: `mx-a64z`

Probe: `foundation/port_names.c`

Test ID: `macos_foundation_port_names`

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
macos-validation/results/mx-a64z/20260512-26.5-25.5.0/foundation_port_names.json
```

Empty stderr logs were not force-added:

```text
foundation_port_names.stderr.log: 0 bytes
foundation_smoke.stderr.log: 0 bytes
signing.stderr.log: 0 bytes
```

## Harness Summary

```text
Summary: 2 probes, 2 pass, 0 fail, 0 skip
Validated: 2 files, 2 pass, 0 fail
```

## Port Names Result

```json
{
  "agent": "mx-a64z",
  "test_id": "macos_foundation_port_names",
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
      "call": "mach_port_names_after_allocate",
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
      "call": "mach_port_names_after_destroy",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    }
  ],
  "right_deltas": [
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
  ],
  "observations": {
    "names_before": 11,
    "names_after_allocate": 12,
    "names_after_destroy": 11,
    "allocation_delta": 1,
    "cleanup_delta": 0,
    "probe_port_seen": true,
    "probe_port_label": "port_names_probe_port"
  },
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

## Finding

On native Apple Silicon macOS 26.5 / Darwin 25.5.0, `mach_port_names()` is
reliable for the OB1.1 foundation contract:

- initial namespace capture returned `KERN_SUCCESS`
- allocated receive right was visible through `mach_port_names()`
- observed right type was `MACH_PORT_TYPE_RECEIVE`
- namespace count increased by exactly one after allocation
- destroy returned `KERN_SUCCESS`
- final namespace matched the baseline exactly
- cleanup returned to baseline

No OB1.1 stop condition occurred on `mx-a64z`.
