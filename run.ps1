# ============================================================================
#  run.ps1 —— PCB 图片转 Gerber 一键向导（仓库根目录）
#
#  三种用法：
#   1) 交互式向导（双击或在 PowerShell 里直接运行）：
#        自动检查依赖 -> 选择四层 PNG 文件夹 -> 确认参数 -> 转换打包 -> 打开输出
#   2) 非交互调用（参数与 scripts/png2gerber.ps1 一致）：
#        powershell -ExecutionPolicy Bypass -File run.ps1 -InputDir .\export -Name myboard -Size 80x60 -LineWidth 0.1
#   3) 只检查环境：
#        powershell -ExecutionPolicy Bypass -File run.ps1 -CheckOnly
#
#  其它开关：-FixEnv 允许在环境缺失时尝试自动 pip 安装；-NoOpen 转换完不弹输出目录
# ============================================================================

param(
    [string]$InputDir = "",
    [string]$Name = "",
    [string]$Size = "80x60",
    [double]$LineWidth = 0.1,
    [switch]$CheckOnly,
    [switch]$FixEnv,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$core = Join-Path $here "scripts\png2gerber.ps1"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  PCB 图片转 Gerber 一键向导" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# ---------- 1. 环境检查 ----------
function Find-Python {
    foreach ($c in @('python', 'py')) {
        try { $v = & $c -V 2>&1; if ($LASTEXITCODE -eq 0) { return $c } } catch {}
    }
    return $null
}
function Find-SvgFlatten {
    foreach ($cand in @('svg-flatten', 'wasi-svg-flatten')) {
        $g = Get-Command $cand -ErrorAction SilentlyContinue
        if ($g) { return @{ Cmd=$cand; Path=$g.Source } }
    }
    $root = Join-Path $env:APPDATA "Python"
    if (Test-Path $root) {
        $hit = Get-ChildItem -Path $root -Recurse -Filter "wasi-svg-flatten.exe" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -match '\\Scripts\\' } | Select-Object -First 1
        if ($hit) { return @{ Cmd='wasi-svg-flatten'; Path=$hit.FullName } }
    }
    return $null
}

$python = Find-Python
$svg    = Find-SvgFlatten

Write-Host "`n[环境检查]"
if ($python) {
    Write-Host "  [OK]   Python      -> 找到 ($python)" -ForegroundColor Green
} else {
    Write-Host "  [!!]   Python      -> 未找到，请先安装 https://www.python.org/downloads/（勾选 Add to PATH）" -ForegroundColor Yellow
}
if ($svg) {
    Write-Host "  [OK]   svg-flatten -> $($svg.Path)" -ForegroundColor Green
} else {
    Write-Host "  [!!]   svg-flatten -> 未找到（说明 gerbolyze / resvg-wasi 未安装）" -ForegroundColor Yellow
}

if ($CheckOnly) {
    $ok = ($python -and $svg)
    Write-Host ""
    if ($ok) { Write-Host "环境就绪，可以正常转换。"; exit 0 }
    else { Write-Host "环境不完整，见上方 [!!] 提示。可用本向导的 -FixEnv 自动补装。"; exit 1 }
}

$needInstall = (-not $python -or -not $svg)
if ($needInstall) {
    Write-Host ""
    Write-Host "部分依赖缺失。" -ForegroundColor Yellow
    if ($python -and -not $svg) {
        $ans = "y"
        if (-not $FixEnv) {
            $ans = Read-Host "是否用以下命令自动安装转换引擎？[y/N]"
        }
        if ($ans -match '^y') {
            Write-Host "正在安装 gerbolyze 与 resvg-wasi ..."
            & $python -m pip install --user gerbolyze resvg-wasi
            if ($LASTEXITCODE -ne 0) { Write-Error "安装失败，请手动执行：$python -m pip install --user gerbolyze resvg-wasi" }
            $svg = Find-SvgFlatten
            if (-not $svg) { Write-Error "安装后仍未找到 svg-flatten，请把 pip Scripts 目录加入 PATH 后重试。" }
            Write-Host "安装完成。" -ForegroundColor Green
        } else {
            Write-Error "跳过安装。可稍后手动执行：python -m pip install --user gerbolyze resvg-wasi"
        }
    } else {
        Write-Error "Python 不可用，无法自动补装。请先安装 Python 后再运行本向导。"
    }
}

# 把 svg-flatten 所在目录加入 PATH，供 wasm 变体找依赖
if ($svg) {
    $scriptDir = Split-Path $svg.Path
    if ($scriptDir -and $env:PATH -notmatch [regex]::Escape($scriptDir)) {
        $env:PATH = "$scriptDir;$env:PATH"
    }
}

# ---------- 2. 交互式向导 ----------
$isInteractive = [string]::IsNullOrEmpty($InputDir)
if ($isInteractive) {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  请选择包含四层 PNG 的文件夹" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
    } catch {}
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "选择 PCB_lightgraph 导出的四层 PNG 所在文件夹"
    $dlg.SelectedPath = (Get-Location).Path
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "已取消。" -ForegroundColor Yellow; exit 0
    }
    $InputDir = $dlg.SelectedPath
}

$in = (Resolve-Path $InputDir -ErrorAction SilentlyContinue)
if (-not $in) { Write-Error "目录不存在：$InputDir" }
$in = $in.Path

# 自动识别四层，展示给用户
$pngs = Get-ChildItem -Path $in -Filter "*_Inverted.png" -ErrorAction SilentlyContinue
if (-not $pngs) {
    $pngs = Get-ChildItem -Path $in -Filter "*.png" -ErrorAction SilentlyContinue
}
if (-not $pngs) { Write-Error "在 $in 下未找到 PNG 文件。" }

Write-Host "`n识别到的分层 PNG：" -ForegroundColor Cyan
$pngs | ForEach-Object { Write-Host ("  - {0}" -f $_.Name) }

# 交互确认参数（非交互模式使用传入值）
if ($isInteractive) {
    $defaultName = (Split-Path $in -Leaf)
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = Read-Host "板名（用作输出前缀）[默认 $defaultName]"
        if ([string]::IsNullOrEmpty($Name)) { $Name = $defaultName }
    }
    if ([string]::IsNullOrEmpty($Size) -or $Size -eq "80x60") {
        $sz = Read-Host "成品尺寸 宽x高 mm [默认 80x60]"
        if (-not [string]::IsNullOrEmpty($sz)) { $Size = $sz }
    }
    $ws = Read-Host "最小线宽/线距 mm [默认 $LineWidth]"
    if ($ws) { $lw = 0.0; if ([double]::TryParse($ws, [ref]$lw)) { $LineWidth = $lw } }

    Write-Host ""
    Write-Host "确认参数：" -ForegroundColor Cyan
    Write-Host "  -InputDir   = $in"
    Write-Host "  -Name       = $Name"
    Write-Host "  -Size       = $Size"
    Write-Host "  -LineWidth  = $LineWidth"
    $confirm = Read-Host "回车开始转换，输入 n 取消"
    if ($confirm -match '^n') { Write-Host "已取消。"; exit 0 }
}

# 调用核心转换脚本
Write-Host "`n开始转换 ..." 
& powershell -ExecutionPolicy Bypass -File $core -InputDir $in -Name $Name -Size $Size -LineWidth $LineWidth

if ($LASTEXITCODE -ne 0) {
    Write-Host "转换失败，退出码 $LASTEXITCODE。可看上方日志或用 -FixEnv 重试。" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

# 打开输出目录
$outDir = Join-Path $in "out_$Name"
if (-not $NoOpen -and (Test-Path $outDir)) {
    $ans = "y"
    if ($isInteractive) {
        $ans = Read-Host "`n是否打开输出目录？[Y/n]"
    }
    if ($ans -notmatch '^n') {
        Start-Process explorer.exe -ArgumentList "`"$outDir`""
    }
}

Write-Host ""
Write-Host "完成。Gerber 已在: $outDir" -ForegroundColor Green
Write-Host "上传入口：嘉立创下单中心 -> 上传 Gerber（建议先在线逐层核对再付款）。"