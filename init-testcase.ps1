# ============================================================
# testcase-creator 一键初始化脚本（Windows PowerShell 版）
# 用法：.\init-testcase.ps1 -TargetDir C:\path\to\your-project
#       .\init-testcase.ps1 -TargetDir . -Sync
#       .\init-testcase.ps1 -TargetDir . -Force
#       .\init-testcase.ps1 -ProjectName _template -TargetDir C:\proj -Sync
# ============================================================

param(
    [string]$ProjectName = "_template",
    [string]$TargetDir = "",
    [switch]$Force,
    [switch]$Sync
)

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-OK   { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Info { param([string]$msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Skip { param([string]$msg) Write-Host "  [SKIP] $msg" -ForegroundColor Yellow }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Force -and $Sync) {
    Write-Warn "同时指定 -Force 与 -Sync 时，以 -Force 为准（会覆盖项目资产）"
    $Sync = $false
}

if (-not $TargetDir) {
    Write-Host "请输入目标项目的绝对路径（直接回车则使用当前目录）：" -ForegroundColor Yellow
    $InputPath = Read-Host
    if (-not $InputPath) {
        $TargetDir = (Get-Location).Path
    } else {
        $TargetDir = $InputPath
    }
}

$TargetDir = (Resolve-Path $TargetDir -ErrorAction SilentlyContinue)?.Path
if (-not $TargetDir -or -not (Test-Path $TargetDir)) {
    Write-Fail "目标路径不存在：$TargetDir"
    exit 1
}

$ProjectDir = Join-Path $ScriptDir "projects\$ProjectName"
if (-not (Test-Path $ProjectDir)) {
    if (Test-Path $ProjectName) {
        $ProjectDir = (Resolve-Path $ProjectName).Path
        $ProjectName = Split-Path $ProjectDir -Leaf
    } else {
        Write-Fail "项目不存在：$ProjectName"
        exit 1
    }
}

Write-Host ""
Write-Color "==========================================" Cyan
Write-Color "   testcase-creator 初始化脚本 (Windows)" Cyan
Write-Color "==========================================" Cyan
Write-Host ""
Write-Host "[DIR] 模板来源：$ScriptDir"
Write-Host "[PROJECT] 项目名称：$ProjectName"
Write-Host "[TARGET] 目标项目：$TargetDir"
if ($Force) {
    Write-Host "[MODE] 强制覆盖（含项目资产）" -ForegroundColor Yellow
} elseif ($Sync) {
    Write-Host "[MODE] 升级同步（保护项目资产）" -ForegroundColor Green
} else {
    Write-Host "[MODE] 首次安装（已存在则跳过）"
}
Write-Host ""

$Confirm = Read-Host "确认将模板文件复制到上述目标路径？(y/N)"
if ($Confirm -notin @("y","Y")) {
    Write-Fail "已取消。"
    exit 0
}

Write-Host ""

function Copy-Asset {
    param(
        [string]$Src,
        [string]$Dst,
        [string]$Label,
        [string]$Kind = "managed"
    )

    if (-not (Test-Path $Src)) {
        Write-Fail "源文件不存在：$Label"
        return
    }

    $FullSrc = (Resolve-Path $Src -ErrorAction SilentlyContinue).Path
    $FullDst = (Resolve-Path $Dst -ErrorAction SilentlyContinue).Path
    if ($FullSrc -and $FullDst -and $FullSrc -eq $FullDst) {
        Write-OK "目标与源相同，无需复制：$Label"
        return
    }

    $DstDir = Split-Path -Parent $Dst
    if (-not (Test-Path $DstDir)) {
        New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
    }

    if (Test-Path $Dst) {
        $allow = $false
        if ($Force) { $allow = $true }
        elseif ($Sync -and $Kind -eq "managed") { $allow = $true }

        if (-not $allow) {
            if ($Sync -and $Kind -eq "project") {
                Write-Skip "项目资产已保护，未覆盖：$Label"
            } else {
                Write-Warn "$Label 已存在，跳过（升级用 -Sync，全量覆盖用 -Force）"
            }
            return
        }

        Copy-Item -Path $Src -Destination $Dst -Force
        if ($Force) { Write-OK "强制覆盖：$Label" } else { Write-OK "已同步：$Label" }
    } else {
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-OK "已复制：$Label"
    }
}

function Copy-TreeFiles {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot,
        [string]$LabelRoot,
        [string]$Kind = "managed"
    )
    if (-not (Test-Path $SourceRoot)) { return }
    Get-ChildItem -Path $SourceRoot -Recurse -File | ForEach-Object {
        $Relative = $_.FullName.Substring((Resolve-Path $SourceRoot).Path.Length).TrimStart('\', '/')
        if ($Relative -eq "settings.local.json" -or $Relative -like "*/settings.local.json" -or $Relative -like "*\settings.local.json") {
            return
        }
        $DestPath = Join-Path $DestinationRoot $Relative
        Copy-Asset $_.FullName $DestPath "$LabelRoot/$($Relative -replace '\\', '/')" $Kind
    }
}

Write-Info "-> 正在构建最新 Skill..."
& python "$ScriptDir\build.py" --clean
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Skill 构建失败"
    exit $LASTEXITCODE
}

Write-Info "-> 正在复制 Agent/Codex Skills..."
Copy-TreeFiles "$ScriptDir\dist\.agents" "$TargetDir\.agents" ".agents" "managed"

Write-Host ""
Write-Info "-> 正在复制 Cursor Skill..."
Copy-TreeFiles "$ScriptDir\dist\.cursor" "$TargetDir\.cursor" ".cursor" "managed"

Write-Host ""
Write-Info "-> 正在复制 Claude Code 命令..."
Copy-TreeFiles "$ScriptDir\dist\.claude" "$TargetDir\.claude" ".claude" "managed"

Write-Host ""
Write-Info "-> 正在复制测试资产目录..."

Copy-TreeFiles "$ScriptDir\framework\templates" "$TargetDir\.testcase-assets\templates" ".testcase-assets/templates" "managed"
Get-ChildItem -Path "$ScriptDir\framework\scripts" -File | ForEach-Object {
    if ($_.Extension -in @(".pyc")) { return }
    Copy-Asset $_.FullName "$TargetDir\.testcase-assets\scripts\$($_.Name)" ".testcase-assets/scripts/$($_.Name)" "managed"
}

Get-ChildItem -Path $ProjectDir -File | ForEach-Object {
    Copy-Asset $_.FullName "$TargetDir\.testcase-assets\$($_.Name)" ".testcase-assets/$($_.Name)" "project"
}

$HistoryDir = "$TargetDir\.testcase-assets\history"
if (-not (Test-Path $HistoryDir)) {
    New-Item -ItemType Directory -Path $HistoryDir -Force | Out-Null
    Write-OK "已创建：.testcase-assets\history\ 目录"
}

$HistoryIndex = "$HistoryDir\history-index.md"
if (-not (Test-Path $HistoryIndex)) {
    $IndexContent = @"
# 用例生成历史索引

> 每次运行 /testcase-creator 自动追加记录。文件按时间倒序排列（最新在前）。

---

| 时间 | 模块 | 用例数 | 运行目录 | 导出文件 |
|------|------|--------|----------|----------|
"@
    Set-Content -Path $HistoryIndex -Value $IndexContent -Encoding UTF8
    Write-OK "已初始化：.testcase-assets\history\history-index.md"
} else {
    Write-OK "保留已有 history-index.md"
}

$GitKeep = "$HistoryDir\.gitkeep"
if (-not (Test-Path $GitKeep)) {
    New-Item -ItemType File -Path $GitKeep -Force | Out-Null
}

function Get-SkillVersion([string]$MetaPath) {
    if (-not (Test-Path $MetaPath)) { return "unknown" }
    $line = Select-String -Path $MetaPath -Pattern 'version:\s*"([^"]+)"' | Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return "unknown"
}

$CreatorVer = Get-SkillVersion "$ScriptDir\skills\testcase-creator\meta.yaml"
$ExportVer = Get-SkillVersion "$ScriptDir\skills\testcase-export\meta.yaml"
$VersionFile = "$TargetDir\.testcase-assets\FRAMEWORK_VERSION"
$SyncedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
@"
# 由 init-testcase 写入；请勿手改业务内容。升级请：init-testcase.ps1 -Sync
testcase-creator=$CreatorVer
testcase-export=$ExportVer
synced_at=$SyncedAt
"@ | Set-Content -Path $VersionFile -Encoding UTF8
Write-OK "已写入：.testcase-assets\FRAMEWORK_VERSION（creator $CreatorVer / export $ExportVer）"

Write-Host ""
Write-Info "-> 正在复制 Codex/纯对话工具指南..."
Copy-Asset "$ScriptDir\TESTCASE_GUIDE.md" "$TargetDir\TESTCASE_GUIDE.md" "TESTCASE_GUIDE.md" "managed"

Write-Host ""
Write-Info "-> 检查 .gitignore..."
$Gitignore = "$TargetDir\.gitignore"
$HistoryPattern = ".testcase-assets/history/"

if (Test-Path $Gitignore) {
    $Content = Get-Content $Gitignore -Raw
    if ($Content -match [regex]::Escape($HistoryPattern)) {
        Write-Warn ".gitignore 已包含 history 目录规则，跳过"
    } else {
        Add-Content -Path $Gitignore -Value "`n# testcase-creator 生成的历史记录（可按需改为 Git 追踪）"
        Add-Content -Path $Gitignore -Value $HistoryPattern
        Write-OK "已追加 .testcase-assets/history/ 到 .gitignore"
    }
} else {
    Write-Warn "未找到 .gitignore，已跳过（可手动添加 .testcase-assets/history/）"
}

Write-Host ""
Write-Info "-> 正在生成 .claude\settings.local.json（根据当前用户动态写入路径）..."

$ClaudeDir = "$TargetDir\.claude"
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

$SettingsFile = "$ClaudeDir\settings.local.json"

$UseWSL = $false
try {
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) { $UseWSL = $true }
} catch {}

if ($UseWSL) {
    $WinUser = $env:USERNAME
    $HomePath = "/mnt/c/Users/$WinUser"
    Write-OK "检测到 WSL，使用 Linux 风格路径：$HomePath"
} else {
    $HomePath = $env:USERPROFILE -replace '\\', '/'
    Write-Warn "未检测到 WSL，使用 Windows 路径：$HomePath"
    Write-Host "         如需 PDF 读取功能，建议安装 WSL 并在其中运行 Claude Code" -ForegroundColor Yellow
}

$SettingsContent = @"
{
  "permissions": {
    "allow": [
      "Bash(pdftotext $HomePath/Downloads/*.pdf -)",
      "Bash(pdftotext $HomePath/Desktop/*.pdf -)",
      "Bash(textutil -convert txt -stdout $HomePath/Downloads/*.docx)",
      "Bash(textutil -convert txt -stdout $HomePath/Desktop/*.docx)",
      "Bash(python3 .testcase-assets/scripts/check_framework_version.py *)",
      "Bash(python3 .testcase-assets/scripts/check_environment.py *)",
      "Bash(python3 .testcase-assets/scripts/gate_stage.py *)",
      "Bash(python3 .testcase-assets/scripts/recommend_checkpoints.py *)",
      "Bash(python3 .testcase-assets/scripts/recommend_history.py *)",
      "Bash(python3 .testcase-assets/scripts/scan_code_scope.py *)",
      "Bash(python3 .testcase-assets/scripts/md_to_json.py .testcase-assets/history/*/2-用例定稿.md .testcase-assets/history/*/export_data.json *)",
      "Bash(python3 .testcase-assets/scripts/export_all.py *)",
      "Bash(python3 .testcase-assets/scripts/merge_cases.py *)",
      "Bash(python3 .testcase-assets/scripts/suggest_assets_from_bugs.py *)",
      "Bash(python3 .testcase-assets/scripts/export_excel.py .testcase-assets/history/*/export_data.json .testcase-assets/history/*/testcases.xlsx)",
      "Bash(python3 .testcase-assets/scripts/export_xmind.py .testcase-assets/history/*/export_data.json .testcase-assets/history/*/testcases.xmind)",
      "Bash(python3 .testcase-assets/scripts/md_to_csv.py .testcase-assets/history/*/2-用例定稿.md .testcase-assets/history/*/jira_export.csv *)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/2-用例定稿.md --audit-output .testcase-assets/history/*/audit-summary.md --strict)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/export_data.json --audit-output .testcase-assets/history/*/audit-summary.md --strict)",
      "Bash(python3 .testcase-assets/scripts/testcase_quality.py .testcase-assets/history/*/export_data.json --audit-output .testcase-assets/history/*/audit-summary.md --xlsx .testcase-assets/history/*/testcases.xlsx --strict)"
    ]
  }
}
"@

Set-Content -Path $SettingsFile -Value $SettingsContent -Encoding UTF8
Write-OK "已生成 .claude\settings.local.json"

Write-Host ""
Write-Color "==========================================" Cyan
if ($Sync) {
    Write-Color " 升级同步完成！" Green
} elseif ($Force) {
    Write-Color " 强制初始化完成！" Green
} else {
    Write-Color " 初始化完成！" Green
}
Write-Color "==========================================" Cyan
Write-Host ""
Write-Host "[DIR] 目标项目结构："
Write-Host "   $TargetDir\"
Write-Host "   +-- .agents\skills\"
Write-Host "   |   +-- source-command-testcase-creator\SKILL.md + references\"
Write-Host "   |   +-- source-command-testcase-export\SKILL.md"
Write-Host "   +-- .cursor\skills\testcase-creator\skill.md"
Write-Host "   +-- .claude\commands\"
Write-Host "   |   +-- testcase-creator.md"
Write-Host "   |   +-- testcase-export.md"
Write-Host "   +-- TESTCASE_GUIDE.md"
Write-Host "   +-- .testcase-assets\"
Write-Host "       +-- FRAMEWORK_VERSION"
Write-Host "       +-- project.config.md               (项目配置，首次使用前必填)"
Write-Host "       +-- checkpoints-index.md"
Write-Host "       +-- review-expectations-index.md"
Write-Host "       +-- templates\"
Write-Host "       +-- scripts\"
Write-Host "       |   +-- testcase_common.py"
Write-Host "       |   +-- md_to_json.py"
Write-Host "       |   +-- export_excel.py"
Write-Host "       |   +-- export_xmind.py"
Write-Host "       |   +-- md_to_csv.py"
Write-Host "       |   +-- testcase_quality.py"
Write-Host "       +-- history\"
Write-Host ""
Write-Host ">> 下一步："
Write-Color "   1. [必填] 编辑 .testcase-assets\project.config.md" Green
Write-Color "   2. [必填] 根据实际业务补充 .testcase-assets\checkpoints-index.md" Green
Write-Color "   3. [环境] 锁定依赖自动安装：openpyxl==3.1.5 json-repair==0.61.2" Yellow
Write-Host "   4. Cursor / Claude Code：输入 /testcase-creator"
Write-Host ""
Write-Color "[TIP] 旧项目升级：.\init-testcase.ps1 -TargetDir <路径> -Sync" Yellow
Write-Host "      （不覆盖 project.config / 检查点 / 历史；-Force 才会覆盖项目资产）"
Write-Host "      本仓库 projects/*：python check_project_copies.py --fix --build 或 ./sync-projects.sh"
Write-Host ""
