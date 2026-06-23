/* invariant-oracle: enqueue vs dequeue balance (no stuck queue work).
 * Uses the dispatch queue push/pop fbt anchors (if available) OR the
 * ipc_mqueue send/receive as a proxy. The probe IS the test. */
#pragma D option quiet
BEGIN { printf("queue-balance oracle start\n"); }
fbt::ipc_mqueue_send:entry    { @enq = count(); }
fbt::ipc_mqueue_receive:entry { @deq = count(); }
END { printf("enqueue=%d dequeue=%d delta=%d\n", @enq, @deq, @enq - @deq);
      exit(@enq - @deq != 0); }
