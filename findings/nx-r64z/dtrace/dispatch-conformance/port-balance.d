/* invariant-oracle: ipc_port alloc vs dealloc balance (no right leak).
 * Net alloc-destroy should be bounded (some ports persist for the lifetime of
 * queues/sources; flag only UNBOUNDED growth across iterations). */
#pragma D option quiet
BEGIN { printf("port-balance oracle start\n"); self->phase = 0; }
fbt::ipc_port_alloc:entry   { @alloc = count(); }
fbt::ipc_port_destroy:entry { @destroy = count(); }
END { printf("alloc=%d destroy=%d delta=%d\n", @alloc, @destroy, @alloc - @destroy); }
