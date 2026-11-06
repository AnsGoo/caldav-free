#!/usr/bin/env bash
# 对已构建的 unsigned HAP 做本地签名。
#
# 前置：mobile/ohos/signature/ 下有
#   caldav-free.p12   密钥库（本地生成，勿提交）
#   *.cer             应用证书（AGC 上传 CSR 后下载）
#   *.p7b             Profile（AGC 创建 Profile 后下载）
#
# 用法：
#   ./mobile/scripts/sign-ohos.sh                 # 只签名
#   ./mobile/scripts/sign-ohos.sh --install       # 签名并装到当前设备
#   ./mobile/scripts/sign-ohos.sh --check         # 只检查素材是否齐备

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIG_DIR="$ROOT/ohos/signature"
OUT_DIR="$ROOT/ohos/entry/build/default/outputs/default"

KEY_ALIAS="caldav-free-key"
SIGN_ALG="SHA256withECDSA"

# 口令来源：环境变量 > signature/.pwd（已 gitignore）> 报错。
# 绝不要把口令写死在脚本里，mobile/scripts/ 是要提交的。
KEY_PWD="${CALDAV_KEY_PWD:-}"
STORE_PWD="${CALDAV_STORE_PWD:-}"
PWD_FILE="$SIG_DIR/.pwd"
if [ -z "$KEY_PWD" ] || [ -z "$STORE_PWD" ]; then
  if [ -f "$PWD_FILE" ]; then
    file_pwd="$(tr -d '\r\n' < "$PWD_FILE")"
    KEY_PWD="${KEY_PWD:-$file_pwd}"
    STORE_PWD="${STORE_PWD:-$file_pwd}"
  fi
fi
COMPAT_VERSION="26"

DEVECO="/Applications/DevEco-Studio.app/Contents"
JAVA="$DEVECO/jbr/Contents/Home/bin/java"
HDC="$DEVECO/sdk/default/openharmony/toolchains/hdc"
TOOL="$DEVECO/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"

info()  { printf '\033[36m[sign]\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m[ok ]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*"; }
die()   { printf '\033[31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 定位素材 ----------
first_match() { ls "$1"/*"$2" 2>/dev/null | head -1 || true; }

# AGC 下载的文件通常落在 ~/Downloads，文件名带时间戳。缺什么就从那里捞最新的一个。
adopt_from_downloads() {
  ext="$1"
  [ -d "$HOME/Downloads" ] || return 0
  cand="$(ls -t "$HOME/Downloads"/*"$ext" 2>/dev/null | head -1 || true)"
  [ -n "$cand" ] && [ -f "$cand" ] || return 0
  cp "$cand" "$SIG_DIR/"
  printf '\033[33m[adopt]\033[0m 已从下载目录取用 %s\n' "$(basename "$cand")"
}

P12="$SIG_DIR/caldav-free.p12"
if [ -z "$(first_match "$SIG_DIR" ".cer")" ]; then adopt_from_downloads ".cer"; fi
if [ -z "$(first_match "$SIG_DIR" ".p7b")" ]; then adopt_from_downloads ".p7b"; fi

CER="$(first_match "$SIG_DIR" ".cer")"
P7B="$(first_match "$SIG_DIR" ".p7b")"

check_only=0
do_install=0
for a in "$@"; do
  case "$a" in
    --check)   check_only=1 ;;
    --install) do_install=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "未知参数：$a" ;;
  esac
done

echo
info "密钥库   : ${P12#$ROOT/}"
info "证书     : ${CER:-<缺失>}"
info "Profile  : ${P7B:-<缺失>}"
echo

[ -f "$P12" ] || die "缺少密钥库 $P12。先生成：见 docs/鸿蒙签名.md 第 1 步"
[ -f "$JAVA" ] || die "找不到 DevEco 自带 JDK：$JAVA"
[ -f "$TOOL" ] || die "找不到 hap-sign-tool.jar：$TOOL"
[ -n "$KEY_PWD" ] || die "缺少密钥库口令：export CALDAV_KEY_PWD=... 或写入 $PWD_FILE"

if "$DEVECO/jbr/Contents/Home/bin/keytool" -list -keystore "$P12" -storetype PKCS12 \
     -storepass "$KEY_PWD" >/dev/null 2>&1; then
  ok "密钥库口令校验通过"
else
  die "密钥库口令不匹配（检查 $PWD_FILE 或 CALDAV_KEY_PWD）"
fi

missing=0
[ -n "$CER" ] && [ -f "$CER" ] || { warn "缺少 .cer  —— 去 AGC 上传 CSR 换证书"; missing=1; }
[ -n "$P7B" ] && [ -f "$P7B" ] || { warn "缺少 .p7b  —— 去 AGC 创建 Profile（要勾 ACL 权限）"; missing=1; }

if [ "$missing" = "1" ]; then
  warn "素材不齐，只能做检查。CSR 在 $SIG_DIR/caldav-free.csr"
  exit 2
fi
[ "$check_only" = "1" ] && { ok "素材齐备，可以签名"; exit 0; }

# ---------- 找 unsigned HAP ----------
UNSIGNED="$OUT_DIR/entry-default-unsigned.hap"
if [ ! -f "$UNSIGNED" ]; then
  # 兼容 hvigor 不同产物命名
  UNSIGNED="$(ls "$OUT_DIR"/*.hap 2>/dev/null | grep -v signed | head -1 || true)"
fi
[ -n "$UNSIGNED" ] && [ -f "$UNSIGNED" ] || die "找不到 HAP，先跑 ./mobile/scripts/build-ohos.sh --fast"

SIGNED="$OUT_DIR/entry-default-signed.hap"
info "输入     : $(basename "$UNSIGNED") ($(du -h "$UNSIGNED" | cut -f1))"

# ---------- 签名 ----------
"$JAVA" -jar "$TOOL" sign-app \
  -mode localSign \
  -keyAlias "$KEY_ALIAS" \
  -keyPwd "$KEY_PWD" \
  -appCertFile "$CER" \
  -profileFile "$P7B" \
  -profileSigned 1 \
  -inFile "$UNSIGNED" \
  -signAlg "$SIGN_ALG" \
  -keystoreFile "$P12" \
  -keystorePwd "$STORE_PWD" \
  -outFile "$SIGNED" \
  -compatibleVersion "$COMPAT_VERSION" \
  -signCode 1 2>&1 | tail -5

[ -f "$SIGNED" ] || die "签名失败，没有产出 $SIGNED"
ok "已签名: ${SIGNED#$ROOT/} ($(du -h "$SIGNED" | cut -f1))"

# ---------- 校验 ----------
if "$JAVA" -jar "$TOOL" verify-app -inFile "$SIGNED" -outCertChain /tmp/caldav-chain.cer -outProfile /tmp/caldav-profile.p7b >/dev/null 2>&1; then
  ok "签名校验通过"
else
  warn "verify-app 未通过（部分 SDK 版本对 debug 证书校验宽松，可继续安装验证）"
fi

# ---------- 安装 ----------
if [ "$do_install" = "1" ]; then
  [ -x "$HDC" ] || die "找不到 hdc：$HDC"
  TARGET="$("$HDC" list targets 2>/dev/null | head -1)"
  [ -n "$TARGET" ] && [ "$TARGET" != "[Empty]" ] || die "没有设备连接，先启动模拟器或用 hdc 连真机"
  info "安装到 $TARGET ..."
  "$HDC" -t "$TARGET" install -r "$SIGNED"
  "$HDC" -t "$TARGET" shell aa force-stop com.caldavfree.caldav_free || true
  "$HDC" -t "$TARGET" shell aa start -a EntryAbility -b com.caldavfree.caldav_free
  ok "已启动"
fi
