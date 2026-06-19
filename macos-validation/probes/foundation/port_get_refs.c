/*
 * port_get_refs.c - Foundation mach_port_get_refs() oracle probe.
 *
 * Test ID: macos_foundation_port_get_refs
 *
 * Verifies observable user-reference accounting for a receive right and an
 * inserted send right. It records exact kern_return_t values, keeps kernel-only
 * entry refs null, and requires the task port namespace to return to baseline.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);
    nx_baseline_capture(&after);

    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr_alloc_receive = KERN_FAILURE;
    kern_return_t kr_recv_refs_initial = KERN_FAILURE;
    kern_return_t kr_send_refs_before_make = KERN_FAILURE;
    kern_return_t kr_insert_send = KERN_FAILURE;
    kern_return_t kr_send_refs_after_make = KERN_FAILURE;
    kern_return_t kr_mod_refs_plus_one = KERN_FAILURE;
    kern_return_t kr_send_refs_after_mod_plus = KERN_FAILURE;
    kern_return_t kr_deallocate_send = KERN_FAILURE;
    kern_return_t kr_send_refs_after_deallocate = KERN_FAILURE;
    kern_return_t kr_mod_refs_minus_one = KERN_FAILURE;
    kern_return_t kr_send_refs_after_mod_minus = KERN_FAILURE;
    kern_return_t kr_recv_refs_final = KERN_FAILURE;
    kern_return_t kr_destroy_receive = KERN_FAILURE;
    mach_port_urefs_t recv_refs_initial = 0;
    mach_port_urefs_t send_refs_before_make = 0;
    mach_port_urefs_t send_refs_after_make = 0;
    mach_port_urefs_t send_refs_after_mod_plus = 0;
    mach_port_urefs_t send_refs_after_deallocate = 0;
    mach_port_urefs_t send_refs_after_mod_minus = 0;
    mach_port_urefs_t recv_refs_final = 0;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#ifdef __APPLE__
    kr_alloc_receive = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);

    if (kr_alloc_receive == KERN_SUCCESS) {
        kr_recv_refs_initial = mach_port_get_refs(mach_task_self(), port,
            MACH_PORT_RIGHT_RECEIVE, &recv_refs_initial);
        kr_send_refs_before_make = mach_port_get_refs(mach_task_self(), port,
            MACH_PORT_RIGHT_SEND, &send_refs_before_make);

        kr_insert_send = mach_port_insert_right(mach_task_self(), port, port,
            MACH_MSG_TYPE_MAKE_SEND);
        if (kr_insert_send == KERN_SUCCESS) {
            kr_send_refs_after_make = mach_port_get_refs(mach_task_self(),
                port, MACH_PORT_RIGHT_SEND, &send_refs_after_make);
        }

        if (kr_send_refs_after_make == KERN_SUCCESS) {
            kr_mod_refs_plus_one = mach_port_mod_refs(mach_task_self(), port,
                MACH_PORT_RIGHT_SEND, 1);
        }
        if (kr_mod_refs_plus_one == KERN_SUCCESS) {
            kr_send_refs_after_mod_plus = mach_port_get_refs(mach_task_self(),
                port, MACH_PORT_RIGHT_SEND, &send_refs_after_mod_plus);
        }

        if (kr_send_refs_after_mod_plus == KERN_SUCCESS) {
            kr_deallocate_send = mach_port_deallocate(mach_task_self(), port);
        }
        if (kr_deallocate_send == KERN_SUCCESS) {
            kr_send_refs_after_deallocate = mach_port_get_refs(
                mach_task_self(), port, MACH_PORT_RIGHT_SEND,
                &send_refs_after_deallocate);
        }

        if (kr_send_refs_after_deallocate == KERN_SUCCESS) {
            kr_mod_refs_minus_one = mach_port_mod_refs(mach_task_self(), port,
                MACH_PORT_RIGHT_SEND, -1);
        }
        if (kr_mod_refs_minus_one == KERN_SUCCESS) {
            kr_send_refs_after_mod_minus = mach_port_get_refs(
                mach_task_self(), port, MACH_PORT_RIGHT_SEND,
                &send_refs_after_mod_minus);
        }

        kr_recv_refs_final = mach_port_get_refs(mach_task_self(), port,
            MACH_PORT_RIGHT_RECEIVE, &recv_refs_final);
        kr_destroy_receive = mach_port_destroy(mach_task_self(), port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#else
    (void)port;
#endif

    bool receive_refs_initial_exact = (kr_recv_refs_initial == KERN_SUCCESS &&
        recv_refs_initial == 1);
    bool send_refs_before_make_zero =
        (kr_send_refs_before_make == KERN_SUCCESS &&
        send_refs_before_make == 0);
    bool send_refs_after_make_exact = (kr_send_refs_after_make == KERN_SUCCESS &&
        send_refs_after_make == 1);
    bool send_refs_after_mod_plus_exact =
        (kr_send_refs_after_mod_plus == KERN_SUCCESS &&
        send_refs_after_mod_plus == 2);
    bool send_refs_after_deallocate_exact =
        (kr_send_refs_after_deallocate == KERN_SUCCESS &&
        send_refs_after_deallocate == 1);
    bool send_refs_after_mod_minus_zero =
        (kr_send_refs_after_mod_minus == KERN_SUCCESS &&
        send_refs_after_mod_minus == 0);
    bool receive_refs_final_exact = (kr_recv_refs_final == KERN_SUCCESS &&
        recv_refs_final == 1);

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
    } else if (!receive_refs_initial_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "initial receive refs were not exactly one";
    } else if (!send_refs_before_make_zero) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs before MACH_MSG_TYPE_MAKE_SEND were not zero";
    } else if (kr_insert_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_insert_right MAKE_SEND failed";
    } else if (!send_refs_after_make_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs after MAKE_SEND were not exactly one";
    } else if (kr_mod_refs_plus_one != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_mod_refs SEND +1 failed";
    } else if (!send_refs_after_mod_plus_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs after mod_refs +1 were not exactly two";
    } else if (kr_deallocate_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_deallocate send failed";
    } else if (!send_refs_after_deallocate_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs after deallocate were not exactly one";
    } else if (kr_mod_refs_minus_one != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_mod_refs SEND -1 failed";
    } else if (!send_refs_after_mod_minus_zero) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs after final SEND -1 were not zero";
    } else if (!receive_refs_final_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "final receive refs were not exactly one";
    } else if (kr_destroy_receive != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy receive failed";
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
        "macos_foundation_port_get_refs",
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
    nx_result_emit_return(&j, "mach_port_get_refs_receive_initial",
        nx_kern_return_str(kr_recv_refs_initial), kr_recv_refs_initial,
        false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_before_make",
        nx_kern_return_str(kr_send_refs_before_make),
        kr_send_refs_before_make, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_make_send",
        nx_kern_return_str(kr_insert_send), kr_insert_send, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_make",
        nx_kern_return_str(kr_send_refs_after_make),
        kr_send_refs_after_make, false, 0);
    nx_result_emit_return(&j, "mach_port_mod_refs_send_plus_one",
        nx_kern_return_str(kr_mod_refs_plus_one), kr_mod_refs_plus_one,
        false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_mod_plus",
        nx_kern_return_str(kr_send_refs_after_mod_plus),
        kr_send_refs_after_mod_plus, false, 0);
    nx_result_emit_return(&j, "mach_port_deallocate_send",
        nx_kern_return_str(kr_deallocate_send), kr_deallocate_send, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_deallocate",
        nx_kern_return_str(kr_send_refs_after_deallocate),
        kr_send_refs_after_deallocate, false, 0);
    nx_result_emit_return(&j, "mach_port_mod_refs_send_minus_one",
        nx_kern_return_str(kr_mod_refs_minus_one), kr_mod_refs_minus_one,
        false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_mod_minus",
        nx_kern_return_str(kr_send_refs_after_mod_minus),
        kr_send_refs_after_mod_minus, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_receive_final",
        nx_kern_return_str(kr_recv_refs_final), kr_recv_refs_final, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_receive",
        nx_kern_return_str(kr_destroy_receive), kr_destroy_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_result_emit_right_delta(&j,
        "allocate receive right",
        "port_get_refs_probe_port",
        "MACH_PORT_RIGHT_RECEIVE",
        -1,
        kr_recv_refs_initial == KERN_SUCCESS ? recv_refs_initial : -1,
        -1,
        -1,
        "receive urefs exactly 1");
    nx_result_emit_right_delta(&j,
        "make send right",
        "port_get_refs_probe_port",
        "MACH_PORT_RIGHT_SEND",
        -1,
        kr_send_refs_after_make == KERN_SUCCESS ? send_refs_after_make : -1,
        -1,
        -1,
        "send urefs exactly 1");
    nx_result_emit_right_delta(&j,
        "mach_port_mod_refs SEND +1",
        "port_get_refs_probe_port",
        "MACH_PORT_RIGHT_SEND",
        kr_send_refs_after_make == KERN_SUCCESS ? send_refs_after_make : -1,
        kr_send_refs_after_mod_plus == KERN_SUCCESS ?
            send_refs_after_mod_plus : -1,
        -1,
        -1,
        "incremented by 1");
    nx_result_emit_right_delta(&j,
        "mach_port_deallocate SEND",
        "port_get_refs_probe_port",
        "MACH_PORT_RIGHT_SEND",
        kr_send_refs_after_mod_plus == KERN_SUCCESS ?
            send_refs_after_mod_plus : -1,
        kr_send_refs_after_deallocate == KERN_SUCCESS ?
            send_refs_after_deallocate : -1,
        -1,
        -1,
        "decremented by 1");
    nx_result_emit_right_delta(&j,
        "mach_port_mod_refs SEND -1",
        "port_get_refs_probe_port",
        "MACH_PORT_RIGHT_SEND",
        kr_send_refs_after_deallocate == KERN_SUCCESS ?
            send_refs_after_deallocate : -1,
        kr_send_refs_after_mod_minus == KERN_SUCCESS ?
            send_refs_after_mod_minus : -1,
        -1,
        -1,
        "send urefs decremented to zero");
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_int(&j, "receive_refs_initial",
        kr_recv_refs_initial == KERN_SUCCESS ? recv_refs_initial : -1);
    nx_json_key_int(&j, "send_refs_before_make",
        kr_send_refs_before_make == KERN_SUCCESS ? send_refs_before_make : -1);
    nx_json_key_bool(&j, "send_refs_before_make_zero",
        send_refs_before_make_zero);
    nx_json_key_string(&j, "send_refs_before_make_return",
        nx_kern_return_str(kr_send_refs_before_make));
    nx_json_key_int(&j, "send_refs_after_make",
        kr_send_refs_after_make == KERN_SUCCESS ? send_refs_after_make : -1);
    nx_json_key_int(&j, "send_refs_after_mod_plus",
        kr_send_refs_after_mod_plus == KERN_SUCCESS ?
            send_refs_after_mod_plus : -1);
    nx_json_key_int(&j, "send_refs_after_deallocate",
        kr_send_refs_after_deallocate == KERN_SUCCESS ?
            send_refs_after_deallocate : -1);
    nx_json_key_int(&j, "send_refs_after_mod_minus",
        kr_send_refs_after_mod_minus == KERN_SUCCESS ?
            send_refs_after_mod_minus : -1);
    nx_json_key_bool(&j, "send_refs_after_mod_minus_zero",
        send_refs_after_mod_minus_zero);
    nx_json_key_string(&j, "send_refs_after_mod_minus_return",
        nx_kern_return_str(kr_send_refs_after_mod_minus));
    nx_json_key_int(&j, "receive_refs_final",
        kr_recv_refs_final == KERN_SUCCESS ? recv_refs_final : -1);
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
