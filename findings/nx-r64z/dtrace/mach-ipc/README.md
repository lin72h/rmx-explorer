# mach-ipc fbt probe library (op-099)

Reusable DTrace fbt scripts over the rmxOS mach-IPC spine. No static probes
exist in `sys/compat/mach`, but the spine is fbt-traceable today (verified
`nm mach.ko` — all anchors are `t` = text = fbt-reachable). Use for future IPC
work + Gatekeeper parity gates so we observe the real path, not exit codes.

## Scripts (one per concern + one full-round-trip)

| script | observes | anchors (fbt functions) |
|---|---|---|
| `msg-send.d` | send half: API → kmsg alloc/copyin → right copyin → enqueue | `mach_msg_send`, `ipc_kmsg_alloc`, `ipc_kmsg_copyin`, `ipc_right_copyin`, `ipc_mqueue_send` |
| `msg-receive.d` | receive half: dequeue → kmsg copyout → right copyout → destroy | `mach_msg_receive`, `ipc_mqueue_receive`, `ipc_kmsg_copyout`, `ipc_right_copyout`, `ipc_kmsg_destroy` |
| `kmsg.d` | kernel-message lifecycle | `ipc_kmsg_alloc`, `ipc_kmsg_copyin`, `ipc_kmsg_copyout`, `ipc_kmsg_clean`, `ipc_kmsg_destroy` |
| `port-rights.d` | port alloc/destroy + right transfer/dealloc/delta/lookup | `ipc_port_alloc`, `ipc_port_destroy`, `ipc_right_copyin/copyout/dealloc/delta/lookup/destroy` |
| `port-set.d` | port-set membership + kqueue EVFILT_MACHPORT filter | `ipc_pset_add`, `ipc_pset_remove`, `filt_machportattach/detach`, `filt_machport` |
| `notify.d` | dead-name + no-senders + port-deleted notifications | `ipc_port_dnrequest/dnnotify/dngrow/dncancel`, `ipc_port_nsrequest`, `ipc_port_pdrequest`, `ipc_right_dnrequest` |
| `full-round-trip.d` | all of the above in one correlated script (the reference) | union of the above |

`ipc-roundtrip.c` — minimal pure-mach probe (allocate receive right → send →
receive → destroy, no libdispatch) used to capture the canonical trace.

## Usage

```sh
# in the rmxOS guest (KDTRACE_HOOKS kernel + the dtrace providers loaded
# individually — NOT dtraceall, which needs kinst/systrace_freebsd32):
kldload opensolaris; kldload dtrace; kldload fbt; kldload fasttrap; kldload systrace
# observe a probe's full round-trip:
dtrace -Z -F -s /path/to/full-round-trip.d -c /path/to/probe
```

`-Z` allows zero-match probes (a script anchoring on a function the running
kernel inlined compiles+runs with that probe silently absent). `-F` adds
function-entry flow indent. Type-safe: `probefunc` + `%s/%d` only (no `%llu`
vs `uint64_t` mismatch — D is strict; see op-094).

## Canonical round-trip reference shape (op-099, target=970, `ipc-roundtrip`)

```text
mach_msg_send
  ipc_kmsg_alloc
    ipc_kmsg_copyin (send-side)
      ipc_right_copyin
        ipc_mqueue_send (enqueue)
mach_msg_receive
  ipc_mqueue_receive (dequeue)
    ipc_kmsg_copyout (recv-side)
```

`ipc_kmsg_destroy` / `ipc_kmsg_clean` fire on the post-receive cleanup path
(present in `nm mach.ko`, fbt-reachable; appear later in the full trace).
Background `mach_msg` activity (launchd/notifyd on the staged guest) also
appears in unfiltered fbt — correlate by the target pid / the probe's
`BEGIN target=` marker. Pins: serial sha `b18ef7397fc0baa40370adb78e65cfac38cb5904a64ee22a2d397bc704ba38d6`; trace sha `7911e21c177e54a5536a2e0ecd0514f46dc4ecdac67629a800e7a83d6e91088f`.

## Blind spots

The spine's **entry points are fully fbt-observable** — every anchor above is a
real `t` symbol in `mach.ko` (no static/inlined entry point missing). Blind
spots are limited to **inlined internal helpers** (e.g. copyin/copyout digest
helpers, header-only utilities) — these are not spine entry points, so they do
not block observation of the round-trip. fbt arg visibility is via raw register
args (no CTF-pretty types unless the kernel was built with `DDB_CTF` and the
dtrace CTF path is enabled) — a limitation of fbt vs SDT, not a blind spot.

## SDT backlog (NOT implemented here — needs kernel source edits, RESTRICTED)

Static SDT probes at the spine entry points would give named, typed args
(port/right/kmsg pointers, send/recv flags, return codes) without manual
register-arg decoding — strictly richer than fbt. Catalog as a backlog item:
add `SDT_PROBE1/2(...)` at `mach_msg_send`/`mach_msg_receive`/
`ipc_mqueue_send`/`ipc_mqueue_receive`/`filt_machport` (and the notify fire
points) under `sys/compat/mach/`. Out of scope for op-099 (observation-only);
a separate Implementer op if the arg-level visibility is needed.

## Net

The mach-ipc spine is **fully fbt-observable** today; this library captures the
canonical round-trip and provides composable per-concern views. The only gap vs
ideal is arg-level type richness (fbt raw-args vs SDT typed-args) — a backlog
SDT-probe op, not a blocker for observing the spine.
