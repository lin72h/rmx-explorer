/*
 * port_set.c — Foundation port-set routing probe (block-080a #5).
 *
 * Test ID: macos_foundation_port_set
 *
 * Exercises the port-set RECEIVE ROUTING contract (mx's stronger version):
 *   - mach_port_allocate(MACH_PORT_RIGHT_PORT_SET) yields a PORT_SET right
 *   - a receive-right member is allocated, given a send right, and added to the
 *     set via mach_port_move_member
 *   - a message is sent to the member (COPY_SEND), then received THROUGH the
 *     port set (rcv_name == the set) -> MACH_MSG_SUCCESS
 *   - routing contract: the received message's local_port equals the member
 *   - the member is removed (move_member to MACH_PORT_NULL), then both the
 *     member and the set are destroyed; namespace baseline returns to 0
 *
 * Raw port names are emitted for provenance but are NOT a comparison axis.
 *
 * Emits a complete nx-r64z.macos-oracle.v1 JSON result to stdout.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nx_json.h"
#include "nx_result.h"
#include "nx_env.h"
#include "nx_mach_utils.h"

#define PORT_SET_MSG_ID 0x50535354  /* "PSST" */

#ifdef __APPLE__
#include <mach/mach.h>

typedef struct {
    mach_msg_header_t header;
} ps_send_msg_t;

typedef struct {
    mach_msg_header_t      header;
    mach_msg_max_trailer_t trailer;
} ps_recv_msg_t;
#endif

static const char *
hex32(unsigned int value)
{
    static char bufs[2][32];
    static unsigned int idx;
    char *buf = bufs[idx++ % 2];
    snprintf(buf, 32, "0x%x", value);
    return buf;
}

int
main(void)
{
    nx_json_t j;
    nx_json_init(&j, stdout);

    nx_baseline_t before, after;
    nx_baseline_capture(&before);

    mach_port_t       pset           = MACH_PORT_NULL;
    mach_port_t       member         = MACH_PORT_NULL;
    mach_port_type_t  set_type       = 0;
    kern_return_t     kr_alloc_set   = KERN_FAILURE;
    kern_return_t     kr_alloc_mem   = KERN_FAILURE;
    kern_return_t     kr_type_set    = KERN_FAILURE;
    kern_return_t     kr_insert_send = KERN_FAILURE;
    kern_return_t     kr_move        = KERN_FAILURE;
    kern_return_t     kr_unmove      = KERN_FAILURE;
    kern_return_t     kr_destroy_mem = KERN_FAILURE;
    kern_return_t     kr_destroy_set = KERN_FAILURE;
    mach_msg_return_t mr_send        = MACH_SEND_INVALID_DEST;
    mach_msg_return_t mr_recv        = MACH_RCV_INVALID_NAME;

    unsigned int sent_msgh_bits = 0;
    bool routed_to_member = false;
    bool id_matches = false;

#ifdef __APPLE__
    kr_alloc_set = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_PORT_SET, &pset);
    kr_alloc_mem = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &member);

    if (kr_alloc_set == KERN_SUCCESS) {
        kr_type_set = mach_port_type(mach_task_self(), pset, &set_type);
    }

    if (kr_alloc_set == KERN_SUCCESS && kr_alloc_mem == KERN_SUCCESS) {
        kr_insert_send = mach_port_insert_right(mach_task_self(),
            member, member, MACH_MSG_TYPE_MAKE_SEND);
    }

    if (kr_insert_send == KERN_SUCCESS) {
        kr_move = mach_port_move_member(mach_task_self(), member, pset);
    }

    if (kr_move == KERN_SUCCESS) {
        ps_send_msg_t send_msg;
        memset(&send_msg, 0, sizeof(send_msg));
        sent_msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
        send_msg.header.msgh_bits = sent_msgh_bits;
        send_msg.header.msgh_size = (mach_msg_size_t)sizeof(send_msg);
        send_msg.header.msgh_remote_port = member;
        send_msg.header.msgh_local_port = MACH_PORT_NULL;
        send_msg.header.msgh_id = PORT_SET_MSG_ID;

        mr_send = mach_msg(&send_msg.header,
            MACH_SEND_MSG | MACH_SEND_TIMEOUT,
            send_msg.header.msgh_size, 0,
            MACH_PORT_NULL, 5000, MACH_PORT_NULL);
    }

    if (mr_send == MACH_MSG_SUCCESS) {
        ps_recv_msg_t recv_msg;
        memset(&recv_msg, 0, sizeof(recv_msg));
        mr_recv = mach_msg(&recv_msg.header,
            MACH_RCV_MSG | MACH_RCV_TIMEOUT,
            0, (mach_msg_size_t)sizeof(recv_msg),
            pset, 5000, MACH_PORT_NULL);

        if (mr_recv == MACH_MSG_SUCCESS) {
            routed_to_member = (recv_msg.header.msgh_local_port == member);
            id_matches = (recv_msg.header.msgh_id == PORT_SET_MSG_ID);
        }
    }

    if (kr_move == KERN_SUCCESS) {
        kr_unmove = mach_port_move_member(mach_task_self(),
            member, MACH_PORT_NULL);
    }

    if (kr_alloc_mem == KERN_SUCCESS) {
        kr_destroy_mem = mach_port_destroy(mach_task_self(), member);
    }
    if (kr_alloc_set == KERN_SUCCESS) {
        kr_destroy_set = mach_port_destroy(mach_task_self(), pset);
    }
#endif /* __APPLE__ */

#ifndef __APPLE__
    (void)pset;
    (void)member;
#endif

    nx_baseline_capture(&after);
    int delta = 0;
    bool baseline_ok = nx_baseline_compare(&before, &after, &delta);

    nx_status_t status = NX_STATUS_PASS;
    nx_semantic_class_t sclass = NX_CLASS_EXACT_CONTRACT;
    const char *notes = "";
    bool cleanup_ok = baseline_ok;
    const char *cleanup_notes = baseline_ok ? "" : "namespace delta detected";

#ifndef __APPLE__
    status = NX_STATUS_SKIP;
    sclass = NX_CLASS_NOT_OBSERVABLE;
    notes = "non-macOS host: Mach APIs unavailable, pipeline smoke only";
    cleanup_ok = true;
    cleanup_notes = "not applicable on non-macOS host";
#else
    if (kr_alloc_set != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(PORT_SET) failed";
    } else if (kr_alloc_mem != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_allocate(RECEIVE) member failed";
    } else if (kr_type_set != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_type on the port set failed";
    } else if (kr_insert_send != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_insert_right(MAKE_SEND) on member failed";
    } else if (kr_move != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_move_member into the set failed";
    } else if (mr_send != MACH_MSG_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_msg SEND to member failed";
    } else if (mr_recv != MACH_MSG_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "mach_msg RECEIVE via port set did not return MACH_MSG_SUCCESS";
    } else if (!routed_to_member) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "received message was not routed through the set to the member";
    } else if (!id_matches) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
        notes = "received message id did not match the sent message id";
    } else if (kr_unmove != KERN_SUCCESS) {
        status = NX_STATUS_PROBE_FAILURE; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "mach_port_move_member out of the set failed";
    } else if (kr_destroy_mem != KERN_SUCCESS || kr_destroy_set != KERN_SUCCESS) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_PROBE_FAILURE;
        notes = "port-set member or set destroy failed";
    } else if (!baseline_ok) {
        status = NX_STATUS_FAIL; sclass = NX_CLASS_EXACT_CONTRACT;
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
        "macos_foundation_port_set",
        NULL, NULL,
        status, sclass);

    nx_env_emit(&j);

    /* Message: routed send/receive-through-set summary */
    nx_json_key(&j, "message");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "msgh_bits", hex32(sent_msgh_bits));
    nx_json_key(&j, "remote_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "member");
    nx_json_key_string(&j, "disposition", "MACH_MSG_TYPE_COPY_SEND");
    nx_json_key_string(&j, "right_type", "MACH_PORT_TYPE_SEND");
    nx_json_end_object(&j);
    nx_json_key(&j, "local_port");
    nx_json_begin_object(&j);
    nx_json_key_string(&j, "name", "port_set");
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
    nx_json_key_int(&j, "descriptor_count", 0);
    nx_json_key(&j, "descriptors");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);
    nx_json_end_object(&j);

    nx_json_key(&j, "returns");
    nx_json_begin_array(&j);
    nx_result_emit_return(&j, "mach_port_names_before",
        nx_kern_return_str(before.kr), before.kr, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_port_set",
        nx_kern_return_str(kr_alloc_set), kr_alloc_set, false, 0);
    nx_result_emit_return(&j, "mach_port_allocate_member",
        nx_kern_return_str(kr_alloc_mem), kr_alloc_mem, false, 0);
    nx_result_emit_return(&j, "mach_port_type_port_set",
        nx_kern_return_str(kr_type_set), kr_type_set, false, 0);
    nx_result_emit_return(&j, "mach_port_insert_right_make_send",
        nx_kern_return_str(kr_insert_send), kr_insert_send, false, 0);
    nx_result_emit_return(&j, "mach_port_move_member_into_set",
        nx_kern_return_str(kr_move), kr_move, false, 0);
    nx_result_emit_return(&j, "mach_msg_send_to_member",
        nx_msg_return_str(mr_send), (long long)mr_send, false, 0);
    nx_result_emit_return(&j, "mach_msg_receive_via_port_set",
        nx_msg_return_str(mr_recv), (long long)mr_recv, false, 0);
    nx_result_emit_return(&j, "mach_port_move_member_out_of_set",
        nx_kern_return_str(kr_unmove), kr_unmove, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_member",
        nx_kern_return_str(kr_destroy_mem), kr_destroy_mem, false, 0);
    nx_result_emit_return(&j, "mach_port_destroy_port_set",
        nx_kern_return_str(kr_destroy_set), kr_destroy_set, false, 0);
    nx_result_emit_return(&j, "mach_port_names_after",
        nx_kern_return_str(after.kr), after.kr, false, 0);
    nx_json_end_array(&j);

    nx_json_key(&j, "right_deltas");
    nx_json_begin_array(&j);
    nx_json_end_array(&j);

    nx_json_key(&j, "observations");
    nx_json_begin_object(&j);
    nx_json_key_bool(&j, "port_set_allocated", kr_alloc_set == KERN_SUCCESS);
    nx_json_key_string(&j, "port_set_type",
        kr_type_set == KERN_SUCCESS ? nx_port_type_str(set_type) : "unknown");
    nx_json_key_bool(&j, "insert_send_succeeded", kr_insert_send == KERN_SUCCESS);
    nx_json_key_bool(&j, "move_member_succeeded", kr_move == KERN_SUCCESS);
    nx_json_key_bool(&j, "send_succeeded", mr_send == MACH_MSG_SUCCESS);
    nx_json_key_bool(&j, "receive_via_set_succeeded", mr_recv == MACH_MSG_SUCCESS);
    nx_json_key_bool(&j, "message_routed_to_member", routed_to_member);
    nx_json_key_bool(&j, "received_msgh_id_matches", id_matches);
    nx_json_key_bool(&j, "destroy_succeeded",
        kr_destroy_mem == KERN_SUCCESS && kr_destroy_set == KERN_SUCCESS);
    nx_json_end_object(&j);

    nx_result_emit_cleanup(&j, cleanup_ok, cleanup_notes);
    nx_json_key_string(&j, "notes", notes);

    nx_json_end_object(&j);
    fprintf(stdout, "\n");

    nx_baseline_free(&before);
    nx_baseline_free(&after);

    return (status == NX_STATUS_PASS || status == NX_STATUS_SKIP) ? 0 : 1;
}
