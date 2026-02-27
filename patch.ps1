<#
.SYNOPSIS
    Claude Desktop RTL Patcher — claude-desktop-rtl-natilevy
.DESCRIPTION
    Adds persistent RTL (Right-to-Left) support to Claude Desktop on Windows.
    Hebrew and Arabic text auto-detects direction. Code blocks stay LTR.

    What it does:
    Phase 1: Extract app.asar → inject RTL JavaScript → repack
    Phase 2: Compute ASAR header hash → replace in claude.exe
    Phase 3: Generate self-signed cert → replace in cowork-svc.exe → re-sign both

    Run as Administrator!
.NOTES
    Version: 1.0.0
    Author:  Nati Levy (claude-desktop-rtl-natilevy)
    Based on: shraga100/claude-desktop-rtl-patch
    License: MIT
#>

# -----------------------------------------------------------------------------
# AUTO-ELEVATION
# -----------------------------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $ScriptPath = $MyInvocation.MyCommand.Path
    if ($ScriptPath) {
        Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    } else {
        $TmpScript = Join-Path $env:TEMP "claude_rtl_patch_natilevy.ps1"
        $RepoUrl = "https://raw.githubusercontent.com/natilevy/claude-desktop-rtl/main/patch.ps1"
        Write-Host "Downloading script for elevation..." -ForegroundColor Cyan
        Invoke-RestMethod -Uri $RepoUrl -OutFile $TmpScript
        Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TmpScript`""
    }
    Exit
}

# -----------------------------------------------------------------------------
# GLOBAL SETTINGS
# -----------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$global:TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "claude_rtl_patch_tmp"
$VERSION = "1.0.0"

# -----------------------------------------------------------------------------
# RTL INJECTION PAYLOAD
# -----------------------------------------------------------------------------
$RTL_INJECTION_CODE = @'
// --- CLAUDE RTL PATCH START (claude-desktop-rtl-natilevy v1.0.0) ---
;(function() {
    'use strict';
    if (typeof document === 'undefined') return;
    try {
        const SELECTORS = {
            RESPONSES: '.font-claude-message, .font-claude-message.mx-auto.w-full.max-w-3xl, .font-claude-response-body, .standard-markdown',
            PARAGRAPHS: '.whitespace-pre-wrap.break-words, .grid-cols-1.grid.gap-2\\.5, .standard-markdown.grid-cols-1.grid.gap-4',
            LISTS: 'ol.list-decimal, ul.list-disc, .standard-markdown ol, .standard-markdown ul',
            WRITING: '[data-testid="chat-input"]',
            SETTINGS: '.bg-bg-000.border'
        };

        const RTL_RANGES = [
            { start: 0x0590, end: 0x05FF },
            { start: 0x0600, end: 0x06FF },
            { start: 0x0750, end: 0x077F },
            { start: 0x08A0, end: 0x08FF }
        ];

        function isRTLChar(char) {
            const code = char.charCodeAt(0);
            return RTL_RANGES.some(range => code >= range.start && code <= range.end);
        }

        function shouldBeRTLText(text) {
            if (!text) return false;
            const trimmed = text.trim();
            if (!trimmed) return false;

            let firstStrongIsRTL = null;
            let rtlCount = 0;
            let ltrCount = 0;

            for (const char of trimmed) {
                if (isRTLChar(char)) {
                    rtlCount++;
                    if (firstStrongIsRTL === null) firstStrongIsRTL = true;
                } else if (/\p{L}/u.test(char)) {
                    ltrCount++;
                    if (firstStrongIsRTL === null) firstStrongIsRTL = false;
                }
            }

            if (firstStrongIsRTL === null) return false;
            if (firstStrongIsRTL) return true;

            const totalLetters = rtlCount + ltrCount;
            return totalLetters > 0 && (rtlCount / totalLetters) >= 0.5;
        }

        function forceCodeBlocksLTR(element) {
            const codeBlocks = element.querySelectorAll('pre, code, .code-block__code, .relative.group\\/copy');
            codeBlocks.forEach(block => {
                block.style.direction = 'ltr';
                block.style.textAlign = 'left';
                block.style.unicodeBidi = 'embed';
            });
        }

        function processChildrenForRTL(element) {
            element.querySelectorAll('p, li, h1, h2, h3, h4, h5, h6').forEach(el => {
                if (el.closest(SELECTORS.WRITING)) return;

                if (shouldBeRTLText(el.textContent)) {
                    el.style.direction = 'rtl';
                    el.style.textAlign = 'right';
                    el.style.unicodeBidi = 'plaintext';
                    if (el.tagName === 'LI') {
                        el.style.listStylePosition = 'inside';
                    }
                } else {
                    el.style.direction = '';
                    el.style.textAlign = '';
                    el.style.unicodeBidi = '';
                    if (el.tagName === 'LI') {
                        el.style.listStylePosition = '';
                    }
                }
            });

            element.querySelectorAll('ul, ol').forEach(el => {
                if (el.closest(SELECTORS.WRITING)) return;

                const text = el.textContent || '';
                if (shouldBeRTLText(text)) {
                    el.style.direction = 'rtl';
                    el.style.textAlign = 'right';
                    if (el.classList.contains('pl-7')) {
                        el.style.paddingRight = '1.75rem';
                        el.style.paddingLeft = '0';
                    } else {
                        el.style.paddingRight = '1em';
                        el.style.paddingLeft = '0';
                    }
                } else {
                    el.style.direction = '';
                    el.style.textAlign = '';
                    el.style.paddingRight = '';
                    el.style.paddingLeft = '';
                }
            });
        }

        function processInputBox() {
            const inputs = document.querySelectorAll(SELECTORS.WRITING);
            inputs.forEach(input => {
                const text = input.textContent || input.innerText || '';
                if (shouldBeRTLText(text)) {
                    input.style.direction = 'rtl';
                    input.style.textAlign = 'right';
                    input.style.paddingRight = '25px';
                } else {
                    input.style.direction = 'ltr';
                    input.style.textAlign = 'left';
                    input.style.paddingRight = '';
                }
            });
        }

        function processElements() {
            document.querySelectorAll(SELECTORS.RESPONSES).forEach(el => {
                if (el.closest(SELECTORS.WRITING)) return;
                processChildrenForRTL(el);
                forceCodeBlocksLTR(el);
            });

            document.querySelectorAll(SELECTORS.PARAGRAPHS).forEach(el => {
                if (el.closest(SELECTORS.WRITING)) return;
                if (!el.closest(SELECTORS.RESPONSES)) {
                    if (shouldBeRTLText(el.textContent)) {
                        el.style.direction = 'rtl';
                        el.style.textAlign = 'right';
                    } else {
                        el.style.direction = '';
                        el.style.textAlign = '';
                    }
                }
            });

            processInputBox();
            forceCodeBlocksLTR(document.body);
        }

        function injectGlobalRTLStyles() {
            if (document.getElementById('claude-rtl-global-styles')) return;
            var style = document.createElement('style');
            style.id = 'claude-rtl-global-styles';
            style.textContent = 'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, summary { unicode-bidi: plaintext; direction: auto; } pre, code, .code-block__code, .relative.group\\/copy { unicode-bidi: embed !important; direction: ltr !important; text-align: left !important; }';
            document.head.appendChild(style);
        }

        function init() {
            injectGlobalRTLStyles();
            processElements();

            document.addEventListener('input', function(event) {
                const target = event.target;
                if (target && (target.tagName === 'TEXTAREA' || target.tagName === 'INPUT' || target.isContentEditable)) {
                    const currentText = target.textContent || target.innerText || target.value || '';
                    if (shouldBeRTLText(currentText)) {
                        target.style.direction = 'rtl';
                        target.style.textAlign = 'right';
                        target.style.paddingRight = '25px';
                    } else {
                        target.style.direction = 'ltr';
                        target.style.textAlign = 'left';
                        target.style.paddingRight = '';
                    }
                }
            }, true);

            const observer = new MutationObserver((mutations) => {
                let hasChanges = mutations.some(m => m.addedNodes.length > 0 || m.type === 'characterData');
                if (hasChanges) {
                    clearTimeout(window._rtlProcessTimeout);
                    window._rtlProcessTimeout = setTimeout(() => { processElements(); }, 50);
                }
            });

            observer.observe(document.body, { childList: true, subtree: true, characterData: true });
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', init);
        } else {
            init();
        }
    } catch(e) { console.error("[Claude RTL Error]", e); }
})();
// --- CLAUDE RTL PATCH END ---
'@

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
function Write-Log($msg)     { Write-Host "  [*] $msg" -ForegroundColor Cyan }
function Write-Step($msg)    { Write-Host "`n> $msg" -ForegroundColor Magenta }
function Write-Success($msg) { Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "  [!] $msg" -ForegroundColor Yellow }

function Find-Bytes([byte[]]$Haystack, [byte[]]$Needle, [int]$StartIndex = 0) {
    if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) { return -1 }
    for ($i = $StartIndex; $i -le ($Haystack.Length - $Needle.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) { return $i }
    }
    return -1
}

function Find-ClaudeDir {
    $pkg = Get-AppxPackage | Where-Object { $_.Name -like '*Claude*' -and $_.InstallLocation -like '*WindowsApps*' } | Select-Object -First 1
    if ($pkg) { return $pkg.InstallLocation }
    return $null
}

function Stop-ClaudeServices {
    Write-Step "Stopping Claude Desktop and services..."

    $wmiSvc = Get-WmiObject Win32_Service | Where-Object { $_.PathName -match "cowork-svc" }
    if ($wmiSvc) {
        Write-Log "Stopping service: $($wmiSvc.Name)"
        Stop-Service -Name $wmiSvc.Name -Force -ErrorAction SilentlyContinue
        $timeout = 10
        for ($w = 0; $w -lt $timeout; $w++) {
            $state = (Get-Service -Name $wmiSvc.Name -ErrorAction SilentlyContinue).Status
            if ($state -eq 'Stopped' -or -not $state) { break }
            Start-Sleep -Seconds 1
        }
    }

    foreach ($procName in @("claude", "cowork-svc")) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Log "Killing $($procs.Count) '$procName' process(es)..."
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Seconds 2
    $remaining = Get-Process -Name "cowork-svc" -ErrorAction SilentlyContinue
    if ($remaining) {
        Start-Sleep -Seconds 5
        Stop-Process -Name "cowork-svc" -Force -ErrorAction SilentlyContinue
    }

    Write-Success "Processes and services stopped."
}

function Test-FileLock([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        return $false
    } catch {
        return $true
    }
}

function Wait-FileUnlock([string]$Path, [int]$TimeoutSeconds = 20) {
    if (-not (Test-Path $Path)) { return }
    for ($w = 0; $w -lt $TimeoutSeconds; $w++) {
        if (-not (Test-FileLock $Path)) {
            Write-Log "File unlocked: $(Split-Path $Path -Leaf)"
            return
        }
        if ($w -eq 0) { Write-Log "Waiting for file unlock: $(Split-Path $Path -Leaf)..." }
        Start-Sleep -Seconds 1
    }
    throw "File '$(Split-Path $Path -Leaf)' still locked after ${TimeoutSeconds}s. Try rebooting first."
}

function Start-ClaudeServices {
    Write-Step "Restarting Claude..."

    $wmiSvc = Get-WmiObject Win32_Service | Where-Object { $_.PathName -match "cowork-svc" }
    if ($wmiSvc) {
        $svcName = $wmiSvc.Name
        $currentState = (Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status

        if ($currentState -ne 'Stopped') {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            $stopTimeout = 10
            for ($w = 0; $w -lt $stopTimeout; $w++) {
                if ((Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status -eq 'Stopped') { break }
                Start-Sleep -Seconds 1
            }
        }

        Stop-Process -Name "cowork-svc" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Try {
            Start-Service -Name $svcName -ErrorAction Stop
            $timeout = 15
            for ($w = 0; $w -lt $timeout; $w++) {
                if ((Get-Service -Name $svcName).Status -eq 'Running') {
                    Write-Success "Service '$svcName' is running."
                    break
                }
                Start-Sleep -Seconds 1
            }
        } Catch {
            Write-Warn "Could not start service: $($_.Exception.Message)"
        }
    }

    Try {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like '*Claude*' } | Select-Object -First 1
        if ($pkg) {
            $appId = "$($pkg.PackageFamilyName)!Claude"
            Start-Process "shell:AppsFolder\$appId" -ErrorAction Stop
            Write-Success "Claude Desktop launched."
        }
    } Catch {
        Write-Warn "Could not launch Claude Desktop. Please start it manually."
    }
}

function Take-Ownership($Path) {
    Write-Log "Taking ownership: $Path"
    cmd.exe /c "takeown /F `"$Path`" /R /D Y >nul 2>&1"
    cmd.exe /c "icacls `"$Path`" /grant Administrators:F /T /Q >nul 2>&1"
}

function Compute-AsarHash($AsarPath) {
    $fs = [System.IO.File]::OpenRead($AsarPath)
    $br = New-Object System.IO.BinaryReader($fs)
    $fs.Seek(12, [System.IO.SeekOrigin]::Begin) | Out-Null
    $jsonSize = $br.ReadUInt32()
    if ($jsonSize -le 0 -or $jsonSize -gt 10485760) {
        $fs.Close()
        throw "Abnormal ASAR header size: $jsonSize"
    }
    $jsonBytes = $br.ReadBytes($jsonSize)
    $fs.Close()

    $jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($jsonStr))
    return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
}

# -----------------------------------------------------------------------------
# INSTALL
# -----------------------------------------------------------------------------
function Install-Patch {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Desktop RTL Patcher v$VERSION — natilevy" -ForegroundColor Cyan
    Write-Host "  Installing RTL support..." -ForegroundColor Cyan
    Write-Host "========================================================`n" -ForegroundColor Cyan

    $ClaudeDir = Find-ClaudeDir
    if (-not $ClaudeDir) { throw "Claude Desktop not found." }
    Write-Success "Found: $ClaudeDir"

    $AppDir = Join-Path $ClaudeDir "app"
    $ResourcesDir = Join-Path $AppDir "resources"
    $AsarPath = Join-Path $ResourcesDir "app.asar"
    $ExePath = Join-Path $AppDir "claude.exe"
    $CoworkSvcPath = Join-Path $ResourcesDir "cowork-svc.exe"

    if (-not (Test-Path $AsarPath)) { throw "app.asar not found!" }

    Try {
        cmd.exe /c "npx --yes @electron/asar --version 2>&1" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "fail" }
    } Catch {
        throw "Node.js is required. Install from https://nodejs.org"
    }

    Stop-ClaudeServices

    Write-Step "Taking ownership..."
    Take-Ownership $AppDir
    Take-Ownership $ResourcesDir

    Write-Step "Creating backups..."
    if (-not (Test-Path "$AsarPath.bak")) { Copy-Item $AsarPath "$AsarPath.bak" -Force; Write-Success "app.asar backed up" }
    if (-not (Test-Path "$ExePath.bak") -and (Test-Path $ExePath)) { Copy-Item $ExePath "$ExePath.bak" -Force; Write-Success "claude.exe backed up" }
    if (-not (Test-Path "$CoworkSvcPath.bak") -and (Test-Path $CoworkSvcPath)) { Copy-Item $CoworkSvcPath "$CoworkSvcPath.bak" -Force; Write-Success "cowork-svc.exe backed up" }

    Try {
        # ==== PHASE 1: ASAR INJECTION ====
        Write-Step "Phase 1/3: ASAR Injection"
        $OldHash = Compute-AsarHash $AsarPath
        Write-Log "Original hash: $OldHash"

        if (Test-Path $global:TmpDir) { Remove-Item $global:TmpDir -Recurse -Force }
        Write-Log "Extracting ASAR..."
        cmd.exe /c "npx --yes @electron/asar extract `"$AsarPath`" `"$global:TmpDir`""

        $BuildDir = Join-Path $global:TmpDir ".vite\build"
        if (Test-Path $BuildDir) {
            $JsFiles = Get-ChildItem -Path $BuildDir -Filter "*.js" -Recurse
            $Injected = 0
            foreach ($file in $JsFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -notmatch "CLAUDE RTL PATCH START") {
                    $newContent = $RTL_INJECTION_CODE + "`n" + $content
                    [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
                    $Injected++
                }
            }
            if ($Injected -gt 0) { Write-Success "Injected RTL into $Injected JS files." }
            else { Write-Warn "Already patched or no JS files found." }
        }

        $TmpAsarPath = "$AsarPath.new"
        Write-Log "Repacking ASAR..."
        cmd.exe /c "npx --yes @electron/asar pack `"$global:TmpDir`" `"$TmpAsarPath`""

        $NewHash = Compute-AsarHash $TmpAsarPath
        Write-Log "New hash: $NewHash"
        Move-Item -Path $TmpAsarPath -Destination $AsarPath -Force

        # ==== PHASE 2 & 3: EXE PATCHING ====
        Write-Step "Phase 2/3: Hash + Certificate patching"
        if ((Test-Path $ExePath) -and (Test-Path $CoworkSvcPath)) {

            $SourceSvc = if (Test-Path "$CoworkSvcPath.bak") { "$CoworkSvcPath.bak" } else { $CoworkSvcPath }
            $SourceExe = if (Test-Path "$ExePath.bak") { "$ExePath.bak" } else { $ExePath }

            # Find Anthropic certificate in cowork-svc.exe
            $SvcBytes = [System.IO.File]::ReadAllBytes($SourceSvc)
            $AnchorBytes = [System.Text.Encoding]::ASCII.GetBytes("Anthropic, PBC")

            $StartPos = -1
            $OldCertSize = 0
            $Offset = 0

            while ($true) {
                $AnchorPos = Find-Bytes -Haystack $SvcBytes -Needle $AnchorBytes -StartIndex $Offset
                if ($AnchorPos -eq -1) { break }

                $Limit = [Math]::Max(0, $AnchorPos - 2000)
                for ($i = $AnchorPos; $i -ge $Limit; $i--) {
                    if ($SvcBytes[$i] -eq 0x30 -and $SvcBytes[$i+1] -eq 0x82) {
                        $TotalSize = 4 + (([int]$SvcBytes[$i+2] -shl 8) -bor [int]$SvcBytes[$i+3])
                        if ($TotalSize -gt 500 -and $TotalSize -lt 4000 -and $i -lt $AnchorPos -and ($i + $TotalSize) -gt $AnchorPos) {
                            $StartPos = $i
                            $OldCertSize = $TotalSize
                            break
                        }
                    }
                }
                if ($StartPos -ne -1) { break }
                $Offset = $AnchorPos + 1
            }

            if ($StartPos -eq -1) {
                throw "Anthropic certificate not found in cowork-svc.exe."
            }

            Write-Log "Certificate found at offset 0x$([Convert]::ToString($StartPos, 16)) ($OldCertSize bytes)"

            # Clone original cert subject
            $OriginalSig = Get-AuthenticodeSignature -FilePath $SourceExe
            $CertSubject = "CN=Claude-RTL-Patcher"
            if ($OriginalSig -and $OriginalSig.SignerCertificate) {
                $CertSubject = $OriginalSig.SignerCertificate.Subject
                Write-Log "Cloning cert subject: $CertSubject"
            }

            # Generate self-signed certificate that fits
            $ValidCertFound = $false
            $Attempts = 1
            $MaxAttempts = 10
            $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
            $Store.Open("ReadWrite")

            $Cert = $null
            $NewCertBytes = $null

            while (-not $ValidCertFound -and $Attempts -le $MaxAttempts) {
                Write-Log "Generating certificate (attempt $Attempts)..."
                $Cert = New-SelfSignedCertificate -Subject $CertSubject -Type CodeSigningCert -CertStoreLocation "Cert:\LocalMachine\My" -FriendlyName "Claude_RTL_NatiLevy" -KeyAlgorithm RSA -KeyLength 2048
                $NewCertBytes = $Cert.RawData

                if ($NewCertBytes.Length -le $OldCertSize) {
                    $Store.Add($Cert)
                    $ValidCertFound = $true
                    Write-Success "Certificate fits ($($NewCertBytes.Length) <= $OldCertSize bytes)"
                } else {
                    Write-Warn "Too large ($($NewCertBytes.Length) bytes), retrying..."
                    Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint } | Remove-Item -ErrorAction SilentlyContinue
                    $Attempts++
                }
            }
            $Store.Close()

            if (-not $ValidCertFound) {
                throw "Failed to generate fitting certificate after $MaxAttempts attempts."
            }

            # Replace hash in claude.exe
            Wait-FileUnlock $ExePath
            $ExeBytes = [System.IO.File]::ReadAllBytes($SourceExe)
            $OldHashBytes = [System.Text.Encoding]::ASCII.GetBytes($OldHash)
            $NewHashBytes = [System.Text.Encoding]::ASCII.GetBytes($NewHash)

            $OffsetExe = 0
            $Replacements = 0

            while ($true) {
                $Idx = Find-Bytes -Haystack $ExeBytes -Needle $OldHashBytes -StartIndex $OffsetExe
                if ($Idx -eq -1) { break }
                [Array]::Copy($NewHashBytes, 0, $ExeBytes, $Idx, $NewHashBytes.Length)
                $OffsetExe = $Idx + $OldHashBytes.Length
                $Replacements++
            }

            if ($Replacements -gt 0) {
                [System.IO.File]::WriteAllBytes($ExePath, $ExeBytes)
                Write-Success "Replaced $Replacements hash(es) in claude.exe"
            } else {
                Write-Warn "Hash not found in claude.exe (may already be patched)."
            }

            # Sign claude.exe
            $SignResult = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $Cert -HashAlgorithm SHA256
            if ($SignResult.Status -eq 'Valid') { Write-Success "Signed claude.exe" }
            else { throw "Failed to sign claude.exe: $($SignResult.Status)" }

            # Replace certificate in cowork-svc.exe
            Wait-FileUnlock $CoworkSvcPath
            $Diff = $OldCertSize - $NewCertBytes.Length
            Write-Log "Swapping certificate (padding $Diff bytes)..."

            $PaddedCert = New-Object byte[] $OldCertSize
            [Array]::Copy($NewCertBytes, 0, $PaddedCert, 0, $NewCertBytes.Length)
            [Array]::Copy($PaddedCert, 0, $SvcBytes, $StartPos, $OldCertSize)
            [System.IO.File]::WriteAllBytes($CoworkSvcPath, $SvcBytes)
            Write-Success "Certificate replaced in cowork-svc.exe"

            # Sign cowork-svc.exe
            $SignResult2 = Set-AuthenticodeSignature -FilePath $CoworkSvcPath -Certificate $Cert -HashAlgorithm SHA256
            if ($SignResult2.Status -eq 'Valid') { Write-Success "Signed cowork-svc.exe" }
            else { throw "Failed to sign cowork-svc.exe: $($SignResult2.Status)" }

        } else {
            Write-Warn "claude.exe or cowork-svc.exe not found. Skipping binary patching."
        }

        # ==== CLEANUP & LAUNCH ====
        Write-Step "Phase 3/3: Cleanup & Launch"
        if (Test-Path $global:TmpDir) { Remove-Item $global:TmpDir -Recurse -Force }
        Start-ClaudeServices

        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "  RTL PATCH INSTALLED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "  Hebrew/Arabic text will auto-detect direction." -ForegroundColor Green
        Write-Host "  Code blocks stay left-to-right." -ForegroundColor Green
        Write-Host "========================================================`n" -ForegroundColor Green

    } Catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "`n[X] ERROR: $ErrorMessage" -ForegroundColor Red
        Write-Host "    Rolling back..." -ForegroundColor Yellow
        Restore-Patch -IsRollback
        throw "Installation failed. System restored to original state."
    }
}

# -----------------------------------------------------------------------------
# RESTORE
# -----------------------------------------------------------------------------
function Restore-Patch {
    param([switch]$IsRollback)

    if (-not $IsRollback) {
        Write-Host "`n========================================================" -ForegroundColor Cyan
        Write-Host "  Restoring Claude Desktop to original state..." -ForegroundColor Cyan
        Write-Host "========================================================`n" -ForegroundColor Cyan
    }

    $ClaudeDir = Find-ClaudeDir
    if (-not $ClaudeDir) {
        if ($IsRollback) { Write-Warn "Claude not found during rollback." }
        else { throw "Claude Desktop not found." }
        return
    }

    $AppDir = Join-Path $ClaudeDir "app"
    $ResourcesDir = Join-Path $AppDir "resources"

    Stop-ClaudeServices
    Take-Ownership $AppDir
    Take-Ownership $ResourcesDir

    $Restored = $false
    $FilesToRestore = @(
        @{"Orig" = Join-Path $ResourcesDir "app.asar"; "Bak" = Join-Path $ResourcesDir "app.asar.bak"},
        @{"Orig" = Join-Path $AppDir "claude.exe"; "Bak" = Join-Path $AppDir "claude.exe.bak"},
        @{"Orig" = Join-Path $ResourcesDir "cowork-svc.exe"; "Bak" = Join-Path $ResourcesDir "cowork-svc.exe.bak"}
    )

    foreach ($Item in $FilesToRestore) {
        if (Test-Path $Item["Bak"]) {
            Try {
                Copy-Item $Item["Bak"] $Item["Orig"] -Force -ErrorAction Stop
                Write-Success "Restored $(Split-Path $Item['Orig'] -Leaf)"
                $Restored = $true
            } Catch {
                Write-Warn "Failed to restore $(Split-Path $Item['Orig'] -Leaf): $($_.Exception.Message)"
            }
        }
    }

    # Clean up certificates
    Try {
        Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.FriendlyName -eq 'Claude_RTL_NatiLevy' } | Remove-Item -ErrorAction SilentlyContinue
        Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.FriendlyName -eq 'Claude_RTL_NatiLevy' } | Remove-Item -ErrorAction SilentlyContinue
        Write-Success "Custom certificates removed."
    } Catch {
        Write-Warn "Could not remove some certificates."
    }

    Start-ClaudeServices

    if ($IsRollback) {
        Write-Host "`n  Rollback complete." -ForegroundColor Green
    } elseif ($Restored) {
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "  Claude Desktop restored to original state." -ForegroundColor Green
        Write-Host "========================================================`n" -ForegroundColor Green
    } else {
        Write-Warn "No backups found. Nothing to restore."
    }
}

# -----------------------------------------------------------------------------
# MAIN MENU
# -----------------------------------------------------------------------------
function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  Claude Desktop RTL Patcher v$VERSION" -ForegroundColor Cyan
    Write-Host "  github.com/natilevy/claude-desktop-rtl" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1. Install RTL Patch" -ForegroundColor White
    Write-Host "  2. Restore Original (Remove Patch)" -ForegroundColor White
    Write-Host "  3. Exit" -ForegroundColor White

    $choice = Read-Host "`n  Choice (1/2/3)"

    if ($choice -eq '1' -or $choice -eq '2') {
        Write-Host "`n  This will close Claude Desktop." -ForegroundColor Yellow
        $confirm = Read-Host "  Continue? (Y/n)"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            Write-Host "  Cancelled."
            Start-Sleep -Seconds 2
            Show-Menu
            return
        }

        try {
            if ($choice -eq '1') { Install-Patch }
            else { Restore-Patch }
        } catch {
            Write-Host "`n  $($_.Exception.Message)" -ForegroundColor Red
        }

        Write-Host "`n  Press Enter to exit..."
        $null = Read-Host
    }
    elseif ($choice -eq '3') { Exit }
    else { Show-Menu }
}

Show-Menu
