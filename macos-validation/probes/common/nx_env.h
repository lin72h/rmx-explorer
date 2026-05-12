/*
 * nx_env.h — Environment capture helpers for oracle probes.
 *
 * Emits the "environment" object inside a result JSON. Under the harness,
 * this embeds the complete environment JSON from NX_ORACLE_ENV_JSON_FILE.
 * Standalone execution falls back to a complete but minimal object.
 */

#ifndef NX_ENV_H
#define NX_ENV_H

#include "nx_json.h"

/*
 * Emit the harness environment object, or a minimal fallback object.
 * Caller must be inside an open JSON object (the result envelope).
 * Emits key "environment" with a complete object value.
 */
void nx_env_emit(nx_json_t *j);

#endif /* NX_ENV_H */
