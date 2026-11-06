#!/usr/bin/env bash
# 打包 caldav-free（历记）为飞牛 fnOS 原生 FPK。
#
# 用法：
#   scripts/build-fnos-fpk.sh              # 打 amd64
#   scripts/build-fnos-fpk.sh amd64
#   scripts/build-fnos-fpk.sh arm64
#   scripts/build-fnos-fpk.sh all
#
# 环境变量：
#   FPK_VERSION=2.7.1   覆盖 manifest 里的 version（CI 从 tag 注入），默认取 manifest
#   FNPAC_BIN=/path     指定官方 fnpack；未指定时若 PATH 里有 fnpack 则用 fnpack，
#                       否则退化为等价的 tar 打包（结构一致，macOS 本地也能出包）
#   SKIP_WEB_BUILD=1    跳过前端构建（复用已有 internal/web/dist）
#   FPK_GOOS=darwin     仅供本机验证冒烟脚本，正式产物固定 linux
#
# 产物：packaging/fnos/dist/caldav-free-<version>-<amd64|arm64>.fpk
# 注意：版本号/平台只在暂存目录里改写，packaging/fnos/caldav-free/manifest 不会被污染。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FPK_APPNAME="caldav-free"
FPK_DIR="${ROOT}/packaging/fnos/${FPK_APPNAME}"
OUT_DIR="${ROOT}/packaging/fnos/dist"
TARGET="${1:-amd64}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 未安装或不在 PATH 中"
}

goarch_for() {
    case "$1" in
        amd64|x86) echo amd64 ;;
        arm64|arm) echo arm64 ;;
        *) die "不支持的架构：$1（可用 amd64 / arm64 / all）" ;;
    esac
}

platform_for() {
    case "$1" in
        amd64|x86) echo x86 ;;
        arm64|arm) echo arm ;;
        *) die "不支持的架构：$1" ;;
    esac
}

manifest_version() {
    grep -E '^version=' "${FPK_DIR}/manifest" | head -1 | cut -d= -f2- | tr -d '[:space:]'
}

preflight() {
    need_cmd go
    need_cmd tar
    for f in manifest ICON.PNG ICON_256.PNG config/privilege config/resource \
             app/ui/config app/ui/images/icon_64.png app/ui/images/icon_256.png \
             wizard/install cmd/main; do
        [ -e "${FPK_DIR}/${f}" ] || die "FPK 结构缺文件：${f}"
    done
}

build_web() {
    if [ -n "${SKIP_WEB_BUILD:-}" ]; then
        echo "==> 跳过前端构建（SKIP_WEB_BUILD=1）"
        [ -d "${ROOT}/internal/web/dist" ] || die "internal/web/dist 不存在，无法跳过前端构建"
        return 0
    fi
    need_cmd npm
    echo "==> 构建前端（web/ → internal/web/dist）"
    (
        cd "${ROOT}/web"
        if [ ! -d node_modules ]; then
            npm ci
        fi
        npm run build
    ) || die "前端构建失败，可先手动执行：cd web && npm ci && npm run build"
}

build_binary() {
    local arch="$1" goarch goos
    goarch="$(goarch_for "${arch}")"
    goos="${FPK_GOOS:-linux}"
    echo "==> 编译服务端 GOOS=${goos} GOARCH=${goarch}（纯 Go SQLite，无需 CGO）"
    mkdir -p "${FPK_DIR}/app/server"
    (
        cd "${ROOT}"
        CGO_ENABLED=0 GOOS="${goos}" GOARCH="${goarch}" GOFLAGS=-trimpath \
            go build -ldflags="-s -w" -o "${FPK_DIR}/app/server/caldav-free" ./cmd/caldav-free
    ) || die "go build 失败"
    chmod +x "${FPK_DIR}/app/server/caldav-free"
}

md5_of() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | cut -d' ' -f1
    else
        md5 -q "$1"
    fi
}

use_fnpack() {
    if [ -n "${FNPAC_BIN:-}" ] && [ -x "${FNPAC_BIN}" ]; then
        return 0
    fi
    if command -v fnpack >/dev/null 2>&1; then
        FNPAC_BIN="$(command -v fnpack)"
        return 0
    fi
    return 1
}

# 把 packaging/fnos/<app>/ 组装成一份可打包的暂存目录：
#   manifest（已改写 version/platform/checksum）+ app.tgz + cmd/ config/ wizard/ ICON*
stage_package() {
    local work="$1" version="$2" platform="$3"

    mkdir -p "${work}"
    cp -R "${FPK_DIR}/cmd" "${FPK_DIR}/config" "${FPK_DIR}/wizard" "${work}/"
    cp "${FPK_DIR}/ICON.PNG" "${FPK_DIR}/ICON_256.PNG" "${work}/"
    chmod +x "${work}/cmd/"*

    echo "==> 打包载荷 app.tgz（app/ → 安装后的 target/）"
    # COPYFILE_DISABLE 避免 macOS 的 ._ 资源分叉文件混进包里
    COPYFILE_DISABLE=1 tar -czf "${work}/app.tgz" -C "${FPK_DIR}/app" .

    sed -e "s|^version=.*|version=${version}|" \
        -e "s|^platform=.*|platform=${platform}|" \
        -e "/^checksum=/d" \
        "${FPK_DIR}/manifest" > "${work}/manifest"
    echo "checksum=$(md5_of "${work}/app.tgz")" >> "${work}/manifest"
}

pack_fpk() {
    local arch="$1" version="$2" platform out work
    platform="$(platform_for "${arch}")"
    out="${OUT_DIR}/${FPK_APPNAME}-${version}-${arch}.fpk"
    mkdir -p "${OUT_DIR}"

    work="$(mktemp -d)"
    stage_package "${work}/pkg" "${version}" "${platform}"

    if use_fnpack; then
        echo "==> 使用 fnpack 打包：${FNPAC_BIN}"
        (
            cd "${work}/pkg"
            "${FNPAC_BIN}" build
            produced="$(ls -1 ./*.fpk 2>/dev/null | head -1 || true)"
            [ -n "${produced}" ] || die "fnpack 执行成功但没有产出 .fpk"
            mv -f "${produced}" "${out}"
        )
    else
        echo "==> 未找到 fnpack，使用等价 tar 打包（结构与 fnpack 一致）"
        (
            cd "${work}/pkg"
            COPYFILE_DISABLE=1 tar -czf "${out}" ./*
        )
    fi

    [ -f "${out}" ] || die "打包失败，未生成 ${out}"
    rm -rf "${work}"
    echo "==> 完成：${out} ($(du -h "${out}" | awk '{print $1}'))"
}

build_one() {
    local arch="$1" version="${FPK_VERSION:-}"
    if [ -z "${version}" ]; then
        version="$(manifest_version)"
    fi
    echo "==> 目标架构：${arch}，版本：${version}"
    build_binary "${arch}"
    pack_fpk "${arch}" "${version}"
}

preflight
build_web

case "${TARGET}" in
    all)
        build_one amd64
        build_one arm64
        ;;
    amd64|x86|arm64|arm)
        build_one "${TARGET}"
        ;;
    *)
        die "用法：$0 [amd64|arm64|all]"
        ;;
esac
