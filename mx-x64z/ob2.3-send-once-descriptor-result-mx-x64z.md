# mx-x64z OB2.3 Send-Once Descriptor Result

Date: 2026-05-13

Agent: `mx-x64z`

Probe: `m2/send_once_descriptor.c`

Test ID: `macos_m2_send_once_descriptor`

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

## Result Directory

```text
/Users/linz/Local/wip-mach/mach-oracle/macos-validation/results/mx-x64z/20260513-26.4-25.4.0
```

Raw artifacts for commit:

```text
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/environment.json
macos-validation/results/mx-x64z/20260513-26.4-25.4.0/m2_send_once_descriptor.json
```

Empty stderr logs were not force-added.

## Harness Summary

```text
Summary: 9 probes, 9 pass, 0 fail, 0 skip
Validated: 21 files, 21 pass, 0 fail
```

## Send-Once Descriptor Result

Status: `pass`

Semantic class: `exact_contract`

Key observations:

- send-once creation API: `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child cargo type before send-once creation: `MACH_PORT_TYPE_RECEIVE`
- child extracted acquired type: `MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE`
- child send-once type before send: `MACH_PORT_TYPE_SEND_ONCE`
- child send-once refs before send: `1`
- child send-once right consumed after descriptor send: `true`
- child send-once type/refs after send: `KERN_INVALID_NAME`
- sent descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND_ONCE`
- sent descriptor message bits: `0x80000013`
- received descriptor message bits: `0x80001100`
- received descriptor count: `1`
- delivered descriptor disposition raw hex: `0x12`
- delivered descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE`
- parent delivered port type: `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs: `1`
- first delivered-right use returned `MACH_MSG_SUCCESS`
- delivered right consumed after first use: `true`
- second delivered-right use returned `MACH_SEND_INVALID_DEST`
- second use blocked: `true`
- child first verification receive returned `MACH_MSG_SUCCESS`
- child second verification receive returned `MACH_RCV_TIMED_OUT`
- child received second verification: `false`
- child cleanup delta: `0`
- parent cleanup delta: `0`
- cleanup returned to baseline: `true`
- `entry_refs_before` and `entry_refs_after` remain `null`

## Finding

On native Intel macOS 26.4 / Darwin 25.4.0, descriptor
`MACH_MSG_TYPE_MOVE_SEND_ONCE` consumes the child's send-once right at
successful `mach_msg(SEND)` return and delivers a usable one-shot right to the
parent. The parent can send exactly one verification message through it; a
second send is rejected with `MACH_SEND_INVALID_DEST`, and the child receives no
second verification message.

No OB2.3 stop condition occurred on `mx-x64z`.

No OB2.4 probe was started.
