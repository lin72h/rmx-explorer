# OB1 Foundation Gate: Opus Lane Comparison Findings

Date: 2026-05-13
Oracle results: mx-a64z (macOS 26.5, Darwin 25.5.0, Apple M4)
                mx-x64z (macOS 26.4, Darwin 25.4.0, Intel i7-11700K)
NextBSD data: batches 3, 5, 21-22 serial logs

## Summary

Three foundation probes passed on both macOS runners. The basic port operations
contract is architecturally identical between Intel and Apple Silicon. One
divergence found against our NextBSD implementation.

## OB1.1: port_names — EXACT MATCH

Classification: `exact_match`

macOS behavior:
- `mach_port_names()` returns 11 names (arm64) / 12 names (x86_64) at baseline
- Allocate receive right: count increases by 1
- Destroy receive right: count returns to baseline
- All calls return `KERN_SUCCESS`

NextBSD comparison:
- Our batch 3 `port_basics` exercises the same allocate/destroy cycle
- Our implementation passes on this contract
- Name count differs (process startup creates different baseline port sets
  between macOS and NextBSD, but the delta behavior is identical)

Note: The baseline name count difference (11 vs 12 between arm64/x86_64, and
different again on NextBSD) is expected — different kernels and architectures
create different numbers of startup ports. The contract is the delta, not the
absolute count.

## OB1.2: port_type — DIVERGENCE FOUND

Classification: `divergence` — task_self right type

macOS behavior (both runners agree):
- Receive right: `MACH_PORT_TYPE_RECEIVE` (0x20000) — exact
- Send+Receive right: `MACH_PORT_TYPE_SEND_RECEIVE` (0x30000) — exact
- Port set: `MACH_PORT_TYPE_PORT_SET` (0x80000) — exact
- **`mach_task_self()`: `MACH_PORT_TYPE_SEND` (0x10000)** — SEND only

NextBSD behavior:
- Our `task_self_trap` returns `MACH_PORT_TYPE_SEND_RECEIVE` with `entry_refs=2`

### Divergence Analysis

On real macOS, `mach_task_self()` gives the process a **send-only** right to its
own task port. The kernel holds the receive right. The process cannot receive
messages on its task port — it can only use the send right to make kernel RPCs
(like `mach_port_allocate`, `mach_port_mod_refs`, etc.).

On NextBSD, our `task_self_trap` appears to return a combined `SEND_RECEIVE`
right. This is overpermissive — user code should not hold the receive right to
its own task port.

**Severity**: Medium. Most code only uses task_self as a send right for kernel
calls. But giving SEND_RECEIVE means user code could theoretically receive
messages destined for the kernel's task port handler, which is incorrect.

**Action required**: Investigate whether our NextBSD `task_self_trap`
implementation incorrectly creates a combined right instead of a send-only
right. The kernel should retain the receive right.

**IMPORTANT caveat**: This finding needs verification. Our batch 21 measurement
used `entry_refs` introspection via FreeBSD-specific `sysctl`, not
`mach_port_type()`. The divergence might be in how we report the type rather
than in the actual right granted. We should add a specific `mach_port_type()`
check on task_self in our bhyve probe to confirm.

## OB1.3: port_get_refs — EXACT MATCH

Classification: `exact_match`

macOS uref accounting contract (both runners agree):

| Step | Observed | Expected |
| --- | --- | --- |
| receive refs after allocate | 1 | 1 |
| send refs before MAKE_SEND | 0 (KERN_SUCCESS) | 0 |
| send refs after MAKE_SEND | 1 | 1 |
| send refs after mod_refs(+1) | 2 | 2 |
| send refs after deallocate | 1 | 1 |
| send refs after mod_refs(-1) | 0 (KERN_SUCCESS) | 0 |
| receive refs at end | 1 | 1 |
| cleanup | returned to baseline | clean |

NextBSD comparison:
- Our batch 5 `send_right_mod_refs` exercises: allocate receive, insert
  make_send, mod_refs(send, -1), destroy. All pass.
- Our batch 6 exercises: allocate receive, insert make_send, deallocate send,
  destroy. All pass.
- The exact uref increment/decrement contract matches.

Notable macOS detail:
- `mach_port_get_refs(SEND)` returns `KERN_SUCCESS` with urefs=0 when no send
  right exists. It does NOT return an error. This is useful — you can query
  send refs on a receive-only port without error.
- `entry_refs` are null in all oracle observations. The oracle probes did not
  capture entry_refs for this probe. Future stock-macOS probes must keep
  `entry_refs_before` and `entry_refs_after` null unless a public observable
  source is available; OB1.4 should use urefs, port type, message fields, and
  cleanup-to-baseline as its oracle contract.

## Cross-Runner Environment Notes

| Field | mx-a64z | mx-x64z |
| --- | --- | --- |
| macOS | 26.5 | 26.4 |
| Darwin | 25.5.0 | 25.4.0 |
| Arch | arm64 | x86_64 |
| CPU | Apple M4 | Intel i7-11700K |
| Compiler | Apple clang 17.0.0 | Apple clang 21.0.0 |
| SDK | 26.5 | 26.5 |
| SIP | enabled | enabled |
| Zig | 0.16.0 | 0.16.0 |
| Baseline names | 11 | 12 |

All three foundation probes agree across both runners. No architecture-specific
behavioral differences in basic port operations.

## Action Items

1. **[INVESTIGATE]** task_self right type divergence. Add `mach_port_type()`
   check on task_self in our bhyve probe to confirm whether NextBSD truly
   returns SEND_RECEIVE or if our batch 21 measurement was measuring something
   else.

2. **[CONFIRMED]** uref accounting contract matches macOS exactly. Our batches
   3, 5, 6 are validated.

3. **[READY]** Foundation gate cleared. Oracle should proceed to OB1.4 (header
   COPY_SEND accounting). This is the probe that will confirm or deny our
   batch 21 finding.

## Next Oracle Probe Needed

OB1.4 `m1/header_copy_send_accounting.c` — this will tell us whether
COPY_SEND leaves sender urefs unchanged on macOS, confirming our batch 21
result. It should distinguish urefs before send, immediately after SEND
returns, and after RECEIVE returns. `entry_refs_*` should remain null on stock
macOS unless directly observable.
