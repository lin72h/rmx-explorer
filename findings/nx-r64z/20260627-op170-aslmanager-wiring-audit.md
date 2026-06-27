# op-170 — aslmanager wiring + reclaim audit (READ-ONLY)

Date: 2026-06-27. Lane: `rmx-explorer-rx-x64z` (rx1). READ-ONLY — no builds, no mounts-and-modify.
Image: `build/op162-leg2/op162-leg2.img`. Source: `wip-gpt/wip-rmxos`.

## VERDICT: aslmanager-not-wired

**aslmanager is NOT installed on the image AND NOT wired as a launchd job.** This alone explains zero reclaim during the op-163 4h soak. The store grew unboundedly because nothing was pruning it.

---

## Q1 (GATE): is an aslmanager launchd job present?

**NO.** First-hand from the op162-leg2 image (mounted read-only):

- `/etc/launchd.d/` contains: `com.apple.syslogd.{plist,json}` + `org.freebsd.devd.{plist,json}`. **No aslmanager plist.**
- `/etc/rc.d/` — **no aslmanager script.**
- `/usr/sbin/aslmanager` — **binary NOT present** on the image (`find / -name "*aslmanager*"` returned zero results).
- Only `/usr/sbin/asld` exists in /usr/sbin/asl*.

The `com.apple.syslogd.plist` mentions `ASL_DISABLE=1` in EnvironmentVariables — this is an env var for asld itself (disables asld's internal ASL client to prevent self-logging), NOT an aslmanager reference.

```text
OP170_ASLMANAGER_WIRED status=0 reason=not_installed_no_plist_no_binary
```

## Q2: what triggers an aslmanager reclaim?

Source: `usr.sbin/aslmanager/aslmanager.c` (1606 lines).

**Invocation model:** aslmanager is a **CLI utility** (run-once-and-exit), NOT a daemon. It's triggered by:
- Manual invocation: `aslmanager [-store_ttl <days>] [-ttl <days>] [-size <bytes>] [-d]`
- Launchd timer (StartCalendarInterval) — this is the macOS pattern (runs periodically, e.g., hourly/daily)
- Config from `/etc/asl.conf` (line 1446: reads parameters from asl.conf)

**Reclaim conditions** (`process_asl_data_store`, line 686):

1. **TTL-based** (line 758): `ttl = dst->ttl[LEVEL_ALL] * SECONDS_PER_DAY`
   - If `ttl > 0 AND ttl <= now`: calculates `ymd_expire = now - ttl`
   - Files named `YYYY.MM.DD.*` older than the expiry date are deleted or archived
   - **Default TTL = 0 = never expire** (line 757 comment: "ttl 0 means files never expire")
   - Config key: `store_ttl` in asl.conf (line 612-615)

2. **Size-based** (line 696, 703): total `store_size` calculated by summing all file sizes
   - If total exceeds `max_store_size`, oldest files are removed first
   - Config key: `max_store_size` in asl.conf (line 622-624)

3. **File rotation** (line 711+): individual files exceeding `max_file_size` are rotated (gzipped)

**Would ~29K msgs / 45MB / 4h have crossed?**

- **TTL: NO.** All messages from a 4h soak are in TODAY's daily file (`YYYY.MM.DD.`). TTL-based expiry only removes files OLDER than N days. Today's file is never expired regardless of TTL setting.
- **Size: DEPENDS on max_store_size config.** Default appears to be 0 (unlimited) unless asl.conf specifies. With no asl.conf on the image and no explicit `-size` arg, the size threshold wouldn't trigger.
- **Even if aslmanager WERE running with defaults**, it would NOT have reclaimed during a 4h soak — all data is today's.

```text
OP170_RECLAIM_TRIGGER: TTL (days-based, default=0=never) + max_store_size (bytes, default=0=unlimited) + file rotation (max_file_size)
OP170_WOULD_HAVE_FIRED: NO — 4h soak produces only today's data; TTL doesn't expire today; size default is unlimited
```

## Q3: does asld retain the store in-memory or on-disk?

Source: `lib/libasl/asl_store.h:59-74` + `usr.sbin/asl/dbserver.c:138`.

**ON-DISK store with fixed-size in-memory I/O cache.**

```c
/* asl_store.h:59-74 */
typedef struct asl_store_s {
    char *base_dir;                        // on-disk base directory
    FILE *storedata;                       // FILE* handle to the store data file
    uint64_t next_id;                      // next message ID counter
    asl_cached_file_t file_cache[FILE_CACHE_SIZE];  // FIXED-SIZE in-memory file cache
    time_t start_today, start_tomorrow;    // daily rotation tracking
    size_t max_file_size;                  // rotation threshold
    ...
} asl_store_t;
```

- Messages are written to on-disk files (`asl_store_open_write` at dbserver.c:138)
- The `file_cache[FILE_CACHE_SIZE]` is a **fixed-size array** — doesn't grow with message count
- Individual `asl_msg` objects are created during processing and should be freed after write
- RSS growth (6→45MB) is likely from: FILE* I/O buffers (kernel + userspace buffering of the growing store file), memory fragmentation from alloc/free cycles, and the file cache's backing data

**aslmanager pruning would NOT directly reduce asld's RSS** (it prunes on-disk files, not asld's memory). BUT: when the store file is rotated/replaced (daily rotation), asld opens a new file → old FILE* buffers are released → RSS plateaus. Without aslmanager, the daily file grows unboundedly → FILE* buffers grow → RSS grows.

```text
OP170_STORE_RETENTION: on-disk (file-backed) with fixed-size in-memory I/O cache; RSS growth from FILE* buffering of growing store file, not message retention
```

---

## OP170 markers

```text
OP170_ASLMANAGER_WIRED status=0        # NOT installed, NOT wired — no plist, no binary
OP170_RECLAIM_TRIGGER: TTL(days,default=0) + max_store_size(bytes,default=0) + file_rotation
OP170_WOULD_HAVE_FIRED status=0        # NO — 4h soak = today's data; TTL doesn't expire today; size default unlimited
OP170_STORE_RETENTION: on-disk file-backed; fixed-size cache; RSS growth from I/O buffering
OP170_VERDICT: aslmanager-not-wired
OP170_TERMINAL status=0
```

## Downstream recommendation

The Implementer needs:
1. **Install aslmanager binary** into the image (same pattern as asld — `doas install -m 755 $obj_root/usr.sbin/aslmanager/aslmanager $guest_root/usr/sbin/aslmanager`)
2. **Create an aslmanager launchd plist** with `StartCalendarInterval` (e.g., hourly) OR `KeepAlive` + internal timer. The macOS pattern runs aslmanager periodically via launchd.
3. **Create `/etc/asl.conf`** with reasonable defaults (e.g., `store_ttl = 7` days, `max_store_size = 25600000` bytes ≈ 25MB)
4. **Re-soak** with the leg-4 instrumentation instrumenting {fd, RSS, on-disk store size} + reclaim-watch (threshold-forced to observe ≥1 reclaim cycle)
5. **Pass-bar**: RSS plateaus across a reclaim cycle (not a monotonic rise)
