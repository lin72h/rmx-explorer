/*
 * absolute_time.c — Foundation time probe (block-080a #3).
 *
 * Test ID: macos_foundation_absolute_time
 *
 * Exercises mach_absolute_time() + mach_timebase_info():
 *   - mach_absolute_time() returns non-zero
 *   - successive reads are monotonic non-decreasing
 *   - mach_timebase_info() succeeds with positive numer and denom
 *
 * No port is involved; namespace baseline unchanged. Raw tick values and
 * the numer/denom ratio are arch/hardware-specific and NOT comparison axes
 * (arm64 macOS reports 125/3, x86_64 reports 1/1); only the invariants are.
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

    unsigned long long t1 = 0, t2 = 0;
    kern_return_t kr_tb = KERN_FAILURE;
    int numer = 0, denom = 0;

#ifdef __APPLE__
    t1 = mach_absolute_time();
    t2 = mach_absolute_time();

    mach_timebase_info_data_t tbi;
    kr_tb = mach_timebase_info(&tbi);
    if (kr_tb == KERN_SUCCESS) {
        numer = (int)tbi.numer;
        denom = (int)tbi.denom;
    }
#endif /* __APPLE__ */

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
    if (t1 == 0) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_absolute_time() returned 0";
    } else if (t2 < t1) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_absolute_time() went backwards (non-monotonic)";
    } else if (kr_tb != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_timebase_info() failed";
    } else if (numer <= 0 || denom <= 0) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_timebase_info() returned non-positive numer/denom";
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
        "macos_foundation_absolute_time",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_absolute_time_first",
        t1 == 0 ? "ZERO" : "KERN_SUCCESS", (long long)t1, false, 0);
    nx_result_emit_return(&j, "mach_absolute_time_second",
        t2 == 0 ? "ZERO" : "KERN_SUCCESS", (long long)t2, false, 0);
    nx_result_emit_return(&j, "mach_timebase_info",
        nx_kern_return_str(kr_tb), kr_tb, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "absolute_time_nonzero", t1 != 0);
    nx_json_key_bool(&j, "absolute_time_monotonic_nondecreasing", t2 >= t1);
    nx_json_key_bool(&j, "timebase_info_succeeded", kr_tb == KERN_SUCCESS);
    nx_json_key_bool(&j, "timebase_numer_positive", kr_tb == KERN_SUCCESS && numer > 0);
    nx_json_key_bool(&j, "timebase_denom_positive", kr_tb == KERN_SUCCESS && denom > 0);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
