/*
 * dead_name_descriptor_right.c - Dead/nonexistent descriptor source probe.
 *
 * Test ID: macos_m2_dead_name_descriptor_right
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

#define OB24_DEAD_MSG_ID     0x4f423242
#define OB24_NONEXIST_MSG_ID 0x4f423243
#define OB24_SEND_TIMEOUT_MS 500
#define OB24_RECV_TIMEOUT_MS 100

#ifdef __APPLE__
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t cargo;
} ob24_dead_send_msg_t;

typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t cargo;
    mach_msg_max_trailer_t trailer;
} ob24_dead_recv_msg_t;
#endif

typedef struct {
    const char *name;
    int use_dead_name;
    nx_baseline_t before;
    nx_baseline_t after;
    mach_port_t service_port;
    mach_port_t source_name;
    mach_port_t delivered_port;
    kern_return_t kr_alloc_service;
    kern_return_t kr_insert_service_send;
    kern_return_t kr_alloc_dead_name;
    kern_return_t kr_source_type_before;
    kern_return_t kr_source_refs_before;
    kern_return_t kr_source_type_after;
    kern_return_t kr_source_refs_after;
    kern_return_t kr_deallocate_source;
    kern_return_t kr_deallocate_delivered;
    kern_return_t kr_destroy_service;
    mach_msg_return_t mr_send;
    mach_msg_return_t mr_receive;
    mach_port_type_t source_type_before;
    mach_port_type_t source_type_after;
    mach_port_urefs_t source_refs_before;
    mach_port_urefs_t source_refs_after;
    unsigned int sent_msgh_bits;
    unsigned int received_msgh_bits;
    unsigned int received_descriptor_count;
    unsigned int received_descriptor_type;
    unsigned int received_descriptor_disposition;
    int received_msgh_id;
    int cleanup_delta;
    bool cleanup_ok;
} ob24_case_t;

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

static void
case_init(ob24_case_t *c, const char *name, int use_dead_name)
{
    memset(c, 0, sizeof(*c));
    c->name = name;
    c->use_dead_name = use_dead_name;
    c->service_port = MACH_PORT_NULL;
    c->source_name = MACH_PORT_NULL;
    c->delivered_port = MACH_PORT_NULL;
    c->kr_alloc_service = KERN_FAILURE;
    c->kr_insert_service_send = KERN_FAILURE;
    c->kr_alloc_dead_name = KERN_FAILURE;
    c->kr_source_type_before = KERN_FAILURE;
    c->kr_source_refs_before = KERN_FAILURE;
    c->kr_source_type_after = KERN_FAILURE;
    c->kr_source_refs_after = KERN_FAILURE;
    c->kr_deallocate_source = KERN_FAILURE;
    c->kr_deallocate_delivered = KERN_FAILURE;
    c->kr_destroy_service = KERN_FAILURE;
    c->mr_send = MACH_SEND_INVALID_DEST;
    c->mr_receive = MACH_RCV_INVALID_NAME;
}

#ifdef __APPLE__
static mach_port_t
find_nonexistent_name(void)
{
    mach_port_t candidate = (mach_port_t)0x6f240003u;
    for (unsigned int i = 0; i < 1024; i++) {
        mach_port_type_t type = 0;
        if (mach_port_type(mach_task_self(), candidate, &type) !=
            KERN_SUCCESS) {
            return candidate;
        }
        candidate += 0x100u;
    }
    return (mach_port_t)0x6f240003u;
}

static void
run_case(ob24_case_t *c, mach_msg_id_t msg_id)
{
    nx_baseline_capture(&c->before);
    nx_baseline_capture(&c->after);

    c->kr_alloc_service = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &c->service_port);
    if (c->kr_alloc_service == KERN_SUCCESS) {
        c->kr_insert_service_send = mach_port_insert_right(mach_task_self(),
            c->service_port, c->service_port, MACH_MSG_TYPE_MAKE_SEND);
    }

    if (c->kr_insert_service_send == KERN_SUCCESS) {
        if (c->use_dead_name) {
            c->kr_alloc_dead_name = mach_port_allocate(mach_task_self(),
                MACH_PORT_RIGHT_DEAD_NAME, &c->source_name);
        } else {
            c->kr_alloc_dead_name = KERN_SUCCESS;
            c->source_name = find_nonexistent_name();
        }
    }

    if (c->source_name != MACH_PORT_NULL) {
        c->kr_source_type_before = mach_port_type(mach_task_self(),
            c->source_name, &c->source_type_before);
        c->kr_source_refs_before = mach_port_get_refs(mach_task_self(),
            c->source_name,
            c->use_dead_name ? MACH_PORT_RIGHT_DEAD_NAME : MACH_PORT_RIGHT_SEND,
            &c->source_refs_before);
    }

    if (c->kr_insert_service_send == KERN_SUCCESS &&
        c->source_name != MACH_PORT_NULL) {
        ob24_dead_send_msg_t msg;
        memset(&msg, 0, sizeof(msg));
        c->sent_msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) |
            MACH_MSGH_BITS_COMPLEX;
        msg.header.msgh_bits = c->sent_msgh_bits;
        msg.header.msgh_size = (mach_msg_size_t)sizeof(msg);
        msg.header.msgh_remote_port = c->service_port;
        msg.header.msgh_local_port = MACH_PORT_NULL;
        msg.header.msgh_id = msg_id;
        msg.body.msgh_descriptor_count = 1;
        msg.cargo.name = c->source_name;
        msg.cargo.disposition = MACH_MSG_TYPE_MOVE_SEND;
        msg.cargo.type = MACH_MSG_PORT_DESCRIPTOR;

        c->mr_send = mach_msg(&msg.header,
            MACH_SEND_MSG | MACH_SEND_TIMEOUT,
            msg.header.msgh_size,
            0,
            MACH_PORT_NULL,
            OB24_SEND_TIMEOUT_MS,
            MACH_PORT_NULL);
    }

    if (c->source_name != MACH_PORT_NULL) {
        c->kr_source_type_after = mach_port_type(mach_task_self(),
            c->source_name, &c->source_type_after);
        c->kr_source_refs_after = mach_port_get_refs(mach_task_self(),
            c->source_name,
            c->use_dead_name ? MACH_PORT_RIGHT_DEAD_NAME : MACH_PORT_RIGHT_SEND,
            &c->source_refs_after);
    }

    if (c->kr_alloc_service == KERN_SUCCESS) {
        ob24_dead_recv_msg_t recv_msg;
        memset(&recv_msg, 0, sizeof(recv_msg));
        c->mr_receive = mach_msg(&recv_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0,
            (mach_msg_size_t)sizeof(recv_msg),
            c->service_port,
            OB24_RECV_TIMEOUT_MS,
            MACH_PORT_NULL);
        if (c->mr_receive == MACH_MSG_SUCCESS) {
            c->received_msgh_bits = recv_msg.header.msgh_bits;
            c->received_msgh_id = recv_msg.header.msgh_id;
            c->received_descriptor_count =
                recv_msg.body.msgh_descriptor_count;
            c->delivered_port = recv_msg.cargo.name;
            c->received_descriptor_type = recv_msg.cargo.type;
            c->received_descriptor_disposition = recv_msg.cargo.disposition;
            if (c->delivered_port != MACH_PORT_NULL) {
                c->kr_deallocate_delivered = mach_port_deallocate(
                    mach_task_self(), c->delivered_port);
            }
        }
    }

    if (c->use_dead_name && c->source_name != MACH_PORT_NULL) {
        c->kr_deallocate_source = mach_port_deallocate(mach_task_self(),
            c->source_name);
    }
    if (c->kr_alloc_service == KERN_SUCCESS) {
        c->kr_destroy_service = mach_port_destroy(mach_task_self(),
            c->service_port);
    }

    nx_baseline_free(&c->after);
    nx_baseline_capture(&c->after);
    c->cleanup_ok = nx_baseline_compare(&c->before, &c->after,
        &c->cleanup_delta);
}
#endif

static bool
case_dead_name_consumed_and_delivered(const ob24_case_t *c)
{
    return c->use_dead_name &&
        c->kr_source_type_before == KERN_SUCCESS &&
        c->source_type_before == MACH_PORT_TYPE_DEAD_NAME &&
        c->kr_source_refs_before == KERN_SUCCESS &&
        c->source_refs_before == 1 &&
        c->mr_send == MACH_MSG_SUCCESS &&
        c->kr_source_type_after == KERN_INVALID_NAME &&
        c->kr_source_refs_after == KERN_INVALID_NAME &&
        c->mr_receive == MACH_MSG_SUCCESS &&
        c->received_descriptor_count == 1 &&
        c->kr_deallocate_delivered == KERN_SUCCESS &&
        c->kr_deallocate_source == KERN_INVALID_NAME;
}

static bool
case_nonexistent_rejected(const ob24_case_t *c)
{
    return c->kr_source_type_before == KERN_INVALID_NAME &&
        c->kr_source_refs_before == KERN_INVALID_NAME &&
        c->mr_send == MACH_SEND_INVALID_RIGHT &&
        c->kr_source_type_after == KERN_INVALID_NAME &&
        c->kr_source_refs_after == KERN_INVALID_NAME &&
        c->mr_receive == MACH_RCV_TIMED_OUT;
}

static bool
case_ok(const ob24_case_t *c)
{
    bool source_behavior_ok = c->use_dead_name ?
        case_dead_name_consumed_and_delivered(c) :
        case_nonexistent_rejected(c);

    return c->before.kr == KERN_SUCCESS &&
        c->kr_alloc_service == KERN_SUCCESS &&
        c->kr_insert_service_send == KERN_SUCCESS &&
        c->kr_alloc_dead_name == KERN_SUCCESS &&
        source_behavior_ok &&
        c->kr_destroy_service == KERN_SUCCESS &&
        c->after.kr == KERN_SUCCESS &&
        c->cleanup_ok;
}

static void
emit_case_returns(nx_json_t *j, const ob24_case_t *c)
{
    char call[128];

    snprintf(call, sizeof(call), "%s_mach_port_names_before", c->name);
    nx_result_emit_return(j, call, nx_kern_return_str(c->before.kr),
        c->before.kr, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_allocate_service", c->name);
    nx_result_emit_return(j, call, nx_kern_return_str(c->kr_alloc_service),
        c->kr_alloc_service, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_insert_right_service_make_send",
        c->name);
    nx_result_emit_return(j, call,
        nx_kern_return_str(c->kr_insert_service_send),
        c->kr_insert_service_send, false, 0);
    snprintf(call, sizeof(call), "%s_setup_source_name", c->name);
    nx_result_emit_return(j, call, nx_kern_return_str(c->kr_alloc_dead_name),
        c->kr_alloc_dead_name, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_type_source_before_send",
        c->name);
    nx_result_emit_return(j, call,
        nx_kern_return_str(c->kr_source_type_before),
        c->kr_source_type_before, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_get_refs_source_before_send",
        c->name);
    nx_result_emit_return(j, call,
        nx_kern_return_str(c->kr_source_refs_before),
        c->kr_source_refs_before, false, 0);
    snprintf(call, sizeof(call), "%s_mach_msg_send_descriptor_move_send",
        c->name);
    nx_result_emit_return(j, call, nx_msg_return_str(c->mr_send),
        c->mr_send, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_type_source_after_send",
        c->name);
    nx_result_emit_return(j, call,
        nx_kern_return_str(c->kr_source_type_after),
        c->kr_source_type_after, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_get_refs_source_after_send",
        c->name);
    nx_result_emit_return(j, call,
        nx_kern_return_str(c->kr_source_refs_after),
        c->kr_source_refs_after, false, 0);
    snprintf(call, sizeof(call), "%s_mach_msg_receive_after_send", c->name);
    nx_result_emit_return(j, call, nx_msg_return_str(c->mr_receive),
        c->mr_receive, false, 0);
    if (c->mr_receive == MACH_MSG_SUCCESS) {
        snprintf(call, sizeof(call), "%s_mach_port_deallocate_delivered",
            c->name);
        nx_result_emit_return(j, call,
            nx_kern_return_str(c->kr_deallocate_delivered),
            c->kr_deallocate_delivered, false, 0);
    }
    if (c->use_dead_name) {
        snprintf(call, sizeof(call), "%s_mach_port_deallocate_source",
            c->name);
        nx_result_emit_return(j, call,
            nx_kern_return_str(c->kr_deallocate_source),
            c->kr_deallocate_source, false, 0);
    }
    snprintf(call, sizeof(call), "%s_mach_port_destroy_service", c->name);
    nx_result_emit_return(j, call, nx_kern_return_str(c->kr_destroy_service),
        c->kr_destroy_service, false, 0);
    snprintf(call, sizeof(call), "%s_mach_port_names_after", c->name);
    nx_result_emit_return(j, call, nx_kern_return_str(c->after.kr),
        c->after.kr, false, 0);
}

static void
emit_case_observation(nx_json_t *j, const ob24_case_t *c)
{
    nx_json_begin_object(j);
    nx_json_key_string(j, "case", c->name);
    nx_json_key_string(j, "source_kind",
        c->use_dead_name ? "dead_name" : "nonexistent_name");
    nx_json_key_string(j, "descriptor_disposition",
        "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(j, "sent_msgh_bits_raw_hex",
        hex32(c->sent_msgh_bits));
    nx_json_key_string(j, "source_type_before",
        nx_port_type_str(c->source_type_before));
    nx_json_key_string(j, "source_type_before_return",
        nx_kern_return_str(c->kr_source_type_before));
    nx_json_key_int(j, "source_refs_before",
        c->kr_source_refs_before == KERN_SUCCESS ?
            (long long)c->source_refs_before : -1);
    nx_json_key_string(j, "send_return", nx_msg_return_str(c->mr_send));
    nx_json_key_bool(j, "send_rejected", c->mr_send != MACH_MSG_SUCCESS);
    nx_json_key_string(j, "source_type_after",
        nx_port_type_str(c->source_type_after));
    nx_json_key_string(j, "source_type_after_return",
        nx_kern_return_str(c->kr_source_type_after));
    nx_json_key_int(j, "source_refs_after",
        c->kr_source_refs_after == KERN_SUCCESS ?
            (long long)c->source_refs_after : -1);
    nx_json_key_bool(j, "source_unchanged",
        c->use_dead_name ? false : case_nonexistent_rejected(c));
    nx_json_key_bool(j, "accepted_behavior_matched",
        c->use_dead_name ? case_dead_name_consumed_and_delivered(c) :
        case_nonexistent_rejected(c));
    nx_json_key_string(j, "receive_after_send",
        nx_msg_return_str(c->mr_receive));
    nx_json_key_bool(j, "message_delivered",
        c->mr_receive == MACH_MSG_SUCCESS);
    nx_json_key_string(j, "received_msgh_bits_raw_hex",
        hex32(c->received_msgh_bits));
    nx_json_key_int(j, "received_msgh_id", c->received_msgh_id);
    nx_json_key_int(j, "received_descriptor_count",
        c->received_descriptor_count);
    nx_json_key_string(j, "received_descriptor_type",
        descriptor_type_str(c->received_descriptor_type));
    nx_json_key_string(j, "received_descriptor_disposition",
        disposition_str(c->received_descriptor_disposition));
    nx_json_key_bool(j, "cleanup_returned_to_baseline", c->cleanup_ok);
    nx_json_key_int(j, "cleanup_delta", c->cleanup_delta);
    nx_json_end_object(j);
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    ob24_case_t dead_case;
    ob24_case_t nonexistent_case;
    case_init(&dead_case, "dead_name", 1);
    case_init(&nonexistent_case, "nonexistent_name", 0);

#ifdef __APPLE__
    run_case(&dead_case, OB24_DEAD_MSG_ID);
    run_case(&nonexistent_case, OB24_NONEXIST_MSG_ID);
#endif

    bool all_ok = case_ok(&dead_case) && case_ok(&nonexistent_case);
    bool cleanup_ok = dead_case.cleanup_ok && nonexistent_case.cleanup_ok;

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
    if (!all_ok) {
        status = NX_STATUS_FAIL;
        notes = "dead or nonexistent descriptor source behavior violated accepted macOS contract";
    } else {
        notes = "accepted macOS behavior: dead-name descriptor sources are delivered and consumed; the old no-delivery/no-mutation expectation was wrong";
    }
#endif

    nx_json_begin_object(&j);
    const char *agent = getenv("NX_ORACLE_AGENT");
    if (agent == NULL || agent[0] == '\0') {
        agent = "development";
    }
    nx_result_emit_header(&j, agent,
        "macos_m2_dead_name_descriptor_right",
        NULL, NULL, status, sclass);
    nx_env_emit(&j);

    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", "0x80000013");
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
    nx_json_key_string(&j, "name", "dead_name_descriptor");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "right_type_before", "MACH_PORT_TYPE_DEAD_NAME");
    nx_json_key_string(&j, "right_type_after",
        nx_port_type_str(dead_case.source_type_after));
    nx_json_end_object(&j);
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "nonexistent_name_descriptor");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_MOVE_SEND");
    nx_json_key_string(&j, "right_type_before", "KERN_INVALID_NAME");
    nx_json_key_string(&j, "right_type_after", "KERN_INVALID_NAME");
    nx_json_end_object(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    emit_case_returns(&j, &dead_case);
    emit_case_returns(&j, &nonexistent_case);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_result_emit_right_delta(&j,
        "dead name descriptor source",
        "dead_name",
        "MACH_PORT_RIGHT_DEAD_NAME",
        dead_case.kr_source_refs_before == KERN_SUCCESS ?
            (long long)dead_case.source_refs_before : -1,
        dead_case.kr_source_refs_after == KERN_SUCCESS ?
            (long long)dead_case.source_refs_after : -1,
        -1, -1, "consumed and delivered");
    nx_result_emit_right_delta(&j,
        "nonexistent descriptor source",
        "nonexistent_name",
        "MACH_PORT_RIGHT_SEND",
        -1, -1, -1, -1, "not present");
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key(&j, "cases");
    nx_json_begin_array(&j);
    emit_case_observation(&j, &dead_case);
    emit_case_observation(&j, &nonexistent_case);
    nx_json_end_array(&j);
    nx_json_key_bool(&j, "all_sends_rejected",
        dead_case.mr_send != MACH_MSG_SUCCESS &&
        nonexistent_case.mr_send != MACH_MSG_SUCCESS);
    nx_json_key_bool(&j, "any_message_delivered",
        dead_case.mr_receive == MACH_MSG_SUCCESS ||
        nonexistent_case.mr_receive == MACH_MSG_SUCCESS);
    nx_json_key_bool(&j, "all_sources_unchanged",
        false);
    nx_json_key_bool(&j, "dead_name_accepted_contract",
        case_dead_name_consumed_and_delivered(&dead_case));
    nx_json_key_bool(&j, "nonexistent_name_accepted_contract",
        case_nonexistent_rejected(&nonexistent_case));
    nx_json_key_string(&j, "old_expectation_note",
        "old expectation was no-delivery/no-mutation for dead names; native macOS delivers and consumes dead-name descriptor sources");
    nx_json_key_bool(&j, "all_cleanup_returned_to_baseline", cleanup_ok);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);
    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&dead_case.before);
    nx_baseline_free(&dead_case.after);
    nx_baseline_free(&nonexistent_case.before);
    nx_baseline_free(&nonexistent_case.after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
