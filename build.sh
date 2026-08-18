#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ -n ${KERNEL_WORKSPACE:-} ]]; then
  kernel_workspace=${KERNEL_WORKSPACE}
elif [[ -x ${repo_dir}/../tools/bazel ]]; then
  # Canonical repo-manifest layout: kernel/<project path>.
  kernel_workspace=${repo_dir}/..
else
  # Local development layout: kernel and kernel-build are siblings.
  kernel_workspace=${repo_dir}/../kernel
fi
kernel_workspace=$(realpath "${kernel_workspace}")

if [[ ! -x ${kernel_workspace}/tools/bazel ]]; then
  echo "error: ${kernel_workspace} is not a synced ACK/Kleaf workspace" >&2
  echo "set KERNEL_WORKSPACE to the kernel checkout root" >&2
  exit 1
fi

required_projects=(
  build/kernel
  common
  prebuilts/build-tools
  prebuilts/clang/host/linux-x86
)
for project in "${required_projects[@]}"; do
  if [[ ! -d ${kernel_workspace}/${project} ]]; then
    echo "error: kernel workspace project '${project}' is missing" >&2
    echo "run: (cd ${kernel_workspace} && repo sync ${project})" >&2
    exit 1
  fi
done

relative_repo=$(realpath --relative-to="${kernel_workspace}" "${repo_dir}")
bazel_args=()

if [[ ${relative_repo} == .. || ${relative_repo} == ../* ]]; then
  # Support the development layout where kernel-build and kernel are siblings.
  package_parent=$(dirname "${repo_dir}")
  package_name=$(basename "${repo_dir}")
  bazel_args+=("--package_path=%workspace%:${package_parent}")
else
  package_name=${relative_repo}
fi

target="//${package_name}:croissandro_x86_64_dist"

echo "ACK workspace: ${kernel_workspace}"
echo "Kleaf target:  ${target}"

cd "${kernel_workspace}"
if [[ -n ${DIST_DIR:-} ]]; then
  exec tools/bazel run "${bazel_args[@]}" "${target}" -- \
    --destdir="$(realpath -m "${DIST_DIR}")"
fi
exec tools/bazel run "${bazel_args[@]}" "${target}"
