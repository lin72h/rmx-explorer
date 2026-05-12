/*
 * nx_json.h — Minimal dependency-free JSON emitter.
 *
 * Write-only. Does not parse JSON. Writes to a FILE*.
 * Handles string escaping for \, ", and control characters.
 */

#ifndef NX_JSON_H
#define NX_JSON_H

#include <stdio.h>
#include <stdbool.h>

/* Opaque writer state — tracks nesting and comma placement. */
typedef struct {
    FILE *fp;
    int depth;
    bool need_comma[32]; /* max nesting depth */
} nx_json_t;

/* Initialize a JSON writer on the given FILE*. */
void nx_json_init(nx_json_t *j, FILE *fp);

/* Object/array begin/end */
void nx_json_begin_object(nx_json_t *j);
void nx_json_end_object(nx_json_t *j);
void nx_json_begin_array(nx_json_t *j);
void nx_json_end_array(nx_json_t *j);

/* Emit a key (inside an object). Must be followed by a value call. */
void nx_json_key(nx_json_t *j, const char *key);

/* Value emitters — can follow nx_json_key or be inside an array. */
void nx_json_string(nx_json_t *j, const char *val);
void nx_json_int(nx_json_t *j, long long val);
void nx_json_uint(nx_json_t *j, unsigned long long val);
void nx_json_bool(nx_json_t *j, bool val);
void nx_json_null(nx_json_t *j);

/* Convenience: key + value in one call */
void nx_json_key_string(nx_json_t *j, const char *key, const char *val);
void nx_json_key_string_or_null(nx_json_t *j, const char *key, const char *val);
void nx_json_key_int(nx_json_t *j, const char *key, long long val);
void nx_json_key_uint(nx_json_t *j, const char *key, unsigned long long val);
void nx_json_key_bool(nx_json_t *j, const char *key, bool val);
void nx_json_key_null(nx_json_t *j, const char *key);

#endif /* NX_JSON_H */
