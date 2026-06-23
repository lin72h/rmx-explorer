/* invariant-oracle: mach_msg send vs receive balance (no leaked messages).
 * Count send entries vs receive entries over the run; at END assert balanced. */
#pragma D option quiet
BEGIN { printf("msg-balance oracle start\n"); }
fbt::mach_msg_send:entry { @send = count(); }
fbt::mach_msg_receive:entry { @recv = count(); }
END { printf("send=%d recv=%d delta=%d\n", @send, @recv, @send - @recv);
      exit(@send - @recv != 0); }  /* non-zero exit = imbalance = leak */
