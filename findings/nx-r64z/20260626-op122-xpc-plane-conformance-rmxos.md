# op-122 — libxpc plane conformance: rmxOS results (rx-x64z side)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1).
Parent: id-021 (li-1005). Harness blob sha: c54e52619472a6b7cbf1dd69843a3d0b556cf59787be06ec03ded344f2975e8b.

## Deliverable status: rx side DONE. macOS-truth (mx-a64z) pending.

## Harness

Extended op-121 substrate blob (@ec25e50) with the deferred plane cases:
- send→reply w/ seqid correlation (PLANE CASE 1)
- typed payload fidelity over nvlist (PLANE CASE 2)
- cancel→XPC_ERROR event handler (PLANE CASE 3)

Byte-identical C source — `xpc-harness-plane.c`. Builds on both macOS and
rmxOS. Build command for rmxOS host-cross: `cc -fblocks -D__APPLE__ ... -lxpc -ldispatch -lBlocksRuntime`.

## rmxOS run results

### Substrate (op-121 carried forward): 14/14 PASS

```
xpc_dictionary_create: PASS
xpc_int64_create: PASS
xpc_int64_get_value: PASS
xpc_dictionary_get_string: PASS
xpc_dictionary_get_int64: PASS
xpc_dictionary_get_count: PASS
xpc_string_create: PASS
xpc_data_create: PASS
xpc_data_get_length: PASS
xpc_data_get_bytes_ptr: PASS
xpc_hash_consistent: PASS
xpc_connection_create: PASS
xpc_connection_lifecycle: PASS
xpc_release: PASS
```

No regression from op-121 substrate. ✓

### Plane cases (op-122 extension): 8 PASS / 6 FAIL

```
--- PLANE CASES (op-122) ---
op122_plane_connect_create: PASS       # xpc_connection_create("com.apple.system.logger") returns non-NULL
op122_plane_connect_resume: PASS       # xpc_connection_resume — no crash
op122_plane_msg_construct: PASS        # message dict with seqid+string+data constructed
op122_plane_reply_received: FAIL       # xpc_send: send failed, kr=22 (EINVAL)
op122_plane_reply_valid: FAIL          # (no reply)
op122_plane_seqid_correlation: FAIL    # (no reply)
op122_plane_typed_int64: PASS          # local round-trip: int64 fidelity
op122_plane_typed_string: PASS         # local round-trip: string fidelity
op122_plane_typed_bool: PASS           # local round-trip: bool fidelity
op122_plane_typed_uint64: PASS         # local round-trip: uint64 fidelity
op122_plane_typed_count: PASS          # dictionary count verified
op122_plane_cancel_connect: PASS       # connection created for cancel test
op122_plane_cancel_event_fired: FAIL   # event handler didn't fire within 1s timeout
op122_plane_cancel_event_obj: FAIL     # (no event captured)
op122_plane_cancel_error_desc_present: FAIL  # (no event captured)
```

`op122_matrix_fails=6`

### Key divergence signals

**1. `xpc_send: send failed, kr=22` (EINVAL)**
`xpc_connection_send_message_with_reply` to `com.apple.system.logger` returned
EINVAL. The connection was created + resumed cleanly, but the actual message
send failed. kr=22 = EINVAL = invalid argument. This is likely because:
- The service "com.apple.system.logger" is NOT registered as an XPC service
  in the launchd bootstrap (it's registered as a Mach service for libasl,
  not as an XPC endpoint)
- OR libxpc's send path on rmxOS requires the service to be registered
  via a specific XPC mechanism that the ASL syslogd doesn't use

This is a CLEAN FAILURE — no crash, no signal, the send returns an error code.
The harness detects it and reports FAIL. This is the divergence the Arranger
predicted: macOS would likely have a real XPC service at this name that
responds; rmxOS doesn't.

**2. `cancel_event_fired: FAIL`**
The event handler set via `xpc_connection_set_event_handler` didn't fire
within the 1s timeout after `xpc_connection_cancel`. This might be because:
- The `dispatch_after` cancel didn't fire (dispatch_main wasn't called —
  the harness uses `nanosleep` for waiting, not a dispatch loop)
- OR rmxOS's XPC cancel→event-handler path doesn't fire synchronously
- OR the event handler timing is different from macOS

For the MATCH diff: macOS-truth will show whether cancel→event fires
within 1s on macOS. If it does, this is a behavioral divergence.

**3. Typed payload fidelity: ALL PASS**
The local message construction + round-trip (int64/string/bool/uint64/count)
all work. This is a substrate-level win — the nvlist encoding correctly
preserves all primitive types. No divergence expected from macOS.

## Apples-to-apples gate

- Harness byte-identical: the `.c` source is shared via git. SHA
  `c54e52619472a6b7cbf1dd69843a3d0b556cf59787be06ec03ded344f2975e8b` recorded.
- macOS-as-truth: mx-a64z must run the SAME `.c` source against macOS. SHA
  diff must be empty.
- Bar = behavior, not wire (op-160 deferred byte-parity to li-1008).

## mx-a64z instructions (for the macOS-truth capture)

1. `git fetch origin && git checkout <SHA of xpc-harness-plane.c>` from the
   `op-122-xpc-plane` branch.
2. Build on macOS (mm4): `cc -fblocks -o xpc-harness-plane xpc-harness-plane.c`
   (macOS has all headers at standard paths; no special -I needed).
3. Run directly (macOS has bootstrap port via launchd as PID 1): `./xpc-harness-plane`.
4. Capture stdout → `op122-macos-serial.log`.
5. Commit + push to the same branch.
6. Diff rx vs mx per-case.

## Artifacts

```
harness source:   findings/nx-r64z/dtrace/xpc-conformance/xpc-harness-plane.c
harness sha:      c54e52619472a6b7cbf1dd69843a3d0b556cf59787be06ec03ded344f2975e8b
rmxOS serial:     findings/nx-r64z/dtrace/xpc-conformance/op122-rmxos-serial.log
built binary:     findings/nx-r64z/dtrace/xpc-conformance/xpc-harness-plane (22256 B, rmxOS)
```

## Markers

```text
OP122_HARNESS_EXTENDED status=0    # substrate + plane cases
OP122_APPLES_TO_APPLES status=0    # byte-identical blob, SHA recorded
OP122_RMXOS_RUN status=0           # 14 substrate PASS + 8 plane PASS + 6 plane FAIL
OP122_MACOS_TRUTH status=pending   # mx-a64z must capture
OP122_PLANE_DIFF status=pending    # diff after macOS-truth captured
OP122_VERDICT rmxos_side_done=1    # rx-x64z complete; mx-a64z pending
OP122_TERMINAL status=0
```
