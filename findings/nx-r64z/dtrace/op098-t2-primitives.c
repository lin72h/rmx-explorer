/* op-098 Task 2 — primitive-surface coverage + bl-004 non-NORMAL QoS timer.
 * Stdout "name: PASS|FAIL <detail>" per test. Built against alpha libdispatch. */
#include <stdio.h>
#include <stdlib.h>
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <mach/mach.h>

/* file-scope so blocks don't capture-by-const (atomic_store needs non-const ptr) */
static _Atomic int g_flag;
static void cb_set(void *ctx) { atomic_store((_Atomic int*)ctx, 1); }
static void cb_add(void *ctx, size_t i) { (void)i; (*(int*)ctx)++; }
#define R(name, ok, det) printf("%s: %s %s\n", (name), (ok)?"PASS":"FAIL", (det)?(det):"")

int main(void) {
    dispatch_queue_t q = dispatch_queue_create("nx.t2", DISPATCH_QUEUE_SERIAL);
    int fails = 0;

    atomic_store(&g_flag, 0);
    dispatch_async(q, ^{ atomic_store(&g_flag, 1); });
    dispatch_sync(q, ^{});
    R("dispatch_async", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);

    atomic_store(&g_flag, 0);
    dispatch_async_f(q, &g_flag, cb_set);
    dispatch_sync(q, ^{});
    R("dispatch_async_f", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);

    atomic_store(&g_flag, 0);
    dispatch_sync(q, ^{ atomic_store(&g_flag, 1); });
    R("dispatch_sync", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);

    atomic_store(&g_flag, 0);
    dispatch_sync_f(q, &g_flag, cb_set);
    R("dispatch_sync_f", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);

    { int iv = 0;
      dispatch_apply_f(8, dispatch_get_global_queue(0,0), &iv, cb_add);
      R("dispatch_apply_f(8)", iv == 8, iv==8?"":"(count)"); fails += (iv!=8); }
    { __block int n = 0;
      dispatch_apply(8, q, ^(size_t i){ (void)i; n++; });
      R("dispatch_apply(8)", n == 8, n==8?"":"(count)"); fails += (n!=8); }

    { static dispatch_once_t pred; static int on = 0;
      dispatch_once(&pred, ^{ on++; }); dispatch_once(&pred, ^{ on++; });
      R("dispatch_once", on == 1, ""); fails += (on!=1); }
    { static dispatch_once_t pred; int ov = 0;
      dispatch_once_f(&pred, &ov, cb_add); dispatch_once_f(&pred, &ov, cb_add);
      R("dispatch_once_f", ov == 1, ""); fails += (ov!=1); }

    { dispatch_queue_t cq = dispatch_queue_create("nx.t2c", DISPATCH_QUEUE_CONCURRENT);
      atomic_store(&g_flag, 0);
      dispatch_barrier_async(cq, ^{ atomic_store(&g_flag, 1); });
      dispatch_barrier_sync(cq, ^{});
      R("dispatch_barrier_async", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);
      atomic_store(&g_flag, 0);
      dispatch_barrier_sync(cq, ^{ atomic_store(&g_flag, 1); });
      R("dispatch_barrier_sync", atomic_load(&g_flag), ""); fails += !atomic_load(&g_flag);
      dispatch_release(cq); }

    /* Timer helper: arm a timer source on `tq` at +150ms, signal a semaphore from
     * the handler; wait up to 1s. fired==0 return => timer delivered. */
    #define TIMER_TEST(label, tq) do { \
        dispatch_semaphore_t _s = dispatch_semaphore_create(0); \
        dispatch_source_t _t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, (tq)); \
        dispatch_source_set_timer(_t, dispatch_time(DISPATCH_TIME_NOW, 150*1000000LL), DISPATCH_TIME_FOREVER, 0); \
        dispatch_source_set_event_handler(_t, ^{ dispatch_semaphore_signal(_s); }); \
        dispatch_resume(_t); \
        long _r = dispatch_semaphore_wait(_s, dispatch_time(DISPATCH_TIME_NOW, 1000*1000000LL)); \
        R(label, _r == 0, _r==0?"(fired)":"(NO fire)"); fails += (_r != 0); \
        dispatch_release(_t); dispatch_release(_s); } while(0)

    TIMER_TEST("timer_QOS_NORMAL", q);
    /* bl-004: route through HIGH/LOW global queues to hit CRITICAL/BACKGROUND slots
     * (NOTE_CRITICAL/NOTE_BACKGROUND fflags). filt_timervalidate accepts only
     * NOTE_TIMER_PRECMASK|NOTE_ABSTIME (kern_event.c:914) -> these get EINVAL -> no arm -> no fire. */
    { dispatch_queue_t hq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
      TIMER_TEST("timer_QOS_HIGH(CRITICAL)", hq); }
    { dispatch_queue_t lq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
      TIMER_TEST("timer_QOS_LOW(BACKGROUND)", lq); }

    printf("op098_t2_fails=%d\n", fails);
    printf("op098_t2_terminal status=0\n");
    return 0;
}
