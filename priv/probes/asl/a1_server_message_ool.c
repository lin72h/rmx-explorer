/*
 * ASL A1 probe: generated asl_ipc_server(), pinned donor codec, and pinned
 * donor __asl_server_message().
 *
 * This file owns only the client/server harness, instrumentation, and fenced
 * daemon hooks. The ASL message parser and __asl_server_message implementation
 * are linked from pinned donor source by the Oracle host build.
 */

#include <asl.h>
#include <asl_msg.h>
#include <bsm/libbsm.h>
#include <errno.h>
#include <mach/mach.h>
#include <pthread.h>
#include <sha256.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "asl_ipc.h"

#define ASL_A1_SOURCE_ASL_MESSAGE 5
#define ASL_A1_EXPECTED_MESSAGE "oracle_asl_a1"
#define ASL_A1_EXPECTED_SENDER "oracle_asl_a1_client"
#define ASL_A1_EXPECTED_FACILITY "com.rmxos.oracle.asl"
#define ASL_A1_EXPECTED_LEVEL "5"
#define ASL_A1_POSITIVE_PAYLOAD \
	"[Sender oracle_asl_a1_client] [Facility com.rmxos.oracle.asl] [Level 5] [Message oracle_asl_a1]"

typedef struct {
	mach_port_t receive_port;
	kern_return_t receive_kr;
	bool demux_handled;
	bool audit_trailer_present;
} asl_a1_server_case_t;

static unsigned int g_process_message_count;
static unsigned int g_donor_enter_count;
static unsigned int g_decode_ok_count;

extern boolean_t asl_ipc_server(mach_msg_header_t *, mach_msg_header_t *);
extern void rmx_asl_a1_donor_msg_release(asl_msg_t *);
static void emit_kv(const char *, const char *);

void
audit_token_to_au32(audit_token_t atoken, uid_t *auidp, uid_t *euidp, gid_t *egidp,
    uid_t *ruidp, gid_t *rgidp, pid_t *pidp, au_asid_t *asidp, au_tid_t *tidp)
{
	if (auidp != NULL) *auidp = (uid_t)atoken.val[0];
	if (euidp != NULL) *euidp = (uid_t)atoken.val[1];
	if (egidp != NULL) *egidp = (gid_t)atoken.val[2];
	if (ruidp != NULL) *ruidp = (uid_t)atoken.val[3];
	if (rgidp != NULL) *rgidp = (gid_t)atoken.val[4];
	if (pidp != NULL) *pidp = (pid_t)atoken.val[5];
	if (asidp != NULL) *asidp = (au_asid_t)atoken.val[6];
	if (tidp != NULL) memset(tidp, 0, sizeof(*tidp));
}

kern_return_t
task_name_for_pid(mach_port_name_t target_tport, int pid, mach_port_name_t *task)
{
	(void)target_tport;
	(void)pid;
	if (task != NULL) *task = MACH_PORT_NULL;
	emit_kv("ASL_A1_TASK_NAME_FOR_PID", "fenced_deferred");
	return KERN_FAILURE;
}

uint32_t
notify_post(const char *name)
{
	(void)name;
	return 0;
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

/*
 * Donor daemon hooks. These are deliberately fenced project-owned stubs. They
 * expose when the exact donor function enters its decode path and hands the
 * decoded donor asl_msg_t to process_message().
 */
int
asldebug(const char *format, ...)
{
	char text[2048];
	va_list ap;

	va_start(ap, format);
	(void)vsnprintf(text, sizeof(text), format, ap);
	va_end(ap);

	if (strncmp(text, "__asl_server_message: ", 22) == 0) {
		char *payload = text + 22;
		size_t len = strlen(payload);

		if (len > 0 && payload[len - 1] == '\n') {
			len--;
			payload[len] = '\0';
		}

		g_donor_enter_count++;
		emit_kv("ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1");
		emit_u32("ASL_A1_RECEIVED_OOL_BYTE_COUNT", (uint32_t)(len + 1));
		emit_sha256("ASL_A1_RECEIVED_OOL_SHA256", payload, len + 1);

		if ((len + 1) == sizeof(ASL_A1_POSITIVE_PAYLOAD) &&
		    memcmp(payload, ASL_A1_POSITIVE_PAYLOAD, sizeof(ASL_A1_POSITIVE_PAYLOAD)) == 0) {
			emit_kv("ASL_A1_DONOR_OOL_BYTES_INTACT", "1");
		}
	}

	return 0;
}

void
register_session(mach_port_name_t client, pid_t pid)
{
	(void)client;
	(void)pid;
	emit_kv("ASL_A1_SESSION_TRACKING", "fenced_stub");
}

void
process_message(asl_msg_t *msg, uint32_t source)
{
	const char *sender = NULL;
	const char *facility = NULL;
	const char *level = NULL;
	const char *message = NULL;
	const char *uid = NULL;
	const char *gid = NULL;
	const char *pid = NULL;

	g_process_message_count++;
	g_decode_ok_count++;
	emit_kv("ASL_A1_DONOR_DECODE_OK", "1");
	emit_kv("ASL_A1_PROCESS_MESSAGE_STUB_CALLED", "1");
	emit_u32("ASL_A1_PROCESS_MESSAGE_SOURCE", source);

	(void)asl_msg_lookup(msg, ASL_KEY_SENDER, &sender, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_FACILITY, &facility, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_LEVEL, &level, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_MSG, &message, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_UID, &uid, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_GID, &gid, NULL);
	(void)asl_msg_lookup(msg, ASL_KEY_PID, &pid, NULL);

	if (sender != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_SENDER", sender);
	if (facility != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_FACILITY", facility);
	if (level != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_LEVEL", level);
	if (message != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_MESSAGE", message);
	if (uid != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_UID", uid);
	if (gid != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_GID", gid);
	if (pid != NULL) emit_kv("ASL_A1_PROCESS_MESSAGE_PID", pid);

	if (uid != NULL) emit_kv("ASL_A1_AUDIT_UID", uid);
	if (gid != NULL) emit_kv("ASL_A1_AUDIT_GID", gid);
	if (pid != NULL) emit_kv("ASL_A1_AUDIT_PID", pid);

	if (uid != NULL && gid != NULL && pid != NULL &&
	    strtol(uid, NULL, 10) == (long)geteuid() &&
	    strtol(gid, NULL, 10) == (long)getegid() &&
	    strtol(pid, NULL, 10) == (long)getpid()) {
		emit_kv("ASL_A1_AUDIT_MATCH", "1");
		emit_kv("ASL_A1_AUDIT_CLAIM", "accepted");
	} else {
		emit_kv("ASL_A1_AUDIT_MATCH", "0");
		emit_kv("ASL_A1_AUDIT_CLAIM", "deferred");
		emit_kv("ASL_A1_AUDIT_DEFER_REASON", "audit_token_not_delivered_or_not_matchable");
	}

	if (source == ASL_A1_SOURCE_ASL_MESSAGE &&
	    message != NULL && strcmp(message, ASL_A1_EXPECTED_MESSAGE) == 0 &&
	    sender != NULL && strcmp(sender, ASL_A1_EXPECTED_SENDER) == 0 &&
	    facility != NULL && strcmp(facility, ASL_A1_EXPECTED_FACILITY) == 0 &&
	    level != NULL && strcmp(level, ASL_A1_EXPECTED_LEVEL) == 0) {
		emit_kv("ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH", "1");
	} else {
		emit_kv("ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH", "0");
	}

	rmx_asl_a1_donor_msg_release(msg);
	emit_kv("ASL_A1_DONOR_RELEASE_COMPLETED", "1");
}

/* Fenced non-A1 MIG routines required by the generated server object. */
kern_return_t
__asl_server_query(mach_port_t server, caddr_t request, mach_msg_type_number_t requestCnt,
    uint64_t startid, int count, int flags, caddr_t *reply,
    mach_msg_type_number_t *replyCnt, uint64_t *lastid, int *status,
    security_token_t *token)
{
	(void)server; (void)request; (void)requestCnt; (void)startid; (void)count;
	(void)flags; (void)token;
	if (reply != NULL) *reply = NULL;
	if (replyCnt != NULL) *replyCnt = 0;
	if (lastid != NULL) *lastid = 0;
	if (status != NULL) *status = ENOTSUP;
	return KERN_SUCCESS;
}

kern_return_t
__asl_server_query_timeout(mach_port_t server, caddr_t request,
    mach_msg_type_number_t requestCnt, uint64_t startid, int count, int flags, caddr_t *reply,
    mach_msg_type_number_t *replyCnt, uint64_t *lastid, int *status, audit_token_t token)
{
	(void)token;
	return __asl_server_query(server, request, requestCnt, startid, count, flags, reply, replyCnt,
	    lastid, status, NULL);
}

kern_return_t
__asl_server_prune(mach_port_t server, caddr_t request, mach_msg_type_number_t requestCnt,
    int *status, security_token_t *token)
{
	(void)server; (void)request; (void)requestCnt; (void)token;
	if (status != NULL) *status = ENOTSUP;
	return KERN_SUCCESS;
}

kern_return_t
__asl_server_create_aux_link(mach_port_t server, caddr_t message,
    mach_msg_type_number_t messageCnt, mach_port_t *fileport, caddr_t *url,
    mach_msg_type_number_t *urlCnt, int *status, audit_token_t token)
{
	(void)server; (void)message; (void)messageCnt; (void)token;
	if (fileport != NULL) *fileport = MACH_PORT_NULL;
	if (url != NULL) *url = NULL;
	if (urlCnt != NULL) *urlCnt = 0;
	if (status != NULL) *status = ENOTSUP;
	return KERN_SUCCESS;
}

kern_return_t
__asl_server_register_direct_watch(mach_port_t server, int port, audit_token_t token)
{
	(void)server; (void)port; (void)token;
	return KERN_SUCCESS;
}

kern_return_t
__asl_server_cancel_direct_watch(mach_port_t server, int port, audit_token_t token)
{
	(void)server; (void)port; (void)token;
	return KERN_SUCCESS;
}

kern_return_t
__asl_server_query_2(mach_port_t server, caddr_t request, mach_msg_type_number_t requestCnt,
    uint64_t startid, int count, int flags, caddr_t *reply,
    mach_msg_type_number_t *replyCnt, uint64_t *lastid, int *status, audit_token_t token)
{
	(void)token;
	return __asl_server_query(server, request, requestCnt, startid, count, flags, reply, replyCnt,
	    lastid, status, NULL);
}

kern_return_t
__asl_server_match(mach_port_t server, caddr_t request, mach_msg_type_number_t requestCnt,
    uint64_t startid, uint64_t count, uint32_t duration, int direction, caddr_t *reply,
    mach_msg_type_number_t *replyCnt, uint64_t *lastid, int *status, audit_token_t token)
{
	(void)duration; (void)direction; (void)token;
	return __asl_server_query(server, request, requestCnt, startid, (int)count, 0, reply,
	    replyCnt, lastid, status, NULL);
}

static mach_msg_size_t
round_msg_size(mach_msg_size_t size)
{
	return (size + sizeof(mach_msg_size_t) - 1) & ~(sizeof(mach_msg_size_t) - 1);
}

static void *
server_thread(void *arg)
{
	asl_a1_server_case_t *state = arg;
	union {
		mach_msg_header_t head;
		uint8_t bytes[8192 + MAX_TRAILER_SIZE];
	} request;
	union {
		mach_msg_header_t head;
		uint8_t bytes[8192 + MAX_TRAILER_SIZE];
	} reply;
	mach_msg_option_t options;
	mach_msg_audit_trailer_t *trailer;
	mach_msg_size_t trailer_offset;

	memset(&request, 0, sizeof(request));
	memset(&reply, 0, sizeof(reply));

	options = MACH_RCV_MSG | MACH_RCV_TIMEOUT |
	    MACH_RCV_TRAILER_TYPE(MACH_MSG_TRAILER_FORMAT_0) |
	    MACH_RCV_TRAILER_ELEMENTS(MACH_RCV_TRAILER_AUDIT);

	state->receive_kr = mach_msg(&request.head, options, 0, sizeof(request), state->receive_port,
	    5000, MACH_PORT_NULL);
	emit_i32("ASL_A1_SERVER_RECEIVE_KR", state->receive_kr);
	if (state->receive_kr != KERN_SUCCESS) return NULL;

	emit_u32("ASL_A1_SERVER_RECEIVED_MSG_ID", (uint32_t)request.head.msgh_id);
	trailer_offset = round_msg_size(request.head.msgh_size);
	if ((trailer_offset + sizeof(mach_msg_audit_trailer_t)) <= sizeof(request)) {
		trailer = (mach_msg_audit_trailer_t *)((uint8_t *)&request + trailer_offset);
		state->audit_trailer_present =
		    trailer->msgh_trailer_size >= sizeof(mach_msg_audit_trailer_t);
	}

	emit_kv("ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER", "1");
	emit_kv("ASL_A1_SERVER_AUDIT_TRAILER_PRESENT",
	    state->audit_trailer_present ? "1" : "0");
	emit_kv("ASL_A1_GENERATED_DEMUX_CALLED", "1");
	state->demux_handled = asl_ipc_server(&request.head, &reply.head);
	emit_kv("ASL_A1_GENERATED_DEMUX_HANDLED", state->demux_handled ? "1" : "0");
	return NULL;
}

static int
send_ool_case(const char *payload)
{
	asl_a1_server_case_t state;
	pthread_t thread;
	mach_port_t receive_port = MACH_PORT_NULL;
	vm_address_t ool = 0;
	mach_msg_type_number_t ool_len;
	kern_return_t kr;

	memset(&state, 0, sizeof(state));
	if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &receive_port) !=
	    KERN_SUCCESS) return 1;
	if (mach_port_insert_right(mach_task_self(), receive_port, receive_port,
	    MACH_MSG_TYPE_MAKE_SEND) != KERN_SUCCESS) return 1;

	state.receive_port = receive_port;
	if (pthread_create(&thread, NULL, server_thread, &state) != 0) return 1;

	ool_len = (mach_msg_type_number_t)(strlen(payload) + 1);
	if (vm_allocate(mach_task_self(), &ool, ool_len, TRUE) != KERN_SUCCESS) return 1;
	memcpy((void *)ool, payload, ool_len);

	emit_kv("ASL_A1_CLIENT_SEND_STARTED", "1");
	kr = _asl_server_message(receive_port, (caddr_t)ool, ool_len);
	emit_i32("ASL_A1_CLIENT_SEND_KR", kr);
	(void)pthread_join(thread, NULL);
	mach_port_destroy(mach_task_self(), receive_port);

	return (kr == KERN_SUCCESS && state.receive_kr == KERN_SUCCESS && state.demux_handled) ? 0 : 1;
}

static int
run_invalid_ool_descriptor_negative(void)
{
	union {
		mach_msg_header_t head;
		uint8_t bytes[512];
	} request;
	union {
		mach_msg_header_t head;
		uint8_t bytes[512];
	} reply;
	unsigned int process_before = g_process_message_count;
	unsigned int donor_before = g_donor_enter_count;
	boolean_t handled;

	memset(&request, 0, sizeof(request));
	memset(&reply, 0, sizeof(reply));
	request.head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
	request.head.msgh_size = sizeof(mach_msg_header_t);
	request.head.msgh_id = 118;

	handled = asl_ipc_server(&request.head, &reply.head);
	if (g_process_message_count == process_before && g_donor_enter_count == donor_before) {
		emit_kv("ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED", "1");
		return 0;
	}

	emit_kv("ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED", handled ? "0" : "0");
	return 1;
}

int
main(void)
{
	unsigned int process_before;
	unsigned int decode_before;
	int rc = 0;

	emit_kv("ASL_A1_PROBE_START", "1");
	emit_kv("ASL_A1_MIG_SUBSYSTEM", "114");
	emit_kv("ASL_A1_MIG_ROUTINE_ID", "118");
	emit_i32("ASL_A1_CLIENT_PID", getpid());
	emit_i32("ASL_A1_CLIENT_UID", geteuid());
	emit_i32("ASL_A1_CLIENT_GID", getegid());

	emit_kv("ASL_A1_ARM_START", "positive_decode");
	emit_u32("ASL_A1_EXPECTED_OOL_BYTE_COUNT", sizeof(ASL_A1_POSITIVE_PAYLOAD));
	emit_sha256("ASL_A1_EXPECTED_OOL_SHA256", ASL_A1_POSITIVE_PAYLOAD,
	    sizeof(ASL_A1_POSITIVE_PAYLOAD));
	process_before = g_process_message_count;
	if (send_ool_case(ASL_A1_POSITIVE_PAYLOAD) != 0) rc = 1;
	if (g_process_message_count == process_before + 1 && g_decode_ok_count > 0) {
		emit_kv("ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED", "1");
	} else {
		emit_kv("ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED", "0");
		rc = 1;
	}
	emit_kv("ASL_A1_ARM_END", "positive_decode");

	emit_kv("ASL_A1_ARM_START", "malformed_payload");
	process_before = g_process_message_count;
	decode_before = g_decode_ok_count;
	if (send_ool_case("not-a-valid-asl-mig-message") != 0) rc = 1;
	if (g_process_message_count == process_before && g_decode_ok_count == decode_before) {
		emit_kv("ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED", "1");
	} else {
		emit_kv("ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED", "0");
		rc = 1;
	}
	emit_kv("ASL_A1_ARM_END", "malformed_payload");

	emit_kv("ASL_A1_ARM_START", "invalid_ool");
	if (run_invalid_ool_descriptor_negative() != 0) rc = 1;
	emit_kv("ASL_A1_ARM_END", "invalid_ool");

	emit_kv("ASL_A1_DONE", rc == 0 ? "1" : "0");
	return rc;
}
