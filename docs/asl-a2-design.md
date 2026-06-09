STATUS: Draft / Awaiting Review

# ASL A2 Design

This document designs ASL A2 only. It authorizes no implementation, guest run,
marker manifest entry, source-side edit, certification claim, or evidence
artifact.

A2 follows the accepted ASL A1 closeout:

- A1 accepted runtime evidence closeout:
  `2305e7457b190cbdeafc146138aa33e8107dd4d5`
- A1 marker authority:
  `ab92a5b9dfd2d9ecbd54002bae72db08a4a9c201`
- A1 accepted claim: `ool_transport_decode_plus_audit_identity`
- A1 non-claims remain: no launchd handoff, no storage/query, no
  syslog/aslmanager/XPC/libnotify, and no certification claim.
- ASL donor tree: `/Users/me/wip-mach/nx/NextBSD`
- ASL donor commit:
  `8be0f2507b69906d068bed31ffc58cdfafadaef3`

A2 is one design with two subclaims:

- Subclaim A: launchd/resource-handoff side.
- Subclaim B: ASL consumer lookup/send side.

A2 is accepted only if Subclaim A and Subclaim B pass in one accepted run.
Subclaim A alone is useful transitional evidence, but it is not accepted A2.

## 1. Exact Runtime Claim

Falsifiable A2 runtime claim:

```text
A2 proves that a server obtains the com.apple.system.logger receive right
through launchd MachServices check-in and that a donor ASL client lookup
resolves a send right to that same checked-in server, demonstrated by a nonce
_asl_server_message sent over the resolved port and received by the checked-in
server.
```

This is new proof beyond A1:

- A1 proved direct ASL `_asl_server_message` OOL transport/decode plus audit
  identity in a project-owned handoff path.
- A2 proves launchd service discovery and resource handoff for
  `com.apple.system.logger`.
- A2 may reuse A1 as supporting evidence that the ASL MIG/decode path can
  consume a message once a send right reaches an ASL server.
- A2 does not re-claim A1 decode/audit authority unless the A2 implementation
  explicitly reuses the A1 validator and records A1 as supporting evidence.
- A2 does not claim launchd lifecycle parity, ASL storage/query, syslog socket
  compatibility, aslmanager, XPC, libnotify, or certification.

## 2. Phase 0.85 Boundary

Phase 0.85 owns general launchd resource-handoff semantics. A2 is ASL's first
conditional consumer and evidence trigger for that surface.

Because no standalone Phase 0.85 authority exists yet, A2 carries a
transitional mini-discipline:

- A2 defines only the ASL-specific use of the handoff:
  `com.apple.system.logger` check-in, donor ASL lookup, and nonce delivery.
- A2 must not become the permanent generic launchd handoff authority.
- When Phase 0.85 authority exists, generic check-in, lookup, port identity, and
  service-name ownership must fold out of A2 into that authority.
- A2 marker/contract literals must not be copied into a later Phase 0.85 module.
  The future implementation must use shared constants, shared helpers, or a
  no-copy/static contract check.

Future ownership:

| Contract surface | Transitional A2 ownership | Future authority |
| --- | --- | --- |
| MachServices registration/check-in markers | A2 may define ASL-scoped markers for `com.apple.system.logger` only. | Phase 0.85 generic launchd resource-handoff authority. |
| ASL client lookup markers | A2 owns donor ASL client lookup facts and service-specific lookup outcomes. | ASL A2 remains consumer-specific; generic lookup semantics fold into Phase 0.85. |
| Port-identity assertion | A2 owns the nonce proof tying donor lookup to checked-in ASL server receipt. | Phase 0.85 should own generic identity/equivalence rules; A2 keeps ASL-specific nonce payload requirements. |
| `com.apple.system.logger` constant | A2 pins it as the ASL service under test. | Shared service registry or Phase 0.85 constant source; no copied literals across authorities. |

Pre-commitment for implementation:

- No copied marker or contract literals across Phase 0.85 and ASL A2 authority
  modules.
- If Phase 0.85 is added before A2 implementation, A2 must consume its shared
  handoff contract instead of creating a parallel one.
- If A2 is implemented first, its launchd handoff markers must be explicitly
  classified as `transitional_phase085_contract`.

## 3. Donor-Surface Inventory

All donor paths below are from `/Users/me/wip-mach/nx/NextBSD` at
`8be0f2507b69906d068bed31ffc58cdfafadaef3`.

| Surface | Donor path | A2 decision |
| --- | --- | --- |
| ASL service constant | `lib/libasl/asl_core.h`, `ASL_SERVICE_NAME "com.apple.system.logger"` | Use the exact donor service name. Treat it as ASL A2 service identity until a shared service registry exists. |
| Donor client lookup | `lib/libasl/asl_core.c`, `asl_core_get_service_port()`, `bootstrap_look_up2(bootstrap_port, ASL_SERVICE_NAME, &tmp, 0, BOOTSTRAP_PRIVILEGED_SERVER)` | Prefer compiling/linking the donor lookup function or a mechanical extraction from the pinned donor commit. A project-owned lookup wrapper may orchestrate the call, but cannot substitute for donor lookup proof. |
| Server check-in | `usr.sbin/asl/syslogd.c`, `launch_config()`, `launch_msg(LAUNCH_KEY_CHECKIN)`, `LAUNCH_JOBKEY_MACHSERVICES`, `launch_data_get_machport(...)` | Use donor semantics as the check-in reference. Prefer a project-owned minimal server probe that performs actual launchd check-in and records actual launchd response data; do not pull full `syslogd.c` unless narrower check-in is blocked. |
| Donor plist | `usr.sbin/asl/com.apple.syslogd.plist`; oracle fixture `fixtures/launchd/com.apple.syslogd.plist` | Reference/provenance only for A2 unless full donor fixture is justified. The first A2 fixture should be reduced to MachServices-only. |
| ASL receive path if B sends a message | A1 donor ASL MIG/decode path from `lib/libasl/asl_ipc.defs` and donor `__asl_server_message` extraction | Reuse A1 as supporting evidence or reuse the A1 decode path if the implementation sends `_asl_server_message`. Do not broaden into storage/query/session/notify behavior. |

Full `syslogd.c` daemon behavior is excluded from A2 unless separately
justified. A2 must not pull or claim:

- BSD socket input or UDP syslog;
- ASL storage/query/prune/retrieval;
- notify configuration or libnotify behavior;
- dispatch daemon main/timer/source behavior beyond what is needed to run the
  probe;
- aslmanager;
- XPC;
- full product daemon behavior.

Implementation choice:

- Client side: use donor `asl_core_get_service_port()` directly if linkable; if
  not, use a reproducible mechanical extraction from donor commit
  `8be0f2507b69906d068bed31ffc58cdfafadaef3`.
- Server side: use a project-owned minimal check-in probe using launchd APIs and
  donor `syslogd.c` semantics as reference. This is acceptable because A2
  proves launchd handoff to ASL's service name, not full syslogd product
  startup.
- Any mechanical extraction must record donor source paths, source hashes,
  extraction recipe, compiler flags, object hashes, linked binary hashes, and
  symbol-origin evidence.
- A project-owned minimal probe may not fake launchd responses or satisfy
  `:launchd` markers from constants.

## 4. Port-Identity Proof

Port identity is mandatory. A non-null lookup result is not sufficient.

Required proof shape:

1. The server runs under a launchd fixture advertising the MachServices key
   `com.apple.system.logger`.
2. The server performs actual launchd check-in and obtains the
   `com.apple.system.logger` receive right from the `LAUNCH_JOBKEY_MACHSERVICES`
   dictionary.
3. The server records that it is receiving on the launchd-provided right.
4. The client resolves `com.apple.system.logger` through donor
   `asl_core_get_service_port()` / `bootstrap_look_up2()`.
5. The client sends a nonce-bearing `_asl_server_message` over the resolved send
   right.
6. The checked-in server receives that exact nonce on the launchd-provided
   receive right.
7. Oracle validation requires both the launchd check-in facts and the nonce
   receipt facts. Either side alone fails A2.

The nonce proof must record:

- generated nonce value or nonce SHA256;
- service name used by donor lookup;
- client lookup return code and resolved-port state;
- server check-in return state and service dictionary state;
- message id, expected ASL routine id `118`, and payload SHA256 if the A1
  message path is reused;
- confirmation that the server which received the nonce is the process that
  performed launchd check-in.

Optional kernel-supported identity evidence may strengthen the proof if
available, but it is not required for A2 acceptance. If kernel-attested port
identity is used as a load-bearing fact, the marker producer must be `:kernel`.

Hard exclusions:

- A harness-created send right handed directly to the client cannot satisfy
  A2B.
- A lookup marker without server receipt cannot satisfy port identity.
- A server receipt marker without launchd check-in cannot satisfy port
  identity.

## 5. D22/D23 Dependency Determination

A2 does not create a new launchctl lifecycle gate if implementation stays within
resource handoff/check-in:

- A2 uses launchd MachServices registration/check-in and donor bootstrap lookup.
- A2 does not prove launchctl load, remove, reload, KeepAlive, RunAtLoad, or
  lifecycle behavior.
- A2 does not consume D22/D23 marker order or multi-arm lifecycle contracts.

Therefore D22/D23 authority migration is not a prerequisite for A2
implementation.

Dependency trigger:

- If an A2 implementation plan starts a new launchctl lifecycle gate, drives
  `launchctl remove`/reload semantics, inherits D22/D23 ordered markers, or adds
  a new multi-arm launchctl pattern, stop before implementation and complete the
  required D22/D23 authority migration/preflight first.

## 6. Fixture Shape

A2 should use a reduced MachServices-only launchd fixture.

Required fixture facts:

- Service key: `com.apple.system.logger`
- Minimal label: project-owned test label, for example
  `org.rmxos.asl.a2.system-logger`
- Program: A2 server/check-in probe
- MachServices dictionary containing `com.apple.system.logger`
- `ResetAtClose` only if the A2 implementation explicitly tests or depends on
  it

Recommended reduced shape:

```text
Label = org.rmxos.asl.a2.system-logger
ProgramArguments = [A2 server/check-in probe path]
MachServices = {
  com.apple.system.logger = true or { ResetAtClose = true }
}
```

The oracle fixture `fixtures/launchd/com.apple.syslogd.plist` and donor
`usr.sbin/asl/com.apple.syslogd.plist` remain provenance references. They
include product fields such as sockets, transactions, `ASL_DISABLE`,
`POSIXSpawnType`, `OnDemand`, and syslogd program arguments. Those fields would
unnecessarily widen A2 into product startup or syslog compatibility.

If the full donor plist is later required, the implementation design must state
why Sockets, Jetsam/transactions, daemon program arguments, and other product
fields do not expand the accepted claim.

## 7. Producer Taxonomy

A2 marker producers are defined before markers exist:

| Producer | Allowed facts |
| --- | --- |
| `:launchd` | Actual launchd check-in response, MachServices dictionary lookup, service handoff result, lookup/check-in errors produced by launchd/bootstrap behavior. |
| `:donor` | Donor ASL client lookup path, donor ASL send/decode path if reused from A1, and donor source-derived behavior. |
| `:kernel` | Kernel-attested port or audit facts only if they are load-bearing and independently observed. |
| `:harness` | Orchestration, fixture staging, nonce generation, process startup, log framing, and negative-control mutations. |

Rules:

- `:launchd` markers must derive from actual launchd responses, not harness
  constants.
- ASL decode markers do not prove launchd handoff.
- Launchd handoff markers do not prove donor ASL decode.
- Generated MIG and process-stub markers must not prove launchd handoff.
- Harness markers may frame the run but cannot satisfy Subclaim A or Subclaim B
  by themselves.
- Summary/pass markers must never be primary proof.

## 8. Falsifier Plan

A2 implementation must include negative controls for at least these cases:

| Falsifier | Expected failure |
| --- | --- |
| Missing MachServices key | Server check-in cannot obtain `com.apple.system.logger`; Subclaim A fails. |
| Wrong service name | Donor lookup resolves nothing or the wrong service; Subclaim B fails. |
| Check-in without usable port | Launchd handoff marker cannot be accepted; server cannot receive nonce. |
| Lookup before registration/check-in | Either lookup fails or retry behavior must be explicitly recorded; it cannot satisfy B without matching server check-in. |
| Port substitution / wrong receive right | Nonce is not received by the checked-in server; port identity fails. |
| Harness-injected port | Reject if client used a harness-provided send right instead of donor lookup. |
| Launchd handoff marker without ASL server receipt | Subclaim A-only evidence; not accepted A2. |
| ASL server receipt without launchd handoff marker | Direct handoff or harness path; not accepted A2. |
| Stale/ResetAtClose service port behavior | If `ResetAtClose` is in scope, closing/restarting must not let a stale cached send right satisfy A2. If not in scope, record as deferred with trigger. |
| Cross-subclaim contamination | A2A markers cannot satisfy A2B, and A2B markers cannot satisfy A2A. |

Additional fail-closed requirements:

- Missing terminal marker fails.
- Duplicate terminal marker fails.
- Wrong value such as `=10` instead of `=1` fails.
- Unknown or copied summary-only pass marker fails.
- Truncated serial is indeterminate/fail-closed, never pass.

## 9. Evidence Plan

Raw evidence should be written only under an ignored runtime path:

```text
priv/runs/asl-a2/<timestamp>-system-logger-handoff/
```

Expected evidence files:

- `parity.json`
- `host_preflight.json`
- `env_resolved.json`
- `boot_identity.json`
- `serial.log`
- `server_host.log`, if host output exists
- `client_host.log`, if host output exists
- `donor_hashes.json`
- `donor_lookup_build_provenance.json`
- `fixture_hashes.json`
- `launchd_checkin.json`
- `client_lookup.json`
- `port_identity.json`
- `nonce_receipt.json`
- `hard_stop_scan.json`
- `negative_controls.json`
- `post_run_revalidation.json`

Host-only preflight must verify:

- stable15-active env matrix and explicit source/profile/objdir pins;
- donor commit/path/source hashes for every donor file used;
- generated MIG hashes if `_asl_server_message` is reused;
- extraction/build/link provenance if donor lookup or decode code is
  mechanically extracted;
- fixture shape and fixture hash;
- no ASL A2 marker manifest entries before accepted runtime evidence;
- no copied Phase 0.85/A2 contract literals if a Phase 0.85 authority exists;
- no source-side mutation.

Guest acceptance requires:

- boot identity passes;
- Subclaim A launchd check-in passes;
- Subclaim B donor lookup and nonce receipt passes;
- port-identity proof passes;
- hard-stop scan passes;
- all required falsifiers fail for their intended reasons;
- exactly one terminal marker and exactly one run end marker;
- post-run revalidation over unchanged raw serial/evidence passes;
- `parity.json` records no certification claim and no A1 re-claim unless A1
  evidence is explicitly referenced as supporting evidence.

Hard-stop scan categories:

- panic;
- fatal trap;
- KASSERT;
- real WITNESS diagnostics such as `WITNESS:` and lock-order reversal, while
  allowing the normal WITNESS boot banner;
- `SIGSYS`, `Bad system call`, `UNKNOWN FreeBSD SYSCALL`, and `nosys`;
- launchd resource-handoff failure markers;
- ASL A2 fatal/error markers;
- timeout;
- single-user prompt or video-primary console contamination;
- missing terminal marker.

Post-run discipline:

- Raw evidence is preserved unchanged.
- Any host-only correction must write separate revalidation output and must not
  rewrite raw serials.
- Marker authority extraction happens only after accepted A2 evidence and
  separate review.
- UI snapshots, if later produced, remain non-evidence cache/state.

## 10. Authorization Path

This design doc authorizes no implementation.

Required before A2 implementation:

- parent acceptance of this design;
- separate source-side authorization for A2 implementation;
- separate authorization for the first A2 guest attempt;
- separate authorization for any replacement guest attempt if the first attempt
  fails, hard-stops, truncates, or exposes scope expansion.

An A2 implementation must stop and return for review if it needs:

- full `syslogd.c` daemon behavior;
- libnotify/notifyd;
- ASL storage/query;
- syslog sockets or UDP;
- XPC/aslmanager;
- launchctl lifecycle semantics;
- D22/D23 marker/order authority;
- source-side edits beyond the authorized scope.

## Explicit Non-Scope

- No libnotify or notifyd.
- No ASL storage/query.
- No syslog socket, BSD syslog, or UDP compatibility.
- No XPC.
- No aslmanager.
- No full asld/syslogd daemon product behavior unless separately justified.
- No D22/D23 migration unless the dependency trigger is hit.
- No marker manifest entries before accepted evidence.
- No source-side deletion.
- No certification claim.
- No `certification/` or `artifacts/`.
- No `oracle-parity-a30ef3f` movement.

## Design Guardrails

- No implementation in this document.
- No guest run.
- No marker manifest entries.
- No A2 code.
- No source-side edits.
- No certification or artifacts directories.
- Unrelated UI work remains separate.
