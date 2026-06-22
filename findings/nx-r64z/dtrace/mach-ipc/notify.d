/* notify.d — dead-name + no-senders (and port-deleted) notifications: the
 * armed-request + fire paths. These are how a holder learns a name died or a
 * send right lost its receiver. */
#pragma D option quiet
BEGIN { printf("notify (dead-name/no-senders) begin (target=%d)\n", $target); }
fbt::ipc_port_dnrequest:entry { printf("ipc_port_dnrequest (dead-name arm)\n"); }
fbt::ipc_port_dnnotify:entry  { printf("ipc_port_dnnotify (dead-name FIRE)\n"); }
fbt::ipc_port_dngrow:entry    { printf("ipc_port_dngrow\n"); }
fbt::ipc_port_dncancel:entry  { printf("ipc_port_dncancel\n"); }
fbt::ipc_port_nsrequest:entry { printf("ipc_port_nsrequest (no-senders arm)\n"); }
fbt::ipc_port_pdrequest:entry { printf("ipc_port_pdrequest (port-deleted arm)\n"); }
fbt::ipc_right_dnrequest:entry { printf("ipc_right_dnrequest\n"); }
