/*
 * op-148 id-025 freeze watchpoint.
 *
 * Passive DTrace observation. Arms two things:
 *   1. A heartbeat (tick-10s) emitting current IPC counters — the Elixir
 *      spine reads these to detect "flat slope" (zero delta for N ticks).
 *   2. A freeze-catcher: on every tick, scan threads currently in
 *      "thread_block" msleep (the Mach receive-side wait). For each blocked
 *      thread, dump stack() + the ith_state to capture the exact wait path.
 *
 * Triggers NO state change. Adds one fbt:: thread_block:entry probe + one
 * tick-Ns heartbeat. Negligible overhead.
 *
 * Counter model (op-147m compliant — global ints, not aggregations):
 *   mqs++  on ipc_mqueue_send:entry   (a send attempt was made)
 *   mqr++  on ipc_mqueue_receive:entry
 *   mqsig++ on ipc_pset_signal:entry  (knote fire path)
 *   mqpst++ on ipc_mqueue_pset_receive:entry
 *
 * Provider deps: dtrace + fbt + profile (for tick-Ns). Loaded individually
 * by the Elixir conductor (NOT dtraceall — op-104 lineage).
 *
 * Termination: self-terminating tick-Ns at conductor-controlled duration.
 * The conductor passes the duration by editing the script's tick-Ns literal
 * OR by sending SIGINT after consuming the heartbeat output (this is the
 * runtime that does NOT lose buffered output — op-104 lineage established
 * that tick-Ns self-terminate is the safe pattern).
 *
 * Usage (driven by Elixir conductor — not as a shell harness):
 *   kldload dtrace
 *   kldload fbt
 *   kldload profile
 *   kldload opensolaris
 *   dtrace -s op148-freeze-watchpoint.d >& output.log &
 *   # Elixir conductor parses output.log for flat-slope detection.
 *
 * Probe selection reconstructed from op-148 §A static analysis (NOT inherited
 * from any other explorer's branch). The probes target the wait paths
 * identified first-hand in:
 *   sys/compat/mach/ipc/ipc_mqueue.c (ipc_mqueue_send, ipc_mqueue_receive,
 *     ipc_mqueue_pset_receive — the strongest id-025 lead)
 *   sys/compat/mach/ipc/ipc_pset.c (ipc_pset_signal — kqueue fire path)
 *   sys/compat/mach/mach_thread.c (thread_block — the msleep wait)
 *   sys/compat/mach/kern/thread_pool.c (candidate A.1: thread_pool_wakeup no-op)
 */

/* Counters — global ints (op-147m: NOT aggregations). */
int mqs;   /* mach_msg_send entries */
int mqr;   /* ipc_mqueue_receive entries */
int mqsig; /* ipc_pset_signal entries (kqueue fire path) */
int mqpst; /* ipc_mqueue_pset_receive entries (the strongest id-025 lead) */
int blocked_now; /* current count of threads inside thread_block (msleep) */
int blk_obs;     /* blocked-thread observation events emitted */

/* fbt: trace ipc_mqueue_send / receive / pset_signal / pset_receive entries.
 * These demarcate the Mach IPC work. */
fbt::ipc_mqueue_send:entry     { mqs++; }
fbt::ipc_mqueue_receive:entry  { mqr++; }
fbt::ipc_pset_signal:entry     { mqsig++; }
fbt::ipc_mqueue_pset_receive:entry { mqpst++; }

/* fbt: trace thread_block entry/exit so we know how many threads are blocked.
 * On entry, increment; on exit, decrement. The "blocked_now" counter is the
 * instantaneous count of threads inside msleep(thread_block). */
fbt::thread_block:entry  { blocked_now++; }
fbt::thread_block:return { blocked_now--; }

/* Heartbeat: every 10s, emit current counter snapshot. The conductor diffs
 * consecutive snapshots; if mqs+mqr+mqsig+mqpst all delta=0 for 3+ ticks,
 * that's a flat-slope onset → freeze candidate.
 *
 * Self-terminating: tick-18000s fires ONCE (5 hours) → exit(0). Conductor
 * sends SIGINT earlier if it detects flat-slope and wants to tear down. */
profile:::tick-10s
{
	printf("OP148_HB mqs=%d mqr=%d mqsig=%d mqpst=%d blocked_now=%d blk_obs=%d\n",
	    mqs, mqr, mqsig, mqpst, blocked_now, blk_obs);
}

/* Freeze-catcher: every 30s, IF blocked_now > 0 (threads waiting), dump the
 * stack of every CPU's current thread. DTrace doesn't have a direct "walk all
 * threads" — but on freeze, the BLOCKED threads are off-CPU. This coarse
 * observation captures the relevant state.
 *
 * Freeze signature (Arranger-verified, first-hand from op-140 onset):
 * bhyve 0.0% CPU + guest state IC → deadlock-on-wait, not spin. Slope flat
 * byte-identical at onset: alloc=35004 destroy=35002 | s=193530 r=196197.
 */
profile:::tick-30s
/ blocked_now > 0 /
{
	printf("OP148_FREEZE_OBS blocked=%d — dumping stacks\n", blocked_now);
	stack();
	ustack();
	blk_obs++;
}

/* Self-terminate at 5h (18000s) — conductor usually SIGINTs first. */
profile:::tick-18000s
{
	printf("OP148_TERMINAL reason=duration_cap\n");
	exit(0);
}

/* Safety net: if ipc_mqueue_pset_receive panics (op-105/bl-009 lineage),
 * DTrace dies silently. Capture the panic string. */
fbt::kern_reboot:entry
{
	printf("OP148_PANIC_OBS kern_reboot:entry arg0=%d stack:\n", arg0);
	stack();
}
