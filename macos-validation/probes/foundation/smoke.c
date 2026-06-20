/*
 * smoke.c — Foundation smoke probe for the oracle pipeline.
 *
 * Test ID: macos_foundation_smoke
 *
 * Allocates one receive right, inspects it with mach_port_type() and
 * mach_port_get_refs(), destroys it, and verifies the port namespace
 * returns to baseline. Exercises every common helper.
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

    /* Capture baseline before any port operations */
    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    /* Allocate a receive right */
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr_alloc = KERN_FAILURE;
    mach_port_type_t ptype = 0;
    kern_return_t kr_type = KERN_FAILURE;
    mach_port_urefs_t recv_refs = 0;
    kern_return_t kr_refs = KERN_FAILURE;
    kern_return_t kr_destroy = KERN_FAILURE;

#ifdef __APPLE__
    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    /* Inspect the port */
    if (kr_alloc == KERN_SUCCESS) {
        kr_type = mach_port_type(mach_task_self(), port, &ptype);
        kr_refs = mach_port_get_refs(mach_task_self(), port,
            MACH_PORT_RIGHT_RECEIVE, &recv_refs);
    }

    /* Destroy the port */
    if (kr_alloc == KERN_SUCCESS) {
        kr_destroy = mach_port_destroy(mach_task_self(), port);
    }
#endif /* __APPLE__ */

#ifndef __APPLE__
    (void)port;
#endif

    /* Capture baseline after cleanup */
    nx_baseline_capture(&after);
    int delta = 0;
    bool baseline_ok = nx_baseline_compare(&before, &after, &delta);

    /* Determine overall status */
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
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate failed";
    } else if (kr_type != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type failed after mach_port_allocate succeeded";
    } else if (kr_refs != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_get_refs failed after mach_port_allocate succeeded";
    } else if (kr_destroy != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy failed";
    } else if (!baseline_ok) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "port namespace did not return to baseline";
    }
#endif

    /* Emit JSON result */
    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j,
        agent,
        "macos_foundation_smoke",         /* test_id */
        NULL,                             /* nextbsd_test_id */
        NULL,                             /* donor_equivalent_id */
        status,
        sclass);

    /* Environment */
    nx_env_emit(&j);

    /* Message — not applicable for this probe */
    nx_result_emit_empty_message(&j);

    /* Returns */
    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate",
        nx_kern_return_str(kr_alloc), kr_alloc, false, 0);
    if (kr_alloc == KERN_SUCCESS) {
        nx_result_emit_return(&j, "mach_port_type",
            nx_kern_return_str(kr_type), kr_type, false, 0);
        nx_result_emit_return(&j, "mach_port_get_refs",
            nx_kern_return_str(kr_refs), kr_refs, false, 0);
        nx_result_emit_return(&j, "mach_port_destroy",
            nx_kern_return_str(kr_destroy), kr_destroy, false, 0);
    }
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    /* Right deltas */
    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    if (kr_alloc == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "allocate receive right",
            "smoke_port",
            kr_type == KERN_SUCCESS ? nx_port_type_str(ptype) : "unknown",
            -1,                                  /* before_urefs: N/A */
            kr_refs == KERN_SUCCESS ? (long long)recv_refs : -1,
            -1,                                  /* entry_refs_before: N/A */
            -1,                                  /* entry_refs_after: N/A */
            "created");
        nx_result_emit_right_delta(&j,
            "destroy receive right",
            "smoke_port",
            "MACH_PORT_TYPE_RECEIVE",
            kr_refs == KERN_SUCCESS ? (long long)recv_refs : -1,
            0,
            -1,
            -1,
            "destroyed");
    }
    nx_json_end_array(&j);

    /* Cleanup */
    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);

    /* Notes */
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    /* Free baselines */
    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
