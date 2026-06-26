#!/usr/bin/env python3
"""op-153 §3 hypervisor-level (gdb stub) capture one-shot.

Same architecture as op151-capture-ddb.py but swaps DDB for kgdb attach to
bhyve's -G gdb stub. Survives the wedge by reading vCPU state via the
hypervisor's debug interface, NOT via DDB (which proved insufficient).

Thin glue per op-147m (observation + capture only — NO verdict markers
emitted from this script).

Inputs:
  vm_name          — bhyve vm name
  serial_tcp_port  — bhyve TCP serial port (for freeze detect)
  gdb_tcp_port     — bhyve -G gdb stub port
  out_log          — file to capture serial stream + kgdb output
  kernel_debug     — host path to kernel.debug (for symbols)
  mach_ko_debug    — host path to mach.ko.debug (for compat/mach symbols)
  max_wait_s       — freeze detector timeout

Usage:
  op153-capture-gdb.py <vm_name> <serial_tcp_port> <gdb_tcp_port> <out_log> <kernel_debug> <mach_ko_debug> <max_wait_s>
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
    max_wait_s = int(sys.argv[7]) if len(sys.argv) > 7 else 600

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

    # Freeze detector: serial silence > 90s + bhyve still alive
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
                log("bhyve gone (silent but no stats) — exit")
                break
        time.sleep(10)

    if freeze_at is None:
        log("no freeze detected within max_wait — exiting")
        out.close()
        return 0

    # === FREEZE CAPTURE: kgdb attach to bhyve -G stub ===
    log(f"attaching kgdb to bhyve gdb stub 127.0.0.1:{gdb_tcp_port}")

    # FreeBSD kgdb doesn't support -batch -x; use stdin-pipe mode.
    # Build a kgdb command stream and pipe it via stdin.
    kgdb_cmds = []
    kgdb_cmds.append("set pagination off")
    kgdb_cmds.append("set confirm off")
    kgdb_cmds.append(f"target remote :{gdb_tcp_port}")
    kgdb_cmds.append(f"add-kld mach {mach_ko_debug}")
    kgdb_cmds.append('printf "=== KGDB ATTACHED — dumping state ===\\n"')
    kgdb_cmds.append('printf "\\n=== current thread bt ===\\n"')
    kgdb_cmds.append("bt")
    kgdb_cmds.append('printf "\\n=== info threads ===\\n"')
    kgdb_cmds.append("info threads")
    kgdb_cmds.append('printf "\\n=== thread apply all bt ===\\n"')
    kgdb_cmds.append("thread apply all bt")
    kgdb_cmds.append('printf "\\n=== info address (key mach fns) ===\\n"')
    kgdb_cmds.append("info address ipc_mqueue_receive")
    kgdb_cmds.append("info address ipc_mqueue_pset_receive")
    kgdb_cmds.append("info address thread_block")
    kgdb_cmds.append("info address thread_pool_wakeup")
    kgdb_cmds.append("info address ipc_pset_signal")
    kgdb_cmds.append('printf "\\n=== END KGDB CAPTURE ===\\n"')
    kgdb_cmds.append("detach")
    kgdb_cmds.append("quit")
    kgdb_stdin = "\n".join(kgdb_cmds) + "\n"

    log(f"running kgdb (stdin-pipe mode) targeting :{gdb_tcp_port}")
    try:
        r = subprocess.run(
            ["kgdb", "-q", kernel_debug],
            input=kgdb_stdin,
            capture_output=True, text=True, timeout=120)
        log(f"kgdb rc={r.returncode} stdout={len(r.stdout)}B stderr={len(r.stderr)}B")
        out.write(b"\n===== KGDB STDOUT =====\n")
        out.write(r.stdout.encode())
        out.write(b"\n===== KGDB STDERR =====\n")
        out.write(r.stderr.encode())
    except subprocess.TimeoutExpired:
        log("kgdb TIMEOUT — guest wedge too deep for stub introspection?")
        out.write(b"\n===== KGDB TIMEOUT =====\n")

    # Poweroff the guest via bhyvectl (we're done)
    log("forcing guest poweroff")
    subprocess.run(["doas", "bhyvectl", "--force-poweroff", f"--vm={vm_name}"],
                   capture_output=True)

    out.close()
    log("capture complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())
