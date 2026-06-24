/* notifyd-soak-oracle.d — invariant oracle for sustained notifyd post/register churn.
 * Adapted from the op-104 dispatch soak-oracle template. Invariants:
 *   1. mach_msg send vs receive balance (no leaked notify messages)
 *   2. ipc_port alloc vs dealloc balance (no right leak across register/cancel cycles)
 *   3. ipc_kmsg alloc vs destroy balance (no stuck kernel messages)
 *   4. ipc_mqueue send vs receive balance (no stuck enqueues)
 *
 * Uses global-int counters (not aggregations) so printf+arithmetic stays valid
 * (the op-104 lesson). Self-terminating via tick-Ns (the op-104-cont lesson —
 * FreeBSD dtrace doesn't fire END on SIGINT; tick is self-terminating).
 *
 * Notifyd has NO USDT → fbt/pid only (the op-099 mach-ipc cross-layer anchor).
 * The tick period must match the soak driver's SOAK_DURATION.
 * For a 120s proof: tick-120s. For a 2h soak: tick-7200s.
 *
 * Cross-layer correlation: notify client (libnotify) ↔ Mach IPC (mach_msg) ↔
 * notifyd (the daemon) ↔ on-disk state (/var/run/notifyd_state). The fbt probes
 * observe the kernel IPC layer; the port-slope series (tick-60s checkpoints)
 * catches slow leaks that end-balance misses (the op-105 lesson). */
#pragma D option quiet

BEGIN { printf("notifyd-soak-oracle begin\n"); }

/* Mach IPC balance — the core transport layer */
fbt::mach_msg_send:entry      { sends++; }
fbt::mach_msg_receive:entry   { recvs++; }
fbt::ipc_kmsg_alloc:entry     { kallocs++; }
fbt::ipc_kmsg_destroy:entry   { kdestroys++; }
fbt::ipc_mqueue_send:entry    { enqs++; }
fbt::ipc_mqueue_receive:entry { deqs++; }

/* Port-right balance — notifyd registers/cancels Mach ports for clients.
 * notify_register_* creates entries; notify_cancel destroys them.
 * Slow leak = delta grows over time (slope). */
fbt::ipc_port_alloc:entry     { pallocs++; }
fbt::ipc_port_destroy:entry   { pdestroys++; }

/* Notifyd-specific: the dead-name notification path (notifyd arms dead-name
 * requests for client ports; when a client dies, notifyd gets a dead-name
 * notification and cleans up). Watch for balance. */
fbt::ipc_port_dnrequest:entry { dnreqs++; }
fbt::ipc_port_dnnotify:entry  { dnfires++; }

/* Port-slope series: per-minute checkpoint for slow-leak detection.
 * delta = pallocs - pdestroys. Flat slope = ports persist but don't grow = no leak.
 * Growing slope = monotonic port accumulation = leak (the op-105 pattern). */
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
        printf("=== NOTIFYD SOAK ORACLE FINAL ===\n");
        printf("msg:   send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
        printf("kmsg:  alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
        printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
        printf("port:  alloc=%d destroy=%d delta=%d\n", pallocs, pdestroys, pallocs - pdestroys);
        printf("deadname: req=%d fire=%d delta=%d\n", dnreqs, dnfires, dnreqs - dnfires);
        printf("port-slope checkpoints: %d\n", minutes);
        printf("=== NOTIFYD SOAK ORACLE END ===\n");
        exit(0);
}
