# op-101 — libdispatch timer USDT probes enabled by Makefile-only diff

Date: 2026-06-23. Implementer trial against rmxOS `alpha`
`129ee3ce8d526566cd1f66b070a4b87d21a890d0`.

Product source state: **not committed**. The diff below is pending Coordinator
sign-off. This finding records the build and runtime proof only.

## Verdict

The Makefile-only timer-USDT path works:

- `lib/libdispatch` clean rebuild status: `0`
- provider header generation happened through the FreeBSD `.d` make rule:
  `dtrace -C -x nolibs -h -s .../src/provider.d`
- DOF/probe object generation happened through the same rule:
  `dtrace -C -x nolibs -G -o provider.pico -s .../src/provider.d ...`
- `provider.pico` linked into `libdispatch.so.5.full`
- built library contains `.SUNW_dof`
- built library exports the four timer DTrace stubs
- in-guest `dtrace -l` listed `dispatch$target:::timer-*`
- a real `dispatch_after_f` primitive fired `timer-configure`, `timer-program`,
  `timer-wake`, and `timer-fire`

The corrected op-100 root cause is confirmed by the absence of the prior
const-qualifier build break: `DISPATCH_USE_DTRACE_INTROSPECTION=0` keeps the
broken callout/queue introspection path compiled out while leaving the timer
block active.

## Product Diff Pending Sign-Off

```diff
diff --git a/lib/libdispatch/Makefile b/lib/libdispatch/Makefile
index 312404570da7..8cf7029d60b5 100644
--- a/lib/libdispatch/Makefile
+++ b/lib/libdispatch/Makefile
@@ -12,7 +12,8 @@ NO_WERROR= yes
 CFLAGS+=	-I${.CURDIR}/../../include/apple -I${.CURDIR}/os -I${.CURDIR}/private
 CFLAGS+=	-I${.CURDIR} -I${.CURDIR}/../../include -I${.CURDIR}/../../sys
 CFLAGS+=	-I. -I${.CURDIR}/include -fblocks -fcommon
-CFLAGS+=	-D__APPLE__ -DDISPATCH_USE_DTRACE=0
+CFLAGS+=	-D__APPLE__ -DDISPATCH_USE_DTRACE=1
+CFLAGS+=	-DDISPATCH_USE_DTRACE_INTROSPECTION=0
 CFLAGS+=	-DDISPATCH_USE_SIMPLE_ASL=0 -DUSE_OBJC=0 -D__BLOCKS__=1
 CFLAGS+=	-DDISPATCH_DEBUG=1
 CFLAGS+=	-DOS_OBJECT_USE_OBJC=0
@@ -62,7 +63,8 @@ SRCS =  protocolUser.c \
 	transform.c \
 	voucher.c \
 	freebsd_kevent64.c \
-	resolver.c
+	resolver.c \
+	provider.d
 
 INCSDIR= ${INCLUDEDIR}/dispatch
 INCS=	base.h \
```

Adding `provider.d` to `SRCS` intentionally uses FreeBSD's existing DTrace
source handling instead of custom per-file rules. The generated object lists
included both `provider.o` and `provider.pico`; the shared library link line
included `provider.pico`.

## Build Proof

Build command:

```sh
env MAKEOBJDIRPREFIX=/Users/me/wip-mach/build/block-075-alpha-final-obj \
  make -C /Users/me/wip-mach/wip-gpt/wip-rmxos/lib/libdispatch clean all
```

Build log:

```text
/Users/me/wip-mach/build/op101-libdispatch-usdt/libdispatch-clean-rebuild.log
```

Key build lines:

```text
dtrace -C -x nolibs -h -s /Users/me/wip-mach/wip-gpt/wip-rmxos/lib/libdispatch/src/provider.d
dtrace -C -x nolibs -G -o provider.pico -s /Users/me/wip-mach/wip-gpt/wip-rmxos/lib/libdispatch/src/provider.d protocolUser.pico protocolServer.pico allocator.pico apply.pico benchmark.pico data.pico init.pico introspection.pico io.pico object.pico once.pico queue.pico semaphore.pico source.pico time.pico transform.pico voucher.pico freebsd_kevent64.pico resolver.pico
cc ... -o libdispatch.so.5.full ... resolver.pico provider.pico ...
```

Binary checks:

```text
.SUNW_dof present in libdispatch.so.5.full
__dtrace_dispatch___timer__configure present
__dtrace_dispatch___timer__program present
__dtrace_dispatch___timer__wake present
__dtrace_dispatch___timer__fire present
```

Built library SHA256:

```text
ab7a9058546c0dc319d8d27ed52dc0c09e425ba71bbf6b4c4295f9dc91435eda  libdispatch.so.5
```

## Guest Probe Listing

Guest run:

```text
/Users/me/wip-mach/build/op101-libdispatch-usdt/run-1/serial.log
SHA256: d4258b3b6bfb78a341079f16d4d19607965fea909e7dec2e57dfecc7b3e74faa
```

Provider modules loaded individually:

```text
op101_kldload_opensolaris_rc=0
op101_kldload_dtrace_rc=0
op101_kldload_fbt_rc=0
op101_kldload_fasttrap_rc=0
op101_kldload_systrace_rc=0
```

`dtrace -l -c /root/dispatch_primitives -n 'dispatch$target:::timer-*'`:

```text
op101_dtrace_list_rc=0
73136 dispatch970  libdispatch.so.5 _dispatch_source_timer_telemetry_slow timer-configure
73137 dispatch970  libdispatch.so.5     _dispatch_source_set_interval timer-configure
73138 dispatch970  libdispatch.so.5 _dispatch_source_set_runloop_timer_4CF timer-configure
73139 dispatch970  libdispatch.so.5         dispatch_source_set_timer timer-configure
73140 dispatch970  libdispatch.so.5              _dispatch_timers_run timer-fire
73141 dispatch970  libdispatch.so.5          _dispatch_timers_program timer-program
73142 dispatch970  libdispatch.so.5            _dispatch_kevent_drain timer-wake
```

## Firing Trace

The primitive itself passed and drove a NORMAL dispatch-after path:

```text
"status":"pass"
"dispatch_after_fired":true
"semaphore_timeout_observed":true
"semaphore_signal_then_wait_ok":true
```

`dtrace -s /root/op101-usdt-timer.d -c /root/dispatch_primitives` firing trace:

```text
op101_usdt_begin target_pid=973
OP101_USDT_FIRE provider=dispatch973 module=libdispatch.so.5 function=_dispatch_source_timer_telemetry_slow name=timer-configure pid=973
OP101_USDT_FIRE provider=dispatch973 module=libdispatch.so.5 function=_dispatch_timers_program name=timer-program pid=973
OP101_USDT_FIRE provider=dispatch973 module=libdispatch.so.5 function=_dispatch_kevent_drain name=timer-wake pid=973
OP101_USDT_FIRE provider=dispatch973 module=libdispatch.so.5 function=_dispatch_timers_run name=timer-fire pid=973
op101_usdt_end
op101_trace_terminal status=0
```

## Non-Claims

This trial does not enable queue/callout probes. Those remain behind the
introspection path and still need a separate source-level const fix if wanted.
No bl-004 or bl-005 behavior changed. This is observation infrastructure only.
