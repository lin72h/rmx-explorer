# op-189 — libxpc Class-C bucket-3 fill surface inventory (READ-ONLY)

Date: 2026-06-28. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY.
Source: `wip-gpt/wip-rmxos` @ `op-171-x86-64-v3-alpha`. Donor: `nx/NextBSD`.

## Class-C bucket-3 readiness matrix

### Connection lifecycle (xpc_connection.c)

| function | line | status | body | donor (NextBSD) | preview-fill |
|---|---|---|---|---|---|
| `xpc_connection_cancel` | 263-266 | **STUB** | `{}` (empty) | SAME (NextBSD:263 = `{}`) | **LOAD-BEARING** — without cancel, connections can't be torn down; op-122 proved cancel_event_fired=FAIL |
| error/interruption delivery | N/A | **STUB** (implicit) | No code path delivers XPC_ERROR to event handler on cancel/invalidation | SAME | **LOAD-BEARING** — the event handler IS set (line 157) but nothing fires an error event into it; cancel stub = no trigger |
| `xpc_connection_set_finalizer_f` | 330-334 | **STUB** | `{}` (empty) | SAME | **CATALOG-ONLY** — no preview connection uses finalizers |
| `xpc_endpoint_create` | 337-338 | **STUB** | `{}` (empty) | SAME | CATALOG-ONLY |
| `xpc_main` | 343-347 | **PARTIAL** | `dispatch_main();` — runs the dispatch loop but doesn't set up the XPC listener/service lifecycle | SAME | PARTIAL — preview services use `xpc_connection_create_mach_service` + `XPC_CONNECTION_MACH_SERVICE_LISTENER` directly; `xpc_main` is for the launchd-hosted service model (li-008) |
| `xpc_transaction_begin` | 350-353 | **STUB** | `{}` (empty) | SAME | **CATALOG-ONLY** — sudden-termination transactions not needed in preview |
| `xpc_transaction_end` | 356-358 | **STUB** | `{}` (empty) | SAME | CATALOG-ONLY |
| `xpc_connection_get_name` | 269-273 | **STUB** | `return ("unknown");` | SAME | cataloged in op-167 (id-032) |

### Typed-dict completeness (xpc_dictionary.c + xpc_type.c + xpc_array.c)

| function | status | file:line | donor | preview-fill |
|---|---|---|---|---|
| `xpc_dictionary_set_data` | **STUB** | header-declared (xpc.h:2072), NO .c def | gap in donor too | CATALOG-ONLY — substrate completeness |
| `xpc_dictionary_get_data` | **STUB** | header-declared, NO .c def | gap in donor too | CATALOG-ONLY |
| `xpc_dictionary_set_bool` | **IMPLEMENTED** | xpc_dictionary.c:368 — creates bool obj + set_value | N/A | n/a (working) |
| `xpc_dictionary_get_bool` | **IMPLEMENTED** | xpc_dictionary.c:408 | N/A | n/a |
| `xpc_dictionary_set_uint64` | **IMPLEMENTED** | xpc_dictionary.c:388 | N/A | n/a |
| `xpc_dictionary_get_uint64` | **IMPLEMENTED** | xpc_dictionary.c:426 | N/A | n/a |
| `xpc_dictionary_set_double` | **STUB** | header-declared (xpc.h implied via xpc_double_create at :637), NO dict-specific .c def | gap | CATALOG-ONLY |
| `xpc_dictionary_get_double` | **STUB** | NO .c def | gap | CATALOG-ONLY |
| `xpc_data_create` | **IMPLEMENTED** | xpc_type.c:267 | N/A | n/a |
| `xpc_array_create` | **IMPLEMENTED** | xpc_array.c:34 | N/A | n/a |
| `xpc_array_set/get_value` | **IMPLEMENTED** | xpc_array.c:49/92 | N/A | n/a |

### Summary counts

- **STUBS**: 9 (cancel, error-delivery, finalizer, endpoint_create, transaction_begin, transaction_end, get_name, set_data, get_data, set_double, get_double)
- **PARTIAL**: 1 (xpc_main — calls dispatch_main but no listener setup)
- **IMPLEMENTED**: 6 (set_bool, get_bool, set_uint64, get_uint64, data_create, array ops)
- **All STUBS are SAME in NextBSD** — inherited from donor, not rmxOS-port defects

## Preview-fill classification

| tier | items | rationale |
|---|---|---|
| **LOAD-BEARING PREVIEW-FILL** | `cancel` + `error delivery` | Without cancel, connections can't be torn down cleanly. op-122 proved the cancel event handler never fires. This blocks proper connection lifecycle management in ANY XPC-based service. |
| **CATALOG-ONLY** | `finalizer`, `endpoint_create`, `transaction_begin/end`, `set_data/get_data`, `set_double/get_double` | No preview workload exercises these. Substrate completeness for eventual macOS-parity. |

## op-187 coupling

**CANCEL + ERROR DELIVERY are coupled with op-187's reply-context plumbing.**

- op-187 fixes `xpc_dictionary_create_reply` (the reply-correlation mechanism)
- When a connection is cancelled, pending reply contexts should be invalidated (the client's `send_message_with_reply_sync` should unblock with an error)
- The cancel STUB currently does nothing → no invalidation → pending sync sends block forever (the exact op-122 symptom)
- op-187 should NOT be asked to fix cancel/error-delivery (no-fold) — but its reply-context struct should be designed so the future cancel implementation can cleanly invalidate pending replies

**Other items (finalizer, transaction, typed-dict gaps) are NOT coupled with op-187.**

## OP189 markers

```text
OP189_CLASSC_MATRIX: 9 STUBs + 1 PARTIAL + 6 IMPLEMENTED; all STUBs same in NextBSD (inherited from donor)
OP189_PREVIEW_FILL: load-bearing = cancel + error-delivery; catalog-only = finalizer/endpoint/transaction/typed-dict-gaps
OP189_OP187_COUPLING: cancel + error-delivery coupled with reply-context (cancel must invalidate pending replies); other items uncoupled
OP189_VERDICT: inventory-complete
OP189_TERMINAL status=0
```
