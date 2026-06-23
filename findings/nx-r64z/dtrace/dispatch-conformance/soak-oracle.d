/* soak-oracle.d — self-terminating combined oracle (op-104).
 * FIX (run 3): -D macro not supported on FreeBSD dtrace; replaced the countdown
 * with a tick-Ns probe (fires once at Ns → print deltas → exit(0)). The tick
 * period must match the soak driver's SOAK_DURATION. For the 120s proof: tick-120s.
 * For op-105's 2h soak: tick-7200s (generate via sed if needed).
 * All 4 invariants: msg-balance, kmsg-balance, queue-balance, port-balance. */
#pragma D option quiet

BEGIN { printf("soak-oracle begin\n"); }

fbt::mach_msg_send:entry      { sends++; }
fbt::mach_msg_receive:entry   { recvs++; }
fbt::ipc_kmsg_alloc:entry     { kallocs++; }
fbt::ipc_kmsg_destroy:entry   { kdestroys++; }
fbt::ipc_mqueue_send:entry    { enqs++; }
fbt::ipc_mqueue_receive:entry { deqs++; }
fbt::ipc_port_alloc:entry     { pallocs++; }
fbt::ipc_port_destroy:entry   { pdestroys++; }

/* Self-terminate at 120s: print deltas + clean exit (dtrace flushes). */
tick-120s {
  printf("=== SOAK ORACLE FINAL ===\n");
  printf("msg:  send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
  printf("kmsg: alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
  printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
  printf("port: alloc=%d destroy=%d delta=%d (nonzero expected; op-105 refines)\n",
         pallocs, pdestroys, pallocs - pdestroys);
  printf("=== SOAK ORACLE END ===\n");
  exit(0);
}
