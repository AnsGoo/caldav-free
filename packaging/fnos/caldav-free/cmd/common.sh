#!/bin/bash
# caldav-free（历记）飞牛 fnOS 生命周期脚本公共函数。
#
# 所有路径都从 TRIM_* 环境变量解析，切勿硬编码安装位置。

APP_NAME="caldav-free"
APP_USER="caldavfree"
APP_GROUP="caldavfree"
BINARY_NAME="caldav-free"
DEFAULT_PORT="5232"
LOG_FILE=""

app_var_dir() { echo "${TRIM_PKGVAR:-/var/apps/${APP_NAME}/var}"; }
app_etc_dir() { echo "${TRIM_PKGETC:-/var/apps/${APP_NAME}/etc}"; }
app_dest_dir() { echo "${TRIM_APPDEST:-/var/apps/${APP_NAME}/target}"; }

# 生命周期日志（安装/升级/启停），与业务日志分开，便于排查。
init_logging() {
    local var_dir
    var_dir="$(app_var_dir)"
    if ! mkdir -p "${var_dir}" 2>/dev/null; then
        var_dir="/tmp/${APP_NAME}-var"
        mkdir -p "${var_dir}" 2>/dev/null || true
    fi
    LOG_FILE="${var_dir}/install.log"
}

log_msg() {
    [ -n "${LOG_FILE}" ] || init_logging
    { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "${LOG_FILE}"; } 2>/dev/null || true
}

# 写入 TRIM_TEMP_LOGFILE 后 exit 1，fnOS 会把内容展示给用户。
fail_with_message() {
    local msg="$1"
    if [ -n "${TRIM_TEMP_LOGFILE:-}" ]; then
        echo "${msg}" > "${TRIM_TEMP_LOGFILE}"
    fi
    log_msg "ERROR: ${msg}"
    exit 1
}

# fnOS 调起生命周期脚本时环境里可能没有 PATH，与系统守护进程保持一致。
export_fnos_path() {
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
}

service_port() {
    echo "${TRIM_SERVICE_PORT:-${DEFAULT_PORT}}"
}

wait_for_port() {
    local port="$1" i=0
    while [ "${i}" -lt 60 ]; do
        if (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null; then
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# 安装脚本通常以 root 运行，创建出来的文件需要交还给应用用户，否则 run-as package 读不到。
chown_app_paths() {
    if id -u "${APP_USER}" >/dev/null 2>&1; then
        chown -R "${APP_USER}:${APP_GROUP}" "$(app_etc_dir)" "$(app_var_dir)" 2>/dev/null || true
    fi
}
