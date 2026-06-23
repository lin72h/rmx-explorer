# op-116 — ASL recon: two-syslogd ownership + transport + harness

## Two-syslogd ownership (SETTLED)

| syslogd | source | launchd plist | transport | macOS-truth? |
|---|---|---|---|---|
| **Apple ASL syslogd** | `usr.sbin/asl/syslogd.c` | `com.apple.syslogd.plist` (Label: com.apple.syslogd) | Mach bootstrap (`com.apple.system.logger`) | **YES** — this is the macOS-27 syslogd |
| stock FreeBSD syslogd | `usr.sbin/syslogd/` | (none in rmxOS) | `/dev/log` socket | NO — legacy FreeBSD logging |

**Ownership**: the Apple ASL syslogd is the rmxOS syslogd. It registers the
`com.apple.system.logger` Mach bootstrap service (libasl looks it up via
`bootstrap_look_up`). The stock FreeBSD syslogd is NOT launched on rmxOS
(no plist) — it's in-tree for reference/compatibility only.

## Transport

libasl reaches syslogd via **Mach bootstrap** (same as notify/libnotify):
- `ASL_SERVICE_NAME "com.apple.system.logger"` (asl.c:130).
- `bootstrap_look_up` for the service port.
- `notify.h` + `<servers/bootstrap.h>` included (asl.c:43,49).

**Implication**: the bl-016 bootstrap-ambient gap applies (a non-launchd
process without a bootstrap port can't reach syslogd via libasl). The
probe-child approach (op-110 — launchd provides the bootstrap) will work.

## API surface (from asl.h)

Core matrix for the harness:
- `asl_open(ident, facility, opts)` → client connection.
- `asl_new(ASL_TYPE_MSG)` → create a message.
- `asl_set(msg, key, value)` → set a kv pair.
- `asl_get(msg, key)` → get a kv value (round-trip).
- `asl_log(client, msg, level, format, ...)` → log a message.
- `asl_set_filter(client, filter)` → level filtering.
- `asl_search(client, query)` → search stored messages.
- `asl_close(client)`.

Extended (pass-2 scope):
- `asl_open_path` + file-store readback.
- `aslmanager` rotation.

## libasl build status

libasl.so.1 IS built in obj_root (`block-075-alpha-final-obj/.../lib/libasl/`).
libasl.so.1 is staged by stage-userland.sh (installed to /usr/lib/).
syslogd is staged by stage-userland.sh (installed to /usr/sbin/).
The com.apple.syslogd plist is NOT currently loaded by the block-078 probe
(only com.apple.notifyd.plist is loaded). The harness run will need to
extend the probe to also load + start syslogd before the ASL client can
reach it.

## Harness

See `asl-harness.c` in this directory. Covers the core matrix above.
Byte-identical shareable across rx-x64z + mx-a64z (the op-110
UNMODIFIED-both-sides property is the bar).

## Next steps

1. Extend the nxplatform-probe to also load com.apple.syslogd.plist + start
   syslogd (after notifyd, before the harness).
2. Run the harness as a launchd child (probe-child bootstrap path).
3. op-117: mx-a64z macOS-truth run + conformance diff.
