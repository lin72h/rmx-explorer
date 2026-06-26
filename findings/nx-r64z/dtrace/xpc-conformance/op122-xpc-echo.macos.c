/* op122-xpc-echo.macos.c — macOS XPC echo responder (mx-a64z).
 *
 * The macOS side of the op-122 echo service. Implements the SAME locked contract
 * as the rmxOS responder (op122-xpc-echo.c) but without rmxOS availability shims
 * (macOS has the real macros) and without the rmxOS fresh-dict fallback — on macOS
 * xpc_dictionary_create_reply WORKS, so the reply is correlated the contract way.
 * This is the clean counterpart to rmxOS's create_reply→NULL (id-029): on macOS the
 * client's send_message_with_reply_sync RETURNS with the echoed reply.
 *
 * Registered as a launchd LaunchAgent: com.rmxos.op122.echo (MachServices, on-demand).
 * Build: cc -fblocks -O2 -o op122-xpc-echo.macos op122-xpc-echo.macos.c
 */
#include <dispatch/dispatch.h>
#include <xpc/xpc.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OP122_SERVICE_NAME "com.rmxos.op122.echo"

static void
op122_handle_peer(xpc_connection_t peer)
{
    xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
        /* create_reply returns NULL for non-replyable events (errors) — skip those. */
        xpc_object_t reply = xpc_dictionary_create_reply(event);
        if (reply == NULL) {
            return;
        }

        /* Echo the locked contract fields (mirrors op122-xpc-echo.c / the client). */
        xpc_dictionary_set_string(reply, "reply", "pong");
        xpc_dictionary_set_int64(reply, "op122_seqid",
            xpc_dictionary_get_int64(event, "op122_seqid"));

        const char *sval = xpc_dictionary_get_string(event, "op122_msg");
        if (sval != NULL) {
            xpc_dictionary_set_string(reply, "op122_msg", sval);
        }
        xpc_dictionary_set_int64(reply, "op122_int64",
            xpc_dictionary_get_int64(event, "op122_int64"));
        xpc_dictionary_set_uint64(reply, "op122_uint64",
            xpc_dictionary_get_uint64(event, "op122_uint64"));
        xpc_dictionary_set_bool(reply, "op122_bool",
            xpc_dictionary_get_bool(event, "op122_bool"));

        xpc_connection_send_message(peer, reply);
        xpc_release(reply);
    });
    xpc_connection_resume(peer);
}

int
main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);

    xpc_connection_t listener = xpc_connection_create_mach_service(
        OP122_SERVICE_NAME, dispatch_get_main_queue(),
        XPC_CONNECTION_MACH_SERVICE_LISTENER);
    if (listener == NULL) {
        fprintf(stderr, "op122-mx-responder: listener NULL\n");
        return 2;
    }

    xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
        op122_handle_peer((xpc_connection_t)event);
    });
    xpc_connection_resume(listener);
    dispatch_main();

    return 0;
}
