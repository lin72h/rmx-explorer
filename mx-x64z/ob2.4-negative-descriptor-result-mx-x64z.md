# mx-x64z OB2.4 Negative Descriptor Result

Date: 2026-05-13

Agent: `mx-x64z`

Probes:

- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/double_move_send_descriptor.c`

Test IDs:

- `macos_m2_invalid_descriptor_disposition`
- `macos_m2_dead_name_descriptor_right`
- `macos_m2_double_move_send_descriptor`

## Host

```text
hostname: rkl.local
uname -m: x86_64
sw_vers:
  ProductName: macOS
  ProductVersion: 26.4
  BuildVersion: 25E246
uname -r: 25.4.0
```

Native Intel macOS.

## Commands

```sh
git pull --ff-only
cd macos-validation
make clean all
make run AGENT=mx-x64z
make validate-json
```

`make run AGENT=mx-x64z` completed all probes but exited nonzero because
`m2/dead_name_descriptor_right` produced a `status: fail` result. JSON schema
validation passed after the run.

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-x64z/20260513-26.4-25.4.0
```

Raw artifacts force-added for commit:

```text
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/environment.json
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m2_invalid_descriptor_disposition.json
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m2_dead_name_descriptor_right.json
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m2_double_move_send_descriptor.json
```

Empty stderr logs were not force-added.

## Harness Summary

```text
Summary: 12 probes, 11 pass, 1 fail, 0 skip
Validated: 27 files, 27 pass, 0 fail
```

## invalid_descriptor_disposition

Result: `pass`

Setup: one service send right plus one cargo send/receive right. The message
used `msgh_bits` `0x80000013`, header remote disposition
`MACH_MSG_TYPE_COPY_SEND`, and one port descriptor with invalid raw disposition
`0xff`.

Observed behavior:

- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT` (`268435466`)
- receiver attempt after send: `MACH_RCV_TIMED_OUT` (`268451843`)
- message delivered: `false`
- service send refs: `1 -> 1`
- cargo send refs: `1 -> 1`
- cargo type: `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_SEND_RECEIVE`
- cleanup delta: `0`
- `entry_refs_before` / `entry_refs_after`: `null`

## dead_name_descriptor_right

Result: `fail`

Setup: separate cases for a `MACH_PORT_RIGHT_DEAD_NAME` descriptor source and a
nonexistent descriptor source. Both messages used `msgh_bits` `0x80000013`,
header remote disposition `MACH_MSG_TYPE_COPY_SEND`, and descriptor disposition
`MACH_MSG_TYPE_MOVE_SEND`.

Dead-name source behavior:

- source before send: `MACH_PORT_TYPE_DEAD_NAME`, refs `1`
- `mach_msg(SEND)`: `MACH_MSG_SUCCESS` (`0`)
- source after send: `KERN_INVALID_NAME`
- receiver attempt after send: `MACH_MSG_SUCCESS` (`0`)
- message delivered: `true`
- received descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- cleanup delta: `0`

Nonexistent-name source behavior:

- source before send: `KERN_INVALID_NAME`
- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT` (`268435466`)
- source after send: `KERN_INVALID_NAME`
- receiver attempt after send: `MACH_RCV_TIMED_OUT` (`268451843`)
- message delivered: `false`
- cleanup delta: `0`

The dead-name subcase violates the expected no-delivery/no-mutation behavior:
native macOS accepts the dead-name descriptor, consumes the dead-name entry, and
delivers a message. This is observable with public APIs and cleanup still
returns to baseline.

## double_move_send_descriptor

Result: `pass`

Setup: one service send right plus one cargo send/receive right. The message
used `msgh_bits` `0x80000013`, header remote disposition
`MACH_MSG_TYPE_COPY_SEND`, and two port descriptors naming the same cargo port,
both with descriptor disposition `MACH_MSG_TYPE_MOVE_SEND`.

Observed behavior:

- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT` (`268435466`)
- receiver attempt after send: `MACH_RCV_TIMED_OUT` (`268451843`)
- message delivered: `false`
- cargo send refs: `1 -> 0 -> 0`
- cargo type: `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_RECEIVE`
- sender consumption class: `fully_consumed`
- cleanup delta: `0`
- `entry_refs_before` / `entry_refs_after`: `null`

## Finding

OB2.4 should not be closed from the current pass criteria. The invalid
disposition and double `MOVE_SEND` probes are clean on native Intel macOS, but
`dead_name_descriptor_right` found that a dead-name source is delivered and
consumed rather than rejected. The raw JSON is committed so the parent can
decide whether this is accepted macOS contract behavior or a gate failure.

No OB2.5 probe was started.
