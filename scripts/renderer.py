# -*- coding: utf-8 -*-
"""
RS-274X Gerber -> PNG 预览渲染器（纯 Python，Pillow）。
用于把转换结果渲染成图片做可视化验证（等价于 Gerber 查看器截图）。
用法: python renderer.py <input.gbr> <output.png> [px_per_mm]
"""
import sys
import re
from PIL import Image, ImageDraw


def parse(gbr_path):
    """解析最简 RS-274X（D02 移动 / D01 画线），返回线段列表 (x0,y0,x1,y1) 与尺寸(mm)。"""
    data = open(gbr_path, "r", encoding="ascii", errors="replace").read()
    cur, start = [0, 0], None
    segs = []
    for ln in data.splitlines():
        ln = ln.strip()
        m = re.fullmatch(r"X(\d+)Y(\d+)D0(\d)\*", ln)
        if m:
            x, y, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
            cur = [x, y]
            if d == 2:
                start = cur
            elif d == 1:
                segs.append((start[0], start[1], cur[0], cur[1]))
                start = cur
            continue
        m = re.fullmatch(r"X(\d+)D0(\d)\*", ln)
        if m:
            x, d = int(m.group(1)), int(m.group(2))
            if d == 2:
                start = (x, cur[1])
                cur = [x, cur[1]]
            elif d == 1:
                cur = [x, cur[1]]
                segs.append((start[0], start[1], cur[0], cur[1]))
                start = cur
            continue
    xs = [v for s in segs for v in (s[0], s[2])]
    ys = [v for s in segs for v in (s[1], s[3])]
    # 画布按板子的最大坐标(而非差值)定尺寸，避免 min 处空区导致下方内容被裁剪
    wmm = max(xs) / 1000.0
    hmm = max(ys) / 1000.0
    return segs, wmm, hmm


def render(gbr_path, png_path, px_per_mm=10):
    segs, wmm, hmm = parse(gbr_path)
    W, H = max(int(wmm * px_per_mm), 1), max(int(hmm * px_per_mm), 1)
    img = Image.new("RGB", (W, H), "white")
    dr = ImageDraw.Draw(img)
    lw = max(int(0.1 * px_per_mm), 1)
    for (x0, y0, x1, y1) in segs:
        bx = min(x0, x1) / 1000.0 * px_per_mm
        by = min(y0, y1) / 1000.0 * px_per_mm
        # 统一水平/垂直线段，用矩形填充显现线宽
        dr.rectangle([bx, by, bx + (abs(x1 - x0) / 1000.0) * px_per_mm,
                      by + (abs(y1 - y0) / 1000.0) * px_per_mm + lw], fill="black")
    img.save(png_path)
    print("rendered %s -> %s (%dx%d)" % (gbr_path, png_path, W, H))


if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 10)