/* op122-xpc-echo.c — rmxOS XPC echo responder.
 *
 * Adapts op-160's xpc-service.c pattern to the op-122 locked contract:
 *   Service name: com.rmxos.op122.echo
 *   Handler echoes: reply="pong", seqid echoed, every typed field echoed verbatim
 *
 * Registers via launchd MachServices plist (NOT shell-launch — id-016).
 * The plist registers com.rmxos.op122.echo as a Mach service; launchd starts
 * this binary when a client connects.
 *
 * Build: cc -fblocks -D__APPLE__ ... -o op122-xpc-echo op122-xpc-echo.c -lxpc -ldispatch -lBlocksRuntime
 */
#ifndef __OSX_AVAILABLE_BUT_DEPRECATED
#define __OSX_AVAILABLE_BUT_DEPRECATED(...)
#endif
#ifndef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(...)
#endif

#include <dispatch/dispatch.h>
#include <xpc/xpc.h>

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OP122_SERVICE_NAME "com.rmxos.op122.echo"

static void
op122_alarm(int signo __attribute__((unused)))
{
	const char *msg = "OP122_ECHO_ALARM phase=wait\n";
	(void)write(STDOUT_FILENO, msg, strlen(msg));
	_exit(124);
}

static void
op122_handle_peer(xpc_connection_t peer)
{
	printf("OP122_ECHO_PEER status=0 peer=%p\n", peer);
	fflush(stdout);
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		xpc_object_t reply;

		/* Create reply. Try xpc_dictionary_create_reply first (macOS-idiomatic);
		 * if it returns NULL (rmxOS behavioral gap), fall back to a fresh dict
		 * sent via xpc_connection_send_message(peer, ...). The fallback tests
		 * whether the peer connection's send path works without create_reply's
		 * internal routing metadata. */
		reply = xpc_dictionary_create_reply(event);
		int used_fallback = 0;
		if (reply == NULL) {
			printf("OP122_ECHO_REPLY status=1 reason=create_reply_null_fallback\n");
			fflush(stdout);
			reply = xpc_dictionary_create(NULL, NULL, 0);
			used_fallback = 1;
		}
		if (reply == NULL) {
			printf("OP122_ECHO_REPLY status=1 reason=both_reply_paths_failed\n");
			fflush(stdout);
			return;
		}

		/* Echo the locked contract fields */
		xpc_dictionary_set_string(reply, "reply", "pong");

		/* Echo seqid (int64) */
		int64_t seqid = xpc_dictionary_get_int64(event, "op122_seqid");
		xpc_dictionary_set_int64(reply, "op122_seqid", seqid);

		/* Echo string field verbatim */
		const char *str_val = xpc_dictionary_get_string(event, "op122_msg");
		if (str_val)
			xpc_dictionary_set_string(reply, "op122_msg", str_val);

		/* Echo int64 field verbatim */
		int64_t i64_val = xpc_dictionary_get_int64(event, "op122_int64");
		xpc_dictionary_set_int64(reply, "op122_int64", i64_val);

		/* Echo uint64 field verbatim */
		uint64_t u64_val = xpc_dictionary_get_uint64(event, "op122_uint64");
		xpc_dictionary_set_uint64(reply, "op122_uint64", u64_val);

		/* Echo bool field verbatim */
		int b_val = (int)xpc_dictionary_get_bool(event, "op122_bool");
		xpc_dictionary_set_bool(reply, "op122_bool", b_val);

		xpc_connection_send_message(peer, reply);
		xpc_release(reply);
		printf("OP122_ECHO_REPLY status=0 seqid=%lld fallback=%d\n",
		    (long long)seqid, used_fallback);
		fflush(stdout);
	});
	xpc_connection_resume(peer);
}

int
main(void)
{
	xpc_connection_t listener;

	setvbuf(stdout, NULL, _IONBF, 0);
	signal(SIGALRM, op122_alarm);
	alarm(60); /* 60s self-terminate if no client */

	printf("OP122_ECHO_START pid=%ld service=%s\n", (long)getpid(),
	    OP122_SERVICE_NAME);
	fflush(stdout);

	listener = xpc_connection_create_mach_service(OP122_SERVICE_NAME,
	    dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
	if (listener == NULL) {
		printf("OP122_ECHO_LISTENER status=1 errno=%d\n", errno);
		return (2);
	}
	printf("OP122_ECHO_LISTENER status=0\n");
	fflush(stdout);

	xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
		op122_handle_peer((xpc_connection_t)event);
	});
	xpc_connection_resume(listener);
	dispatch_main();

	return (0);
}
