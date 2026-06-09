STATUS: Host-only A0 classification / Awaiting Review

# ASL A0 Build Classification

This document classifies the minimal ASL build and receive-path surface before
any A1 runtime implementation. It is host-only evidence. It does not implement
ASL, run a guest, create a certification claim, or migrate D22/D23 launchctl
authority.

## Current Provenance

Oracle repo:

- Path: `/Users/me/wip-mach/wip-gpt-oracle`
- Commit at classification time: `de5560c`

Source roadmap/policy repo:

- Path: `/Users/me/wip-mach/wip-gpt`
- Commit at classification time: `f2bb0f9`
- Dirty state: docs-only edits/untracked docs were present in the source repo.
  A0 did not mutate source files.

ASL donor tree:

- Path: `/Users/me/wip-mach/nx/NextBSD`
- Commit/source identity:
  `8be0f2507b69906d068bed31ffc58cdfafadaef3`
- Dirty state in donor tree: modified Mach IPC kernel files only:
  `sys/compat/mach/ipc/ipc_entry.c`,
  `sys/compat/mach/ipc/ipc_right.c`,
  `sys/sys/mach/ipc/ipc_entry.h`.
  These are not ASL donor files.

Throwaway MIG/build probe inputs:

- MIG tool: `/Users/me/wip-mach/build/m7a-libmach-work/tools/bin/mig`
- Staged Mach include prefix: `/Users/me/wip-mach/build/m7a-libmach-prefix`
- System include root:
  `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/sys`
- Donor defs:
  `/Users/me/wip-mach/nx/NextBSD/lib/libasl/asl_ipc.defs`

## Donor Surface Classification

All donor paths below are from `/Users/me/wip-mach/nx/NextBSD` at
`8be0f2507b69906d068bed31ffc58cdfafadaef3` unless otherwise stated.

| Surface | Donor paths | A0 classification | A1 decision |
| --- | --- | --- | --- |
| `lib/libasl` core library | `lib/libasl/Makefile`, `asl.c`, `asl_core.c`, `asl_msg.c`, `asl_string.c`, `asl_object.c`, `asl_common.c`, `asl_client.c`, `asl_memory.c`, headers | Donor client library and ASL message codec. It is broader than the first runtime claim because full `asl_open()` / `asl_send()` touches bootstrap lookup, notify filters, quota/config behavior, and syslog compatibility. | Use only the minimum donor codec/stub pieces needed to create one `_asl_server_message` OOL payload. Full `libasl` public API and `syslog(3)` compatibility stay deferred unless A1 proves they are required. |
| ASL MIG contract | `lib/libasl/asl_ipc.defs`, generated `asl_ipc.h`, generated user/server stubs | Central ASL transport contract. Defines subsystem `asl_ipc 114`; `_asl_server_message` is message id 118 and is a MIG simpleroutine with OOL byte data and an audit token. | In scope for A1. A1 must enter the generated ASL MIG demux/decode path and target `_asl_server_message`, not a hand-written toy receiver. |
| ASL daemon minimal receive path | `usr.sbin/asl/dbserver.c`, `usr.sbin/asl/daemon.h`, generated `usr.sbin/asl/asl_ipc.h` | `database_server()` receives Mach messages with audit trailers and calls `asl_ipc_server()`. `__asl_server_message()` validates/deallocates OOL bytes, parses the ASL message, decodes UID/GID/PID from `audit_token_t`, optionally performs session tracking with `task_name_for_pid`, and calls `process_message`. | A1 can drive donor `asl_ipc_server()` plus donor `__asl_server_message()` inside a project-owned harness. Storage, watchers, and daemon lifecycle should be stubbed/fenced. |
| Full `asld` daemon | `usr.sbin/asl/Makefile`, `syslogd.c`, `daemon.c`, `asl_action.c`, `klog_in.c`, `bsd_in.c`, `bsd_out.c`, `udp_in.c`, `remote.c`, `com.apple.syslogd.plist` | Broad daemon product: launchd check-in, BSD/UDP sockets, klog input, output modules, config, database, remote input, and dispatch timers/sources. | Deferred for A1 except where `dbserver.c` receive code pulls small support hooks. Full service handoff becomes A2 if A0/A1 proves launchd handoff is required. |
| Syslog compatibility | `lib/libasl/syslog.c`, `lib/libasl/syslog.3`, `usr.sbin/asl/bsd_in.c`, `usr.sbin/asl/bsd_out.c`, `usr.sbin/asl/udp_in.c`, `usr.sbin/asl/remote.c`, `usr.sbin/asl/syslogd.c` | Compatibility input/output paths, sockets, UDP, BSD syslog, and remote behavior. | Deferred. A1 should use a project-owned ASL/MIG probe, not libc `syslog(3)` or socket syslog. |
| `aslmanager` | `usr.sbin/aslmanager/Makefile`, `usr.sbin/aslmanager/aslmanager.c` | Rotation/archive/prune helper with XPC server path and broad link dependencies. | Deferred. It is not needed to prove one ASL message transport/receive path. |
| `libnotify` pulls | `lib/libnotify`, uses from `lib/libasl/asl.c`, `lib/libasl/asl_msg.c`, `usr.sbin/asl/daemon.c`, `usr.sbin/asl/asl_action.c`, `usr.sbin/asl/bsd_out.c`, `usr.sbin/asl/remote.c`, `usr.sbin/asl/syslogd.c` | Notification/config/quota/update behavior. Concrete symbols seen include `notify_register_plain`, `notify_register_dispatch`, `notify_register_file_descriptor`, `notify_check`, `notify_get_state`, `notify_post`, `notify_cancel`, and `NOTIFY_STATUS_OK`. | Stub/fence by default for A1. If a concrete A1 compile path pulls one of these symbols, provide a narrow stub and record it as support, not a notify claim. |
| Audit/BSM pulls | `contrib/openbsm`, `lib/libbsm`, `dbserver.c` include/use of `audit_token_t` and `audit_token_to_au32` | ASL receive identity uses Mach audit trailers and BSM token decoding. Full audit daemon or audit policy is not required by the first transport claim. | Keep audit-token-only scope. If audit token delivery is unavailable, A1 can claim OOL transport only, not ASL audit identity. |
| XPC pulls | `lib/libxpc`, `usr.sbin/aslmanager/aslmanager.c`, `usr.sbin/asl/dbserver.c` entitlement helper under embedded path, `lib/libasl/asl_util.c` ASL manager trigger | XPC appears in deferred manager/entitlement/trigger paths. `aslmanager` links and serves XPC; `dbserver.c` entitlement inspection is not part of the plain A1 receive path unless embedded entitlement checks are enabled. | Deferred for A1. Fence embedded entitlement paths and ASL manager trigger paths unless a concrete compile/link pull proves otherwise. |
| `libosxsupport` and BlocksRuntime | `lib/libosxsupport`, `lib/libblocksruntime`, broad ASL/aslmanager Makefile link lines | Support-library link dependencies for Blocks/dispatch/XPC-oriented product code. | Not an ASL semantic claim. Pull only if the selected donor object set requires it, and classify as support glue. |
| Launchd handoff | `usr.sbin/asl/com.apple.syslogd.plist`, `usr.sbin/asl/syslogd.c` launch config path | Full product startup gets `com.apple.system.logger` from launchd check-in. A1 can avoid this by using a project-owned server port setup. | Not required for A1 unless the A1 design chooses full `asld` launch. If launchd check-in is required, it becomes A2, not part of the first ASL receive proof. |

## MIG Status

`asl_ipc.defs` was regenerated with the staged current MIG tool using the
throwaway host command shape below:

```text
/Users/me/wip-mach/build/m7a-libmach-work/tools/bin/mig
  -I/Users/me/wip-mach/build/m7a-libmach-prefix/include
  -I/Users/me/wip-mach/build/m7a-libmach-prefix/include/apple
  -I/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/sys
  -I/Users/me/wip-mach/nx/NextBSD/lib/libasl
  -user asl_ipcUser.c
  -server asl_ipcServer.c
  -header asl_ipc.h
  -sheader asl_ipcServer.h
  /Users/me/wip-mach/nx/NextBSD/lib/libasl/asl_ipc.defs
```

Result:

- `mig_rc=0`
- generated client stub: `asl_ipcUser.c` (`42917` bytes)
- generated server stub: `asl_ipcServer.c` (`42362` bytes)
- generated user header: `asl_ipc.h` (`17108` bytes)
- generated server header: `asl_ipcServer.h` (`23953` bytes)
- `cc -c asl_ipcUser.c`: pass, object size `7848` bytes
- `cc -c asl_ipcServer.c`: pass, object size `8424` bytes

Generated stub facts:

- subsystem: `asl_ipc 114`
- generated message id range: 114 through 122
- `_asl_server_message` generated client sends `msgh_id = 118`
- generated server dispatch calls donor `__asl_server_message(...)` with the
  OOL message pointer/count and `TrailerP->msgh_audit`
- `_asl_server_message` remains a simpleroutine/no-reply shape

No host compile-time ABI/layout blocker was found for generated subsystem 114
client/server stubs with the staged MIG and Mach headers. Runtime acceptance is
still not implied: A1 must prove OOL memory delivery/deallocation, audit trailer
availability, and simpleroutine behavior inside the guest.

Deferred MIG paths:

- `_asl_server_query`, `_asl_server_query_timeout`, `_asl_server_query_2`, and
  `_asl_server_match` reply with OOL data and are outside A1.
- `_asl_server_create_aux_link` returns a moved send right/fileport and is
  outside A1.
- direct watch registration/cancel uses separate watch/socket behavior and is
  outside A1.

## Minimal A1 Receiver Shape

A1 can use donor `asl_ipc_server()` plus donor `__asl_server_message()` as the
receive/decode path. It must not replace the receive side with a toy parser that
only looks for bytes in a Mach message.

Recommended A1 shape:

- project-owned server setup creates the receive right used by the client
  probe;
- project-owned client sends one `_asl_server_message` OOL payload generated
  from the donor ASL MIG client shape or an equivalent project-owned client
  that uses the generated request format;
- server receives one message with `MACH_RCV_TRAILER_AUDIT` requested;
- server passes the raw Mach request through generated `asl_ipc_server()`;
- donor `__asl_server_message()` validates null termination, deallocates OOL
  memory, parses the ASL message, and calls a stubbed `process_message`;
- `process_message` records the parsed key/value message and source as A1
  evidence instead of writing to disk or running full daemon policy.

Stub/fence decisions for A1:

- `process_message` / storage: stub to record one parsed message and source;
  do not open ASL memory/file databases or trigger rotation.
- Session tracking: fence or stub `task_name_for_pid` and
  `register_session`. If this remains disabled/stubbed, do not claim session
  tracking.
- `task_name_for_pid`: deferred unless the A1 claim explicitly includes session
  registration and the Mach substrate supports it.
- Notify/config/quota paths: stub/fence. They are not needed for one
  `_asl_server_message` transport proof.
- Watchers/direct watch: deferred.
- Launchd check-in: deferred to A2 if required by a later full service claim.

## Mach Substrate Check

| Mach surface | A0 classification | A1 impact |
| --- | --- | --- |
| OOL byte payload with dealloc | Supported as an accepted Mach substrate for same-process OOL data, but not yet proven through the ASL `_asl_server_message` donor path. `_asl_server_message` requires `message : ooline_data, dealloc`. | In scope. A1 must show donor ASL OOL bytes arrive intact and are consumed through the donor decode path. |
| `MACH_RCV_TRAILER_AUDIT` / `audit_token_t` | Partially supported/observable: accepted launchd paths request audit trailers, and ASL generated server stubs pass `TrailerP->msgh_audit` into `__asl_server_message`. A0 does not prove non-zero ASL sender identity. | In scope only if available. If unavailable or zero-only, A1 can claim OOL transport/decode, not ASL audit identity. |
| Port-set receive | Supported as an accepted Mach substrate. Donor `database_server()` receives on `global.listen_set`, but minimal A1 can avoid full daemon port-set setup by using a project-owned receive loop that still calls `asl_ipc_server()`. | Not required for the first A1 claim unless A1 chooses to drive `database_server()` itself. |
| MIG simpleroutine no-reply | Supported as a staged MIG shape: generated stubs for `_asl_server_message` build, and the donor path treats message 118 as a simpleroutine/no-reply case. Runtime behavior still needs ASL-specific proof. | In scope. A1 should record the send/receive return behavior and confirm no reply is required for the selected message path. |
| `task_name_for_pid` | Not accepted as required ASL substrate. It is pulled by optional session tracking after audit-token PID extraction, but it is not needed to prove payload delivery and parsing. | Defer/stub by default. If enabled, it becomes a separate session/identity claim. |

## Dependency Decisions

- `libnotify`: stub/fence by default. Exact observed symbols/functions that may
  be pulled by wider ASL code include `notify_register_plain`,
  `notify_register_dispatch`, `notify_register_file_descriptor`,
  `notify_check`, `notify_get_state`, `notify_post`, `notify_cancel`, and
  `NOTIFY_STATUS_OK`.
- `libauditd` / `libbsm`: keep audit-token-only scope. `audit_token_t` and
  `audit_token_to_au32` are relevant; broader audit daemon behavior is not.
- libc `syslog(3)`, BSD socket input, UDP syslog, remote syslog: deferred.
- XPC and `aslmanager`: deferred.
- `libosxsupport` / BlocksRuntime: support-library disposition only, not a
  semantic ASL claim.
- Launchd handoff: not required for A1 unless a concrete implementation path
  proves otherwise. If needed, it is an A2 resource-handoff gate.

## Proposed First Runtime Claim

A1 should target this claim:

```text
A project-owned ASL client sends one _asl_server_message OOL payload to a
receiver using the donor ASL MIG demux/decode path; OOL bytes arrive intact;
audit identity is either observed and matched, or explicitly deferred from the
claim.
```

Acceptance constraints for that claim:

- It is L2 guest integration evidence only.
- It is not a certification claim.
- It must use generated ASL MIG demux/decode or an equivalent donor-derived
  request format; a toy receiver is not accepted ASL proof.
- If audit identity is claimed, the evidence must include the received audit
  token fields and a sender identity match.
- If `task_name_for_pid` is stubbed or unavailable, session tracking is outside
  the claim.
- If launchd check-in is not used, the claim is ASL transport/decode only, not
  product service startup.

## Guardrails Observed

- No guest run was performed.
- No ASL implementation was added.
- No D22/D23 launchctl migration was performed.
- No source-side file was edited.
- No source deletion occurred.
- No `certification/` or `artifacts/` directory was created.
- `oracle-parity-a30ef3f` was not moved.
