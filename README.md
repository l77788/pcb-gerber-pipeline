# PCB 图片转 Gerber 打样 · 项目归档

把 **PCB_lightgraph** 导出的四层 PNG（丝印 / 阻焊 / 铜层 / 背光）转成标准 **RS-274X Gerber**，打包后上传 **嘉立创** 打样的一整套方案与验证记录。

| 目录/文件 | 说明 |
|-----------|------|
| `docs/gerber-guide/index.html` | 操作手册：安装 → 转换 → 嘉立创下单 全流程 |
| `docs/bvt-selfcheck/index.html` | 自检说明：测试流程、问题定位、结果验证（含对照图） |
| `scripts/png2gerber.ps1` | **正式转换脚本**（调用 `svg-flatten`，自动识别四层并打包 zip） |
| `scripts/converter.py` | 纯 Python 兜底转换器（不依赖 WASM，受限环境可用） |
| `scripts/renderer.py` | Gerber → PNG 预览渲染器（验证用） |
| `scripts/make_overview.py` | 把各层输入与渲染拼接成对照总览图 |
| `testdata/input/` | 四层测试用二值 PNG |
| `testdata/gerber/` | 转换出的四层 Gerber + 打包 zip |
| `testdata/preview/` | 渲染预览图与四层对照总览 |

## 快速上手（常规 Windows）

```powershell
# 1. 安装转换器
python -m pip install --user gerbolyze resvg-wasi

# 2. 把 PCB_lightgraph 导出的四层 PNG 放一个目录，执行转换 + 打包
powershell -ExecutionPolicy Bypass -File scripts/png2gerber.ps1 `
  -InputDir .\你的导出目录 -Name myboard -Size 80x60 -LineWidth 0.1

# 3. 生成的 myboard_gerber.zip 上传嘉立创，先在线查看逐层核对再下单
```

## 受限环境（WASM 不可用）兜底

部分环境（如沙盒）会拦截 `svg-flatten` 的 WASM 文件 IO（报 `os error 63`），此时改用纯 Python 兜底：

```powershell
python scripts/converter.py testdata/input/test_Silk_Inverted.png  out/test.GTO  80x60
python scripts/converter.py testdata/input/test_Mask_Inverted.png  out/test.GTS  80x60
python scripts/converter.py testdata/input/test_Copper_Inverted.png out/test.GTL 80x60
python scripts/renderer.py  out/test.GTO preview.png 10   # 可选：渲染预览验证
Compress-Archive -Path out/*.G* -DestinationPath out/myboard_gerber.zip -Force
```

## 关键结论（详见自检说明）

- **转换链路逻辑通过**：四层自动识别、嘉立创扩展名映射（丝印 `GTO` / 阻焊 `GTS` / 铜层 `GTL`）、命令构造、失败处理均正确。
- **背光层特殊**：透光 = 铜窗 + 阻焊开窗 的工艺叠加，导出为独立 `.gbr`，下单前需人工确认。
- **生产建议**：正式量产用 `png2gerber.ps1 + svg-flatten`；兜底脚本保留作为受限场景验证用。

## 复现自检

`docs/bvt-selfcheck/index.html` 含完整测试记录（含四层「输入 → Gerber」对照总览），测试输入与产物均保留在 `testdata/` 下，可随时重新跑通。