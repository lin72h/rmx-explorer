# op-135 — libxpc macOS-truth surface (mx-a64z, macOS 27)

macOS-side reference for the id-021/li-007 divergence ledger: Apple's actually-shipped
libxpc surface + expected behavior, so rmxOS Class-B (declared/zero-impl) and Class-C
(defined-but-stub) gaps can be confirmed real-vs-Apple rather than header-vs-our-.c.

## Provenance

- host:      mm4.local — macOS 27.0 (Darwin 27.0.0), arm64 (Apple M4)
- compiler:  Apple clang 17.0.0; SDK MacOSX.sdk (Xcode-beta)
- export source: `MacOSX.sdk/usr/lib/system/libxpc.tbd` — Apple's canonical re-export list
  (802 symbols). NOTE: on macOS 27 the shipped dylib lives in the dyld shared cache only;
  there is no on-disk `/usr/lib/system/libxpc.dylib`, so the `.tbd` (the linker's authoritative
  interface) is the equivalent of `nm -gU /usr/lib/system/libxpc.dylib`.
- public headers: `MacOSX.sdk/usr/include/xpc/{activity,base,connection,endpoint,listener,
  peer_requirement,rich_error,session,xpc}.h`
- full export list: `libxpc-macos-exports.txt` (802 sorted symbols) — grep this for the
  Class-B/C per-symbol join.

## Exported surface summary (counts; from libxpc-macos-exports.txt)

| surface | exported | surface | exported |
|---|---:|---|---:|
| xpc_connection | 60 | xpc_session | 16 |
| xpc_dictionary | 45 | xpc_array | 34 |
| xpc_activity | 20 | xpc_copy (family) | 15 |
| xpc_listener | 10 | xpc_endpoint | 9 |
| xpc_data | 7 | xpc_date | 6 |
| xpc_pipe | 17 | xpc_shmem | 4 |
| xpc_fd | 2 | xpc_rich_error | 2 |
| xpc_retain / xpc_release | 1 / 1 | xpc_uint64/int64/bool/double/uuid | 2 ea |

## Named surfaces (Apple-shipped, macOS=present) + expected behavior

### xpc_activity_* (20) — system-scheduled background activities
`xpc_activity_register`, `_unregister`, `_set_criteria`, `_copy_criteria`, `_set_state`,
`_get_state`, `_should_defer`, `_defer_until_network_change`, `_defer_until_percentage`,
`_get_percentage`, `_set_network_threshold`, `_set_completion_status`, `_run`, `_list`,
`_debug`, `_add_eligibility_changed_handler`, `_remove_eligibility_changed_handler`,
`_copy_dispatch_queue`, `_copy_identifier`, `_should_be_data_budgeted`.
Behavior: NOT a timer — activities are registered with an `xpc_activity_criteria_t`
(interval / min-interval / grace-period / repeats / allow-battery / precedence) and the
**system** schedules when they fire (opportunistic, budget/battery/network-gated). The
handler calls `xpc_activity_set_state(CONTINUE|DEFER|WAIT|DONE)` to drive the lifecycle;
`should_defer` / `get_percentage` reflect the current budget. A rmxOS Class-B stub here
= no real system scheduling (the "activity" would never be dispatched by the kernel/launchd).

### xpc_shmem_* (4) — shared memory over XPC
`xpc_shmem_create`, `_create_readonly`, `_get_length`, `_map`.
Behavior: wraps a caller-mmap'd region into an xpc object that is **transmitted over an
xpc connection**; the recipient `xpc_shmem_map`s it into its own address space (read-only
variant enforces RO on the peer). Stub = the object exists but no real shared mapping is
plumbed across the boundary.

### xpc_copy / xpc_retain / xpc_release — object memory model
`xpc_copy` (deep copy → independent object), `xpc_retain`, `xpc_release` (refcount).
Behavior: `xpc_object_t` is refcounted; `xpc_copy` produces a deep, independent copy
(not just a +1 retain). Also `xpc_copy_*` family: `_description`, `_debug_description`,
`_short_description`, `_clean_description`, `_bootstrap`, `_event`, `_entitlements_*`,
`_code_signing_identity_for_token` (introspection/entitlement copies).

### event-stream / incoming-message handler
`xpc_connection_set_event_handler` (legacy), `xpc_session_set_incoming_message_handler`,
`xpc_copy_event`, `xpc_copy_event_entitlements`.
Behavior: the block set here is invoked on each incoming message/event (and on the final
error/cancel event). The session variant is the modern API; `xpc_copy_event` lets the
handler defer/inspect the current event.

### cancel / error delivery
`xpc_connection_cancel`, `xpc_session_cancel`, `xpc_listener_cancel`, `xpc_cancel` is not
a separate symbol (cancel is per-object); `xpc_rich_error_can_retry`, `_copy_description`.
Behavior: cancel tears the object down and **delivers a final error event** to the peer's
handler; `xpc_rich_error_t` carries retry-ability + a human description. A Class-C stub
here = cancel doesn't propagate the terminal event / no rich-error detail.

### core connection / session / listener / endpoint
- xpc_connection_* (60): full legacy surface — `create`/`create_mach_service`/`create_from_endpoint`,
  `set_event_handler`/`set_target_queue`/`activate`/`cancel`/`send_message`/`send_message_with_reply*
  /`resume`/`suspend`, peer audit + entitlements.
- xpc_session_* (16): modern replacement — `create_xpc_service`/`_mach_service`/`_xpc_endpoint`,
  `set_incoming_message_handler`/`set_peer_requirement`/`set_target_queue`/`activate`/`cancel`,
  `send_message[_with_reply_async|_sync]`.
- xpc_listener_* (10): server side — `create`/`_anonymous`/`_endpoint`/`activate`/`cancel`/
  `set_incoming_session_handler`/`set_peer_requirement`/`reject_peer`.
- xpc_endpoint_* (9): `create`, `_create_bs_named[_user|_service]`, `_compare`,
  `_get_bs_job_handle` (+ 2 simulator-only `_4sim` shims).
- xpc_fd_* (2): `xpc_fd_create`, `_dup` (file-descriptor passing over xpc).

## Class-B/C cross-reference (op-135 step 3) — PENDING li-007

The rmxOS Class-B (declared, zero-impl) + Class-C (defined-but-stub) symbol lists live in
**`l1i/li-007-libxpc-core-service.md`**, which is **NOT in this repo** (it's in the rmxOS
tree — propagation gap; not ferried to rmx-explorer). 

The macOS reference is complete and ready (this catalog + `libxpc-macos-exports.txt`).
Step 3 — the per-symbol `symbol: macOS=present|absent | behavior-note` join — is a one-line
grep of each Class-B/C symbol against `libxpc-macos-exports.txt` + attachment of the behavior
note above; it runs the moment `li-007` is ferried. No macOS re-run needed to finish it.

## Out of scope
nvlist wire byte format (Class A, decided); any rmxOS run; product edits. Observation-only
macOS-truth capture.
