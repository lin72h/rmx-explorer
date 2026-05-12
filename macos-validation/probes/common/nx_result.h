/*
 * nx_result.h — Oracle result schema constants and helpers.
 *
 * Schema: nx-v64z.macos-oracle.v1
 */

#ifndef NX_RESULT_H
#define NX_RESULT_H

#include "nx_json.h"

/* Schema name — single point of change if parent renames. */
#define NX_SCHEMA_NAME "nx-v64z.macos-oracle.v1"

/* Result status values */
typedef enum {
    NX_STATUS_PASS,
    NX_STATUS_FAIL,
    NX_STATUS_SKIP,
    NX_STATUS_PROBE_FAILURE
} nx_status_t;

/* Semantic class values */
typedef enum {
    NX_CLASS_EXACT_CONTRACT,
    NX_CLASS_EQUIVALENT_CONTRACT,
    NX_CLASS_VERSION_SENSITIVE,
    NX_CLASS_PRIVILEGE_SENSITIVE,
    NX_CLASS_NOT_OBSERVABLE,
    NX_CLASS_PROBE_FAILURE,
    NX_CLASS_INTENTIONAL_DIVERGENCE
} nx_semantic_class_t;

/* Convert enums to their JSON string representation. */
const char *nx_status_str(nx_status_t s);
const char *nx_class_str(nx_semantic_class_t c);

/* Emit the top-level result envelope fields:
 *   schema, agent, test_id, cross_reference, status, semantic_class
 *
 * Caller must have called nx_json_begin_object first.
 * After this call, the object is still open for environment, message, etc. */
void nx_result_emit_header(nx_json_t *j,
                           const char *agent,
                           const char *test_id,
                           const char *nextbsd_test_id,
                           const char *donor_equivalent_id,
                           nx_status_t status,
                           nx_semantic_class_t semantic_class);

/* Emit the cleanup block. */
void nx_result_emit_cleanup(nx_json_t *j,
                            bool returned_to_baseline,
                            const char *notes);

/* Emit a single returns[] entry. */
void nx_result_emit_return(nx_json_t *j,
                           const char *call,
                           const char *returned_str,
                           long long raw,
                           bool has_errno,
                           int errno_val);

/* Emit a single right_deltas[] entry.
 * entry_refs_before/after: use -1 to emit null (not available). */
void nx_result_emit_right_delta(nx_json_t *j,
                                const char *operation,
                                const char *port_name,
                                const char *right_type,
                                long long before_urefs,  /* -1 = null */
                                long long after_urefs,   /* -1 = null */
                                long long entry_refs_before, /* -1 = null */
                                long long entry_refs_after,  /* -1 = null */
                                const char *expected);

/* Emit an empty message block (no message sent/received). */
void nx_result_emit_empty_message(nx_json_t *j);

#endif /* NX_RESULT_H */
