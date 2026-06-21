/*
 * dispatch_global_queue_service.c — Dispatch global-queue servicing probe (op-082 #1).
 *
 * Test ID: macos_dispatch_global_queue_service
 *
 * Captures macOS-27 ground truth for dispatch_async_f servicing on the global
 * concurrent queue (the #1 / TWQ-worker-pool target):
 *   - dispatch_group_async_f N work blocks to dispatch_get_global_queue()
 *   - dispatch_group_wait(FOREVER) -> all N complete
 *   - an atomic completion counter == N (no lost updates, no abort/hang)
 *
 * Worker counts, completion ordering, and elapsed time are NON-DETERMINISTIC —
 * captured, never asserted. The macOS-observable kernel-workqueue analog of
 * rmxOS's kern.twq.threads_created is the process thread-count delta across the
 * batch (captured via task_threads under __APPLE__); the rx half captures
 * kern.twq.threads_created directly.
 *
 * Pure libdispatch: guarded on dispatch availability (__has_include), NOT on
 * __APPLE__, so it runs on any host with libdispatch (macOS + rmxOS guest).
 *
 * Emits an nx-r64z.macos-oracle.v1 JSON result to stdout.
 */

#include <stdio.h>
#include <stdlib.h>

#include "nx_json.h"
#include "nx_result.h"
#include "nx_env.h"
#include "nx_mach_utils.h"

#if __has_include(<dispatch/dispatch.h>)
#define NX_HAVE_DISPATCH 1
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <sys/sysctl.h>   /* kern.twq.threads_created (rmxOS distinguishing signal) */
#else
#define NX_HAVE_DISPATCH 0
#endif

#if NX_HAVE_DISPATCH
/* kern.twq.threads_created: rmxOS kernel-TWQ counter (absent on macOS). Returns
 * -1 when the sysctl is absent so the macOS vector stays byte-identical. */
static long long
read_kern_twq_threads_created(void)
{
    long long val = 0;
    size_t    sz  = sizeof(val);
    if (sysctlbyname("kern.twq.threads_created", &val, &sz, NULL, 0) != 0) {
        return -1;
    }
    return val;
}
#endif

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_time.h>
/* kern.twq.threads_created is rmxOS-specific (absent on macOS); the macOS
 * observable analog is the process thread-count delta across the batch. */
static long long
current_thread_count(void)
{
    thread_act_array_t      threads = NULL;
    mach_msg_type_number_t  count   = 0;
    kern_return_t           kr = task_threads(mach_task_self(), &threads, &count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (threads && count > 0) {
        vm_deallocate(mach_task_self(), (vm_address_t)threads,
            (vm_size_t)(count * sizeof(thread_act_t)));
    }
    return (long long)count;
}
#endif

#define DGQS_N 64

static void
dgqs_work(void *counterptr)
{
    atomic_int *c = (atomic_int *)counterptr;
    atomic_fetch_add_explicit(c, 1, memory_order_relaxed);
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    int       ran = 0;          /* NX_HAVE_DISPATCH path taken */
    long long completed = -1;
    long long wait_kr = (long long)-1;
    long long threads_before = -1;
    long long threads_after = -1;
    long long threads_delta = -1;
    long long twq_before = -1;
    long long twq_after = -1;
    long long twq_delta = -1;
    unsigned long long elapsed_ns = 0;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#if NX_HAVE_DISPATCH
    ran = 1;
    atomic_int counter;
    atomic_init(&counter, 0);

    twq_before = read_kern_twq_threads_created();

#ifdef __APPLE__
    threads_before = current_thread_count();
    mach_timebase_info_data_t tbi;
    mach_timebase_info(&tbi);
    uint64_t t0 = mach_absolute_time();
#endif

    dispatch_queue_t gq = dispatch_get_global_queue(
        DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t grp = dispatch_group_create();

    for (int i = 0; i < DGQS_N; i++) {
        dispatch_group_async_f(grp, gq, &counter, dgqs_work);
    }
    wait_kr = (long long)dispatch_group_wait(grp, DISPATCH_TIME_FOREVER);
    completed = (long long)atomic_load(&counter);

    twq_after = read_kern_twq_threads_created();
    if (twq_before >= 0 && twq_after >= 0) {
        twq_delta = twq_after - twq_before;
    }

#ifdef __APPLE__
    uint64_t t1 = mach_absolute_time();
    if (tbi.denom != 0) {
        elapsed_ns = (unsigned long long)
            ((t1 - t0) * (uint64_t)tbi.numer / (uint64_t)tbi.denom);
    }
    threads_after = current_thread_count();
    if (threads_before >= 0 && threads_after >= 0) {
        threads_delta = threads_after - threads_before;
    }
#endif

    if (grp != NULL) {
        dispatch_release(grp);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#endif

    nx_status_t status = NX_STATUS_PASS;
    nx_semantic_class_t sclass = NX_CLASS_EXACT_CONTRACT;
    const char *notes = "";
    const char *cleanup_notes = cleanup_ok ? "" : "libdispatch leaves internal Mach ports (delta captured, non-gating)";

#if !NX_HAVE_DISPATCH
    status = NX_STATUS_SKIP;
    sclass = NX_CLASS_NOT_OBSERVABLE;
    notes = "host without libdispatch: global-queue servicing not available";
    cleanup_ok = true;
    cleanup_notes = "not applicable on this host";
#else
    if (wait_kr != 0) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "dispatch_group_wait did not return 0 (all-complete) within FOREVER";
    } else if (completed != (long long)DGQS_N) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "not all dispatched blocks completed (counter != N)";
    }
    /* libdispatch leaves internal Mach ports in the namespace; the port-
     * namespace baseline is NOT a contract for dispatch probes (delta captured). */
#endif

    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j, agent, "macos_dispatch_global_queue_service",
        NULL, NULL, status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "dispatch_group_wait",
        (wait_kr == 0 ? "0=all_complete" : (wait_kr < 0 ? "n/a" : "nonzero")),
        wait_kr, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_int(&j, "dispatched_block_count", DGQS_N);
    nx_json_key_bool(&j, "dispatch_available", ran);
    nx_json_key_bool(&j, "all_blocks_completed",
        (completed == (long long)DGQS_N));
    nx_json_key_int(&j, "completed_block_count", completed);
    /* Non-deterministic (capture-not-assert): worker-pool / timing. */
    nx_json_key_int(&j, "threads_before", threads_before);
    nx_json_key_int(&j, "threads_after", threads_after);
    nx_json_key_int(&j, "threads_delta", threads_delta);
    nx_json_key_uint(&j, "elapsed_ns", elapsed_ns);
    nx_json_key_string(&j, "kwq_signal_note",
        "kern.twq.threads_created is rmxOS-specific (absent on macOS); "
        "threads_delta is the macOS kernel-workqueue analog");
    /* kern.twq.threads_created: emitted ONLY when the sysctl is present (rmxOS).
     * Absent on macOS -> not emitted -> macOS vector byte-identical to op-082. */
    if (twq_before >= 0) {
        nx_json_key_int(&j, "kern_twq_threads_created_before", twq_before);
        nx_json_key_int(&j, "kern_twq_threads_created_after", twq_after);
        nx_json_key_int(&j, "kern_twq_threads_created_delta", twq_delta);
    }
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
