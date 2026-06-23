# op-114 — staging-model audit: inputs pinned, distributable-gap scoped

Date: 2026-06-23. Lane: `rmx-explorer-rx-x64z` (recon, observation-only).

## The staging pipeline (end-to-end)

The op-104/op-110 guest is produced by a **snapshot + selective overlay** model:

```
base image (pre-staged rmxOS snapshot)
  → cp (disposable copy)
  → stage-userland.sh (overlay alpha userland + mach.ko + test infra)
  → run-guest.sh (bhyve boot)
```

### Step 1: base image

**Path**: `block-078-runtime-smoke/runs/20260619T112919Z-clean-check-token-smoke/block078-userland-smoke.img`
**Size**: 6.0G raw GPT image (boot/efi/swap/ufs partitions).
**Nature**: a **pre-staged rmxOS image** (NOT stock FreeBSD):
- Userland: FreeBSD 15.0 (os-release says "15.0-RELEASE"; actual kernel is "15.0-STABLE").
- **Two kernels present**:
  - `/boot/kernel/kernel` — ident `TWQDEBUG` (FreeBSD 15.0-STABLE, the previous-test kernel).
  - `/boot/MACHDEBUGDEBUG/kernel` — ident `MACHDEBUGDEBUG` (the Mach-compat kernel that actually boots).
- `loader.conf`: `kernel="MACHDEBUGDEBUG"`, `module_path="/boot/kernel;/boot/modules;/boot/MACHDEBUGDEBUG"`, `mach_load="YES"`.
- `mach.ko` in `/boot/modules/` (installed by stage-guest.sh).
- rc.conf: all `nxplatform_phase*` services disabled (NO test phases auto-run).
- 83 stock FreeBSD modules in `/boot/kernel/`.

**Provenance of the base image itself**: undocumented in the current staging flow. It was assembled by a prior process (likely a `stage-guest.sh` run that installed the MACHDEBUGDEBUG kernel + mach.ko into a FreeBSD 15.0 image). **No SHA pin on the base image content** — it's identified only by its directory name + mtime.

### Step 2: stage-userland.sh (the overlay)

**Path**: `block-078-runtime-smoke/stage-userland.sh` (test infra, NOT product source).

Does NOT install or replace the kernel. Installs into the mounted root partition:
- **Alpha userland shared libraries** (from obj_root `block-075-alpha-final-obj/.../wip-rmxos/amd64.amd64/lib/*/`): libdispatch.so.5, libmach.so.5, libthr.so.3, libsys.so.7, libBlocksRuntime.so.0, liblaunch.so.5, libnotify.so.5, libosxsupport.so.5, libxpc.so.5, libjansson.so.4, libasl.so.1, + supporting libs.
- **Binaries**: notifyd, launchd, launchctl (from obj_root/usr.sbin/ + sbin/ + bin/).
- **Kernel module**: `mach.ko` from `obj_root/sys/modules/mach/` → `/boot/modules/mach.ko`.
- **Test infra**: block-078 probe binaries + plists + rc.local.
- **Cleanup**: removes stale nxplatform_phase* rc.d scripts; writes empty /etc/bootstrap.

### Step 3: run-guest.sh (the boot)

**Path**: `wip-gpt/scripts/bhyve/run-guest.sh`.
Boots via `doas bhyveload` + `doas bhyve -AHP -c 4 -m 8G -l com1,stdio -s 4:0,virtio-blk,$image`. Serial to stdio (captured). The guest boots the MACHDEBUGDEBUG kernel (per loader.conf), loads mach.ko, runs rc.local (the block-078 probe or the op-110 extended probe), then powers off.

## The three pinned inputs

### Input 1: base FreeBSD image rev

- **FreeBSD 15.0-RELEASE userland** (os-release) / **15.0-STABLE kernel** (strings).
- **Not a stock release** — a pre-staged rmxOS image with MACHDEBUGDEBUG kernel + mach.ko already installed.
- **How obtained**: prior `stage-guest.sh` run (the kernel/module installer at `wip-gpt/scripts/bhyve/stage-guest.sh`). The op-111 finding confirms "no buildworld completed" — the kernel was built by targeted `make buildkernel`, not a full buildworld.
- **Gap**: no content SHA pin on the base image; identified by directory name only.

### Input 2: overlay commit (alpha userland)

- **wip-rmxos alpha HEAD**: `e317099de3b1` ("include: add Apple overlay dirs to include mtree").
- **obj_root**: `block-075-alpha-final-obj/Users/me/wip-mach/wip-gpt/wip-rmxos/amd64.amd64`.
- This is the source commit whose build output (libs + binaries + mach.ko) stage-userland.sh copies into the image.
- **Note**: the obj_root was built by a prior buildworld/buildkernel cycle (the "block-075-alpha-final" in the name suggests a finalized alpha build at a specific commit).

### Input 3: kernel provenance

- **Source tree**: `freebsd-src-official-stable-15` @ git commit `f71260cf4c9e` ("mach: clean up immediate receive timeout"). Latest: `524d71df420e` ("mach: route dead-name notifications through ipc rights").
- **KERNCONF**: `MACHDEBUGDEBUG` (includes `COMPAT_MACH`, `DEBUG_LOCKS`, `THRWORKQ`, + `include GENERIC` which brings `KDTRACE_HOOKS`, `KDTRACE_FRAME`, `DDB_CTF`).
- **Build path**: `make buildkernel KERNCONF=MACHDEBUGDEBUG` → kernel obj at `official-stable15-mach-obj/.../sys/MACHDEBUGDEBUG`.
- **Installation into the image**: via `stage-guest.sh` (NOT stage-userland.sh). stage-guest.sh mounts the image + installs the kernel to `/boot/MACHDEBUGDEBUG/` + configures loader.conf + enables mach.ko.
- **mach patch**: `mach-stable15-port.patch` (108KB) applied to the FreeBSD source before the kernel build.

## The distributable-artifact gap

What the current model does vs what a distributable artifact (USB/ISO) needs:

| step | current model (in-place staging) | distributable artifact |
|---|---|---|
| kernel | pre-installed in base image (stage-guest.sh prior run) | `make buildkernel KERNCONF=MACHDEBUGDEBUG` from pinned source → `installkernel` |
| userland | selective lib-copy (stage-userland.sh copies ~15 libs + 3 binaries) | `make buildworld + installworld` from pinned alpha source → complete userland |
| mach.ko | copied from obj_root to /boot/modules/ | installed via `installkernel` (part of the kernel build) |
| loader.conf | pre-configured in base image | generated by `installkernel` + mach.ko loader entry |
| rc.conf | pre-configured (nxplatform phases disabled) | minimal config (launchd_enable, notifyd_enable) |
| test infra | block-078 probe + plists + rc.local | **none** (test infra is staging-only) |
| packaging | raw .img (dd-able to a virtio-blk, but not a USB/ISO) | `mkimg` (raw/USB) or `make-memstick` (bootable ISO) |
| reproducibility | **non-reproducible** (base image is a manual snapshot) | **reproducible** (build from source → install → package) |

**Key gap**: the current model cannot produce an image from source alone — it requires the pre-staged base image as a starting point. A distributable artifact requires a from-source build pipeline (`buildworld + buildkernel → installworld + installkernel → mkimg`), which is op-111's separate arc (bl-012).

## Summary for the follow-on Gatekeeper op (legs 2-4)

The staging model is **documented + inputs pinned** (first-hand). A third party could follow the in-place staging model (cp base → stage-userland → boot). But to produce a **distributable artifact**, they need:
1. A from-source build pipeline (kernel + userworld) — the buildworld/buildkernel path.
2. An install-to-image step (installkernel + installworld to a fresh UFS image).
3. A packaging step (mkimg for USB, or make-memstick for ISO).
4. A boot-config template (loader.conf + rc.conf + first-boot setup).

These are scoped for the Gatekeeper legs 2-4, executing against this audit as the spec.
