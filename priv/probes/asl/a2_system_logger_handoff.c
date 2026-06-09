/*
 * ASL A2 probe: launchd/bootstrap handoff for com.apple.system.logger plus
 * donor ASL client lookup. This file owns only the harness-side server/client
 * probes. The donor lookup function is linked from a generated extraction of
 * pinned NextBSD lib/libasl/asl_core.c by the Oracle host build.
 */

#include <errno.h>
#include <mach/mach.h>
#include <sha256.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "asl_ipc.h"

#define LAUNCH_KEY_CHECKIN "CheckIn"
#define LAUNCH_JOBKEY_MACHSERVICES "MachServices"
#define ASL_A2_SERVICE_NAME "com.apple.system.logger"
#define ASL_A2_NONCE "rmxos-asl-a2-nonce-v1"
#define ASL_A2_PAYLOAD \
	"[Sender oracle_asl_a2_client] [Facility com.rmxos.oracle.asl] [Level 5] [Message " ASL_A2_NONCE "]"

extern mach_port_t asl_core_get_service_port(int reset);
typedef struct _launch_data *launch_data_t;
extern launch_data_t launch_data_new_string(const char *);
extern void launch_data_free(launch_data_t);
extern launch_data_t launch_data_dict_lookup(const launch_data_t, const char *);
extern mach_port_t launch_data_get_machport(const launch_data_t);
extern launch_data_t launch_msg(const launch_data_t);

int
fileport_makeport(int fd, mach_port_t *port)
{
	(void)fd;
	if (port != NULL) *port = MACH_PORT_NULL;
	return ENOTSUP;
}

int
fileport_makefd(mach_port_t port)
{
	(void)port;
	errno = ENOTSUP;
	return -1;
}

int
_vprocmgr_getsocket(void)
{
	errno = ENOTSUP;
	return -1;
}

void *
_vprocmgr_init(const char *session_type)
{
	(void)session_type;
	return NULL;
}

int
_vprocmgr_move_subset_to_user(uid_t target_user, const char *session_type, uint64_t flags)
{
	(void)target_user;
	(void)session_type;
	(void)flags;
	return ENOTSUP;
}

static void
emit_kv(const char *key, const char *value)
{
	printf("%s=%s\n", key, value);
	fflush(stdout);
}

static void
emit_u32(const char *key, uint32_t value)
{
	printf("%s=%u\n", key, value);
	fflush(stdout);
}

static void
emit_i32(const char *key, int32_t value)
{
	printf("%s=%d\n", key, value);
	fflush(stdout);
}

static void
emit_sha256(const char *key, const void *bytes, size_t size)
{
	char digest[SHA256_DIGEST_STRING_LENGTH];

	if (SHA256_Data(bytes, (unsigned int)size, digest) == NULL) {
		emit_kv(key, "sha256_error");
		return;
	}

	emit_kv(key, digest);
}

static mach_msg_size_t
round_msg_size(mach_msg_size_t size)
{
	return (size + sizeof(mach_msg_size_t) - 1) & ~(sizeof(mach_msg_size_t) - 1);
}

#if defined(ASL_A2_ROLE_SERVER)
static int
run_server(void)
{
	launch_data_t request = NULL;
	launch_data_t reply = NULL;
	launch_data_t machservices = NULL;
	launch_data_t service = NULL;
	mach_port_t receive_port = MACH_PORT_NULL;
	kern_return_t kr;
	union {
		__Request___asl_server_message_t request;
		uint8_t bytes[8192 + MAX_TRAILER_SIZE];
	} message;
	mach_msg_audit_trailer_t *trailer = NULL;
	mach_msg_size_t trailer_offset;
	const char *payload = NULL;
	size_t payload_size = 0;
	int rc = 1;

	memset(&message, 0, sizeof(message));
	emit_kv("ASL_A2_SERVER_START", "1");
	emit_kv("ASL_A2_SERVICE_NAME", ASL_A2_SERVICE_NAME);
	emit_kv("ASL_A2_LAUNCH_CHECKIN_CALLED", "1");
	emit_kv("ASL_A2_LAUNCH_CHECKIN_KEY", LAUNCH_KEY_CHECKIN);

	request = launch_data_new_string(LAUNCH_KEY_CHECKIN);
	reply = launch_msg(request);
	emit_kv("ASL_A2_LAUNCH_CHECKIN_REPLY_PRESENT", reply != NULL ? "1" : "0");
	if (request != NULL) launch_data_free(request);
	if (reply == NULL) goto out;

	machservices = launch_data_dict_lookup(reply, LAUNCH_JOBKEY_MACHSERVICES);
	emit_kv("ASL_A2_MACHSERVICES_DICT_PRESENT", machservices != NULL ? "1" : "0");
	if (machservices == NULL) goto out;

	service = launch_data_dict_lookup(machservices, ASL_A2_SERVICE_NAME);
	emit_kv("ASL_A2_SERVICE_ENTRY_PRESENT", service != NULL ? "1" : "0");
	if (service == NULL) goto out;

	receive_port = launch_data_get_machport(service);
	emit_u32("ASL_A2_SERVER_CHECKIN_RECEIVE_PORT", receive_port);
	emit_kv("ASL_A2_SERVER_RECEIVE_RIGHT_USABLE",
	    receive_port != MACH_PORT_NULL ? "1" : "0");
	if (receive_port == MACH_PORT_NULL) goto out;

	emit_kv("ASL_A2_SUBCLAIM_A_PASSED", "1");

	kr = mach_msg(&message.request.Head,
	    MACH_RCV_MSG | MACH_RCV_TIMEOUT |
	    MACH_RCV_TRAILER_TYPE(MACH_MSG_TRAILER_FORMAT_0) |
	    MACH_RCV_TRAILER_ELEMENTS(MACH_RCV_TRAILER_AUDIT),
	    0, sizeof(message), receive_port, 15000, MACH_PORT_NULL);
	emit_i32("ASL_A2_SERVER_RECEIVE_KR", kr);
	if (kr != KERN_SUCCESS) goto out;

	emit_u32("ASL_A2_SERVER_RECEIVED_MSG_ID", (uint32_t)message.request.Head.msgh_id);
	emit_kv("ASL_A2_SERVER_RECEIVED_COMPLEX",
	    (message.request.Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ? "1" : "0");
	emit_u32("ASL_A2_SERVER_DESCRIPTOR_COUNT",
	    (uint32_t)message.request.msgh_body.msgh_descriptor_count);
	emit_u32("ASL_A2_RECEIVED_OOL_BYTE_COUNT", message.request.message.size);

	trailer_offset = round_msg_size(message.request.Head.msgh_size);
	if ((trailer_offset + sizeof(mach_msg_audit_trailer_t)) <= sizeof(message))
		trailer = (mach_msg_audit_trailer_t *)((uint8_t *)&message + trailer_offset);
	emit_kv("ASL_A2_SERVER_REQUESTED_AUDIT_TRAILER", "1");
	emit_kv("ASL_A2_SERVER_AUDIT_TRAILER_PRESENT",
	    trailer != NULL && trailer->msgh_trailer_size >= sizeof(*trailer) ? "1" : "0");

	if (message.request.Head.msgh_id != 118 ||
	    !(message.request.Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
	    message.request.msgh_body.msgh_descriptor_count != 1 ||
	    message.request.message.address == NULL ||
	    message.request.message.size == 0) {
		goto out;
	}

	payload = (const char *)message.request.message.address;
	payload_size = message.request.message.size;
	emit_sha256("ASL_A2_RECEIVED_OOL_SHA256", payload, payload_size);
	emit_kv("ASL_A2_NONCE_MATCH",
	    payload_size == sizeof(ASL_A2_PAYLOAD) &&
	    memcmp(payload, ASL_A2_PAYLOAD, sizeof(ASL_A2_PAYLOAD)) == 0 ? "1" : "0");
	emit_kv("ASL_A2_PORT_IDENTITY_NONCE_RECEIVED", "1");
	emit_kv("ASL_A2_SUBCLAIM_B_SERVER_RECEIPT", "1");

	if (payload != NULL)
		(void)vm_deallocate(mach_task_self(), (vm_address_t)payload,
		    (vm_size_t)payload_size);

	rc = 0;

out:
	emit_kv("ASL_A2_DONE", rc == 0 ? "1" : "0");
	if (reply != NULL) launch_data_free(reply);
	return rc;
}
#endif

#if defined(ASL_A2_ROLE_CLIENT)
static int
run_client(void)
{
	mach_port_t service_port;
	vm_address_t ool = 0;
	mach_msg_type_number_t ool_len;
	kern_return_t kr;

	emit_kv("ASL_A2_CLIENT_START", "1");
	emit_kv("ASL_A2_SERVICE_NAME", ASL_A2_SERVICE_NAME);
	emit_kv("ASL_A2_DONOR_LOOKUP_FUNCTION", "asl_core_get_service_port");
	emit_kv("ASL_A2_DONOR_LOOKUP_CALLED", "1");

	service_port = asl_core_get_service_port(1);
	emit_u32("ASL_A2_CLIENT_LOOKUP_SEND_RIGHT", service_port);
	emit_kv("ASL_A2_CLIENT_LOOKUP_SUCCESS",
	    service_port != MACH_PORT_NULL ? "1" : "0");
	if (service_port == MACH_PORT_NULL) return 1;

	ool_len = (mach_msg_type_number_t)sizeof(ASL_A2_PAYLOAD);
	emit_u32("ASL_A2_EXPECTED_OOL_BYTE_COUNT", ool_len);
	emit_sha256("ASL_A2_EXPECTED_OOL_SHA256", ASL_A2_PAYLOAD, ool_len);
	emit_kv("ASL_A2_NONCE", ASL_A2_NONCE);

	kr = vm_allocate(mach_task_self(), &ool, ool_len, TRUE);
	emit_i32("ASL_A2_CLIENT_VM_ALLOCATE_KR", kr);
	if (kr != KERN_SUCCESS) return 1;
	memcpy((void *)ool, ASL_A2_PAYLOAD, ool_len);

	emit_kv("ASL_A2_CLIENT_SEND_STARTED", "1");
	kr = _asl_server_message(service_port, (caddr_t)ool, ool_len);
	emit_i32("ASL_A2_CLIENT_SEND_KR", kr);
	emit_kv("ASL_A2_SUBCLAIM_B_CLIENT_SEND", kr == KERN_SUCCESS ? "1" : "0");

	return kr == KERN_SUCCESS ? 0 : 1;
}
#endif

int
main(void)
{
#if defined(ASL_A2_ROLE_SERVER)
	return run_server();
#elif defined(ASL_A2_ROLE_CLIENT)
	return run_client();
#else
	emit_kv("ASL_A2_BUILD_ROLE_MISSING", "1");
	return 64;
#endif
}
