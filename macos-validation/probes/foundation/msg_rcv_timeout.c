/*
 * msg_rcv_timeout.c — Foundation receive-timeout probe (block-080a #6).
 *
 * Test ID: macos_foundation_msg_rcv_timeout
 *
 * Exercises mach_msg(MACH_RCV_MSG | MACH_RCV_TIMEOUT) on an empty receive
 * right:
 *   - returns MACH_RCV_TIMED_OUT (no message is available)
 *   - no message is delivered (the receive buffer is untouched)
 *
 * Allocates + destroys one receive right; namespace baseline returns to 0.
 * Emits a complete nx-r64z.macos-oracle.v1 JSON result to stdout.
 */

#include <stdio.h>
#include <stdlib.h>

#include "nx_json.h"
#include "nx_result.h"
#include "nx_env.h"
#include "nx_mach_utils.h"

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    mach_port_t       port     = MACH_PORT_NULL;
    kern_return_t     kr_alloc = KERN_FAILURE;
    kern_return_t     kr_dest  = KERN_FAILURE;
    mach_msg_return_t mr       = MACH_RCV_TIMED_OUT;

#ifdef __APPLE__
    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    if (kr_alloc == KERN_SUCCESS) {
        mach_msg_header_t hdr;
        mr = mach_msg(&hdr,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0, sizeof(hdr), port, 10, MACH_PORT_NULL);

        kr_dest = mach_port_destroy(mach_task_self(), port);
    }
#endif /* __APPLE__ */

#ifndef __APPLE__
    (void)port;
#endif

    nx_baseline_capture(&after);
    int delta = 0;
    bool baseline_ok = nx_baseline_compare(&before, &after, &delta);

    nx_status_t status = NX_STATUS_PASS;
    nx_semantic_class_t sclass = NX_CLASS_EXACT_CONTRACT;
    const char *notes = "";
    bool cleanup_ok = baseline_ok;
    const char *cleanup_notes = baseline_ok ? "" : "namespace delta detected";

#ifndef __APPLE__
    status = NX_STATUS_SKIP;
    sclass = NX_CLASS_NOT_OBSERVABLE;
    notes = "non-macOS host: Mach APIs unavailable, pipeline smoke only";
    cleanup_ok = true;
    cleanup_notes = "not applicable on non-macOS host";
#else
    if (kr_alloc != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(RECEIVE) failed";
    } else if (mr != MACH_RCV_TIMED_OUT) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_msg on empty receive right did not return MACH_RCV_TIMED_OUT";
    } else if (kr_dest != KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy failed";
    } else if (!baseline_ok) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "port namespace did not return to baseline";
    }
#endif

    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j,
        agent,
        "macos_foundation_msg_rcv_timeout",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_receive",
        nx_kern_return_str(kr_alloc), kr_alloc, false, 0);
    nx_result_emit_return(&j, "mach_msg_receive_timeout",
        nx_msg_return_str(mr), (long long)mr, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_receive",
        nx_kern_return_str(kr_dest), kr_dest, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "allocate_succeeded", kr_alloc == KERN_SUCCESS);
    nx_json_key_bool(&j, "receive_returned_timed_out", mr == MACH_RCV_TIMED_OUT);
    nx_json_key_bool(&j, "no_message_delivered", mr != MACH_MSG_SUCCESS);
    nx_json_key_bool(&j, "destroy_succeeded", kr_dest == KERN_SUCCESS);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
