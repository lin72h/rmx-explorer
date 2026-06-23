/* op-102 libdispatch runtime-conformance harness.
 * Core subset: async/_f, sync/_f, apply/_f, once/_f, barrier_async/sync,
 * group (enter/leave/wait), semaphore (signal/wait/timeout), source-timer (NORMAL),
 * source-MACH_RECV. Emits structured "name: block=PASS|FAIL f=PASS|FAIL" lines for
 * conformance diffing. Built against alpha 129ee3c libdispatch. */
#include <stdio.h>
#include <string.h>
#include <dispatch/dispatch.h>
#include <stdatomic.h>
#include <mach/mach.h>

static _Atomic int g_flag;
static void cb_set(void *c) { atomic_store((_Atomic int*)c, 1); }
static void _sem_handler(void *c) { dispatch_semaphore_signal((dispatch_semaphore_t)c); }
static void cb_add(void *c, size_t i) { (void)i; (*(int*)c)++; }
static void cb_once(void *c) { (*(int*)c)++; }  /* dispatch_function_t (1-arg) for dispatch_once_f */
static int g_fails = 0;
#define R(name, val) printf("%s: %s\n", name, (val)?"PASS":"FAIL"); g_fails += !(val)
#define R2(name, bv, fv) printf("%s: block=%s f=%s\n", name, (bv)?"PASS":"FAIL", (fv)?"PASS":"FAIL"); g_fails += !(bv) + !(fv)

int main(void) {
    dispatch_queue_t q = dispatch_queue_create("op102", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t cq = dispatch_queue_create("op102c", DISPATCH_QUEUE_CONCURRENT);
    dispatch_semaphore_t sem;
    long wr;

    /* async + async_f */
    atomic_store(&g_flag,0); dispatch_async(q,^{atomic_store(&g_flag,1);}); dispatch_sync(q,^{});
    int ab = atomic_load(&g_flag);
    atomic_store(&g_flag,0); dispatch_async_f(q,&g_flag,cb_set); dispatch_sync(q,^{});
    R2("async", ab, atomic_load(&g_flag));

    /* sync + sync_f */
    atomic_store(&g_flag,0); dispatch_sync(q,^{atomic_store(&g_flag,1);});
    int sb = atomic_load(&g_flag);
    atomic_store(&g_flag,0); dispatch_sync_f(q,&g_flag,cb_set);
    R2("sync", sb, atomic_load(&g_flag));

    /* apply + apply_f */
    { __block int n=0; dispatch_apply(8,q,^(size_t i){(void)i;n++;}); int bv=(n==8);
      int iv=0; dispatch_apply_f(8,q,&iv,cb_add); int fv=(iv==8);
      R2("apply", bv, fv); }

    /* once + once_f */
    { static dispatch_once_t p1; static int o1=0;
      dispatch_once(&p1,^{o1++;}); dispatch_once(&p1,^{o1++;}); int bv=(o1==1);
      static dispatch_once_t p2; int o2=0;
      dispatch_once_f(&p2,&o2,cb_once); dispatch_once_f(&p2,&o2,cb_once); int fv=(o2==1);
      R2("once", bv, fv); }

    /* barrier_async + barrier_sync */
    atomic_store(&g_flag,0); dispatch_barrier_async(cq,^{atomic_store(&g_flag,1);});
    dispatch_barrier_sync(cq,^{}); int bab=atomic_load(&g_flag);
    atomic_store(&g_flag,0); dispatch_barrier_sync(cq,^{atomic_store(&g_flag,1);});
    R2("barrier", bab, atomic_load(&g_flag));

    /* group: enter/leave/wait */
    { dispatch_group_t grp = dispatch_group_create();
      atomic_store(&g_flag,0);
      dispatch_group_enter(grp);
      dispatch_async(q,^{ atomic_store(&g_flag,1); dispatch_group_leave(grp); });
      wr = dispatch_group_wait(grp, dispatch_time(DISPATCH_TIME_NOW, 500*1000000));
      int gv = (wr == 0 && atomic_load(&g_flag));
      /* group notify */
      dispatch_group_enter(grp);
      atomic_store(&g_flag,0);
      dispatch_group_notify(grp, q,^{ atomic_store(&g_flag,1); });
      dispatch_group_leave(grp);
      dispatch_sync(q,^{}); /* drain */
      int gn = atomic_load(&g_flag);
      R2("group", gv, gn);
      dispatch_release(grp); }

    /* semaphore: signal/wait/timeout */
    { sem = dispatch_semaphore_create(0);
      dispatch_semaphore_signal(sem);
      int sw = (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 100*1000000)) == 0);
      int to = (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 100*1000000)) != 0);
      R2("semaphore", sw, to); /* block=signal+wait ok; f=timeout observed */
      dispatch_release(sem); }

    /* source-timer NORMAL QoS */
    { sem = dispatch_semaphore_create(0);
      dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
      dispatch_source_set_timer(t, dispatch_time(DISPATCH_TIME_NOW, 150*1000000LL), DISPATCH_TIME_FOREVER, 0);
      dispatch_source_set_event_handler(t, ^{ dispatch_semaphore_signal(sem); });
      dispatch_resume(t);
      int tv = (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 1000*1000000)) == 0);
      R("source-timer(NORMAL)", tv);
      dispatch_release(t); dispatch_release(sem); }

    /* source-MACH_RECV */
    { mach_port_t port = MACH_PORT_NULL;
      kern_return_t kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
      int mv = 0;
      if (kr == KERN_SUCCESS) {
        sem = dispatch_semaphore_create(0);
        dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, (uintptr_t)port, 0, q);
        if (s) {
          dispatch_set_context(s, sem);
          dispatch_source_set_event_handler_f(s, _sem_handler);
          /* send a msg to fire the source */
          dispatch_resume(s);
          struct { mach_msg_header_t h; } msg;
          memset(&msg,0,sizeof(msg));
          msg.h.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
          msg.h.msgh_size = sizeof(msg);
          msg.h.msgh_remote_port = port;
          msg.h.msgh_id = 0x4f5032;
          kr = mach_msg(&msg.h, MACH_SEND_MSG, sizeof(msg), 0, MACH_PORT_NULL, 100, MACH_PORT_NULL);
          if (kr == KERN_SUCCESS)
            mv = (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 1000*1000000)) == 0);
          dispatch_release(s);
        }
        dispatch_release(sem);
        mach_port_destroy(mach_task_self(), port);
      }
      R("source-MACH_RECV", mv); }

    printf("op102_matrix_fails=%d\n", g_fails);
    printf("op102_matrix_terminal status=0\n");
    return 0;
}
