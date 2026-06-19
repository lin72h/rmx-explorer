/*
 * header_move_send_accounting.c - Header MOVE_SEND accounting oracle probe.
 *
 * Test ID: macos_m1_header_move_send_accounting
 *
 * Sends one same-process Mach message whose header remote-port disposition is
 * MACH_MSG_TYPE_MOVE_SEND. The probe records source send urefs before send,
 * immediately after mach_msg(SEND), and after mach_msg(RECEIVE). The key
 * OB1.5 condition is that MOVE_SEND consumes the sender's observable send
 * right at SEND return.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

#define OB15_MSG_ID 0x4f423135
#define OB15_USABILITY_MSG_ID 0x4f423136

#ifdef __APPLE__
typedef struct {
    mach_msg_header_t header;
} ob15_send_msg_t;

typedef struct {
    mach_msg_header_t header;
    mach_msg_max_trailer_t trailer;
} ob15_recv_msg_t;
#endif

static const char *
hex32(unsigned int value)
{
    static char bufs[8][32];
    static unsigned int idx;
    char *buf = bufs[idx++ % 8];

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
        return "MACH_MSG_TYPE_MOVE_SEND";
#endif
#ifdef MACH_MSG_TYPE_MOVE_SEND_ONCE
    case MACH_MSG_TYPE_MOVE_SEND_ONCE:
        return "MACH_MSG_TYPE_MOVE_SEND_ONCE";
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
port_label(mach_port_t observed, mach_port_t service_port)
{
    if (observed == MACH_PORT_NULL) {
        return "MACH_PORT_NULL";
    }
    if (observed == service_port) {
        return "service_port";
    }
    return "other_port";
}

static bool
type_has_send(mach_port_type_t type)
{
    return (type & MACH_PORT_TYPE_SEND) == MACH_PORT_TYPE_SEND;
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);
    nx_baseline_capture(&after);

    mach_port_t service_port = MACH_PORT_NULL;
    kern_return_t kr_alloc_receive = KERN_FAILURE;
    kern_return_t kr_insert_send = KERN_FAILURE;
    kern_return_t kr_send_refs_before = KERN_FAILURE;
    kern_return_t kr_type_before = KERN_FAILURE;
    mach_msg_return_t mr_send = MACH_SEND_INVALID_DEST;
    kern_return_t kr_send_refs_after_send = KERN_FAILURE;
    kern_return_t kr_type_after_send = KERN_FAILURE;
    mach_msg_return_t mr_receive = MACH_RCV_INVALID_NAME;
    kern_return_t kr_send_refs_after_receive = KERN_FAILURE;
    kern_return_t kr_type_after_receive = KERN_FAILURE;
    mach_msg_return_t mr_usability_send = MACH_SEND_INVALID_DEST;
    mach_msg_return_t mr_usability_receive = MACH_RCV_INVALID_NAME;
    kern_return_t kr_send_refs_after_usability = KERN_FAILURE;
    kern_return_t kr_destroy_service = KERN_FAILURE;
    mach_port_urefs_t send_refs_before = 0;
    mach_port_urefs_t send_refs_after_send = 0;
    mach_port_urefs_t send_refs_after_receive = 0;
    mach_port_urefs_t send_refs_after_usability = 0;
    mach_port_type_t type_before = 0;
    mach_port_type_t type_after_send = 0;
    mach_port_type_t type_after_receive = 0;
    unsigned int sent_msgh_bits = 0;
    unsigned int received_msgh_bits = 0;
    unsigned int usability_msgh_bits = 0;
    unsigned int received_remote_disp = 0;
    unsigned int received_local_disp = 0;
    unsigned int received_msgh_size = 0;
    int received_msgh_id = 0;
    mach_port_t received_remote_port = MACH_PORT_NULL;
    mach_port_t received_local_port = MACH_PORT_NULL;
    int cleanup_delta = 0;
    bool cleanup_ok = false;
    bool usability_attempted = false;
    bool delivered_right_usable = false;

#ifdef __APPLE__
    kr_alloc_receive = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &service_port);
    if (kr_alloc_receive == KERN_SUCCESS) {
        kr_insert_send = mach_port_insert_right(mach_task_self(),
            service_port, service_port, MACH_MSG_TYPE_MAKE_SEND);
    }
    if (kr_insert_send == KERN_SUCCESS) {
        kr_send_refs_before = mach_port_get_refs(mach_task_self(),
            service_port, MACH_PORT_RIGHT_SEND, &send_refs_before);
        kr_type_before = mach_port_type(mach_task_self(), service_port,
            &type_before);
    }

    if (kr_send_refs_before == KERN_SUCCESS &&
        kr_type_before == KERN_SUCCESS) {
        ob15_send_msg_t send_msg;
        memset(&send_msg, 0, sizeof(send_msg));
        sent_msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND, 0);
        send_msg.header.msgh_bits = sent_msgh_bits;
        send_msg.header.msgh_size = (mach_msg_size_t)sizeof(send_msg);
        send_msg.header.msgh_remote_port = service_port;
        send_msg.header.msgh_local_port = MACH_PORT_NULL;
        send_msg.header.msgh_id = OB15_MSG_ID;

        mr_send = mach_msg(&send_msg.header,
            MACH_SEND_MSG | MACH_SEND_TIMEOUT,
            send_msg.header.msgh_size,
            0,
            MACH_PORT_NULL,
            5000,
            MACH_PORT_NULL);
    }

    if (mr_send == MACH_MSG_SUCCESS) {
        kr_send_refs_after_send = mach_port_get_refs(mach_task_self(),
            service_port, MACH_PORT_RIGHT_SEND, &send_refs_after_send);
        kr_type_after_send = mach_port_type(mach_task_self(), service_port,
            &type_after_send);

        ob15_recv_msg_t recv_msg;
        memset(&recv_msg, 0, sizeof(recv_msg));
        mr_receive = mach_msg(&recv_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0,
            (mach_msg_size_t)sizeof(recv_msg),
            service_port,
            5000,
            MACH_PORT_NULL);

        if (mr_receive == MACH_MSG_SUCCESS) {
            received_msgh_bits = recv_msg.header.msgh_bits;
            received_msgh_size = recv_msg.header.msgh_size;
            received_msgh_id = recv_msg.header.msgh_id;
            received_remote_port = recv_msg.header.msgh_remote_port;
            received_local_port = recv_msg.header.msgh_local_port;
            received_remote_disp = MACH_MSGH_BITS_REMOTE(received_msgh_bits);
            received_local_disp = MACH_MSGH_BITS_LOCAL(received_msgh_bits);
        }

        kr_send_refs_after_receive = mach_port_get_refs(mach_task_self(),
            service_port, MACH_PORT_RIGHT_SEND, &send_refs_after_receive);
        kr_type_after_receive = mach_port_type(mach_task_self(), service_port,
            &type_after_receive);

        if (kr_send_refs_after_receive == KERN_SUCCESS &&
            send_refs_after_receive > 0 &&
            kr_type_after_receive == KERN_SUCCESS &&
            type_has_send(type_after_receive)) {
            usability_attempted = true;

            ob15_send_msg_t usability_msg;
            memset(&usability_msg, 0, sizeof(usability_msg));
            usability_msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
            usability_msg.header.msgh_bits = usability_msgh_bits;
            usability_msg.header.msgh_size =
                (mach_msg_size_t)sizeof(usability_msg);
            usability_msg.header.msgh_remote_port = service_port;
            usability_msg.header.msgh_local_port = MACH_PORT_NULL;
            usability_msg.header.msgh_id = OB15_USABILITY_MSG_ID;

            mr_usability_send = mach_msg(&usability_msg.header,
                MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                usability_msg.header.msgh_size,
                0,
                MACH_PORT_NULL,
                5000,
                MACH_PORT_NULL);

            if (mr_usability_send == MACH_MSG_SUCCESS) {
                ob15_recv_msg_t usability_recv_msg;
                memset(&usability_recv_msg, 0, sizeof(usability_recv_msg));
                mr_usability_receive = mach_msg(&usability_recv_msg.header,
                    MACH_RCV_MSG | MACH_RCV_TIMEOUT,
                    0,
                    (mach_msg_size_t)sizeof(usability_recv_msg),
                    service_port,
                    5000,
                    MACH_PORT_NULL);
            }

            delivered_right_usable =
                (mr_usability_send == MACH_MSG_SUCCESS &&
                mr_usability_receive == MACH_MSG_SUCCESS);
            kr_send_refs_after_usability = mach_port_get_refs(
                mach_task_self(), service_port, MACH_PORT_RIGHT_SEND,
                &send_refs_after_usability);
        }
    }

    if (kr_alloc_receive == KERN_SUCCESS) {
        kr_destroy_service = mach_port_destroy(mach_task_self(), service_port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#else
    (void)service_port;
#endif

    bool send_refs_before_exact = (kr_send_refs_before == KERN_SUCCESS &&
        send_refs_before == 1);
    bool send_refs_consumed_at_send =
        (kr_send_refs_after_send == KERN_SUCCESS &&
        send_refs_after_send == 0);
    bool type_before_exact = (kr_type_before == KERN_SUCCESS &&
        type_before == MACH_PORT_TYPE_SEND_RECEIVE);
    bool type_after_send_exact = (kr_type_after_send == KERN_SUCCESS &&
        type_after_send == MACH_PORT_TYPE_RECEIVE);
    bool received_id_matches = (mr_receive == MACH_MSG_SUCCESS &&
        received_msgh_id == OB15_MSG_ID);
    bool after_receive_state_observed =
        (kr_send_refs_after_receive == KERN_SUCCESS &&
        kr_type_after_receive == KERN_SUCCESS);
    bool after_receive_state_bounded =
        (kr_send_refs_after_receive == KERN_SUCCESS &&
        send_refs_after_receive <= 1);
    bool after_receive_type_consistent = false;
    if (kr_type_after_receive == KERN_SUCCESS &&
        kr_send_refs_after_receive == KERN_SUCCESS) {
        if (send_refs_after_receive == 0) {
            after_receive_type_consistent =
                (type_after_receive == MACH_PORT_TYPE_RECEIVE);
        } else if (send_refs_after_receive == 1) {
            after_receive_type_consistent =
                (type_after_receive == MACH_PORT_TYPE_SEND_RECEIVE);
        }
    }
    bool usability_ok = (!usability_attempted || delivered_right_usable);

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
    if (nx_baseline_blocks_probe(&before)) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "initial mach_port_names failed";
    } else if (kr_alloc_receive != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate receive failed";
    } else if (kr_insert_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_insert_right MAKE_SEND failed";
    } else if (!send_refs_before_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "send refs before MOVE_SEND were not exactly one";
    } else if (!type_before_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "port type before MOVE_SEND was not SEND_RECEIVE";
    } else if (mr_send != MACH_MSG_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_msg SEND failed";
    } else if (!send_refs_consumed_at_send) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "MOVE_SEND did not consume sender send urefs at SEND return";
    } else if (!type_after_send_exact) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "port type after SEND was not RECEIVE";
    } else if (mr_receive != MACH_MSG_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_msg RECEIVE failed";
    } else if (!received_id_matches) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "received message id did not match sent message id";
    } else if (!after_receive_state_observed) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "post-RECEIVE refs/type observation failed";
    } else if (!after_receive_state_bounded) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "post-RECEIVE send urefs exceeded one";
    } else if (!after_receive_type_consistent) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "post-RECEIVE type did not match send urefs";
    } else if (!usability_ok) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "delivered send right usability check failed";
    } else if (kr_destroy_service != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_destroy service failed";
    } else if (nx_baseline_blocks_probe(&after)) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "final mach_port_names failed";
    } else if (!cleanup_ok) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_EXACT_CONTRACT;
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
        "macos_m1_header_move_send_accounting",
        NULL,
        NULL,
        status,
        sclass);

    nx_env_emit(&j);

    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", hex32(sent_msgh_bits));
    nx_json_key(&j, "remote_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "service_port");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
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
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_SEND");
    nx_json_key_string(&j, "right_type_after",
        type_after_send_exact ? "MACH_PORT_TYPE_RECEIVE" : "unknown");
    nx_json_end_object(&j);
    nx_json_end_array(&j);
    nx_json_key_int(&j, "descriptor_count", 0);
    nx_json_key(&j, "descriptors");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_receive",
        nx_kern_return_str(kr_alloc_receive), kr_alloc_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_make_send",
        nx_kern_return_str(kr_insert_send), kr_insert_send, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_before_send",
        nx_kern_return_str(kr_send_refs_before), kr_send_refs_before,
        false, 0);
    nx_result_emit_return(&j, "mach_port_type_before_send",
        nx_kern_return_str(kr_type_before), kr_type_before, false, 0);
    nx_result_emit_return(&j, "mach_msg_send_move_send",
        nx_msg_return_str(mr_send), mr_send, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_send",
        nx_kern_return_str(kr_send_refs_after_send),
        kr_send_refs_after_send, false, 0);
    nx_result_emit_return(&j, "mach_port_type_after_send",
        nx_kern_return_str(kr_type_after_send), kr_type_after_send,
        false, 0);
    nx_result_emit_return(&j, "mach_msg_receive",
        nx_msg_return_str(mr_receive), mr_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_send_after_receive",
        nx_kern_return_str(kr_send_refs_after_receive),
        kr_send_refs_after_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_type_after_receive",
        nx_kern_return_str(kr_type_after_receive), kr_type_after_receive,
        false, 0);
    if (usability_attempted) {
        nx_result_emit_return(&j, "mach_msg_usability_send_copy_send",
            nx_msg_return_str(mr_usability_send), mr_usability_send,
            false, 0);
        nx_result_emit_return(&j, "mach_msg_usability_receive",
            nx_msg_return_str(mr_usability_receive), mr_usability_receive,
            false, 0);
        nx_result_emit_return(&j, "mach_port_get_refs_send_after_usability",
            nx_kern_return_str(kr_send_refs_after_usability),
            kr_send_refs_after_usability, false, 0);
    }
    nx_result_emit_return(&j, "mach_port_destroy_service",
        nx_kern_return_str(kr_destroy_service), kr_destroy_service,
        false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_result_emit_right_delta(&j,
        "header MOVE_SEND at SEND return",
        "service_port",
        "MACH_PORT_RIGHT_SEND",
        kr_send_refs_before == KERN_SUCCESS ?
            (long long)send_refs_before : -1,
        kr_send_refs_after_send == KERN_SUCCESS ?
            (long long)send_refs_after_send : -1,
        -1,
        -1,
        "consumed");
    nx_result_emit_right_delta(&j,
        "header MOVE_SEND after RECEIVE",
        "service_port",
        "MACH_PORT_RIGHT_SEND",
        kr_send_refs_after_send == KERN_SUCCESS ?
            (long long)send_refs_after_send : -1,
        kr_send_refs_after_receive == KERN_SUCCESS ?
            (long long)send_refs_after_receive : -1,
        -1,
        -1,
        "recorded");
    if (usability_attempted) {
        nx_result_emit_right_delta(&j,
            "delivered header right usability check",
            "service_port",
            "MACH_PORT_RIGHT_SEND",
            kr_send_refs_after_receive == KERN_SUCCESS ?
                (long long)send_refs_after_receive : -1,
            kr_send_refs_after_usability == KERN_SUCCESS ?
                (long long)send_refs_after_usability : -1,
            -1,
            -1,
            delivered_right_usable ? "usable" : "not usable");
    }
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_int(&j, "send_urefs_before_send",
        kr_send_refs_before == KERN_SUCCESS ?
            (long long)send_refs_before : -1);
    nx_json_key_int(&j, "send_urefs_after_send",
        kr_send_refs_after_send == KERN_SUCCESS ?
            (long long)send_refs_after_send : -1);
    nx_json_key_bool(&j, "send_urefs_consumed_at_send_return",
        send_refs_consumed_at_send);
    nx_json_key_int(&j, "send_urefs_after_receive",
        kr_send_refs_after_receive == KERN_SUCCESS ?
            (long long)send_refs_after_receive : -1);
    nx_json_key_string(&j, "port_type_before_send",
        nx_port_type_str(type_before));
    nx_json_key_string(&j, "port_type_after_send",
        nx_port_type_str(type_after_send));
    nx_json_key_string(&j, "port_type_after_receive",
        nx_port_type_str(type_after_receive));
    nx_json_key_bool(&j, "delivered_right_usability_attempted",
        usability_attempted);
    nx_json_key_bool(&j, "delivered_right_usable", delivered_right_usable);
    nx_json_key_int(&j, "send_urefs_after_usability",
        kr_send_refs_after_usability == KERN_SUCCESS ?
            (long long)send_refs_after_usability : -1);
    nx_json_key_string(&j, "sent_msgh_bits_raw_hex", hex32(sent_msgh_bits));
    nx_json_key_string(&j, "sent_remote_disposition",
        "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "sent_local_disposition", "0");
    nx_json_key_string(&j, "received_msgh_bits_raw_hex",
        hex32(received_msgh_bits));
    nx_json_key_string(&j, "received_remote_disposition",
        disposition_str(received_remote_disp));
    nx_json_key_string(&j, "received_local_disposition",
        disposition_str(received_local_disp));
    nx_json_key_string(&j, "received_remote_port",
        port_label(received_remote_port, service_port));
    nx_json_key_string(&j, "received_local_port",
        port_label(received_local_port, service_port));
    nx_json_key_int(&j, "received_msgh_size", received_msgh_size);
    nx_json_key_int(&j, "received_msgh_id", received_msgh_id);
    nx_json_key_string(&j, "usability_msgh_bits_raw_hex",
        hex32(usability_msgh_bits));
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
