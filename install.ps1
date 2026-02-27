<#
.SYNOPSIS
    One-liner installer for claude-desktop-rtl-natilevy
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/mediawave-dev/claude-desktop-rtl-natilevy/master/install.ps1 | iex
#>

$TmpDir = Join-Path $env:TEMP "claude-rtl-natilevy"
$RepoZip = "https://github.com/levy-n/claude-desktop-rtl-natilevy/archive/refs/heads/master.zip"
$ZipPath = Join-Path $env:TEMP "claude-rtl-natilevy.zip"

Write-Host ""
Write-Host "  Claude Desktop RTL — natilevy" -ForegroundColor Cyan
Write-Host "  Downloading full project..." -ForegroundColor Gray
Write-Host ""

# Download and extract full project (includes package.json for local asar)
if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }
Invoke-WebRequest -Uri $RepoZip -OutFile $ZipPath -UseBasicParsing
Expand-Archive -Path $ZipPath -DestinationPath $TmpDir -Force
Remove-Item $ZipPath -Force

# Find the extracted folder (github adds -master suffix)
$ExtractedDir = Get-ChildItem $TmpDir -Directory | Select-Object -First 1
$PatchScript = Join-Path $ExtractedDir.FullName "patch.ps1"

if (-not (Test-Path $PatchScript)) {
    Write-Host "  [X] Download failed — patch.ps1 not found." -ForegroundColor Red
    Exit 1
}

Write-Host "  Downloaded to: $($ExtractedDir.FullName)" -ForegroundColor Gray
Write-Host ""

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    & $PatchScript
} else {
    Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PatchScript`""
}
