/* op-130 id-015 step-3 smoke sample: dispatch_async_f shell-context marker.
 * Minimal Darwin sample: dispatch a work item that prints a marker from inside
 * the async block, drain, exit. Shell-launch is correct — dispatch needs no
 * Mach bootstrap (id-016). Links against the image's libdispatch.so.5.
 *
 * Compile recipe (in-guest, using the image's cc):
 *   cc -std=c11 -fblocks -D__APPLE__ -o /root/dispatch_async_f \
 *     /root/dispatch_async_f.c -ldispatch -lmach -lBlocksRuntime -lthr -lsys
 *
 * Or cross-compile on the build host:
 *   cc -std=c11 -fblocks -D__APPLE__ \
 *     -I$rmxos/lib/libdispatch -I$rmxos/include -I$rmxos/sys \
 *     -o dispatch_async_f dispatch_async_f.c \
 *     -L$obj/lib/libdispatch -L$obj/lib/libmach -L$obj/lib/libblocksruntime \
 *     -L$obj/lib/libthr -L$obj/lib/libsys -ldispatch -lmach -lBlocksRuntime -lthr -lsys
 *
 * Expected output:
 *   OP130_DISPATCH status=0
 *   OP130_TERMINAL status=0
 */
#include <dispatch/dispatch.h>
#include <stdio.h>

static void work_item(void *ctx) {
    (void)ctx;
    printf("OP130_DISPATCH status=0\n");
    fflush(stdout);
}

int main(void) {
    dispatch_queue_t q = dispatch_queue_create("op130.smoke", NULL);
    dispatch_async_f(q, NULL, work_item);
    /* drain: dispatch_sync forces the queue to complete before we exit */
    dispatch_sync(q, ^{});
    dispatch_release(q);
    printf("OP130_TERMINAL status=0\n");
    return 0;
}
