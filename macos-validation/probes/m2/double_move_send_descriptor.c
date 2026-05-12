/*
 * double_move_send_descriptor.c - Duplicate MOVE_SEND descriptor source probe.
 *
 * Test ID: macos_m2_double_move_send_descriptor
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nx_env.h"
#include "nx_json.h"
#include "nx_mach_utils.h"
#include "nx_result.h"

#define OB24_DOUBLE_MSG_ID  0x4f423244
#define OB24_SEND_TIMEOUT_MS 500
#define OB24_RECV_TIMEOUT_MS 100

#ifdef __APPLE__
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t first;
    mach_msg_port_descriptor_t second;
} ob24_double_send_msg_t;

typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t first;
    mach_msg_port_descriptor_t second;
    mach_msg_max_trailer_t trailer;
} ob24_double_recv_msg_t;
#endif

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
consumption_class(kern_return_t kr_after_send, mach_port_urefs_t refs_before,
    mach_port_urefs_t refs_after_send)
{
    if (kr_after_send == KERN_INVALID_NAME ||
        kr_after_send == KERN_INVALID_RIGHT) {
        return "fully_consumed_or_name_invalid";
    }
    if (kr_after_send != KERN_SUCCESS) {
        return "unobservable";
    }
    if (refs_after_send == refs_before) {
        return "not_consumed";
    }
    if (refs_after_send == 0) {
        return "fully_consumed";
    }
    if (refs_after_send < refs_before) {
        return "partially_consumed";
    }
    return "refs_increased_or_recreated";
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
    mach_port_t cargo_port = MACH_PORT_NULL;
    mach_port_t delivered_first = MACH_PORT_NULL;
    mach_port_t delivered_second = MACH_PORT_NULL;
    kern_return_t kr_alloc_service = KERN_FAILURE;
    kern_return_t kr_insert_service_send = KERN_FAILURE;
    kern_return_t kr_alloc_cargo = KERN_FAILURE;
    kern_return_t kr_insert_cargo_send = KERN_FAILURE;
    kern_return_t kr_cargo_type_before = KERN_FAILURE;
    kern_return_t kr_cargo_refs_before = KERN_FAILURE;
    kern_return_t kr_cargo_type_after_send = KERN_FAILURE;
    kern_return_t kr_cargo_refs_after_send = KERN_FAILURE;
    kern_return_t kr_cargo_type_after_receive = KERN_FAILURE;
    kern_return_t kr_cargo_refs_after_receive = KERN_FAILURE;
    kern_return_t kr_deallocate_first = KERN_FAILURE;
    kern_return_t kr_deallocate_second = KERN_FAILURE;
    kern_return_t kr_destroy_cargo = KERN_FAILURE;
    kern_return_t kr_destroy_service = KERN_FAILURE;
    mach_msg_return_t mr_send = MACH_SEND_INVALID_DEST;
    mach_msg_return_t mr_receive = MACH_RCV_INVALID_NAME;
    mach_port_type_t cargo_type_before = 0;
    mach_port_type_t cargo_type_after_send = 0;
    mach_port_type_t cargo_type_after_receive = 0;
    mach_port_urefs_t cargo_refs_before = 0;
    mach_port_urefs_t cargo_refs_after_send = 0;
    mach_port_urefs_t cargo_refs_after_receive = 0;
    unsigned int sent_msgh_bits = 0;
    unsigned int received_msgh_bits = 0;
    unsigned int received_descriptor_count = 0;
    unsigned int first_descriptor_type = 0;
    unsigned int first_descriptor_disposition = 0;
    unsigned int second_descriptor_type = 0;
    unsigned int second_descriptor_disposition = 0;
    int received_msgh_id = 0;
    int cleanup_delta = 0;
    bool cleanup_ok = false;

#ifdef __APPLE__
    kr_alloc_service = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &service_port);
    if (kr_alloc_service == KERN_SUCCESS) {
        kr_insert_service_send = mach_port_insert_right(mach_task_self(),
            service_port, service_port, MACH_MSG_TYPE_MAKE_SEND);
    }
    if (kr_insert_service_send == KERN_SUCCESS) {
        kr_alloc_cargo = mach_port_allocate(mach_task_self(),
            MACH_PORT_RIGHT_RECEIVE, &cargo_port);
    }
    if (kr_alloc_cargo == KERN_SUCCESS) {
        kr_insert_cargo_send = mach_port_insert_right(mach_task_self(),
            cargo_port, cargo_port, MACH_MSG_TYPE_MAKE_SEND);
    }
    if (kr_insert_cargo_send == KERN_SUCCESS) {
        kr_cargo_type_before = mach_port_type(mach_task_self(), cargo_port,
            &cargo_type_before);
        kr_cargo_refs_before = mach_port_get_refs(mach_task_self(),
            cargo_port, MACH_PORT_RIGHT_SEND, &cargo_refs_before);
    }

    if (kr_cargo_type_before == KERN_SUCCESS &&
        kr_cargo_refs_before == KERN_SUCCESS) {
        ob24_double_send_msg_t msg;
        memset(&msg, 0, sizeof(msg));
        sent_msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) |
            MACH_MSGH_BITS_COMPLEX;
        msg.header.msgh_bits = sent_msgh_bits;
        msg.header.msgh_size = (mach_msg_size_t)sizeof(msg);
        msg.header.msgh_remote_port = service_port;
        msg.header.msgh_local_port = MACH_PORT_NULL;
        msg.header.msgh_id = OB24_DOUBLE_MSG_ID;
        msg.body.msgh_descriptor_count = 2;
        msg.first.name = cargo_port;
        msg.first.disposition = MACH_MSG_TYPE_MOVE_SEND;
        msg.first.type = MACH_MSG_PORT_DESCRIPTOR;
        msg.second.name = cargo_port;
        msg.second.disposition = MACH_MSG_TYPE_MOVE_SEND;
        msg.second.type = MACH_MSG_PORT_DESCRIPTOR;

        mr_send = mach_msg(&msg.header,
            MACH_SEND_MSG | MACH_SEND_TIMEOUT,
            msg.header.msgh_size,
            0,
            MACH_PORT_NULL,
            OB24_SEND_TIMEOUT_MS,
            MACH_PORT_NULL);
    }

    kr_cargo_type_after_send = mach_port_type(mach_task_self(), cargo_port,
        &cargo_type_after_send);
    kr_cargo_refs_after_send = mach_port_get_refs(mach_task_self(),
        cargo_port, MACH_PORT_RIGHT_SEND, &cargo_refs_after_send);

    if (kr_alloc_service == KERN_SUCCESS) {
        ob24_double_recv_msg_t recv_msg;
        memset(&recv_msg, 0, sizeof(recv_msg));
        mr_receive = mach_msg(&recv_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0,
            (mach_msg_size_t)sizeof(recv_msg),
            service_port,
            OB24_RECV_TIMEOUT_MS,
            MACH_PORT_NULL);
        if (mr_receive == MACH_MSG_SUCCESS) {
            received_msgh_bits = recv_msg.header.msgh_bits;
            received_msgh_id = recv_msg.header.msgh_id;
            received_descriptor_count = recv_msg.body.msgh_descriptor_count;
            delivered_first = recv_msg.first.name;
            delivered_second = recv_msg.second.name;
            first_descriptor_type = recv_msg.first.type;
            first_descriptor_disposition = recv_msg.first.disposition;
            second_descriptor_type = recv_msg.second.type;
            second_descriptor_disposition = recv_msg.second.disposition;

            if (delivered_first != MACH_PORT_NULL) {
                kr_deallocate_first = mach_port_deallocate(mach_task_self(),
                    delivered_first);
            }
            if (delivered_second != MACH_PORT_NULL) {
                kr_deallocate_second = mach_port_deallocate(mach_task_self(),
                    delivered_second);
            }
        }
    }

    kr_cargo_type_after_receive = mach_port_type(mach_task_self(), cargo_port,
        &cargo_type_after_receive);
    kr_cargo_refs_after_receive = mach_port_get_refs(mach_task_self(),
        cargo_port, MACH_PORT_RIGHT_SEND, &cargo_refs_after_receive);

    if (kr_alloc_cargo == KERN_SUCCESS) {
        kr_destroy_cargo = mach_port_destroy(mach_task_self(), cargo_port);
    }
    if (kr_alloc_service == KERN_SUCCESS) {
        kr_destroy_service = mach_port_destroy(mach_task_self(), service_port);
    }

    nx_baseline_free(&after);
    nx_baseline_capture(&after);
    cleanup_ok = nx_baseline_compare(&before, &after, &cleanup_delta);
#endif

    bool setup_ok =
        (kr_alloc_service == KERN_SUCCESS &&
        kr_insert_service_send == KERN_SUCCESS &&
        kr_alloc_cargo == KERN_SUCCESS &&
        kr_insert_cargo_send == KERN_SUCCESS &&
        kr_cargo_type_before == KERN_SUCCESS &&
        kr_cargo_refs_before == KERN_SUCCESS);
    bool send_succeeded = (mr_send == MACH_MSG_SUCCESS);
    bool send_failed = !send_succeeded;
    bool delivery_observed = (mr_receive == MACH_MSG_SUCCESS);
    bool coherent_path =
        (send_failed && mr_receive == MACH_RCV_TIMED_OUT) ||
        (send_succeeded && delivery_observed);

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
    } else if (!setup_ok) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "setup failed";
    } else if (!coherent_path) {
        status = NX_STATUS_FAIL;
        notes = "double MOVE_SEND delivery did not match send result";
    } else if (kr_destroy_cargo != KERN_SUCCESS ||
        kr_destroy_service != KERN_SUCCESS) {
        status = NX_STATUS_FAIL;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "cleanup destroy failed";
    } else if (after.kr != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE;
        sclass = NX_CLASS_PROBE_FAILURE;
        notes = "final mach_port_names failed";
    } else if (!cleanup_ok) {
        status = NX_STATUS_FAIL;
        notes = "port namespace did not return to baseline";
    }
#endif

    nx_json_begin_object(&j);
    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }
    nx_result_emit_header(&j, agent,
        "macos_m2_double_move_send_descriptor",
        NULL, NULL, status, sclass);
    nx_env_emit(&j);

    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", hex32(sent_msgh_bits));
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
    nx_json_key_int(&j, "descriptor_count", 2);
    nx_json_key(&j, "descriptors");
    nx_json_begin_array(&j);
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "cargo_send_descriptor_1");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_SEND");
    nx_json_key_string(&j, "right_type_after",
        nx_port_type_str(cargo_type_after_send));
    nx_json_end_object(&j);
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "cargo_send_descriptor_2");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_SEND");
    nx_json_key_string(&j, "right_type_after",
        nx_port_type_str(cargo_type_after_send));
    nx_json_end_object(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_service",
        nx_kern_return_str(kr_alloc_service), kr_alloc_service, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_service_make_send",
        nx_kern_return_str(kr_insert_service_send), kr_insert_service_send,
        false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_cargo",
        nx_kern_return_str(kr_alloc_cargo), kr_alloc_cargo, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_cargo_make_send",
        nx_kern_return_str(kr_insert_cargo_send), kr_insert_cargo_send,
        false, 0);
    nx_result_emit_return(&j, "mach_port_type_cargo_before_send",
        nx_kern_return_str(kr_cargo_type_before), kr_cargo_type_before,
        false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_cargo_before_send",
        nx_kern_return_str(kr_cargo_refs_before), kr_cargo_refs_before,
        false, 0);
    nx_result_emit_return(&j, "mach_msg_send_double_move_send_descriptor",
        nx_msg_return_str(mr_send), mr_send, false, 0);
    nx_result_emit_return(&j, "mach_port_type_cargo_after_send",
        nx_kern_return_str(kr_cargo_type_after_send),
        kr_cargo_type_after_send, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_cargo_after_send",
        nx_kern_return_str(kr_cargo_refs_after_send),
        kr_cargo_refs_after_send, false, 0);
    nx_result_emit_return(&j, "mach_msg_receive_after_double_move_send",
        nx_msg_return_str(mr_receive), mr_receive, false, 0);
    if (mr_receive == MACH_MSG_SUCCESS) {
        nx_result_emit_return(&j, "mach_port_deallocate_delivered_first",
            nx_kern_return_str(kr_deallocate_first),
            kr_deallocate_first, false, 0);
        nx_result_emit_return(&j, "mach_port_deallocate_delivered_second",
            nx_kern_return_str(kr_deallocate_second),
            kr_deallocate_second, false, 0);
    }
    nx_result_emit_return(&j, "mach_port_type_cargo_after_receive",
        nx_kern_return_str(kr_cargo_type_after_receive),
        kr_cargo_type_after_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_get_refs_cargo_after_receive",
        nx_kern_return_str(kr_cargo_refs_after_receive),
        kr_cargo_refs_after_receive, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_cargo",
        nx_kern_return_str(kr_destroy_cargo), kr_destroy_cargo, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_service",
        nx_kern_return_str(kr_destroy_service), kr_destroy_service, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_result_emit_right_delta(&j,
        "double MOVE_SEND at send return",
        "cargo_port",
        "MACH_PORT_RIGHT_SEND",
        kr_cargo_refs_before == KERN_SUCCESS ? cargo_refs_before : -1,
        kr_cargo_refs_after_send == KERN_SUCCESS ?
            cargo_refs_after_send : -1,
        -1, -1, consumption_class(kr_cargo_refs_after_send,
            cargo_refs_before, cargo_refs_after_send));
    nx_result_emit_right_delta(&j,
        "double MOVE_SEND after receive attempt",
        "cargo_port",
        "MACH_PORT_RIGHT_SEND",
        kr_cargo_refs_after_send == KERN_SUCCESS ?
            cargo_refs_after_send : -1,
        kr_cargo_refs_after_receive == KERN_SUCCESS ?
            cargo_refs_after_receive : -1,
        -1, -1, "recorded");
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "send_succeeded", send_succeeded);
    nx_json_key_string(&j, "send_return", nx_msg_return_str(mr_send));
    nx_json_key_string(&j, "sent_msgh_bits_raw_hex",
        hex32(sent_msgh_bits));
    nx_json_key_string(&j, "descriptor_1_disposition",
        "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "descriptor_2_disposition",
        "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "cargo_type_before",
        nx_port_type_str(cargo_type_before));
    nx_json_key_int(&j, "cargo_send_refs_before", cargo_refs_before);
    nx_json_key_string(&j, "cargo_type_after_send",
        nx_port_type_str(cargo_type_after_send));
    nx_json_key_int(&j, "cargo_send_refs_after_send",
        kr_cargo_refs_after_send == KERN_SUCCESS ?
            (long long)cargo_refs_after_send : -1);
    nx_json_key_string(&j, "sender_consumption_class",
        consumption_class(kr_cargo_refs_after_send, cargo_refs_before,
            cargo_refs_after_send));
    nx_json_key_bool(&j, "message_delivered", delivery_observed);
    nx_json_key_string(&j, "receive_after_send",
        nx_msg_return_str(mr_receive));
    nx_json_key_string(&j, "received_msgh_bits_raw_hex",
        hex32(received_msgh_bits));
    nx_json_key_int(&j, "received_msgh_id", received_msgh_id);
    nx_json_key_int(&j, "received_descriptor_count",
        received_descriptor_count);
    nx_json_key_string(&j, "received_first_descriptor_type",
        descriptor_type_str(first_descriptor_type));
    nx_json_key_string(&j, "received_first_descriptor_disposition",
        disposition_str(first_descriptor_disposition));
    nx_json_key_string(&j, "received_second_descriptor_type",
        descriptor_type_str(second_descriptor_type));
    nx_json_key_string(&j, "received_second_descriptor_disposition",
        disposition_str(second_descriptor_disposition));
    nx_json_key_bool(&j, "delivered_descriptor_names_equal",
        delivered_first != MACH_PORT_NULL && delivered_first == delivered_second);
    nx_json_key_string(&j, "deallocate_first_delivered",
        nx_kern_return_str(kr_deallocate_first));
    nx_json_key_string(&j, "deallocate_second_delivered",
        nx_kern_return_str(kr_deallocate_second));
    nx_json_key_string(&j, "cargo_type_after_receive",
        nx_port_type_str(cargo_type_after_receive));
    nx_json_key_int(&j, "cargo_send_refs_after_receive",
        kr_cargo_refs_after_receive == KERN_SUCCESS ?
            (long long)cargo_refs_after_receive : -1);
    nx_json_key_bool(&j, "coherent_send_receive_path", coherent_path);
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
