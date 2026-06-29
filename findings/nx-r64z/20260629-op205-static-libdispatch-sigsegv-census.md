# op-205 — static-libdispatch latent-SIGSEGV census (READ-ONLY)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery.
Source: obj_root `block-075-alpha-final-obj`. Runtime: `op201-hybrid.img` throwaway clone.

## D1: structural suspects

Sweep: ALL ELF executables in obj_root `sbin/ bin/ usr.sbin/ usr.bin/ libexec/` with BOTH:
1. libdispatch symbols (`_dispatch_*` / `dispatch_*`)
2. `__elf_aux_vector` as local BSS symbol (the crash indicator — static-linked libsys.a reads it at ctor)
3. `NEEDED` = `libc.so.7` ONLY (no `libdispatch.so.5` → statically linked)

| # | binary | NEEDED | __elf_aux_vector | dispatch_syms | dl_init_phdr_info | size |
|---|---|---|---|---|---|---|
| 1 | `usr.sbin/aslmanager/aslmanager` | `[libc.so.7]` | B 0x3d0830 | 461 | t 0x306ba0 | 2.1 MB |
| 2 | `usr.bin/aslutil/aslutil` | `[libc.so.7]` | B 0x3f50b0 | 460 | t 0x2f6720 | 2.3 MB |

**Contrast (DO NOT crash — dynamic libdispatch.so.5):**
- `usr.sbin/asl/asld`: NEEDED 16 libs incl. libdispatch.so.5 + libsys.so.7. `__elf_aux_vector` = ABSENT. dispatch_syms=21.
- `usr.sbin/notifyd/notifyd`: NEEDED 15 libs incl. libdispatch.so.5 + libsys.so.7. `__elf_aux_vector` = ABSENT. dispatch_syms=25.

**No other suspects found.** The structural sweep covered the entire Darwin userland build output. Only aslmanager and aslutil have the crash signature.

```text
OP205_SUSPECTS: 2 binaries — aslmanager (known op-204) + aslutil (NEW)
```

## D2: runtime classification

Both suspects staged on a booted rmxOS image (clone of op201-hybrid with launchd PID-1 + rc-chainload). Run with `-h` (no-args help):

| binary | rc | result | classification |
|---|---|---|---|
| `aslmanager-suspect -h` | **139** | `Segmentation fault (core dumped)` | **CRASHES** |
| `aslutil-suspect -h` | **139** | `Segmentation fault (core dumped)` | **CRASHES** |

Both crash identically to op-204's aslmanager: SIGSEGV before main(), in libdispatch's load-time ctor → `dl_init_phdr_info` → NULL `__elf_aux_vector` deref.

```text
OP205_RUNTIME_CLASS: aslmanager=CRASHES(rc=139), aslutil=CRASHES(rc=139)
```

## D3: ledger

| binary | static-libdispatch? | crashes? | on preview image? | preview-relevance | fix recommendation |
|---|---|---|---|---|---|
| **aslmanager** | YES (`__elf_aux_vector`=B, NEEDED libc only) | **YES** (rc=139) | **NO** (op-170: absent from golden image) | LOW (not shipped; but op-170 recommends wire-up → must fix BEFORE shipping) | Dynamic-link libdispatch.so.5 (mirror notifyd/asld pattern) |
| **aslutil** | YES (same signature) | **YES** (rc=139) | **NO** (absent from golden image) | LOW (utility, not boot-path) | Same fix: dynamic-link |

**No HIGH-priority crashers.** Neither suspect is a core-service daemon or boot-path binary. Both are administrative utilities (aslmanager = log rotation; aslutil = ASL query tool). Neither is shipped on the preview image.

**The crash class is contained to the ASL tool family** (aslmanager + aslutil). No other Darwin userland binary has the static-libdispatch + `__elf_aux_vector` signature.

```text
OP205_LEDGER: 2 crashers (aslmanager + aslutil), both ABSENT from preview image, both fixable via dynamic-link (mirror notifyd). No HIGH-priority crasher. No boot-path binary affected.
```

## OP205 markers

```text
OP205_SUSPECTS: 2 (aslmanager + aslutil — both __elf_aux_vector=1, NEEDED libc.so.7-only)
OP205_RUNTIME_CLASS: aslmanager=CRASHES(rc=139), aslutil=CRASHES(rc=139)
OP205_LEDGER: 2 crashers, both absent from preview, both LOW priority (admin utilities); fix=dynamic-link
OP205_VERDICT: census-found (2 crashers — aslmanager known, aslutil NEW; both absent from preview → de-risked)
OP205_TERMINAL status=0
```
