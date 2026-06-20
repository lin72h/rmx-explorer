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
PROBE_TIMEOUT="${NX_ORACLE_PROBE_TIMEOUT:-20s}"
RUN_RECORDS_FILE="${NX_ORACLE_RUN_RECORDS_FILE:-}"
if command -v python3 >/dev/null 2>&1; then
    HAVE_PYTHON=1
else
    HAVE_PYTHON=0
fi

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_string_value() {
    key="$1"
    file="$2"
    sed -n "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | sed -n '1p'
}

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
                [ -f "$bin" ] || continue
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
RAW_ENV_TMP="$RAW_ENV.tmp"
SIGN_TSV="$BASE_DIR/.build/signing.tsv"

echo "Collecting environment..." >&2
"$SCRIPT_DIR/collect_env.sh" > "$RAW_ENV_TMP"
mv "$RAW_ENV_TMP" "$RAW_ENV"

if [ "$HAVE_PYTHON" -eq 1 ]; then
    RESULT_DIR_NAME=$(python3 - "$RAW_ENV" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("result_dir_name") or "unknown")
PY
)
else
    RESULT_DIR_NAME=$(json_string_value result_dir_name "$RAW_ENV")
    [ -n "$RESULT_DIR_NAME" ] || RESULT_DIR_NAME=unknown
fi

RESULT_DIR="$BASE_DIR/results/$AGENT/$RESULT_DIR_NAME"
mkdir -p "$RESULT_DIR"

if [ -n "$RUN_RECORDS_FILE" ]; then
    mkdir -p "$(dirname "$RUN_RECORDS_FILE")"
    : > "$RUN_RECORDS_FILE"
fi

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

ENV_JSON_TMP="$RESULT_DIR/environment.json.tmp"
if [ "$HAVE_PYTHON" -eq 1 ]; then
    python3 - "$RAW_ENV" "$SIGN_TSV" "$ENV_JSON_TMP" <<'PY'
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
    python3 - "$ENV_JSON_TMP" <<'PY'
import json
import sys

with open(sys.argv[1]) as fh:
    json.load(fh)
PY
else
    cp "$RAW_ENV" "$ENV_JSON_TMP"
fi
mv "$ENV_JSON_TMP" "$RESULT_DIR/environment.json"

emit_fallback_result() {
    out_path="$1"
    env_path="$2"
    agent="$3"
    probe="$4"
    rc="$5"
    reason="$6"

    if [ "$HAVE_PYTHON" -eq 1 ]; then
        python3 - "$out_path" "$env_path" "$agent" "$probe" "$rc" "$reason" <<'PY'
import json
import sys

out_path, env_path, agent, probe, rc, reason = sys.argv[1:7]
try:
    with open(env_path) as fh:
        env = json.load(fh)
except Exception:
    env = {
        "sw_vers": None,
        "uname": None,
        "os_name": None,
        "kernel_version": None,
        "result_dir_name": None,
        "arch": None,
        "machine": None,
        "compiler": None,
        "sdk": None,
        "sdk_version": None,
        "sdk_path": None,
        "xcode_select_path": None,
        "cpu_brand": None,
        "cpu_features": {},
        "apple_silicon": {
            "hw_optional_arm64": None,
            "arm64e": None,
            "pointer_authentication": None,
            "raw_sysctls": {},
        },
        "rosetta": None,
        "sip_enabled": None,
        "sandboxed": None,
        "run_as_root": False,
        "ad_hoc_signed": False,
        "hardened_runtime": False,
        "signing": {"binaries": []},
        "zig_version": None,
        "zig_path": None,
        "zig_lib_dir": None,
        "zig_fallback": False,
        "zig_fallback_reason": None,
    }

payload = {
    "schema": "nx-r64z.macos-oracle.v1",
    "agent": agent,
    "test_id": "macos_" + probe.replace("/", "_"),
    "cross_reference": {
        "nextbsd_test_id": None,
        "donor_equivalent_id": None,
    },
    "status": "probe_failure",
    "semantic_class": "probe_failure",
    "environment": env,
    "message": {
        "msgh_bits": "",
        "remote_port": {
            "name": None,
            "disposition": None,
            "right_type": None,
        },
        "local_port": {
            "name": None,
            "disposition": None,
            "right_type": None,
        },
        "header_rights": [],
        "descriptor_count": 0,
        "descriptors": [],
    },
    "returns": [
        {
            "call": "probe_process_exit",
            "returned": reason,
            "raw": int(rc),
            "errno": None,
        }
    ],
    "right_deltas": [],
    "cleanup": {
        "returned_to_baseline": False,
        "notes": "probe did not emit valid JSON",
    },
    "notes": "probe stdout was missing or invalid; generated harness fallback result",
}

with open(out_path, "w") as fh:
    json.dump(payload, fh, indent=2, sort_keys=False)
    fh.write("\n")
PY
        return 0
    fi

    test_id=$(printf 'macos_%s' "$probe" | tr '/' '_')
    env_payload=$(cat "$env_path")
    cat > "$out_path" <<EOF
{
  "schema": "nx-r64z.macos-oracle.v1",
  "agent": "$(json_escape "$agent")",
  "test_id": "$(json_escape "$test_id")",
  "cross_reference": {
    "nextbsd_test_id": null,
    "donor_equivalent_id": null
  },
  "status": "probe_failure",
  "semantic_class": "probe_failure",
  "environment": $env_payload,
  "message": {
    "msgh_bits": "",
    "remote_port": {
      "name": null,
      "disposition": null,
      "right_type": null
    },
    "local_port": {
      "name": null,
      "disposition": null,
      "right_type": null
    },
    "header_rights": [],
    "descriptor_count": 0,
    "descriptors": []
  },
  "returns": [
    {
      "call": "probe_process_exit",
      "returned": "$(json_escape "$reason")",
      "raw": $rc,
      "errno": null
    }
  ],
  "right_deltas": [],
  "cleanup": {
    "returned_to_baseline": false,
    "notes": "probe did not emit valid JSON"
  },
  "notes": "probe stdout was missing or invalid; generated harness fallback result"
}
EOF
}

result_status() {
    if [ "$HAVE_PYTHON" -eq 1 ]; then
        python3 - "$1" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
    status = data.get("status", "probe_failure")
    if not isinstance(status, str) or not status:
        status = "probe_failure"
    print(status)
except Exception:
    print("probe_failure")
    sys.exit(1)
PY
        return $?
    fi

    if [ ! -s "$1" ]; then
        printf 'probe_failure\n'
        return 1
    fi
    status=$(awk '
        match($0, /"status"[[:space:]]*:[[:space:]]*"[^"]+"/) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^"status"[[:space:]]*:[[:space:]]*"/, "", value)
            sub(/"$/, "", value)
            print value
            exit
        }
    ' "$1")
    if [ -z "$status" ]; then
        printf 'probe_failure\n'
        return 1
    fi
    printf '%s\n' "$status"
}

append_run_record() {
    [ -n "$RUN_RECORDS_FILE" ] || return 0
    probe="$1"
    status="$2"
    rc="$3"
    result_file="$4"

    if [ "$HAVE_PYTHON" -eq 1 ]; then
        python3 - "$RUN_RECORDS_FILE" "$probe" "$status" "$rc" "$result_file" <<'PY'
import json
import sys

path, probe, result_status, rc, result_file = sys.argv[1:6]
rc_int = int(rc)
record_ok = rc_int == 0 and result_status in {"pass", "skip"}
record = {
    "component": "macos-validation",
    "probe": probe,
    "status": "ok" if record_ok else "error",
    "ok": record_ok,
    "rc": rc_int,
    "result_status": result_status,
    "result_file": result_file,
}
with open(path, "a") as fh:
    fh.write(json.dumps(record, sort_keys=True))
    fh.write("\n")
PY
        return 0
    fi

    if [ "$rc" -eq 0 ] && { [ "$status" = pass ] || [ "$status" = skip ]; }; then
        record_status=ok
        record_ok=true
    else
        record_status=error
        record_ok=false
    fi
    printf '{"component":"macos-validation","probe":"%s","rc":%s,"result_file":"%s","result_status":"%s","status":"%s","ok":%s}\n' \
        "$(json_escape "$probe")" \
        "$rc" \
        "$(json_escape "$result_file")" \
        "$(json_escape "$status")" \
        "$record_status" \
        "$record_ok" >> "$RUN_RECORDS_FILE"
}

append_runner_summary() {
    [ -n "$RUN_RECORDS_FILE" ] || return 0

    if [ "$HAVE_PYTHON" -eq 1 ]; then
        python3 - "$RUN_RECORDS_FILE" "$total" "$pass" "$fail" "$skip" "$RESULT_DIR" <<'PY'
import json
import sys

path, total, passed, failed, skipped, result_dir = sys.argv[1:7]
record = {
    "component": "macos-validation",
    "probe": "runner_summary",
    "status": "ok",
    "ok": True,
    "rc": 0,
    "total": int(total),
    "pass": int(passed),
    "fail": int(failed),
    "skip": int(skipped),
    "probe_fail": 1 if int(failed) else 0,
    "result_dir": result_dir,
}
with open(path, "a") as fh:
    fh.write(json.dumps(record, sort_keys=True))
    fh.write("\n")
PY
        return 0
    fi

    if [ "$fail" -eq 0 ]; then
        probe_fail=0
    else
        probe_fail=1
    fi
    printf '{"component":"macos-validation","fail":%s,"ok":true,"pass":%s,"probe":"runner_summary","probe_fail":%s,"rc":0,"result_dir":"%s","skip":%s,"status":"ok","total":%s}\n' \
        "$fail" \
        "$pass" \
        "$probe_fail" \
        "$(json_escape "$RESULT_DIR")" \
        "$skip" \
        "$total" >> "$RUN_RECORDS_FILE"
}

if [ "$HAVE_PYTHON" -eq 1 ]; then
    os_name=$(python3 - "$RESULT_DIR/environment.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("os_name") or "")
PY
)

    arch=$(python3 - "$RESULT_DIR/environment.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("arch") or "")
PY
)

    rosetta=$(python3 - "$RESULT_DIR/environment.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as fh:
    print(json.load(fh).get("rosetta") or "")
PY
)
else
    os_name=$(json_string_value os_name "$RESULT_DIR/environment.json")
    arch=$(json_string_value arch "$RESULT_DIR/environment.json")
    rosetta=$(json_string_value rosetta "$RESULT_DIR/environment.json")
fi

if [ "$os_name" = "Darwin" ]; then
    if [ "$rosetta" = "active" ]; then
        echo "Rosetta-translated execution is not valid oracle evidence; use native Intel for mx-x64z or native arm64 for mx-a64z." >&2
        exit 1
    fi

    case "$AGENT:$arch" in
        mx-x64z:x86_64) ;;
        mx-a64z:arm64)
            ;;
        rx:*)
            echo "Agent rx is reserved for non-macOS development/comparison lanes; use mx-x64z or mx-a64z on native macOS." >&2
            exit 1
            ;;
        *)
            echo "Agent $AGENT does not match native macOS architecture $arch." >&2
            exit 1
            ;;
    esac
elif [ "$AGENT" != "rx" ]; then
    echo "Agent $AGENT is reserved for native macOS; use rx on non-macOS hosts." >&2
    exit 1
fi

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
    tmp_result="$result_file.tmp"
    raw_invalid_file="$result_file.invalid-stdout"
    stderr_file="$RESULT_DIR/$(printf '%s' "$p" | tr '/' '_').stderr.log"
    total=$((total + 1))

    echo "Running: $p ..." >&2
    rm -f "$tmp_result" "$raw_invalid_file"
    set +e
    if command -v timeout >/dev/null 2>&1; then
        timeout "$PROBE_TIMEOUT" env \
            NX_ORACLE_AGENT="$AGENT" \
            NX_ORACLE_ENV_JSON_FILE="$RESULT_DIR/environment.json" \
            "$bin" > "$tmp_result" 2>"$stderr_file"
    else
        env \
            NX_ORACLE_AGENT="$AGENT" \
            NX_ORACLE_ENV_JSON_FILE="$RESULT_DIR/environment.json" \
            "$bin" > "$tmp_result" 2>"$stderr_file"
    fi
    probe_rc=$?
    status=$(result_status "$tmp_result")
    json_rc=$?
    set -e

    if [ "$json_rc" -ne 0 ]; then
        if [ -s "$tmp_result" ]; then
            mv "$tmp_result" "$raw_invalid_file"
        else
            rm -f "$tmp_result"
        fi
        emit_fallback_result "$result_file" "$RESULT_DIR/environment.json" \
            "$AGENT" "$p" "$probe_rc" "invalid_or_missing_probe_json"
        status="probe_failure"
    else
        mv "$tmp_result" "$result_file"
    fi

    append_run_record "$p" "$status" "$probe_rc" "$result_file"

    if [ "$probe_rc" -ne 0 ]; then
        fail=$((fail + 1))
        echo "  FAIL: $p ($status, rc=$probe_rc)" >&2
        continue
    fi

    case "$status" in
        pass) pass=$((pass + 1)); echo "  PASS: $p" >&2 ;;
        skip) skip=$((skip + 1)); echo "  SKIP: $p" >&2 ;;
        *)    fail=$((fail + 1)); echo "  FAIL: $p ($status, rc=$probe_rc)" >&2 ;;
    esac
done

echo "" >&2
echo "Summary: $total probes, $pass pass, $fail fail, $skip skip" >&2
echo "Results in: $RESULT_DIR" >&2
append_runner_summary

[ "$fail" -eq 0 ]
