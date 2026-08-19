# -*- coding: utf-8 -*-
"""
生成一套"真艺术"四层演示输入（白=实体，黑=背景，与 converter.py 约定一致），
以及生成输入->Gerber 渲染的对照总览图。

用法:
  python make_demo.py                  # 生成 input/ 下四层 PNG
  python make_demo.py --overview       # 依据 input/ + preview/ 拼对照总览图
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 600, 450            # 画布(px)
FG = 255                    # 白 = 实体层
BG = 0                      # 黑 = 背景

HERE = os.path.dirname(os.path.abspath(__file__))
IN_DIR = os.path.join(HERE, "input")
GB_DIR = os.path.join(HERE, "gerber")
PV_DIR = os.path.join(HERE, "preview")

FONT_SIZE = 60


def _font():
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, FONT_SIZE)
        except Exception:
            pass
    return ImageFont.load_default()


def heart_points(cx, cy, s, n=96):
    """心形参数方程（钟形心形），s 为缩放。"""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    return pts


def star_points(cx, cy, r_outer, r_inner, n=5):
    pts = []
    for i in range(2 * n):
        r = r_outer if i % 2 == 0 else r_inner
        a = math.pi / 2 + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    return pts


def layer(name, draw):
    im = Image.new("L", (W, H), BG)
    d = ImageDraw.Draw(im)
    draw(d)
    im.save(os.path.join(IN_DIR, "demo_%s_Inverted.png" % name))
    print("saved input/ demo_%s_Inverted.png" % name)


def gen_inputs():
    os.makedirs(IN_DIR, exist_ok=True)
    font = _font()
    cx, cy = W / 2, H * 0.42
    heart = heart_points(cx, cy, 16)

    # 铜层：实心心 + 文字 + 星
    def copper(d):
        d.polygon(heart, fill=FG)
        d.text((cx, H * 0.74), "PCB ART", font=font, anchor="mm", fill=FG)
        d.polygon(star_points(cx * 1.72, cy, 34, 14), fill=FG)   # 右上星
        d.polygon(star_points(cx * 0.28, cy, 26, 11), fill=FG)   # 左上星
    layer("Copper", copper)

    # 丝印：心形描边 + 文字
    def silk(d):
        poly = [(int(x), int(y)) for x, y in heart]
        d.polygon(poly, outline=FG, width=3)
        d.text((cx, H * 0.74), "PCB ART", font=font, anchor="mm", fill=FG)
        d.line([(cx * 1.72 - 26, cy), (cx * 1.72 + 26, cy)], fill=FG, width=4)
        d.line([(cx * 0.28 - 20, cy), (cx * 0.28 + 20, cy)], fill=FG, width=4)
    layer("Silk", silk)

    # 阻焊：整片心形开窗区域
    def mask(d):
        d.polygon(heart, fill=FG)
    layer("Mask", mask)

    # 背光：心内 4 颗 LED 透光窗（圆形）
    def backlight(d):
        for fx in (0.82, 1.0, 1.18):
            d.ellipse([cx * fx - 22, cy * 0.9 - 22, cx * fx + 22, cy * 0.9 + 22], fill=FG)
        d.ellipse([cx - 20, cy * 1.22 - 20, cx + 20, cy * 1.22 + 20], fill=FG)
    layer("Backlight", backlight)


CELLS = [
    ("Silk(GTO)", "demo_Silk_Inverted.png",     "demo_Silk.png"),
    ("Mask(GTS)", "demo_Mask_Inverted.png",     "demo_Mask.png"),
    ("Copper(GTL)", "demo_Copper_Inverted.png", "demo_Copper.png"),
    ("Backlight", "demo_Backlight_Inverted.png", "demo_Backlight.png"),
]


def build_overview():
    os.makedirs(PV_DIR, exist_ok=True)
    Hh = 300
    GAP = 10
    try:
        font = ImageFont.truetype("arial.ttf", 22)
    except Exception:
        font = ImageFont.load_default()
    panels = []
    pan_w = 0
    for title, inp, prev in CELLS:
        a = Image.open(os.path.join(IN_DIR, inp)).convert("RGB")
        b = Image.open(os.path.join(PV_DIR, prev)).convert("RGB")
        a = a.resize((round(a.width * Hh / a.height), Hh))
        b = b.resize((round(b.width * Hh / b.height), Hh))
        pad = 14
        w = a.width + b.width + GAP * 3 + pad * 2
        cell = Image.new("RGB", (w, Hh + 56), "white")
        d = ImageDraw.Draw(cell)
        d.text((pad, 8), title, fill="black", font=font)
        d.text((pad + 170, 8), "input  ->  gerber", fill="gray", font=font)
        cell.paste(a, (pad, 40))
        cell.paste(b, (pad + a.width + GAP, 40))
        panels.append(cell)
        pan_w = max(pan_w, w)
    cols, rows = 2, 2
    canvas = Image.new("RGB", (pan_w * cols + GAP * (cols + 1),
                               (Hh + 56) * rows + GAP * (rows + 1)), "#dddddd")
    for i, p in enumerate(panels):
        r, c = divmod(i, cols)
        canvas.paste(p, (GAP + c * (pan_w + GAP), GAP + r * ((Hh + 56) + GAP)))
    canvas.save(os.path.join(PV_DIR, "demo_overview.png"))
    print("overview saved:", os.path.join(PV_DIR, "demo_overview.png"))


if __name__ == "__main__":
    if "--overview" in sys.argv:
        build_overview()
    else:
        gen_inputs()