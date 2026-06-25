# op-143 — asld SIGSEGV root cause CONFIRMED (static-libsys linking + dynamic-binary auxv-init bail)

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z` (recon, read-only — static analysis
+ existing op-138 core; no new guest run).

## VERDICT: asld SIGSEGV root cause CONFIRMED via static analysis + core mining.
**No new guest run needed. id-024-bisect (PIE hypothesis) is dead — all three
binaries are ET_EXEC. The real cause is a static-vs-dynamic linking mismatch in
asld's build.**

## The root cause (one sentence)

asld links `libsys.a` STATICALLY (dragging `dl_init_phdr_info` + `__elf_aux_vector`
into asld's own BSS), but is itself a DYNAMIC binary (`/libexec/ld-elf.so.1`
interpreter + `libc.so.7` NEEDED + `_DYNAMIC` section) — so its own
`__init_elf_aux_vector()` bails out (`if (&_DYNAMIC != NULL) return;`), rtld
populates the dynamic-symbol-table `__elf_aux_vector` (in libsys.so.7) but NOT
asld's local BSS copy, and when an INIT_ARRAY constructor triggers
`dladdr`/`dl_iterate_phdr`, `dl_init_phdr_info` reads asld's local NULL
`__elf_aux_vector` and dereferences it → SIGSEGV at `movq (%rax),%rcx`.

## STEP 1 — ELF type triage (free, no guest run)

| binary | type | `__elf_aux_vector` | dynamic deps | INIT_ARRAY size | C++ syms |
|---|---|---|---|---|---|
| **asld**   | ET_EXEC | **`B 0x41c170`** (defined in BSS — local)  | libc.so.7 (only)               | 48 B (6 ctors) | 7 |
| notifyd    | ET_EXEC | (absent — uses libsys.so.7's)               | libsys.so.7 + libc.so.7 + 14   | (none)         | 0 |
| op-139 probe | ET_EXEC | `U` (undefined — imports from libc.so.7)  | libc.so.7 (only)               | (none)         | 0 |

**PIE hypothesis dead at line 1: all three binaries are ET_EXEC (non-PIE).**

**The smoking gun is column 3**: asld DEFINES `__elf_aux_vector` as a local BSS
symbol; notifyd doesn't have the symbol at all (uses libsys.so.7's); the probe
IMPORTS it (U) from libc.so.7/libsys.so.7 via GOT. asld's local BSS copy is
invisible to rtld — rtld only populates dynamic symbols.

asld's INIT_ARRAY (6 constructors, run before main):

| # | addr | symbol |
|---|---|---|
| 1 | 0x363ae0 | `__guard_setup` (SSP canary) |
| 2 | 0x2ce930 | `_libdispatch_init` (GCD init) |
| 3 | 0x300060 | `mach_init` (Mach compat layer) |
| 4 | 0x3036e0 | `_thread_init_hack` (pthread init) |
| 5 | 0x319730 | `uexterr_ctr` (extended error counter) |
| 6 | 0x3a67f0 | `jemalloc_constructor` (allocator init) |

One of these (likely `_libdispatch_init` or `mach_init`) calls `dladdr` or
`dl_iterate_phdr`, which triggers `dl_init_phdr_info` via
`pthread_once(dl_phdr_info_once, dl_init_phdr_info)`.

## STEP 2 — mine existing op-138 core (free, no guest run)

Core: `runs/20260624T132820Z-op138-core/asld.core.970` (commit 2bead3f era,
13.5 MB ELF FreeBSD core, from `/usr/sbin/asld -d`, pid=970).

### Crash-time registers (lldb)

```
rax = 0x0000000000000000    ← NULL — value loaded from __elf_aux_vector
rbx = 0x000000000041c2d0    ← dl_phdr_info_once (pthread_once arg)
rcx = 0x00000000003149ca    (scratch)
rdx = 0x0000000000000000
rdi = 0x000000000041c2d0    ← pthread_once arg
rsi = 0x00000000003165f0    ← &dl_init_phdr_info (pthread_once init function)
rbp = 0x000000082108c950
rsp = 0x000000082108c950
rip = 0x00000000003165fb    ← crash RIP = dl_init_phdr_info + 0xb
rflags = 0x0000000000010297
```

The `rsi = &dl_init_phdr_info` + `rdi = dl_phdr_info_once` is the exact
signature of `pthread_once(once, dl_init_phdr_info)` — proves the call path:
caller → `_dl_iterate_phdr_locked` (or similar) → `pthread_once(dl_phdr_info_once, dl_init_phdr_info)` → crash on first instruction that dereferences `__elf_aux_vector`.

### Disassembly of `dl_init_phdr_info` (asld's own statically-linked copy)

```
00000000003165f0 <dl_init_phdr_info>:
  3165f0: 55                            pushq   %rbp
  3165f1: 48 89 e5                      movq    %rsp, %rbp
  3165f4: 48 8b 05 75 5b 10 00          movq    0x105b75(%rip), %rax    # 0x41c170 <__elf_aux_vector>
  3165fb: 48 8b 08                      movq    (%rax), %rcx    ← CRASH HERE (rax=0)
  3165fe: 48 85 c9                      testq   %rcx, %rcx
  316601: 74 5c                         je      0x31665f <dl_init_phdr_info+0x6f>
  ...
```

Crash instruction at `0x3165fb`: `movq (%rax), %rcx` = libc source
`auxp->a_type` (first member of `Elf_Auxinfo`). With `rax=0` (because the
__elf_aux_vector BSS slot at 0x41c170 is zero), this dereferences NULL →
SIGSEGV. RIP=0x3165fb matches the op-138 backtrace exactly.

### Disassembly of `__init_elf_aux_vector` (asld's own statically-linked copy)

```
0000000000313510 <__init_elf_aux_vector>:
  313510: 55                            pushq   %rbp
  313511: 48 89 e5                      movq    %rsp, %rbp
  313514: b8 b8 2c 40 00                movl    $0x402cb8, %eax    # imm = &_DYNAMIC
  313519: 48 85 c0                      testq   %rax, %rax          # _DYNAMIC addr non-NULL?
  31351c: 74 02                         je      0x313520             # if NULL, do init
  31351e: 5d                            popq    %rbp
  31351f: c3                            retq                          # else BAIL OUT
  313520: bf 60 c1 41 00                movl    $0x41c160, %edi    # &aux_vector_once
  313525: be 30 35 31 00                movl    $0x313530, %esi    # &init_aux_vector_once
  31352a: 5d                            popq    %rbp
  31352b: e9 f0 23 00 00                jmp     0x315920 <_once>   # pthread_once(once, init)
```

The immediate `$0x402cb8` is the address of asld's `_DYNAMIC` section
(confirmed via `nm asld` → `0000000000402cb8 d _DYNAMIC` and `readelf -S` →
`.dynamic` at 0x402cb8). Since `_DYNAMIC` is non-NULL in any dynamic binary,
`__init_elf_aux_vector` ALWAYS bails out without populating
`__elf_aux_vector`.

This is the libc source from `lib/libsys/auxv.c:60-67`:
```c
#ifndef PIC
void
__init_elf_aux_vector(void)
{
    if (&_DYNAMIC != NULL)
        return;                        // ← asld hits this
    _once(&aux_vector_once, init_aux_vector_once);
}
#endif
```

The baked-in assumption is: "if you're a dynamic binary, rtld populates
`__elf_aux_vector`". That assumption holds for binaries that IMPORT
`__elf_aux_vector` from a shared lib (notifyd, op-139 probe). It FAILS for
binaries that have a LOCAL BSS COPY (asld) — rtld never touches local BSS
symbols.

## Why notifyd + the op-139 probe don't crash

- **notifyd**: dynamic deps include `libsys.so.7`. notifyd has NO local copy
  of `__elf_aux_vector`. rtld populates libsys.so.7's exported copy at process
  start; notifyd's `_elf_aux_info` / libc's `dl_init_phdr_info` (in libsys.so.7)
  uses that populated copy.

- **op-139 probe**: my probe declared `extern void *__elf_aux_vector;` and
  linked with `-fPIC -Wl,--unresolved-symbols=ignore-all` so the symbol
  resolves to libsys.so.7's dynamic copy via GOT. rtld populates that copy.
  op-139's verdict (AT_PHDR present in both shell and launchd contexts) was
  reading the LIBSYS.SO.7 copy, not asld's local BSS.

That's why op-139 REFUTED id-024 ("AT_PHDR missing from auxv") without
finding the real bug: the auxv IS fine for shared-libc/libsys binaries. asld
is the outlier because of its static-libsys linking.

## The fix (out of scope for this op — discovery only — but here for the Implementer)

asld's Makefile must NOT statically link libsys.a. Either:

  1. **Dynamic link libsys.so.7** (notifyd's approach): add `-lsys` to asld's
     LDADD or DPADD chain. Removes the local BSS copies of `__elf_aux_vector`,
     `dl_init_phdr_info`, `phdr_info`, etc. — rtld populates the shared copies.
  2. **Drop the static-libsys objects entirely** if asld doesn't actually need
     them — asld already links libc.so.7 dynamically; libc.so.7's transitive
     NEEDS on libsys.so.7 should be sufficient.

Either approach removes the local BSS shadow and the crash disappears.

## What this op did NOT do

- Did not identify WHICH INIT_ARRAY constructor triggers `dladdr`/`dl_iterate_phdr`.
  That's a follow-up if needed, but not load-bearing for the fix — any of them
  that reaches `dl_init_phdr_info` crashes the same way. Likely candidates by
  symbol name: `_libdispatch_init` (libdispatch GCD init often introspects via
  `dladdr`) and `mach_init` (Mach layer may walk phdrs). Confirmation requires
  a gdb/llvm-dwarfdump dive into asld's symbol map; the fix doesn't depend on it.

## Artifacts

```
findings note:        findings/nx-r64z/20260625-op143-asld-crash-locate.md (this file)
disassembly + syms:   findings/nx-r64z/dtrace/asld-crash-locate/asld-static-symbols.txt
existing core:        /Users/me/wip-mach/build/block-078-runtime-smoke/runs/20260624T132820Z-op138-core/asld.core.970 (13.5 MB, ELF 64-bit FreeBSD core)
asld binary (built):  /Users/me/wip-mach/build/block-075-alpha-final-obj/Users/me/wip-mach/wip-gpt/wip-rmxos/amd64.amd64/usr.sbin/asl/asld (2.4 MB)
```

## Structured markers (for the Coordinator)

```text
OP143_PIE_HYPOTHESIS status=DEAD (all three binaries ET_EXEC)
OP143_STATIC_LIBSYS_LINKING status=CONFIRMED_ROOT_CAUSE
OP143_AUXV_GLOBAL_IN_ASLD status=LOCAL_BSS_NULL (0x41c170, never populated)
OP143_INIT_elf_aux_vector status=BAILS_OUT_for_dynamic_binary (imm 0x402cb8 = &_DYNAMIC, non-NULL)
OP143_CRASH_RAX status=NULL (value loaded from local BSS __elf_aux_vector)
OP143_CRASH_RIP status=0x3165fb (dl_init_phdr_info + 0xb, "movq (%rax),%rcx")
OP143_FIX_RECOMMENDATION dynamic_link_libsys_so_7_NOT_libsys_a
OP143_VERDICT root_cause_located=1 step3_PIE_guest_run_NOT_needed
OP143_TERMINAL status=0
```
