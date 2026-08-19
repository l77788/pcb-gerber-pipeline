# ============================================================================
#  demo.ps1 —— 真实施例·一键复现
#
#  用纯 Python 兜底转换器把 examples/demo 里的艺术图完整走一遍：
#    生成输入 -> 四层转 Gerber -> 渲染预览 -> 打包 -> 对照总览图
#
#  用法：powershell -ExecutionPolicy Bypass -File demo.ps1
#  说明：生产打样仍推荐仓库根的 run.ps1（svg-flatten 高保真）；本脚本用于
#        在任意环境（含沙盒）快速复现"有板可看、有币可传"的完整链路。
# ============================================================================

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)   # examples/demo -> 仓库根
$py = "python"

$inDir  = Join-Path $here "input"
$gbDir  = Join-Path $here "gerber"
$pvDir  = Join-Path $here "preview"
$zipPath = Join-Path $gbDir "demo_gerber.zip"

New-Item -ItemType Directory -Force -Path $inDir, $gbDir, $pvDir | Out-Null

Write-Host "==> 1/5 生成四层艺术输入 PNG" -ForegroundColor Cyan
& $py "$here\make_demo.py"
if ($LASTEXITCODE -ne 0) { exit 1 }

# 层 -> 嘉立创扩展名映射（与 png2gerber.ps1 一致）
$layers = @(
    @("Copper",    "GTL"),
    @("Silk",      "GTO"),
    @("Mask",      "GTS"),
    @("Backlight", "gbr")
)

Write-Host "`n==> 2/5 四层转 Gerber（converter.py 兜底）" -ForegroundColor Cyan
$created = @()
foreach ($kv in $layers) {
    $name, $ext = $kv
    $src = Join-Path $inDir "demo_${name}_Inverted.png"
    $dst = Join-Path $gbDir "demo.${ext}"
    Write-Host ("    {0,-10} -> {1}" -f $name, (Split-Path $dst -Leaf))
    & $py "$root\scripts\converter.py" $src $dst "80x60"
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $created += $dst
}

Write-Host "`n==> 3/5 渲染 Gerber 预览" -ForegroundColor Cyan
foreach ($kv in $layers) {
    $name, $ext = $kv
    $src = Join-Path $gbDir "demo.${ext}"
    $dst = Join-Path $pvDir "demo_${name}.png"
    if ($ext -eq "gbr") { $dst = Join-Path $pvDir "demo_Backlight.png" }
    & $py "$root\scripts\renderer.py" $src $dst 10
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host "`n==> 4/5 打包 Gerber" -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$created | Compress-Archive -DestinationPath $zipPath -Force
Write-Host ("    已打包: {0} ({1} KB)" -f $zipPath, [math]::Round((Get-Item $zipPath).Length/1KB,1))

Write-Host "`n==> 5/5 生成输入->Gerber 对照总览图" -ForegroundColor Cyan
& $py "$here\make_demo.py" --overview
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`n完成。产物：" -ForegroundColor Green
Get-ChildItem $gbDir | ForEach-Object { Write-Host ("  - {0}" -f $_.FullName) }
Write-Host ("  - 对照总览: {0}" -f (Join-Path $pvDir "demo_overview.png"))