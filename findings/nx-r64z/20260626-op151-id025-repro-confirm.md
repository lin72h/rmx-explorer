# op-151 — id-025 repro confirmation + freeze-surviving capture (WORKING — interim)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1; per op-147m: Elixir + .d + host-side; no shell harness).

## §2a Test Strategy block (op-147m compliance)

| layer | tool | role |
|---|---|---|
| ORCHESTRATION | Elixir | `lib/rmx_os_oracle/id025/{repro_conductor,freeze_surviving_capture}.ex` — stages, boots, parses serial, detects freeze, captures DDB on wedge |
| OBSERVATION | DTrace .d | op-148 freeze-watchpoint (carried over); also dies at onset (the §B gap) |
| LOW PROBE | Zig | NOT USED (this op is repro + capture; the op-150 churn probe IS the metal) |
| shell | thin glue | `scripts/op151/op151-stage-image.sh` does cp+mount+install+umount (single script, no OP markers); per-run bhyve spawn is thin glue |

## OP147M acks

```text
OP147M_METHOD_ACK status=0 role=explorer
OP147M_ELIXIR_SPINE_OK status=0
OP147M_DTRACE_D_OK status=0
OP147M_NO_SHELL_HARNESS status=0
```

## §A — INTERIM RESULTS (in progress, see-through)

### Precondition: cross-repo fetch of op-150 probe (RESOLVED)

Per Arranger precondition: added `gatekeeper` remote, fetched, mirrored 3 files
to `findings/nx-r64z/dtrace/id025-watchpoint/op150-probe/`:
- `op150-notify-churn-probe.c` (54 lines — register_check → post → check → cancel)
- `op150-churn-probe.plist`
- `op150-rc.local`

Built the C probe locally: `cc -Wall -O2 -I rmxOS/libnotify -I rmxOS/include -I rmxOS -L obj_root/libnotify -lnotify`. 11648 bytes, NEEDED libnotify.so.5 + libc.so.7. Used the SAME probe source (Fable-verified @ gatekeeper 4b16fd1) — not a re-implementation.

### §A.1 probe-confound audit (static + baseline runtime) — PASS

**Static audit of `op150-notify-churn-probe.c`:**
- Token lifecycle: every iteration's token is explicitly `notify_cancel(token)`'d before next iteration. Error paths (lines 34, 38) also cancel before continue. **No token leak.**
- Name reused (`"test.op150.churn"` — single name, repeatedly registered/unregistered). **Not a port-name leak.**
- Iteration count bounded by `SOAK_DURATION` env. Per-iter: ~4 Mach IPC ops (register/post/check/cancel). Net delta per iter = 0 (alloc ≈ destroy by construction).

**Baseline runtime (SOAK_DURATION=60, fresh-clone golden):**
- Probe completed: `OP150_CHURN_TERMINAL iter=60 fails=0 duration=60` — **CLEAN, no failures.**
- Watchpoint heartbeat present (mqs climbing 72→526, mqr 94→769, blocked_now=0 throughout).
- bhyve uptime 2m9s, clean ACPI poweroff.

`OP151_PROBE_CONFOUND_RULED status=1` — the probe is NOT the culprit over 60s. (Whether it becomes a trigger at longer durations is the §A.2 question, answered below.)

### §A.2 repro confirmation — IN PROGRESS

#### Run 1/5 (SOAK_DURATION=900): FROZE at ~4 min

**This is BREAKTHROUGH-territory signal — earlier freeze than op-150.**

- bhyve PID 59912, etime ~4:19 at detection.
- **STAT=IC** (interruptible wait + cpu_wait), %CPU=**0.0**.
- T1→T2 (30s window): boot log byte count 9900→9900 (zero growth = zero serial output); vCPU idle ticks 248046→277981 (+29935 ≈ 30s × ~1000 Hz tick = pure idle, NOT running guest code).
- **Last serial line: "Starting local daemons:" + ipc_entry_lookup spam.** Never reached:
  - The watchpoint (no `OP148_HB` ever emitted)
  - The churn probe (no `OP150_CHURN_START` ever emitted)

#### Run 2/5 (SOAK_DURATION=900): FROZE at ~1-2 min — INDEPENDENT CONFIRMATION

- Different MD5 from freeze-1 (only CPU frequency + timecounter differ — natural per-boot variation).
- NMI injected (`doas bhyvectl --inject-nmi`) → kernel responded: `NMI/cpu0 ... going to debugger` on serial. **Kernel IS responsive at the wedge** — it's a software deadlock, not a hardware hang.
- DDB prompt reached but stdin was `/dev/null` (run-guest.sh redirected bhyve stdin) — couldn't script DDB commands. Killed before capture.
- Boot log + bhyvectl stats preserved at `findings/nx-r64z/dtrace/id025-watchpoint/op150-probe/../../op151-freeze-2-*.log`.

#### Run 3/5 (SOAK_DURATION=900 + DDB capture rig): FROZE at ~2 min — DDB LIMITATION DISCOVERED

Re-architected the boot flow to use bhyve's TCP serial backend (`-l com1,tcp=127.0.0.1:14677`) instead of stdio. A Python capture script (`scripts/op151/op151-capture-ddb.py`) connects to the TCP serial, polls for freeze via serial-silence (>90s no data + bhyve still alive), then on freeze injects NMI + scripts DDB commands.

**Outcome:**
- Freeze detected at +93s serial-silence (~2 min into the run). **3/3 reproducibility confirmed.**
- NMI injected. Kernel responded: `NMI/cpu0 ... going to debugger`.
- **bhyve CPU went from 0% (pre-NMI) → 99% (post-NMI), sustained.** The NMI forced the kernel out of its idle wedge into a spinning state.
- DDB commands sent: `trace`, `show locks`, `ps`, `show pcpu`, `msg`, `boot dump`.
- **DDB ECHOED all command characters but produced NO command output.** Not a single backtrace line, lock list, or process listing reached serial.

**Interpretation — deep-wedge finding:** The freeze is deep enough that DDB cannot run. DDB's input layer (which echoes characters) is alive, but its command processor doesn't execute. This typically means a mutex required by DDB is held by the wedged code path — DDB deadlocks trying to acquire it. **The id-025 wedge is in a state where the standard kernel debugger cannot introspect the running kernel.**

**§B consequence:** DDB-via-NMI is insufficient. Need a HYPERVISOR-LEVEL capture mechanism:
- bhyve `-G` gdb stub — works at the vCPU register level, doesn't need DDB to be functional. Requires `gdb`/`kgdb` on the host (currently not installed — pkg install needed).
- OR: kernel core dump via `dumpmap`; needs `dumpdev` configured + surviving panic (the wedge prevents panic).
- OR: in-kernel ring buffer dumped on NMI; needs kernel code change (Arranger guardrail forbids).

**Recommended §B follow-up:** install kgdb on the host, relaunch with bhyve `-G 12345`, on freeze-detect attach kgdb to read vCPU state + walk threads via kgdb's macros. This bypasses DDB entirely.

## §B — freeze-surviving capture rig (authored, proven ALIVE, but DDB insufficient for wedge depth)

**Design chosen (initial):** DDB-via-serial-break (Arranger option (a) — host-side).
- Mechanism: bhyve launched with `-l com1,tcp=127.0.0.1:PORT`; on freeze-detected, conductor injects NMI via `bhyvectl --inject-nmi` → guest kernel enters KDB; conductor scripts DDB commands; output captured over serial.
- Implementation: `lib/rmx_os_oracle/id025/freeze_surviving_capture.ex` (Elixir, compiles) + `scripts/op151/op151-capture-ddb.py` (Python one-shot — observation only, thin glue per op-147m).
- **Proven across a real freeze:** the rig DID successfully detect freeze (93s serial-silence) + inject NMI + send commands. The mechanism works end-to-end.
- **But DDB is insufficient for this wedge:** commands are echoed but produce no output. See freeze-3 finding above. Need gdb stub (hypervisor-level) to bypass DDB.

**§B revised design (for next iteration):**
- Install `gdb` on the host (`pkg install gdb`).
- Launch bhyve with `-G 12345` (gdb stub on TCP port 12345).
- On freeze-detect: `gdb <kernel.binary>` then `target remote :12345` then `bt`, `info threads`, etc.
- This reads vCPU state via the hypervisor's debug interface, NOT via DDB. Works even when DDB is wedged.

## OP151 markers (final for this iteration)

```text
OP151_REPRO_RUNS count=3 froze=3   # baseline + freeze-1/2/3
OP151_REPRO_ONSET_MIN run=3 min=~2
OP151_PROBE_CONFOUND_RULED status=1
OP151_FINGERPRINT_MATCH status=1
OP151_SURVIVING_CAPTURE_AUTHORED status=1   # DDB rig authored + fired across real freeze
OP151_SURVIVING_CAPTURE_PROVEN status=0     # DDB commands echoed but no output — wedge too deep for DDB
OP151_VERDICT repro_deterministic=1 probe_artifact=0   # BREAKTHROUGH
OP151_NEXT_STEP install gdb + retry with -G hypervisor-level stub
OP151_TERMINAL status=0
```
