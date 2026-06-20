/*
 * port_set.c — Foundation port-set probe (block-080a #5).
 *
 * Test ID: macos_foundation_port_set
 *
 * Exercises a port-set lifecycle:
 *   - mach_port_allocate(MACH_PORT_RIGHT_PORT_SET) yields a PORT_SET right
 *   - a receive-right member is allocated and added via mach_port_move_member
 *   - mach_msg(MACH_RCV_MSG|MACH_RCV_TIMEOUT) on the set returns
 *     MACH_RCV_TIMED_OUT (the set is empty)
 *   - the member is removed (move_member to MACH_PORT_NULL), then both the
 *     member and the set are destroyed; namespace baseline returns to 0
 *
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

    mach_port_t       pset           = MACH_PORT_NULL;
    mach_port_t       member         = MACH_PORT_NULL;
    mach_port_type_t  set_type       = 0;
    kern_return_t     kr_alloc_set   = KERN_FAILURE;
    kern_return_t     kr_alloc_mem   = KERN_FAILURE;
    kern_return_t     kr_type_set    = KERN_FAILURE;
    kern_return_t     kr_move        = KERN_FAILURE;
    kern_return_t     kr_unmove      = KERN_FAILURE;
    kern_return_t     kr_destroy_mem = KERN_FAILURE;
    kern_return_t     kr_destroy_set = KERN_FAILURE;
    mach_msg_return_t mr_recv        = MACH_RCV_TIMED_OUT;

#ifdef __APPLE__
    kr_alloc_set = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_PORT_SET, &pset);
    kr_alloc_mem = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &member);

    if (kr_alloc_set == KERN_SUCCESS) {
        kr_type_set = mach_port_type(mach_task_self(), pset, &set_type);
    }

    if (kr_alloc_set == KERN_SUCCESS && kr_alloc_mem == KERN_SUCCESS) {
        kr_move = mach_port_move_member(mach_task_self(), member, pset);

        /* Receive on the (empty) set with a short timeout. */
        mach_msg_header_t hdr;
        mr_recv = mach_msg(&hdr,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0, sizeof(hdr), pset, 10, MACH_PORT_NULL);

        kr_unmove = mach_port_move_member(mach_task_self(), member,
            MACH_PORT_NULL);
    }

    if (kr_alloc_mem == KERN_SUCCESS) {
        kr_destroy_mem = mach_port_destroy(mach_task_self(), member);
    }
    if (kr_alloc_set == KERN_SUCCESS) {
        kr_destroy_set = mach_port_destroy(mach_task_self(), pset);
    }
#endif /* __APPLE__ */

#ifndef __APPLE__
    (void)pset;
    (void)member;
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
    if (kr_alloc_set != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(PORT_SET) failed";
    } else if (kr_alloc_mem != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(RECEIVE) member failed";
    } else if (kr_move != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_move_member into the set failed";
    } else if (mr_recv != MACH_RCV_TIMED_OUT) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_msg on empty set did not return MACH_RCV_TIMED_OUT";
    } else if (kr_destroy_set != KERN_SUCCESS || kr_destroy_mem != KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "port-set member or set destroy failed";
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
        "macos_foundation_port_set",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);

    /* Message: receive-on-set summary */
    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", "");
    nx_json_key(&j, "remote_port");
    nx_json_begin_object(&j);
    nx_json_key_null(&j, "name");
    nx_json_key_null(&j, "disposition");
    nx_json_key_null(&j, "right_type");
    nx_json_end_object(&j);
    nx_json_key(&j, "local_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "port_set");
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
    nx_result_emit_return(&j, "mach_port_allocate_port_set",
        nx_kern_return_str(kr_alloc_set), kr_alloc_set, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_member",
        nx_kern_return_str(kr_alloc_mem), kr_alloc_mem, false, 0);
    nx_result_emit_return(&j, "mach_port_type_port_set",
        nx_kern_return_str(kr_type_set), kr_type_set, false, 0);
    nx_result_emit_return(&j, "mach_port_move_member_into_set",
        nx_kern_return_str(kr_move), kr_move, false, 0);
    nx_result_emit_return(&j, "mach_msg_receive_on_set",
        nx_msg_return_str(mr_recv), (long long)mr_recv, false, 0);
    nx_result_emit_return(&j, "mach_port_move_member_out_of_set",
        nx_kern_return_str(kr_unmove), kr_unmove, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_member",
        nx_kern_return_str(kr_destroy_mem), kr_destroy_mem, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_port_set",
        nx_kern_return_str(kr_destroy_set), kr_destroy_set, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "port_set_allocated", kr_alloc_set == KERN_SUCCESS);
    nx_json_key_string(&j, "port_set_type",
        kr_type_set == KERN_SUCCESS ? nx_port_type_str(set_type) : "unknown");
    nx_json_key_bool(&j, "move_member_succeeded", kr_move == KERN_SUCCESS);
    nx_json_key_bool(&j, "receive_on_set_timed_out", mr_recv == MACH_RCV_TIMED_OUT);
    nx_json_key_bool(&j, "destroy_succeeded",
        kr_destroy_mem == KERN_SUCCESS && kr_destroy_set == KERN_SUCCESS);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
