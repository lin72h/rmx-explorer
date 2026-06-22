/* mach-ipc full-round-trip.d — correlated view of a full mach_msg round-trip:
 * send -> copyin -> enqueue -> dequeue -> copyout -> receive, plus the
 * port-right + kmsg lifecycle + dead-name/no-senders neighbors. The canonical
 * reference script for IPC spine observation (op-099). Type-safe: probefunc + %s.
 *
 * Anchors verified via `nm mach.ko` (all `t` = fbt-reachable). Compose narrower
 * views with the per-concern siblings (msg-send.d, msg-receive.d, kmsg.d,
 * port-rights.d, port-set.d, notify.d). */
#pragma D option quiet
BEGIN { printf("mach-ipc full-round-trip begin (target=%d)\n", $target); }

/* mach_msg entry (the API surface) */
fbt::mach_msg_send:entry   { printf("> mach_msg_send\n"); }
fbt::mach_msg_send:return  { printf("< mach_msg_send\n"); }
fbt::mach_msg_receive:entry  { printf("> mach_msg_receive\n"); }
fbt::mach_msg_receive:return { printf("< mach_msg_receive\n"); }

/* kmsg lifecycle */
fbt::ipc_kmsg_alloc:entry   { printf("  > ipc_kmsg_alloc\n"); }
fbt::ipc_kmsg_copyin:entry  { printf("  > ipc_kmsg_copyin (send-side)\n"); }
fbt::ipc_kmsg_copyout:entry { printf("  > ipc_kmsg_copyout (recv-side)\n"); }
fbt::ipc_kmsg_destroy:entry { printf("  > ipc_kmsg_destroy\n"); }
fbt::ipc_kmsg_clean:entry   { printf("  > ipc_kmsg_clean\n"); }

/* mqueue enqueue/dequeue */
fbt::ipc_mqueue_send:entry    { printf("  > ipc_mqueue_send (enqueue)\n"); }
fbt::ipc_mqueue_receive:entry { printf("  > ipc_mqueue_receive (dequeue)\n"); }

/* port-right transfer */
fbt::ipc_right_copyin:entry  { printf("  > ipc_right_copyin\n"); }
fbt::ipc_right_copyout:entry { printf("  > ipc_right_copyout\n"); }

/* port-set / kqueue machport filter */
fbt::ipc_pset_add:entry    { printf("  > ipc_pset_add\n"); }
fbt::ipc_pset_remove:entry { printf("  > ipc_pset_remove\n"); }
fbt::filt_machportattach:entry { printf("  > filt_machportattach (kqueue MACHPORT attach)\n"); }
fbt::filt_machportdetach:entry { printf("  > filt_machportdetach\n"); }
fbt::filt_machport:entry       { printf("  > filt_machport (kqueue MACHPORT event)\n"); }

/* dead-name / no-senders notifications */
fbt::ipc_port_dnrequest:entry { printf("  > ipc_port_dnrequest (dead-name arm)\n"); }
fbt::ipc_port_dnnotify:entry  { printf("  > ipc_port_dnnotify (dead-name fire)\n"); }
fbt::ipc_port_nsrequest:entry { printf("  > ipc_port_nsrequest (no-senders arm)\n"); }
