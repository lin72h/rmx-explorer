/* msg-send.d — the send half: mach_msg_send -> kmsg alloc/copyin -> right copyin
 * -> mqueue enqueue. Composable; pair with msg-receive.d. */
#pragma D option quiet
BEGIN { printf("msg-send begin (target=%d)\n", $target); }
fbt::mach_msg_send:entry   { printf("> mach_msg_send\n"); self->s = 1; }
fbt::mach_msg_send:return  /self->s/ { printf("< mach_msg_send rc=%d\n", (int)arg1); self->s = 0; }
fbt::ipc_kmsg_alloc:entry  { printf("  ipc_kmsg_alloc\n"); }
fbt::ipc_kmsg_copyin:entry { printf("  ipc_kmsg_copyin\n"); }
fbt::ipc_right_copyin:entry { printf("  ipc_right_copyin\n"); }
fbt::ipc_mqueue_send:entry { printf("  ipc_mqueue_send (enqueue)\n"); }
