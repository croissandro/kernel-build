#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ -n ${KERNEL_WORKSPACE:-} ]]; then
  kernel_workspace=${KERNEL_WORKSPACE}
elif [[ -x ${repo_dir}/../tools/bazel ]]; then
  kernel_workspace=${repo_dir}/..
else
  kernel_workspace=${repo_dir}/../kernel
fi
common_dir=$(realpath "${kernel_workspace}")/common
fragment=${repo_dir}/config/hyperv_x86_64.fragment

if [[ ! -f ${common_dir}/arch/x86/configs/gki_defconfig ]]; then
  echo "error: missing x86_64 GKI defconfig under ${common_dir}" >&2
  exit 1
fi

work_dir=$(mktemp -d)
trap 'rm -rf -- "${work_dir}"' EXIT

cp "${common_dir}/arch/x86/configs/gki_defconfig" "${work_dir}/.config"
"${common_dir}/scripts/kconfig/merge_config.sh" -m -O "${work_dir}" \
  "${work_dir}/.config" "${fragment}" >/dev/null
make -s -C "${common_dir}" O="${work_dir}" ARCH=x86_64 olddefconfig

failed=false
while IFS= read -r requirement; do
  [[ ${requirement} =~ ^CONFIG_[A-Za-z0-9_]+= ]] || continue
  symbol=${requirement%%=*}
  actual=$(grep -E "^${symbol}=" "${work_dir}/.config" || true)
  if [[ ${actual} != "${requirement}" ]]; then
    echo "error: requested '${requirement}', resolved '${actual:-not set}'" >&2
    failed=true
  fi
done < "${fragment}"

if ${failed}; then
  exit 1
fi

echo "Hyper-V config validation passed"
