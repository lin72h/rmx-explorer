# op-167 — libxpc bucket-2 verify-FIRST sweep (READ-ONLY)

Date: 2026-06-26. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY — no edits, no builds.
Source: `/Users/me/wip-mach/wip-gpt/wip-rmxos/` (alpha tip).

## Part A (id-031) — header-surface truth, 4 non-exported symbols

### A1: declarations + .c definitions

| symbol | header decl | .c def | status |
|---|---|---|---|
| `xpc_debugger_api_misuse_info` | `xpc/debug.h:21` | NONE | **still-valid** — declared, no def |
| `xpc_object_validate` | **NOT declared** as public symbol | N/A | **STALE census item** — only `_xpc_object_validate` exists (inline in `xpc.h:71`); the public non-underscore version doesn't exist |
| `xpc_service_main` | `xpc/xpc.h:2441` | NONE | **still-valid** — declared, no def |
| `xpc_unreachable` | **NOT declared** as public symbol | N/A | **STALE census item** — only `_xpc_unreachable()` exists (macro in `base.h:99`: `#define _xpc_unreachable() __builtin_unreachable()`); the public version doesn't exist |

### A2: export status (nm -D libxpc.so.5)

All 4 symbols (plus underscore variants) are **NOT exported** from libxpc.so.5:
```
xpc_debugger_api_misuse_info: NOT exported
xpc_object_validate:          NOT exported
xpc_service_main:             NOT exported
xpc_unreachable:              NOT exported
_xpc_object_validate:         NOT exported
_xpc_unreachable:             NOT exported
```

### A3: internal callers (grep entire rmxOS tree)

**Zero callers** of any of the 4 public symbols outside libxpc. The underscore variants are used only in headers (inline/macro). No live caller issue.

```text
OP167_ID031_DECLS: 2-of-4 valid (debugger_api_misuse_info@debug.h:21, service_main@xpc.h:2441); 2 stale (object_validate, unreachable don't exist as public symbols)
OP167_ID031_EXPORT: all 4 NOT exported (confirmed)
OP167_ID031_CALLERS: 0 internal callers (no live caller issue)
```

**id-031 VERDICT: partially stale.** The 2 valid items (`xpc_debugger_api_misuse_info`, `xpc_service_main`) are still declared-but-undefined + non-exported + uncalled — safe to defer. The other 2 were census errors (internal symbols counted as public). **Needs-Coordinator-flag: the census list should be pruned to 2 items.**

---

## Part B (id-032) — xpc_connection_get_name stub

### B1: stub confirmed

```c
/* lib/libxpc/xpc_connection.c:269-273 */
const char *
xpc_connection_get_name(xpc_connection_t connection)
{
	return ("unknown"); /* ??? */
}
```

Returns literal `"unknown"` at `xpc_connection.c:272`. The `/* ??? */` comment confirms this is a known stub. Line number matches the census (census was :269, current is :269 — unchanged).

### B2: service-name retention

**NOT retained.** The `xc_name` field EXISTS on the struct (`xpc_internal.h:109: const char *xc_name;` — the first field), but `xpc_connection_create` never assigns it:

```c
/* xpc_connection.c:42-88 */
xpc_connection_create(const char *name, dispatch_queue_t targetq) {
    conn = malloc(sizeof(struct xpc_connection));
    memset(conn, 0, sizeof(struct xpc_connection));  /* xc_name = NULL */
    conn->xc_last_id = 1;
    /* ... queue + port setup ... */
    /* xc_name NEVER assigned */
    return (conn);
}
```

`xpc_connection_create_mach_service` receives `name` but uses it only for `bootstrap_check_in`/`bootstrap_look_up` (the Mach port lookup) — never stores it in `conn->xc_name`.

**Fix shape: retain-at-create + return.** Two lines:
1. In `xpc_connection_create` (or `_mach_service`): `conn->xc_name = name;` (safe — caller's string literal has program lifetime; for dynamic names, consider `strdup`)
2. In `xpc_connection_get_name`: `return (conn->xc_name);` instead of `return ("unknown");`

### B3: macOS behavior cross-check (from header docs)

The rmxOS header's OWN documentation (`connection.h:559-569`) says:
> "Returns the name of the service with which the connections was created."
> "The name of the remote service. If you obtained the connection through an
> invocation of another connection's event handler, NULL is returned."

And for `xpc_connection_create_mach_service`:
> "If non-NULL, the name of the service with which to connect."
> "If NULL, an anonymous listener connection will be created."

macOS behavior (from the header contract):
- Named connection → returns the name string
- Peer connection (obtained via event handler) → returns NULL
- Anonymous connection (name=NULL at create) → returns NULL

rmxOS stub returns "unknown" for ALL cases — diverges from the header's own spec.

After the B2 fix, `get_name` returning `conn->xc_name` would match:
- Named: returns the name (set at create) ✓
- Peer/anonymous: returns NULL (xc_name stays NULL from memset) ✓

```text
OP167_ID032_STUB: confirmed at xpc_connection.c:269-272, returns "unknown"
OP167_ID032_RETENTION: NOT retained — xc_name field exists (xpc_internal.h:109) but never assigned; fix = retain-at-create + return
OP167_ID032_MACOS: header docs say named→returns name, peer/anon→NULL; current stub diverges (returns "unknown" always)
```

**id-032 VERDICT: still-valid-bucket-2.** The stub is confirmed. The fix is well-shaped (2 lines). The `xc_name` field already exists — just needs assignment at create + return in accessor.

---

## OP167 markers

```text
OP167_ID031_DECLS: 2-of-4 valid (debugger_api_misuse_info, service_main); 2 stale (object_validate, unreachable are internal-only)
OP167_ID031_EXPORT: all 4 NOT exported (confirmed via nm -D)
OP167_ID031_CALLERS: 0 internal callers
OP167_ID032_STUB: confirmed xpc_connection.c:269 returns "unknown"
OP167_ID032_RETENTION: NOT retained — xc_name exists (xpc_internal.h:109) but never set; fix = retain-at-create + return
OP167_ID032_MACOS: header docs specify named→name, peer/anon→NULL; stub diverges
OP167_VERDICT id031=partially-stale-needs-census-prune id032=still-valid-bucket-2
OP167_TERMINAL status=0
```
