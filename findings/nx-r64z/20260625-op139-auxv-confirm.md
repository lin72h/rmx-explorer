# op-139 — auxv-confirm: id-024 REFUTED at the canonical layer
# (`__elf_aux_vector` global + AT_PHDR both valid in shell AND launchd contexts)

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z` (recon, read-only — single-boot,
two-perspective auxv capture).

## VERDICT: id-024 REFUTED. The libc global `__elf_aux_vector` is non-NULL and
points to a complete auxv (AT_PHDR/PHNUM/ENTRY/BASE all present + non-zero) in
BOTH the FreeBSD-init-spawned shell context AND the launchd-spawned child
context. The op-138 asld SIGSEGV in `dl_init_phdr_info` is NOT caused by:
  - a missing/NULL AT_PHDR entry in the auxv, nor
  - a NULL `__elf_aux_vector` global in the launchd-spawned exec path, nor
  - a mismatch between the global and the stack auxv.

The Arranger's guardrail applies: **op-141 must NOT proceed** on the
id-024 hypothesis. The crash locus is elsewhere.

## The question (from the Arranger dispatch)

> Confirm id-024 cause: is AT_PHDR missing from the auxv ONLY for launchd-spawned procs?
> Method: print AT_PHDR/PHNUM/ENTRY/BASE/EXECFD via getauxval + walk
> `extern Elf_Auxinfo *__elf_aux_vector;` (the same symbol dlfcn.c reads).

op-138 backtrace pointed at `dl_init_phdr_info` (libc dlfcn.c:180). Hypothesis:
`__elf_aux_vector` is NULL or missing AT_PHDR for launchd-spawned processes,
so the libc phdr walk dereferences NULL → SIGSEGV. op-139 tests this directly.

## API notes (first-hand; the dispatch's suggested API differs from rmxOS)

  - **`getauxval()` is NOT in rmxOS libc** (glibc/uclibc API). Closest rmxOS
    equivalent `elf_aux_info(3)` (lib/libsys/auxv.c:280-444) does NOT support
    AT_PHDR/AT_PHNUM/AT_BASE — they fall through `default → ENOENT`. So the
    public API cannot read the load-bearing entries.
  - **`__elf_aux_vector` IS reachable directly** via `extern void *__elf_aux_vector;`
    + link flags `-fPIC -Wl,--unresolved-symbols=ignore-all`. The symbol is
    FBSDprivate_1.0, marked `U` in libc.so.7 (rtld publishes it); the GOT entry
    is filled in at runtime by rtld. dlsym(NULL, ...) returns NULL because
    rtld's private symbols aren't in RTLD_DEFAULT, but the extern declaration +
    link flags work.
  - Probe ALSO computes the auxv pointer via `environ` walk (libc's own
    technique from auxv.c:53-57) as an independent cross-check on the global.

## The probe (findings/nx-r64z/dtrace/auxv-confirm/auxv-probe.c)

Reads `__elf_aux_vector` directly (the SAME symbol libc's `dl_init_phdr_info`
dereferences), AND computes the auxv from environ. Compares the two pointers.
Walks the global vector printing every a_type/a_un. Records presence + value
of AT_PHDR, AT_PHNUM, AT_ENTRY, AT_BASE, AT_EXECFD.

Does NOT call `dladdr` / `dl_iterate_phdr` / anything that would trip
`dl_init_phdr_info` (Arranger guardrail — the probe must report, not crash).

Built with `cc -Wall -Wextra -O2 -fPIC -Wl,--unresolved-symbols=ignore-all`.

Two runs, same image, same boot:

  - **(a) shell context** — `/root/auxv-probe` direct from `/etc/rc.local`.
    FreeBSD-init child (init → rc → rc.local). Baseline.
  - **(b) launchd context** — launchd `-u` started, then `run-as-launchd-job.sh`
    loads+starts a transient launchd job that exec's `/root/auxv-probe`. SAME
    exec path asld took in op-138 (launchctl-loaded plist → launchd fork+exec).

## Result (single boot, two perspectives — canonical global + environ cross-check)

### RUN A — shell context

```
OP139_A OP139_AUXV_GLOBAL global_addr=0x8225ca910 deref_value=0x8202321a0
OP139_A OP139_AUXV_ENVWALK addr=0x8202321a0 environ=0x820232138 envc=12
OP139_A OP139_AUXV_VECTOR status=OK using=global global==envwalk=1
OP139_A OP139_AT_PHDR_present=1   value=0x200040
OP139_A OP139_AT_PHNUM_present=1  value=11
OP139_A OP139_AT_ENTRY_present=1  value=0x201ca0
OP139_A OP139_AT_BASE_present=1   value=0x1958f5c52000
OP139_A OP139_AT_EXECFD_present=0 value=0
OP139_A OP139_VERDICT at_phdr_missing=0
```

### RUN B — launchd context

```
OP139_B OP139_AUXV_GLOBAL global_addr=0x8231aa910 deref_value=0x8207b6b30
OP139_B OP139_AUXV_ENVWALK addr=0x8207b6b30 environ=0x8207b6ac0 envc=13
OP139_B OP139_AUXV_VECTOR status=OK using=global global==envwalk=1
OP139_B OP139_AT_PHDR_present=1   value=0x200040
OP139_B OP139_AT_PHNUM_present=1  value=11
OP139_B OP139_AT_ENTRY_present=1  value=0x201ca0
OP139_B OP139_AT_BASE_present=1   value=0x2cb2d752f000
OP139_B OP139_AT_EXECFD_present=0 value=0
OP139_B OP139_VERDICT at_phdr_missing=0
```

### Diff

| marker                          | shell (A)         | launchd (B)      | divergence? |
|--------------------------------|-------------------|------------------|-------------|
| `__elf_aux_vector` global addr | 0x8225ca910       | 0x8231aa910      | process-local (libc BSS), expected |
| global deref (auxv base)       | 0x8202321a0       | 0x8207b6b30      | process-local (stack), expected |
| environ-walk addr              | 0x8202321a0       | 0x8207b6b30      | **matches global deref** |
| `global==envwalk`              | **1**             | **1**            | **NONE** |
| auxv entries walked            | 26                | 26               | none |
| **AT_PHDR present**            | **1**             | **1**            | **NONE** |
| **AT_PHDR value**              | **0x200040**      | **0x200040**     | **byte-identical** |
| **AT_PHNUM present**           | **1**             | **1**            | **NONE** |
| **AT_PHNUM value**             | **11**            | **11**           | **byte-identical** |
| AT_ENTRY present               | 1                 | 1                | none |
| AT_ENTRY value                 | 0x201ca0          | 0x201ca0         | byte-identical (same binary) |
| AT_BASE present                | 1                 | 1                | none |
| AT_BASE value                  | 0x1958f5c52000    | 0x2cb2d752f000   | rtld base — ASLR, expected |
| AT_EXECFD present              | 0                 | 0                | none (modern ELF doesn't use AT_EXECFD) |

**`__elf_aux_vector` is non-NULL in both contexts and dereferences to a
complete auxv.** The global and the environ-walk agree in both runs. AT_PHDR,
AT_PHNUM, AT_ENTRY, AT_BASE are all present + non-NULL in both. AT_PHDR value
is byte-identical (0x200040) because it's the program-header offset within the
binary's load image — same binary, same value.

## What this means for op-138

The op-138 backtrace (RIP=0x3165fb → `dl_init_phdr_info` at libc dlfcn.c:180)
is real, BUT the cause is NOT what id-024 hypothesized. Remaining candidates,
all specific to asld's binary (not to the launchd exec path):

  1. **dl_init_phdr_info static `phdr_info` struct corrupted by asld's
     earlier static init** — asld is the Apple ASL syslogd, a complex C++
     binary; some constructor may stomp the libc static before the phdr walk
     runs. Notifyd, auxv-probe, etc. don't have that constructor.

  2. **dl_init_phdr_info crashes via a code path NOT covered by the auxv
     check** — e.g., the second for-loop at dlfcn.c:189-193 reading
     `phdr_info.dlpi_phdr[i].p_type` AFTER the first loop. If dlpi_phdr is
     non-NULL but `phdr_info` was overwritten between the loops, that crashes.
     addr2line's "line 180" resolution depends on debug info quality.

  3. **TLS segment layout in asld specifically** — the dl_init_phdr_info loop
     checks `phdr_info.dlpi_phdr[i].p_type == PT_TLS`. If asld's TLS segment
     has a pathological layout (huge dlpi_phnum, misaligned phdr), the loop
     could over-run. But dlpi_phnum=11 in the probe; asld's may differ.

## Recommendation: op-140

A separate probe that calls `dladdr((void*)&main, &dli)` AND
`dl_iterate_phdr(NULL, NULL)` from a launchd child — the actual trigger for
`dl_init_phdr_info`. If THOSE crash, the divergence is in how the libc global
is propagated or `phdr_info` static-init order under launchd-spawn exec.
If they don't crash, the asld SIGSEGV is specific to asld's startup (link
map, TLS segment, C++ static init) — broaden the lens.

(Initial attempt to fold this into op-139's probe changed the early
symbol-resolution surface and crashed at the first printf on the host —
referencing `dl_iterate_phdr` / `pthread_once` from a non-pthread-linked
binary. Separate op, clean probe with `-pthread` or equivalent.)

## Artifacts

```
probe:     findings/nx-r64z/dtrace/auxv-confirm/auxv-probe (13032 bytes)
probe sha: 1887b9ca260934196229477545ff2c0b9a71a8e3d7e5c08e14f7490507a4205b
serial:    findings/nx-r64z/dtrace/auxv-confirm/op139-serial.log
staged:    /Users/me/wip-mach/build/op139-auxv-confirm/op139-auxv.img (op-128 base + /root/auxv-probe + /etc/rc.local)
boot:      single bhyve boot, 7s uptime, captured both A + B runs
build:     cc -Wall -Wextra -O2 -fPIC -Wl,--unresolved-symbols=ignore-all
```

## Structured markers (for the Coordinator)

```text
OP139_AT_PHDR_PRESENT shell=1 launchd=1 value=0x200040
OP139_AUXV_GLOBAL_NONNULL shell=1 launchd=1
OP139_AUXV_GLOBAL_EQUALS_ENVWALK shell=1 launchd=1
OP139_VERDICT id_024_status=REFUTED_AT_PHDR_present_in_both_contexts_global_non_null
OP141_GUARDRAIL do_not_proceed_on_id_024_hypothesis
OP139_NEXT op-140 exercise dl_init_phdr_info via dladdr/dl_iterate_phdr in launchd child
OP139_TERMINAL status=0
```

