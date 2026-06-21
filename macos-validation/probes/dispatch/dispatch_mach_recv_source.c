/*
 * dispatch_mach_recv_source.c — Dispatch MACH_RECV source probe (op-082 #2).
 *
 * Test ID: macos_dispatch_mach_recv_source
 *
 * Captures macOS-27 ground truth for DISPATCH_SOURCE_TYPE_MACH_RECV servicing:
 *   - allocate a receive right; create a serial queue
 *   - dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, port, 0, queue)
 *   - set an event handler that receives the message via mach_msg(MACH_RCV_MSG)
 *   - resume the source; send a message to the port
 *   - the source fires -> handler runs -> services (receives) the message
 *
 * This is the dispatch-servicing-of-a-Mach-port target behavior (#2 / MACH_RECV).
 * The probe needs BOTH Mach (recv right) and libdispatch, so it is Apple-only
 * (rmxOS guest skips until it has Mach recv + dispatch). Raw port names are
 * provenance, not a comparison axis. Timing is non-deterministic (capture-not-
 * assert): only the source-fired + handler-serviced invariants are asserted.
 *
 * Emits an nx-r64z.macos-oracle.v1 JSON result to stdout.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nx_json.h"
#include "nx_result.h"
#include "nx_env.h"
#include "nx_mach_utils.h"

#if defined(__APPLE__) && __has_include(<dispatch/dispatch.h>)
#define NX_HAVE_DISPATCH 1
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <mach/mach.h>
#else
#define NX_HAVE_DISPATCH 0
#endif

#define DMRS_MSG_ID 0x444d5253  /* "DMRS" */
#define DMRS_WAIT_NS (2LL * 1000 * 1000 * 1000)  /* 2 s */

#if NX_HAVE_DISPATCH
typedef struct {
    dispatch_semaphore_t sem;
    mach_port_t          port;
    _Atomic int          serviced;
    kern_return_t        recv_kr;
} dmrs_ctx_t;

static void
dmrs_handler(void *ctxptr)
{
    dmrs_ctx_t *c = (dmrs_ctx_t *)ctxptr;

    /* Receive the message that fired the MACH_RECV source. */
    struct {
        mach_msg_header_t      header;
        mach_msg_max_trailer_t trailer;
    } msg;
    memset(&msg, 0, sizeof(msg));
    c->recv_kr = mach_msg(&msg.header,
        MACH_RCV_MSG | MACH_RCV_TIMEOUT,
        0, (mach_msg_size_t)sizeof(msg), c->port, 500, MACH_PORT_NULL);

    if (c->recv_kr == MACH_MSG_SUCCESS) {
        atomic_store(&c->serviced, 1);
    }
    dispatch_semaphore_signal(c->sem);
}
#endif

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    kern_return_t        kr_alloc  = KERN_FAILURE;
    kern_return_t        kr_send   = KERN_FAILURE;
    kern_return_t        kr_dest   = KERN_FAILURE;
    int                  handler_serviced = 0;
    long long            recv_kr   = (long long)KERN_FAILURE;
    int                  cleanup_delta = 0;
    bool                 cleanup_ok = false;

#if NX_HAVE_DISPATCH
    mach_port_t port = MACH_PORT_NULL;
    dmrs_ctx_t  ctx;
    memset(&ctx, 0, sizeof(ctx));
    atomic_init(&ctx.serviced, 0);
    ctx.recv_kr = KERN_FAILURE;

    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    if (kr_alloc == KERN_SUCCESS) {
        dispatch_queue_t q = dispatch_queue_create("nx.dmrs",
            DISPATCH_QUEUE_SERIAL);
        dispatch_source_t src = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_MACH_RECV, (uintptr_t)port, 0, q);

        if (src != NULL) {
            ctx.sem  = dispatch_semaphore_create(0);
            ctx.port = port;
            dispatch_set_context(src, &ctx);
            dispatch_source_set_event_handler_f(src, dmrs_handler);
            dispatch_resume(src);

            /* Send one minimal message to the port (MAKE_SEND from the receive
             * right we hold). This is what the source observes + the handler
             * receives. */
            struct {
                mach_msg_header_t header;
            } send_msg;
            memset(&send_msg, 0, sizeof(send_msg));
            send_msg.header.msgh_bits =
                MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
            send_msg.header.msgh_size = (mach_msg_size_t)sizeof(send_msg);
            send_msg.header.msgh_remote_port = port;
            send_msg.header.msgh_local_port = MACH_PORT_NULL;
            send_msg.header.msgh_id = DMRS_MSG_ID;
            kr_send = mach_msg(&send_msg.header,
                MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                send_msg.header.msgh_size, 0,
                MACH_PORT_NULL, 5000, MACH_PORT_NULL);

            if (kr_send == KERN_SUCCESS) {
                dispatch_semaphore_wait(ctx.sem,
                    dispatch_time(DISPATCH_TIME_NOW, DMRS_WAIT_NS));
            }

            handler_serviced = atomic_load(&ctx.serviced);
            recv_kr = (long long)ctx.recv_kr;

            dispatch_release(src);
            if (ctx.sem != NULL) {
                dispatch_release(ctx.sem);
            }
        }
        if (q != NULL) {
            dispatch_release(q);
        }
        kr_dest = mach_port_destroy(mach_task_self(), port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#endif

    nx_status_t status = NX_STATUS_PASS;
    nx_semantic_class_t sclass = NX_CLASS_EXACT_CONTRACT;
    const char *notes = "";
    const char *cleanup_notes = cleanup_ok ? "" : "libdispatch leaves internal Mach ports (delta captured, non-gating)";

#if !NX_HAVE_DISPATCH
    status = NX_STATUS_SKIP;
    sclass = NX_CLASS_NOT_OBSERVABLE;
    notes = "host without Mach+dispatch: MACH_RECV source not available";
    cleanup_ok = true;
    cleanup_notes = "not applicable on this host";
#else
    if (kr_alloc != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(RECEIVE) failed";
    } else if (kr_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_msg SEND to the recv port failed";
    } else if (!handler_serviced) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "DISPATCH_SOURCE_TYPE_MACH_RECV did not fire + service the message";
    } else if (kr_dest != KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy failed";
    }
    /* libdispatch leaves internal Mach ports (worker reply/event ports) in the
     * namespace, so the port-namespace baseline is NOT a contract for dispatch
     * probes; the delta is captured as a non-deterministic observation. */
#endif

    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j, agent, "macos_dispatch_mach_recv_source",
        NULL, NULL, status, sclass);

    nx_env_emit(&j);

    /* Message: the message sent to the recv port (MAKE_SEND, no descriptors). */
    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", "MACH_MSGH_BITS(MAKE_SEND,0)");
    nx_json_key(&j, "remote_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "recv_port");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MAKE_SEND");
    nx_json_key_string(&j, "right_type", "MACH_PORT_TYPE_RECEIVE");
    nx_json_end_object(&j);
    nx_json_key(&j, "local_port");
    nx_json_begin_object(&j);
    nx_json_key_null(&j, "name");
    nx_json_key_null(&j, "disposition");
    nx_json_key_null(&j, "right_type");
    nx_json_end_object(&j);
    nx_json_key(&j, "header_rights");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);
    nx_json_key_int(&j, "descriptor_count", 0);
    nx_json_key(&j, "descriptors");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_receive",
        nx_kern_return_str(kr_alloc), kr_alloc, false, 0);
    nx_result_emit_return(&j, "mach_msg_send_to_recv_port",
        nx_kern_return_str(kr_send), kr_send, false, 0);
    nx_result_emit_return(&j, "mach_msg_receive_in_handler",
        nx_kern_return_str((kern_return_t)recv_kr), (long long)recv_kr, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_recv_port",
        nx_kern_return_str(kr_dest), kr_dest, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "mach_recv_source_created", kr_alloc == KERN_SUCCESS);
    nx_json_key_bool(&j, "send_succeeded", kr_send == KERN_SUCCESS);
    nx_json_key_bool(&j, "handler_fired_and_serviced", handler_serviced);
    nx_json_key_string(&j, "source_type", "DISPATCH_SOURCE_TYPE_MACH_RECV");
    nx_json_key_int(&j, "names_before", before.valid ? before.names_count : -1);
    nx_json_key_int(&j, "names_after", after.valid ? after.names_count : -1);
    nx_json_key_int(&j, "cleanup_delta", cleanup_delta);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
