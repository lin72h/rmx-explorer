/*
 * descriptor_copy_send.c - Descriptor COPY_SEND oracle probe.
 *
 * Test ID: macos_m2_descriptor_copy_send
 *
 * Parent publishes a service receive right to a forked child through the
 * bootstrap special-port inheritance path. The child sends a complex Mach
 * message containing a port descriptor with MACH_MSG_TYPE_COPY_SEND. The
 * parent verifies the delivered send right by sending a Mach message back to
 * the child's cargo receive right. Pipes are used only for rendezvous/status.
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

#define OB21_DESCRIPTOR_MSG_ID 0x4f423231
#define OB21_VERIFY_MSG_ID     0x4f423232
#define OB21_STATUS_VERSION    1
#define OB21_TIMEOUT_SECONDS   15

#ifdef __APPLE__
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t cargo;
} ob21_descriptor_send_msg_t;

typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t cargo;
    mach_msg_max_trailer_t trailer;
} ob21_descriptor_recv_msg_t;

typedef struct {
    mach_msg_header_t header;
} ob21_simple_send_msg_t;

typedef struct {
    mach_msg_header_t header;
    mach_msg_max_trailer_t trailer;
} ob21_simple_recv_msg_t;
#endif

typedef struct {
    int version;
    int child_cleanup_ok;
    int child_cleanup_delta;
    int child_exit_code;
    kern_return_t kr_child_baseline_before;
    kern_return_t kr_child_get_bootstrap;
    kern_return_t kr_child_alloc_cargo;
    kern_return_t kr_child_insert_send;
    kern_return_t kr_child_type_before_send;
    kern_return_t kr_child_refs_before_send;
    mach_msg_return_t mr_child_send_descriptor;
    kern_return_t kr_child_type_after_send;
    kern_return_t kr_child_refs_after_send;
    mach_msg_return_t mr_child_receive_verify;
    kern_return_t kr_child_type_after_verify;
    kern_return_t kr_child_refs_after_verify;
    kern_return_t kr_child_destroy_cargo;
    kern_return_t kr_child_baseline_after;
    mach_port_type_t child_type_before_send;
    mach_port_type_t child_type_after_send;
    mach_port_type_t child_type_after_verify;
    mach_port_urefs_t child_refs_before_send;
    mach_port_urefs_t child_refs_after_send;
    mach_port_urefs_t child_refs_after_verify;
    unsigned int child_sent_msgh_bits;
    unsigned int child_verify_received_msgh_bits;
    unsigned int child_verify_received_remote_disp;
    unsigned int child_verify_received_local_disp;
    int child_verify_received_msgh_id;
    unsigned int child_verify_received_msgh_size;
} ob21_child_status_t;

static const char *
hex32(unsigned int value)
{
    static char bufs[12][32];
    static unsigned int idx;
    char *buf = bufs[idx++ % 12];

    snprintf(buf, 32, "0x%x", value);
    return buf;
}

static const char *
disposition_str(unsigned int disposition)
{
    switch (disposition) {
#ifdef MACH_MSG_TYPE_MOVE_RECEIVE
    case MACH_MSG_TYPE_MOVE_RECEIVE:
        return "MACH_MSG_TYPE_MOVE_RECEIVE";
#endif
#ifdef MACH_MSG_TYPE_MOVE_SEND
    case MACH_MSG_TYPE_MOVE_SEND:
        return "MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND";
#endif
#ifdef MACH_MSG_TYPE_MOVE_SEND_ONCE
    case MACH_MSG_TYPE_MOVE_SEND_ONCE:
        return "MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE";
#endif
#ifdef MACH_MSG_TYPE_COPY_SEND
    case MACH_MSG_TYPE_COPY_SEND:
        return "MACH_MSG_TYPE_COPY_SEND";
#endif
#ifdef MACH_MSG_TYPE_MAKE_SEND
    case MACH_MSG_TYPE_MAKE_SEND:
        return "MACH_MSG_TYPE_MAKE_SEND";
#endif
#ifdef MACH_MSG_TYPE_MAKE_SEND_ONCE
    case MACH_MSG_TYPE_MAKE_SEND_ONCE:
        return "MACH_MSG_TYPE_MAKE_SEND_ONCE";
#endif
    case 0:
        return "0";
    default:
        return hex32(disposition);
    }
}

static const char *
descriptor_type_str(unsigned int type)
{
#ifdef MACH_MSG_PORT_DESCRIPTOR
    if (type == MACH_MSG_PORT_DESCRIPTOR) {
        return "MACH_MSG_PORT_DESCRIPTOR";
    }
#endif
    return hex32(type);
}

static const char *
port_label(mach_port_t port, mach_port_t service_port, mach_port_t delivered)
{
    if (port == MACH_PORT_NULL) {
        return "MACH_PORT_NULL";
    }
    if (port == service_port) {
        return "service_port";
    }
    if (delivered != MACH_PORT_NULL && port == delivered) {
        return "delivered_cargo_send";
    }
    return "other_port";
}

#ifdef __APPLE__
static bool
write_full(int fd, const void *buf, size_t len)
{
    const char *p = (const char *)buf;
    while (len > 0) {
        ssize_t n = write(fd, p, len);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return false;
        }
        if (n == 0) {
            return false;
        }
        p += n;
        len -= (size_t)n;
    }
    return true;
}

static bool
read_full(int fd, void *buf, size_t len)
{
    char *p = (char *)buf;
    while (len > 0) {
        ssize_t n = read(fd, p, len);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return false;
        }
        if (n == 0) {
            return false;
        }
        p += n;
        len -= (size_t)n;
    }
    return true;
}

static void
child_run(int status_fd)
{
    alarm(OB21_TIMEOUT_SECONDS);

    ob21_child_status_t st;
    memset(&st, 0, sizeof(st));
    st.version = OB21_STATUS_VERSION;
    st.child_exit_code = 1;
    st.kr_child_baseline_before = KERN_FAILURE;
    st.kr_child_get_bootstrap = KERN_FAILURE;
    st.kr_child_alloc_cargo = KERN_FAILURE;
    st.kr_child_insert_send = KERN_FAILURE;
    st.kr_child_type_before_send = KERN_FAILURE;
    st.kr_child_refs_before_send = KERN_FAILURE;
    st.mr_child_send_descriptor = MACH_SEND_INVALID_DEST;
    st.kr_child_type_after_send = KERN_FAILURE;
    st.kr_child_refs_after_send = KERN_FAILURE;
    st.mr_child_receive_verify = MACH_RCV_INVALID_NAME;
    st.kr_child_type_after_verify = KERN_FAILURE;
    st.kr_child_refs_after_verify = KERN_FAILURE;
    st.kr_child_destroy_cargo = KERN_FAILURE;
    st.kr_child_baseline_after = KERN_FAILURE;

    mach_port_t service_port = MACH_PORT_NULL;
    mach_port_t cargo_port = MACH_PORT_NULL;
    nx_baseline_t before, after;
    nx_baseline_capture(&after);

    st.kr_child_get_bootstrap = task_get_special_port(mach_task_self(),
        TASK_BOOTSTRAP_PORT, &service_port);

    nx_baseline_capture(&before);
    st.kr_child_baseline_before = before.kr;

    if (st.kr_child_get_bootstrap == KERN_SUCCESS) {
        st.kr_child_alloc_cargo = mach_port_allocate(mach_task_self(),
            MACH_PORT_RIGHT_RECEIVE, &cargo_port);
    }
    if (st.kr_child_alloc_cargo == KERN_SUCCESS) {
        st.kr_child_insert_send = mach_port_insert_right(mach_task_self(),
            cargo_port, cargo_port, MACH_MSG_TYPE_MAKE_SEND);
    }
    if (st.kr_child_insert_send == KERN_SUCCESS) {
        st.kr_child_type_before_send = mach_port_type(mach_task_self(),
            cargo_port, &st.child_type_before_send);
        st.kr_child_refs_before_send = mach_port_get_refs(mach_task_self(),
            cargo_port, MACH_PORT_RIGHT_SEND,
            &st.child_refs_before_send);
    }

    if (st.kr_child_type_before_send == KERN_SUCCESS &&
        st.kr_child_refs_before_send == KERN_SUCCESS) {
        ob21_descriptor_send_msg_t msg;
        memset(&msg, 0, sizeof(msg));
        st.child_sent_msgh_bits =
            MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) |
            MACH_MSGH_BITS_COMPLEX;
        msg.header.msgh_bits = st.child_sent_msgh_bits;
        msg.header.msgh_size = (mach_msg_size_t)sizeof(msg);
        msg.header.msgh_remote_port = service_port;
        msg.header.msgh_local_port = MACH_PORT_NULL;
        msg.header.msgh_id = OB21_DESCRIPTOR_MSG_ID;
        msg.body.msgh_descriptor_count = 1;
        msg.cargo.name = cargo_port;
        msg.cargo.disposition = MACH_MSG_TYPE_COPY_SEND;
        msg.cargo.type = MACH_MSG_PORT_DESCRIPTOR;

        st.mr_child_send_descriptor = mach_msg(&msg.header,
            MACH_SEND_MSG | MACH_SEND_TIMEOUT,
            msg.header.msgh_size,
            0,
            MACH_PORT_NULL,
            5000,
            MACH_PORT_NULL);
    }

    if (st.mr_child_send_descriptor == MACH_MSG_SUCCESS) {
        st.kr_child_type_after_send = mach_port_type(mach_task_self(),
            cargo_port, &st.child_type_after_send);
        st.kr_child_refs_after_send = mach_port_get_refs(mach_task_self(),
            cargo_port, MACH_PORT_RIGHT_SEND,
            &st.child_refs_after_send);

        ob21_simple_recv_msg_t verify_msg;
        memset(&verify_msg, 0, sizeof(verify_msg));
        st.mr_child_receive_verify = mach_msg(&verify_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0,
            (mach_msg_size_t)sizeof(verify_msg),
            cargo_port,
            5000,
            MACH_PORT_NULL);

        if (st.mr_child_receive_verify == MACH_MSG_SUCCESS) {
            st.child_verify_received_msgh_bits = verify_msg.header.msgh_bits;
            st.child_verify_received_msgh_id = verify_msg.header.msgh_id;
            st.child_verify_received_msgh_size = verify_msg.header.msgh_size;
            st.child_verify_received_remote_disp =
                MACH_MSGH_BITS_REMOTE(st.child_verify_received_msgh_bits);
            st.child_verify_received_local_disp =
                MACH_MSGH_BITS_LOCAL(st.child_verify_received_msgh_bits);
        }

        st.kr_child_type_after_verify = mach_port_type(mach_task_self(),
            cargo_port, &st.child_type_after_verify);
        st.kr_child_refs_after_verify = mach_port_get_refs(mach_task_self(),
            cargo_port, MACH_PORT_RIGHT_SEND,
            &st.child_refs_after_verify);
    }

    if (st.kr_child_alloc_cargo == KERN_SUCCESS) {
        st.kr_child_destroy_cargo = mach_port_destroy(mach_task_self(),
            cargo_port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    st.kr_child_baseline_after = after.kr;
    st.child_cleanup_ok = nx_baseline_compare(&before, &after,
        &st.child_cleanup_delta) ? 1 : 0;

    if (st.kr_child_get_bootstrap == KERN_SUCCESS &&
        service_port != MACH_PORT_NULL) {
        (void)mach_port_deallocate(mach_task_self(), service_port);
    }

    if (st.kr_child_baseline_before == KERN_SUCCESS &&
        st.kr_child_get_bootstrap == KERN_SUCCESS &&
        st.kr_child_alloc_cargo == KERN_SUCCESS &&
        st.kr_child_insert_send == KERN_SUCCESS &&
        st.kr_child_type_before_send == KERN_SUCCESS &&
        st.kr_child_refs_before_send == KERN_SUCCESS &&
        st.mr_child_send_descriptor == MACH_MSG_SUCCESS &&
        st.kr_child_type_after_send == KERN_SUCCESS &&
        st.kr_child_refs_after_send == KERN_SUCCESS &&
        st.mr_child_receive_verify == MACH_MSG_SUCCESS &&
        st.kr_child_type_after_verify == KERN_SUCCESS &&
        st.kr_child_refs_after_verify == KERN_SUCCESS &&
        st.kr_child_destroy_cargo == KERN_SUCCESS &&
        st.kr_child_baseline_after == KERN_SUCCESS &&
        st.child_cleanup_ok) {
        st.child_exit_code = 0;
    }

    (void)write_full(status_fd, &st, sizeof(st));
    close(status_fd);
    nx_baseline_free(&before);
    nx_baseline_free(&after);
    _exit(st.child_exit_code);
}
#endif

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);
    nx_baseline_capture(&after);

    ob21_child_status_t child;
    memset(&child, 0, sizeof(child));
    child.version = OB21_STATUS_VERSION;
    child.child_exit_code = -1;

    mach_port_t original_bootstrap = MACH_PORT_NULL;
    mach_port_t service_port = MACH_PORT_NULL;
    mach_port_t delivered_port = MACH_PORT_NULL;
    kern_return_t kr_get_bootstrap = KERN_FAILURE;
    kern_return_t kr_alloc_service = KERN_FAILURE;
    kern_return_t kr_insert_service_send = KERN_FAILURE;
    kern_return_t kr_set_bootstrap_service = KERN_FAILURE;
    kern_return_t kr_restore_bootstrap = KERN_FAILURE;
    kern_return_t kr_deallocate_original_bootstrap = KERN_FAILURE;
    kern_return_t kr_parent_delivered_type = KERN_FAILURE;
    kern_return_t kr_parent_delivered_refs = KERN_FAILURE;
    kern_return_t kr_parent_deallocate_delivered = KERN_FAILURE;
    kern_return_t kr_destroy_service = KERN_FAILURE;
    mach_msg_return_t mr_parent_receive_descriptor = MACH_RCV_INVALID_NAME;
    mach_msg_return_t mr_parent_send_verify = MACH_SEND_INVALID_DEST;
    mach_port_type_t parent_delivered_type = 0;
    mach_port_urefs_t parent_delivered_refs = 0;
    unsigned int parent_received_msgh_bits = 0;
    unsigned int parent_received_remote_disp = 0;
    unsigned int parent_received_local_disp = 0;
    unsigned int parent_received_msgh_size = 0;
    unsigned int parent_received_descriptor_count = 0;
    unsigned int delivered_descriptor_type = 0;
    unsigned int delivered_descriptor_disposition = 0;
    int parent_received_msgh_id = 0;
    unsigned int verify_sent_msgh_bits = 0;
    int status_pipe[2] = {-1, -1};
    pid_t child_pid = -1;
    int child_wait_status = -1;
    bool child_status_read = false;
    bool child_waited = false;
    bool status_pipe_created = false;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#ifdef __APPLE__
    alarm(OB21_TIMEOUT_SECONDS);

    if (pipe(status_pipe) != 0) {
        status_pipe[0] = -1;
        status_pipe[1] = -1;
    } else {
        status_pipe_created = true;
    }

    kr_get_bootstrap = task_get_special_port(mach_task_self(),
        TASK_BOOTSTRAP_PORT, &original_bootstrap);
    if (kr_get_bootstrap == KERN_SUCCESS) {
        kr_alloc_service = mach_port_allocate(mach_task_self(),
            MACH_PORT_RIGHT_RECEIVE, &service_port);
    }
    if (kr_alloc_service == KERN_SUCCESS) {
        kr_insert_service_send = mach_port_insert_right(mach_task_self(),
            service_port, service_port, MACH_MSG_TYPE_MAKE_SEND);
    }
    if (kr_insert_service_send == KERN_SUCCESS) {
        kr_set_bootstrap_service = task_set_special_port(mach_task_self(),
            TASK_BOOTSTRAP_PORT, service_port);
    }

    if (kr_set_bootstrap_service == KERN_SUCCESS && status_pipe[0] >= 0) {
        child_pid = fork();
        if (child_pid == 0) {
            close(status_pipe[0]);
            child_run(status_pipe[1]);
        }
        close(status_pipe[1]);
        status_pipe[1] = -1;
    }

    if (kr_set_bootstrap_service == KERN_SUCCESS) {
        kr_restore_bootstrap = task_set_special_port(mach_task_self(),
            TASK_BOOTSTRAP_PORT, original_bootstrap);
    }

    if (child_pid > 0) {
        ob21_descriptor_recv_msg_t recv_msg;
        memset(&recv_msg, 0, sizeof(recv_msg));
        mr_parent_receive_descriptor = mach_msg(&recv_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0,
            (mach_msg_size_t)sizeof(recv_msg),
            service_port,
            5000,
            MACH_PORT_NULL);

        if (mr_parent_receive_descriptor == MACH_MSG_SUCCESS) {
            parent_received_msgh_bits = recv_msg.header.msgh_bits;
            parent_received_msgh_size = recv_msg.header.msgh_size;
            parent_received_msgh_id = recv_msg.header.msgh_id;
            parent_received_remote_disp =
                MACH_MSGH_BITS_REMOTE(parent_received_msgh_bits);
            parent_received_local_disp =
                MACH_MSGH_BITS_LOCAL(parent_received_msgh_bits);
            parent_received_descriptor_count = recv_msg.body.msgh_descriptor_count;
            delivered_port = recv_msg.cargo.name;
            delivered_descriptor_type = recv_msg.cargo.type;
            delivered_descriptor_disposition = recv_msg.cargo.disposition;

            kr_parent_delivered_type = mach_port_type(mach_task_self(),
                delivered_port, &parent_delivered_type);
            kr_parent_delivered_refs = mach_port_get_refs(mach_task_self(),
                delivered_port, MACH_PORT_RIGHT_SEND,
                &parent_delivered_refs);

            if (kr_parent_delivered_refs == KERN_SUCCESS &&
                parent_delivered_refs > 0) {
                ob21_simple_send_msg_t verify_msg;
                memset(&verify_msg, 0, sizeof(verify_msg));
                verify_sent_msgh_bits =
                    MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
                verify_msg.header.msgh_bits = verify_sent_msgh_bits;
                verify_msg.header.msgh_size =
                    (mach_msg_size_t)sizeof(verify_msg);
                verify_msg.header.msgh_remote_port = delivered_port;
                verify_msg.header.msgh_local_port = MACH_PORT_NULL;
                verify_msg.header.msgh_id = OB21_VERIFY_MSG_ID;

                mr_parent_send_verify = mach_msg(&verify_msg.header,
                    MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                    verify_msg.header.msgh_size,
                    0,
                    MACH_PORT_NULL,
                    5000,
                    MACH_PORT_NULL);
            }
        }

        child_status_read = read_full(status_pipe[0], &child, sizeof(child));
        close(status_pipe[0]);
        status_pipe[0] = -1;

        if (waitpid(child_pid, &child_wait_status, 0) == child_pid) {
            child_waited = true;
        }
    }

    if (delivered_port != MACH_PORT_NULL) {
        kr_parent_deallocate_delivered = mach_port_deallocate(mach_task_self(),
            delivered_port);
    }
    if (kr_alloc_service == KERN_SUCCESS) {
        kr_destroy_service = mach_port_destroy(mach_task_self(), service_port);
    }
    if (original_bootstrap != MACH_PORT_NULL) {
        kr_deallocate_original_bootstrap = mach_port_deallocate(
            mach_task_self(), original_bootstrap);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#else
    (void)status_pipe;
    (void)child_pid;
#endif

    bool parent_received_descriptor =
        (mr_parent_receive_descriptor == MACH_MSG_SUCCESS &&
        parent_received_descriptor_count == 1 &&
        delivered_port != MACH_PORT_NULL);
    bool child_send_refs_preserved =
        (child.kr_child_refs_before_send == KERN_SUCCESS &&
        child.kr_child_refs_after_send == KERN_SUCCESS &&
        child.child_refs_after_send == child.child_refs_before_send);
    bool child_type_preserved_after_send =
        (child.kr_child_type_before_send == KERN_SUCCESS &&
        child.kr_child_type_after_send == KERN_SUCCESS &&
        child.child_type_before_send == MACH_PORT_TYPE_SEND_RECEIVE &&
        child.child_type_after_send == child.child_type_before_send);
    bool child_type_preserved_after_verify =
        (child.kr_child_type_before_send == KERN_SUCCESS &&
        child.kr_child_type_after_verify == KERN_SUCCESS &&
        child.child_type_after_verify == child.child_type_before_send);
    bool child_send_refs_after_verify_preserved =
        (child.kr_child_refs_after_verify == KERN_SUCCESS &&
        child.child_refs_after_verify == child.child_refs_before_send);
    bool parent_delivered_send_right =
        (kr_parent_delivered_type == KERN_SUCCESS &&
        (parent_delivered_type & MACH_PORT_TYPE_SEND) == MACH_PORT_TYPE_SEND &&
        kr_parent_delivered_refs == KERN_SUCCESS &&
        parent_delivered_refs >= 1);
    bool delivered_right_usable =
        (mr_parent_send_verify == MACH_MSG_SUCCESS &&
        child.mr_child_receive_verify == MACH_MSG_SUCCESS &&
        child.child_verify_received_msgh_id == OB21_VERIFY_MSG_ID);
    bool child_clean = (child_status_read && child.child_exit_code == 0 &&
        child.child_cleanup_ok);

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
    if (before.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "initial mach_port_names failed";
    } else if (!status_pipe_created) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "pipe setup failed";
    } else if (kr_get_bootstrap != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "task_get_special_port bootstrap failed";
    } else if (kr_alloc_service != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate service failed";
    } else if (kr_insert_service_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_insert_right service failed";
    } else if (kr_set_bootstrap_service != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "task_set_special_port service failed";
    } else if (child_pid <= 0) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "fork failed";
    } else if (kr_restore_bootstrap != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "task_set_special_port restore failed";
    } else if (!parent_received_descriptor) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "parent did not receive descriptor";
    } else if (child.kr_child_type_before_send != KERN_SUCCESS ||
        child.child_type_before_send != MACH_PORT_TYPE_SEND_RECEIVE) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "child cargo type before send was not SEND_RECEIVE";
    } else if (!child_type_preserved_after_send) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "descriptor COPY_SEND changed child cargo type after send";
    } else if (!child_send_refs_preserved) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "descriptor COPY_SEND changed child cargo send urefs";
    } else if (!parent_delivered_send_right) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "parent delivered descriptor was not an observable send right";
    } else if (!delivered_right_usable) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "parent delivered send right usability failed";
    } else if (!child_type_preserved_after_verify) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "child cargo type changed after verification";
    } else if (!child_send_refs_after_verify_preserved) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "child cargo send refs changed after verification";
    } else if (!child_status_read || !child_waited) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "child status or waitpid failed";
    } else if (!child_clean) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "child cleanup did not return to baseline";
    } else if (kr_parent_deallocate_delivered != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "parent mach_port_deallocate delivered failed";
    } else if (kr_destroy_service != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "parent mach_port_destroy service failed";
    } else if (after.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "final mach_port_names failed";
    } else if (!cleanup_ok) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "parent port namespace did not return to baseline";
    }
#endif

    nx_json_begin_object(&j);

    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }

    nx_result_emit_header(&j,
        agent,
        "macos_m2_descriptor_copy_send",
        NULL,
        NULL,
        status,
        sclass);

    nx_env_emit(&j);

    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", hex32(child.child_sent_msgh_bits));
    nx_json_key(&j, "remote_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "service_port");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_COPY_SEND");
    nx_json_key_string(&j, "right_type", "MACH_PORT_TYPE_SEND");
    nx_json_end_object(&j);
    nx_json_key(&j, "local_port");
    nx_json_begin_object(&j);
    nx_json_key_null(&j, "name");
    nx_json_key_null(&j, "disposition");
    nx_json_key_null(&j, "right_type");
    nx_json_end_object(&j);
    nx_json_key(&j, "header_rights");
    nx_json_begin_array(&j);
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "field", "msgh_remote_port");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_COPY_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_SEND");
    nx_json_key_string(&j, "right_type_after", "MACH_PORT_TYPE_SEND");
    nx_json_end_object(&j);
    nx_json_end_array(&j);
    nx_json_key_int(&j, "descriptor_count", 1);
    nx_json_key(&j, "descriptors");
    nx_json_begin_array(&j);
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "cargo_send_descriptor");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_COPY_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_SEND");
    nx_json_key_string(&j, "right_type_after", nx_port_type_str(parent_delivered_type));
    nx_json_end_object(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "parent_mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "parent_task_get_special_port_bootstrap",
        nx_kern_return_str(kr_get_bootstrap), kr_get_bootstrap, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_allocate_service",
        nx_kern_return_str(kr_alloc_service), kr_alloc_service, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_insert_right_service_make_send",
        nx_kern_return_str(kr_insert_service_send), kr_insert_service_send,
        false, 0);
    nx_result_emit_return(&j, "parent_task_set_special_port_service",
        nx_kern_return_str(kr_set_bootstrap_service),
        kr_set_bootstrap_service, false, 0);
    nx_result_emit_return(&j, "parent_task_set_special_port_restore",
        nx_kern_return_str(kr_restore_bootstrap), kr_restore_bootstrap,
        false, 0);
    nx_result_emit_return(&j, "child_task_get_special_port_bootstrap",
        nx_kern_return_str(child.kr_child_get_bootstrap),
        child.kr_child_get_bootstrap, false, 0);
    nx_result_emit_return(&j, "child_mach_port_allocate_cargo",
        nx_kern_return_str(child.kr_child_alloc_cargo),
        child.kr_child_alloc_cargo, false, 0);
    nx_result_emit_return(&j, "child_mach_port_insert_right_cargo_make_send",
        nx_kern_return_str(child.kr_child_insert_send),
        child.kr_child_insert_send, false, 0);
    nx_result_emit_return(&j, "child_mach_port_type_cargo_before_send",
        nx_kern_return_str(child.kr_child_type_before_send),
        child.kr_child_type_before_send, false, 0);
    nx_result_emit_return(&j, "child_mach_port_get_refs_send_before_send",
        nx_kern_return_str(child.kr_child_refs_before_send),
        child.kr_child_refs_before_send, false, 0);
    nx_result_emit_return(&j, "child_mach_msg_send_descriptor_copy_send",
        nx_msg_return_str(child.mr_child_send_descriptor),
        child.mr_child_send_descriptor, false, 0);
    nx_result_emit_return(&j, "child_mach_port_type_cargo_after_send",
        nx_kern_return_str(child.kr_child_type_after_send),
        child.kr_child_type_after_send, false, 0);
    nx_result_emit_return(&j, "child_mach_port_get_refs_send_after_send",
        nx_kern_return_str(child.kr_child_refs_after_send),
        child.kr_child_refs_after_send, false, 0);
    nx_result_emit_return(&j, "parent_mach_msg_receive_descriptor",
        nx_msg_return_str(mr_parent_receive_descriptor),
        mr_parent_receive_descriptor, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_type_delivered",
        nx_kern_return_str(kr_parent_delivered_type),
        kr_parent_delivered_type, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_get_refs_delivered_send",
        nx_kern_return_str(kr_parent_delivered_refs),
        kr_parent_delivered_refs, false, 0);
    nx_result_emit_return(&j, "parent_mach_msg_send_verify_copy_send",
        nx_msg_return_str(mr_parent_send_verify), mr_parent_send_verify,
        false, 0);
    nx_result_emit_return(&j, "child_mach_msg_receive_verify",
        nx_msg_return_str(child.mr_child_receive_verify),
        child.mr_child_receive_verify, false, 0);
    nx_result_emit_return(&j, "child_mach_port_type_cargo_after_verify",
        nx_kern_return_str(child.kr_child_type_after_verify),
        child.kr_child_type_after_verify, false, 0);
    nx_result_emit_return(&j, "child_mach_port_get_refs_send_after_verify",
        nx_kern_return_str(child.kr_child_refs_after_verify),
        child.kr_child_refs_after_verify, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_deallocate_delivered",
        nx_kern_return_str(kr_parent_deallocate_delivered),
        kr_parent_deallocate_delivered, false, 0);
    nx_result_emit_return(&j, "child_mach_port_destroy_cargo",
        nx_kern_return_str(child.kr_child_destroy_cargo),
        child.kr_child_destroy_cargo, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_destroy_service",
        nx_kern_return_str(kr_destroy_service), kr_destroy_service,
        false, 0);
    nx_result_emit_return(&j, "parent_mach_port_deallocate_original_bootstrap",
        nx_kern_return_str(kr_deallocate_original_bootstrap),
        kr_deallocate_original_bootstrap, false, 0);
    nx_result_emit_return(&j, "child_mach_port_names_after",
        nx_kern_return_str(child.kr_child_baseline_after),
        child.kr_child_baseline_after, false, 0);
    nx_result_emit_return(&j, "parent_mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_result_emit_right_delta(&j,
        "descriptor COPY_SEND child sender",
        "cargo_port",
        "MACH_PORT_RIGHT_SEND",
        child.kr_child_refs_before_send == KERN_SUCCESS ?
            (long long)child.child_refs_before_send : -1,
        child.kr_child_refs_after_send == KERN_SUCCESS ?
            (long long)child.child_refs_after_send : -1,
        -1,
        -1,
        "unchanged");
    nx_result_emit_right_delta(&j,
        "descriptor COPY_SEND parent delivered",
        "delivered_cargo_send",
        nx_port_type_str(parent_delivered_type),
        -1,
        kr_parent_delivered_refs == KERN_SUCCESS ?
            (long long)parent_delivered_refs : -1,
        -1,
        -1,
        "usable send right");
    nx_result_emit_right_delta(&j,
        "descriptor COPY_SEND child after verification",
        "cargo_port",
        "MACH_PORT_RIGHT_SEND",
        child.kr_child_refs_after_send == KERN_SUCCESS ?
            (long long)child.child_refs_after_send : -1,
        child.kr_child_refs_after_verify == KERN_SUCCESS ?
            (long long)child.child_refs_after_verify : -1,
        -1,
        -1,
        "unchanged");
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "transport_setup",
        "bootstrap special-port inheritance plus status pipe");
    nx_json_key_bool(&j, "child_status_read", child_status_read);
    nx_json_key_bool(&j, "child_waited", child_waited);
    nx_json_key_int(&j, "child_wait_status", child_wait_status);
    nx_json_key_string(&j, "child_cargo_type_before_send",
        nx_port_type_str(child.child_type_before_send));
    nx_json_key_string(&j, "child_cargo_type_after_send",
        nx_port_type_str(child.child_type_after_send));
    nx_json_key_bool(&j, "child_cargo_type_unchanged_after_send",
        child_type_preserved_after_send);
    nx_json_key_int(&j, "child_cargo_send_urefs_before_send",
        child.kr_child_refs_before_send == KERN_SUCCESS ?
            (long long)child.child_refs_before_send : -1);
    nx_json_key_int(&j, "child_cargo_send_urefs_after_send",
        child.kr_child_refs_after_send == KERN_SUCCESS ?
            (long long)child.child_refs_after_send : -1);
    nx_json_key_bool(&j, "child_cargo_send_urefs_unchanged_after_send",
        child_send_refs_preserved);
    nx_json_key_int(&j, "child_cargo_send_urefs_after_verify",
        child.kr_child_refs_after_verify == KERN_SUCCESS ?
            (long long)child.child_refs_after_verify : -1);
    nx_json_key_string(&j, "child_cargo_type_after_verify",
        nx_port_type_str(child.child_type_after_verify));
    nx_json_key_bool(&j, "child_cargo_type_unchanged_after_verify",
        child_type_preserved_after_verify);
    nx_json_key_bool(&j, "child_cargo_send_urefs_unchanged_after_verify",
        child_send_refs_after_verify_preserved);
    nx_json_key_string(&j, "sent_msgh_bits_raw_hex",
        hex32(child.child_sent_msgh_bits));
    nx_json_key_string(&j, "received_msgh_bits_raw_hex",
        hex32(parent_received_msgh_bits));
    nx_json_key_string(&j, "received_remote_disposition",
        disposition_str(parent_received_remote_disp));
    nx_json_key_string(&j, "received_local_disposition",
        disposition_str(parent_received_local_disp));
    nx_json_key_int(&j, "received_msgh_size", parent_received_msgh_size);
    nx_json_key_int(&j, "received_msgh_id", parent_received_msgh_id);
    nx_json_key_int(&j, "received_descriptor_count",
        parent_received_descriptor_count);
    nx_json_key_string(&j, "delivered_descriptor_name",
        port_label(delivered_port, service_port, delivered_port));
    nx_json_key_string(&j, "delivered_descriptor_type",
        descriptor_type_str(delivered_descriptor_type));
    nx_json_key_string(&j, "delivered_descriptor_disposition",
        disposition_str(delivered_descriptor_disposition));
    nx_json_key_string(&j, "delivered_descriptor_disposition_raw_hex",
        hex32(delivered_descriptor_disposition));
    nx_json_key_string(&j, "parent_delivered_port_type",
        nx_port_type_str(parent_delivered_type));
    nx_json_key_int(&j, "parent_delivered_send_refs",
        kr_parent_delivered_refs == KERN_SUCCESS ?
            (long long)parent_delivered_refs : -1);
    nx_json_key_bool(&j, "delivered_right_usable", delivered_right_usable);
    nx_json_key_string(&j, "verify_sent_msgh_bits_raw_hex",
        hex32(verify_sent_msgh_bits));
    nx_json_key_string(&j, "child_verify_received_msgh_bits_raw_hex",
        hex32(child.child_verify_received_msgh_bits));
    nx_json_key_string(&j, "child_verify_received_remote_disposition",
        disposition_str(child.child_verify_received_remote_disp));
    nx_json_key_string(&j, "child_verify_received_local_disposition",
        disposition_str(child.child_verify_received_local_disp));
    nx_json_key_int(&j, "child_verify_received_msgh_size",
        child.child_verify_received_msgh_size);
    nx_json_key_int(&j, "child_verify_received_msgh_id",
        child.child_verify_received_msgh_id);
    nx_json_key_bool(&j, "child_cleanup_returned_to_baseline",
        child.child_cleanup_ok != 0);
    nx_json_key_int(&j, "child_cleanup_delta", child.child_cleanup_delta);
    nx_json_key_int(&j, "parent_names_before",
        before.valid ? before.names_count : -1);
    nx_json_key_int(&j, "parent_names_after",
        after.valid ? after.names_count : -1);
    nx_json_key_int(&j, "parent_cleanup_delta", cleanup_delta);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);

    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
