#!/bin/sh
#
# run_all.sh -- Run enabled oracle probes and capture schema JSON results.
#
# Usage:
#   run_all.sh --agent mx-x64z
#   run_all.sh --agent mx-a64z
#   run_all.sh --agent rx        # non-macOS development/comparison lane
#   run_all.sh --list

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_BIN="$BASE_DIR/.build/bin"

AGENT=""
LIST_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --agent)
            shift
            [ $# -gt 0 ] || { echo "Error: --agent needs a value" >&2; exit 1; }
            AGENT="$1"
            ;;
        --list)
            LIST_ONLY=true
            ;;
        *)
            echo "Usage: $0 --agent <mx-x64z|mx-a64z|rx> [--list]" >&2
            exit 1
            ;;
    esac
    shift
done

discover_probes() {
    probes=""
    for dir in foundation m1 m2; do
        probe_dir="$BUILD_BIN/$dir"
        if [ -d "$probe_dir" ]; then
            for bin in "$probe_dir"/*; do
                [ -x "$bin" ] || continue
                probes="$probes $dir/$(basename "$bin")"
            done
        fi
    done
    printf '%s\n' "$probes"
}

PROBES=$(discover_probes)

if [ "$LIST_ONLY" = "true" ]; then
    echo "Known probes:"
    if [ -z "$PROBES" ]; then
        echo "  (none built -- run 'make' first)"
    else
        for p in $PROBES; do
            echo "  $p"
        done
    fi
    exit 0
fi

if [ -z "$AGENT" ]; then
    echo "Error: --agent is required" >&2
    echo "Usage: $0 --agent <mx-x64z|mx-a64z|rx>" >&2
    exit 1
fi

case "$AGENT" in
    mx-x64z|mx-a64z|rx) ;;
    *)
        echo "Error: agent must be mx-x64z, mx-a64z, or rx; got: $AGENT" >&2
        exit 1
        ;;
esac

if [ -z "$PROBES" ]; then
    echo "No probes found. Run 'make' first." >&2
    exit 1
fi

mkdir -p "$BASE_DIR/.build"

RAW_ENV="$BASE_DIR/.build/environment.raw.json"
SIGN_TSV="$BASE_DIR/.build/signing.tsv"

echo "Collecting environment..." >&2
"$SCRIPT_DIR/collect_env.sh" > "$RAW_ENV"

RESULT_DIR_NAME=$(python3 - "$RAW_ENV" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("result_dir_name") or "unknown")
PY
)

RESULT_DIR="$BASE_DIR/results/$AGENT/$RESULT_DIR_NAME"
mkdir -p "$RESULT_DIR"

: > "$SIGN_TSV"
: > "$RESULT_DIR/signing.stderr.log"

echo "Signing probes..." >&2
sign_fail=0
for p in $PROBES; do
    bin="$BUILD_BIN/$p"
    [ -x "$bin" ] || continue
    set +e
    sign_output=$("$SCRIPT_DIR/sign_probe.sh" "$bin" 2>>"$RESULT_DIR/signing.stderr.log")
    rc=$?
    set -e
    case "$sign_output" in
        signed:*) status="signed" ;;
        sign_failed:*) status="sign_failed" ;;
        *) status="invalid_output" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$bin" "$status" "$rc" "$sign_output" >> "$SIGN_TSV"
    echo "  $sign_output" >&2
    if [ "$rc" -ne 0 ]; then
        sign_fail=1
    fi
done

python3 - "$RAW_ENV" "$SIGN_TSV" "$RESULT_DIR/environment.json" <<'PY'
import json
import sys

raw_env, sign_tsv, out_path = sys.argv[1:4]
with open(raw_env) as fh:
    env = json.load(fh)

records = []
with open(sign_tsv) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        path, status, return_code, output = line.split("\t", 3)
        records.append({
            "path": path,
            "status": status,
            "return_code": int(return_code),
            "output": output,
        })

env["signing"] = {"binaries": records}
env["ad_hoc_signed"] = (
    env.get("os_name") == "Darwin" and
    bool(records) and
    all(r["status"] == "signed" and r["return_code"] == 0 for r in records)
)

with open(out_path, "w") as fh:
    json.dump(env, fh, indent=2, sort_keys=False)
    fh.write("\n")
PY

os_name=$(python3 - "$RESULT_DIR/environment.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("os_name") or "")
PY
)

if [ "$os_name" = "Darwin" ] && [ "$sign_fail" -ne 0 ]; then
    echo "Signing failed on macOS; refusing to run unsigned oracle probes." >&2
    exit 1
fi

echo "Results: $RESULT_DIR" >&2

pass=0
fail=0
skip=0
total=0

for p in $PROBES; do
    bin="$BUILD_BIN/$p"
    result_file="$RESULT_DIR/$(printf '%s' "$p" | tr '/' '_').json"
    stderr_file="$RESULT_DIR/$(printf '%s' "$p" | tr '/' '_').stderr.log"
    total=$((total + 1))

    echo "Running: $p ..." >&2
    set +e
    NX_ORACLE_AGENT="$AGENT" \
    NX_ORACLE_ENV_JSON_FILE="$RESULT_DIR/environment.json" \
        "$bin" > "$result_file" 2>"$stderr_file"
    probe_rc=$?
    set -e

    status=$(python3 - "$result_file" <<'PY'
import json
import sys
try:
    with open(sys.argv[1]) as fh:
        print(json.load(fh).get("status", "probe_failure"))
except Exception:
    print("probe_failure")
PY
)
    case "$status" in
        pass) pass=$((pass + 1)); echo "  PASS: $p" >&2 ;;
        skip) skip=$((skip + 1)); echo "  SKIP: $p" >&2 ;;
        *)    fail=$((fail + 1)); echo "  FAIL: $p ($status, rc=$probe_rc)" >&2 ;;
    esac
done

echo "" >&2
echo "Summary: $total probes, $pass pass, $fail fail, $skip skip" >&2
echo "Results in: $RESULT_DIR" >&2

[ "$fail" -eq 0 ]
