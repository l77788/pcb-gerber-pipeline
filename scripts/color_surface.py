# -*- coding: utf-8 -*-
"""
color_surface.py —— 单张彩色原图 -> 四层二值 PNG（白=有内容 / 黑=空白）

把"图片上的颜色"映射到 PCB 的 铜 / 阻焊 / 丝印 / 背光 四层，输出可直接喂给
png2gerber.ps1（或 converter.py 兜底）的层图。拆层思路参考 pcb-art（MIT，
https://github.com/Rainbow-prince/pcb-art）的"颜色简化 -> 分离 -> 合并"管线，
这里做成无交互的独立脚本，产出的层命名/极性与本仓库 *_Inverted.png 约定一致。

用法:
  python color_surface.py --image photo.png --name myboard --outdir derived [--scale 0.75]

实现要点:
  * 每个像素映射到最近的一个"调色板色"（RGB 欧氏距离，可编辑 PALETTE）。
  * 每个色块定义它要"涂白（有内容）"哪些层，据此把整图拆成若干 Layer 图。
  * 输出 <outdir>/<name>_<Layer>_Inverted.png，逐像素 0/255。
"""
import argparse
import os

from PIL import Image
import numpy as np

# 层名（输出文件名附加 _Inverted，与 png2gerber.ps1 的识别规则一致）
LAYERS = ["Copper", "Mask", "Silk", "Backlight"]

# 默认调色板：每一项 = (标签, RGB, 要涂白的层列表)
#   Silk     白-丝印文字          -> 只上丝印层
#   Copper   铜色-露铜            -> 铜层
#   Mask     深绿-有阻焊(正片)     -> 阻焊层
#   CuMask   浅绿-阻焊下有铜       -> 铜层 + 阻焊层
#   Back     深蓝-透光窗口        -> 背光层
#   BackTint 紫-半透带色          -> 背光层 + 阻焊层
PALETTE = [
    ("Silk",     (240, 240, 240),            ["Silk"]),
    ("Copper",   (198, 122,  62),            ["Copper"]),
    ("Mask",     ( 40, 100,  46),            ["Mask"]),
    ("CuMask",   (128, 170, 120),            ["Copper", "Mask"]),
    ("Back",     ( 18,  60,  92),            ["Backlight"]),
    ("BackTint", ( 96,  72, 150),            ["Mask", "Backlight"]),
]


def nearest_indices(pixels, palette_rgb):
    """pixels: HxWx3 float; palette_rgb: Px3 float; -> HxW 的最近色索引。"""
    d = ((pixels[:, :, None, :] - palette_rgb[None, None, :, :]) ** 2).sum(axis=-1)
    return d.argmin(axis=-1)


def split(image_path, name, outdir, scale):
    img = Image.open(image_path).convert("RGB")
    if 0 < scale < 1:
        img = img.resize((max(1, round(img.width * scale)),
                          max(1, round(img.height * scale))), Image.NEAREST)
    a = np.asarray(img, dtype=np.float32)

    pal = np.array([c for (_, c, _) in PALETTE], dtype=np.float32)
    idx = nearest_indices(a, pal)

    os.makedirs(outdir, exist_ok=True)
    written = []
    for layer in LAYERS:
        mask = np.zeros(img.size[::-1], dtype=np.uint8)  # (H, W)
        for k, (_, _, layers) in enumerate(PALETTE):
            if layer in layers:
                mask |= (idx == k)
        out = np.where(mask > 0, 255, 0).astype(np.uint8)
        fp = os.path.join(outdir, "%s_%s_Inverted.png" % (name, layer))
        Image.fromarray(out, "L").save(fp)
        count = int(mask.sum())
        written.append((layer, fp, count))
        print("  [%s] %5d 像素  -> %s" % (layer, count, fp))
    return written


def main():
    ap = argparse.ArgumentParser(description="彩色原图 -> 四层二值 PNG")
    ap.add_argument("--image", required=True, help="输入彩色原图路径")
    ap.add_argument("--name", default="board", help="输出文件名的前缀")
    ap.add_argument("--outdir", default="derived", help="四层 PNG 输出目录")
    ap.add_argument("--scale", type=float, default=0.75,
                    help="下采样倍率(0,1]，越小越粗、文件越小；1 不缩放")
    args = ap.parse_args()

    if not (0 < args.scale <= 1):
        raise SystemExit("--scale 必须在 (0,1] 之间")
    print("输入: %s | 名称: %s | 层级: %s" % (args.image, args.name, ", ".join(LAYERS)))
    split(args.image, args.name, args.outdir, args.scale)
    print("完成。层图已写入 %s，可直接接 png2gerber.ps1 转换。" % args.outdir)


if __name__ == "__main__":
    main()