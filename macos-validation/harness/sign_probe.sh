#!/bin/sh
#
# sign_probe.sh — Ad-hoc sign a probe binary.
#
# Usage: sign_probe.sh <binary>
#
# Returns 0 on success, 1 on failure.
# Prints exactly one line to stdout:
#   signed: <path>
#   sign_failed: <path>
#
# On non-macOS hosts where codesign is unavailable, prints sign_failed and
# returns 1. run_all.sh records that truth and still allows non-macOS
# development runs.

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <binary>" >&2
    exit 1
fi

BINARY="$1"

if [ ! -f "$BINARY" ]; then
    echo "sign_failed: $BINARY"
    echo "Error: file not found: $BINARY" >&2
    exit 1
fi

# Check if codesign is available (macOS only)
if command -v codesign >/dev/null 2>&1; then
    if codesign -s - -f "$BINARY" 2>/dev/null; then
        echo "signed: $BINARY"
        exit 0
    else
        echo "sign_failed: $BINARY"
        exit 1
    fi
else
    # Non-macOS: codesign not available, binary runs unsigned
    echo "sign_failed: $BINARY"
    echo "Note: codesign not available on this host" >&2
    exit 1
fi
