/*
 * nx_mach_utils.c — Mach IPC utility helpers for oracle probes.
 *
 * On non-macOS, baseline capture marks itself as invalid (no Mach API).
 * String formatting works on all platforms.
 */

#include "nx_mach_utils.h"

#include <stdio.h>
#include <string.h>

void
nx_baseline_capture(nx_baseline_t *b)
{
    memset(b, 0, sizeof(*b));
#ifdef __APPLE__
    b->kr = mach_port_names(mach_task_self(),
                            &b->names, &b->names_count,
                            &b->types, &b->types_count);
    b->valid = (b->kr == KERN_SUCCESS);
#else
    b->kr = KERN_FAILURE;
    b->valid = false;
#endif
}

void
nx_baseline_free(nx_baseline_t *b)
{
#ifdef __APPLE__
    if (b->names && b->names_count > 0) {
        vm_deallocate(mach_task_self(),
                      (vm_address_t)b->names,
                      b->names_count * sizeof(mach_port_name_t));
    }
    if (b->types && b->types_count > 0) {
        vm_deallocate(mach_task_self(),
                      (vm_address_t)b->types,
                      b->types_count * sizeof(mach_port_type_t));
    }
#endif
    memset(b, 0, sizeof(*b));
}

bool
nx_baseline_is_unsupported_gap(const nx_baseline_t *b)
{
    return b != NULL && !b->valid && b->kr == KERN_NOT_SUPPORTED;
}

bool
nx_baseline_blocks_probe(const nx_baseline_t *b)
{
    return b == NULL || (!b->valid && !nx_baseline_is_unsupported_gap(b));
}

bool
nx_baseline_compare(const nx_baseline_t *before,
                    const nx_baseline_t *after,
                    int *delta)
{
    if (nx_baseline_is_unsupported_gap(before) &&
        nx_baseline_is_unsupported_gap(after)) {
        if (delta)
            *delta = 0;
        return true;
    }

    if (!before->valid || !after->valid) {
        if (delta)
            *delta = 0;
        return false;
    }
    int d = (int)after->names_count - (int)before->names_count;
    if (delta)
        *delta = d;
    if (d != 0 || before->types_count != before->names_count ||
        after->types_count != after->names_count) {
        return false;
    }

    for (mach_msg_type_number_t i = 0; i < before->names_count; i++) {
        bool found = false;
        for (mach_msg_type_number_t n = 0; n < after->names_count; n++) {
            if (before->names[i] == after->names[n] &&
                before->types[i] == after->types[n]) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
    }

    return true;
}

const char *
nx_kern_return_str(kern_return_t kr)
{
    static char buf[64];
    switch (kr) {
    case KERN_SUCCESS:              return "KERN_SUCCESS";
    case KERN_INVALID_ADDRESS:      return "KERN_INVALID_ADDRESS";
    case KERN_PROTECTION_FAILURE:   return "KERN_PROTECTION_FAILURE";
    case KERN_NO_SPACE:             return "KERN_NO_SPACE";
    case KERN_INVALID_ARGUMENT:     return "KERN_INVALID_ARGUMENT";
    case KERN_FAILURE:              return "KERN_FAILURE";
    case KERN_RESOURCE_SHORTAGE:    return "KERN_RESOURCE_SHORTAGE";
    case KERN_NOT_RECEIVER:         return "KERN_NOT_RECEIVER";
    case KERN_NO_ACCESS:            return "KERN_NO_ACCESS";
    case KERN_INVALID_NAME:         return "KERN_INVALID_NAME";
    case KERN_INVALID_RIGHT:        return "KERN_INVALID_RIGHT";
    case KERN_INVALID_VALUE:        return "KERN_INVALID_VALUE";
    case KERN_UREFS_OVERFLOW:       return "KERN_UREFS_OVERFLOW";
    case KERN_INVALID_CAPABILITY:   return "KERN_INVALID_CAPABILITY";
    case KERN_NOT_SUPPORTED:        return "KERN_NOT_SUPPORTED";
    default:
        snprintf(buf, sizeof(buf), "KERN_0x%x", (unsigned)kr);
        return buf;
    }
}

const char *
nx_msg_return_str(mach_msg_return_t mr)
{
    static char buf[64];
    switch (mr) {
    case MACH_MSG_SUCCESS:              return "MACH_MSG_SUCCESS";
    case MACH_SEND_INVALID_DATA:        return "MACH_SEND_INVALID_DATA";
    case MACH_SEND_INVALID_DEST:        return "MACH_SEND_INVALID_DEST";
    case MACH_SEND_TIMED_OUT:           return "MACH_SEND_TIMED_OUT";
    case MACH_SEND_INVALID_HEADER:      return "MACH_SEND_INVALID_HEADER";
    case MACH_SEND_INVALID_NOTIFY:      return "MACH_SEND_INVALID_NOTIFY";
    case MACH_SEND_NO_BUFFER:           return "MACH_SEND_NO_BUFFER";
    case MACH_SEND_INVALID_RIGHT:       return "MACH_SEND_INVALID_RIGHT";
    case MACH_SEND_INVALID_TYPE:        return "MACH_SEND_INVALID_TYPE";
    case MACH_SEND_MSG_TOO_SMALL:       return "MACH_SEND_MSG_TOO_SMALL";
    case MACH_RCV_INVALID_NAME:         return "MACH_RCV_INVALID_NAME";
    case MACH_RCV_TIMED_OUT:            return "MACH_RCV_TIMED_OUT";
    case MACH_RCV_TOO_LARGE:            return "MACH_RCV_TOO_LARGE";
    case MACH_RCV_INVALID_DATA:         return "MACH_RCV_INVALID_DATA";
    case MACH_RCV_HEADER_ERROR:         return "MACH_RCV_HEADER_ERROR";
    case MACH_RCV_BODY_ERROR:           return "MACH_RCV_BODY_ERROR";
    default:
        snprintf(buf, sizeof(buf), "MACH_MSG_0x%x", (unsigned)mr);
        return buf;
    }
}

const char *
nx_port_type_str(mach_port_type_t type)
{
    static char buf[128];

    /* Check known composite types first. Extra bits must remain visible. */
    if (type == MACH_PORT_TYPE_SEND_RECEIVE)
        return "MACH_PORT_TYPE_SEND_RECEIVE";

    /* Single right types */
    if (type == MACH_PORT_TYPE_SEND)
        return "MACH_PORT_TYPE_SEND";
    if (type == MACH_PORT_TYPE_RECEIVE)
        return "MACH_PORT_TYPE_RECEIVE";
    if (type == MACH_PORT_TYPE_SEND_ONCE)
        return "MACH_PORT_TYPE_SEND_ONCE";
    if (type == MACH_PORT_TYPE_PORT_SET)
        return "MACH_PORT_TYPE_PORT_SET";
    if (type == MACH_PORT_TYPE_DEAD_NAME)
        return "MACH_PORT_TYPE_DEAD_NAME";

    /* Unknown — record as raw hex per plan requirement */
    snprintf(buf, sizeof(buf), "MACH_PORT_TYPE_0x%x", (unsigned)type);
    return buf;
}
