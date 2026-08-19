# ============================================================================
#  image2gerber.ps1 —— 桥接：单张彩色原图 -> 四层 PNG -> Gerber -> zip
#
#  本质是 pcb-art 的"颜色拆层" + 本仓库"PNG→Gerber"两条管线的首尾相接：
#     原图 -> color_surface.py(拆成 Silk/Mask/Copper/Backlight) -> png2gerber.ps1
#
#  用法示例（普通环境，走 svg-flatten 高保真）：
#    powershell -ExecutionPolicy Bypass -File image2gerber.ps1 -Image .\photo.png -Name art -Size 80x60
#
#  受限环境（svg-flatten/WASM 不可用）走纯 Python 兜底：
#    powershell -ExecutionPolicy Bypass -File image2gerber.ps1 -Image .\photo.png -Name art -Size 80x60 -Fallback
#
#  参数说明：
#    -Image        输入彩色原图（必填）
#    -Name         板名，作为文件前缀（默认 board）
#    -Scale        拆层下采样倍率 (0,1]（默认 0.75，越小越粗文件越小）
#    -Size         成品尺寸 "宽x高"（mm，默认 80x60）
#    -LineWidth    最小线宽/线距（mm，默认 0.1）
#    -OutDir       输出目录（默认 与 -Image 同级下的 out_<Name>）
#    -Fallback     若指定，改用 converter.py 纯 Python 转换（不依赖 svg-flatten）
# ============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Image,
    [string]$Name = "board",
    [double]$Scale = 0.75,
    [string]$Size = "80x60",
    [double]$LineWidth = 0.1,
    [string]$OutDir = "",
    [switch]$Fallback
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
$colorSurface = Join-Path $scriptDir "color_surface.py"
$png2gerber   = Join-Path $scriptDir "png2gerber.ps1"
$converter    = Join-Path $scriptDir "converter.py"

if (-not (Test-Path $Image)) { Write-Error "找不到原图: $Image"; exit 1 }
$imageAbs  = (Resolve-Path $Image).Path
$out = if ($OutDir) { $OutDir } else { Join-Path (Split-Path $imageAbs) "out_$Name" }
$derived = Join-Path $out "derived"
New-Item -ItemType Directory -Force -Path $out, $derived | Out-Null

Write-Host "==> 第 1 步：彩色原图 -> 四层 PNG"
Write-Host "    原图: $imageAbs | 层图目录: $derived"
& python $colorSurface --image $imageAbs --name $Name --outdir $derived --scale $Scale
if ($LASTEXITCODE -ne 0) { Write-Error "color_surface.py 运行失败。"; exit 1 }

if ($Fallback) {
    # ---- 兜底路径：converter.py 逐层转 Gerber 并打包 ----
    Write-Host "`n==> 第 2 步（兜底）：converter.py 逐层转换"
    $layerExt = @{ Backlight = "gbr"; Silk = "GTO"; Mask = "GTS"; Copper = "GTL" }
    $created = @()
    foreach ($layer in $layerExt.Keys) {
        $src = Join-Path $derived ("{0}_{1}_Inverted.png" -f $Name, $layer)
        if (-not (Test-Path $src)) { continue }
        $gbr = Join-Path $out ("{0}.{1}" -f $Name, $layerExt[$layer])
        Write-Host ("  {0,-10} -> {1}" -f $layer, $gbr)
        & python $converter $src $gbr $Size
        if ($LASTEXITCODE -ne 0) { Write-Error "转换 $layer 失败。"; exit 1 }
        $created += $gbr
    }
    $zipPath = Join-Path $out ("{0}_gerber.zip" -f $Name)
    $created | Compress-Archive -DestinationPath $zipPath -Force
    Write-Host "`n已打包: $zipPath"
} else {
    # ---- 常规路径：交给 png2gerber.ps1（svg-flatten 高保真） ----
    Write-Host "`n==> 第 2 步：png2gerber.ps1 转换 + 打包"
    & powershell -ExecutionPolicy Bypass -File $png2gerber `
        -InputDir $derived -Name $Name -Size $Size -LineWidth $LineWidth -OutputDir $out
    if ($LASTEXITCODE -ne 0) { Write-Error "png2gerber.ps1 运行失败。"; exit 1 }
}

Write-Host "`n完成。请用 Gerber 查看器逐层核对（尤其阻焊开窗与背光窗口）后再上传嘉立创。"