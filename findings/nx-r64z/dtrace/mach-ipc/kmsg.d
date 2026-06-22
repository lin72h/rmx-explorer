/* kmsg.d — kernel message lifecycle: alloc -> copyin (send) -> copyout (recv)
 * -> clean -> destroy. The allocation/copy path is the hot path for descriptor
 * + OOL handling. */
#pragma D option quiet
BEGIN { printf("kmsg-lifecycle begin (target=%d)\n", $target); }
fbt::ipc_kmsg_alloc:entry   { printf("ipc_kmsg_alloc\n"); }
fbt::ipc_kmsg_copyin:entry  { printf("ipc_kmsg_copyin\n"); }
fbt::ipc_kmsg_copyout:entry { printf("ipc_kmsg_copyout\n"); }
fbt::ipc_kmsg_clean:entry   { printf("ipc_kmsg_clean\n"); }
fbt::ipc_kmsg_destroy:entry { printf("ipc_kmsg_destroy\n"); }
