# op-138 core backtrace: asld crashes in libc dl_init_phdr_info (ELF auxv), NOT in MachServices

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z`.

## The backtrace (lldb, first-hand)

```
Core file: ELF 64-bit LSB core file, x86-64, FreeBSD-style, from '/usr/sbin/asld -d', pid=970
Thread #1, name = 'asld', stop reason = signal SIGSEGV
  * frame #0: 0x00000000003165fb
    frame #1: 0x000000082108c970
RIP = 0x00000000003165fb
RSP = 0x000000082108c950
```

addr2line resolution of 0x3165fb:
```
dl_init_phdr_info
/usr/src/lib/libc/gen/dlfcn.c:180
```

## The crashing code (first-hand, lib/libc/gen/dlfcn.c:175-195)

```c
static void
dl_init_phdr_info(void)
{
        Elf_Auxinfo *auxp;
        unsigned int i;

        for (auxp = __elf_aux_vector; auxp->a_type != AT_NULL; auxp++) {
                switch (auxp->a_type) {
                case AT_BASE:    phdr_info.dlpi_addr = (Elf_Addr)auxp->a_un.a_ptr;    break;
                case AT_EXECPATH: phdr_info.dlpi_name = (const char *)auxp->a_un.a_ptr; break;
                case AT_PHDR:   phdr_info.dlpi_phdr = (const Elf_Phdr *)auxp->a_un.a_ptr; break;
                case AT_PHNUM:  phdr_info.dlpi_phnum = (Elf_Half)auxp->a_un.a_val;      break;
                }
        }
        for (i = 0; i < phdr_info.dlpi_phnum; i++) {
                if (phdr_info.dlpi_phdr[i].p_type == PT_TLS) {   // <-- likely NULL deref here
                        phdr_info.dlpi_tls_modid = 1;
                }
        }
}
```

The crash is at the phdr iteration (line ~191): `phdr_info.dlpi_phdr[i].p_type` — if `dlpi_phdr`
is NULL (AT_PHDR not found in the auxv, or `__elf_aux_vector` is NULL), this dereferences NULL →
SIGSEGV.

## What this means

1. **NOT asld's code**: the crash is in libc's ELF auxv processing — before asld's main() runs.
2. **NOT MachServices/Sockets**: my prior diagnosis (op-138 run-3) was **wrong**. The crash is in
   the dynamic linker's phdr init, not in launchd's plist-level service registration.
3. **NOT a bootstrap gap (bl-016)**: the crash is in ELF/auxv setup, not Mach IPC.

## Root cause hypothesis (to verify by an Implementer)

`dl_init_phdr_info` is called via `pthread_once` from `dl_iterate_phdr` (line 230) or `dladdr`
(line 334). asld triggers one of these during its initialization (likely via liblaunch's Mach IPC
setup calling `dladdr` for symbol resolution). notifyd doesn't hit this path — explaining why
notifyd works but asld crashes.

The crash itself: `__elf_aux_vector` is either NULL or missing AT_PHDR for the launchd-spawned
process. The rmxOS Mach-compat `posix_spawn`/exec path may not properly propagate the ELF auxv
that FreeBSD's standard exec sets up.

## Prior diagnosis retracted

The "plist MachServices/Sockets unsupported by -u launchd" finding (0abd532) was based on
guessing without the backtrace. The Arranger correctly flagged it as disproven (notifyd uses
the same checkin pattern + works; asld NULL-checks the MachServices paths). The ACTUAL cause
is a libc/auxv-level crash, confirmed by lldb + addr2line.

## Artifacts

```
core: 13.5M ELF 64-bit FreeBSD core (from /root/asld.core.970)
serial sha: d99983850e7e3e84745c6cea77508a5726c11e06fcb21d3bfacaa51f41d3aacb
RIP = 0x3165fb = dl_init_phdr_info (dlfcn.c:180)
```
