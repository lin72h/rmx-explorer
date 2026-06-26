#!/usr/bin/env python3
"""op-155 §2 capture — fixed detector (HB-iter gate) + per-thread bt reconstruction.

Diff vs op-154:
  - Freeze detector parses OP150_CHURN_HB iter=N from serial, gates freeze on
    (iter-stopped > 120s) AND (iter >= 380) — not just raw serial silence.
    This avoids op-154's false positive where rc.local's `sleep 960` looked
    like a freeze because the workload wrote to files, not serial.
  - On real freeze: kgdb attach + allproc walk + per-thread wchan/wmesg AND
    per-thread backtrace reconstruction via td_pcb (pcb_rip/pcb_rbp).
    wmesg=thread_block is ambiguous (normal Mach msg-wait AND wedged
    ipc_mqueue_receive both block via thread_block); only a real stack frame
    (ipc_mqueue_receive/pset_receive in the bt) distinguishes id-025 from
    benign idle.

Thin glue per op-147m.
"""
import os
import re
import socket
import subprocess
import sys
import threading
import time

ITER_GATE = 380          # op-150 onset was ~400; gate at 380 (5% slack)
ITER_STALL_S = 120       # churn iter must stop advancing for 120s + iter>=GATE
POST_KGDB_SETTLE_S = 5

def main():
    vm_name = sys.argv[1]
    serial_tcp_port = int(sys.argv[2])
    gdb_tcp_port = int(sys.argv[3])
    out_path = sys.argv[4]
    kernel_debug = sys.argv[5]
    mach_ko_debug = sys.argv[6]
    sysroot = sys.argv[7]
    max_wait_s = int(sys.argv[8]) if len(sys.argv) > 8 else 1200  # 20 min default

    out = open(out_path, "wb", buffering=0)
    bytes_written = [0]
    last_data_at = [time.time()]
    last_iter = [0]
    last_iter_at = [time.time()]

    def log(s):
        line = f"[cap {time.strftime('%H:%M:%S')}] {s}\n"
        sys.stderr.write(line)
        out.write(line.encode())

    log(f"connecting to bhyve TCP serial 127.0.0.1:{serial_tcp_port}")
    s = socket.socket()
    s.settimeout(2.0)
    while True:
        try:
            s.connect(("127.0.0.1", serial_tcp_port))
            break
        except (ConnectionRefusedError, socket.timeout):
            time.sleep(0.2)
    log("serial connected")

    hb_re = re.compile(rb"OP150_CHURN_HB iter=(\d+)")

    def reader():
        buf = b""
        while True:
            try:
                data = s.recv(4096)
            except socket.timeout:
                continue
            except OSError:
                break
            if not data:
                log("reader: EOF from bhyve serial")
                break
            out.write(data)
            bytes_written[0] += len(data)
            last_data_at[0] = time.time()
            # Parse churn HB iter
            buf += data
            for m in hb_re.finditer(buf):
                iter_n = int(m.group(1))
                if iter_n > last_iter[0]:
                    last_iter[0] = iter_n
                    last_iter_at[0] = time.time()
            buf = buf[-512:]  # keep last 512B for partial-line matching
    threading.Thread(target=reader, daemon=True).start()

    # Freeze detector: HB-iter stall + iter gate
    log(f"freeze detector: HB-iter gate={ITER_GATE} stall={ITER_STALL_S}s max_wait={max_wait_s}s")
    start = time.time()
    freeze_at = None
    while time.time() - start < max_wait_s:
        elapsed = time.time() - start
        iter_age = time.time() - last_iter_at[0]
        cur_iter = last_iter[0]

        # Freeze condition: churn HB has been seen (iter>0), iter stopped
        # advancing for >stall_s, AND iter >= GATE (op-150 onset window).
        # Without the iter gate, rc.local's sleep 960 would false-positive.
        if cur_iter >= ITER_GATE and iter_age > ITER_STALL_S:
            log(f"REAL FREEZE: iter={cur_iter} stalled={iter_age:.0f}s (gate={ITER_GATE})")
            freeze_at = time.time()
            break

        # If we've seen some iters but they're < GATE and now silent for a long
        # time, the probe may have died early. Note as anomaly but don't trigger.
        if 0 < cur_iter < ITER_GATE and iter_age > 300:
            log(f"WARN: iter stuck at {cur_iter} (below gate) for {iter_age:.0f}s — probe died?")
            break

        time.sleep(5)
    else:
        log(f"no freeze within max_wait ({max_wait_s}s); last_iter={last_iter[0]}")

    if freeze_at is None:
        log(f"no real freeze detected — final_iter={last_iter[0]}")
        # Still dump final state for diagnosis
        out.close()
        return 0

    # === REAL FREEZE CAPTURE ===
    log(f"attaching kgdb with sysroot={sysroot}")

    cmds = []
    cmds.append("set pagination off")
    cmds.append("set confirm off")
    cmds.append(f"set sysroot {sysroot}")
    cmds.append(f"set solib-search-path {sysroot}/boot/kernel:{sysroot}/boot/modules:{sysroot}/usr/lib/debug/boot/kernel:{sysroot}/usr/lib/debug/boot/modules")
    cmds.append(f"target remote :{gdb_tcp_port}")
    cmds.append('printf "=== KGDB ATTACHED (REAL FREEZE) ===\\n"')
    cmds.append(f"add-kld mach {mach_ko_debug}")
    cmds.append('printf "\\n=== verify mach symbols ===\\n"')
    cmds.append("info address ipc_mqueue_receive")
    cmds.append("info address thread_block")
    cmds.append("info address thread_pool_wakeup")
    cmds.append('printf "\\n=== vCPU stacks ===\\n"')
    cmds.append("thread apply all bt")
    cmds.append('printf "\\n=== allproc walk + per-thread state + bt reconstruction ===\\n"')
    cmds.append("set $p = allproc.lh_first")
    cmds.append("set $i = 0")
    cmds.append("while ($p && $i < 100)")
    cmds.append('  printf "proc[%d] pid=%d comm=%s numthreads=%d\\n", $i, $p->p_pid, $p->p_comm, $p->p_numthreads')
    cmds.append("  set $td = $p->p_threads.tqh_first")
    cmds.append("  set $j = 0")
    cmds.append("  while ($td && $j < 20)")
    cmds.append('    printf "  thr[%d] td=%p state=%d wchan=%p wmesg=%s\\n", $j, $td, $td->td_state, $td->td_wchan, ($td->td_wmesg ? $td->td_wmesg : "(none)")')
    # Per-thread bt reconstruction: switch to the thread's saved context via
    # td_pcb + td_frame. kgdb's `thread apply all bt` only sees vCPUs; for
    # kernel threads we manually read the saved frame pointer + walk.
    # The convention: $td->td_pcb->pcb_rbp = frame pointer at preemption,
    # $td->td_pcb->pcb_rip = instruction pointer. Use these as the seed for
    # frame walking via the `backtrace` command on manually-seeded registers.
    # kgdb doesn't directly support this — but `x/20i $pc` shows code at an
    # address; `x/8ag $rbp` walks the saved-frame chain.
    cmds.append('    printf "    stack walk from td_pcb:\\n"')
    cmds.append("    set $rbp = $td->td_pcb->pcb_rbp")
    cmds.append("    set $rip = $td->td_pcb->pcb_rip")
    cmds.append('    printf "      rip=%p rbp=%p\\n", $rip, $rbp')
    cmds.append("    set $n = 0")
    cmds.append("    while ($rbp != 0 && $n < 16)")
    cmds.append("      info symbol $rip")
    cmds.append("      set $next_rbp = *(unsigned long *)$rbp")
    cmds.append("      set $next_rip = *(unsigned long *)($rbp + 8)")
    cmds.append('      printf "      [%d] rip=%p rbptest=%s\\n", $n, $rip, "..."')
    cmds.append("      set $rbp = $next_rbp")
    cmds.append("      set $rip = $next_rip")
    cmds.append("      set $n = $n + 1")
    cmds.append("    end")
    cmds.append("    set $td = $td->td_plist.tqe_next")
    cmds.append("    set $j = $j + 1")
    cmds.append("  end")
    cmds.append("  set $p = (struct proc *)$p->p_list.le_next")
    cmds.append("  set $i = $i + 1")
    cmds.append("end")
    cmds.append('printf "\\n=== END allproc walk ===\\n"')
    cmds.append('printf "\\n=== END CAPTURE ===\\n"')
    cmds.append("detach")
    cmds.append("quit")
    kgdb_stdin = "\n".join(cmds) + "\n"

    log("running kgdb (real-freeze capture)")
    try:
        r = subprocess.run(
            ["kgdb", "-q", kernel_debug],
            input=kgdb_stdin,
            capture_output=True, text=True, timeout=300)
        log(f"kgdb rc={r.returncode} stdout={len(r.stdout)}B stderr={len(r.stderr)}B")
        out.write(b"\n===== KGDB STDOUT =====\n")
        out.write(r.stdout.encode())
        out.write(b"\n===== KGDB STDERR =====\n")
        out.write(r.stderr.encode())
    except subprocess.TimeoutExpired as e:
        log(f"kgdb TIMEOUT after 300s")
        out.write(b"\n===== KGDB TIMEOUT =====\n")
        if e.stdout:
            out.write(e.stdout if isinstance(e.stdout, bytes) else e.stdout.encode())

    # Force poweroff
    log("forcing guest poweroff")
    subprocess.run(["doas", "bhyvectl", "--force-poweroff", f"--vm={vm_name}"],
                   capture_output=True)
    out.close()
    log("capture complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())
