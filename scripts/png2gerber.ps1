# ============================================================================
#  png2gerber.ps1 —— 把 PCB_lightgraph 导出的四层 PNG 批量转成 Gerber 并打包 zip
#
#  用法示例：
#    powershell -ExecutionPolicy Bypass -File png2gerber.ps1 -InputDir .\export -Name myboard -Size 80x60 -LineWidth 0.1
#    powershell -ExecutionPolicy Bypass -File png2gerber.ps1 -Name logo -Size 100x70 -SkipZip
#
#  参数说明：
#    -InputDir       PNG 所在目录（默认当前目录）。脚本会自动识别 *_Inverted.png 的层
#    -Name           板名（作为 Gerber 文件前缀，默认 board）
#    -Size           成品尺寸，格式 "宽x高"（mm，默认 80x60）
#    -LineWidth      最小线宽/线距（mm，svg-flatten 的 -d，默认 0.1）
#    -OutputDir      输出目录（默认在 -InputDir 下创建 out_<Name>）
#    -BacklightAsCopper  若指定，把背光层也作为一个独立 .gbr 输出（供参考合并用）
#    -SkipZip        若指定，只转 Gerber、不打包 zip
# ============================================================================

param(
    [string]$InputDir = ".",
    [string]$Name = "board",
    [string]$Size = "80x60",
    [double]$LineWidth = 0.1,
    [string]$OutputDir = "",
    [switch]$BacklightAsCopper,
    [switch]$SkipZip
)

$ErrorActionPreference = "Stop"

# ---------- 0. 前置检查：定位 svg-flatten ----------
# 优先原生命令 svg-flatten；pip --user 安装的 WASM 变体叫 wasi-svg-flatten
$SvgFlatten = $null
foreach ($cand in @('svg-flatten', 'wasi-svg-flatten')) {
    $g = Get-Command $cand -ErrorAction SilentlyContinue
    if ($g) { $SvgFlatten = $g.Source; break }
}
if (-not $SvgFlatten) {
    # Windows 下 pip --user 默认把 WASM 变体装在 %APPDATA%\Python\<ver>\Scripts，直接扫描定位
    $root = Join-Path $env:APPDATA "Python"
    if (Test-Path $root) {
        $hit = Get-ChildItem -Path $root -Recurse -Filter "wasi-svg-flatten.exe" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -match '\\Scripts\\' } | Select-Object -First 1
        if ($hit) { $SvgFlatten = $hit.FullName }
    }
}
if (-not $SvgFlatten) {
    Write-Error "找不到 svg-flatten。请先安装：python -m pip install --user gerbolyze resvg-wasi，并把 pip Scripts 目录加入 PATH。"
    exit 1
}
# 把脚本所在目录加入 PATH，便于 wasm 变体找到 resvg/usvg 等依赖
$scriptDir = Split-Path $SvgFlatten
if ($scriptDir -and $env:PATH -notmatch [regex]::Escape($scriptDir)) {
    $env:PATH = "$scriptDir;$env:PATH"
}
Write-Host "使用转换器: $SvgFlatten"
if ($LineWidth -le 0) { Write-Error "-LineWidth 必须大于 0（mm）。"; exit 1 }

$in = (Resolve-Path $InputDir).Path
$out = if ($OutputDir) { $OutputDir } else { Join-Path $in "out_$Name" }
New-Item -ItemType Directory -Force -Path $out | Out-Null

Write-Host "输入目录: $in"
Write-Host "输出目录: $out"
Write-Host "尺寸: $Size mm | 最小线宽/线距: $LineWidth mm"

# ---------- 1. 收集并识别各层 PNG ----------
$pngs = Get-ChildItem -Path $in -Filter "*_Inverted.png"
if (-not $pngs) { Write-Error "在 $in 下未找到 *_Inverted.png，请确认已用 PCB_lightgraph 导出图纸。"; exit 1 }

# 层名 → 嘉立创扩展名 的识别规则（关键词顺序敏感，背光要在/copper 前判断）
$layerExt = @("Backlight", "Silk", "Mask", "Copper")
$layerMap = @{
    Backlight = "gbr"   # 背光层是铜窗+阻焊开窗的工艺叠加，不单映射一层
    Silk      = "GTO"
    Mask      = "GTS"
    Copper    = "GTL"
}
function Get-LayerFor([string]$fname) {
    $n = $fname.ToLower()
    if ($n -match "backlight|\\bback\\b|led")  { return "Backlight" }
    if ($n -match "silkscreen|silk" -or $n -match "_sto_" -or $n -match "_gto_") { return "Silk" }
    if ($n -match "soldermask|sold\.mask|mask|_gts_") { return "Mask" }
    if ($n -match "copper|bottom|top|_gtl_") { return "Copper" }
    return $null
}

$found = @{}   # 层 -> 文件
$unknown = @()
foreach ($p in $pngs) {
    $layer = Get-LayerFor $p.Name
    if ($layer -and -not $found.ContainsKey($layer)) {
        $found[$layer] = $p.FullName
    }
    elseif (-not $layer) {
        $unknown += $p.Name
    }
}

Write-Host "`n识别到的分层 PNG："
$layerExt | ForEach-Object { 
    if ($found.ContainsKey($_)) { Write-Host ("  [OK]  {0,-10} <- {1}" -f $_, (Split-Path $found[$_] -Leaf)) }
    else                        { Write-Host ("  ---  {0,-10} (未找到)" -f $_) }
}
if ($unknown) { Write-Host "  [??]  以下文件未识别，请人工核对：$($unknown -join ', ')" }

# ---------- 2. 逐层转换 ----------
$common = "--format gerber --force-png --vectorizer binary-contours --size $Size -d $($LineWidth.ToString('0.####')) -p 5"
$created = @()
foreach ($layer in $layerExt) {
    if (-not $found.ContainsKey($layer)) { continue }
    $ext = if ($layer -eq "Backlight" -and -not $BacklightAsCopper) { "gbr" } else { $layerMap[$layer] }
    $outFn = Join-Path $out ("{0}.{1}" -f $Name, $ext)
    Write-Host ("`n==> 转换 {0} -> {1}" -f (Split-Path $found[$layer] -Leaf), $outFn)
    & $SvgFlatten $common.Split(' ') $found[$layer] $outFn
    if ($LASTEXITCODE -ne 0) { Write-Error "转换 $layer 失败（退出码 $LASTEXITCODE）。"; exit 1 }
    $created += $outFn
}

# 背光层提示
if ($found.ContainsKey("Backlight") -and -not $BacklightAsCopper) {
    Write-Warning "背光层已输出为独立 .gbr 参考。透光效果需在 Gerber 里把背光窗口与 Copper/Mask 重叠设计，请先在查看器里核对再下单。"
}

# ---------- 3. 打包 zip ----------
if (-not $SkipZip) {
    $zipPath = Join-Path $out ("{0}_gerber.zip" -f $Name)
    $created | Compress-Archive -DestinationPath $zipPath -Force
    Write-Host "`n已打包: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1KB,1)) KB)"
}

Write-Host "`n完成。请在 Gerber 查看器（嘉立创在线查看器 / gerbv / 立创EDA）逐层检查后再上传嘉立创下单。"