/* port-set.d — port-set membership + the kqueue EVFILT_MACHPORT filter ops
 * (provided by mach.ko dynamically). Observes how a port-set/kevent-based
 * receiver is wired (e.g. libdispatch's MACH_RECV source, op-098 T1). */
#pragma D option quiet
BEGIN { printf("port-set begin (target=%d)\n", $target); }
fbt::ipc_pset_add:entry       { printf("ipc_pset_add\n"); }
fbt::ipc_pset_remove:entry    { printf("ipc_pset_remove\n"); }
fbt::filt_machportattach:entry { printf("filt_machportattach (kqueue MACHPORT attach)\n"); }
fbt::filt_machportdetach:entry { printf("filt_machportdetach\n"); }
fbt::filt_machport:entry       { printf("filt_machport (kqueue MACHPORT event fire)\n"); }
