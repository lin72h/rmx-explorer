#!/bin/sh
#
# collect_env.sh -- Capture host environment as one JSON object.
#
# This script is intentionally broader than the current C-only probes. The
# result schema is shared with later Zig probes, so Zig fields are always
# present. Missing tools are represented as null/false, not by omitted fields.

set -eu

if ! command -v python3 >/dev/null 2>&1; then
    echo "TOOLCHAIN FAILURE: python3 is required for environment capture" >&2
    exit 2
fi

exec python3 - <<'PY'
import datetime
import json
import os
import platform
import re
import shutil
import subprocess
import sys


failures = []


def run(argv):
    try:
        cp = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, check=False)
    except Exception as exc:
        failures.append({"command": argv, "error": str(exc)})
        return None
    if cp.returncode != 0:
        failures.append({
            "command": argv,
            "return_code": cp.returncode,
            "stderr": cp.stderr.strip() or None,
        })
        return None
    return cp.stdout.rstrip("\n")


def first_line(text):
    if not text:
        return None
    return text.splitlines()[0] if text.splitlines() else None


def sanitize_component(value):
    if not value:
        return "unknown"
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9._+-]+", "-", value)
    return value.strip("-") or "unknown"


def sanitize_exact_component(value):
    if not value:
        return "unknown"
    value = value.strip()
    value = re.sub(r"[^A-Za-z0-9._+-]+", "-", value)
    return value.strip("-") or "unknown"


def sysctl_value(name):
    return run(["sysctl", "-n", name])


def sysctl_map(names):
    out = {}
    for name in names:
        out[name] = sysctl_value(name)
    return out


uname = platform.uname()
os_name = uname.system
kernel_version = uname.release
is_macos = os_name == "Darwin"
today = datetime.datetime.now().strftime("%Y%m%d")

sw_vers_full = run(["sw_vers"]) if is_macos else None
macos_version = run(["sw_vers", "-productVersion"]) if is_macos else None
darwin_version = kernel_version if is_macos else None

if is_macos:
    result_dir_name = "%s-%s-%s" % (
        today,
        sanitize_component(macos_version),
        sanitize_component(darwin_version),
    )
else:
    result_dir_name = "%s-%s-%s" % (
        today,
        sanitize_exact_component(os_name),
        sanitize_exact_component(kernel_version),
    )

compiler = first_line(run(["cc", "--version"])) or first_line(run(["clang", "--version"]))

sdk_path = run(["xcrun", "--show-sdk-path"]) if is_macos else None
sdk_version = run(["xcrun", "--show-sdk-version"]) if is_macos else None
xcode_select_path = run(["xcode-select", "-p"]) if is_macos else None

if is_macos:
    cpu_brand = sysctl_value("machdep.cpu.brand_string")
else:
    cpu_brand = sysctl_value("hw.model")

cpu_features = {}
if is_macos:
    cpu_features = sysctl_map([
        "machdep.cpu.features",
        "machdep.cpu.leaf7_features",
        "hw.optional.arm64",
        "hw.optional.arm.FEAT_PAuth",
        "hw.optional.arm.FEAT_PAuth2",
    ])
else:
    cpu_features = sysctl_map([
        "hw.instruction_sse",
        "hw.instruction_sse2",
        "hw.instruction_avx",
        "hw.instruction_avx2",
    ])

apple_raw = sysctl_map([
    "hw.optional.arm64",
    "hw.optional.arm.FEAT_PAuth",
    "hw.optional.arm.FEAT_PAuth2",
]) if is_macos else {}

rosetta = None
if is_macos:
    translated = sysctl_value("sysctl.proc_translated")
    if translated == "1":
        rosetta = "active"
    elif translated == "0":
        rosetta = "native"
    else:
        rosetta = "unknown"

sip_enabled = None
if is_macos:
    csr = run(["csrutil", "status"])
    if csr:
        if "enabled" in csr:
            sip_enabled = True
        elif "disabled" in csr:
            sip_enabled = False

zig_path = shutil.which("zig")
zig_version = None
zig_lib_dir = None
if zig_path:
    zig_version = first_line(run([zig_path, "version"]))
    zig_env = run([zig_path, "env"])
    if zig_env:
        try:
            zig_env_obj = json.loads(zig_env)
            zig_lib_dir = zig_env_obj.get("lib_dir")
        except json.JSONDecodeError as exc:
            match = re.search(r'\.lib_dir\s*=\s*"([^"]+)"', zig_env)
            if match:
                zig_lib_dir = match.group(1)
            else:
                failures.append({"command": [zig_path, "env"], "error": str(exc)})

env = {
    "sw_vers": sw_vers_full,
    "uname": " ".join([uname.system, uname.node, uname.release, uname.version, uname.machine]),
    "os_name": os_name,
    "kernel_version": kernel_version,
    "result_dir_name": result_dir_name,
    "arch": uname.machine,
    "machine": uname.machine,
    "compiler": compiler,
    "sdk": sdk_path,
    "sdk_version": sdk_version,
    "sdk_path": sdk_path,
    "xcode_select_path": xcode_select_path,
    "cpu_brand": cpu_brand,
    "cpu_features": cpu_features,
    "apple_silicon": {
        "hw_optional_arm64": apple_raw.get("hw.optional.arm64"),
        "arm64e": apple_raw.get("hw.optional.arm.FEAT_PAuth"),
        "pointer_authentication": apple_raw.get("hw.optional.arm.FEAT_PAuth2"),
        "raw_sysctls": apple_raw,
    },
    "rosetta": rosetta,
    "sip_enabled": sip_enabled,
    "sandboxed": bool(os.environ.get("APP_SANDBOX_CONTAINER_ID")) if is_macos else None,
    "run_as_root": os.geteuid() == 0,
    "ad_hoc_signed": False,
    "hardened_runtime": False,
    "signing": {
        "binaries": []
    },
    "zig_version": zig_version,
    "zig_path": zig_path,
    "zig_lib_dir": zig_lib_dir,
    "zig_fallback": False,
    "zig_fallback_reason": None,
    "command_failures": failures,
}

json.dump(env, sys.stdout, indent=2, sort_keys=False)
sys.stdout.write("\n")
PY
