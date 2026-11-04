#!/usr/bin/env python3
"""把 CalFree 标记分发到全部平台图标位。

来源：build_logo.py 中的纯几何标记（不依赖字体 / 位图素材）。
输出：Web / PWA、Android（含自适应图标）、iOS、macOS、Windows。

用法：
    python3 apply_icons.py           # 全部生成
    python3 apply_icons.py --dry-run # 只打印将写入的文件
"""

import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from build_logo import frame_open, dot, svg  # noqa: E402

BG = "#2F55E8"
FG = "#FFFFFF"
TMP = os.path.join(HERE, "_icons")

# 平台通用的几何比例
RADIUS = 0.225      # 圆角占边长比例（与 brand/svg/app-icon.svg 一致）
MARK = 0.46         # 标记占边长比例
MARK_FULL = 0.50    # 满版（iOS）稍大
MARK_MASK = 0.44    # maskable 安全区更保守


def icon(size, radius=RADIUS, mark=MARK, pad=0.0, small=False):
    """生成图标 SVG。pad 为四周留白比例（macOS 用）。"""
    inner = size * (1 - 2 * pad)
    r = radius * size
    body = f'<rect width="{size:g}" height="{size:g}" rx="{r:.3f}" fill="{BG}"/>'
    m = inner * mark
    ox = (size - m) / 2
    oy = (size - m) / 2
    t, op, dm = (0.20, 0.50, 0.26) if small else (0.175, 0.47, 0.23)
    body += f'<path fill="{FG}" d="{frame_open(ox, oy, m, op, t)}"/>'
    body += f'<path fill="{FG}" d="{dot(ox + m / 2, oy + m / 2, m * dm)}"/>'
    return svg(size, size, body)


def render(svg_text, size, out_path, alpha=True):
    """用 rsvg-convert 按目标像素渲染；alpha=False 时输出不含透明通道（iOS 要求）。"""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    tmp_svg = os.path.join(TMP, "tmp.svg")
    tmp_png = os.path.join(TMP, "tmp.png")
    with open(tmp_svg, "w") as fh:
        fh.write(svg_text)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), tmp_svg, "-o", tmp_png], check=True)
    if alpha:
        shutil.copyfile(tmp_png, out_path)
    else:
        from PIL import Image
        Image.open(tmp_png).convert("RGB").save(out_path)
    return out_path


def ico(out_path, sizes):
    """多尺寸 .ico：每档单独渲染，小尺寸用加粗笔画以免糊掉。"""
    os.makedirs(TMP, exist_ok=True)
    parts = []
    for s in sizes:
        p = os.path.join(TMP, f"ico-{s}.png")
        render(icon(s, radius=0.18, mark=0.48, small=s <= 32), s, p)
        parts.append(p)
    subprocess.run(["magick"] + parts + [out_path], check=True)


def plan():
    """返回 [(目标路径, 说明, 生成函数)]。"""
    jobs = []

    web = os.path.join(ROOT, "web", "public")
    dist = os.path.join(ROOT, "internal", "web", "dist")

    for base in (web, dist):
        jobs.append((os.path.join(base, "icon-192.png"), "web/pwa 192", lambda p: render(icon(192), 192, p)))
        jobs.append((os.path.join(base, "icon-512.png"), "web/pwa 512", lambda p: render(icon(512), 512, p)))
        jobs.append((os.path.join(base, "icon-180.png"), "apple-touch 180",
                     lambda p: render(icon(180, mark=MARK_FULL), 180, p, alpha=False)))
        jobs.append((os.path.join(base, "icon-maskable-192.png"), "maskable 192",
                     lambda p: render(icon(192, radius=0, mark=MARK_MASK), 192, p)))
        jobs.append((os.path.join(base, "icon-maskable-512.png"), "maskable 512",
                     lambda p: render(icon(512, radius=0, mark=MARK_MASK), 512, p)))

    svg_src = icon(512)
    for base in (web, dist):
        jobs.append((os.path.join(base, "icon.svg"), "web svg", None))

    res = os.path.join(ROOT, "mobile", "android", "app", "src", "main", "res")
    for folder, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        jobs.append((os.path.join(res, f"mipmap-{folder}", "ic_launcher.png"), f"android {folder}",
                     (lambda px: lambda p: render(icon(px, small=px <= 48), px, p))(px)))

    ios = os.path.join(ROOT, "mobile", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(ios):
        names = json.load(open(os.path.join(ios, "Contents.json")))["images"]
        for entry in names:
            fn = entry.get("filename")
            if not fn:
                continue
            base = float(entry["size"].split("x")[0])
            scale = int(entry["scale"].rstrip("x"))
            px = round(base * scale)
            jobs.append((os.path.join(ios, fn), f"ios {fn}",
                         (lambda px: lambda p: render(icon(px, radius=0, mark=MARK_FULL), px, p, alpha=False))(px)))

    mac = os.path.join(ROOT, "mobile", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(mac):
        for px in (16, 32, 64, 128, 256, 512, 1024):
            fn = f"app_icon_{px}.png"
            jobs.append((os.path.join(mac, fn), f"macos {px}",
                         (lambda px: lambda p: render(icon(px, mark=0.48, pad=0.095 if px >= 128 else 0.06,
                                                          small=px <= 32), px, p))(px)))

    win = os.path.join(ROOT, "mobile", "windows", "runner", "resources", "app_icon.ico")
    if os.path.isdir(os.path.dirname(win)):
        jobs.append((win, "windows ico", lambda p: ico(p, [16, 24, 32, 48, 64, 128, 256])))

    return jobs, svg_src


def main():
    jobs, svg_src = plan()
    dry = "--dry-run" in sys.argv
    written = 0
    for path, label, fn in jobs:
        if dry:
            print(f"{label:22s} -> {os.path.relpath(path, ROOT)}")
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if fn is None:
            with open(path, "w") as fh:
                fh.write(svg_src)
        else:
            fn(path)
        written += 1
    if dry:
        print(f"\n{len(jobs)} files")
        return
    shutil.rmtree(TMP, ignore_errors=True)

    # Android 自适应图标（前景矢量 + 背景色）
    res = os.path.join(ROOT, "mobile", "android", "app", "src", "main", "res")
    vd = adaptive_foreground()
    files = {
        os.path.join(res, "drawable", "ic_launcher_foreground.xml"): vd,
        os.path.join(res, "values", "ic_launcher_background.xml"):
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="ic_launcher_background">{BG}</color>\n</resources>\n',
        os.path.join(res, "mipmap-anydpi-v26", "ic_launcher.xml"):
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n',
    }
    for path, data in files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(data)
        written += 1
    print(f"wrote {written} files")


def adaptive_foreground():
    """108dp 自适应图标的矢量前景：标记居中，完整落在 72dp 安全圆内。"""
    m = 44.0
    ox = (108 - m) / 2
    oy = (108 - m) / 2
    frame = frame_open(ox, oy, m, 0.47, 0.175)
    d = dot(ox + m / 2, oy + m / 2, m * 0.23)
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp"\n'
            '    android:viewportWidth="108" android:viewportHeight="108">\n'
            f'    <path android:fillColor="{FG}" android:pathData="{frame}"/>\n'
            f'    <path android:fillColor="{FG}" android:pathData="{d}"/>\n'
            '</vector>\n')


if __name__ == "__main__":
    main()
