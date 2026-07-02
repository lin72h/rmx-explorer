# op-241 — MACH_RECV servicing premise-check — LIVE GAP (kernel panic)

Date: 2026-07-02. Lane: `rmx-explorer-rx-x64z` (rx1). Premise-verify + source read.
Source: `wip-gpt/wip-rmxos` @ HEAD `106f9d7fd160`. Image: golden `leg4-soak.img`.

## D1: premise check — KERNEL PANIC

The MACH_RECV source was created, resumed, and a Mach message was sent. The handler was ABOUT to fire (the JSON output was interrupted mid-write) when the KERNEL PANICKED:

```
panic: mtx_lock() of spin mutex (null) @ /usr/src/sys/compat/mach/ipc/ipc_kmsg.c:2844

Backtrace:
  ipc_kmsg_copyout_dest() at ipc_kmsg_copyout_dest+0x77
  msg_receive_error() at msg_receive_error+0x3e
  mach_msg_receive() at mach_msg_receive+0x22b
  mach_msg_overwrite_trap() at mach_msg_overwrite_trap+0xb9
  sys_mach_msg_overwrite_trap() at sys_mach_msg_overwrite_trap+0xa1
  amd64_syscall()
```

The probe output confirms:
1. Port allocated ✓ (port=20)
2. Source created ✓
3. Source resumed ✓ (kevent armed)
4. Mach message send triggered the receive path
5. **KERNEL PANIC** during `ipc_kmsg_copyout_dest` at line 2844 — `io_lock(dest)` on a port whose mutex is NULL

```text
OP241_HANDLER_FIRED: INDETERMINATE — kernel panicked before handler could complete
OP241_MACH_RECV_SERVICED: NO — kernel panic prevents servicing
OP241_DARK_LABEL: CONFIRMED — MACH_RECV is NOT stale; it's a live kernel IPC defect
```

## D2: routing read + panic trace

### The panic site (ipc_kmsg.c:2834-2860)

`ipc_kmsg_copyout_dest(kmsg, space)` at line 2834:

```c
/* ipc_kmsg.c:2843-2845 */
dest = (ipc_object_t) kmsg->ikm_header->msgh_remote_port;
...
io_lock(dest);  /* line ~2844 — panics: dest->io_lock_data is a NULL spin mutex */
```

The message's `msgh_remote_port` points to an `ipc_object_t` whose internal mutex (`io_lock_data`) is NULL. `io_lock()` calls `mtx_lock_flags(&io_lock_data, ...)` on a NULL mutex pointer → kernel panic.

### Call chain

```
mach_msg(MACH_SEND_MSG) → kernel delivers message to recv port
  → dispatch source fires (kevent armed on EVFILT_MACHPORT)
  → mach_msg_receive() called by dispatch handler (or kernel)
  → msg_receive_error() — called when the receive encounters an error condition
  → ipc_kmsg_copyout_dest(kmsg, space) — tries to copy out the destination port
  → io_lock(dest) — dest->io_lock_data is NULL → PANIC
```

### Which engine?

The panic is in the KERNEL Mach compat layer (`sys/compat/mach/ipc/`), NOT in libdispatch's twq/pool servicing. The dispatch source WAS armed (the kevent registered on EVFILT_MACHPORT), and the kernel DID deliver the message. The crash is in the kernel's `ipc_kmsg_copyout_dest` during the receive-side message processing.

This means:
- The dispatch source creation/resume WORKS (libdispatch correctly arms the kevent)
- The kernel filter `filt_machport` WORKS (op-098 proven — the kevent fires)
- The KERNEL's message receive path has a NULL mutex bug in `ipc_kmsg_copyout_dest`

### Root cause hypothesis

The message's `msgh_remote_port` (the SEND right the probe created via `mach_port_insert_right`) points to an `ipc_port_t` whose `io_lock_data` mutex was never properly initialized. This could be:
1. The `mach_port_insert_right` path doesn't initialize the port's mutex when creating a MAKE_SEND right on an existing receive right
2. The send right created by `mach_port_insert_right` shares the same underlying `ipc_port_t` as the receive right — but the port's lock state is inconsistent
3. A use-after-free or uninitialized port object

The `io_lock` macro expands to `mtx_lock_flags(&((ipc_object_t)dest)->io_lock_data, ...)`. The panic says `(null)` — meaning `io_lock_data` itself is NULL (not just unlocked).

## D3: adjudication

**LIVE GAP — CONFIRMED.** MACH_RECV servicing is NOT dark due to a stale label. It's a live kernel IPC defect: `ipc_kmsg_copyout_dest` at `ipc_kmsg.c:2844` calls `io_lock(dest)` on a port whose `io_lock_data` mutex is NULL.

### Smallest falsifiable requirement (for downstream Implementer op)

```
BUG: mtx_lock() of NULL spin mutex at ipc_kmsg.c:2844 during mach_msg_receive
PATH: mach_msg_receive → msg_receive_error → ipc_kmsg_copyout_dest → io_lock(dest) → PANIC
SITE: sys/compat/mach/ipc/ipc_kmsg.c:2844 (io_lock on msgh_remote_port)
TRIGGER: dispatch_source_create(MACH_RECV) + mach_msg send → receive path
INVARIANT VIOLATED: port's io_lock_data mutex must be non-NULL when io_lock is called
FIX DIRECTION: ensure mach_port_insert_right / port creation initializes io_lock_data
```

This is a KERNEL-level fix (Implementer), not a libdispatch fix. The dispatch source servicing path works correctly up to the point where the kernel tries to process the received message.

**Confidence: 9/10** — the panic is first-hand, the backtrace is clear, the trigger is reproducible (single message round-trip).

```text
OP241_VERDICT: live-gap — kernel panic at ipc_kmsg.c:2844 (NULL io_lock_data mutex on received message's remote_port); not stale; not a twq/pool issue; KERNEL-level fix needed
OP241_CONFIDENCE: 9
OP241_TERMINAL status=0
```
