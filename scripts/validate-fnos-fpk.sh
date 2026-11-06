#!/usr/bin/env bash
# 校验飞牛 FPK 源目录结构（不需要 fnpack、不产出包），CI 与本地都可跑。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FPK_DIR="${ROOT}/packaging/fnos/caldav-free"

required_files=(
    manifest
    ICON.PNG
    ICON_256.PNG
    config/privilege
    config/resource
    app/ui/config
    app/ui/images/icon_64.png
    app/ui/images/icon_256.png
    wizard/install
    wizard/uninstall
    cmd/common.sh
    cmd/main
    cmd/install_init
    cmd/install_callback
    cmd/upgrade_init
    cmd/upgrade_callback
    cmd/uninstall_init
    cmd/uninstall_callback
    cmd/config_init
    cmd/config_callback
)

required_dirs=(
    app/server
    cmd
    config
    wizard
)

fail=0
for f in "${required_files[@]}"; do
    if [ ! -f "${FPK_DIR}/${f}" ]; then
        echo "MISSING file: ${f}" >&2
        fail=1
    fi
done

for d in "${required_dirs[@]}"; do
    if [ ! -d "${FPK_DIR}/${d}" ]; then
        echo "MISSING dir: ${d}" >&2
        fail=1
    fi
done

for key in appname version display_name service_port source platform; do
    if ! grep -qE "^${key}=" "${FPK_DIR}/manifest"; then
        echo "MISSING manifest key: ${key}" >&2
        fail=1
    fi
done

# 原生应用不应夹带 docker 模板
if [ -d "${FPK_DIR}/app/docker" ]; then
    echo "ERROR: 原生应用不应包含 app/docker" >&2
    fail=1
fi

# 生命周期脚本必须是可执行 + bash 语法正确
for script in "${FPK_DIR}/cmd/"*; do
    [ -f "${script}" ] || continue
    # common.sh 是被 source 的库，不需要可执行位
    case "${script}" in
        *.sh) ;;
        *)
            if [ ! -x "${script}" ]; then
                echo "WARN: 未设置可执行位：${script}" >&2
            fi
            ;;
    esac
    if ! bash -n "${script}" 2>/dev/null; then
        echo "ERROR: bash 语法错误：${script}" >&2
        fail=1
    fi
done

# JSON 配置必须是合法 JSON
for json in "${FPK_DIR}/config/privilege" "${FPK_DIR}/config/resource" \
            "${FPK_DIR}/app/ui/config" "${FPK_DIR}/wizard/install" "${FPK_DIR}/wizard/uninstall"; do
    [ -f "${json}" ] || continue
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${json}" 2>/dev/null; then
        echo "ERROR: 非法 JSON：${json}" >&2
        fail=1
    fi
done

if [ "${fail}" -ne 0 ]; then
    exit 1
fi

echo "FPK 结构校验通过：${FPK_DIR}"
