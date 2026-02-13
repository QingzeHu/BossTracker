# BossTracker 版本号自动递增脚本
# 用法:
#   .\bump.ps1 patch   # 0.2.0 → 0.2.1
#   .\bump.ps1 minor   # 0.2.1 → 0.3.0
#   .\bump.ps1 major   # 0.3.0 → 1.0.0
#   .\bump.ps1          # 不带参数则交互式选择

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$BumpType
)

$tocFile = Join-Path $PSScriptRoot "BossTracker.toc"

if (-not (Test-Path $tocFile)) {
    Write-Host "错误: 找不到 $tocFile" -ForegroundColor Red
    exit 1
}

# 读取当前版本号
$tocContent = Get-Content $tocFile -Raw
if ($tocContent -match '## Version:\s*(\d+)\.(\d+)\.(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $oldVersion = "$major.$minor.$patch"
} else {
    Write-Host "错误: .toc 文件中找不到 ## Version 行" -ForegroundColor Red
    exit 1
}

Write-Host "当前版本: $oldVersion" -ForegroundColor Cyan

# 交互式选择
if (-not $BumpType) {
    Write-Host ""
    Write-Host "选择递增类型:"
    Write-Host "  [1] patch  $major.$minor.$($patch+1)  (Bug修复、小调整)" -ForegroundColor Green
    Write-Host "  [2] minor  $major.$($minor+1).0  (新功能)" -ForegroundColor Yellow
    Write-Host "  [3] major  $($major+1).0.0  (重大改动)" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "输入选择 (1/2/3)"
    switch ($choice) {
        "1" { $BumpType = "patch" }
        "2" { $BumpType = "minor" }
        "3" { $BumpType = "major" }
        default {
            Write-Host "已取消" -ForegroundColor Gray
            exit 0
        }
    }
}

# 计算新版本号
switch ($BumpType) {
    "patch" { $patch++ }
    "minor" { $minor++; $patch = 0 }
    "major" { $major++; $minor = 0; $patch = 0 }
}
$newVersion = "$major.$minor.$patch"

# 更新 .toc 文件
$tocContent = $tocContent -replace '## Version:\s*\d+\.\d+\.\d+', "## Version: $newVersion"
Set-Content $tocFile -Value $tocContent -NoNewline

Write-Host ""
Write-Host "$oldVersion → $newVersion ($BumpType)" -ForegroundColor Green

# 询问是否 git commit + tag
$doGit = Read-Host "是否自动 git commit + tag? (y/N)"
if ($doGit -eq "y" -or $doGit -eq "Y") {
    git add $tocFile
    git commit -m "bump: v$newVersion"
    git tag "v$newVersion"
    Write-Host ""
    Write-Host "已提交并打标签 v$newVersion" -ForegroundColor Green
    Write-Host "发布请运行: git push && git push --tags" -ForegroundColor Cyan
}
