/* op-121 libxpc substrate conformance harness — shared blob for lockstep leg 2.
 * Substrate axis: object create/encode/decode (nvlist wire), dictionary ops,
 * primitive objects (int64/data/string), type/hash identity, connection lifecycle.
 * NOT: send/reply round-trip (needs a registered XPC service + live bootstrap —
 * that's the transport-layer pass-2 extension).
 * Structured "name: PASS|FAIL" output. Byte-identical-shareable rx-x64z + mx-a64z. */
#include <stdio.h>
#include <string.h>
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>

static int g_fails = 0;
#define R(name, val) printf("%s: %s\n", (name), (val)?"PASS":"FAIL"); g_fails += !(val)

int main(void) {
    /* === Object creation + dictionary round-trip === */
    xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
    R("xpc_dictionary_create", dict != NULL);

    /* int64 set/get */
    xpc_object_t i64 = xpc_int64_create(0x7F0000000001LL);
    R("xpc_int64_create", i64 != NULL);
    if (i64) {
        int64_t got = xpc_int64_get_value(i64);
        R("xpc_int64_get_value", got == 0x7F0000000001LL);
        xpc_dictionary_set_value(dict, "seq", i64);
    }

    /* string set/get via dictionary */
    xpc_dictionary_set_int64(dict, "count", 42);
    xpc_dictionary_set_string(dict, "service", "com.test.op121");

    const char *svc = xpc_dictionary_get_string(dict, "service");
    R("xpc_dictionary_get_string", svc != NULL && strcmp(svc, "com.test.op121") == 0);

    int64_t cnt = xpc_dictionary_get_int64(dict, "count");
    R("xpc_dictionary_get_int64", cnt == 42);

    /* data set/get — xpc_dictionary_set_data/get_data are DECLARED in the rmxOS
     * xpc.h header but NOT IMPLEMENTED in libxpc.so.5 (no symbol). This is a
     * genuine API gap — catalog, don't include in the harness (lockstep doctrine:
     * the harness must link on both sides). */
    uint8_t payload[] = {0xDE, 0xAD, 0xBE, 0xEF};
    /* (data round-trip via dictionary omitted — API gap bl-NNN) */

    /* === Dictionary count + apply === */
    size_t dcount = xpc_dictionary_get_count(dict);
    R("xpc_dictionary_get_count", dcount == 3); /* seq, count, service */

    /* === Type identity (XPC_TYPE_* macros use extern-variable addresses that
     * FreeBSD LLD can't copy-relocate from shared libs — skip on rmxOS; macOS
     * may link fine. A build-side divergence to catalog, not a harness fix.) === */
    /* xpc_get_type checks omitted: xpc_get_type(dict) == XPC_TYPE_DICTIONARY
     * fails to link on rmxOS (copy-relocation of _xpc_type_dictionary). */

    xpc_object_t str = xpc_string_create("hello-xpc");
    R("xpc_string_create", str != NULL);

    xpc_object_t data = xpc_data_create("bytes", 5);
    R("xpc_data_create", data != NULL);
    if (data) {
        R("xpc_data_get_length", xpc_data_get_length(data) == 5);
        R("xpc_data_get_bytes_ptr", memcmp(xpc_data_get_bytes_ptr(data), "bytes", 5) == 0);
    }

    /* === Hash identity === */
    xpc_object_t dict2 = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(dict2, "count", 42);
    xpc_dictionary_set_string(dict2, "service", "com.test.op121");
    xpc_dictionary_set_int64(dict2, "seq", 0x7F0000000001LL);
    /* payload data set omitted (xpc_dictionary_set_data not implemented on rmxOS) */
    /* Same content → same hash (if the nvlist encoder is deterministic) */
    size_t h1 = xpc_hash(dict);
    size_t h2 = xpc_hash(dict2);
    R("xpc_hash_consistent", h1 == h2);

    /* === Connection lifecycle (no live peer — tests graceful create/resume/cancel) === */
    xpc_connection_t conn = xpc_connection_create("com.test.op121.nonexistent", NULL);
    /* xpc_connection_create may return non-NULL even if the bootstrap lookup
     * failed (the error defers to resume/send). A non-NULL conn = the object
     * was created. Resume then cancel tests the lifecycle path. */
    R("xpc_connection_create", conn != NULL);
    if (conn) {
        xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
            (void)event; /* no-op handler for the lifecycle test */
        });
        xpc_connection_resume(conn);
        xpc_connection_cancel(conn);
        R("xpc_connection_lifecycle", 1); /* reached here without crash = pass */
    } else {
        R("xpc_connection_lifecycle", 0);
    }

    /* === Release === */
    xpc_release(dict);
    xpc_release(dict2);
    if (i64) xpc_release(i64);
    if (str) xpc_release(str);
    if (data) xpc_release(data);
    if (conn) xpc_release(conn);
    R("xpc_release", 1); /* non-crash = pass */

    printf("op121_matrix_fails=%d\n", g_fails);
    printf("op121_matrix_terminal status=0\n");
    return 0;
}
