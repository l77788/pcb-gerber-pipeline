# -*- coding: utf-8 -*-
"""把各层 输入PNG 与 转换渲染预览 拼成一张对照总览图。"""
from PIL import Image, ImageDraw, ImageFont
import os

base = "C:/Users/lenovo/AppData/Roaming/TRAE SOLO CN/ModularData/ai-agent/work-mode-projects/6a8507bfc032eb55e7649158/_pg_test"
out_dir = os.path.join(base, "out_test")

cells = [
    ("Silk  (GTO)", "test_Silk_Inverted.png", "preview_Silk_GTO.png"),
    ("Mask  (GTS)", "test_Mask_Inverted.png", "preview_Mask_GTS.png"),
    ("Copper(GTL)", "test_Copper_Inverted.png", "preview_Copper_GTL.png"),
    ("Backlight", "test_Backlight_Inverted.png", "preview_Backlight.png"),
]

H = 280
GAP = 8
try:
    font = ImageFont.truetype("arial.ttf", 20)
except Exception:
    font = ImageFont.load_default()

panel_w = 0
panels = []
for (title, inp, prev) in cells:
    a = Image.open(os.path.join(base, inp)).convert("RGB")
    b = Image.open(os.path.join(out_dir, prev)).convert("RGB")
    a = a.resize((round(a.width * H / a.height), H))
    b = b.resize((round(b.width * H / b.height), H))
    pad = 12
    w = a.width + b.width + GAP * 3 + pad * 2
    cell = Image.new("RGB", (w, H + 54), "white")
    d = ImageDraw.Draw(cell)
    d.text((pad, 8), title, fill="black", font=font)
    d.text((pad + 150, 8), "input -> gerber", fill="gray", font=font)
    cell.paste(a, (pad, 36))
    cell.paste(b, (pad + a.width + GAP, 36))
    d.line([(pad + a.width + GAP / 2, 36), (pad + a.width + GAP / 2, 36 + H)], fill="black", width=2)
    panels.append(cell)
    panel_w = max(panel_w, w)

cols, rows = 2, 2
canvas = Image.new("RGB", (panel_w * cols + GAP * (cols + 1),
                            (H + 54) * rows + GAP * (rows + 1)), "#dddddd")
for i, p in enumerate(panels):
    r, c = divmod(i, cols)
    canvas.paste(p, (GAP + c * (panel_w + GAP), GAP + r * ((H + 54) + GAP)))
canvas.save(os.path.join(out_dir, "gerber_preview_overview.png"))
print("overview saved", canvas.size)