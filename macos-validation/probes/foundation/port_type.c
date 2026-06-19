/*
 * port_type.c - Foundation mach_port_type() oracle probe.
 *
 * Test ID: macos_foundation_port_type
 *
 * Verifies observable Mach port type transitions for receive rights, inserted
 * send rights, port sets, and the task self port. Cleans up all allocated
 * rights and requires the task port namespace to return to baseline.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

static const char *
type_hex(mach_port_type_t type)
{
    static char bufs[4][32];
    static unsigned int idx;
    char *buf = bufs[idx++ % 4];

    snprintf(buf, 32, "0x%x", (unsigned)type);
    return buf;
}

static bool
is_exact_type(mach_port_type_t observed, mach_port_type_t expected)
{
    return observed == expected;
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);
    nx_baseline_capture(&after);

    mach_port_t receive_port = MACH_PORT_NULL;
    mach_port_t port_set = MACH_PORT_NULL;
    kern_return_t kr_alloc_receive = KERN_FAILURE;
    kern_return_t kr_type_receive = KERN_FAILURE;
    kern_return_t kr_insert_send = KERN_FAILURE;
    kern_return_t kr_type_send_receive = KERN_FAILURE;
    kern_return_t kr_alloc_port_set = KERN_FAILURE;
    kern_return_t kr_type_port_set = KERN_FAILURE;
    kern_return_t kr_type_task_self = KERN_FAILURE;
    kern_return_t kr_destroy_receive = KERN_FAILURE;
    kern_return_t kr_destroy_port_set = KERN_FAILURE;
    mach_port_type_t type_receive = 0;
    mach_port_type_t type_send_receive = 0;
    mach_port_type_t type_port_set = 0;
    mach_port_type_t type_task_self = 0;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#ifdef __APPLE__
    kr_alloc_receive = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &receive_port);
    if (kr_alloc_receive == KERN_SUCCESS) {
        kr_type_receive = mach_port_type(mach_task_self(), receive_port,
            &type_receive);
        kr_insert_send = mach_port_insert_right(mach_task_self(),
            receive_port, receive_port, MACH_MSG_TYPE_MAKE_SEND);
        if (kr_insert_send == KERN_SUCCESS) {
            kr_type_send_receive = mach_port_type(mach_task_self(),
                receive_port, &type_send_receive);
        }
    }

    kr_alloc_port_set = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_PORT_SET, &port_set);
    if (kr_alloc_port_set == KERN_SUCCESS) {
        kr_type_port_set = mach_port_type(mach_task_self(), port_set,
            &type_port_set);
    }

    kr_type_task_self = mach_port_type(mach_task_self(), mach_task_self(),
        &type_task_self);

    if (kr_alloc_receive == KERN_SUCCESS) {
        kr_destroy_receive = mach_port_destroy(mach_task_self(), receive_port);
    }
    if (kr_alloc_port_set == KERN_SUCCESS) {
        kr_destroy_port_set = mach_port_destroy(mach_task_self(), port_set);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#else
    (void)receive_port;
    (void)port_set;
#endif

    bool receive_exact = is_exact_type(type_receive, MACH_PORT_TYPE_RECEIVE);
    bool send_receive_exact = is_exact_type(type_send_receive,
        MACH_PORT_TYPE_SEND_RECEIVE);
    bool port_set_exact = is_exact_type(type_port_set, MACH_PORT_TYPE_PORT_SET);
    bool task_self_observed = (kr_type_task_self == KERN_SUCCESS);

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
    if (nx_baseline_blocks_probe(&before)) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "initial mach_port_names failed";
    } else if (kr_alloc_receive != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate receive failed";
    } else if (kr_type_receive != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type receive failed";
    } else if (!receive_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "receive right type was not exact MACH_PORT_TYPE_RECEIVE";
    } else if (kr_insert_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_insert_right MAKE_SEND failed";
    } else if (kr_type_send_receive != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type send_receive failed";
    } else if (!send_receive_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send+receive type was not exact MACH_PORT_TYPE_SEND_RECEIVE";
    } else if (kr_alloc_port_set != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate port set failed";
    } else if (kr_type_port_set != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type port set failed";
    } else if (!port_set_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "port set type was not exact MACH_PORT_TYPE_PORT_SET";
    } else if (kr_type_task_self != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type mach_task_self failed";
    } else if (kr_destroy_receive != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy receive failed";
    } else if (kr_destroy_port_set != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy port set failed";
    } else if (nx_baseline_blocks_probe(&after)) {
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
        "macos_foundation_port_type",
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
    nx_result_emit_return(&j, "mach_port_allocate_receive",
        nx_kern_return_str(kr_alloc_receive), kr_alloc_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_type_receive",
        nx_kern_return_str(kr_type_receive), kr_type_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_make_send",
        nx_kern_return_str(kr_insert_send), kr_insert_send, false, 0);
    nx_result_emit_return(&j, "mach_port_type_send_receive",
        nx_kern_return_str(kr_type_send_receive), kr_type_send_receive,
        false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_port_set",
        nx_kern_return_str(kr_alloc_port_set), kr_alloc_port_set, false, 0);
    nx_result_emit_return(&j, "mach_port_type_port_set",
        nx_kern_return_str(kr_type_port_set), kr_type_port_set, false, 0);
    nx_result_emit_return(&j, "mach_port_type_task_self",
        nx_kern_return_str(kr_type_task_self), kr_type_task_self, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_receive",
        nx_kern_return_str(kr_destroy_receive), kr_destroy_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_port_set",
        nx_kern_return_str(kr_destroy_port_set), kr_destroy_port_set,
        false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    if (kr_type_receive == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "allocate receive right",
            "port_type_receive_port",
            nx_port_type_str(type_receive),
            -1,
            -1,
            -1,
            -1,
            "MACH_PORT_TYPE_RECEIVE");
    }
    if (kr_type_send_receive == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "insert send right",
            "port_type_receive_port",
            nx_port_type_str(type_send_receive),
            -1,
            -1,
            -1,
            -1,
            "MACH_PORT_TYPE_SEND_RECEIVE");
    }
    if (kr_type_port_set == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "allocate port set",
            "port_type_port_set",
            nx_port_type_str(type_port_set),
            -1,
            -1,
            -1,
            -1,
            "MACH_PORT_TYPE_PORT_SET");
    }
    if (kr_type_task_self == KERN_SUCCESS) {
        nx_result_emit_right_delta(&j,
            "inspect task self",
            "mach_task_self",
            nx_port_type_str(type_task_self),
            -1,
            -1,
            -1,
            -1,
            "observed");
    }
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "receive_type", nx_port_type_str(type_receive));
    nx_json_key_string(&j, "receive_type_raw_hex", type_hex(type_receive));
    nx_json_key_bool(&j, "receive_type_exact", receive_exact);
    nx_json_key_string(&j, "send_receive_type",
        nx_port_type_str(type_send_receive));
    nx_json_key_string(&j, "send_receive_type_raw_hex",
        type_hex(type_send_receive));
    nx_json_key_bool(&j, "send_receive_type_exact", send_receive_exact);
    nx_json_key_string(&j, "port_set_type", nx_port_type_str(type_port_set));
    nx_json_key_string(&j, "port_set_type_raw_hex", type_hex(type_port_set));
    nx_json_key_bool(&j, "port_set_type_exact", port_set_exact);
    nx_json_key_bool(&j, "task_self_observed", task_self_observed);
    nx_json_key_string(&j, "task_self_type", nx_port_type_str(type_task_self));
    nx_json_key_string(&j, "task_self_type_raw_hex", type_hex(type_task_self));
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
