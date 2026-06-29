# op-212 — Mach-IPC-receive convergence probe (READ-ONLY)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY source census.
Source: `wip-gpt/wip-rmxos` @ `op-171-x86-64-v3-alpha`.

## D1: ipc_entry_lookup on name 0 — BENIGN NOISE, not a real drop

### Full path trace (file:line cited)

The `ipc_entry_lookup failed on 0` printf at `ipc_kmsg.c:1318` fires inside `ipc_kmsg_copyin_header` (ipc_kmsg.c:1026).

**Call chain:**
1. Userspace calls `mach_msg_send` → kernel `mach_msg.c:269` → `ipc_kmsg_copyin` (ipc_kmsg.c:1918)
2. `ipc_kmsg_copyin` calls `ipc_kmsg_copyin_header` (ipc_kmsg.c:1926)
3. `ipc_kmsg_copyin_header` extracts `dest_name = CAST_MACH_PORT_TO_NAME(msg->msgh_remote_port)` (line 1052)
4. If both `dest_name != 0` AND `reply_name != 0` (complex two-port copyin, line ~1258 `else` branch):
   - `ipc_entry_lookup(space, dest_name)` at line 1316
   - If `IE_NULL` → printf at line 1318 → `goto invalid_dest` → returns `MACH_SEND_INVALID_DEST`

**When `dest_name = 0`:** `msgh_remote_port = MACH_PORT_NULL`. The sender constructed a message with a NULL destination. This happens when:
- The sender's `bootstrap_port = MACH_PORT_NULL` (bl-016 under `-u` launchd)
- `bootstrap_look_up2(bootstrap_port, "com.apple.system.logger", &tmp, ...)` (asl_core.c:110) fails because `bootstrap_port = 0`
- `server_port = MACH_PORT_NULL` (asl_core.c returns NULL)
- `_asl_global.server_port = MACH_PORT_NULL` (asl.c:1132 check fails → skip send)
- BUT: some OTHER callers (non-ASL) may still construct Mach messages with `msgh_remote_port = 0` from stale port variables

**The kernel handles this correctly:** `ipc_entry_lookup(space, 0)` returns `IE_NULL` (name 0 is never a valid entry). The message is rejected with `MACH_SEND_INVALID_DEST`. The sender receives the error code.

**Classification: BENIGN NOISE.** The printf is a donor-inherited diagnostic (op-192 confirmed: NextBSD identical, 45 printfs in both trees). The kernel's rejection is correct. The spam correlates with processes that have `bootstrap_port = 0` (bl-016 under `-u` launchd) trying to use Mach IPC. Under PID-1 launchd (op-201), the bootstrap is CLOSED and this spam would disappear.

```text
OP212_PORT0_CHARACTERIZED: benign-noise — dest_name=0=MACH_PORT_NULL from bl-016 null-bootstrap callers; kernel correctly rejects with MACH_SEND_INVALID_DEST; donor-inherited printf (op-192); suppressed under PID-1 launchd (op-201: bootstrap CLOSED)
```

## D2: ASL-native submit trace — LOST BEFORE the Mach send, NOT at port-0

### The send path (file:line cited)

```
asl_log → _asl_send_message (asl.c:953)
  → asl_core_get_service_port (asl_core.c:96-112)
    → bootstrap_look_up2(bootstrap_port, "com.apple.system.logger", &tmp, ...) (asl_core.c:110)
    → if bootstrap_port=0 → fails → returns MACH_PORT_NULL
  → _asl_global.server_port = MACH_PORT_NULL (asl.c:149)
  → asl.c:1132: if (_asl_global.server_port != MACH_PORT_NULL) && (eval & EVAL_SEND))
    → FALSE (server_port IS NULL) → SEND IS SKIPPED ENTIRELY
  → message never reaches _asl_server_message (asl.c:1163)
  → message never reaches the Mach kernel → no ipc_entry_lookup → no port-0 printf
```

**The ASL submit is LOST at the USERSPACE LEVEL** — `asl_core.c:110` `bootstrap_look_up2` fails because `bootstrap_port = 0` (bl-016). The `server_port` stays NULL. The send-path guard at `asl.c:1132` (`server_port != MACH_PORT_NULL`) prevents the Mach send entirely. The message is silently dropped BEFORE it ever crosses the kernel boundary.

**Does it cross port-0?** NO. The message never reaches `ipc_kmsg_copyin_header`. The `_asl_server_message` Mach mig call (asl.c:1163) is never invoked because the guard at line 1132 fails. The port-0 printf at ipc_kmsg.c:1318 is triggered by OTHER callers (non-ASL processes that construct raw Mach messages with stale/null ports), not by libasl.

**op-210's "found=0" drops:** if the ASL-native submit test was run by a process with `bootstrap_port = 0` (non-launchd child under `-u`), the message is lost at `asl_core.c:110` — never reaches asld. The fix is PID-1 launchd (op-201: bootstrap_port=0x13, CLOSED) OR running as a launchd child (inherits bootstrap via runtime_fork).

### libdispatch MACH_RECV servicing

The MACH_RECV path in libdispatch does NOT cross port-0:
- libdispatch's `DISPATCH_SOURCE_TYPE_MACH_RECV` uses `dispatch_source_create` with the Mach port it receives from its event handler
- The port comes from `xpc_connection_recv_message` (xpc_connection.c:517) which receives on `conn->xc_local_port` — a port ALLOCATED by the process itself (xpc_connection.c:73: `mach_port_allocate(MACH_PORT_RIGHT_RECEIVE, &conn->xc_local_port)`)
- This port is NOT bootstrap_port-dependent — it's a self-allocated receive right
- The MACH_RECV servicing is GATED by whether the connection was successfully established (which DOES depend on bootstrap_port for service lookup), but the RECEIVE itself operates on the process's own port

**Does port-0 gate MACH_RECV?** NO — the receive side operates on a self-allocated port. The SEND side (reaching the service) depends on bootstrap_port. If bootstrap_port=0, the connection is never established (the `bootstrap_look_up` in `xpc_connection_create_mach_service` fails), so there's nothing to receive. But this is a connection-establishment failure, not a port-0 receive defect.

```text
OP212_ASL_SUBMIT_TRACED: lost at userspace (asl_core.c:110 bootstrap_look_up2 fails on bootstrap_port=0 → server_port=NULL → asl.c:1132 send guard skips); message never reaches Mach kernel; does NOT cross port-0; MACH_RECV operates on self-allocated ports (not bootstrap-dependent)
```

## D3: verdict — INDEPENDENT, not shared-root

The port-0 printf and the ASL submit drop are **independent symptoms of the SAME root cause (bl-016 null-bootstrap)** but they are **NOT the same defect**:

1. **port-0 printf** (ipc_kmsg.c:1318): kernel-level diagnostic when a SENDER constructs `msgh_remote_port=0`. Triggered by raw Mach message sends from processes with stale/null port variables. The kernel correctly rejects. Does NOT affect the ASL path (ASL never reaches the kernel with port-0).

2. **ASL submit drop** (asl_core.c:110 → asl.c:1132): userspace-level message loss when `bootstrap_port=0` prevents service port lookup. The message is silently dropped BEFORE any Mach IPC. Independent of the port-0 kernel path.

3. **MACH_RECV servicing**: operates on self-allocated ports. Not gated by port-0. Connection establishment IS gated by bootstrap_port, but that's a separate concern from receive-side servicing.

**Both (1) and (2) are symptoms of bl-016 (null-bootstrap under `-u` launchd), which op-201 PROVED is CLOSED under PID-1 launchd.** They are not separate Mach-IPC defects. They do NOT bear on debt-#21 MACH_RECV servicing as an independent issue.

```text
OP212_VERDICT: independent — port-0 printf (kernel diagnostic on bl-16 null-bootstrap) and ASL submit drop (userspace service-port lookup failure on bl-16) are both symptoms of the SAME root cause (bl-016); CLOSED under PID-1 launchd (op-201); do NOT bear on debt-#21 MACH_RECV servicing (that path operates on self-allocated ports)
```
