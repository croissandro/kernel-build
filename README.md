# CroissAndro kernel build

This repository owns the CroissAndro kernel **configuration and build policy**.
It does not contain Linux source and it does not contain released binaries.

The source checkout is an Android Common Kernel (ACK) workspace, while built
artifacts are published separately. The canonical `repo` layout is:

```text
croissandro/
├── kernel/                 ACK repo workspace
│   ├── build/kernel/
│   ├── common/
│   ├── croissandro/        this Git repository
│   └── tools/bazel
└── kernel-prebuilts/       versioned artifacts consumed by the AOSP product
```

During initial development this repository may remain beside `kernel/` as
`kernel-build/`. The scripts support that layout through Bazel's package path,
but a pinned kernel manifest should eventually place it at `kernel/croissandro`.

## Scope

The initial target is an x86_64 Android GKI-derived kernel that can reach a
diagnostic userspace as a normal Hyper-V guest. Hyper-V boot-critical drivers
are built into `bzImage`; PI-1 must not depend on a vendor module partition or
an early userspace module loader.

The fragment enables:

- Hyper-V core, timer and VMBus support;
- StorVSC for the root/block device;
- NetVSC for the synthetic network adapter;
- Hyper-V PCI frontend and IRQ/IOMMU handling;
- Hyper-V keyboard and HID mouse input;
- Hyper-V sockets for a future host/guest control transport;
- guest utilities and dynamic-memory ballooning.

It intentionally does not enable Cuttlefish/Goldfish, virtio-gpu, MANA/Azure
accelerated networking, Hyper-V root-partition mode, or experimental VTL mode.
Graphics and Android boot-image integration are later product increments.

## Prerequisites

Initialize and sync an ACK workspace with Kleaf and the prebuilt toolchains.
Follow the AOSP kernel guide and use `repo` to fetch the sources, build tools,
and pinned compiler together. In the canonical layout:

```shell
test -x ../tools/bazel
test -f ../common/arch/x86/configs/gki_defconfig
```

The kernel manifest project entry for this repository should use a path such
as `croissandro`; keep the Android platform device repository and binary
prebuilt repository out of the kernel source checkout.

For example, a kernel-workspace local manifest can contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="croissandro-github" fetch="https://github.com/" />
  <project
      name="croissandro/kernel-build.git"
      path="croissandro"
      remote="croissandro-github"
      revision="main" />
</manifest>
```

For reproducible builds, replace `main` with a reviewed tag or commit in the
release manifest.

The checked-out ACK revision is the source of truth. Keep it pinned in the
kernel manifest; do not silently build whatever happens to be at the tip of
`android-mainline` for a published release.

## Build

From this repository:

```shell
./build.sh
```

Override the ACK checkout in the sibling development layout when necessary:

```shell
KERNEL_WORKSPACE=/path/to/kernel ./build.sh
```

The script invokes the documented Kleaf `*_dist` pattern. In the canonical
layout this is equivalent to:

```shell
tools/bazel run //croissandro:croissandro_x86_64_dist
```

Select an explicit distribution directory using the same `--destdir` contract
shown in the official guide:

```shell
DIST_DIR=/path/to/dist ./build.sh
```

Without `DIST_DIR`, the sibling layout writes the distribution to:

```text
../kernel/out/croissandro_x86_64/dist/
```

Important outputs are:

- `bzImage` — kernel image later packaged by the Android device repository;
- `vmlinux` and `System.map` — debugging and symbolization;
- `vmlinux.symvers` — kernel symbol/version information;
- `modules.builtin` and `modules.builtin.modinfo` — built-in driver inventory.

Run the configuration checker without compiling the kernel:

```shell
./check-config.sh
```

It merges the x86_64 GKI defconfig with the CroissAndro fragment, resolves
Kconfig dependencies with `olddefconfig`, and verifies every requested value.

## Configuration policy

Edit [`config/hyperv_x86_64.fragment`](config/hyperv_x86_64.fragment), not the
ACK `gki_defconfig`. Kleaf applies it as a checked post-defconfig fragment, so
an unavailable symbol or an unmet dependency fails the build instead of being
quietly dropped.

Keep boot-path drivers built in (`=y`) until the Android product owns a tested
initramfs and module-partition contract. Add optional devices only when a
product increment has a consumer and a boot/runtime test.

## Publishing and AOSP integration

Do not make the AOSP device tree consume `kernel/out` directly. After boot and
config validation, copy a reviewed distribution into `kernel-prebuilts`,
record the ACK and `kernel-build` commits, and make the device product consume
that immutable prebuilt. This keeps normal AOSP builds hermetic and avoids
rebuilding the kernel during every `m` invocation.

PI-1 should introduce the kernel plus a diagnostic ramdisk/boot image. Only
then should `TARGET_NO_KERNEL := true` be removed from the device BoardConfig.

## References

- [Build kernels](https://source.android.com/docs/setup/build/building-kernels)
- [Kleaf defconfig fragments](https://android.googlesource.com/kernel/build/+/refs/heads/main-kernel/kleaf/docs/kernel_config.md#defconfig-fragments)
