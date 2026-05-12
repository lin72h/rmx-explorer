/*
 * nx_env.c -- Environment embedding helpers for oracle probes.
 */

#include "nx_env.h"

#include <stdlib.h>

static int
emit_file_raw(nx_json_t *j, const char *path)
{
    FILE *fp = fopen(path, "r");
    if (fp == NULL) {
        return 0;
    }

    int ch;
    while ((ch = fgetc(fp)) != EOF) {
        fputc(ch, j->fp);
    }
    fclose(fp);

    if (j->depth > 0) {
        j->need_comma[j->depth] = true;
    }
    return 1;
}

static void
emit_minimal_fallback(nx_json_t *j)
{
    nx_json_begin_object(j);
    nx_json_key_null(j, "sw_vers");
    nx_json_key_null(j, "uname");
    nx_json_key_null(j, "os_name");
    nx_json_key_null(j, "kernel_version");
    nx_json_key_null(j, "result_dir_name");
    nx_json_key_null(j, "arch");
    nx_json_key_null(j, "machine");
    nx_json_key_null(j, "compiler");
    nx_json_key_null(j, "sdk");
    nx_json_key_null(j, "sdk_version");
    nx_json_key_null(j, "sdk_path");
    nx_json_key_null(j, "xcode_select_path");
    nx_json_key_null(j, "cpu_brand");

    nx_json_key(j, "cpu_features");
    nx_json_begin_object(j);
    nx_json_end_object(j);

    nx_json_key(j, "apple_silicon");
    nx_json_begin_object(j);
    nx_json_key_null(j, "hw_optional_arm64");
    nx_json_key_null(j, "arm64e");
    nx_json_key_null(j, "pointer_authentication");
    nx_json_key(j, "raw_sysctls");
    nx_json_begin_object(j);
    nx_json_end_object(j);
    nx_json_end_object(j);

    nx_json_key_null(j, "rosetta");
    nx_json_key_null(j, "sip_enabled");
    nx_json_key_null(j, "sandboxed");
    nx_json_key_bool(j, "run_as_root", false);
    nx_json_key_bool(j, "ad_hoc_signed", false);
    nx_json_key_bool(j, "hardened_runtime", false);

    nx_json_key(j, "signing");
    nx_json_begin_object(j);
    nx_json_key(j, "binaries");
    nx_json_begin_array(j);
    nx_json_end_array(j);
    nx_json_end_object(j);

    nx_json_key_null(j, "zig_version");
    nx_json_key_null(j, "zig_path");
    nx_json_key_null(j, "zig_lib_dir");
    nx_json_key_bool(j, "zig_fallback", false);
    nx_json_key_null(j, "zig_fallback_reason");
    nx_json_end_object(j);
}

void
nx_env_emit(nx_json_t *j)
{
    const char *path = getenv("NX_ORACLE_ENV_JSON_FILE");

    nx_json_key(j, "environment");
    if (path != NULL && path[0] != '\0' && emit_file_raw(j, path)) {
        return;
    }

    emit_minimal_fallback(j);
}
