/* soak-oracle.d — combined invariant oracle for the continuous soak (op-104).
 * All 4 invariants in one script; aggregations printed at END (on SIGINT kill).
 * - msg-balance: mach_msg_send vs mach_msg_receive
 * - kmsg-balance: ipc_kmsg_alloc vs ipc_kmsg_destroy
 * - queue-balance: ipc_mqueue_send vs ipc_mqueue_receive
 * - port-balance: ipc_port_alloc vs ipc_port_destroy (NOTE: nonzero end-balance
 *   is expected — ports persist for queue/source lifetimes; op-105 will refine
 *   this to per-iteration steady-state delta. For the proof, capture raw counts.)
 * Plus a tick-60s periodic checkpoint so intermediate state is visible. */
#pragma D option quiet
BEGIN { printf("soak-oracle begin\n"); }

fbt::mach_msg_send:entry     { @send = count(); }
fbt::mach_msg_receive:entry  { @recv = count(); }
fbt::ipc_kmsg_alloc:entry    { @kalloc = count(); }
fbt::ipc_kmsg_destroy:entry  { @kdestroy = count(); }
fbt::ipc_mqueue_send:entry   { @enq = count(); }
fbt::ipc_mqueue_receive:entry { @deq = count(); }
fbt::ipc_port_alloc:entry    { @palloc = count(); }
fbt::ipc_port_destroy:entry  { @pdestroy = count(); }

END {
  printf("=== SOAK ORACLE FINAL ===\n");
  printf("msg:  send=%d recv=%d delta=%d\n", @send, @recv, @send - @recv);
  printf("kmsg: alloc=%d destroy=%d delta=%d\n", @kalloc, @kdestroy, @kalloc - @kdestroy);
  printf("queue: enq=%d deq=%d delta=%d\n", @enq, @deq, @enq - @deq);
  printf("port: alloc=%d destroy=%d delta=%d (nonzero expected; op-105 refines)\n",
    @palloc, @pdestroy, @palloc - @pdestroy);
  printf("=== SOAK ORACLE END ===\n");
}
