#!/usr/bin/env python3
"""op-151 §B DDB capture one-shot.

Connects to bhyve's TCP serial port, reads serial output, polls bhyvectl
stats for freeze. On freeze: injects NMI, waits for DDB prompt, sends
DDB commands (trace, show locks, ps, show pcpu, msg). Captures everything
to an output file.

Thin glue per op-147m (observation + capture only — NO verdict markers
emitted from this script). The verdict is computed by the Elixir conductor
that invokes this script.

Usage:
  op151-capture-ddb.py <vm_name> <tcp_port> <out_log> <max_wait_s>
"""
import socket
import subprocess
import sys
import threading
import time

def main():
    vm_name = sys.argv[1]
    tcp_port = int(sys.argv[2])
    out_path = sys.argv[3]
    max_wait_s = int(sys.argv[4]) if len(sys.argv) > 4 else 600

    out = open(out_path, "wb", buffering=0)
    bytes_written = [0]   # mutable holder for the reader thread
    last_data_at = [time.time()]

    def log(s):
        line = f"[cap {time.strftime('%H:%M:%S')}] {s}\n"
        sys.stderr.write(line)
        out.write(line.encode())

    log(f"connecting to bhyve TCP serial 127.0.0.1:{tcp_port}")
    s = socket.socket()
    s.settimeout(2.0)
    while True:
        try:
            s.connect(("127.0.0.1", tcp_port))
            break
        except (ConnectionRefusedError, socket.timeout):
            time.sleep(0.2)
    log("connected")

    # Reader: continuously drain serial to file + track last-data time
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

    # Freeze detector: id-025 freeze signal is SERIAL-OUTPUT SILENCE while
    # the vCPU continues to do HLTs (idle ticks climbing). So watch the
    # serial stream, not the idle counter.
    log(f"freeze detector: polling serial silence for {max_wait_s}s")
    start = time.time()
    freeze_at = None
    # Let the guest boot first (~60s) before applying silence threshold.
    boot_grace_s = 60
    silence_threshold_s = 90
    while time.time() - start < max_wait_s:
        elapsed = time.time() - start
        since_data = time.time() - last_data_at[0]
        if elapsed > boot_grace_s and since_data > silence_threshold_s:
            # Verify bhyve still alive (otherwise this is just shutdown)
            r = subprocess.run(
                ["doas", "bhyvectl", "--get-stats", f"--vm={vm_name}"],
                capture_output=True, text=True, timeout=5)
            if "ticks vcpu was idle" in r.stdout:
                log(f"FREEZE-DETECTED serial-silent={since_data:.0f}s "
                    f"bytes={bytes_written[0]} bhyve-still-alive=yes")
                freeze_at = time.time()
                break
            else:
                log(f"bhyve gone (silent but no stats) — exit")
                break
        time.sleep(10)

    if freeze_at is None:
        log("no freeze detected within max_wait — exiting")
        out.close()
        return 0

    # === FREEZE CAPTURE: NMI → DDB → commands ===
    log("injecting NMI")
    subprocess.run(["doas", "bhyvectl", "--inject-nmi", f"--vm={vm_name}"],
                   capture_output=True)
    time.sleep(3)  # let DDB enter + print banner

    log("sending DDB commands")
    for cmd in ["trace", "show locks", "ps", "show pcpu", "msg", "boot dump"]:
        log(f"DDB: {cmd}")
        try:
            s.send(cmd.encode() + b"\n")
        except OSError as e:
            log(f"send failed: {e}")
            break
        time.sleep(2)  # let DDB process + emit

    # Final drain
    time.sleep(5)
    out.close()
    log("capture complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())
