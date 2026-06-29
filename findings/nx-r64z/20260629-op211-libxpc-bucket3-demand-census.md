# op-211 — libxpc connection-lifecycle preview-demand census (READ-ONLY)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY source census.
Source: `wip-gpt/wip-rmxos` @ `op-171-x86-64-v3-alpha`. Consumes op-189 (stub inventory) + op-190 (macOS contract) as inputs — does NOT re-inventory.

## D1: xpc_domain state — REAL code, DARK at runtime

The xpc_domain functions are **REAL implementations** (not stubs) in launchd `core.c`:

| function | file:line | implementation | runtime state |
|---|---|---|---|
| `xpc_domain_load_services` | core.c:10454 | Unpacks nvlist service defs via `launch_data_unpack`, imports via `_xpc_domain_import_services`, wakes requester via `xpc_call_wakeup`. Gates on `BOOTSTRAP_PROPERTY_XPC_DOMAIN` + `xpc_bootstrapper`. | **DARK** (op-195: property never set, no XPC service bundles exist) |
| `xpc_domain_check_in` | core.c:10502 | Returns bootstrap port, sub-bootstrap, exception port, audit port, uid/gid/asid, context — all real fields from job manager. Gates on `BOOTSTRAP_PROPERTY_XPC_DOMAIN` + `req_asport != MACH_PORT_NULL`. | **DARK** (same gate) |
| `xpc_domain_get_service_name` | core.c:10542 | Walks job's machservices list to find service name. Gates on `j->xpc_service` flag. | **DARK** (no XPC services registered) |

The xpc_domain code path is a **complete real implementation that is unreachable** in the current preview because:
1. `BOOTSTRAP_PROPERTY_XPC_DOMAIN` is never set (no XPC service bundles to trigger domain creation)
2. `xpc_bootstrapper` is never claimed by any job
3. The entire XPC domain creation + check-in protocol is dormant

This means launchd's XPC service-hosting plane exists as code but does NOT stand up at runtime. The current libxpc path works via the **MachServices/bootstrap** mechanism (op-195: LIVE), NOT via xpc_domain.

```text
OP211_XPCDOMAIN_STATE: real-code-dark-runtime — full implementations (load_services core.c:10454, check_in core.c:10502, get_service_name core.c:10542) but BOOTSTRAP_PROPERTY_XPC_DOMAIN never set → unreachable in preview
```

## D2: consumer-demand census

Exhaustive grep across the ENTIRE preview userland (sbin/, lib/, usr.sbin/, usr.bin/, tools/) for every call site of the bucket-3 APIs:

### xpc_connection_cancel

| call site | file:line | classification |
|---|---|---|
| `aslmanager.c:179` — `xpc_connection_cancel(listener)` | usr.sbin/aslmanager/aslmanager.c:179 | **DEAD** — aslmanager is ABSENT from the preview image (op-170/op-205) and CRASHES at startup (op-204/op-205) |

**Zero live preview consumers.**

### XPC_ERROR_CONNECTION_INVALID / INTERRUPTED / TERMINATION_IMMINENT

| call site | file:line | classification |
|---|---|---|
| (none outside libxpc) | — | — |

**Zero consumers** in the preview userland check for any XPC_ERROR_* constant. The error constants are defined in libxpc headers (`connection.h:33/40`) and the string "Connection invalid" is defined in `xpc_type.c:79-80`, but **no consumer code compares against them**.

Notably:
- libasl: **ZERO** XPC_ERROR references (grepped `lib/libasl/*.c`)
- libnotify: **ZERO** XPC_ERROR references
- launchd core.c: **ZERO** XPC_ERROR references (launchd doesn't use the libxpc error-delivery path)
- op-160 xpc-service.c: **ZERO** XPC_ERROR references

### xpc_transaction_begin / xpc_transaction_end

| call site | file:line | classification |
|---|---|---|
| (none outside libxpc) | — | — |

**Zero consumers.** Only the stub definitions in `xpc_connection.c:404/410`.

### xpc_connection_set_finalizer_f

| call site | file:line | classification |
|---|---|---|
| (none outside libxpc) | — | — |

**Zero consumers.** Only the stub definition in `xpc_connection.c:376`.

### Summary: ZERO live preview consumer demand for ANY bucket-3 API

```text
OP211_CONSUMER_DEMAND:
  xpc_connection_cancel: 1 caller (aslmanager) → DEAD (not shipped + crashes)
  XPC_ERROR_*: 0 callers → DEAD
  xpc_transaction_begin/end: 0 callers → DEAD
  xpc_connection_set_finalizer_f: 0 callers → DEAD
```

## D3: verdict

**CHALLENGES-GATE.** The bucket-3 fill (cancel + error delivery, filled by op-191) has **ZERO live consumer demand** in the preview userland. No preview service, library, daemon, or harness calls `xpc_connection_cancel`, checks `XPC_ERROR_*`, uses transactions, or sets finalizers.

The op-191 implementation IS real and working (op-194 verified cancel+error delivery code path). But it is **PROVIDER-side infrastructure with no CONSUMER-side demand**. Like building a fire escape that nobody uses — it's there if needed, but its absence wouldn't affect the preview.

**Blast-radius if bucket-3 is deferred (not gated):**
- The op-122 xpc-harness-plane test exercises cancel→error (it's the ONLY test that does). If bucket-3 is deferred, the op-122 PLANE CASE 3 (cancel→XPC_ERROR) would FAIL. But op-122 is a TEST, not a preview consumer.
- No preview daemon (notifyd, asld, devd) depends on cancel/error/transaction/finalizer.
- The 4 core services (notify, asl, dispatch, mach-IPC) work via MachServices/bootstrap, NOT via xpc_domain.

**Report, not re-decide:** the Arranger resolved bucket-3 gates the preview. This census provides the evidence that **the gate stands on architectural completeness (the code path exists and works), not on live consumer demand (nothing in the preview exercises it)**. The Arranger may soften the gate to li-005 (post-preview catalog) based on this evidence — that's their call.

```text
OP211_VERDICT: challenges-gate — zero live preview consumer demand for any bucket-3 API; cancel+error filled by op-191 but unused; gate stands on architectural completeness not demand
```
