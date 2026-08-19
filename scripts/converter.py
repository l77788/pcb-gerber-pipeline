# -*- coding: utf-8 -*-
"""
纯 Python 二值 PNG -> RS-274X Gerber 转换器（Fallback，不依赖 WASM）。
仅用于流程验证演示；生产环境请使用 png2gerber.ps1 + svg-flatten。
用法: python converter.py <input.png> <output.gbr> [WxH_mm]
"""
import sys
from PIL import Image
import numpy as np


def convert(png_path, gbr_path, size_mm="80x60"):
    w, h = (int(x) for x in size_mm.split("x"))
    img = Image.open(png_path).convert("L")
    a = np.array(img)  # shape: HxW
    Hh, Ww = a.shape
    # 白色(>128)为实体层；黑色为空白（与 PCB_lightgraph "反色"位图约定一致）
    white = a > 128
    scale = 1000  # 3 位小数，单位 mm

    def xc(px):
        return round((px + 0.5) * (w / Ww) * scale)

    def yc(py):
        return round((py + 0.5) * (h / Hh) * scale)

    # 行程编码：把每行的白色连续段压成一条水平线段，显著减小文件
    runs = []
    for y in range(Hh):
        row = white[y]
        x = 0
        while x < Ww:
            if row[x]:
                x0 = x
                while x < Ww and row[x]:
                    x += 1
                runs.append((y, x0, x - 1))
            else:
                x += 1

    out = ["%FSLAX3Y3*%", "%MOMM*%", "%IPPOS*%", "%ADD10R,0.1X0.1*%", "G90*", "G01*"]
    for (y, x0, x1) in runs:
        out.append("X%06dY%06dD02*" % (xc(x0), yc(y)))
        out.append("X%06dD01*" % xc(x1))
    out.append("M02*")
    with open(gbr_path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("converted %s -> %s (%d runs)" % (png_path, gbr_path, len(runs)))


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "80x60")