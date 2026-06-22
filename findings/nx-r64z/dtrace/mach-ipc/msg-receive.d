/* msg-receive.d — the receive half: mqueue dequeue -> kmsg copyout -> right
 * copyout -> kmsg destroy -> mach_msg_receive returns. Pair with msg-send.d. */
#pragma D option quiet
BEGIN { printf("msg-receive begin (target=%d)\n", $target); }
fbt::mach_msg_receive:entry  { printf("> mach_msg_receive\n"); self->r = 1; }
fbt::mach_msg_receive:return /self->r/ { printf("< mach_msg_receive rc=%d\n", (int)arg1); self->r = 0; }
fbt::ipc_mqueue_receive:entry { printf("  ipc_mqueue_receive (dequeue)\n"); }
fbt::ipc_kmsg_copyout:entry  { printf("  ipc_kmsg_copyout\n"); }
fbt::ipc_right_copyout:entry { printf("  ipc_right_copyout\n"); }
fbt::ipc_kmsg_destroy:entry  { printf("  ipc_kmsg_destroy\n"); }
