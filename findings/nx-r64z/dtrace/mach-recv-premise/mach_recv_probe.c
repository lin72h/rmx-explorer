/* op-241 MACH_RECV premise probe — single-message round-trip.
 * Creates a Mach port, registers a DISPATCH_SOURCE_TYPE_MACH_RECV source,
 * sends a Mach message, checks if the handler fires.
 *
 * If handler fires + mach_msg_receive succeeds → MACH_RECV is NOT dark.
 * If handler never fires → MACH_RECV IS dark (pool-fallback or no servicing).
 *
 * Build host-cross: cc -fblocks -D__APPLE__ -I rmxOS -I rmxOS/include -I rmxOS/sys \
 *   -L obj_root/lib/libdispatch -L obj_root/lib/libmach -L obj_root/lib/libBlocksRuntime \
 *   -o mach_recv_probe mach_recv_probe.c -ldispatch -lmach -lBlocksRuntime -lpthread
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/message.h>

#ifndef __OSX_AVAILABLE_BUT_DEPRECATED
#define __OSX_AVAILABLE_BUT_DEPRECATED(...)
#endif
#ifndef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(...)
#endif

/* Simple Mach message struct */
typedef struct {
    mach_msg_header_t header;
} simple_msg_t;

static volatile int handler_fired = 0;
static mach_msg_return_t handler_recv_kr = 0;

int main(void) {
    kern_return_t kr;
    mach_port_t recv_port = MACH_PORT_NULL;
    mach_port_t send_port = MACH_PORT_NULL;

    /* Step 1: Create a receive right */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &recv_port);
    if (kr != KERN_SUCCESS) {
        printf("{\"test\":\"mach_recv\",\"result\":\"FAIL\",\"stage\":\"port_allocate\",\"kr\":%d}\n", kr);
        return 1;
    }
    printf("{\"test\":\"mach_recv\",\"stage\":\"port_allocated\",\"port\":%u}\n", recv_port);

    /* Insert a send right so we can send to ourselves */
    kr = mach_port_insert_right(mach_task_self(), recv_port, recv_port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        printf("{\"test\":\"mach_recv\",\"result\":\"FAIL\",\"stage\":\"insert_send\",\"kr\":%d}\n", kr);
        return 1;
    }

    /* Step 2: Create a DISPATCH_SOURCE_TYPE_MACH_RECV source */
    dispatch_source_t src = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_MACH_RECV,
        (uintptr_t)recv_port,
        0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

    if (src == NULL) {
        printf("{\"test\":\"mach_recv\",\"result\":\"FAIL\",\"stage\":\"source_create\",\"reason\":\"NULL source\"}\n");
        return 1;
    }
    printf("{\"test\":\"mach_recv\",\"stage\":\"source_created\"}\n");

    /* Step 3: Set the event handler */
    dispatch_source_set_event_handler(src, ^{
        handler_fired = 1;

        /* Receive the Mach message inside the handler */
        simple_msg_t rcv_msg;
        memset(&rcv_msg, 0, sizeof(rcv_msg));
        handler_recv_kr = mach_msg(
            &rcv_msg.header,
            MACH_RCV_MSG,
            0,
            sizeof(rcv_msg),
            recv_port,
            0,          /* no timeout */
            MACH_PORT_NULL);

        printf("{\"test\":\"mach_recv\",\"stage\":\"handler_fired\",\"mach_msg_rcv_kr\":%d}\n",
               handler_recv_kr);
    });

    /* Set cancellation handler to clean up */
    dispatch_source_set_cancel_handler(src, ^{
        /* cleanup */
    });

    /* Step 4: Resume the source — this arms the MACH_RECV kevent */
    dispatch_resume(src);
    printf("{\"test\":\"mach_recv\",\"stage\":\"source_resumed\"}\n");

    /* Step 5: Send a Mach message to the port */
    usleep(100000); /* 100ms — let the source arm */

    simple_msg_t send_msg;
    memset(&send_msg, 0, sizeof(send_msg));
    send_msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    send_msg.header.msgh_size = sizeof(send_msg);
    send_msg.header.msgh_remote_port = recv_port;  /* send to ourselves */
    send_msg.header.msgh_local_port = MACH_PORT_NULL;
    send_msg.header.msgh_id = 0x241001;

    mach_msg_return_t send_kr = mach_msg(
        &send_msg.header,
        MACH_SEND_MSG,
        sizeof(send_msg),
        0,
        MACH_PORT_NULL,
        0,
        MACH_PORT_NULL);

    printf("{\"test\":\"mach_recv\",\"stage\":\"msg_sent\",\"mach_msg_send_kr\":%d}\n", send_kr);

    /* Step 6: Wait for the handler to fire (or timeout) */
    int waited = 0;
    while (!handler_fired && waited < 50) {
        usleep(100000); /* 100ms */
        waited++;
    }

    /* Step 7: Report result */
    if (handler_fired) {
        printf("{\"test\":\"mach_recv\",\"result\":\"PASS\",\"handler_fired\":true,\"mach_msg_rcv_kr\":%d,\"waited_ms\":%d}\n",
               handler_recv_kr, waited * 100);
        printf("{\"test\":\"mach_recv\",\"verdict\":\"MACH_RECV_SERVICED\",\"dark_label\":\"STALE\"}\n");
    } else {
        printf("{\"test\":\"mach_recv\",\"result\":\"FAIL\",\"handler_fired\":false,\"reason\":\"handler_timeout_5s\"}\n");
        printf("{\"test\":\"mach_recv\",\"verdict\":\"MACH_RECV_DARK\",\"dark_label\":\"CONFIRMED\"}\n");
    }

    /* Cleanup */
    dispatch_cancel(src);
    usleep(100000);
    mach_port_deallocate(mach_task_self(), recv_port);

    return handler_fired ? 0 : 1;
}
