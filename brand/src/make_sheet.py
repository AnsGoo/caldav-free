#!/usr/bin/env python3
"""生成品牌预览图 brand-sheet.png（仅用于展示，不参与标志本体）。"""

import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SVG = os.path.join(HERE, "..", "svg")
OUT = os.path.join(HERE, "..", "png", "brand-sheet.png")

INK, ACC, PAPER, DARK, MUTED = "#10131A", "#2F55E8", "#FFFFFF", "#0B0E14", "#8A93A6"


def load(name):
    s = open(os.path.join(SVG, name)).read()
    body = re.sub(r"^.*?<svg[^>]*>", "", s, flags=re.S)
    body = body.replace("</svg>", "")
    return body


def place(body, x, y, scale):
    return f'<g transform="translate({x} {y}) scale({scale})">{body}</g>'


def label(x, y, text, size=11, color=MUTED, track=1.6):
    return (f'<text x="{x}" y="{y}" font-family="Helvetica Neue, Arial" font-size="{size}" '
            f'letter-spacing="{track}" fill="{color}">{text}</text>')


def main():
    W, H = 1600, 1180
    p = [f'<rect width="{W}" height="{H}" fill="{PAPER}"/>']

    # ---- header
    p.append(label(80, 84, "CALFREE  /  BRAND MARK", 11))
    p.append(label(80, 108, "历记 · 自托管日历", 11))
    p.append(f'<line x1="80" y1="132" x2="{W-80}" y2="132" stroke="#E6E9EF" stroke-width="1"/>')

    # ---- primary lockup
    p.append(place(load("logo-horizontal.svg"), 80, 200, 1.55))
    p.append(label(80, 420, "PRIMARY LOCKUP  ·  HORIZONTAL", 10))

    # ---- stacked
    p.append(place(load("logo-stacked.svg"), W - 80 - 228 * 1.15, 176, 1.15))
    p.append(label(W - 80 - 228 * 1.15, 420, "STACKED  ·  中英组合", 10))

    # ---- mark row
    my = 500
    p.append(place(load("logo-mark.svg"), 80, my, 0.92))
    p.append(place(load("logo-mark-mono.svg"), 80 + 130, my, 0.92))
    p.append(f'<rect x="{80+260-18}" y="{my-18}" width="124" height="124" fill="{DARK}"/>')
    p.append(place(load("logo-mark-inverse.svg"), 80 + 260, my, 0.92))
    p.append(place(load("app-icon.svg"), 80 + 420, my - 12, 0.22))
    p.append(label(80, my + 130, "SYMBOL  ·  单色  ·  反白  ·  应用图标", 10))

    # ---- palette
    px, py = 80, 660
    for i, (name, hexv, note) in enumerate([
            ("INK", INK, "主色 / 文字 / 标志"),
            ("SIGNAL BLUE", ACC, "强调 / 日期点 / 交互"),
            ("DARK", DARK, "深色界面底"),
            ("PAPER", PAPER, "浅色界面底")]):
        x = px + i * 300
        stroke = ' stroke="#E6E9EF"' if hexv == PAPER else ""
        p.append(f'<rect x="{x}" y="{py}" width="88" height="88" fill="{hexv}"{stroke}/>')
        p.append(label(x, py + 116, name, 10, INK, 1.2))
        p.append(f'<text x="{x}" y="{py + 138}" font-family="Menlo, monospace" font-size="13" fill="{INK}">{hexv}</text>')
        p.append(label(x, py + 160, note, 10))

    # ---- dark band
    dy = 900
    p.append(f'<rect x="0" y="{dy}" width="{W}" height="196" fill="{DARK}"/>')
    p.append(place(load("logo-horizontal-inverse.svg"), 80, dy + 61, 1.0))
    p.append(label(W - 80 - 300, dy + 96, "ON DARK", 10, "#5C6577"))
    p.append(label(W - 80 - 300, dy + 118, "反白版用于深色底", 10, "#5C6577"))

    # ---- footer
    p.append(label(80, H - 34, "MIN WIDTH 120 PX  ·  CLEAR SPACE = 0.5 × MARK HEIGHT", 10))

    body = "".join(p)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
           f'viewBox="0 0 {W} {H}">{body}</svg>')
    tmp = os.path.join(HERE, "_sheet.svg")
    open(tmp, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1", tmp, "-o", OUT], check=True)
    os.remove(tmp)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
