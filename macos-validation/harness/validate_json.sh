#!/bin/sh
#
# validate_json.sh -- Validate oracle result JSON files.
#
# Usage:
#   validate_json.sh [file-or-directory ...]
#   validate_json.sh
#
# python3 is mandatory for Stage 1-2. jq is optional and not required.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "TOOLCHAIN FAILURE: python3 is required for JSON validation" >&2
    exit 2
fi

if [ $# -eq 0 ]; then
    set -- "$BASE_DIR/results"
fi

python3 - "$@" <<'PY'
import json
import os
import sys

SCHEMA = "nx-v64z.macos-oracle.v1"

TOP = [
    "schema", "agent", "test_id", "cross_reference", "status",
    "semantic_class", "environment", "message", "returns",
    "right_deltas", "cleanup", "notes",
]
CROSS = ["nextbsd_test_id", "donor_equivalent_id"]
ENV = [
    "sw_vers", "uname", "os_name", "kernel_version", "result_dir_name",
    "arch", "machine", "compiler", "sdk", "sdk_version", "sdk_path",
    "xcode_select_path", "cpu_brand", "cpu_features", "apple_silicon",
    "rosetta", "sip_enabled", "sandboxed", "run_as_root",
    "ad_hoc_signed", "hardened_runtime", "signing", "zig_version",
    "zig_path", "zig_lib_dir", "zig_fallback", "zig_fallback_reason",
]
APPLE = ["hw_optional_arm64", "arm64e", "pointer_authentication", "raw_sysctls"]
MESSAGE = [
    "msgh_bits", "remote_port", "local_port", "header_rights",
    "descriptor_count", "descriptors",
]
CLEANUP = ["returned_to_baseline", "notes"]
STATUSES = {"pass", "fail", "skip", "probe_failure"}
CLASSES = {
    "exact_contract", "equivalent_contract", "version_sensitive",
    "privilege_sensitive", "not_observable", "probe_failure",
    "intentional_divergence",
}


def collect(paths):
    out = []
    for path in paths:
        if os.path.isdir(path):
            for root, _, files in os.walk(path):
                for name in files:
                    if not name.endswith(".json"):
                        continue
                    if name == "environment.json":
                        continue
                    out.append(os.path.join(root, name))
        else:
            out.append(path)
    return sorted(out)


def require_keys(obj, keys, prefix, errors):
    if not isinstance(obj, dict):
        errors.append(f"{prefix} is not an object")
        return
    for key in keys:
        if key not in obj:
            errors.append(f"missing {prefix}.{key}")


def validate(path):
    errors = []
    try:
        with open(path) as fh:
            data = json.load(fh)
    except Exception as exc:
        return [f"invalid JSON: {exc}"]

    require_keys(data, TOP, "result", errors)

    if data.get("schema") != SCHEMA:
        errors.append(f"unexpected schema: {data.get('schema')!r}")
    if data.get("status") not in STATUSES:
        errors.append(f"invalid status: {data.get('status')!r}")
    if data.get("semantic_class") not in CLASSES:
        errors.append(f"invalid semantic_class: {data.get('semantic_class')!r}")

    require_keys(data.get("cross_reference"), CROSS, "cross_reference", errors)
    require_keys(data.get("environment"), ENV, "environment", errors)
    require_keys(data.get("message"), MESSAGE, "message", errors)
    require_keys(data.get("cleanup"), CLEANUP, "cleanup", errors)

    env = data.get("environment")
    if isinstance(env, dict):
        require_keys(env.get("apple_silicon"), APPLE, "environment.apple_silicon", errors)
        signing = env.get("signing")
        if not isinstance(signing, dict) or not isinstance(signing.get("binaries"), list):
            errors.append("environment.signing.binaries is not a list")
        if env.get("zig_path") is None:
            if env.get("zig_version") is not None or env.get("zig_lib_dir") is not None:
                errors.append("zig_version/zig_lib_dir must be null when zig_path is null")
        if not isinstance(env.get("zig_fallback"), bool):
            errors.append("environment.zig_fallback is not boolean")

    if not isinstance(data.get("returns"), list):
        errors.append("returns is not a list")
    if not isinstance(data.get("right_deltas"), list):
        errors.append("right_deltas is not a list")

    return errors


files = collect(sys.argv[1:])
if not files:
    print("No oracle result JSON files found", file=sys.stderr)
    sys.exit(1)

passed = 0
failed = 0
for path in files:
    errors = validate(path)
    if errors:
        failed += 1
        print(f"FAIL: {path}", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
    else:
        passed += 1
        print(f"PASS: {path}", file=sys.stderr)

print("", file=sys.stderr)
print(f"Validated: {passed + failed} files, {passed} pass, {failed} fail", file=sys.stderr)
sys.exit(1 if failed else 0)
PY
