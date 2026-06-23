/* soak-oracle.d — combined invariant oracle for the continuous soak (op-104).
 * FIX (Arbiter op-104-cont): replaced count() AGGREGATIONS with plain global int
 * counters — DTrace forbids printf/arithmetic on aggregations; the END block needs
 * inline deltas (sends - recvs), so globals are the correct choice (printa can't
 * subtract). All 4 invariants in one script.
 * - msg-balance: mach_msg_send vs mach_msg_receive
 * - kmsg-balance: ipc_kmsg_alloc vs ipc_kmsg_destroy
 * - queue-balance: ipc_mqueue_send vs ipc_mqueue_receive
 * - port-balance: ipc_port_alloc vs ipc_port_destroy (nonzero end-delta expected —
 *   ports persist for queue/source lifetimes; op-105 refines to per-iteration delta) */
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

END {
  printf("=== SOAK ORACLE FINAL ===\n");
  printf("msg:  send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
  printf("kmsg: alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
  printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
  printf("port: alloc=%d destroy=%d delta=%d (nonzero expected; op-105 refines)\n",
         pallocs, pdestroys, pallocs - pdestroys);
  printf("=== SOAK ORACLE END ===\n");
}
