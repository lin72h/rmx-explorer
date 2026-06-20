/*
 * task_info.c — Foundation task-introspection probe (block-080a #1).
 *
 * Test ID: macos_foundation_task_info
 *
 * Exercises mach_task_self() + task_info() against the current task:
 *   - mach_task_self() returns a valid, stable (cached) send right
 *   - the task-self port type is observed via mach_port_type()
 *   - task_info(MACH_TASK_BASIC_INFO) succeeds with the expected in/out count
 *     (MACH_TASK_BASIC_INFO_COUNT == 12). The modern flavor is used; the legacy
 *     TASK_BASIC_INFO flavors are deprecated in the SDK.
 *   - task_info(invalid flavor) is rejected (KERN_INVALID_ARGUMENT)
 *   - task_info(bogus/null task port) is rejected
 *
 * No port is allocated or destroyed, so the port-namespace baseline is
 * expected to be unchanged. Raw port names and the captured sizes/times are
 * emitted for provenance but are NOT comparison axes (per block-074 guidance);
 * suspend_count==0 for a running task is a portable invariant.
 *
 * Emits a complete nx-r64z.macos-oracle.v1 JSON result to stdout.
 */

#include <stdio.h>
#include <stdlib.h>

#include "nx_json.h"
#include "nx_result.h"
#include "nx_env.h"
#include "nx_mach_utils.h"

#ifdef __APPLE__
#include <mach/task_info.h>
#endif

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    /* Baseline before any introspection */
    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    mach_port_t      task_self_a   = MACH_PORT_NULL;
    mach_port_t      task_self_b   = MACH_PORT_NULL;
    mach_port_type_t ptype         = 0;
    kern_return_t    kr_type       = KERN_FAILURE;
    kern_return_t    kr_basic      = KERN_FAILURE;
    kern_return_t    kr_bad_flavor = KERN_FAILURE;
    kern_return_t    kr_null_task  = KERN_FAILURE;
    mach_msg_type_number_t basic_count = 0;
    mach_msg_type_number_t expected_basic_count = 0;

    /* mx-fidelity provenance fields (captured, not asserted). */
    long long suspend_count = -1;
    long long policy = -1;
    unsigned long long virtual_size = 0;
    unsigned long long resident_size = 0;
    long long user_time_seconds = -1;
    long long user_time_microseconds = -1;
    long long system_time_seconds = -1;
    long long system_time_microseconds = -1;

#ifdef __APPLE__
    task_self_a = mach_task_self();
    task_self_b = mach_task_self();

    kr_type = mach_port_type(task_self_a, task_self_a, &ptype);

    mach_task_basic_info_data_t basic_info;
    basic_count = MACH_TASK_BASIC_INFO_COUNT;
    expected_basic_count = MACH_TASK_BASIC_INFO_COUNT;
    kr_basic = task_info(task_self_a, MACH_TASK_BASIC_INFO,
                         (task_info_t)&basic_info, &basic_count);
    if (kr_basic == KERN_SUCCESS) {
        suspend_count = basic_info.suspend_count;
        policy = basic_info.policy;
        virtual_size = (unsigned long long)basic_info.virtual_size;
        resident_size = (unsigned long long)basic_info.resident_size;
        user_time_seconds = basic_info.user_time.seconds;
        user_time_microseconds = basic_info.user_time.microseconds;
        system_time_seconds = basic_info.system_time.seconds;
        system_time_microseconds = basic_info.system_time.microseconds;
    }

    mach_msg_type_number_t bad_count = MACH_TASK_BASIC_INFO_COUNT;
    kr_bad_flavor = task_info(task_self_a, (task_flavor_t)0xffffff,
                              (task_info_t)&basic_info, &bad_count);

    mach_msg_type_number_t null_count = MACH_TASK_BASIC_INFO_COUNT;
    kr_null_task = task_info(MACH_PORT_NULL, MACH_TASK_BASIC_INFO,
                             (task_info_t)&basic_info, &null_count);
#endif /* __APPLE__ */

#ifndef __APPLE__
    /* Stub values stay KERN_FAILURE on non-Apple; emitted for suite parity. */
#endif

    nx_baseline_capture(&after);
    int delta = 0;
    bool baseline_ok = nx_baseline_compare(&before, &after, &delta);

    bool count_exact = (kr_basic == KERN_SUCCESS &&
        basic_count == expected_basic_count);

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
    if (task_self_a == MACH_PORT_NULL) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_task_self() returned MACH_PORT_NULL";
    } else if (kr_type != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type on task-self failed";
    } else if (kr_basic != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "task_info(MACH_TASK_BASIC_INFO) failed";
    } else if (!count_exact) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "task_info out-count did not match MACH_TASK_BASIC_INFO_COUNT";
    } else if (kr_bad_flavor == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "task_info accepted an invalid flavor (expected KERN_INVALID_ARGUMENT)";
    } else if (kr_null_task == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "task_info accepted a null task port (expected failure)";
    } else if (!baseline_ok) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
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
        "macos_foundation_task_info",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    /* Returns */
    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_task_self",
        task_self_a == MACH_PORT_NULL ? "MACH_PORT_NULL" : "KERN_SUCCESS",
        (long long)task_self_a, false, 0);
    nx_result_emit_return(&j, "mach_port_type_task_self",
        nx_kern_return_str(kr_type), kr_type, false, 0);
    nx_result_emit_return(&j, "task_info_mach_task_basic_info",
        nx_kern_return_str(kr_basic), kr_basic, false, 0);
    nx_result_emit_return(&j, "task_info_invalid_flavor",
        nx_kern_return_str(kr_bad_flavor), kr_bad_flavor, false, 0);
    nx_result_emit_return(&j, "task_info_null_task",
        nx_kern_return_str(kr_null_task), kr_null_task, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    /* Right deltas — none manipulated */
    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    /* Observations */
    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "task_self_nonnull", task_self_a != MACH_PORT_NULL);
    nx_json_key_bool(&j, "task_self_stable_across_two_calls", task_self_a == task_self_b);
    nx_json_key_string(&j, "task_self_port_type",
        kr_type == KERN_SUCCESS ? nx_port_type_str(ptype) : "unknown");
    nx_json_key_bool(&j, "task_info_basic_succeeded", kr_basic == KERN_SUCCESS);
    nx_json_key_int(&j, "task_info_basic_count", (long long)basic_count);
    nx_json_key_bool(&j, "task_info_basic_count_exact", count_exact);
    nx_json_key_string(&j, "task_info_invalid_flavor_returned",
        nx_kern_return_str(kr_bad_flavor));
    nx_json_key_bool(&j, "task_info_invalid_flavor_rejected", kr_bad_flavor != KERN_SUCCESS);
    nx_json_key_bool(&j, "task_info_null_task_rejected", kr_null_task != KERN_SUCCESS);
    /* Provenance (non-comparison): captured values from MACH_TASK_BASIC_INFO. */
    nx_json_key_int(&j, "suspend_count", suspend_count);
    nx_json_key_bool(&j, "suspend_count_zero", suspend_count == 0);
    nx_json_key_int(&j, "policy", policy);
    nx_json_key_uint(&j, "virtual_size", virtual_size);
    nx_json_key_uint(&j, "resident_size", resident_size);
    nx_json_key_int(&j, "user_time_seconds", user_time_seconds);
    nx_json_key_int(&j, "user_time_microseconds", user_time_microseconds);
    nx_json_key_int(&j, "system_time_seconds", system_time_seconds);
    nx_json_key_int(&j, "system_time_microseconds", system_time_microseconds);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
