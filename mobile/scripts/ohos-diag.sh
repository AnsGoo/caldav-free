#!/usr/bin/env bash
# 秒级定位鸿蒙 HAP 构建失败。
#
# 背景：`flutter build hap` 失败时只会打印
#   ProcessException: The command failed with exit code 255
# 真正的报错全在 hvigor 的 debug 日志里：几百 KB、几百条 WARN，
# 错误通常埋在第 4900 行之后，而且同一段错误会重复打印 3 遍。
# 本脚本把最后一次构建窗口切出来，去重后只留人话。
#
# 用法：
#   ./scripts/ohos-diag.sh              # 诊断最近一次构建
#   ./scripts/ohos-diag.sh --history    # 附上每次构建的耗时与死因
#   ./scripts/ohos-diag.sh -v           # 连 WARN 也打出来
#   ./scripts/ohos-diag.sh <log路径>
set -uo pipefail

cd "$(dirname "$0")/.."

SHOW_HISTORY=0
SHOW_WARN=0
LOG=""
for arg in "$@"; do
  case "$arg" in
    --history) SHOW_HISTORY=1 ;;
    -v|--verbose) SHOW_WARN=1 ;;
    -*) echo "未知参数：$arg" >&2; exit 2 ;;
    *) LOG="$arg" ;;
  esac
done
LOG="${LOG:-ohos/.hvigor/outputs/build-logs/build.log}"

if [ ! -f "$LOG" ]; then
  printf '找不到构建日志：%s\n先跑一次 flutter build hap --debug --target-platform ohos-arm64\n' "$LOG" >&2
  exit 2
fi

TMP="$(mktemp -t ohosdiag)"
trap 'rm -f "$TMP".*' EXIT

# ---- 单次扫描：切窗口 + 归因 + 错误去重 + 历史摘要（避免 BSD grep 反复扫大文件）----
awk -v win="$TMP.win" -v meta="$TMP.meta" -v errf="$TMP.err" -v hist="$TMP.hist" -v base="$(pwd)/" '
  function ts(l,   s) { if (match(l, /T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) return substr(l, RSTART + 1, 8); return "" }
  {
    line = $0
    sub(/\033\[[0-9;]*[A-Za-z]/, "", line)
    L[NR] = line
  }
  /BUILD (FAILED|SUCCESSFUL) in / { if (end) start = end; end = NR; st[end] = $0 }
  END {
    total = NR
    if (!end) { start = 1; end = total }
    wstart = (start ? start + 1 : 1)

    nerr = 0; nwarn = 0; fenv = 0; fcfg = 0; fnet = 0; fark = 0; fok = 0
    for (i = wstart; i <= end; i++) {
      l = L[i]
      print l > win
      if (l ~ /WARN:/) nwarn++
      if (l ~ /Cannot find module .flutter-hvigor-plugin/) fenv = 1
      if (l ~ /00306042/) fcfg = 1
      if (l ~ /attepted to download/ || l ~ /Operation timed out/ || l ~ /SocketException/) fnet = 1
      if (l ~ /COMPILE RESULT:FAIL/) fark = 1
      if (l ~ /BUILD SUCCESSFUL/) fok = 1
      # "Error Message: xxx At File: /abs/path:line:col"
      if (match(l, /Error Message: .* At File: /)) {
        msg = substr(l, RSTART + 15, RLENGTH - 25)
        loc = substr(l, RSTART + RLENGTH)
        if (match(loc, /:[0-9]+:[0-9]+/)) loc = substr(loc, 1, RSTART + RLENGTH - 1)
        sub(base, "", loc)
        if (!((loc SUBSEP msg) in seen)) { seen[loc, msg] = 1; printf "%s\t%s\n", loc, msg > errf; nerr++ }
      }
    }
    close(errf)
    close(win)
    dur = (end in st) ? substr(st[end], index(st[end], " in ") + 4) : ""
    sub(/ *$/, "", dur)
    printf "total\t%d\nlastts\t%s\nduration\t%s\nstatus\t%s\nnerr\t%d\nnwarn\t%d\nfenv\t%d\nfcfg\t%d\nfnet\t%d\nfark\t%d\nfok\t%d\nstart\t%d\nend\t%d\n", \
      total, ts(st[end]), dur, \
      (end in st ? (st[end] ~ /SUCCESSFUL/ ? "BUILD SUCCESSFUL" : "BUILD FAILED") : "未知"), \
      nerr, nwarn, fenv, fcfg, fnet, fark, fok, wstart, end > meta
    close(meta)

    n = 0
    for (i = 1; i <= total; i++) if (i in st) ends[++n] = i
    for (k = 1; k <= n; k++) {
      lo = (k == 1) ? 1 : ends[k - 1] + 1
      hi = ends[k]
      cause = ""
      for (i = lo; i <= hi && cause == ""; i++) {
        l = L[i]
        if (l ~ /Cannot find module .flutter-hvigor-plugin/) cause = "环境 flutter-hvigor-plugin 缺失"
        else if (l ~ /00306042/) cause = "配置 规格超限"
        else if (l ~ /attepted to download/ || l ~ /Operation timed out/) cause = "网络 原生库下载超时"
        else if (l ~ /COMPILE RESULT:FAIL/) cause = "代码 ArkTS 编译错误"
        else if (l ~ /BUILD SUCCESSFUL/) cause = "成功"
      }
      if (cause == "") cause = "未知"
      d = st[hi]; sub(/.*BUILD (FAILED|SUCCESSFUL) in /, "", d); sub(/ *$/, "", d)
      printf "%s\t%s\t%s\n", ts(st[hi]), d, cause > hist
    }
    close(hist)
  }
' "$LOG"

TOTAL=""; LAST_TS=""; DURATION=""; STATUS=""; NERR=0; NWARN=0; FENV=0; FCFG=0; FNET=0; FARK=0; FOK=0
while IFS=$'\t' read -r k v; do
  case "$k" in
    total) TOTAL="$v" ;; lastts) LAST_TS="$v" ;; duration) DURATION="$v" ;;
    status) STATUS="$v" ;; nerr) NERR="$v" ;; nwarn) NWARN="$v" ;;
    fenv) FENV="$v" ;; fcfg) FCFG="$v" ;; fnet) FNET="$v" ;; fark) FARK="$v" ;; fok) FOK="$v" ;;
  esac
done < "$TMP.meta"

SIZE=$(ls -lh "$LOG" | awk '{print $5}')

printf '\n=== 鸿蒙构建诊断 ===\n'
printf '日志      %s（%s / %s 行）\n' "$LOG" "$SIZE" "${TOTAL:-?}"
printf '最近构建  %s  %s  %s\n' "${LAST_TS:-?}" "${STATUS:-未知}" "${DURATION:+耗时 $DURATION}"

KIND=""; HINT=""
if [ "$FENV" = "1" ]; then
  KIND="环境 · hvigor 找不到 flutter-hvigor-plugin"
  HINT="hvigor 只在 \$FLUTTER_SDK/packages/flutter_tools/hvigor 里带这个插件。
     先确认 ohos/hvigor/hvigor-config.json5 的 hvigorVersion 和 flutter 自带的一致，
     再用 flutter 自带的 hvigorw 构建，别混用 DevEco/command-line-tools 里的那套。"
elif [ "$FCFG" = "1" ]; then
  KIND="配置 · module.json5 / build-profile.json5 不符合规格"
  HINT="按日志点名的字段改（常见：bundleName 超长、label/icon 缺失、versionCode 越界）。"
elif [ "$FNET" = "1" ]; then
  KIND="网络 · 构建期下载原生预编译库失败"
  HINT="sqlite3 的 build hook 会去 github.com 拉 libsqlite3；鸿蒙 target 下它把 OS 认成 linux，
     下载到 glibc 版 .so 即使成功也加载不了。既然已用 RDB 桥接，直接让它别下载：
       在 mobile/pubspec.yaml 根层加
         hooks:
           user_defines:
             sqlite3:
               source: system"
elif [ "$FARK" = "1" ]; then
  KIND="代码 · ArkTS 编译错误（只需改 ets，不必重装环境）"
  HINT="只改下面点名的 .ets，然后用 ./scripts/build-ohos.sh --fast 增量重编。"
elif [ "$FOK" = "1" ]; then
  KIND="成功"
fi
[ -n "$KIND" ] && printf '类型      %s\n' "$KIND"

if [ "$NERR" -gt 0 ]; then
  printf '\n错误 %s 条（已去重；编译器上报数可能更多，因为它把同一处打了三遍）：\n' "$NERR"
  sort -t: -k1,1 -k2,2n "$TMP.err" | awk -F'\t' '{ printf "  %-44s %s\n", $1, $2 }'
  printf '\n涉及文件：\n'
  cut -f1 "$TMP.err" | cut -d: -f1 | sort | uniq -c | awk '{ printf "  %s  (%s 条)\n", $2, $1 }'
else
  OTHER=$(awk '/\[ERROR\]|ERROR: [0-9]{5,}/ && !/BUILD FAILED|log4js|Writing to file/ {
      sub(/^\[[0-9T:.+-]+\] \[ERROR\] debug-file - /, "");
      if (!seen[$0]++) print
    }' "$TMP.win" | head -12)
  [ -n "$OTHER" ] && printf '\n错误行：\n%s\n' "$(printf '%s' "$OTHER" | sed 's/^/  /')"
fi

if [ "$SHOW_WARN" = "1" ]; then
  printf '\n警告 %s 条，去重后前 20：\n' "$NWARN"
  awk -v base="$(pwd)/" '{
      if (match($0, /WARN File: [^ ]+:[0-9]+:[0-9]+/)) {
        s = substr($0, RSTART + 11, RLENGTH - 11); sub(base, "", s);
        if (!seen[s]++) print "  " s
      }
    }' "$TMP.win" | head -20
fi

if [ "$SHOW_HISTORY" = "1" ]; then
  printf '\n历史构建（结束时间 / 耗时 / 死因）：\n'
  awk -F'\t' '{ printf "  %-10s %-18s %s\n", $1, $2, $3 }' "$TMP.hist"
  printf '  —— 每轮都是全量构建（日志里 IS_FULL_BUILD=true、IS_DAEMON=false），所以动辄 2~5 分钟。\n'
fi

[ -n "$HINT" ] && printf '\n下一步：%s\n' "$HINT"
printf '\n'
