#!/usr/bin/env python3
"""op-154 §1 complete capture — resolve mach.ko symbols + walk allproc.

Builds on op153-capture-gdb.py with:
- set sysroot + solib-search-path so add-kld mach resolves
- add-kld mach + verify info address ipc_mqueue_receive
- ps macro (kgdb built-in) for process enumeration
- Manual allproc walk via the p_list linked list
- Manual thread_list walk for kernel threads
- DDB cross-check via NMI (idle kernel may allow DDB to function)

Thin glue per op-147m (observation + capture only — NO verdict markers).
"""
import os
import socket
import subprocess
import sys
import threading
import time

def main():
    vm_name = sys.argv[1]
    serial_tcp_port = int(sys.argv[2])
    gdb_tcp_port = int(sys.argv[3])
    out_path = sys.argv[4]
    kernel_debug = sys.argv[5]
    mach_ko_debug = sys.argv[6]
    sysroot = sys.argv[7]
    max_wait_s = int(sys.argv[8]) if len(sys.argv) > 8 else 900

    out = open(out_path, "wb", buffering=0)
    bytes_written = [0]
    last_data_at = [time.time()]

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

    def reader():
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
    threading.Thread(target=reader, daemon=True).start()

    # Freeze detector
    log(f"freeze detector: polling serial silence for {max_wait_s}s")
    start = time.time()
    boot_grace_s = 60
    silence_threshold_s = 90
    freeze_at = None
    while time.time() - start < max_wait_s:
        elapsed = time.time() - start
        since_data = time.time() - last_data_at[0]
        if elapsed > boot_grace_s and since_data > silence_threshold_s:
            r = subprocess.run(
                ["doas", "bhyvectl", "--get-stats", f"--vm={vm_name}"],
                capture_output=True, text=True, timeout=5)
            if "ticks vcpu was idle" in r.stdout:
                log(f"FREEZE-DETECTED serial-silent={since_data:.0f}s bytes={bytes_written[0]}")
                freeze_at = time.time()
                break
            else:
                log("bhyve gone — exit")
                break
        time.sleep(10)

    if freeze_at is None:
        log("no freeze detected — exiting")
        out.close()
        return 0

    # === CAPTURE: kgdb with FIXED sysroot + add-kld + allproc walk ===
    log(f"attaching kgdb with sysroot={sysroot}")

    cmds = []
    cmds.append("set pagination off")
    cmds.append("set confirm off")
    cmds.append(f"set sysroot {sysroot}")
    cmds.append(f"set solib-search-path {sysroot}/boot/kernel:{sysroot}/boot/modules:{sysroot}/usr/lib/debug/boot/kernel:{sysroot}/usr/lib/debug/boot/modules")
    cmds.append(f"target remote :{gdb_tcp_port}")
    cmds.append('printf "=== KGDB ATTACHED ===\\n"')
    cmds.append('printf "\\n=== info sharedlibrary ===\\n"')
    cmds.append("info sharedlibrary")
    cmds.append('printf "\\n=== add-kld mach ===\\n"')
    cmds.append(f"add-kld mach {mach_ko_debug}")
    cmds.append('printf "\\n=== info sharedlibrary (post add-kld) ===\\n"')
    cmds.append("info sharedlibrary")
    cmds.append('printf "\\n=== verify mach symbols resolved ===\\n"')
    cmds.append("info address ipc_mqueue_receive")
    cmds.append("info address ipc_mqueue_pset_receive")
    cmds.append("info address thread_block")
    cmds.append("info address thread_pool_wakeup")
    cmds.append("info address ipc_pset_signal")
    cmds.append('printf "\\n=== info threads (vCPUs only) ===\\n"')
    cmds.append("info threads")
    cmds.append('printf "\\n=== thread apply all bt (vCPU stacks) ===\\n"')
    cmds.append("thread apply all bt")
    cmds.append('printf "\\n=== allproc manual walk ===\\n"')
    cmds.append("set $p = allproc.lh_first")
    cmds.append("set $i = 0")
    cmds.append("while ($p && $i < 100)")
    cmds.append('  printf "proc[%d] pid=%d comm=%s numthreads=%d p_state=%d\\n", $i, $p->p_pid, ($p->p_comm ? $p->p_comm : "(null)"), $p->p_numthreads, $p->p_state')
    cmds.append("  set $p = (struct proc *)$p->p_list.le_next")
    cmds.append("  set $i = $i + 1")
    cmds.append("end")
    cmds.append('printf "\\n=== END allproc walk, total=%d ===\\n", $i')
    # Now walk per-proc threads using the CORRECT TAILQ field name.
    # In modern FreeBSD, struct thread's per-proc list link is via td_lockq OR
    # a specific field. To avoid guessing, use kgdb's maint print struct thread
    # to dump fields. Simpler: just walk allproc + for each proc, print p_threads.tqh_first
    # then use the field name from kgdb's "ptype struct thread".
    cmds.append('printf "\\n=== ptype struct thread (find linkage field) ===\\n"')
    cmds.append("ptype struct thread")
    cmds.append('printf "\\n=== walk per-proc threads using td_plist ===\\n"')
    cmds.append("set $p = allproc.lh_first")
    cmds.append("set $i = 0")
    cmds.append("while ($p && $i < 100)")
    cmds.append("  set $td = $p->p_threads.tqh_first")
    cmds.append("  set $j = 0")
    cmds.append("  while ($td && $j < 20)")
    cmds.append('    printf "proc[%d] pid=%d thr[%d] td=%p td_state=%d wchan=%p wmesg=%s\\n", $i, $p->p_pid, $j, $td, $td->td_state, $td->td_wchan, ($td->td_wmesg ? $td->td_wmesg : "(none)")')
    cmds.append("    set $td = $td->td_plist.tqe_next")
    cmds.append("    set $j = $j + 1")
    cmds.append("  end")
    cmds.append("  set $p = (struct proc *)$p->p_list.le_next")
    cmds.append("  set $i = $i + 1")
    cmds.append("end")
    cmds.append('printf "\\n=== END per-proc thread walk ===\\n"')
    cmds.append('printf "\\n=== END CAPTURE ===\\n"')
    cmds.append("detach")
    cmds.append("quit")
    kgdb_stdin = "\n".join(cmds) + "\n"

    log(f"running kgdb (sysroot={sysroot})")
    try:
        r = subprocess.run(
            ["kgdb", "-q", kernel_debug],
            input=kgdb_stdin,
            capture_output=True, text=True, timeout=180)
        log(f"kgdb rc={r.returncode} stdout={len(r.stdout)}B stderr={len(r.stderr)}B")
        out.write(b"\n===== KGDB STDOUT =====\n")
        out.write(r.stdout.encode())
        out.write(b"\n===== KGDB STDERR =====\n")
        out.write(r.stderr.encode())
    except subprocess.TimeoutExpired as e:
        log(f"kgdb TIMEOUT after 180s — partial stdout={len(e.stdout or b'')}B")
        out.write(b"\n===== KGDB TIMEOUT =====\n")
        if e.stdout:
            out.write(e.stdout)
        if e.stderr:
            out.write(b"\n--- stderr ---\n")
            out.write(e.stderr)

    # DDB cross-check: kernel idle now, DDB might work
    log("DDB cross-check: NMI + ps + alltrace")
    subprocess.run(["doas", "bhyvectl", "--inject-nmi", f"--vm={vm_name}"],
                   capture_output=True)
    time.sleep(3)
    # Try DDB commands via the TCP serial
    ddb_cmds = ["ps", "show pcpu", "alltrace", "reset"]
    for cmd in ddb_cmds:
        try:
            s.send(cmd.encode() + b"\n")
        except OSError:
            break
        time.sleep(2)
    time.sleep(5)

    # Poweroff
    log("forcing guest poweroff")
    subprocess.run(["doas", "bhyvectl", "--force-poweroff", f"--vm={vm_name}"],
                   capture_output=True)
    out.close()
    log("capture complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())
