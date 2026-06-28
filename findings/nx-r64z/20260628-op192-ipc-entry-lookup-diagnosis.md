# op-192 — ipc_entry_lookup failed on 0 diagnosis (READ-ONLY)

Date: 2026-06-28. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY.
Source: `wip-gpt/wip-rmxos` @ `op-171-x86-64-v3-alpha`. Donor: `nx/NextBSD`.

## Q1: call site + flow

**Enclosing function:** `ipc_kmsg_copyin_header` (ipc_kmsg.c:1026).

This function is called during `mach_msg_send` to validate + copyin port rights from the message header. The flow:

```c
/* ipc_kmsg.c:1026-1052 */
ipc_kmsg_copyin_header(kmsg, space, notify_name) {
    mach_msg_header_t *msg = kmsg->ikm_header;
    mach_msg_type_name_t dest_type = MACH_MSGH_BITS_REMOTE(msg->msgh_bits);
    mach_port_name_t dest_name = CAST_MACH_PORT_TO_NAME(msg->msgh_remote_port);
    // dest_name comes DIRECTLY from the message header's msgh_remote_port

    /* ... later in the complex-descriptor path ... */
    /* ipc_kmsg.c:1316-1320 */
    dest_entry = ipc_entry_lookup(space, dest_name);  // dest_name = 0 = MACH_PORT_NULL
    if (dest_entry == IE_NULL) {
        printf("ipc_entry_lookup failed on %d %s:%d\n", dest_name, __FILE__, __LINE__);
        goto invalid_dest;  // returns MACH_SEND_INVALID_DEST
    }
}
```

**`dest_name` = `msg->msgh_remote_port`** — the DESTINATION port name in the sender's namespace. When the sender sets `msgh_remote_port = MACH_PORT_NULL = 0` (because it doesn't have a valid port for the destination), the lookup fails.

**Who passes name==0:** Processes without a bootstrap port (bl-016 ambient-bootstrap gap, op-119). When `bootstrap_port = MACH_PORT_NULL`, `bootstrap_look_up` returns 0 for the service port → the sender puts 0 in `msgh_remote_port` → `ipc_entry_lookup(space, 0)` returns `IE_NULL`.

## Q2: is name==0 legitimately reachable? Donor comparison.

**Yes, name==0 is spec-legal.** `MACH_PORT_NULL` (0) is a reserved name that never has a port-space entry. A sender can legally construct a message with `msgh_remote_port = 0` — the kernel rejects it with `MACH_SEND_INVALID_DEST`, which is the CORRECT behavior.

**Donor verification (verify_signature_divergence):**
- **NextBSD has the IDENTICAL printf** at ipc_kmsg.c:1318: `printf("ipc_entry_lookup failed on %d %s:%d\n", dest_name, __FILE__, __LINE__);`
- NextBSD ALSO has a SECOND instance at line 1257: `printf("ipc_entry_lookup failed on dest_name=%d\n", dest_name);`
- **Both trees have exactly 45 printf calls** in ipc_kmsg.c — identical count
- The diff between wip-rmxos and NextBSD at lines 1310-1325 is EMPTY (identical code)

**This printf is NOT an rmxOS-local addition — it's INHERITED from NextBSD (the donor).** The donor has the same diagnostic pattern throughout the file. Verify-first confirmed: no divergence.

## Q3: noise or symptom?

**BENIGN NOISE.** The timing discriminator confirms:

- **Startup burst** (at "Starting local daemons"): rc.d-launched processes (syslogd, devd) try Mach IPC without a launchd-provided bootstrap port (bl-016). Their `bootstrap_look_up` returns 0 → sends with `msgh_remote_port=0` → printf fires. These processes EXPECT to fail Mach IPC — they fall back to FreeBSD-native mechanisms.

- **Shutdown burst** (at "syslogd exiting on signal 15"): during teardown, processes may send cleanup messages via ports that are already destroyed or via the null bootstrap. Same mechanism, same correct rejection.

The kernel handles this correctly:
1. `ipc_entry_lookup(space, 0)` → `IE_NULL` (correct — name 0 is reserved)
2. `goto invalid_dest` → returns `MACH_SEND_INVALID_DEST` to the caller
3. The caller (libnotify/libasl/etc.) receives the error and handles it (or ignores it)

**The 4h soak ran CLEAN** (op-168) — no crash, no stall, no corruption. The messages are diagnostic noise from the expected bl-016 null-bootstrap path. The kernel's handling is correct; the printf is just verbose.

## OP192 markers

```text
OP192_CALL_SITE: ipc_kmsg_copyin_header (ipc_kmsg.c:1026); dest_name = msg->msgh_remote_port (line 1052); lookup at line 1316-1320
OP192_NAME0_CASE: MACH_PORT_NULL (0) — spec-legal; sender without bootstrap port (bl-016); kernel correctly rejects with MACH_SEND_INVALID_DEST
OP192_NOISE_OR_SYM: benign-noise — donor-inherited diagnostic printf (NextBSD identical, 45 printfs in both trees); 4h soak ran clean; correct kernel behavior
OP192_VERDICT: benign-noise (gate the printf — Implementer follow-up to reduce serial verbosity; NOT a code defect)
OP192_TERMINAL status=0
```
