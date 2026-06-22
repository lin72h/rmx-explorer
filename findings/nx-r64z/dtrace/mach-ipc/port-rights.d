/* port-rights.d — port + right manipulation: alloc/destroy, right copyin/copyout
 * (transfer), dealloc/delta (uref change), lookup/check. Observes the right
 * accounting that gates message delivery. */
#pragma D option quiet
BEGIN { printf("port-rights begin (target=%d)\n", $target); }
fbt::ipc_port_alloc:entry    { printf("ipc_port_alloc\n"); }
fbt::ipc_port_destroy:entry  { printf("ipc_port_destroy\n"); }
fbt::ipc_right_copyin:entry  { printf("ipc_right_copyin (transfer in)\n"); }
fbt::ipc_right_copyout:entry { printf("ipc_right_copyout (transfer out)\n"); }
fbt::ipc_right_dealloc:entry { printf("ipc_right_dealloc\n"); }
fbt::ipc_right_delta:entry   { printf("ipc_right_delta (uref change)\n"); }
fbt::ipc_right_lookup:entry  { printf("ipc_right_lookup\n"); }
fbt::ipc_right_destroy:entry { printf("ipc_right_destroy\n"); }
