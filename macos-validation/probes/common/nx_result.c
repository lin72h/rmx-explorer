/*
 * nx_result.c — Oracle result schema helpers.
 */

#include "nx_result.h"

const char *
nx_status_str(nx_status_t s)
{
    switch (s) {
    case NX_STATUS_PASS:          return "pass";
    case NX_STATUS_FAIL:          return "fail";
    case NX_STATUS_SKIP:          return "skip";
    case NX_STATUS_PROBE_FAILURE: return "probe_failure";
    }
    return "probe_failure";
}

const char *
nx_class_str(nx_semantic_class_t c)
{
    switch (c) {
    case NX_CLASS_EXACT_CONTRACT:         return "exact_contract";
    case NX_CLASS_EQUIVALENT_CONTRACT:    return "equivalent_contract";
    case NX_CLASS_VERSION_SENSITIVE:       return "version_sensitive";
    case NX_CLASS_PRIVILEGE_SENSITIVE:     return "privilege_sensitive";
    case NX_CLASS_NOT_OBSERVABLE:          return "not_observable";
    case NX_CLASS_PROBE_FAILURE:          return "probe_failure";
    case NX_CLASS_INTENTIONAL_DIVERGENCE: return "intentional_divergence";
    }
    return "probe_failure";
}

void
nx_result_emit_header(nx_json_t *j,
                      const char *agent,
                      const char *test_id,
                      const char *nextbsd_test_id,
                      const char *donor_equivalent_id,
                      nx_status_t status,
                      nx_semantic_class_t semantic_class)
{
    nx_json_key_string(j, "schema", NX_SCHEMA_NAME);
    nx_json_key_string(j, "agent", agent);
    nx_json_key_string(j, "test_id", test_id);

    nx_json_key(j, "cross_reference");
    nx_json_begin_object(j);
    nx_json_key_string_or_null(j, "nextbsd_test_id", nextbsd_test_id);
    nx_json_key_string_or_null(j, "donor_equivalent_id", donor_equivalent_id);
    nx_json_end_object(j);

    nx_json_key_string(j, "status", nx_status_str(status));
    nx_json_key_string(j, "semantic_class", nx_class_str(semantic_class));
}

void
nx_result_emit_cleanup(nx_json_t *j,
                       bool returned_to_baseline,
                       const char *notes)
{
    nx_json_key(j, "cleanup");
    nx_json_begin_object(j);
    nx_json_key_bool(j, "returned_to_baseline", returned_to_baseline);
    nx_json_key_string(j, "notes", notes ? notes : "");
    nx_json_end_object(j);
}

void
nx_result_emit_return(nx_json_t *j,
                      const char *call,
                      const char *returned_str,
                      long long raw,
                      bool has_errno,
                      int errno_val)
{
    nx_json_begin_object(j);
    nx_json_key_string(j, "call", call);
    nx_json_key_string(j, "returned", returned_str);
    nx_json_key_int(j, "raw", raw);
    if (has_errno)
        nx_json_key_int(j, "errno", errno_val);
    else
        nx_json_key_null(j, "errno");
    nx_json_end_object(j);
}

void
nx_result_emit_right_delta(nx_json_t *j,
                           const char *operation,
                           const char *port_name,
                           const char *right_type,
                           long long before_urefs,
                           long long after_urefs,
                           long long entry_refs_before,
                           long long entry_refs_after,
                           const char *expected)
{
    nx_json_begin_object(j);
    nx_json_key_string(j, "operation", operation);
    nx_json_key_string(j, "port_name", port_name);
    nx_json_key_string(j, "right_type", right_type);

    if (before_urefs >= 0)
        nx_json_key_int(j, "before_urefs", before_urefs);
    else
        nx_json_key_null(j, "before_urefs");

    if (after_urefs >= 0)
        nx_json_key_int(j, "after_urefs", after_urefs);
    else
        nx_json_key_null(j, "after_urefs");

    if (entry_refs_before >= 0)
        nx_json_key_int(j, "entry_refs_before", entry_refs_before);
    else
        nx_json_key_null(j, "entry_refs_before");

    if (entry_refs_after >= 0)
        nx_json_key_int(j, "entry_refs_after", entry_refs_after);
    else
        nx_json_key_null(j, "entry_refs_after");

    nx_json_key_string(j, "expected", expected);
    nx_json_end_object(j);
}

void
nx_result_emit_empty_message(nx_json_t *j)
{
    nx_json_key(j, "message");
    nx_json_begin_object(j);
    nx_json_key_string(j, "msgh_bits", "");
    nx_json_key(j, "remote_port");
    nx_json_begin_object(j);
    nx_json_key_null(j, "name");
    nx_json_key_null(j, "disposition");
    nx_json_key_null(j, "right_type");
    nx_json_end_object(j);
    nx_json_key(j, "local_port");
    nx_json_begin_object(j);
    nx_json_key_null(j, "name");
    nx_json_key_null(j, "disposition");
    nx_json_key_null(j, "right_type");
    nx_json_end_object(j);
    nx_json_key(j, "header_rights");
    nx_json_begin_array(j);
    nx_json_end_array(j);
    nx_json_key_int(j, "descriptor_count", 0);
    nx_json_key(j, "descriptors");
    nx_json_begin_array(j);
    nx_json_end_array(j);
    nx_json_end_object(j);
}
