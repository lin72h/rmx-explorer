/* soak-oracle-2h.d — 2-hour soak oracle (op-105). tick-7200s self-termination.
 * Port-slope: tick-60s prints port alloc/destroy/delta each minute → 120
 * checkpoints → the slope (delta-of-deltas). Flat = no leak; growing = leak.
 * Carry-forwards from op-104 applied: global-int counters (not aggregations);
 * tick period hardcoded (7200s) matching the driver's SOAK_DURATION=7200;
 * no -D macros (FreeBSD dtrace limitation). */
#pragma D option quiet

BEGIN { printf("soak-oracle-2h begin (tick-7200s, port-slope via tick-60s)\n"); }

fbt::mach_msg_send:entry      { sends++; }
fbt::mach_msg_receive:entry   { recvs++; }
fbt::ipc_kmsg_alloc:entry     { kallocs++; }
fbt::ipc_kmsg_destroy:entry   { kdestroys++; }
fbt::ipc_mqueue_send:entry    { enqs++; }
fbt::ipc_mqueue_receive:entry { deqs++; }
fbt::ipc_port_alloc:entry     { pallocs++; }
fbt::ipc_port_destroy:entry   { pdestroys++; }

int minutes;
/* Port-slope series: per-minute port delta checkpoint. The SLOPE is
 * (delta[t] - delta[t-1]). Flat slope = ports persist but don't grow = no leak.
 * Growing slope = monotonic port accumulation = leak. */
tick-60s {
        minutes++;
        printf("[slope t=%dm] port: alloc=%d destroy=%d delta=%d\n",
               minutes, pallocs, pdestroys, pallocs - pdestroys);
}

/* Self-terminate at 7200s (2h): final summary + clean exit (flush). */
tick-7200s {
        printf("=== SOAK ORACLE FINAL (2h) ===\n");
        printf("msg:  send=%d recv=%d delta=%d\n", sends, recvs, sends - recvs);
        printf("kmsg: alloc=%d destroy=%d delta=%d\n", kallocs, kdestroys, kallocs - kdestroys);
        printf("queue: enq=%d deq=%d delta=%d\n", enqs, deqs, enqs - deqs);
        printf("port: alloc=%d destroy=%d delta=%d\n", pallocs, pdestroys, pallocs - pdestroys);
        printf("port-slope checkpoints: %d (tick-60s firings)\n", minutes);
        printf("=== SOAK ORACLE END ===\n");
        exit(0);
}
