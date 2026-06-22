/* ipc-roundtrip.c — minimal pure-mach-ipc round-trip probe (no libdispatch).
 * Allocates a receive right, sends one message, receives it. Exercises the
 * canonical spine that full-round-trip.d observes: mach_port_allocate ->
 * mach_msg send (mach_msg_send -> ipc_kmsg_alloc/copyin -> ipc_right_copyin ->
 * ipc_mqueue_send) -> mach_msg receive (mach_msg_receive -> ipc_mqueue_receive
 * -> ipc_kmsg_copyout -> ipc_right_copyout -> ipc_kmsg_destroy) -> destroy. */
#include <stdio.h>
#include <mach/mach.h>

int main(void) {
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) { printf("alloc_fail kr=%d\n", (int)kr); return 1; }

    struct { mach_msg_header_t h; } send;
    send.h.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
    send.h.msgh_size = sizeof(send);
    send.h.msgh_remote_port = port;
    send.h.msgh_local_port = MACH_PORT_NULL;
    send.h.msgh_id = 0x4f5031;
    kr = mach_msg(&send.h, MACH_SEND_MSG, sizeof(send), 0,
        MACH_PORT_NULL, 0, MACH_PORT_NULL);
    printf("send kr=%d port=%u\n", (int)kr, (unsigned)port);

    struct { mach_msg_header_t h; mach_msg_max_trailer_t t; } recv;
    memset(&recv, 0, sizeof(recv));
    kr = mach_msg(&recv.h, MACH_RCV_MSG, 0, sizeof(recv),
        port, 1000, MACH_PORT_NULL);
    printf("recv kr=%d id=0x%x\n", (int)kr, (unsigned)recv.h.msgh_id);

    mach_port_destroy(mach_task_self(), port);
    printf("ipc-roundtrip done\n");
    return 0;
}
