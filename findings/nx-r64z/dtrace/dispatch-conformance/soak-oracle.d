/* soak-oracle.d — self-terminating combined oracle (op-104).
 * FIX (run 2): FreeBSD dtrace doesn't reliably fire END on SIGINT; the output
 * buffer was lost on SIGKILL. Replaced END with a tick-1s countdown that prints
 * the deltas + exit(0) — dtrace flushes cleanly on its own exit.
 * Pass SOAK_SECONDS via -DSOAK_SECONDS=N on the dtrace command line. */
#pragma D option quiet

BEGIN { printf("soak-oracle begin (SOAK_SECONDS=%d)\n", SOAK_SECONDS); countdown = SOAK_SECONDS; }

fbt::mach_msg_send:entry      { sends++; }
fbt::mach_msg_receive:entry   { recvs++; }
fbt::ipc_kmsg_alloc:entry     { kallocs++; }
fbt::ipc_kmsg_destroy:entry   { kdestroys++; }
fbt::ipc_mqueue_send:entry    { enqs++; }
fbt::ipc_mqueue_receive:entry { deqs++; }
fbt::ipc_port_alloc:entry     { pallocs++; }
fbt::ipc_port_destroy:entry   { pdestroys++; }

tick-1s /countdown > 0/ { countdown--; }
tick-1s /countdown == 0/ {
  printf("=== SOAK ORACLE FINAL ===\n");
  printf("msg:  send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
  printf("kmsg: alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
  printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
  printf("port: alloc=%d destroy=%d delta=%d (nonzero expected; op-105 refines)\n",
         pallocs, pdestroys, pallocs - pdestroys);
  printf("=== SOAK ORACLE END ===\n");
  exit(0);
}
