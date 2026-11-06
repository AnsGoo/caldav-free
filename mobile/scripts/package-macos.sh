#!/usr/bin/env bash
# 把 flutter build macos 产出的 .app 打成 DMG。
#
# 用法:
#   package-macos.sh <app 路径> <输出目录> <版本标签> [--split]
#
#   --split   额外产出 arm64 / x64 两个单架构 DMG。体积约减半（App 与
#             FlutterMacOS 两个 framework 都是通用二进制），代价是用户得
#             自己认机型，所以默认只出通用版。
#
# 产物名:
#   caldav-free-macos-universal-<tag>.dmg
#   caldav-free-macos-arm64-<tag>.dmg      （--split 才有）
#   caldav-free-macos-x64-<tag>.dmg        （--split 才有）
set -euo pipefail

die() { printf '错误: %s\n' "$1" >&2; exit 1; }

APP=${1:-}
OUT_DIR=${2:-}
TAG=${3:-}
[ -n "$APP" ] && [ -n "$OUT_DIR" ] && [ -n "$TAG" ] ||
  die "用法: package-macos.sh <app 路径> <输出目录> <版本标签> [--split]"

SPLIT=0
for arg in "${@:4}"; do
  [ "$arg" = "--split" ] && SPLIT=1
done

[ -d "$APP" ] || die "找不到 .app: $APP"
[ -f "$APP/Contents/Info.plist" ] || die "$APP 不是合法的 app bundle"
command -v hdiutil >/dev/null || die "hdiutil 只在 macOS 上有"

APP_NAME=$(basename "$APP")
# 卷名取应用显示名，Finder 里挂载出来就是这个名字。
VOL_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Contents/Info.plist" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP/Contents/Info.plist" 2>/dev/null ||
  echo "${APP_NAME%.app}")
[ -n "$VOL_NAME" ] || VOL_NAME="${APP_NAME%.app}"

mkdir -p "$OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)

# ---------- DMG ----------

# ditto 而不是 cp -R：要保住 framework 里的符号链接和扩展属性，
# 用 cp 会把 Versions/Current 之类的链接展开成实文件，包体直接翻倍。
make_dmg() {
  local app=$1 out=$2
  local stage
  stage=$(mktemp -d)
  ditto "$app" "$stage/$(basename "$app")"
  ln -s /Applications "$stage/Applications"
  rm -f "$out"
  hdiutil create -quiet -volname "$VOL_NAME" -srcfolder "$stage" \
    -ov -format UDZO "$out" >/dev/null
  rm -rf "$stage"
  hdiutil verify -quiet "$out" >/dev/null || die "DMG 校验失败: $out"
}

# ---------- 单架构裁剪 ----------

# 只保留指定架构：逐个找出通用 Mach-O，lipo -thin 掉另一片，再重新签名。
# 注意瘦身会让原签名失效，必须重签，否则包能打出来但一打开就崩。
thin_app() {
  local src=$1 dst=$2 arch=$3
  rm -rf "$dst"
  ditto "$src" "$dst"

  local thinned=0 skipped=0
  while IFS= read -r -d '' f; do
    # 不用 file | grep -q：grep 提前退出会让 file 吃 SIGPIPE。
    local kind
    kind=$(file -b "$f" 2>/dev/null || true)
    case "$kind" in
      *Mach-O*) ;;
      *) continue ;;
    esac

    local archs
    archs=$(lipo -archs "$f" 2>/dev/null || true)
    [ -n "$archs" ] || continue

    local has_arch=0 count=0 a
    for a in $archs; do
      count=$((count + 1))
      [ "$a" = "$arch" ] && has_arch=1
    done
    [ "$count" -gt 1 ] || continue   # 已经是单架构
    if [ "$has_arch" != 1 ]; then
      skipped=$((skipped + 1))
      printf '    跳过 %s（无 %s 片）\n' "${f#"$dst"/}" "$arch"
      continue
    fi

    if lipo -thin "$arch" "$f" -output "$f.__thin" 2>/dev/null; then
      mv "$f.__thin" "$f"
      chmod +x "$f"
      thinned=$((thinned + 1))
    else
      rm -f "$f.__thin"
      printf '    警告: 瘦身失败 %s\n' "${f#"$dst"/}"
    fi
  done < <(find "$dst" -type f -print0)

  printf '    裁剪 %d 个 Mach-O（跳过 %d 个）\n' "$thinned" "$skipped"
  [ "$thinned" -gt 0 ] || die "一个二进制都没裁掉，架构参数可能写错了: $arch"

  # 先签内层（framework / dylib），再签外层 app。顺序反了外层签名会被内层覆盖。
  local fw
  for fw in "$dst/Contents/Frameworks/"*.framework; do
    [ -d "$fw" ] || continue
    codesign --force --sign - --timestamp=none "$fw" >/dev/null 2>&1 ||
      die "重签失败: $(basename "$fw")"
  done
  codesign --force --sign - --timestamp=none "$dst" >/dev/null 2>&1 ||
    die "重签失败: $dst"
  codesign --verify --deep --strict "$dst" 2>/dev/null ||
    die "重签后校验不过: $dst"
}

# ---------- 主流程 ----------

universal="$OUT_DIR/caldav-free-macos-universal-$TAG.dmg"
printf '== 通用包 ==\n'
make_dmg "$APP" "$universal"
printf '   %s  %s\n' "$(du -h "$universal" | cut -f1)" "$(basename "$universal")"

if [ "$SPLIT" = 1 ]; then
  work=$(mktemp -d)
  for arch in arm64 x86_64; do
    case "$arch" in
      arm64) label=arm64 ;;
      x86_64) label=x64 ;;
    esac
    printf '== 单架构 %s ==\n' "$arch"
    # 必须保持 .app 原名：卷里挂出来叫 caldav-free.app-arm64 的话，
    # 拖进「应用程序」文件夹后会变成一个打不开的怪名字。
    mkdir -p "$work/$label"
    thinned="$work/$label/$APP_NAME"
    thin_app "$APP" "$thinned" "$arch"
    exe="$thinned/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$thinned/Contents/Info.plist")"
    printf '   主二进制架构: %s\n' "$(lipo -archs "$exe")"
    out="$OUT_DIR/caldav-free-macos-$label-$TAG.dmg"
    make_dmg "$thinned" "$out"
    printf '   %s  %s\n' "$(du -h "$out" | cut -f1)" "$(basename "$out")"
  done
  rm -rf "$work"
fi

printf '\n== 产物 ==\n'
for f in "$OUT_DIR"/*.dmg; do
  printf '%s  %s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$(du -h "$f" | cut -f1)" "$(basename "$f")"
done
