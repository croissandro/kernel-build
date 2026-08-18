# CroissAndro kernel build

This repository owns the Hyper-V x86-64 kernel configuration and Kleaf build
policy for CroissAndro. It contains neither Android Common Kernel (ACK) source
nor published kernel binaries.

The canonical kernel local manifest checks it out inside the ACK workspace:

```text
kernel/
├── build/kernel/          upstream Kleaf
├── common/                upstream ACK source
├── croissandro/           this repository
└── tools/bazel
```

The scripts also support the early-development layout where `kernel/` and
`kernel-build/` are siblings. The manifest-managed layout above is the release
model.

## Repository family

| Repository | Responsibility |
|---|---|
| [`manifest`](https://github.com/croissandro/manifest) | Adds CroissAndro projects to the AOSP and ACK workspaces |
| [`croissandro`](https://github.com/croissandro/croissandro) | Android product, board and device policy |
| [`kernel-build`](https://github.com/croissandro/kernel-build) | Hyper-V kernel configuration and Kleaf build logic — this repository |
| [`kernel-prebuilts`](https://github.com/croissandro/kernel-prebuilts) | Reviewed kernel artifacts consumed by AOSP |

## Current product increment

The initial target supports **PI-1: kernel boot**. It is a full x86-64
GKI-derived source build because Hyper-V boot drivers change the bootable
kernel configuration and cannot be layered onto an already-built GKI image as
device modules.

Boot-critical drivers are built into `bzImage` until CroissAndro owns a tested
initramfs and module-partition contract. The fragment enables:

- Hyper-V core, timer, and VMBus;
- StorVSC and NetVSC;
- Hyper-V PCI frontend and IRQ/IOMMU handling;
- synthetic keyboard and HID mouse;
- Hyper-V sockets, guest utilities, and dynamic-memory ballooning.

It intentionally excludes Cuttlefish/Goldfish drivers, virtio-gpu,
MANA/Azure accelerated networking, Hyper-V root-partition mode, and VTL mode.
Graphics and complete Android boot integration belong to later increments.

## Initialize the ACK workspace

Use [`kernel-manifest.xml`](https://github.com/croissandro/manifest/blob/main/kernel-manifest.xml)
from the manifest repository. It places this project at `kernel/croissandro`.
The checked-out ACK revision and compiler are the source of truth for a build.

The current `common-android-mainline` checkout is exploratory. Pin a compatible
ACK release branch and reviewed revisions before publishing artifacts.

## Validate and build

From `kernel/croissandro`:

```sh
./check-config.sh
./build.sh
```

`check-config.sh` merges the x86-64 GKI defconfig with
[`config/hyperv_x86_64.fragment`](config/hyperv_x86_64.fragment), runs
`olddefconfig`, and verifies that Kconfig resolved every requested value
exactly.

`build.sh` invokes the Kleaf distribution target. In the canonical workspace
it is equivalent to:

```sh
tools/bazel run //croissandro:croissandro_x86_64_dist
```

Choose an explicit distribution directory when preparing a publication:

```sh
DIST_DIR=/absolute/path/to/dist ./build.sh
```

Important outputs include:

- `bzImage` — the x86-64 kernel image;
- `vmlinux` and `System.map` — debugging and symbolization;
- `vmlinux.symvers` — symbol/version information;
- `modules.builtin` and `modules.builtin.modinfo` — built-in inventory.

If the build reports a missing manifest project, sync that project from the
kernel workspace. For example:

```sh
repo sync -c prebuilts/clang/host/linux-x86
```

## Configuration policy

Edit `config/hyperv_x86_64.fragment`, not upstream `gki_defconfig`. Kleaf uses
it as a checked post-defconfig fragment, so an unavailable symbol or unmet
dependency fails instead of being silently discarded.

Add an option only when a product increment has a consumer and a boot/runtime
test. Keep optional drivers out of the kernel until module loading and the
relevant Android or host interface are defined.

## Publication contract

Do not make the Android device tree consume `kernel/out` directly. After
config, boot, and compatibility validation:

1. record the ACK branch and commit;
2. record the `kernel-build` commit and compiler identity;
3. copy the reviewed distribution into `kernel-prebuilts`;
4. generate checksums and provenance metadata;
5. pin the prebuilt revision in the AOSP manifest.

The AOSP overlay currently mounts `kernel-prebuilts` under a `6.18` namespace.
Do not publish a mainline 7.x build into that namespace; align the ACK branch
and publication path deliberately before PI-1 integration.

## References

- [Build Android kernels](https://source.android.com/docs/setup/build/building-kernels)
- [Kleaf defconfig fragments](https://android.googlesource.com/kernel/build/+/refs/heads/main-kernel/kleaf/docs/kernel_config.md#defconfig-fragments)
