#!/usr/sbin/dtrace -s
#pragma D option quiet

BEGIN
{
	printf("op101_usdt_begin target_pid=%d\n", $target);
}

dispatch$target:::timer-configure,
dispatch$target:::timer-program,
dispatch$target:::timer-wake,
dispatch$target:::timer-fire
{
	printf("OP101_USDT_FIRE provider=%s module=%s function=%s name=%s pid=%d\n",
	    probeprov, probemod, probefunc, probename, pid);
}

END
{
	printf("op101_usdt_end\n");
}
