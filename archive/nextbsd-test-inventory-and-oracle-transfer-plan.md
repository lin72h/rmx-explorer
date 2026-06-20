# NextBSD Test Inventory and Oracle Transfer Plan

Date: 2026-05-12

## Purpose

This document tells the oracle agent how to ingest the existing NextBSD donor
tests into the macOS oracle test plan.

The rule is:

1. Inventory the existing NextBSD tests.
2. Validate the relevant test behavior first on native macOS where possible.
3. Run the same or equivalent tests on local `rx` / rmxOS after the required
   Mach IPC surfaces exist.

The oracle lane is a semantic validation lane. It must not import XNU
implementation code, require private entitlements by default, or silently change
test meaning to make macOS pass.

## Parent Decisions Already Recorded

- `/Users/me/wip-mach/wip-gpt-oracle` is the cloneable oracle probe repository.
- `/Users/me/wip-mach/wip-gpt` remains the planning/docs repository.
- Existing donor tests stay in their native C/Make shape.
- First oracle implementation is shell/Make plus native C probes.
- Elixir is for orchestration, manifests, result classification, and reports;
  it must not replace the donor C tests.
- Zig is only for new narrow ABI/descriptor probes when donor tests are too
  broad or exact layout/source sharing requires it.
- Curated summary JSON and findings notes may be committed. Raw logs stay
  outside git unless a raw fixture is specifically useful.
- The `nx-v64z.macos-oracle.v1` schema does not define a separate architecture
  class. Intel versus Apple Silicon disagreement uses `version_sensitive` with
  explicit architecture notes.

## Important Scope Split

The NextBSD tree contains two different kinds of tests:

1. Inherited FreeBSD / NetBSD / contrib base-system tests.
2. NextBSD-specific Mach, libmach, bootstrap, dispatch, and XPC tests.

Do not copy the whole inherited FreeBSD test suite into the oracle repo. It is
large, mostly unrelated to Mach semantic validation, and belongs in the native
FreeBSD/rmxOS test lane.

The oracle transfer target is the NextBSD-specific control-plane test set:

- `usr.bin/mach-tests`
- `lib/libmach/test`
- `usr.bin/xpc-tests`

The broad FreeBSD test roots should be recorded as an inventory fact only.

## Located Donor Roots

Primary donor checkout inspected:

```text
/Users/me/wip-mach/nx/NextBSD
```

Equivalent snapshot root also exists:

```text
/Users/me/wip-mach/nx/NextBSD-NextBSD-CURRENT
```

Primary transfer roots:

```text
/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

## Mach Test Inventory

These are the concrete files found under `usr.bin/mach-tests`:

| Test | Files | What it exercises | Oracle treatment |
| --- | --- | --- | --- |
| `ipc-hello` | `usr.bin/mach-tests/ipc-hello/Makefile`, `ipc-hello.c` | Same-process pthread server, `mach_msg` request/reply, inline string payload | First macOS build/run candidate; also first rmxOS native donor sanity test after M2 |
| `set-bport` | `usr.bin/mach-tests/set-bport/Makefile`, `set-bport.c` | `mach_port_allocate`, `mach_port_insert_right`, `task_set_bootstrap_port`, `task_get_bootstrap_port` | macOS probe may be `privilege_sensitive`; rmxOS gate only if bootstrap-port mutation is supported |
| `bootstrap/server` | `usr.bin/mach-tests/bootstrap/server/Makefile`, `bootstrap-server.c` | `bootstrap_check_in`, service receive, reply send | macOS validation may require launchd context; classify carefully |
| `bootstrap/client` | `usr.bin/mach-tests/bootstrap/client/Makefile`, `bootstrap-client.c` | `bootstrap_look_up`, reply port, send/receive | Pair with server; do not run as isolated pass |
| `bootstrap-kqueue/server` | `usr.bin/mach-tests/bootstrap-kqueue/server/Makefile`, `bootstrap-kqueue-server.c` | bootstrap service receive through port set + `EVFILT_MACHPORT` + `kevent64` | macOS semantic probe after port-set/kqueue foundation |
| `bootstrap-kqueue/client` | `usr.bin/mach-tests/bootstrap-kqueue/client/Makefile`, `bootstrap-kqueue-client.c` | repeated service request/reply through bootstrap lookup | Pair with a selected server |
| `bootstrap-kqueue/server-inline-receive` | `usr.bin/mach-tests/bootstrap-kqueue/server-inline-receive/Makefile`, `bootstrap-inline-receive-server.c` | `EVFILT_MACHPORT` with inline receive behavior and supplied receive buffer | Important macOS oracle test if it builds |
| `bootstrap-kqueue/server-portset-fiddling` | `usr.bin/mach-tests/bootstrap-kqueue/server-portset-fiddling/Makefile`, `bootstrap-portset-fiddling-server.c` | port-set membership mutation while receiving service traffic | Later stress test, not first proof |
| `bootstrap-kqueue/server-libdispatch` | `usr.bin/mach-tests/bootstrap-kqueue/server-libdispatch/Makefile`, `bootstrap-libdispatch-server.c` | `DISPATCH_SOURCE_TYPE_MACH_RECV` service receive | Post-Phase 0.5 libdispatch gate, not a first oracle target |
| `kqueue-tests` | `usr.bin/mach-tests/kqueue-tests/Makefile`, `kqueue-tests.c`, `tests.h` | broad kqueue, `EVFILT_MACHPORT`, port sets, `mach_msg`, `mach_vm_allocate`, fork/kevent behavior | Split into subprobes before using as a broad gate |
| `mach-tests-setup` | `usr.bin/mach-tests/mach-tests-setup/Makefile`, `mach-tests-setup.sh.in` | donor-era setup script | Reference only; do not make macOS oracle depend on it |

Build notes found in donor Makefiles:

- `ipc-hello`, `set-bport`, and `kqueue-tests` link with `-lmach -pthread`.
- `kqueue-tests` uses `-D__APPLE__`.
- bootstrap and bootstrap-kqueue tests use `-lSystem` in donor Makefiles.
- `server-libdispatch` uses `-fblocks`.

## libmach Test Inventory

Files found under `lib/libmach/test`:

```text
lib/libmach/test/kqueue_tests/Makefile
lib/libmach/test/kqueue_tests/kqueue_tests.c
```

This is an older kqueue/Mach event coverage suite. It overlaps with
`usr.bin/mach-tests/kqueue-tests`, but it is valuable because it exercises the
`libmach` surface directly.

Oracle treatment:

- macOS: compile/run if headers and APIs are available without private setup.
- rmxOS: run after `libmach` and Mach kqueue support are stable enough.
- If it fails, split failure into narrower probes before making kernel claims.

## XPC Test Inventory

Files found under `usr.bin/xpc-tests`:

| Test | Files | What it exercises | Oracle treatment |
| --- | --- | --- | --- |
| `echo-server` | `usr.bin/xpc-tests/echo-server/Makefile`, `xpc-echo-server.c` | XPC Mach service listener, dispatch main, dictionary reply | Later Phase 0.8+ / XPC-adjacent oracle work |
| `echo-client` | `usr.bin/xpc-tests/echo-client/Makefile`, `xpc-echo-client.c` | XPC Mach service client, async replies | Pair with `echo-server`; not standalone |
| `json-client` | `usr.bin/xpc-tests/json-client/Makefile`, `xpc-json-client.c` | JSON to XPC dictionary/array/value conversion | Can become host-side XPC object conversion test if dependencies exist |
| `credentials/server` | `usr.bin/xpc-tests/credentials/server/Makefile`, `xpc-credentials-server.c` | XPC peer credentials: UID, GID, PID | Later semantic oracle for credential propagation |

Build notes found in donor Makefiles:

- These tests use `-D__APPLE__`, `-fblocks`, `libdispatch`, `liblaunch`,
  `libxpc`, `libosxsupport`, `libbsm`, `libnv`, `libsbuf`, and sometimes
  `jansson`.
- On macOS, equivalent functionality may come from the system SDK/libSystem
  rather than these donor libraries. The oracle agent must record the exact
  build surface instead of pretending the donor FreeBSD link line is portable.

XPC is not the first Phase 0.5 oracle target. Treat it as a later control-plane
test family after Mach IPC, bootstrap, and dispatch receive semantics are
understood.

## Broad Inherited Test Roots

The following test directories exist under `/Users/me/wip-mach/nx/NextBSD`.
Most are inherited FreeBSD/NetBSD/contrib tests and are not part of the initial
oracle transfer:

```text
bin/cat/tests
bin/date/tests
bin/dd/tests
bin/ed/test
bin/expr/tests
bin/ls/tests
bin/mv/tests
bin/pax/tests
bin/pkill/tests
bin/sh/tests
bin/sleep/tests
bin/test
bin/test/tests
bin/tests
cddl/contrib/opensolaris/cmd/dtrace/test
cddl/lib/tests
cddl/sbin/tests
cddl/tests
cddl/usr.bin/tests
cddl/usr.sbin/dtrace/tests
cddl/usr.sbin/tests
cddl/usr.sbin/zfsd/tests
contrib/apr-util/test
contrib/blacklist/test
contrib/byacc/test
contrib/dma/test
contrib/expat/tests
contrib/file/tests
contrib/groff/contrib/gdiffmk/tests
contrib/jansson/test
contrib/libarchive/cat/test
contrib/libarchive/cpio/test
contrib/libarchive/libarchive/test
contrib/libarchive/tar/test
contrib/libpcap/tests
contrib/libucl/tests
contrib/libxo/encoder/test
contrib/libxo/tests
contrib/netbsd-tests/lib/libcurses/tests
contrib/ntp/lib/isc/tests
contrib/ntp/sntp/libevent/test
contrib/ntp/sntp/tests
contrib/ntp/tests
contrib/openbsm/test
contrib/pjdfstest/tests
contrib/wpa/wpa_supplicant/tests
crypto/heimdal/appl/test
gnu/lib/tests
gnu/tests
gnu/usr.bin/diff/tests
gnu/usr.bin/grep/tests
gnu/usr.bin/tests
lib/atf/libatf-c++/tests
lib/atf/libatf-c/tests
lib/atf/tests
lib/libarchive/tests
lib/libc/db/test
lib/libc/tests
lib/libcrypt/tests
lib/libdevdctl/tests
lib/libmach/test
lib/libmp/tests
lib/libnv/tests
lib/libpam/libpam/tests
lib/libproc/tests
lib/librt/tests
lib/libthr/tests
lib/libutil/tests
lib/libxo/tests
lib/libz/test
lib/msun/tests
lib/tests
libexec/atf/atf-check/tests
libexec/atf/atf-sh/tests
libexec/atf/tests
libexec/rtld-elf/tests
libexec/tests
sbin/devd/tests
sbin/dhclient/tests
sbin/growfs/tests
sbin/ifconfig/tests
sbin/mdconfig/tests
sbin/tests
secure/lib/tests
secure/libexec/tests
secure/tests
secure/usr.bin/tests
secure/usr.sbin/tests
share/examples/kld/cdev/test
share/examples/kld/syscall/test
share/examples/tests
share/examples/tests/tests
share/me/test
share/tests
sys/boot/userboot/test
sys/modules/tests
sys/netpfil/ipfw/test
sys/tests
targets/pseudo/tests
tests
tests/sys/pjdfstest/tests
tools/regression/bpf/bpf_filter/tests
tools/test
tools/tools/shlib-compat/test
usr.bin/apply/tests
usr.bin/basename/tests
usr.bin/bmake/tests
usr.bin/bsdcat/tests
usr.bin/calendar/tests
usr.bin/cmp/tests
usr.bin/col/tests
usr.bin/comm/tests
usr.bin/cpio/tests
usr.bin/ctags/test
usr.bin/cut/tests
usr.bin/dirname/tests
usr.bin/file2c/tests
usr.bin/grep/tests
usr.bin/gzip/tests
usr.bin/ident/tests
usr.bin/join/tests
usr.bin/jot/tests
usr.bin/lastcomm/tests
usr.bin/limits/tests
usr.bin/m4/tests
usr.bin/mach-tests
usr.bin/mkimg/tests
usr.bin/ncal/tests
usr.bin/printf/tests
usr.bin/sdiff/tests
usr.bin/sed/tests
usr.bin/soelim/tests
usr.bin/tar/tests
usr.bin/tests
usr.bin/timeout/tests
usr.bin/tr/tests
usr.bin/truncate/tests
usr.bin/units/tests
usr.bin/uudecode/tests
usr.bin/uuencode/tests
usr.bin/xargs/tests
usr.bin/xinstall/tests
usr.bin/xo/tests
usr.bin/xpc-tests
usr.bin/yacc/tests
usr.sbin/chown/tests
usr.sbin/etcupdate/tests
usr.sbin/extattr/tests
usr.sbin/fmtree/test
usr.sbin/fstyp/tests
usr.sbin/makefs/tests
usr.sbin/newsyslog/tests
usr.sbin/nmtree/tests
usr.sbin/pw/tests
usr.sbin/rpcbind/tests
usr.sbin/sa/tests
usr.sbin/tests
```

Top-level count from the inventory:

| Top-level area | Test dirs |
| --- | ---: |
| `usr.bin` | 41 |
| `contrib` | 24 |
| `lib` | 20 |
| `bin` | 14 |
| `usr.sbin` | 12 |
| `cddl` | 8 |
| `share` | 6 |
| `sbin` | 6 |
| `secure` | 5 |
| `libexec` | 5 |
| `gnu` | 5 |
| `sys` | 4 |
| `tools` | 3 |
| `tests` | 2 |
| `targets` | 1 |
| `crypto` | 1 |

## Oracle Transfer Strategy

### Stage 1: Manifest, Do Not Copy Full Trees

Create oracle manifests for:

- Mach tests
- libmach tests
- XPC tests
- broad inherited FreeBSD test roots

The oracle repo should initially store paths, expected source fragments, build
requirements, and phase classification. Do not copy full donor source trees
unless the parent explicitly approves a curated fixture.

### Stage 2: macOS Compile Probes

For each Mach/libmach test, attempt a macOS compile-only pass with the stock SDK.

Default C build style:

```sh
clang -Wall -Wextra -O0 -g -o probe probe.c
codesign -s - probe
```

Record:

- SDK path and version
- compiler version
- link flags used
- whether `-D__APPLE__` was required
- whether `-fblocks` was required
- whether donor include paths were avoided or required
- whether the test uses APIs unavailable on modern macOS

Compile failures are useful oracle facts. Do not paper over them with broad
compatibility shims before reporting them.

### Stage 3: macOS Runtime Probes

Run the macOS-safe tests in this order:

1. `ipc-hello`
2. `set-bport` as read/write bootstrap-port observation, classified as
   `privilege_sensitive` or `not_observable` if stock macOS blocks mutation
3. minimal bootstrap lookup/check-in probes, if stock launchd context permits
4. `kqueue-tests` split into focused subprobes before running the full broad test
5. non-libdispatch `bootstrap-kqueue` variants
6. `server-libdispatch` only after dispatch Mach receive is in scope
7. XPC tests only after launchd/XPC phase planning approves them

Every runtime probe must include:

- watchdog timeout
- cleanup path
- child/server termination path
- structured JSON result
- classification from `nx-v64z.macos-oracle.v1`: `exact_contract`,
  `equivalent_contract`, `version_sensitive`, `privilege_sensitive`,
  `not_observable`, `probe_failure`, or `intentional_divergence`
- architecture-specific host disagreement recorded as `version_sensitive` with
  explicit architecture notes

### Stage 4: rmxOS Native Donor Run

After macOS behavior is captured, run the selected donor tests on local rmxOS in
their native C/Make shape.

Do not rewrite the donor tests into Elixir or Zig. Elixir may orchestrate the
build/run and summarize results. Zig should only fill gaps where narrow ABI or
descriptor probes are needed.

rmxOS order:

1. `ipc-hello`
2. narrow M2 descriptor/rights probes
3. `set-bport`
4. bootstrap client/server
5. port-set and `EVFILT_MACHPORT` probes
6. non-GCD `bootstrap-kqueue`
7. `kqueue-tests`
8. `libmach/test/kqueue_tests`
9. `server-libdispatch`
10. XPC tests after launchd/libdispatch/XPC readiness

## Initial Phase Assignment

| Test family | macOS oracle phase | rmxOS phase |
| --- | --- | --- |
| `ipc-hello` | immediate | Phase 0.5 M2 smoke after descriptor/right preflight |
| `set-bport` | immediate observation, may be privilege-sensitive | Phase 0.5 if bootstrap-port mutation is supported |
| `bootstrap` | after bootstrap context strategy | Phase 0.5 / 0.8 boundary depending on launchd readiness |
| `bootstrap-kqueue` non-GCD | after port-set + EVFILT_MACHPORT probes | Phase 0.5 after M3/M4 |
| `bootstrap-kqueue/server-libdispatch` | after dispatch Mach receive oracle work | post-Phase 0.5 libdispatch gate |
| `kqueue-tests` | split first, full run later | Phase 0.5 broad sweep |
| `libmach/test/kqueue_tests` | split/build first, full run later | Phase 0.5 reference suite |
| `xpc-tests` | later XPC oracle package | Phase 0.8+ / Phase 1.0 adjacent |
| inherited FreeBSD base tests | inventory only | native FreeBSD/rmxOS lane |

## Acceptance Criteria For Oracle Agent

The oracle agent has done the transfer correctly when it can produce:

1. A machine-readable manifest of all Mach/libmach/XPC donor tests.
2. A broad inventory of inherited FreeBSD test roots, excluded from default
   macOS oracle runs.
3. macOS compile results for each Mach/libmach donor C test.
4. macOS runtime results for `ipc-hello` and any other stock-userland-safe tests.
5. Explicit skip classifications for tests blocked by launchd context,
   privileges, missing APIs, or modern macOS version differences.
6. A matching rmxOS run plan that keeps donor tests native C/Make.
7. A comparison report that says which behavior should become an rmxOS gate and
   which behavior is only modern macOS reference data.

## Copy/Paste Prompt For Oracle Agent

You are the `nx-v64z` macOS oracle test-transfer agent.

Your task is to ingest the existing NextBSD donor test inventory into the oracle
test plan. Work from:

```text
/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

Do not copy or run the entire inherited FreeBSD test suite. Record it as broad
inventory only.

Create:

1. a machine-readable manifest for Mach/libmach/XPC donor tests;
2. a macOS compile matrix for each C test;
3. a macOS runtime plan that starts with `ipc-hello`;
4. skip/stop classifications for tests that require launchd context, private
   privilege, unsupported APIs, or broader phase prerequisites;
5. an rmxOS execution plan that runs the selected donor tests in their native
   C/Make form after macOS facts are captured.

Preserve these rules:

- Native macOS is a semantic oracle, not an implementation source.
- Existing donor tests stay native C/Make; do not rewrite them into Elixir or
  Zig.
- Elixir is for orchestration, manifests, result classification, and reports.
- Zig is only for new narrow ABI/descriptor probes when the donor tests are too
  broad.
- Use `mach_msg()` explicitly in new probes, not `mach_msg2()` or
  `mach_msg_overwrite()`.
- Modern macOS behavior may differ from the NextBSD donor era; classify that as
  `version_sensitive`, not automatically as an rmxOS bug.
- Intel versus Apple Silicon disagreement also uses `version_sensitive` with
  explicit architecture notes unless the schema is deliberately revised later.

Report back with:

1. test inventory summary;
2. proposed manifest schema;
3. exact first ten macOS compile/run attempts;
4. tests that should be blocked/deferred and why;
5. changes needed to the existing oracle Elixir migration plan.
