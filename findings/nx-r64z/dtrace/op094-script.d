#!/usr/sbin/dtrace -Fs
/* op-094 v4 — minimal, type-safe. submission = SYSCALL kevent(nchanges>0)+FBT
 * filt_timervalidate; fire = FBT filt_timerexpire; delivery = SYSCALL kevent:return.
 * The probe's own result.json records dispatch_after_fired. */
#pragma D option quiet
BEGIN { printf("op094_v4_begin target_pid=%d\n", $target); }

syscall::kevent:entry
/pid == $target/
{ self->knc = (int)arg2;
  printf("SYSCALL kevent ENTRY kq=%d nchanges=%d nevents=%d\n", (int)arg0, self->knc, (int)arg4); }
syscall::kevent:return
/self->knc/
{ printf("SYSCALL kevent RETURN rc=%d (nchanges was %d)\n", (int)arg1, self->knc); self->knc = 0; }

fbt::filt_timer*:entry
{ printf("FBT %s ENTRY\n", probefunc); }
