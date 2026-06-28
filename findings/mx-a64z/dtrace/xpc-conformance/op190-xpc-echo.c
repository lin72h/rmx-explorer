/* op190-xpc-echo.c — controllable macOS XPC responder for op-190 cancel/error capture.
 *
 * Registers com.rmxos.op190.echo as a launchd MachServices listener. Per-message "op":
 *   op=ping  -> immediate echo (establishes the connection is live)
 *   op=delay -> sleep 3s, then echo (so the client can cancel a pending _with_reply_sync)
 *   op=exit  -> exit(0) (simulate remote peer death)
 * Replies use xpc_dictionary_create_reply (the contract path).
 * Build: cc -fblocks -O2 -o op190-xpc-echo op190-xpc-echo.c
 */
#include <dispatch/dispatch.h>
#include <xpc/xpc.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OP190_SERVICE "com.rmxos.op190.echo"

static void
op190_handle_peer(xpc_connection_t peer)
{
    xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
        xpc_object_t reply = xpc_dictionary_create_reply(event);
        if (reply == NULL) {
            return;  /* non-replyable (error) event */
        }
        const char *op = xpc_dictionary_get_string(event, "op");
        if (op != NULL && strcmp(op, "exit") == 0) {
            /* Acknowledge then exit -> remote peer death for the client. */
            xpc_dictionary_set_string(reply, "reply", "exiting");
            xpc_connection_send_message(peer, reply);
            xpc_release(reply);
            exit(0);
        }
        if (op != NULL && strcmp(op, "delay") == 0) {
            sleep(3);  /* hold the reply so the client can cancel mid-flight */
            xpc_dictionary_set_string(reply, "reply", "pong-delayed");
        } else {
            xpc_dictionary_set_string(reply, "reply", "pong");
        }
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
        OP190_SERVICE, dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
    if (listener == NULL) {
        fprintf(stderr, "op190-responder: listener NULL\n");
        return 2;
    }
    xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
        op190_handle_peer((xpc_connection_t)event);
    });
    xpc_connection_resume(listener);
    dispatch_main();
    return 0;
}
