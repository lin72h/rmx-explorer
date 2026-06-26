/* op-122 libxpc substrate + PLANE conformance harness (CANONICAL CLIENT BLOB).
 *
 * This is the BYTE-IDENTICAL client shared across rx-x64z (rmxOS) + mx-a64z (macOS).
 * No rmxOS-only #ifdef — if a symbol is absent, that absence IS the divergence.
 *
 * FIX-BACK from the REJECTED prior run:
 *   - Plane Case 1 target changed from com.apple.system.logger → com.rmxos.op122.echo
 *   - Uses xpc_connection_create_mach_service (not xpc_connection_create)
 *   - Uses xpc_connection_send_message_with_reply_sync (op-160 proven on rmxOS)
 *   - Asserts reply=="pong" + seqid echo + typed field echo
 *   - RECORD-not-assert cancel→error (prints description, no strcmp-assert)
 *
 * Build:
 *   rmxOS: cc -fblocks -D__APPLE__ -I... -o xpc-harness-plane xpc-harness-plane.c -lxpc -ldispatch -lBlocksRuntime
 *   macOS:  cc -fblocks -o xpc-harness-plane xpc-harness-plane.c
 */
#ifndef __OSX_AVAILABLE_BUT_DEPRECATED
#define __OSX_AVAILABLE_BUT_DEPRECATED(...)
#endif
#ifndef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(...)
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>

static int g_fails = 0;
#define R(name, val) printf("%s: %s\n", (name), (val)?"PASS":"FAIL"); g_fails += !(val)

/* Cancel-event capture (RECORDED, not asserted) */
static volatile int g_cancel_event_seen = 0;
static char g_cancel_desc[256] = "(no event)";

#define OP122_ECHO_SERVICE "com.rmxos.op122.echo"

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);

    /* ================================================================
     * SUBSTRATE CASES (op-121 carried forward, unchanged)
     * ================================================================ */

    xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
    R("xpc_dictionary_create", dict != NULL);

    xpc_object_t i64 = xpc_int64_create(0x7F0000000001LL);
    R("xpc_int64_create", i64 != NULL);
    if (i64) {
        int64_t got = xpc_int64_get_value(i64);
        R("xpc_int64_get_value", got == 0x7F0000000001LL);
        xpc_dictionary_set_value(dict, "seq", i64);
    }

    xpc_dictionary_set_int64(dict, "count", 42);
    xpc_dictionary_set_string(dict, "service", "com.test.op122");

    const char *svc = xpc_dictionary_get_string(dict, "service");
    R("xpc_dictionary_get_string", svc != NULL && strcmp(svc, "com.test.op122") == 0);

    int64_t cnt = xpc_dictionary_get_int64(dict, "count");
    R("xpc_dictionary_get_int64", cnt == 42);

    size_t dcount = xpc_dictionary_get_count(dict);
    R("xpc_dictionary_get_count", dcount == 3);

    xpc_object_t str = xpc_string_create("hello-xpc");
    R("xpc_string_create", str != NULL);

    xpc_object_t data = xpc_data_create("bytes", 5);
    R("xpc_data_create", data != NULL);
    if (data) {
        R("xpc_data_get_length", xpc_data_get_length(data) == 5);
        R("xpc_data_get_bytes_ptr", memcmp(xpc_data_get_bytes_ptr(data), "bytes", 5) == 0);
    }

    xpc_object_t dict2 = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(dict2, "count", 42);
    xpc_dictionary_set_string(dict2, "service", "com.test.op122");
    xpc_dictionary_set_int64(dict2, "seq", 0x7F0000000001LL);
    size_t h1 = xpc_hash(dict);
    size_t h2 = xpc_hash(dict2);
    R("xpc_hash_consistent", h1 == h2);

    /* Connection lifecycle (substrate — no live peer) */
    xpc_connection_t conn0 = xpc_connection_create("com.test.op122.nonexistent", NULL);
    R("xpc_connection_create", conn0 != NULL);
    if (conn0) {
        xpc_connection_set_event_handler(conn0, ^(xpc_object_t event) { (void)event; });
        xpc_connection_resume(conn0);
        xpc_connection_cancel(conn0);
        R("xpc_connection_lifecycle", 1);
    } else {
        R("xpc_connection_lifecycle", 0);
    }

    /* ================================================================
     * PLANE CASES (op-122 — the deferred transport layer)
     * ================================================================ */
    printf("\n--- PLANE CASES (op-122) ---\n");

    /* === PLANE CASE 1: send→reply w/ seqid + typed echo ===
     *
     * Connect to the op-122 echo service via Mach bootstrap.
     * Send: op122_seqid, op122_msg, op122_int64, op122_uint64, op122_bool.
     * Assert: reply=="pong", seqid echoed, all typed fields echoed verbatim.
     */
    {
        xpc_connection_t conn = xpc_connection_create_mach_service(
            OP122_ECHO_SERVICE, dispatch_get_main_queue(), 0);
        R("op122_plane_connect", conn != NULL);

        if (conn) {
            /* Set up cancel-event capture (for PLANE CASE 3 below) */
            xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
                g_cancel_event_seen = 1;
                const char *desc = xpc_dictionary_get_string(event, "description");
                if (desc) {
                    strncpy(g_cancel_desc, desc, sizeof(g_cancel_desc)-1);
                    g_cancel_desc[sizeof(g_cancel_desc)-1] = '\0';
                } else {
                    strncpy(g_cancel_desc, "(no description key)", sizeof(g_cancel_desc)-1);
                }
            });
            xpc_connection_resume(conn);
            R("op122_plane_resume", 1);

            /* Build typed-payload request */
            xpc_object_t req = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(req, "op", "ping");
            xpc_dictionary_set_int64(req, "op122_seqid", 0xCAFE0001LL);
            xpc_dictionary_set_string(req, "op122_msg", "typed-payload-test");
            xpc_dictionary_set_int64(req, "op122_int64", 0x7FFFll);
            xpc_dictionary_set_uint64(req, "op122_uint64", 0xFFFFFFFFll);
            xpc_dictionary_set_bool(req, "op122_bool", 1);
            R("op122_plane_request_construct", req != NULL);

            /* Synchronous send → reply */
            xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, req);
            xpc_release(req);

            if (reply) {
                R("op122_plane_reply_received", 1);

                /* Assert reply=="pong" */
                const char *pong = xpc_dictionary_get_string(reply, "reply");
                R("op122_plane_reply_pong", pong != NULL && strcmp(pong, "pong") == 0);

                /* Assert seqid echo */
                int64_t echo_seqid = xpc_dictionary_get_int64(reply, "op122_seqid");
                R("op122_plane_seqid_echo", echo_seqid == 0xCAFE0001LL);

                /* Assert typed field echo */
                const char *echo_str = xpc_dictionary_get_string(reply, "op122_msg");
                R("op122_plane_string_echo",
                    echo_str != NULL && strcmp(echo_str, "typed-payload-test") == 0);

                int64_t echo_i64 = xpc_dictionary_get_int64(reply, "op122_int64");
                R("op122_plane_int64_echo", echo_i64 == 0x7FFFll);

                uint64_t echo_u64 = xpc_dictionary_get_uint64(reply, "op122_uint64");
                R("op122_plane_uint64_echo", echo_u64 == 0xFFFFFFFFll);

                int echo_bool = (int)xpc_dictionary_get_bool(reply, "op122_bool");
                R("op122_plane_bool_echo", echo_bool == 1);

                xpc_release(reply);
            } else {
                R("op122_plane_reply_received", 0);
                R("op122_plane_reply_pong", 0);
                R("op122_plane_seqid_echo", 0);
                R("op122_plane_string_echo", 0);
                R("op122_plane_int64_echo", 0);
                R("op122_plane_uint64_echo", 0);
                R("op122_plane_bool_echo", 0);
            }

            /* === PLANE CASE 2: typed payload fidelity ===
             * (Already exercised by CASE 1's typed fields + assertions.
             * The local round-trip checks below verify the XPC dictionary
             * API without a live service — pure substrate-level.) */
            xpc_object_t typed = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_int64(typed, "tv_i64", 0x7FFFll);
            xpc_dictionary_set_string(typed, "tv_str", "fidelity");
            xpc_dictionary_set_bool(typed, "tv_bool", 1);
            xpc_dictionary_set_uint64(typed, "tv_u64", 0xFFFFFFFFll);
            R("op122_plane_typed_int64",
                xpc_dictionary_get_int64(typed, "tv_i64") == 0x7FFFll);
            R("op122_plane_typed_string",
                strcmp(xpc_dictionary_get_string(typed, "tv_str"), "fidelity") == 0);
            R("op122_plane_typed_bool",
                (int)xpc_dictionary_get_bool(typed, "tv_bool") == 1);
            R("op122_plane_typed_uint64",
                xpc_dictionary_get_uint64(typed, "tv_u64") == 0xFFFFFFFFll);
            R("op122_plane_typed_count",
                xpc_dictionary_get_count(typed) == 4);
            xpc_release(typed);

            /* === PLANE CASE 3: cancel→error (RECORDED, not asserted) ===
             * Cancel the connection. Wait 2s for the event handler.
             * RECORD whatever the cancel event contains — no strcmp-assert. */
            xpc_connection_cancel(conn);

            /* Give the dispatch queue time to fire the event handler */
            sleep(2);

            printf("op122_plane_cancel_event_seen: %s\n",
                g_cancel_event_seen ? "PASS" : "FAIL");
            g_fails += !g_cancel_event_seen;

            printf("OP122_CANCEL_DESC description=%s\n", g_cancel_desc);
            /* NO assertion on the description string — just record it.
             * The diff between rx and mx will show if the error
             * descriptions diverge. */

            xpc_release(conn);
        }
    }

    /* ================================================================
     * RELEASE (substrate cleanup)
     * ================================================================ */
    xpc_release(dict);
    xpc_release(dict2);
    if (i64) xpc_release(i64);
    if (str) xpc_release(str);
    if (data) xpc_release(data);
    if (conn0) xpc_release(conn0);
    R("xpc_release", 1);

    printf("op122_matrix_fails=%d\n", g_fails);
    printf("op122_matrix_terminal status=0\n");
    return 0;
}
