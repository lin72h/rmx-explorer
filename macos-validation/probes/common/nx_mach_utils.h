/*
 * nx_mach_utils.h — Mach IPC utility helpers for oracle probes.
 *
 * Provides:
 *   - mach_port_names baseline snapshot and comparison
 *   - kern_return_t / mach_msg_return_t formatting
 *   - symbolic port type formatting
 *
 * On non-macOS hosts, Mach types are stubbed so the helper library
 * compiles. Actual Mach functionality is only available on macOS.
 */

#ifndef NX_MACH_UTILS_H
#define NX_MACH_UTILS_H

#include <stdbool.h>

#if __has_include(<mach/mach.h>)
#include <mach/mach.h>
#else
/* Minimal stubs for hosts WITHOUT <mach/mach.h> (e.g. bare FreeBSD). rmxOS
 * (which has Mach) takes the real path above, same as macOS -- the guard keys
 * on Mach availability, not on __APPLE__. */
typedef unsigned int mach_port_t;
typedef unsigned int mach_port_name_t;
typedef unsigned int mach_port_type_t;
typedef unsigned int mach_port_urefs_t;
typedef unsigned int mach_msg_type_number_t;
typedef int          kern_return_t;
typedef int          mach_msg_return_t;
#define MACH_PORT_NULL             0
#define KERN_SUCCESS               0
#define KERN_INVALID_ADDRESS       1
#define KERN_PROTECTION_FAILURE    2
#define KERN_NO_SPACE              3
#define KERN_INVALID_ARGUMENT      4
#define KERN_FAILURE               5
#define KERN_RESOURCE_SHORTAGE     6
#define KERN_NOT_RECEIVER          7
#define KERN_NO_ACCESS             8
#define KERN_INVALID_NAME         15
#define KERN_INVALID_RIGHT        17
#define KERN_INVALID_VALUE        18
#define KERN_UREFS_OVERFLOW       19
#define KERN_INVALID_CAPABILITY   20
#define KERN_NOT_SUPPORTED        46
#define MACH_MSG_SUCCESS            0
#define MACH_SEND_INVALID_DATA     0x10000002
#define MACH_SEND_INVALID_DEST     0x10000003
#define MACH_SEND_TIMED_OUT        0x10000004
#define MACH_SEND_INVALID_HEADER   0x10000010
#define MACH_SEND_INVALID_NOTIFY   0x1000000b
#define MACH_SEND_NO_BUFFER        0x1000000d
#define MACH_SEND_INVALID_RIGHT    0x10000009
#define MACH_SEND_INVALID_TYPE     0x1000000f
#define MACH_SEND_MSG_TOO_SMALL    0x10000008
#define MACH_RCV_INVALID_NAME      0x10004002
#define MACH_RCV_TIMED_OUT         0x10004003
#define MACH_RCV_TOO_LARGE         0x10004004
#define MACH_RCV_INVALID_DATA      0x10004008
#define MACH_RCV_HEADER_ERROR      0x1000400d
#define MACH_RCV_BODY_ERROR        0x1000400e
#define MACH_PORT_TYPE_SEND          (1 << 16)
#define MACH_PORT_TYPE_RECEIVE       (1 << 17)
#define MACH_PORT_TYPE_SEND_ONCE     (1 << 18)
#define MACH_PORT_TYPE_PORT_SET      (1 << 19)
#define MACH_PORT_TYPE_DEAD_NAME     (1 << 20)
#define MACH_PORT_TYPE_SEND_RECEIVE  (MACH_PORT_TYPE_SEND | MACH_PORT_TYPE_RECEIVE)
#define MACH_PORT_RIGHT_SEND       0
#define MACH_PORT_RIGHT_RECEIVE    1
#define MACH_PORT_RIGHT_PORT_SET   3
#define MACH_MSG_TYPE_MAKE_SEND   20
#define MACH_MSG_PORT_DESCRIPTOR   0
#endif /* !__has_include(<mach/mach.h>) */

#ifndef KERN_NOT_SUPPORTED
#define KERN_NOT_SUPPORTED        46
#endif

/*
 * Baseline snapshot — captures mach_port_names() state.
 * Used before and after probe bodies to verify cleanup.
 */
typedef struct {
    mach_port_name_t *names;
    mach_msg_type_number_t names_count;
    mach_port_type_t *types;
    mach_msg_type_number_t types_count;
    bool valid;       /* false if mach_port_names() failed */
    kern_return_t kr; /* return code from mach_port_names() */
} nx_baseline_t;

/* Take a baseline snapshot of the current task's port namespace.
 * On non-macOS, sets valid=false. */
void nx_baseline_capture(nx_baseline_t *b);

/* Free resources held by a baseline snapshot. */
void nx_baseline_free(nx_baseline_t *b);

/* Compare two baselines.
 * Returns true if both snapshots contain the same name/type entries.
 * Sets *delta to (after->names_count - before->names_count). */
bool nx_baseline_compare(const nx_baseline_t *before,
                         const nx_baseline_t *after,
                         int *delta);

/* True when mach_port_names() failed with rmxOS's observable
 * KERN_NOT_SUPPORTED gap. That gap should be cataloged, but it should not
 * hide the probe's primary Mach behavior. */
bool nx_baseline_is_unsupported_gap(const nx_baseline_t *b);

/* True when a baseline failure should stop the probe before its primary
 * behavior can be interpreted. KERN_NOT_SUPPORTED is a cataloged observable,
 * not a setup failure. */
bool nx_baseline_blocks_probe(const nx_baseline_t *b);

/* Format a kern_return_t as a string. Returns a static buffer. */
const char *nx_kern_return_str(kern_return_t kr);

/* Format a mach_msg_return_t as a string. Returns a static buffer. */
const char *nx_msg_return_str(mach_msg_return_t mr);

/* Format a mach_port_type_t as a string. Returns a static buffer. */
const char *nx_port_type_str(mach_port_type_t type);

#endif /* NX_MACH_UTILS_H */
