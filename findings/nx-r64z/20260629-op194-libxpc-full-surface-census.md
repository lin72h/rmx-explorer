# op-194 — libxpc FULL public surface census + id-021 gap ledger (READ-ONLY)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY.
Source: `wip-gpt/wip-rmxos` @ HEAD `501a1ef454c5` ("libxpc: deliver cancel and peer-death errors").
**RECONCILE:** op-191 (cancel + error delivery) has been applied — the op-189 STUB list is PARTIALLY STALE. This census reflects the CURRENT state.

## D1: surface enumeration (7 source files, ~358 function definitions)

| file | functions | covers |
|---|---|---|
| `xpc_connection.c` | 41+9 internal | connection lifecycle, send/receive, cancel/interrupt/error (op-191), peer-death monitoring |
| `xpc_type.c` | 32 | 16-type object model (null/bool/int64/uint64/double/date/data/string/uuid + get_type/equal/hash) |
| `xpc_dictionary.c` | 23 | dictionary create/reply/set/get/apply + mach port ops |
| `xpc_array.c` | 26 | array create/set/get/count |
| `xpc_misc.c` | 20 | retain/release/strerror/copy_description/pack/unpack + pipe_* internal IPC |
| `subr_nvlist.c` | 133 | nvlist wire serialization (internal) |
| `subr_nvpair.c` | 83 | nvpair primitives (internal) |

## D2: classified surface

### Connection lifecycle (xpc_connection.c)

| API | line | class | detail |
|---|---|---|---|
| `xpc_connection_create` | 49 | **REAL** | malloc + queues + local port |
| `xpc_connection_create_mach_service` | 98 | **REAL** | bootstrap_check_in/look_up |
| `xpc_connection_create_from_endpoint` | 139 | **PARTIAL** | creates conn but endpoint_create is STUB → can't get valid endpoint |
| `xpc_connection_set_target_queue` | 153 | **REAL** | sets xc_target_queue |
| `xpc_connection_set_event_handler` | 164 | **REAL** | sets handler + dispatch source |
| `xpc_connection_suspend` | 175 | **REAL** | dispatch_suspend(recv_queue) |
| `xpc_connection_resume` | 184 | **REAL** | dispatch_resume + arms proc source |
| `xpc_connection_send_message` | 217 | **REAL** | seqid + xpc_send |
| `xpc_connection_send_message_with_reply` | 237 | **REAL** | async + pending queue |
| `xpc_connection_send_message_with_reply_sync` | 259 | **REAL** | sync wrapper (semaphore) |
| `xpc_connection_send_barrier` | 278 | **REAL** | dispatch_sync(send_queue) |
| `xpc_connection_cancel` | 287 | **REAL (op-191)** | atomic flag + invalidate(CONNECTION_INVALID) |
| `xpc_connection_get_name` | 299 | **STUB** | returns "unknown" (id-032, op-167) |
| `xpc_connection_get_euid` | 306 | **REAL** | returns xc_remote_euid |
| `xpc_connection_get_guid` | 315 | **REAL** | returns xc_remote_guid |
| `xpc_connection_get_pid` | 324 | **REAL** | returns xc_remote_pid |
| `xpc_connection_get_asid` | 333 | **REAL** | returns xc_remote_asid |
| `xpc_connection_set_context` | 342 | **REAL** | sets xc_context |
| `xpc_connection_get_context` | 351 | **REAL** | returns xc_context |
| `xpc_connection_set_finalizer_f` | 360 | **STUB** | empty {} |
| `xpc_endpoint_create` | 367 | **STUB** | empty {} |
| `xpc_main` | 373 | **PARTIAL** | calls dispatch_main() but ignores handler arg |
| `xpc_transaction_begin` | 380 | **STUB** | empty {} |
| `xpc_transaction_end` | 386 | **STUB** | empty {} |

**op-191 internal (all REAL):** invalidate(442), complete_pending(410), deliver_event(428), interrupt(450), remote_dead(462), remote_proc_dead(469), arm_proc_source(476), set_credentials(496), recv_message(517)

### 16-type object model (xpc_type.c) — ALL REAL

| type | create | get | line |
|---|---|---|---|
| null | `xpc_null_create` | n/a | 207 |
| bool | `xpc_bool_create` | `xpc_bool_get_value` | 214/223 |
| int64 | `xpc_int64_create` | `xpc_int64_get_value` | 238/247 |
| uint64 | `xpc_uint64_create` | `xpc_uint64_get_value` | 262/271 |
| double | `xpc_double_create` | `xpc_double_get_value` | 286/295 |
| date | `xpc_date_create` / `_from_current` | `xpc_date_get_value` | 306/315/321 |
| data | `xpc_data_create` | `get_length` / `get_bytes_ptr` / `get_bytes` | 335/350/364/378 |
| string | `xpc_string_create` / `_with_format` | `get_length` / `get_string_ptr` | 386/395/416/430 |
| uuid | `xpc_uuid_create` | `xpc_uuid_get_bytes` | 444/453 |
| meta | `xpc_get_type` / `xpc_equal` / `xpc_hash` | — | 468/477/495 |

### Dictionary (xpc_dictionary.c)

| API | line | class |
|---|---|---|
| `xpc_dictionary_create` | 227 | **REAL** |
| `xpc_dictionary_create_reply` | 243 | **PARTIAL** (op-187 target — returns NULL currently, li-1008) |
| `xpc_dictionary_get_audit_token` | 264 | **REAL** |
| `xpc_dictionary_set_mach_recv` | 273 | **REAL** |
| `xpc_dictionary_set_mach_send` | 286 | **REAL** |
| `xpc_dictionary_copy_mach_send` | 298 | **REAL** |
| `xpc_dictionary_set_value` | 316 | **REAL** |
| `xpc_dictionary_get_value` | 341 | **REAL** |
| `xpc_dictionary_get_count` | 359 | **REAL** |
| `xpc_dictionary_set_bool` | 368 | **REAL** |
| `xpc_dictionary_set_int64` | 378 | **REAL** |
| `xpc_dictionary_set_uint64` | 388 | **REAL** |
| `xpc_dictionary_set_string` | 398 | **REAL** |
| `xpc_dictionary_get_bool` | 408 | **REAL** |
| `xpc_dictionary_get_int64` | 417 | **REAL** |
| `xpc_dictionary_get_uint64` | 426 | **REAL** |
| `xpc_dictionary_get_string` | 435 | **REAL** |
| `xpc_dictionary_apply` | 444 | **REAL** |
| `xpc_dictionary_set_data` | — | **STUB** (header-declared, no .c def) |
| `xpc_dictionary_get_data` | — | **STUB** |
| `xpc_dictionary_set_double` | — | **STUB** |
| `xpc_dictionary_get_double` | — | **STUB** |

### Array + Misc + Serialization

| API group | class | detail |
|---|---|---|
| `xpc_array_create/set_value/get_value/get_count` | **REAL** | xpc_array.c:34-114 |
| `xpc_retain` / `xpc_release` | **REAL** | xpc_misc.c:152/165 |
| `xpc_strerror` / `xpc_copy_description` | **REAL** | xpc_misc.c:188/197 |
| `xpc_pack` / `xpc_unpack` | **REAL** | xpc_misc.c:109/129 (nvlist wire serialization) |
| `xpc_pipe_*` (send/receive/try_receive/routine_reply) | **REAL** | xpc_misc.c:365-543 (internal Mach IPC transport) |
| `ld2xpc` | **REAL** | xpc_misc.c:327 (launch_data conversion) |
| `xpc_copy_entitlement_for_token` | **STUB** | xpc_misc.c:354 (args __unused) |
| `xpc_activity_*` | **STUB** | header only (`xpc/activity.h`), no .c |
| `xpc_call_wakeup` | **REAL** | xpc_misc.c:543 |

## D3: id-021 gap ledger (ordered: preview-load-bearing first, then MACH_RECV, then launchd-join)

| # | API | class | file:line | macOS behavior | plane | preview-load-bearing? |
|---|---|---|---|---|---|---|
| 1 | `xpc_dictionary_create_reply` | PARTIAL | xpc_dictionary.c:243 | Creates reply dict routed back to sender via internal correlation | MACH_RECV | **YES** (blocks send→reply round-trip; op-187 target) |
| 2 | `xpc_connection_get_name` | STUB | xpc_connection.c:299 | Returns the service name from create; NULL for peers/anon | pure-userland | NO (cosmetic; id-032) |
| 3 | `xpc_dictionary_set_data` | STUB | (no .c) | Sets raw byte data in dict via nvlist | pure-userland | NO (substrate completeness) |
| 4 | `xpc_dictionary_get_data` | STUB | (no .c) | Gets raw byte data from dict | pure-userland | NO |
| 5 | `xpc_dictionary_set_double` | STUB | (no .c) | Sets double value in dict | pure-userland | NO |
| 6 | `xpc_dictionary_get_double` | STUB | (no .c) | Gets double value from dict | pure-userland | NO |
| 7 | `xpc_connection_set_finalizer_f` | STUB | xpc_connection.c:360 | Called when connection deallocated; cleans up context | launchd-join | NO (preview connections don't use finalizers) |
| 8 | `xpc_endpoint_create` | STUB | xpc_connection.c:367 | Creates an endpoint from a connection for passing to another conn | launchd-join | NO (preview doesn't use endpoint passing) |
| 9 | `xpc_main` | PARTIAL | xpc_connection.c:373 | Sets up XPC service listener + registers with launchd + dispatch_main | launchd-join | NO (preview uses create_mach_service directly) |
| 10 | `xpc_transaction_begin` | STUB | xpc_connection.c:380 | Begins a transaction (sudden-termination bookkeeping) | launchd-join | NO |
| 11 | `xpc_transaction_end` | STUB | xpc_connection.c:386 | Ends a transaction | launchd-join | NO |
| 12 | `xpc_copy_entitlement_for_token` | STUB | xpc_misc.c:354 | Returns security entitlement for audit token | launchd-join | NO |
| 13 | `xpc_activity_*` | STUB | (header only) | Scheduled activity API (background tasks) | launchd-join | NO (out-of-preview; Class-D) |

**Stale-from-op-189 (now FILLED by op-191):**
- ~~`xpc_connection_cancel`~~ — NOW REAL (line 287)
- ~~error/interruption delivery~~ — NOW REAL (invalidate + deliver_event + interrupt + complete_pending + arm_proc_source)

## OP194 markers

```text
OP194_SURFACE_ENUM: 7 files, ~358 functions; 16-type model all REAL; connection lifecycle 17 REAL + 5 STUB + 2 PARTIAL; dictionary 14 REAL + 4 STUB + 1 PARTIAL
OP194_CLASSIFIED: 13 gaps total (1 PARTIAL load-bearing + 4 typed-dict STUBs + 7 launchd-join STUBs + 1 PARTIAL xpc_main); op-191 filled cancel+error (verified first-hand)
OP194_LEDGER: see D3 table above (ordered by preview-load-bearing → MACH_RECV → launchd-join)
OP194_VERDICT: census-complete
OP194_TERMINAL status=0
```
