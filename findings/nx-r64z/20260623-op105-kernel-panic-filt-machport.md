# op-105 — kernel panic: use-after-free in ipc_mqueue_pset_receive via filt_machport (bl-009)

Date: 2026-06-23. Lane: `rmx-explorer-rx-x64z`. rmxOS alpha `129ee3ce8d52`.

## Finding

The 2h soak (op-105) **crashed on the first iteration** with a kernel panic — a use-after-free in the compat/mach IPC layer, triggered by the harness's dispatch_source MACH_RECV create/destroy cycle. The op-104 120s proof (451 iterations) did not hit it (the race is intermittent).

## Panic details

```text
Fatal trap 9: general protection fault while in kernel mode
rcx: deadc0dedeadc0d8  rax: deadc0dedeadc0de   ← DEADC0DE poison (freed memory)
panic: general protection fault
current process = 2515 (harness)

Stack backtrace:
__mtx_lock_sleep()                    ← GPF: locking a mutex on freed memory
__mtx_lock_flags()
ipc_mqueue_pset_receive() at +0xbf    ← dereferences a freed mqueue/port-set
filt_machport() at +0x269             ← kqueue EVFILT_MACHPORT event callback
kqueue_scan()
kqueue_kevent() → kern_kevent_fp() → kern_kevent() → sys_kevent()
--- syscall (560, FreeBSD ELF64, kevent) ---
```

## Root cause

The harness's dispatch_source MACH_RECV test creates a receive port + a dispatch_source (backed by EVFILT_MACHPORT) + sends a message + the handler services it + destroys the source/port. This cycle triggers a race: a port or message-queue object is freed, but the kqueue's `filt_machport` knote still references it. On the next `kevent()` scan, `filt_machport` calls `ipc_mqueue_pset_receive` which tries to lock a mutex on the freed object → GPF (the DEADC0DE poison pattern in the freed memory causes the general protection fault).

This is a **use-after-free in `ipc_mqueue_pset_receive`** (sys/compat/mach/ipc/ipc_mqueue.c) when accessed via the `filt_machport` kqueue filter (sys/compat/mach/ipc/ipc_pset.c) after the underlying port/mqueue is destroyed.

## Impact

- Blocks op-105 (the 2h soak cannot complete until this is fixed).
- Any sustained dispatch_source MACH_RECV create/destroy workload will eventually trigger this panic (intermittent race; manifested on iteration 1 here, 451+ iterations in the op-104 proof).
- Laddered to **bl-009** (kernel use-after-free in compat/mach IPC via filt_machport).

## Pins

```text
serial log sha256: a60387a55adf75bb9b9c093fe3b20f8b47863af666d9903160af8b8a48342994
run dir: block-078-runtime-smoke/runs/20260623T041533Z-op105-soak-2h
```
