#!/usr/bin/env bash
# 对打包好的 .fpk 做一次真实安装冒烟测试（在 Linux runner 上跑）。
#
# 做法：把 fpk 解到临时目录，按 fnOS 的方式布置 TRIM_* 环境变量，
# 依次执行 install_init / install_callback / main start|status|stop，
# 并确认端口能响应、数据库已创建、管理员账号已初始化。
#
# 用法：scripts/smoke-test-fpk.sh <path-to-fpk>

set -euo pipefail

FPK="${1:?用法: $0 <path-to-fpk>}"
[ -f "${FPK}" ] || { echo "找不到 fpk：${FPK}" >&2; exit 1; }

WORK="$(mktemp -d)"
PORT="${SMOKE_PORT:-5299}"
cleanup() {
    if [ -n "${TRIM_PKGVAR:-}" ] && [ -f "${TRIM_PKGVAR}/caldav-free.pid" ]; then
        bash "${WORK}/cmd/main" stop >/dev/null 2>&1 || true
    fi
    rm -rf "${WORK}"
}
trap cleanup EXIT

echo "==> 解包 ${FPK}"
tar -xzf "${FPK}" -C "${WORK}"

for f in manifest app.tgz cmd/main config/privilege wizard/install ICON.PNG ICON_256.PNG; do
    [ -e "${WORK}/${f}" ] || { echo "fpk 缺文件：${f}" >&2; exit 1; }
done

mkdir -p "${WORK}/target" "${WORK}/var" "${WORK}/etc"
tar -xzf "${WORK}/app.tgz" -C "${WORK}/target"
[ -x "${WORK}/target/server/caldav-free" ] || { echo "载荷缺少可执行文件 server/caldav-free" >&2; exit 1; }

export TRIM_APPDEST="${WORK}/target"
export TRIM_PKGETC="${WORK}/etc"
export TRIM_PKGVAR="${WORK}/var"
export TRIM_APPNAME="caldav-free"
export TRIM_SERVICE_PORT="${PORT}"
export TRIM_TEMP_LOGFILE="${WORK}/trim-temp.log"
export wizard_admin_username="admin"
export wizard_admin_password="SmokeTest#2026"

echo "==> install_init"
bash "${WORK}/cmd/install_init"

echo "==> install_callback（写入管理员口令）"
bash "${WORK}/cmd/install_callback"
[ -s "${WORK}/etc/admin.env" ] || { echo "admin.env 未生成" >&2; exit 1; }

echo "==> main start"
bash "${WORK}/cmd/main" start

echo "==> 探测 http://127.0.0.1:${PORT}/"
code="$(curl -s -o "${WORK}/index.html" -w '%{http_code}' --max-time 10 "http://127.0.0.1:${PORT}/" || true)"
if [ "${code}" != "200" ]; then
    echo "首页返回 ${code}，服务日志：" >&2
    tail -n 40 "${WORK}/var/caldav-free.log" >&2 || true
    exit 1
fi

echo "==> main status"
bash "${WORK}/cmd/main" status

[ -f "${WORK}/var/caldav-free.db" ] || { echo "数据库未创建" >&2; tail -n 40 "${WORK}/var/caldav-free.log" >&2; exit 1; }
if ! grep -qi "created initial admin account" "${WORK}/var/caldav-free.log"; then
    echo "日志里没有管理员初始化记录：" >&2
    tail -n 40 "${WORK}/var/caldav-free.log" >&2
    exit 1
fi

echo "==> main stop"
bash "${WORK}/cmd/main" stop
if bash "${WORK}/cmd/main" status; then
    echo "停止后 status 仍返回 0" >&2
    exit 1
else
    rc=$?
    if [ "${rc}" -ne 3 ]; then
        echo "停止后 status 应返回 3，实际 ${rc}" >&2
        exit 1
    fi
fi

echo "冒烟测试通过：首页 200、数据库已创建、管理员已初始化、停止后 status=3"
