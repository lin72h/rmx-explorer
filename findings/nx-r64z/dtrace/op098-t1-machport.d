#pragma D option quiet
/* op-098 Task 1 — mach_recv GREEN paradox: is the message delivered via the
 * kernel EVFILT_MACHPORT (null_filtops -> impossible) or a libdispatch-internal
 * non-kqueue path? Decisive:
 *   - fbt::filt_machport*  -> expect ZERO (null_filtops; confirms not-kernel)
 *   - fbt::mach_msg*       -> the manager drain + handler receive
 *   - pid dmrs_handler     -> the probe's handler fired (a.out symbol) */
BEGIN { printf("op098_t1_begin target=%d\n", $target); }
fbt::filt_machport*:entry
{ printf("FBT %s ENTRY <<<KERNEL MACHPORT FILTER>>>\n", probefunc); }
fbt::mach_msg*:entry
{ printf("FBT %s ENTRY\n", probefunc); self->mm = 1; }
fbt::mach_msg*:return
/self->mm/
{ printf("FBT %s RETURN\n", probefunc); self->mm = 0; }
pid$target::dmrs_handler:entry
{ printf("PID dmrs_handler ENTRY <<<HANDLER FIRED>>>\n"); }
