/* op190-xpc-cancel-truth.c — macOS XPC cancel + error-delivery contract capture.
 *
 * Captures the BEHAVIORAL contract macOS libxpc delivers (runtime, not source) so the
 * rmxOS bucket-3 fill designs to a quantified target. Three scenarios, each on a SERIAL
 * queue + semaphore (NOT a main-thread sleep — the op-122 lesson: the async cancel event
 * only fires if the connection's target queue is pumped):
 *   D1a local-cancel  : established conn, xpc_connection_cancel -> handler event?
 *   D1b remote-death   : server op=exit -> peer dies -> handler event?
 *   D3  reply-pending  : _with_reply_sync in flight (server op=delay), cancel -> what does
 *                        the waiter return? (the op-187 reply-context invalidation coupling)
 *   D2  error-structure: for each event, xpc_get_type==XPC_TYPE_ERROR? xpc_equal vs the
 *                        XPC_ERROR_* singletons? dict count? (shared-singleton discrimination)
 *
 * Target service: com.rmxos.op190.echo (LaunchAgent, op190-xpc-echo.c: ping/delay/exit).
 * Build: cc -fblocks -include Availability.h -O2 -o op190-xpc-cancel-truth op190-xpc-cancel-truth.c
 */
#include <dispatch/dispatch.h>
#include <xpc/xpc.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OP190_SERVICE "com.rmxos.op190.echo"

/* Per-scenario capture state (reset before each). */
static const char      *g_label;
static volatile int     g_fired;
static int              g_is_err;
static int              g_eq_inv;
static int              g_eq_int;
static int              g_eq_term;
static size_t           g_count;
static char             g_desc[256];
static dispatch_semaphore_t g_sem;

static void
reset_cap(const char *label)
{
    g_label = label;
    g_fired = 0; g_is_err = 0; g_eq_inv = 0; g_eq_int = 0; g_eq_term = 0;
    g_count = 0; g_desc[0] = '\0';
    g_sem = dispatch_semaphore_create(0);
}

static void
capture_event(xpc_object_t event)
{
    g_fired  = 1;
    g_is_err = (xpc_get_type(event) == XPC_TYPE_ERROR);
    g_eq_inv  = xpc_equal(event, (xpc_object_t)XPC_ERROR_CONNECTION_INVALID);
    g_eq_int  = xpc_equal(event, (xpc_object_t)XPC_ERROR_CONNECTION_INTERRUPTED);
    g_eq_term = xpc_equal(event, (xpc_object_t)XPC_ERROR_TERMINATION_IMMINENT);
    g_count = xpc_dictionary_get_count(event);
    const char *d = xpc_dictionary_get_string(event, "description");
    strncpy(g_desc, d ? d : "(no 'description' key)", sizeof(g_desc) - 1);
    g_desc[sizeof(g_desc) - 1] = '\0';
    dispatch_semaphore_signal(g_sem);
}

static void
print_cap(void)
{
    printf("[D2-ERROR-STRUCT] %s: fired=%d  is_XPC_TYPE_ERROR=%d  "
           "eq_CONNECTION_INVALID=%d  eq_CONNECTION_INTERRUPTED=%d  "
           "eq_TERMINATION_IMMINENT=%d  dict_count=%zu\n",
        g_label, g_fired, g_is_err, g_eq_inv, g_eq_int, g_eq_term, g_count);
    printf("[D2-ERROR-STRUCT]   description=\"%s\"\n", g_desc);
}

static void
op190_send_op(xpc_connection_t conn, const char *op)
{
    xpc_object_t req = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(req, "op", op);
    xpc_connection_send_message(conn, req);  /* fire-and-forget */
    xpc_release(req);
}

int
main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    long w;

    /* ===== D1a: local cancel ===== */
    printf("\n=== D1a: local cancel ===\n");
    reset_cap("D1a_local_cancel");
    {
        dispatch_queue_t q = dispatch_queue_create("op190.d1a", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t conn = xpc_connection_create_mach_service(OP190_SERVICE, q, 0);
        xpc_connection_set_event_handler(conn, ^(xpc_object_t e) { capture_event(e); });
        xpc_connection_resume(conn);
        /* establish the connection with an op=ping round-trip */
        xpc_object_t req = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(req, "op", "ping");
        xpc_object_t rep = xpc_connection_send_message_with_reply_sync(conn, req);
        xpc_release(req);
        const char *rs = rep ? xpc_dictionary_get_string(rep, "reply") : NULL;
        printf("D1a: established=%d reply=\"%s\"\n", rep != NULL, rs ? rs : "(null)");
        if (rep) xpc_release(rep);
        /* local cancel */
        xpc_connection_cancel(conn);
        w = dispatch_semaphore_wait(g_sem, dispatch_time(DISPATCH_TIME_NOW, 5LL * 1000 * 1000 * 1000));
        printf("D1a: handler %s\n", w == 0 ? "FIRED" : "TIMEOUT(no event)");
        print_cap();
        xpc_release(conn);
    }

    /* ===== D1b: remote peer death (server op=exit) ===== */
    printf("\n=== D1b: remote peer death ===\n");
    reset_cap("D1b_remote_death");
    {
        dispatch_queue_t q = dispatch_queue_create("op190.d1b", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t conn = xpc_connection_create_mach_service(OP190_SERVICE, q, 0);
        xpc_connection_set_event_handler(conn, ^(xpc_object_t e) { capture_event(e); });
        xpc_connection_resume(conn);
        /* op=exit: server replies "exiting" then exit(0) -> peer dies */
        xpc_object_t req = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(req, "op", "exit");
        xpc_object_t rep = xpc_connection_send_message_with_reply_sync(conn, req);
        xpc_release(req);
        const char *rs = rep ? xpc_dictionary_get_string(rep, "reply") : NULL;
        printf("D1b: pre-death reply=\"%s\"\n", rs ? rs : "(null)");
        if (rep) xpc_release(rep);
        w = dispatch_semaphore_wait(g_sem, dispatch_time(DISPATCH_TIME_NOW, 5LL * 1000 * 1000 * 1000));
        printf("D1b: handler %s\n", w == 0 ? "FIRED" : "TIMEOUT(no event)");
        print_cap();
        xpc_release(conn);
    }

    /* ===== D3: cancel vs in-flight _with_reply_sync (op-187 coupling) ===== */
    printf("\n=== D3: cancel vs pending _with_reply_sync ===\n");
    reset_cap("D3_reply_pending");
    {
        dispatch_queue_t q = dispatch_queue_create("op190.d3", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t conn = xpc_connection_create_mach_service(OP190_SERVICE, q, 0);
        xpc_connection_set_event_handler(conn, ^(xpc_object_t e) { capture_event(e); });
        xpc_connection_resume(conn);

        /* BG thread: op=delay -> _with_reply_sync blocks ~3s while server delays */
        __block xpc_object_t bg_reply = NULL;
        dispatch_semaphore_t reply_sem = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            xpc_object_t req = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(req, "op", "delay");
            bg_reply = xpc_connection_send_message_with_reply_sync(conn, req);
            xpc_release(req);
            dispatch_semaphore_signal(reply_sem);
        });

        usleep(500000);  /* 0.5s — server is mid-delay; the waiter is blocked */
        printf("D3: cancelling the connection mid-pending-reply\n");
        xpc_connection_cancel(conn);

        /* what does the waiter receive? */
        long wr = dispatch_semaphore_wait(reply_sem, dispatch_time(DISPATCH_TIME_NOW, 8LL * 1000 * 1000 * 1000));
        printf("D3: _with_reply_sync %s\n", wr == 0 ? "RETURNED" : "STILL_BLOCKED(timeout)");
        if (wr == 0) {
            if (bg_reply == NULL) {
                printf("D3: waiter returned NULL\n");
            } else {
                int r_is_err = (xpc_get_type(bg_reply) == XPC_TYPE_ERROR);
                const char *rstr = xpc_dictionary_get_string(bg_reply, "reply");
                printf("D3: waiter reply=\"%s\" is_XPC_TYPE_ERROR=%d\n", rstr ? rstr : "(null)", r_is_err);
                xpc_release(bg_reply);
            }
        }
        /* handler (cancel) event too? */
        long wh = dispatch_semaphore_wait(g_sem, dispatch_time(DISPATCH_TIME_NOW, 3LL * 1000 * 1000 * 1000));
        printf("D3: handler %s\n", wh == 0 ? "FIRED" : "no-additional-event");
        print_cap();
        xpc_release(conn);
    }

    printf("\nOP190_TERMINAL status=0\n");
    return 0;
}
