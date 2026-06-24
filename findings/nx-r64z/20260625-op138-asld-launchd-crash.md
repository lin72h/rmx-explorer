# op-138 re-run3 — asld crashes under launchd too (MachServices/Sockets plist gap)

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z`.

## Finding: asld SIGSEGV even when launched by launchd

```
OP138_SYSLOG_LOAD rc=0
OP138_SYSLOG_START rc=0
pid 969 (asld), jid 0, uid 0: exited on signal 11 (core dumped)
```

asld was installed at BOTH `/usr/sbin/asld` (plist's expected path) AND
`/usr/sbin/syslogd`. rc.d was renamed (.disabled). Launchd loaded + started the
plist (rc=0). The process started... then crashed with SIGSEGV.

## Root cause: plist-level MachServices/Sockets registration unsupported by -u launchd

The product `com.apple.syslogd.plist` uses:
- `<key>MachServices</key>` with `com.apple.system.logger` — plist-level Mach
  service endpoint registration (launchd creates the receive right + registers it
  in the bootstrap namespace on the daemon's behalf).
- `<key>Sockets</key>` — launchd creates the socket FDs and passes them to the
  daemon.

These are PID-1 launchd features. rmxOS launchd runs with `-u` (user-session,
non-PID-1). The notifyd plist does NOT use MachServices — notifyd registers its
service at the PROGRAM level (`bootstrap_check_in` in notifyd's C code).
syslogd's plist relies on launchd-level service setup that the `-u` session
launchd doesn't provide.

asld's startup code expects the Mach service port to already exist (created by
launchd from the MachServices plist key). When it finds NULL, it dereferences
it → SIGSEGV.

## Contrast with notifyd

| | notifyd | asld (syslogd) |
|---|---|---|
| Service registration | program-level (`bootstrap_check_in` in C code) | plist-level (`MachServices` key) |
| Plist MachServices key | absent | present (`com.apple.system.logger`) |
| Plist Sockets key | absent | present |
| Launchd `-u` support | works (program does its own bootstrap_check_in) | **crashes (expects launchd to create the service port)** |

## Impact

This is NOT just bl-016 (bootstrap-ambient gap). It's a **launchd capability
gap**: the `-u` session launchd doesn't implement plist-level MachServices or
Sockets registration. This affects ALL daemons whose plists use these keys
(syslogd, potentially others). Making launchd PID 1 (b-equiv option a from
op-119) would enable these features.

## rc.conf NO failure (secondary)

Despite appending `syslogd_enable="NO"` to rc.conf, rc.d still started syslogd
(line 128). The sh -c quoting likely corrupted the rc.conf line. The rename
(rc.d/syslogd → .disabled) was the correct definitive fix but was partially
bypassed because rc.d found the binary via a different path. This is a staging
issue, not a product gap.

## Markers

```
OP138_RCD_RENAMED=1 (rc.d/syslogd disabled)
OP138_ASLD_AS_SYSLOGD=1 (2.4M asld at both /usr/sbin/asld + /usr/sbin/syslogd)
OP138_SYSLOG_LOAD=0 (launchd loaded plist)
OP138_SYSLOG_START=0 (launchd started job)
OP138_BOOTSTRAP_OK=0 (asld crashed SIGSEGV)
OP138_ASL_ROUNDTRIP=SKIP (daemon down)
OP138_TERMINAL status=1
```

serial sha: 1cad86540a2716a70e8214be5f6dc3452a67115802e7a892fab3a60c62b29d71

## Recommendation for the Coordinator

The asld daemon cannot run under the current rmxOS launchd `-u` model. Three
options:
1. **Make launchd PID 1** (op-119 option a) → MachServices + Sockets work →
   asld starts correctly. This is the macOS model.
2. **Modify asld to use program-level bootstrap_check_in** (like notifyd) —
   removes the plist MachServices dependency. Product source edit (Implementer).
3. **Catalog as a Gate-E item** — syslogd/asld doesn't work in the current
   launchd session model. The preview floor uses notifyd (which works); asl
   conformance is post-preview.
