/*
 * port_get_attributes.c — Foundation port-attributes probe (block-080a #4).
 *
 * Test ID: macos_foundation_port_get_attributes
 *
 * Exercises mach_port_get_attributes() on a fresh receive right:
 *   - MACH_PORT_RECEIVE_STATUS succeeds and returns the expected in/out count
 *     (MACH_PORT_RECEIVE_STATUS_COUNT == 10) with a mach_port_status_t
 *   - an invalid flavor is rejected
 *   - attributes on a non-existent name are rejected (KERN_INVALID_NAME)
 *
 * Allocates + destroys one receive right; namespace baseline returns to 0.
 * The captured status fields (mps_*) are emitted for provenance; the contract
 * invariants are: a fresh receive right reads back mps_msgcount==0,
 * mps_seqno==0, mps_sorights==0, mps_srights==false, mps_pset==0. mps_qlimit is
 * environment-default and captured, not asserted.
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

    /* mx-fidelity provenance from mach_port_status_t (captured, not asserted). */
    long long mps_pset = -1, mps_seqno = -1, mps_mscount = -1, mps_qlimit = -1;
    long long mps_msgcount = -1, mps_sorights = -1, mps_flags = -1;
    bool mps_srights = false, mps_pdrequest = false, mps_nsrequest = false;

#ifdef __APPLE__
    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    if (kr_alloc == KERN_SUCCESS) {
        mach_port_status_t status;
        attrs_count = MACH_PORT_RECEIVE_STATUS_COUNT;
        kr_attrs = mach_port_get_attributes(mach_task_self(), port,
            MACH_PORT_RECEIVE_STATUS, (mach_port_info_t)&status, &attrs_count);

        if (kr_attrs == KERN_SUCCESS) {
            mps_pset = (long long)status.mps_pset;
            mps_seqno = (long long)status.mps_seqno;
            mps_mscount = (long long)status.mps_mscount;
            mps_qlimit = (long long)status.mps_qlimit;
            mps_msgcount = (long long)status.mps_msgcount;
            mps_sorights = (long long)status.mps_sorights;
            mps_srights = status.mps_srights;
            mps_pdrequest = status.mps_pdrequest;
            mps_nsrequest = status.mps_nsrequest;
            mps_flags = (long long)status.mps_flags;
        }

        mach_port_status_t sink;
        mach_msg_type_number_t bad_count = MACH_PORT_RECEIVE_STATUS_COUNT;
        kr_bad_flavor = mach_port_get_attributes(mach_task_self(), port,
            (mach_port_flavor_t)0xff, (mach_port_info_t)&sink, &bad_count);

        kr_bad_name = mach_port_get_attributes(mach_task_self(),
            (mach_port_name_t)0xdeadbeef, MACH_PORT_RECEIVE_STATUS,
            (mach_port_info_t)&sink, &bad_count);

        kr_destroy = mach_port_destroy(mach_task_self(), port);
    }
#endif /* __APPLE__ */

#ifndef __APPLE__
    (void)port;
#endif

    nx_baseline_capture(&after);
    int delta = 0;
    bool baseline_ok = nx_baseline_compare(&before, &after, &delta);

    bool count_exact = (kr_attrs == KERN_SUCCESS &&
        attrs_count == MACH_PORT_RECEIVE_STATUS_COUNT);
    bool fresh_receive_state = (kr_attrs == KERN_SUCCESS &&
        mps_msgcount == 0 && mps_seqno == 0 && mps_sorights == 0 &&
        !mps_srights && mps_pset == 0);

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
        notes = "mach_port_get_attributes(RECEIVE_STATUS) failed";
    } else if (!count_exact) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "get_attributes out-count did not match MACH_PORT_RECEIVE_STATUS_COUNT";
    } else if (!fresh_receive_state) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "fresh receive right did not read back an empty, send-less status";
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
    nx_result_emit_return(&j, "mach_port_get_attributes_receive_status",
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
    nx_json_key_bool(&j, "count_matches_receive_status_count", count_exact);
    nx_json_key_bool(&j, "fresh_receive_right_state", fresh_receive_state);
    nx_json_key_bool(&j, "invalid_flavor_rejected", kr_bad_flavor != KERN_SUCCESS);
    nx_json_key_bool(&j, "bad_name_rejected", kr_bad_name != KERN_SUCCESS);
    nx_json_key_bool(&j, "destroy_succeeded", kr_destroy == KERN_SUCCESS);
    /* Provenance (captured, not comparison): mach_port_status_t fields. */
    nx_json_key_int(&j, "mps_pset", mps_pset);
    nx_json_key_int(&j, "mps_seqno", mps_seqno);
    nx_json_key_int(&j, "mps_mscount", mps_mscount);
    nx_json_key_int(&j, "mps_qlimit", mps_qlimit);
    nx_json_key_int(&j, "mps_msgcount", mps_msgcount);
    nx_json_key_int(&j, "mps_sorights", mps_sorights);
    nx_json_key_bool(&j, "mps_srights", mps_srights);
    nx_json_key_bool(&j, "mps_pdrequest", mps_pdrequest);
    nx_json_key_bool(&j, "mps_nsrequest", mps_nsrequest);
    nx_json_key_int(&j, "mps_flags", mps_flags);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
