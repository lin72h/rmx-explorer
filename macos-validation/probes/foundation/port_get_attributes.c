/*
 * port_get_attributes.c — Foundation port-attributes probe (block-080a #4).
 *
 * Test ID: macos_foundation_port_get_attributes
 *
 * Exercises mach_port_get_attributes() on a fresh receive right:
 *   - MACH_PORT_RECEIVE_CONTEXT succeeds and returns a sane in/out count
 *   - an invalid flavor is rejected
 *   - attributes on a non-existent name are rejected (KERN_INVALID_NAME)
 *
 * Allocates + destroys one receive right; namespace baseline returns to 0.
 * The receive-context VALUE (default 0) is intentionally not observed here
 * to avoid coupling to a specific union member name; the success/count
 * contract is the parity-relevant part.
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

    mach_port_t           port          = MACH_PORT_NULL;
    kern_return_t         kr_alloc      = KERN_FAILURE;
    kern_return_t         kr_attrs      = KERN_FAILURE;
    kern_return_t         kr_bad_flavor = KERN_FAILURE;
    kern_return_t         kr_bad_name   = KERN_FAILURE;
    kern_return_t         kr_destroy    = KERN_FAILURE;
    mach_msg_type_number_t attrs_count  = 0;

#ifdef __APPLE__
    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    if (kr_alloc == KERN_SUCCESS) {
        mach_port_info_data_t info;

        attrs_count = MACH_PORT_INFO_COUNT;
        kr_attrs = mach_port_get_attributes(mach_task_self(), port,
            MACH_PORT_RECEIVE_CONTEXT, (mach_port_info_t)&info, &attrs_count);

        mach_msg_type_number_t bad_count = MACH_PORT_INFO_COUNT;
        kr_bad_flavor = mach_port_get_attributes(mach_task_self(), port,
            (mach_port_flavor_t)0xff, (mach_port_info_t)&info, &bad_count);

        kr_bad_name = mach_port_get_attributes(mach_task_self(),
            (mach_port_name_t)0xdeadbeef, MACH_PORT_RECEIVE_CONTEXT,
            (mach_port_info_t)&info, &bad_count);

        kr_destroy = mach_port_destroy(mach_task_self(), port);
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
    } else if (kr_attrs != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_get_attributes(RECEIVE_CONTEXT) failed";
    } else if (kr_bad_flavor == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_port_get_attributes accepted an invalid flavor (expected rejection)";
    } else if (kr_bad_name == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_port_get_attributes accepted a non-existent name (expected KERN_INVALID_NAME)";
    } else if (kr_destroy != KERN_SUCCESS) {
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
        "macos_foundation_port_get_attributes",
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
    nx_result_emit_return(&j, "mach_port_get_attributes_receive_context",
        nx_kern_return_str(kr_attrs), kr_attrs, false, 0);
    nx_result_emit_return(&j, "mach_port_get_attributes_invalid_flavor",
        nx_kern_return_str(kr_bad_flavor), kr_bad_flavor, false, 0);
    nx_result_emit_return(&j, "mach_port_get_attributes_bad_name",
        nx_kern_return_str(kr_bad_name), kr_bad_name, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_receive",
        nx_kern_return_str(kr_destroy), kr_destroy, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "allocate_succeeded", kr_alloc == KERN_SUCCESS);
    nx_json_key_bool(&j, "get_attributes_succeeded", kr_attrs == KERN_SUCCESS);
    nx_json_key_int(&j, "get_attributes_count", (long long)attrs_count);
    nx_json_key_bool(&j, "invalid_flavor_rejected", kr_bad_flavor != KERN_SUCCESS);
    nx_json_key_bool(&j, "bad_name_rejected", kr_bad_name != KERN_SUCCESS);
    nx_json_key_bool(&j, "destroy_succeeded", kr_destroy == KERN_SUCCESS);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
