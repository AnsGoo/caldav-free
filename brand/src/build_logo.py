#!/usr/bin/env python3
"""CalFree / 历记 品牌标志生成器

所有图形都是纯几何构造，输出为轮廓化的 SVG（无字体依赖）。

  - 标记：开口方框 + 日期方块
  - 字标：Inter Bold 转曲后按自定义字距重新排版
  - 中文：Hiragino Sans GB W6 转曲（仅用于中文副标）

用法：
    python3 build_logo.py            # 输出到 ../svg 和 ../png
    python3 build_logo.py --svg-only # 只输出 SVG
"""

import os
import re
import sys
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_SVG = os.path.join(HERE, "..", "svg")
OUT_PNG = os.path.join(HERE, "..", "png")

# ---------------------------------------------------------------- 品牌色
INK = "#10131A"      # 主色 · 墨黑
ACC = "#2F55E8"      # 强调色 · 信号蓝
PAPER = "#FFFFFF"
DARK = "#0B0E14"     # 深色底

# ---------------------------------------------------------------- 路径工具
NUM = re.compile(r"[MLCZHV]|-?\d*\.?\d+(?:e-?\d+)?")
CMDS = set("MLCZHV")


def segs(d):
    """把 path 数据拆成 (命令, 参数)，展开隐式重复命令。"""
    toks = NUM.findall(d)
    i, cmd = 0, None
    while i < len(toks):
        t = toks[i]
        if t in CMDS:
            cmd = t
            i += 1
            if cmd == "Z":
                yield ("Z", [])
                continue
        if cmd in ("M", "L"):
            yield (cmd, [float(toks[i]), float(toks[i + 1])])
            i += 2
            cmd = "L" if cmd == "M" else cmd
        elif cmd == "C":
            yield ("C", [float(toks[i + k]) for k in range(6)])
            i += 6
        elif cmd in ("H", "V"):
            yield (cmd, [float(toks[i])])
            i += 1
        else:
            i += 1


def xform(d, sx=1.0, sy=None, dx=0.0, dy=0.0):
    """仿射变换，输出只含绝对 M/L/C/Z 的路径。"""
    if sy is None:
        sy = sx
    out, cx, cy = [], 0.0, 0.0
    for cmd, a in segs(d):
        if cmd in ("M", "L"):
            cx, cy = a
            out.append(f"{cmd}{cx * sx + dx:.3f} {cy * sy + dy:.3f}")
        elif cmd == "H":
            cx = a[0]
            out.append(f"L{cx * sx + dx:.3f} {cy * sy + dy:.3f}")
        elif cmd == "V":
            cy = a[0]
            out.append(f"L{cx * sx + dx:.3f} {cy * sy + dy:.3f}")
        elif cmd == "C":
            p = [(a[k] * sx + dx, a[k + 1] * sy + dy) for k in (0, 2, 4)]
            cx, cy = a[4], a[5]
            out.append("C" + " ".join(f"{x:.3f} {y:.3f}" for x, y in p))
        else:
            out.append("Z")
    return "".join(out)


def bbox(d):
    xs, ys, cx, cy = [], [], 0.0, 0.0
    for cmd, a in segs(d):
        if cmd in ("M", "L"):
            cx, cy = a
            xs.append(cx)
            ys.append(cy)
        elif cmd == "H":
            cx = a[0]
            xs.append(cx)
        elif cmd == "V":
            cy = a[0]
            ys.append(cy)
        elif cmd == "C":
            for k in (0, 2, 4):
                xs.append(a[k])
                ys.append(a[k + 1])
            cx, cy = a[4], a[5]
    return min(xs), min(ys), max(xs), max(ys)


# ---------------------------------------------------------------- 标记几何
def rect(x, y, w, h):
    return f"M{x:.3f} {y:.3f}H{x + w:.3f}V{y + h:.3f}H{x:.3f}Z"


def frame_open(x, y, s, open_frac=0.47, t_frac=0.16):
    """方框，右边中部开口 —— 日历框架 / 字母 C 的方形变体。"""
    t = s * t_frac
    a = (s - s * open_frac) / 2
    return (rect(x, y, s, t)
            + rect(x, y + s - t, s, t)
            + rect(x, y, t, s)
            + rect(x + s - t, y, t, a)
            + rect(x + s - t, y + s - a, t, a))


def dot(cx, cy, d):
    return rect(cx - d / 2, cy - d / 2, d, d)


# ---------------------------------------------------------------- 字标
BASE, CAP = 600.0, 727.5          # Inter 源文件中的基线与大写高
K = 100.0 / CAP                   # 归一化：大写高 = 100

_raw = re.findall(r'<path d="([^"]+)"', open(os.path.join(HERE, "inter-bold-outlines.svg")).read())
LETTERS = "CalFree"
GLYPHS = []
for ch, d in zip(LETTERS, _raw):
    x0, _, x1, _ = bbox(d)
    GLYPHS.append({"ch": ch, "d": d, "x0": x0, "x1": x1})

ADV = [(GLYPHS[i + 1]["x0"] - GLYPHS[i]["x0"]) * K for i in range(len(GLYPHS) - 1)]
# 自定义字距（单位：大写高 100），按视觉间距手工微调
KERN = {"Ca": -1.0, "al": -1.5, "lF": 7.0, "Fr": -2.0, "re": -0.5, "ee": -1.5}


def wordmark(scale=1.0):
    pen, items = 0.0, []
    for i, g in enumerate(GLYPHS):
        d = xform(g["d"], K * scale, K * scale, (pen - g["x0"] * K) * scale, -BASE * K * scale)
        items.append((g["ch"], d))
        if i < len(ADV):
            pen += ADV[i] + KERN.get(g["ch"] + GLYPHS[i + 1]["ch"], 0.0)
    bs = [bbox(d) for _, d in items]
    return items, (min(b[0] for b in bs), min(b[1] for b in bs),
                   max(b[2] for b in bs), max(b[3] for b in bs))


_CJK_FONT = None


def cjk(ch, em=100.0):
    """从系统 Hiragino Sans GB W6 取轮廓；如缺失则返回空（中文副标可省略）。"""
    global _CJK_FONT
    from fontTools.ttLib import TTCollection
    from fontTools.pens.svgPathPen import SVGPathPen
    if _CJK_FONT is None:
        path = "/System/Library/Fonts/Hiragino Sans GB.ttc"
        if not os.path.exists(path):
            raise SystemExit("缺少中文字体：/System/Library/Fonts/Hiragino Sans GB.ttc")
        _CJK_FONT = TTCollection(path).fonts[2]
    gs = _CJK_FONT.getGlyphSet()
    name = _CJK_FONT.getBestCmap()[ord(ch)]
    pen = SVGPathPen(gs, ntos=lambda v: f"{v:.3f}")
    gs[name].draw(pen)
    upem = _CJK_FONT["head"].unitsPerEm
    return xform(pen.getCommands(), em / upem, -em / upem, 0, 0)


# ---------------------------------------------------------------- 组合
def img(d, fill):
    return f'<path fill="{fill}" d="{d}"/>'


def mark(x, y, s, ink=INK, accent=ACC, mono=False):
    a = ink if mono else accent
    return img(frame_open(x, y, s), ink) + img(dot(x + s / 2, y + s / 2, s * 0.23), a)


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.3f}" height="{h:.3f}" '
            f'viewBox="0 0 {w:.3f} {h:.3f}">{body}</svg>\n')


def build_horizontal(cap=46, mk=74, gap=24, color=INK, accent=ACC, mono=False):
    items, (x0, _, x1, _) = wordmark(cap / 100.0)
    wmw = x1 - x0
    W, H = mk + gap + wmw, mk
    base = mk / 2 + cap / 2
    body = mark(0, 0, mk, color, accent, mono)
    body += "".join(img(xform(d, 1, 1, mk + gap - x0, base), color) for _, d in items)
    return svg(W, H, body), W, H


def cjk_text(text, em, x, baseline, color=INK, track=0.24):
    body, pen = "", x
    for ch in text:
        d = cjk(ch, em)
        b = bbox(d)
        body += img(xform(d, 1, 1, pen - b[0], baseline), color)
        pen += (b[2] - b[0]) + em * track
    return body, pen - em * track - x


def build_stacked(cap=46, mk=64, gap=25, zh_em=32, color=INK, accent=ACC, mono=False):
    items, (x0, _, x1, _) = wordmark(cap / 100.0)
    wmw = x1 - x0
    _, zhw = cjk_text("历记", zh_em, 0, 0, color)
    W = max(mk, wmw, zhw)
    base = mk + gap + cap
    zh_base = base + cap * 0.30 + zh_em * 0.805
    H = zh_base + zh_em * 0.09
    body = mark((W - mk) / 2, 0, mk, color, accent, mono)
    body += "".join(img(xform(d, 1, 1, (W - wmw) / 2 - x0, base), color) for _, d in items)
    zh, _ = cjk_text("历记", zh_em, (W - zhw) / 2, zh_base, color)
    return svg(W, H, body + zh), W, H


def build_mark(size=96, color=INK, accent=ACC, mono=False):
    return svg(size, size, mark(0, 0, size, color, accent, mono)), size, size


def build_wordmark(cap=100, color=INK):
    items, (x0, y0, x1, y1) = wordmark(cap / 100.0)
    body = "".join(img(xform(d, 1, 1, -x0, -y1), color) for _, d in items)
    return svg(x1 - x0, y1 - y0, body), x1 - x0, y1 - y0


def build_appicon(size=512, r=0.225, bg=ACC, fg=PAPER):
    mk = size * 0.46
    pad = (size - mk) / 2
    body = f'<rect width="{size}" height="{size}" rx="{size * r:.1f}" fill="{bg}"/>'
    body += f'<g transform="translate({pad:.2f} {pad:.2f})">'
    body += img(frame_open(0, 0, mk, 0.47, 0.175), fg) + img(dot(mk / 2, mk / 2, mk * 0.23), fg)
    return svg(size, size, body + "</g>"), size, size


def build_favicon(size=32):
    """小尺寸光学修正：笔画更粗、点更大。"""
    body = img(frame_open(0, 0, size, 0.50, 0.20), INK) + img(dot(size / 2, size / 2, size * 0.26), INK)
    return svg(size, size, body), size, size


# ---------------------------------------------------------------- 输出
def main():
    os.makedirs(OUT_SVG, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    files = {
        "logo-horizontal.svg": build_horizontal()[0],
        "logo-horizontal-mono.svg": build_horizontal(mono=True)[0],
        "logo-horizontal-inverse.svg": build_horizontal(color=PAPER, accent=PAPER)[0],
        "logo-stacked.svg": build_stacked()[0],
        "logo-stacked-inverse.svg": build_stacked(color=PAPER, accent=PAPER)[0],
        "logo-mark.svg": build_mark()[0],
        "logo-mark-mono.svg": build_mark(mono=True)[0],
        "logo-mark-inverse.svg": build_mark(color=PAPER, accent=PAPER)[0],
        "logo-wordmark.svg": build_wordmark()[0],
        "app-icon.svg": build_appicon()[0],
        "favicon.svg": build_favicon()[0],
    }
    for name, data in files.items():
        with open(os.path.join(OUT_SVG, name), "w") as fh:
            fh.write(data)

    if "--svg-only" in sys.argv:
        print(f"wrote {len(files)} svg")
        return

    pngs = [
        ("logo-horizontal.svg", "logo-horizontal.png", 3, PAPER),
        ("logo-horizontal-inverse.svg", "logo-horizontal-inverse.png", 3, DARK),
        ("logo-horizontal-mono.svg", "logo-horizontal-mono.png", 3, PAPER),
        ("logo-stacked.svg", "logo-stacked.png", 3, PAPER),
        ("logo-stacked-inverse.svg", "logo-stacked-inverse.png", 3, DARK),
        ("logo-mark.svg", "logo-mark-512.png", 512 / 96, PAPER),
        ("logo-mark.svg", "logo-mark-128.png", 128 / 96, PAPER),
        ("logo-mark.svg", "logo-mark-32.png", 32 / 96, PAPER),
        ("logo-mark-inverse.svg", "logo-mark-inverse-512.png", 512 / 96, DARK),
        ("app-icon.svg", "app-icon-512.png", 1, None),
        ("app-icon.svg", "app-icon-1024.png", 2, None),
        ("favicon.svg", "favicon-32.png", 1, PAPER),
    ]
    for src, dst, scale, bg in pngs:
        cmd = ["rsvg-convert", "-z", f"{scale:.4f}"]
        if bg:
            cmd += ["-b", bg]
        cmd += [os.path.join(OUT_SVG, src), "-o", os.path.join(OUT_PNG, dst)]
        subprocess.run(cmd, check=True)
    print(f"wrote {len(files)} svg + {len(pngs)} png")


if __name__ == "__main__":
    main()
