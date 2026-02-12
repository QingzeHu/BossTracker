# BossTracker 打包脚本
# 用法: 在项目根目录运行 .\pack.ps1
# 输出: BossTracker.zip（不含截图、开发文件等）

$addonName = "BossTracker"
$outputZip = "$addonName.zip"

# 排除的文件和目录
$excludes = @(
    "docs",
    ".claude",
    ".git",
    ".gitignore",
    ".gitkeep",
    "CLAUDE.md",
    "pack.ps1",
    "pack.bat",
    "*.zip"
)

# 清理旧zip
if (Test-Path $outputZip) { Remove-Item $outputZip }

# 创建临时目录
$tempDir = Join-Path $env:TEMP "$addonName-pack"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path "$tempDir\$addonName" | Out-Null

# 复制文件，排除不需要的
Get-ChildItem -Path . -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
    $skip = $false
    foreach ($ex in $excludes) {
        if ($relativePath -like "$ex*" -or $relativePath -like "*\$ex*" -or $relativePath -like $ex) {
            $skip = $true
            break
        }
    }
    -not $skip
} | ForEach-Object {
    $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
    $destPath = Join-Path "$tempDir\$addonName" $relativePath
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $_.FullName -Destination $destPath
}

# 压缩
Compress-Archive -Path "$tempDir\$addonName" -DestinationPath $outputZip

# 清理临时目录
Remove-Item $tempDir -Recurse -Force

$fileSize = [math]::Round((Get-Item $outputZip).Length / 1KB, 1)
Write-Host "打包完成: $outputZip ($fileSize KB)" -ForegroundColor Green
