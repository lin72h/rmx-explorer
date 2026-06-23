/* invariant-oracle: ipc_kmsg alloc vs destroy balance (no stuck work).
 * Every kmsg allocated should eventually be destroyed (no leaked messages). */
#pragma D option quiet
BEGIN { printf("kmsg-balance oracle start\n"); }
fbt::ipc_kmsg_alloc:entry   { @alloc = count(); }
fbt::ipc_kmsg_destroy:entry { @destroy = count(); }
END { printf("alloc=%d destroy=%d delta=%d\n", @alloc, @destroy, @alloc - @destroy);
      exit(@alloc - @destroy != 0); }
