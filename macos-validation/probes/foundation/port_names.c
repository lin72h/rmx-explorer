/*
 * port_names.c - Foundation mach_port_names() oracle probe.
 *
 * Test ID: macos_foundation_port_names
 *
 * Captures the current task's port namespace, allocates one receive right,
 * verifies mach_port_names() observes that symbolic probe port, destroys it,
 * and verifies the namespace returns to the original baseline.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

static bool
baseline_has_port(const nx_baseline_t *baseline, mach_port_t port,
                  mach_port_type_t *type_out)
{
    if (!baseline->valid || baseline->types_count != baseline->names_count) {
        return false;
    }

    for (mach_msg_type_number_t i = 0; i < baseline->names_count; i++) {
        if (baseline->names[i] == port) {
            if (type_out != NULL) {
                *type_out = baseline->types[i];
            }
            return true;
        }
    }

    return false;
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, during, after;
    nx_baseline_capture(&before);
    nx_baseline_capture(&during);
    nx_baseline_capture(&after);

    mach_port_t probe_port = MACH_PORT_NULL;
    mach_port_type_t observed_type = 0;
    kern_return_t kr_alloc = KERN_FAILURE;
    kern_return_t kr_destroy = KERN_FAILURE;
    bool probe_seen = false;
    int during_delta = 0;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#ifdef __APPLE__
    kr_alloc = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &probe_port);

    nx_baseline_free(&during);
    nx_baseline_capture(&during);

    if (kr_alloc == KERN_SUCCESS && during.valid) {
        probe_seen = baseline_has_port(&during, probe_port, &observed_type);
    }

    if (kr_alloc == KERN_SUCCESS) {
        kr_destroy = mach_port_destroy(mach_task_self(), probe_port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);

    if (before.valid && during.valid) {
        during_delta = (int)during.names_count - (int)before.names_count;
    }
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#else
    (void)probe_port;
    (void)observed_type;
#endif

    nx_status_t status = NX_STATUS_PASS;
    nx_semantic_class_t sclass = NX_CLASS_EXACT_CONTRACT;
    const char *notes = "";
    const char *cleanup_notes = cleanup_ok ? "" : "namespace delta detected";

#ifndef __APPLE__
    status = NX_STATUS_SKIP;
    sclass = NX_CLASS_NOT_OBSERVABLE;
    notes = "non-macOS host: Mach APIs unavailable";
    cleanup_ok = true;
    cleanup_notes = "not applicable on non-macOS host";
#else
    if (before.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "initial mach_port_names failed";
    } else if (kr_alloc != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate failed";
    } else if (during.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_names after allocation failed";
    } else if (!probe_seen) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_port_names did not report allocated probe port";
    } else if (during_delta != 1) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_port_names count delta was not one after allocation";
    } else if (kr_destroy != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy failed";
    } else if (after.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "final mach_port_names failed";
    } else if (!cleanup_ok) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
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
        "macos_foundation_port_names",
        NULL,
        NULL,
        status,
        sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate",
        nx_kern_return_str(kr_alloc), kr_alloc, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after_allocate",
        nx_kern_return_str(during.kr), during.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy",
        nx_kern_return_str(kr_destroy), kr_destroy, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after_destroy",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    if (kr_alloc == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "allocate receive right observed by mach_port_names",
            "port_names_probe_port",
            probe_seen ? nx_port_type_str(observed_type) : "unknown",
            -1,
            -1,
            -1,
            -1,
            probe_seen ? "present" : "missing");
        nx_result_emit_right_delta(&j,
            "destroy receive right observed by mach_port_names",
            "port_names_probe_port",
            probe_seen ? nx_port_type_str(observed_type) : "unknown",
            -1,
            -1,
            -1,
            -1,
            cleanup_ok ? "removed" : "cleanup_delta");
    }
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_int(&j, "names_before", before.valid ? before.names_count : -1);
    nx_json_key_int(&j, "names_after_allocate",
        during.valid ? during.names_count : -1);
    nx_json_key_int(&j, "names_after_destroy",
        after.valid ? after.names_count : -1);
    nx_json_key_int(&j, "allocation_delta", during_delta);
    nx_json_key_int(&j, "cleanup_delta", cleanup_delta);
    nx_json_key_bool(&j, "probe_port_seen", probe_seen);
    nx_json_key_string(&j, "probe_port_label", "port_names_probe_port");
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);

    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&during);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
