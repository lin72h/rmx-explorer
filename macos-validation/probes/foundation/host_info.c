/*
 * host_info.c — Foundation host-introspection probe (block-080a #2).
 *
 * Test ID: macos_foundation_host_info
 *
 * Exercises mach_host_self() + host_info() against the host port:
 *   - mach_host_self() returns a valid, stable (cached) send right
 *   - host_info(HOST_BASIC_INFO) succeeds with the expected in/out count
 *   - host_info(invalid flavor) is rejected
 *   - host_info(bogus/null host port) is rejected
 *
 * No port is allocated or destroyed, so the port-namespace baseline is
 * expected to be unchanged. Raw port names are emitted for provenance but
 * are NOT a comparison axis (per block-074 guidance).
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

    mach_port_t           host_self_a   = MACH_PORT_NULL;
    mach_port_t           host_self_b   = MACH_PORT_NULL;
    kern_return_t         kr_basic      = KERN_FAILURE;
    kern_return_t         kr_bad_flavor = KERN_FAILURE;
    kern_return_t         kr_null_host  = KERN_FAILURE;
    kern_return_t         kr_dealloc_a  = KERN_FAILURE;
    kern_return_t         kr_dealloc_b  = KERN_FAILURE;
    mach_msg_type_number_t basic_count  = 0;
    /* Arch-divergent host topology (capture-not-assert; differs arm64 vs x86_64). */
    long long             max_cpus      = 0;
    long long             avail_cpus    = 0;
    long long             cpu_type      = 0;
    long long             cpu_subtype   = 0;
    long long             cpu_threadtype = 0;
    long long             physical_cpu  = 0;
    long long             physical_cpu_max = 0;
    long long             logical_cpu   = 0;
    long long             logical_cpu_max  = 0;
    unsigned long long    memory_size   = 0;
    unsigned long long    max_mem       = 0;

#ifdef __APPLE__
    host_self_a = mach_host_self();
    host_self_b = mach_host_self();

    host_basic_info_data_t basic;
    basic_count = HOST_BASIC_INFO_COUNT;
    kr_basic = host_info(host_self_a, HOST_BASIC_INFO,
                         (host_info_t)&basic, &basic_count);
    if (kr_basic == KERN_SUCCESS) {
        max_cpus         = basic.max_cpus;
        avail_cpus       = basic.avail_cpus;
        cpu_type         = basic.cpu_type;
        cpu_subtype      = basic.cpu_subtype;
        cpu_threadtype   = basic.cpu_threadtype;
        physical_cpu     = basic.physical_cpu;
        physical_cpu_max = basic.physical_cpu_max;
        logical_cpu      = basic.logical_cpu;
        logical_cpu_max  = basic.logical_cpu_max;
        memory_size      = (unsigned long long)basic.memory_size;
        max_mem          = (unsigned long long)basic.max_mem;
    }

    mach_msg_type_number_t bad_count = HOST_BASIC_INFO_COUNT;
    kr_bad_flavor = host_info(host_self_a, (host_flavor_t)0xffffff,
                              (host_info_t)&basic, &bad_count);

    mach_msg_type_number_t null_count = HOST_BASIC_INFO_COUNT;
    kr_null_host = host_info(MACH_PORT_NULL, HOST_BASIC_INFO,
                             (host_info_t)&basic, &null_count);

    /* Balance the send rights acquired by the two mach_host_self() calls so the
     * port namespace returns to baseline. mach_host_self() grants a send right
     * each call (same name); without these deallocate()s the host port name
     * leaks and cleanup-to-baseline fails. */
    kr_dealloc_a = mach_port_deallocate(mach_task_self(), host_self_a);
    kr_dealloc_b = mach_port_deallocate(mach_task_self(), host_self_b);
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
    if (host_self_a == MACH_PORT_NULL) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_host_self() returned MACH_PORT_NULL";
    } else if (kr_basic != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "host_info(HOST_BASIC_INFO) failed";
    } else if (kr_bad_flavor == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "host_info accepted an invalid flavor (expected rejection)";
    } else if (kr_null_host == KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "host_info accepted a null host port (expected failure)";
    } else if (kr_dealloc_a != KERN_SUCCESS || kr_dealloc_b != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_deallocate of host port failed";
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
        "macos_foundation_host_info",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_host_self",
        host_self_a == MACH_PORT_NULL ? "MACH_PORT_NULL" : "KERN_SUCCESS",
        (long long)host_self_a, false, 0);
    nx_result_emit_return(&j, "host_info_basic",
        nx_kern_return_str(kr_basic), kr_basic, false, 0);
    nx_result_emit_return(&j, "host_info_invalid_flavor",
        nx_kern_return_str(kr_bad_flavor), kr_bad_flavor, false, 0);
    nx_result_emit_return(&j, "host_info_null_host",
        nx_kern_return_str(kr_null_host), kr_null_host, false, 0);
    nx_result_emit_return(&j, "mach_port_deallocate_host_a",
        nx_kern_return_str(kr_dealloc_a), kr_dealloc_a, false, 0);
    nx_result_emit_return(&j, "mach_port_deallocate_host_b",
        nx_kern_return_str(kr_dealloc_b), kr_dealloc_b, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "host_self_nonnull", host_self_a != MACH_PORT_NULL);
    nx_json_key_bool(&j, "host_self_stable_across_two_calls", host_self_a == host_self_b);
    nx_json_key_bool(&j, "host_info_basic_succeeded", kr_basic == KERN_SUCCESS);
    nx_json_key_int(&j, "host_info_basic_count", (long long)basic_count);
    /* max_cpus is environment-specific; only its positivity is a contract invariant. */
    nx_json_key_bool(&j, "host_info_basic_max_cpus_positive",
        kr_basic == KERN_SUCCESS && max_cpus > 0);
    /* Arch-divergent topology (capture-not-assert; expected-divergence on rx-x64z). */
    nx_json_key_int(&j, "host_info_max_cpus", max_cpus);
    nx_json_key_int(&j, "host_info_avail_cpus", avail_cpus);
    nx_json_key_int(&j, "host_info_cpu_type", cpu_type);
    nx_json_key_int(&j, "host_info_cpu_subtype", cpu_subtype);
    nx_json_key_int(&j, "host_info_cpu_threadtype", cpu_threadtype);
    nx_json_key_int(&j, "host_info_physical_cpu", physical_cpu);
    nx_json_key_int(&j, "host_info_physical_cpu_max", physical_cpu_max);
    nx_json_key_int(&j, "host_info_logical_cpu", logical_cpu);
    nx_json_key_int(&j, "host_info_logical_cpu_max", logical_cpu_max);
    nx_json_key_uint(&j, "host_info_memory_size", memory_size);
    nx_json_key_uint(&j, "host_info_max_mem", max_mem);
    nx_json_key_bool(&j, "host_info_invalid_flavor_rejected", kr_bad_flavor != KERN_SUCCESS);
    nx_json_key_bool(&j, "host_info_null_host_rejected", kr_null_host != KERN_SUCCESS);
    nx_json_key_bool(&j, "host_port_dealloc_succeeded",
        kr_dealloc_a == KERN_SUCCESS && kr_dealloc_b == KERN_SUCCESS);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
