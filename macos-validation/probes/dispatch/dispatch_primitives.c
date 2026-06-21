/*
 * dispatch_primitives.c — Dispatch primitives probe (op-082 #3).
 *
 * Test ID: macos_dispatch_primitives
 *
 * Captures macOS-27 ground truth for three dispatch primitives:
 *   - group enter/leave/wait: dispatch_async_f work that dispatch_group_leave()s;
 *     dispatch_group_wait() returns 0 (the group balances).
 *   - semaphore: an unsignaled wait times out; after signal, wait succeeds (0).
 *   - dispatch_after_f: a handler scheduled for NOW+delay fires within a bound.
 *
 * Ordering and timing are NON-DETERMINISTIC — captured, not asserted. Only the
 * per-primitive completion invariants are asserted. Pure libdispatch: guarded
 * on dispatch availability (__has_include), so it runs on any host with
 * libdispatch (macOS + rmxOS guest).
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
#else
#define NX_HAVE_DISPATCH 0
#endif

#define DP_AFTER_DELAY_NS  (20LL * 1000 * 1000)   /* 20 ms */
#define DP_WAIT_BOUND_NS   (2LL * 1000 * 1000 * 1000)  /* 2 s */

#if NX_HAVE_DISPATCH
typedef struct {
    dispatch_group_t   g;
    atomic_int        *count;
} dp_group_ctx_t;

static void
dp_group_work(void *ctxptr)
{
    dp_group_ctx_t *c = (dp_group_ctx_t *)ctxptr;
    atomic_fetch_add_explicit(c->count, 1, memory_order_relaxed);
    dispatch_group_leave(c->g);
}

typedef struct {
    atomic_int        *fired;
    dispatch_semaphore_t sem;
} dp_after_ctx_t;

static void
dp_after_work(void *ctxptr)
{
    dp_after_ctx_t *c = (dp_after_ctx_t *)ctxptr;
    atomic_store(c->fired, 1);
    dispatch_semaphore_signal(c->sem);
}
#endif

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    int       ran = 0;
    bool      group_ok = false;
    long long group_count = -1;
    bool      sem_timeout_observed = false;
    bool      sem_signal_wait_ok = false;
    bool      after_fired = false;
    int       cleanup_delta = 0;
    bool      cleanup_ok = false;

#if NX_HAVE_DISPATCH
    ran = 1;
    dispatch_queue_t q = dispatch_queue_create("nx.dprim", DISPATCH_QUEUE_SERIAL);

    /* --- group enter/leave/wait --- */
    atomic_int gcount;
    atomic_init(&gcount, 0);
    dispatch_group_t g = dispatch_group_create();
    if (g != NULL) {
        dp_group_ctx_t gctx = { g, &gcount };
        dispatch_group_enter(g);
        dispatch_async_f(q, &gctx, dp_group_work);
        long long gw = (long long)dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
        group_count = (long long)atomic_load(&gcount);
        group_ok = (gw == 0 && group_count == 1);
        dispatch_release(g);
    }

    /* --- semaphore: an unsignaled wait times out; after signal, wait succeeds. --- */
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if (sem != NULL) {
        long long w_timeout = (long long)dispatch_semaphore_wait(sem,
            dispatch_time(DISPATCH_TIME_NOW, 50LL * 1000 * 1000)); /* 50 ms */
        sem_timeout_observed = (w_timeout != 0);
        dispatch_semaphore_signal(sem);
        long long w_second = (long long)dispatch_semaphore_wait(sem,
            dispatch_time(DISPATCH_TIME_NOW, DP_WAIT_BOUND_NS));
        sem_signal_wait_ok = (w_second == 0);
    }

    /* --- dispatch_after_f --- */
    atomic_int afired;
    atomic_init(&afired, 0);
    dispatch_semaphore_t asem = dispatch_semaphore_create(0);
    if (asem != NULL && q != NULL) {
        dp_after_ctx_t actx = { &afired, asem };
        dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, DP_AFTER_DELAY_NS),
            q, &actx, dp_after_work);
        long long aw = (long long)dispatch_semaphore_wait(asem,
            dispatch_time(DISPATCH_TIME_NOW, DP_WAIT_BOUND_NS));
        after_fired = (aw == 0 && atomic_load(&afired) == 1);
        dispatch_release(asem);
    }
    if (sem != NULL) {
        dispatch_release(sem);
    }
    if (q != NULL) {
        dispatch_release(q);
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
    notes = "host without libdispatch: primitives not available";
    cleanup_ok = true;
    cleanup_notes = "not applicable on this host";
#else
    if (!group_ok) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "group enter/leave/wait did not balance + run the work";
    } else if (!sem_timeout_observed || !sem_signal_wait_ok) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "semaphore did not time out when unsignaled, then succeed after signal";
    } else if (!after_fired) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "dispatch_after_f handler did not fire within the bound";
    }
    /* libdispatch leaves internal Mach ports in the namespace; the port-
     * namespace baseline is NOT a contract for dispatch probes (delta captured). */
#endif

    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j, agent, "macos_dispatch_primitives",
        NULL, NULL, status, sclass);

    nx_env_emit(&j);
    nx_result_emit_empty_message(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "dispatch_available", ran);
    nx_json_key_bool(&j, "group_enter_leave_wait_ok", group_ok);
    nx_json_key_int(&j, "group_work_count", group_count);
    nx_json_key_bool(&j, "semaphore_timeout_observed", sem_timeout_observed);
    nx_json_key_bool(&j, "semaphore_signal_then_wait_ok", sem_signal_wait_ok);
    nx_json_key_bool(&j, "dispatch_after_fired", after_fired);
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
