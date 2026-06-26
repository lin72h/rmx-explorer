# op-153 — id-025 hypervisor-level gdb-stub capture + identity verdict (WORKING)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1). Per op-147m: Elixir +
Python capture (host-side) + kgdb; no shell harness.

## §2a Test Strategy block (op-147m compliance)

| layer | tool | role |
|---|---|---|
| ORCHESTRATION | Elixir | (would normally drive; for this one-shot, Python capture script stands in — observation/capture only, no verdict-emit) |
| OBSERVATION/CAPTURE | Python + kgdb | `scripts/op151/op153-capture-gdb.py` — TCP serial freeze-detect + bhyve -G stub attach + kgdb batch script via stdin |
| LOW PROBE | Zig | NOT USED |
| shell | thin glue | single bhyveload + single bhyve + single python invocation |

## OP147M acks

```text
OP147M_METHOD_ACK status=0 role=explorer
OP147M_ELIXIR_SPINE_OK status=0
OP147M_DTRACE_D_OK status=0    # .d not used here; kgdb is the evidence layer
OP147M_NO_SHELL_HARNESS status=0
```

## §0 — gdb install + kernel symbols

- `pkg install -y gdb` → /usr/local/bin/{gdb,kgdb} installed
- Kernel binary extracted from golden image: `/Users/me/wip-mach/build/op153-kernel/kernel` (31MB, MACHDEBUGDEBUG, BuildID 950bb198837021982df5cdd589845a75b0515fa7)
- `kernel.debug` (matching mtime/size): `/Users/me/wip-mach/build/official-stable15-mach-obj/.../sys/MACHDEBUGDEBUG/kernel.debug` (114MB, .text=0x00e4a17c matches kernel's .text)
- **mach.ko.debug** (compat/mach symbols, the actual deadlock surface): `/Users/me/wip-mach/build/block-075-alpha-final-obj/.../sys/modules/mach/mach.ko.debug` — has `ipc_mqueue_receive` @ 0x1a410, `ipc_mqueue_pset_receive` @ 0x19f10, `thread_pool_wakeup` @ etc.
- mach.ko extracted from golden image: `/Users/me/wip-mach/build/op153-kernel/mach.ko` (345456 bytes — same as kernel module on guest)

**Key insight:** compat/mach code is a LOADABLE MODULE (mach.ko), NOT built into the kernel binary. `nm kernel.debug | grep ipc_mqueue` returns EMPTY. The deadlock surface lives entirely in mach.ko.debug. kgdb must use `add-kld mach <mach.ko.debug>` to resolve module symbols.

## §1 — ipc_kmsg.c:1318 first-hand read: SYMPTOM, NOT CAUSE

```c
/* sys/compat/mach/ipc/ipc_kmsg.c:1316-1320 */
dest_entry = ipc_entry_lookup(space, dest_name);
if (dest_entry == IE_NULL) {
    printf("ipc_entry_lookup failed on %d %s:%d\n", dest_name, __FILE__, __LINE__);
    goto invalid_dest;
}
```

`dest_name = 0` (MACH_PORT_NULL). This is **bl-016 ambient-bootstrap gap** (op-119):
non-launchd processes have `bootstrap_port = MACH_PORT_NULL`, so libnotify/libasl/
`bootstrap_look_up` calls return service port = 0, and subsequent sends trigger
this printf. The kernel is correctly rejecting an invalid destination from a
userspace process without a bootstrap.

`ipc_entry_lookup failed on 0` is **NOT the freeze cause** — it's the kernel
correctly handling bl-016. The spam is noise from the same processes that
produce it during normal operation (op-110 notify, op-124 asl lifecycle both
had this spam and worked fine).

`OP153_IPC_KMSG_1318 cause=0 symptom=1` — the Arranger's hypothesis confirmed
first-hand.

## §2 — gdb-stub capture rig authored

- `scripts/op151/op153-capture-gdb.py` (Python, observation only)
- Launches bhyve with `-G 127.0.0.1:12345` (gdb stub) + `-l com1,tcp=127.0.0.1:14677` (TCP serial for freeze-detect)
- On freeze (serial silence > 90s + bhyve still alive): pipes kgdb commands via stdin
- Commands: `target remote :12345`, `add-kld mach <mach.ko.debug>`, `bt`, `info threads`, `thread apply all bt`, `info address <fn>` for key Mach functions
- Force-poweroffs the bhyve at end

bhyve -G stub syntax: `-G [w][bind_address:]port`. Just `-G 12345` did NOT bind
(rejected silently); `-G 127.0.0.1:12345` worked. Both ports now listening.

## §3 — freeze-5 capture (DONE) — REFUTES "MY FAST-FREEZE = id-025"

**kgdb attached across a real freeze. Captured backtraces from BOTH vCPUs.**

### What kgdb captured

```
0xffffffff810be2d4 in cpu_idle_acpi (sbt=40140102)
   at /usr/src/sys/x86/x86/cpu_machdep.c:363
363		__asm __volatile("sti; hlt");

Thread 1 (vCPU 0) bt:
#0  cpu_idle_acpi         cpu_machdep.c:363
#1  cpu_idle              cpu_machdep.c:801
#2  sched_ule_idletd      sched_ule.c:3168
#3  fork_exit             kern_fork.c:1199
#4  <signal handler called>

Thread 2 (vCPU 1) bt: identical structure (different sbt values)
```

**Both vCPUs are in the IDLE THREAD (`sched_ule_idletd` → `cpu_idle` → `cpu_idle_acpi`'s `sti; hlt`).** No mach compat code in either stack. No mutex held. No `msleep`, no `mtx_lock`, no `ipc_mqueue_*`.

### What kgdb could NOT find

```
warning: Could not load shared library symbols for mach.ko.
Unable to locate kld
No symbol "ipc_mqueue_receive" in current context.
```

**mach.ko is NOT LOADED in the guest.** The kgdb `add-kld` failed because the module isn't there. The guest kernel never ran `kldload mach` — which is the FIRST thing rc.local does.

### Interpretation

The serial output stopped at `Mounting late filesystems:.` — which is a normal FreeBSD rc.d step BEFORE `/etc/rc.d/local` runs `/etc/rc.local`. The system hung in the rc.d sequence, **before rc.local ever ran**.

If rc.local never ran:
- `kldload mach` never happened → mach.ko not loaded (confirmed by kgdb)
- launchd -u never started → no `ipc_entry_lookup failed on 0` spam from launchd
- churn probe never started → no OP150_CHURN_* markers (confirmed in serial)
- op-148 watchpoint never started → no OP148_HB markers (confirmed in serial)

The kernel is idle because **no userspace work exists to schedule** — the boot is hung waiting for something between "Mounting late filesystems:" and "Starting local daemons:". Both vCPUs naturally fall into HLT.

## §4 — identity verdict: REFUTES "my fast-freeze = id-025"

```text
OP153_GDB_INSTALLED status=1
OP153_GDB_STUB_ATTACHED status=1
OP153_BLOCKED_STACKS_CAPTURED status=1   # both vCPU stacks captured
OP153_DEADLOCK_IDENTIFIED status=0       # NO deadlock — kernel is idle
OP153_IPC_KMSG_1318 cause=0 symptom=1    # first-hand read confirms
OP153_IDENTITY_VERDICT notifyd_ipc_deadlock=0 different_wedge=1
OP153_FINGERPRINT_TRULY_MATCHED status=0
OP153_TERMINAL status=0
```

**My "fast-freeze" (op-151's 3/3 BREAKTHROUGH claim) is NOT id-025.** op-151's
`OP151_FINGERPRINT_MATCH=1` was correctly flagged as over-claimed by the Arranger.
The kgdb capture confirms: no mach compat code in any vCPU stack, mach.ko not
loaded, kernel idle. This is a DIFFERENT wedge — a FreeBSD rc.d boot hang,
unrelated to the id-025 Mach-IPC deadlock race.

**op-151's reproducibility claim (3/3 fast freeze) stands** — the freeze IS
reproducible. But it's reproducing the WRONG bug. The op-150 freeze (churn iter
≈400 with `ipc_entry_lookup failed` storm from active launchd) is the actual
id-025 candidate; my fast-freeze is in something earlier (rc.d boot).

### Reconciliation with op-150

op-150 froze at churn iter≈400 with watchpoint heartbeats 0-40s then silent.
That requires launchd to have started, churn probe running, THEN froze. My
fast-freeze never gets that far.

Two possibilities for the divergence:
- (H1) **op-150 won a stochastic race past the rc.d hang point** (rare) and
  then froze later in the actual id-025 code. My runs lose the rc.d race
  earlier. Both bugs exist; only my reproduction is hitting the wrong one.
- (H2) **op-150's image / setup differed** in a way that bypassed the rc.d hang
  (e.g., different kldload order, different ldconfig state). My fresh-clone
  doesn't have whatever bypass op-150 had.

Either way: **the op-151 §A "BREAKTHROUGH" was mis-attributed to id-025**. The
Arranger's caution was warranted. This op REFUTES that claim.

### What this op delivered

- **§A.1-SYMPTOM confirmed:** `ipc_entry_lookup failed on 0` is bl-016 noise,
  not the freeze cause.
- **§3 hypervisor-level capture RIG proven:** kgdb attaches cleanly via bhyve
  -G stub, captures both vCPU stacks across a real freeze. The RIG works.
- **§4 IDENTITY: my fast-freeze is a different wedge** — not id-025. Re-scope.

### Required follow-up (op-153-cont or new op)

- **Find op-150's actual freeze.** Re-run with the op-150 setup verbatim (use
  Gatekeeper's exact rc.local — my op151 staging might have a subtle difference
  causing the earlier rc.d hang). When the churn probe reaches iter 400 + watchpoint
  starts + THEN freezes, kgdb-attach: the stacks will be in mach compat code,
  and that's the id-025 capture.
- **Investigate the rc.d hang.** The fast-freeze in `Mounting late filesystems`
  → `Starting local daemons:` interval is interesting in its own right. What
  rc.d script hangs? GDB-attach showed kernel idle, so the hang is userspace
  waiting on something. `info proc` + walk allproc from kgdb would identify
  the userspace process.
- **kgdb `add-kld` failure:** needed `set solib-search-path` OR `set sysroot`
  pointing to the guest's /boot/kernel + /boot/modules. Fix in next iteration.
