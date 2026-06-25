/* op-139 auxv-confirm probe — is AT_PHDR missing/NULL for launchd-spawned procs?
 *
 * Hypothesis (id-024, from op-138): asld SIGSEGV in dl_init_phdr_info at
 * libc dlfcn.c:180 because __elf_aux_vector is NULL or missing the AT_PHDR
 * entry for launchd-spawned processes. notifyd works because it doesn't
 * trigger the dl_iterate_phdr / dladdr path during init.
 *
 * DO:
 *   - Read `extern void *__elf_aux_vector;` directly — the SAME symbol libc's
 *     dl_init_phdr_info dereferences. Requires -fPIC + -Wl,--unresolved-symbols=
 *     ignore-all at link time so the GOT entry is resolved by rtld at runtime
 *     (rtld publishes the symbol even though libc.so.7 only imports it).
 *   - ALSO compute the auxv pointer the way libc does for static binaries
 *     (lib/libsys/auxv.c:53-57): sp = environ; while (*sp++ != 0);
 *     auxv = (Elf_Auxinfo *)sp;  This is the SOURCE DATA the kernel built.
 *   - Compare both pointers — they MUST agree. If __elf_aux_vector is NULL
 *     or points elsewhere while environ-walk finds the real auxv, that's the
 *     smoking gun for id-024 (data is good, global is broken).
 *   - Walk every a_type / a_un pair from the global.
 *   - Record presence + value of AT_PHDR, AT_PHNUM, AT_ENTRY, AT_BASE, AT_EXECFD.
 *
 * Critical (Arranger guardrail): this probe must NOT call dladdr /
 * dl_iterate_phdr / anything that trips dl_init_phdr_info — or the probe
 * will crash the same way asld does, instead of reporting.
 *
 * Structured markers:
 *   OP139_AUXV_START
 *   OP139_AUXV_GLOBAL  addr=... deref=...
 *   OP139_AUXV_ENVWALK addr=...
 *   OP139_AUXV_VECTOR status=OK|NULL|global_envwalk_mismatch  ...
 *   OP139_AUXV_ENTRIES
 *     [N] a_type=... a_val=... a_ptr=...
 *   OP139_AUXV_SUMMARY entries=N
 *   OP139_AT_PHDR_present=0|1  value=0x...
 *   OP139_AT_PHNUM_present=0|1 value=...
 *   OP139_AT_ENTRY_present=0|1 value=...
 *   OP139_AT_BASE_present=0|1  value=...
 *   OP139_AT_EXECFD_present=0|1 value=...
 *   OP139_VERDICT at_phdr_missing=0|1
 *   OP139_TERMINAL status=0
 */
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/elf_common.h>

/* Elf_Auxinfo is a kernel-internal type — not in any public userland header
 * on rmxOS. Mirror the kernel layout locally. amd64 layout:
 *   { int32_t a_type; (4 bytes pad) union { int64_t a_val; void *a_ptr; } a_un; }
 * = 16 bytes per entry. */
typedef struct {
	int32_t	a_type;
	int32_t	_pad;
	union {
		long	 a_val;
		void	*a_ptr;
	} a_un;
} op139_auxinfo_t;

/* The SAME symbol libc/dlfcn.c dereferences. rtld publishes it (FBSDprivate_1.0);
 * libc.so.7 imports it. Built with -fPIC + -Wl,--unresolved-symbols=ignore-all
 * so the GOT entry is filled in by rtld at runtime. */
extern void *__elf_aux_vector;

/* environ is provided by libc at process start. The auxv is laid out
 * immediately after the envp NULL terminator on the main stack:
 *   argc | argv[0..argc-1] | NULL | envp[0..envc-1] | NULL | auxv[0..AT_NULL]
 * Walking environ forward past the NULL terminator lands us on the auxv. */
extern char **environ;

static const char *
at_name(int32_t t)
{
	switch (t) {
	case AT_NULL:		return "AT_NULL";
	case AT_IGNORE:		return "AT_IGNORE";
	case AT_EXECFD:		return "AT_EXECFD";
	case AT_PHDR:		return "AT_PHDR";
	case AT_PHENT:		return "AT_PHENT";
	case AT_PHNUM:		return "AT_PHNUM";
	case AT_PAGESZ:		return "AT_PAGESZ";
	case AT_BASE:		return "AT_BASE";
	case AT_FLAGS:		return "AT_FLAGS";
	case AT_ENTRY:		return "AT_ENTRY";
	case AT_NOTELF:		return "AT_NOTELF";
	case AT_UID:		return "AT_UID";
	case AT_EUID:		return "AT_EUID";
	case AT_GID:		return "AT_GID";
	case AT_EGID:		return "AT_EGID";
	case AT_EXECPATH:	return "AT_EXECPATH";
	case AT_CANARY:		return "AT_CANARY";
	case AT_CANARYLEN:	return "AT_CANARYLEN";
	case AT_OSRELDATE:	return "AT_OSRELDATE";
	case AT_NCPUS:		return "AT_NCPUS";
	case AT_PAGESIZES:	return "AT_PAGESIZES";
	case AT_PAGESIZESLEN:	return "AT_PAGESIZESLEN";
	case AT_TIMEKEEP:	return "AT_TIMEKEEP";
	case AT_STACKPROT:	return "AT_STACKPROT";
	case AT_EHDRFLAGS:	return "AT_EHDRFLAGS";
	case AT_HWCAP:		return "AT_HWCAP";
	case AT_HWCAP2:		return "AT_HWCAP2";
	case AT_BSDFLAGS:	return "AT_BSDFLAGS";
	case AT_ARGC:		return "AT_ARGC";
	case AT_ARGV:		return "AT_ARGV";
	case AT_ENVC:		return "AT_ENVC";
	case AT_ENVV:		return "AT_ENVV";
	case AT_PS_STRINGS:	return "AT_PS_STRINGS";
	case AT_FXRNG:		return "AT_FXRNG";
	case AT_KPRELOAD:	return "AT_KPRELOAD";
	case AT_USRSTACKBASE:	return "AT_USRSTACKBASE";
	case AT_USRSTACKLIM:	return "AT_USRSTACKLIM";
	case AT_HWCAP3:		return "AT_HWCAP3";
	case AT_HWCAP4:		return "AT_HWCAP4";
	default:		return "?";
	}
}

int
main(void)
{
	op139_auxinfo_t *auxp_global;
	op139_auxinfo_t *auxp_envwalk;
	op139_auxinfo_t *auxp;
	uintptr_t *sp;
	int found_phdr = 0, found_phnum = 0, found_base = 0, found_entry = 0, found_execfd = 0;
	int count = 0, envc = 0;
	uintptr_t phdr_val = 0, entry_val = 0, base_val = 0;
	long phnum_val = 0;
	int execfd_val = 0;

	printf("OP139_AUXV_START\n");

	/* === PATH 1: read the libc global directly === */
	/* This is the SAME pointer dl_init_phdr_info dereferences at dlfcn.c:180.
	 * If THIS is NULL, the crash is explained regardless of what's on the
	 * stack — libc will segfault when it dereferences. */
	auxp_global = (op139_auxinfo_t *)__elf_aux_vector;
	printf("OP139_AUXV_GLOBAL global_addr=%p deref_value=%p\n",
	    (void *)&__elf_aux_vector, (void *)auxp_global);

	/* === PATH 2: compute from environ (the source-of-truth stack layout) === */
	if (environ == NULL) {
		printf("OP139_AUXV_ENVWALK addr=NULL reason=environ_NULL\n");
		auxp_envwalk = NULL;
	} else {
		sp = (uintptr_t *)environ;
		while (*sp != 0) { sp++; envc++; }
		sp++; /* skip the NULL terminator */
		auxp_envwalk = (op139_auxinfo_t *)sp;
		printf("OP139_AUXV_ENVWALK addr=%p environ=%p envc=%d\n",
		    (void *)auxp_envwalk, (void *)environ, envc);
	}

	/* === Cross-check: the two paths must agree === */
	if (auxp_global == NULL && auxp_envwalk == NULL) {
		printf("OP139_AUXV_VECTOR status=NULL_both_paths\n");
		printf("OP139_VERDICT auxv_null=1 at_phdr_missing=1 (dl_init_phdr_info would SIGSEGV at first iteration)\n");
		printf("OP139_TERMINAL status=0\n");
		return 0;
	}
	if (auxp_global == NULL && auxp_envwalk != NULL) {
		/* SMOKING GUN for id-024: data is on the stack, but the libc global
		 * is NULL. dl_init_phdr_info would crash; environ-walk finds data. */
		printf("OP139_AUXV_VECTOR status=GLOBAL_NULL_ENVWALK_OK global_broken=1\n");
		printf("OP139_VERDICT auxv_null=1 at_phdr_missing=1 (global NULL — root cause CONFIRMED)\n");
		printf("OP139_TERMINAL status=0\n");
		return 0;
	}
	if (auxp_global != auxp_envwalk) {
		/* Both non-NULL but disagree — also a smoking gun, different flavor. */
		printf("OP139_AUXV_VECTOR status=GLOBAL_ENVWALK_MISMATCH global=%p envwalk=%p\n",
		    (void *)auxp_global, (void *)auxp_envwalk);
		/* Continue walking the GLOBAL since that's what libc uses. */
	}
	printf("OP139_AUXV_VECTOR status=OK using=global global==envwalk=%d\n",
	    auxp_global == auxp_envwalk);
	printf("OP139_AUXV_ENTRIES\n");

	for (auxp = auxp_global; auxp->a_type != AT_NULL; auxp++) {
		printf("  [%2d] a_type=%-4d (%-14s) a_val=0x%016lx a_ptr=%p\n",
		    count, (int)auxp->a_type, at_name(auxp->a_type),
		    (unsigned long)auxp->a_un.a_val, auxp->a_un.a_ptr);
		switch (auxp->a_type) {
		case AT_PHDR:
			found_phdr = 1;
			phdr_val = (uintptr_t)auxp->a_un.a_ptr;
			break;
		case AT_PHNUM:
			found_phnum = 1;
			phnum_val = auxp->a_un.a_val;
			break;
		case AT_ENTRY:
			found_entry = 1;
			entry_val = (uintptr_t)auxp->a_un.a_val;
			break;
		case AT_BASE:
			found_base = 1;
			base_val = (uintptr_t)auxp->a_un.a_ptr;
			break;
		case AT_EXECFD:
			found_execfd = 1;
			execfd_val = (int)auxp->a_un.a_val;
			break;
		default:
			break;
		}
		count++;
		/* Defensive cap — a corrupted vector without AT_NULL would loop forever. */
		if (count > 64) {
			printf("  ... truncated at 64 entries (no AT_NULL seen)\n");
			break;
		}
	}

	printf("OP139_AUXV_SUMMARY entries=%d\n", count);
	printf("OP139_AT_PHDR_present=%d   value=0x%lx\n", found_phdr,   (unsigned long)phdr_val);
	printf("OP139_AT_PHNUM_present=%d  value=%ld\n",   found_phnum,  phnum_val);
	printf("OP139_AT_ENTRY_present=%d  value=0x%lx\n", found_entry,  (unsigned long)entry_val);
	printf("OP139_AT_BASE_present=%d   value=0x%lx\n", found_base,   (unsigned long)base_val);
	printf("OP139_AT_EXECFD_present=%d value=%d\n",    found_execfd, execfd_val);

	/* dl_init_phdr_info's for-loop (dlfcn.c:189-193) reads
	 *   phdr_info.dlpi_phdr[i].p_type
	 * where dlpi_phdr is initialized ONLY from AT_PHDR. If AT_PHDR is
	 * absent OR points to NULL, dlpi_phdr stays NULL → NULL deref → SIGSEGV.
	 * That matches the op-138 backtrace (crash at dlfcn.c:180→189).
	 *
	 * NOTE: this probe does NOT directly exercise dl_init_phdr_info (which
	 * runs via pthread_once from dladdr/dl_iterate_phdr). The verdict here
	 * is about the AUXV DATA + the GLOBAL POINTER only. */
	int phdr_missing = (!found_phdr) || (phdr_val == 0);
	printf("OP139_VERDICT at_phdr_missing=%d", phdr_missing);
	if (phdr_missing) {
		printf(" (dl_init_phdr_info would SIGSEGV — matches op-138 backtrace)");
	}
	printf("\n");

	printf("OP139_TERMINAL status=0\n");
	return 0;
}
