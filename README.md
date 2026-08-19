# PCB 图片转 Gerber 打样 · 项目归档

把 **PCB_lightgraph** 导出的四层 PNG（丝印 / 阻焊 / 铜层 / 背光）转成标准 **RS-274X Gerber**，打包后上传 **嘉立创** 打样的一整套方案、脚本与验证记录。

> 浏览器直接看文档入口：👉 **[GitHub Pages](https://l77788.github.io/pcb-gerber-pipeline/)** 👈（收录操作手册 / 自检说明 / 同类调研）
>
> 在线地址（复制时只到这一行为止，不要带上右侧括号内文字）：`https://l77788.github.io/pcb-gerber-pipeline/`

## 目录结构

| 目录/文件 | 说明 |
|-----------|------|
| `index.html` | 文档总入口（GitHub Pages 首页） |
| `run.ps1` | **一键交互式向导**：自动检查依赖 → 选文件夹 → 四层转换 → 打包 → 打开输出 |
| `docs/gerber-guide/index.html` | 操作手册：安装 → 转换 → 嘉立创下单 全流程 |
| `docs/bvt-selfcheck/index.html` | 自检说明：测试流程、问题定位、结果验证（含对照图） |
| `docs/similar-projects/index.html` | 同类开源项目调研：图片转 PCB 方案的对比与选择建议 |
| `scripts/png2gerber.ps1` | **正式转换脚本**（调用 `svg-flatten`，自动识别四层并打包 zip） |
| `scripts/converter.py` | 纯 Python 兜底转换器（不依赖 WASM，受限环境可用） |
| `scripts/renderer.py` | Gerber → PNG 预览渲染器（验证用） |
| `scripts/make_overview.py` | 把各层输入与渲染拼接成对照总览图 |
| `examples/demo/` | **真实施例**：艺术图四层 PNG + `demo.ps1` 一键复现 + 预期 Gerber/预览/对照图 |
| `testdata/` | 自检测试输入 / Gerber / 预览 |
| `.github/workflows/pages.yml` | GitHub Pages 自动部署工作流 |

## 快速上手（常规 Windows）

**方式 A —— 一键向导（推荐）**
```powershell
# 在仓库根目录运行，会自动检查环境、弹窗选文件夹、提示确认参数并转换
powershell -ExecutionPolicy Bypass -File run.ps1
```

**方式 B —— 参数化调用**
```powershell
# 1. 安装转换器
python -m pip install --user gerbolyze resvg-wasi

# 2. 把 PCB_lightgraph 导出的四层 PNG 放一个目录，执行转换 + 打包
powershell -ExecutionPolicy Bypass -File run.ps1 `
  -InputDir .\你的导出目录 -Name myboard -Size 80x60 -LineWidth 0.1
```

3. 生成的 `out_myboard\myboard_gerber.zip` 上传**嘉立创**，先在线查看逐层核对再下单。

## 真实施例（一键复现，任意环境可跑）

`examples/demo/demo.ps1` 用纯 Python 兜底，把一套"心形 + PCB ART"四层艺术图完整走一遍（生成输入 → 转 Gerber → 渲染预览 → 打包 → 对照图），适合快速上手和核对链路：

```powershell
powershell -ExecutionPolicy Bypass -File examples\demo\demo.ps1
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
- **生产建议**：正式量产用 `run.ps1 / png2gerber.ps1 + svg-flatten`；兜底脚本保留作为受限场景验证用。

## 复现自检

`docs/bvt-selfcheck/index.html` 含完整测试记录（含四层「输入 → Gerber」对照总览），测试输入与产物均保留在 `testdata/` 下，可随时重新跑通。