/*
 * nx_json.c — Minimal dependency-free JSON emitter.
 */

#include "nx_json.h"
#include <string.h>

void
nx_json_init(nx_json_t *j, FILE *fp)
{
    j->fp = fp;
    j->depth = 0;
    memset(j->need_comma, 0, sizeof(j->need_comma));
}

static void
emit_comma_if_needed(nx_json_t *j)
{
    if (j->depth > 0 && j->need_comma[j->depth]) {
        fputc(',', j->fp);
    }
}

static void
mark_value_written(nx_json_t *j)
{
    if (j->depth > 0) {
        j->need_comma[j->depth] = true;
    }
}

/* Emit a JSON-escaped string (without surrounding quotes). */
static void
emit_escaped(FILE *fp, const char *s)
{
    if (s == NULL) {
        return;
    }
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        switch (c) {
        case '"':  fputs("\\\"", fp); break;
        case '\\': fputs("\\\\", fp); break;
        case '\n': fputs("\\n", fp);  break;
        case '\r': fputs("\\r", fp);  break;
        case '\t': fputs("\\t", fp);  break;
        default:
            if (c < 0x20) {
                fprintf(fp, "\\u%04x", c);
            } else {
                fputc(c, fp);
            }
            break;
        }
    }
}

void
nx_json_begin_object(nx_json_t *j)
{
    emit_comma_if_needed(j);
    fputc('{', j->fp);
    j->depth++;
    if (j->depth < 32)
        j->need_comma[j->depth] = false;
}

void
nx_json_end_object(nx_json_t *j)
{
    fputc('}', j->fp);
    if (j->depth > 0)
        j->depth--;
    mark_value_written(j);
}

void
nx_json_begin_array(nx_json_t *j)
{
    emit_comma_if_needed(j);
    fputc('[', j->fp);
    j->depth++;
    if (j->depth < 32)
        j->need_comma[j->depth] = false;
}

void
nx_json_end_array(nx_json_t *j)
{
    fputc(']', j->fp);
    if (j->depth > 0)
        j->depth--;
    mark_value_written(j);
}

void
nx_json_key(nx_json_t *j, const char *key)
{
    emit_comma_if_needed(j);
    fputc('"', j->fp);
    emit_escaped(j->fp, key);
    fputs("\":", j->fp);
    /* Next value should not emit a leading comma — the key acts as separator.
     * Temporarily suppress comma for the value that follows. */
    if (j->depth > 0)
        j->need_comma[j->depth] = false;
}

void
nx_json_string(nx_json_t *j, const char *val)
{
    emit_comma_if_needed(j);
    fputc('"', j->fp);
    emit_escaped(j->fp, val);
    fputc('"', j->fp);
    mark_value_written(j);
}

void
nx_json_int(nx_json_t *j, long long val)
{
    emit_comma_if_needed(j);
    fprintf(j->fp, "%lld", val);
    mark_value_written(j);
}

void
nx_json_uint(nx_json_t *j, unsigned long long val)
{
    emit_comma_if_needed(j);
    fprintf(j->fp, "%llu", val);
    mark_value_written(j);
}

void
nx_json_bool(nx_json_t *j, bool val)
{
    emit_comma_if_needed(j);
    fputs(val ? "true" : "false", j->fp);
    mark_value_written(j);
}

void
nx_json_null(nx_json_t *j)
{
    emit_comma_if_needed(j);
    fputs("null", j->fp);
    mark_value_written(j);
}

/* Convenience: key + value */

void
nx_json_key_string(nx_json_t *j, const char *key, const char *val)
{
    nx_json_key(j, key);
    nx_json_string(j, val);
}

void
nx_json_key_string_or_null(nx_json_t *j, const char *key, const char *val)
{
    nx_json_key(j, key);
    if (val)
        nx_json_string(j, val);
    else
        nx_json_null(j);
}

void
nx_json_key_int(nx_json_t *j, const char *key, long long val)
{
    nx_json_key(j, key);
    nx_json_int(j, val);
}

void
nx_json_key_uint(nx_json_t *j, const char *key, unsigned long long val)
{
    nx_json_key(j, key);
    nx_json_uint(j, val);
}

void
nx_json_key_bool(nx_json_t *j, const char *key, bool val)
{
    nx_json_key(j, key);
    nx_json_bool(j, val);
}

void
nx_json_key_null(nx_json_t *j, const char *key)
{
    nx_json_key(j, key);
    nx_json_null(j);
}
