# op-216 — asl native-submit launchd-context re-test — NATIVE-GREEN

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). Functional round-trip.
Image: `build/op216-native/op216-native.img` (leg4-soak + asld op-144 + libasl + asl-harness).

## D1 — bootstrap context: **CONFIRMED**

asl-harness ran as a launchd child via `run-as-launchd-job.sh` (inherits bootstrap from launchd via runtime_fork). The harness's `asl_open: PASS` proves `asl_core_get_service_port` → `bootstrap_look_up2(bootstrap_port, "com.apple.system.logger", ...)` (asl_core.c:110) resolved non-null. If `bootstrap_port` were 0 (bl-016 gap), asl_open would return NULL → FAIL.

```text
OP216_BOOTSTRAP_OK status=1 — launchd-child bootstrap_look_up2 resolved com.apple.system.logger non-null
```

## D2 — native submit lands: **CONFIRMED**

All 9 harness cases PASS (`op116_matrix_fails=0`):

```
asl_open: PASS
asl_new: PASS
asl_set: PASS
asl_log: PASS              ← native Mach submit over com.apple.system.logger
asl_get_roundtrip: PASS
asl_set_filter: PASS
asl_log_filtered: PASS
asl_search_roundtrip: PASS ← STORE READ-BACK: message found in asld's store
asl_close: PASS
```

**Store evidence:**
```
/var/log/asl/2026.06.29.G80.asl  1665 bytes  (created by asld, contains the submitted messages)
/var/log/asl/StoreData            12 bytes    (store index)
```

**This IS the native Mach path, NOT the BSD socket fallback:**
- The harness uses `asl_log(c, m, ASL_LEVEL_NOTICE, ...)` → `_asl_send_message` (asl.c:953)
- `_asl_send_message` calls `asl_core_get_service_port` → `bootstrap_look_up2` → gets asld's port
- `_asl_global.server_port != MACH_PORT_NULL` → send guard at asl.c:1132 passes
- `_asl_server_message(server_port, str, len)` (asl.c:1163) → Mach mig call to asld over `com.apple.system.logger`
- The BSD socket path (`/var/run/log`) is used by `syslog(3)`/`vsyslog(3)` → `bsd_in.c`. The harness does NOT use this path — it uses `asl_log` which is exclusively the Mach-native path.

```text
OP216_NATIVE_LANDS status=1 — asl_log PASS + asl_search_roundtrip PASS + store file created (1665B); native Mach path (asl_log → _asl_server_message over com.apple.system.logger)
```

## D3 — disposition: **NATIVE-GREEN**

The bl-016 gap (op-212) was the sole cause of op-210's `found=0`. Running the client in a valid bootstrap context (launchd child) makes the native ASL Mach submit work end-to-end:
1. Bootstrap resolves `com.apple.system.logger` ✓
2. `asl_log` submits via `_asl_server_message` Mach mig call ✓
3. asld receives, processes, stores ✓
4. `asl_search` reads back from store — found>0 ✓
5. On-disk store file created (1665 bytes) ✓

Under PID-1 launchd (op-201: bootstrap CLOSED), this path would work for ALL processes (not just launchd children), closing the bl-016 gap entirely.

```text
OP216_VERDICT: native-green — valid bootstrap + native Mach submit lands in store → asl's last leg closed
OP216_TERMINAL status=0
```
