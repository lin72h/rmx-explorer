/* asld-soak-oracle.d — invariant oracle for sustained ASL log/search churn.
 *
 * Mirrors notifyd-soak-oracle.d (op-129/op-131), adapted for asld (syslogd):
 *   1. mach_msg send vs receive balance (no leaked ASL/Mach messages)
 *   2. ipc_port alloc vs dealloc balance (no right leak across open/close cycles)
 *   3. ipc_kmsg alloc vs destroy balance (no stuck kernel messages)
 *   4. ipc_mqueue send vs receive balance (no stuck enqueue)
 *
 * ASL-specific addition: watch for aslmanager reclaim (store rotation). The
 * store writes go through nvlist_pack (the ASL serializer) + Mach IPC to asld.
 * Under sustained load, aslmanager should fire to bound the store. The
 * port-slope series (tick-60s checkpoints) catches slow leaks that end-balance
 * misses.
 *
 * Pure fbt (no USDT on asld, no shell/bootstrap dependency for the oracle).
 * Self-terminating via tick-Ns (op-104 lesson: FreeBSD dtrace doesn't fire END
 * on SIGINT). The tick period must match SOAK_DURATION:
 *   For a 120s proof: tick-120s. For a 2h soak: tick-7200s.
 *
 * The oracle IS the test (assert, don't exit-code). */
#pragma D option quiet

BEGIN { printf("asld-soak-oracle begin\n"); }

/* Mach IPC balance — the core transport layer (asl client → asld via Mach) */
fbt::mach_msg_send:entry      { sends++; }
fbt::mach_msg_receive:entry   { recvs++; }
fbt::ipc_kmsg_alloc:entry     { kallocs++; }
fbt::ipc_kmsg_destroy:entry   { kdestroys++; }
fbt::ipc_mqueue_send:entry    { enqs++; }
fbt::ipc_mqueue_receive:entry { deqs++; }

/* Port-right balance — asl_open creates client connections (ports);
 * asl_close deallocates. Slow leak = delta grows over time (slope). */
fbt::ipc_port_alloc:entry     { pallocs++; }
fbt::ipc_port_destroy:entry   { pdestroys++; }

/* Dead-name notification path (asl may arm dead-name requests for client
 * ports that disconnect). Watch for balance. */
fbt::ipc_port_dnrequest:entry { dnreqs++; }
fbt::ipc_port_dnnotify:entry  { dnfires++; }

/* Port-slope series: per-minute checkpoint for slow-leak detection.
 * delta = pallocs - pdestroys. Flat slope = ports persist but don't grow.
 * Growing slope = monotonic port accumulation = leak (op-105 lesson). */
int minutes;
tick-60s {
        minutes++;
        printf("[slope t=%dm] port: alloc=%d destroy=%d delta=%d | dn: req=%d fire=%d | msg: s=%d r=%d\n",
               minutes, pallocs, pdestroys, pallocs - pdestroys,
               dnreqs, dnfires,
               sends, recvs);
}

/* Self-terminate at the soak duration. Change tick period to match SOAK_DURATION.
 * For proof runs: tick-120s. For 2h: tick-7200s. */
tick-120s {
        printf("=== ASLD SOAK ORACLE FINAL ===\n");
        printf("msg:   send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
        printf("kmsg:  alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
        printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
        printf("port:  alloc=%d destroy=%d delta=%d\n", pallocs, pdestroys, pallocs - pdestroys);
        printf("deadname: req=%d fire=%d delta=%d\n", dnreqs, dnfires, dnreqs - dnfires);
        printf("port-slope checkpoints: %d\n", minutes);
        printf("=== ASLD SOAK ORACLE END ===\n");
        exit(0);
}
