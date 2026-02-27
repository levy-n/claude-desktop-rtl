<#
.SYNOPSIS
    One-liner installer for claude-desktop-rtl-natilevy
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/natilevy/claude-desktop-rtl/main/install.ps1 | iex
#>

$TmpScript = Join-Path $env:TEMP "claude_rtl_patch_natilevy.ps1"
$RepoUrl = "https://raw.githubusercontent.com/natilevy/claude-desktop-rtl/main/patch.ps1"

Write-Host ""
Write-Host "  Claude Desktop RTL — natilevy" -ForegroundColor Cyan
Write-Host "  Downloading patcher..." -ForegroundColor Gray
Write-Host ""

Invoke-RestMethod -Uri $RepoUrl -OutFile $TmpScript

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    & $TmpScript
} else {
    Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TmpScript`""
}
