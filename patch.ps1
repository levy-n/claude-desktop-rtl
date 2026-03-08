<#
.SYNOPSIS
    Claude Desktop RTL Patcher — claude-desktop-rtl
.DESCRIPTION
    Adds persistent RTL (Right-to-Left) support to Claude Desktop on Windows.
    Hebrew and Arabic text auto-detects direction. Code blocks stay LTR.

    What it does:
    Phase 0: Check & install dependencies (Node.js, @electron/asar, Claude Desktop)
    Phase 1: Extract app.asar -> inject RTL JavaScript -> repack
    Phase 2: Compute ASAR header hash -> replace in claude.exe
    Phase 3: Generate self-signed cert -> replace in cowork-svc.exe -> re-sign both

    Run as Administrator!
.NOTES
    Version: 1.1.0
    Author:  Nati Levy (claude-desktop-rtl)
    Based on: shraga100/claude-desktop-rtl-patch (https://github.com/shraga100/claude-desktop-rtl-patch)
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
        $TmpScript = Join-Path $env:TEMP "claude_rtl_patch.ps1"
        $RepoUrl = "https://raw.githubusercontent.com/levy-n/claude-desktop-rtl/master/patch.ps1"
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
$VERSION = "1.1.0"
# Resolve script directory (for local asar fallback)
$global:ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }

# -----------------------------------------------------------------------------
# RTL RENDERER INJECTION PAYLOAD (base64-encoded <script> block)
# Injected into .vite/renderer/*/index.html (Chromium renderer context with DOM)
# Fix by: SpeedGitHub (https://github.com/levy-n/claude-desktop-rtl/issues/1)
# -----------------------------------------------------------------------------
$RTL_RENDERER_B64 = @'
PHNjcmlwdD4KLyoqDQogKiBDbGF1ZGUgRGVza3RvcCBSVEwgSW5qZWN0aW9uIC0gUmVuZGVyZXIgVmVyc2lvbg0KICoNCiAqIFBST0JMRU06DQogKiAgIFRoZSBvcmlnaW5hbCBwYXRjaCBpbmplY3RzIEphdmFTY3JpcHQgaW50byAudml0ZS9idWlsZC8qLmpzIGZpbGVzLg0KICogICBUaGVzZSBhcmUgbWFpbi1wcm9jZXNzIC8gcHJlbG9hZCBzY3JpcHRzIHRoYXQgcnVuIGluIE5vZGUuanMgY29udGV4dC4NCiAqICAgVGhleSBoYXZlIE5PIGFjY2VzcyB0byB0aGUgRE9NIChkb2N1bWVudCwgd2luZG93LCBldGMuKS4NCiAqDQogKiAgIFRoZSBhY3R1YWwgVUkgaXMgcmVuZGVyZWQgYnkgQ2hyb21pdW0gaW4gc2VwYXJhdGUgcmVuZGVyZXIgcHJvY2Vzc2VzLA0KICogICB3aGljaCBsb2FkIEhUTUwgZmlsZXMgZnJvbSAudml0ZS9yZW5kZXJlci8qL2luZGV4Lmh0bWwNCiAqDQogKiBTT0xVVElPTjoNCiAqICAgSW5qZWN0IGEgPHNjcmlwdD4gdGFnIGludG8gdGhlIHJlbmRlcmVyIEhUTUwgZmlsZXMgaW5zdGVhZC4NCiAqICAgVGhpcyBjb2RlIHJ1bnMgaW4gdGhlIGJyb3dzZXIgY29udGV4dCB3aXRoIGZ1bGwgRE9NIGFjY2Vzcy4NCiAqDQogKiBTQUZFVFk6DQogKiAgIC0gV3JhcHBlZCBpbiBET01Db250ZW50TG9hZGVkIHRvIGVuc3VyZSBkb2N1bWVudC5ib2R5IGV4aXN0cw0KICogICAtIHRyeS9jYXRjaCBhcm91bmQgYWxsIG9wZXJhdGlvbnMgdG8gcHJldmVudCBhcHAgY3Jhc2hlcw0KICogICAtIEd1YXJkIHZhcmlhYmxlIChfX3J0bFYxMSkgcHJldmVudHMgZG91YmxlLWV4ZWN1dGlvbg0KICoNCiAqIElOSkVDVElPTiBUQVJHRVQ6DQogKiAgIC52aXRlL3JlbmRlcmVyL21haW5fd2luZG93L2luZGV4Lmh0bWwgICAgICAobWFpbiBjaGF0IHdpbmRvdykNCiAqICAgLnZpdGUvcmVuZGVyZXIvcXVpY2tfd2luZG93L2luZGV4Lmh0bWwgICAgICAocXVpY2sgaW5wdXQpDQogKiAgIC52aXRlL3JlbmRlcmVyL2Fib3V0L2luZGV4Lmh0bWwgICAgICAgICAgICAgKGFib3V0IGRpYWxvZykNCiAqICAgLnZpdGUvcmVuZGVyZXIvZmluZF9pbl9wYWdlL2luZGV4Lmh0bWwgICAgICAoc2VhcmNoIGRpYWxvZykNCiAqDQogKiBJbnNlcnQgYmVmb3JlIDwvaGVhZD4gYXM6IDxzY3JpcHQ+e3RoaXMgY29kZX08L3NjcmlwdD4NCiAqDQogKiBGaXggYnk6IFNwZWVkR2l0SHViIChodHRwczovL2dpdGh1Yi5jb20vbGV2eS1uL2NsYXVkZS1kZXNrdG9wLXJ0bC9pc3N1ZXMvMSkNCiAqLw0KDQo7KGZ1bmN0aW9uICgpIHsNCiAgJ3VzZSBzdHJpY3QnOw0KDQogIC8vIFByZXZlbnQgZG91YmxlLWV4ZWN1dGlvbg0KICBpZiAod2luZG93Ll9fcnRsVjExKSByZXR1cm47DQogIHdpbmRvdy5fX3J0bFYxMSA9IHRydWU7DQoNCiAgZnVuY3Rpb24gaW5pdFJUTCgpIHsNCiAgICB0cnkgew0KICAgICAgaWYgKCFkb2N1bWVudC5ib2R5KSByZXR1cm47DQoNCiAgICAgIC8vID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KICAgICAgLy8gMS4gSU5KRUNUIEdMT0JBTCBDU1MgUlVMRVMNCiAgICAgIC8vID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KICAgICAgdmFyIHN0eWxlID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc3R5bGUnKTsNCiAgICAgIHN0eWxlLmlkID0gJ3J0bC12MTEnOw0KICAgICAgc3R5bGUudGV4dENvbnRlbnQgPSBbDQogICAgICAgIC8vIFJUTCBlbGVtZW50cyBhbGlnbiByaWdodA0KICAgICAgICAnW2Rpcj1ydGxdIHsgdGV4dC1hbGlnbjogcmlnaHQgIWltcG9ydGFudCB9JywNCiAgICAgICAgJ1tkaXI9bHRyXSB7IHRleHQtYWxpZ246IGxlZnQgIWltcG9ydGFudCB9JywNCg0KICAgICAgICAvLyBSVEwgbGlzdHM6IGZsaXAgcGFkZGluZw0KICAgICAgICAndWxbZGlyPXJ0bF0sIG9sW2Rpcj1ydGxdIHsgcGFkZGluZy1yaWdodDogMnJlbSAhaW1wb3J0YW50OyBwYWRkaW5nLWxlZnQ6IDAgIWltcG9ydGFudCB9JywNCg0KICAgICAgICAvLyBSVEwgYmxvY2txdW90ZXM6IGJvcmRlciBvbiByaWdodCBzaWRlDQogICAgICAgICdibG9ja3F1b3RlW2Rpcj1ydGxdIHsnLA0KICAgICAgICAnICBib3JkZXItbGVmdDogbm9uZSAhaW1wb3J0YW50OycsDQogICAgICAgICcgIGJvcmRlci1yaWdodDogM3B4IHNvbGlkICM1NjU4NjkgIWltcG9ydGFudDsnLA0KICAgICAgICAnICBwYWRkaW5nLWxlZnQ6IDAgIWltcG9ydGFudDsnLA0KICAgICAgICAnICBwYWRkaW5nLXJpZ2h0OiAxZW0gIWltcG9ydGFudCcsDQogICAgICAgICd9JywNCg0KICAgICAgICAvLyBGb3JjZSBjb2RlIGJsb2NrcyB0byBzdGF5IExUUg0KICAgICAgICAncHJlLCBwcmUgKiwgY29kZSwgY29kZSAqLCcsDQogICAgICAgICdbY2xhc3MqPWNvZGVdICosIFtjbGFzcyo9Q29kZV0gKiwnLA0KICAgICAgICAnW2NsYXNzKj1obGpzXSAqLCBbZGF0YS1sYW5ndWFnZV0gKiwnLA0KICAgICAgICAnW2NsYXNzKj1sYW5ndWFnZS1dICosJywNCiAgICAgICAgJ2tiZCwgc2FtcCwgdmFyLCBzdmcsIHN2ZyAqIHsnLA0KICAgICAgICAnICBkaXJlY3Rpb246IGx0ciAhaW1wb3J0YW50OycsDQogICAgICAgICcgIHVuaWNvZGUtYmlkaTogZW1iZWQgIWltcG9ydGFudDsnLA0KICAgICAgICAnICB0ZXh0LWFsaWduOiBsZWZ0ICFpbXBvcnRhbnQnLA0KICAgICAgICAnfScsDQoNCiAgICAgICAgLy8gSW5wdXQgZmllbGRzOiBhdXRvLWRldGVjdCBkaXJlY3Rpb24NCiAgICAgICAgJ3RleHRhcmVhLCBbY29udGVudGVkaXRhYmxlPXRydWVdLCBbcm9sZT10ZXh0Ym94XSB7JywNCiAgICAgICAgJyAgdW5pY29kZS1iaWRpOiBwbGFpbnRleHQnLA0KICAgICAgICAnfScNCiAgICAgIF0uam9pbignXG4nKTsNCiAgICAgIGRvY3VtZW50LmhlYWQuYXBwZW5kQ2hpbGQoc3R5bGUpOw0KDQogICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiAgICAgIC8vIDIuIFVOSUNPREUgUkFOR0UgVEFCTEVTDQogICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICAgICAgLy8gUlRMIHNjcmlwdCByYW5nZXMgKEhlYnJldywgQXJhYmljLCBleHRlbmRlZCBBcmFiaWMpDQogICAgICB2YXIgUlRMX1JBTkdFUyA9IFsNCiAgICAgICAgWzB4MDU5MCwgMHgwNUZGXSwgICAvLyBIZWJyZXcNCiAgICAgICAgWzB4MDYwMCwgMHgwNkZGXSwgICAvLyBBcmFiaWMNCiAgICAgICAgWzB4MDc1MCwgMHgwNzdGXSwgICAvLyBBcmFiaWMgU3VwcGxlbWVudA0KICAgICAgICBbMHgwOEEwLCAweDA4RkZdLCAgIC8vIEFyYWJpYyBFeHRlbmRlZC1BDQogICAgICAgIFsweEZCNTAsIDB4RkRGRl0sICAgLy8gQXJhYmljIFByZXNlbnRhdGlvbiBGb3Jtcy1BDQogICAgICAgIFsweEZFNzAsIDB4RkVGRl0gICAgLy8gQXJhYmljIFByZXNlbnRhdGlvbiBGb3Jtcy1CDQogICAgICBdOw0KDQogICAgICAvLyBMVFIgc2NyaXB0IHJhbmdlcyAoTGF0aW4pDQogICAgICB2YXIgTFRSX1JBTkdFUyA9IFsNCiAgICAgICAgWzB4NDEsIDB4NUFdLCAgICAgICAvLyBBLVoNCiAgICAgICAgWzB4NjEsIDB4N0FdICAgICAgICAvLyBhLXoNCiAgICAgIF07DQoNCiAgICAgIGZ1bmN0aW9uIGluUmFuZ2UoY29kZVBvaW50LCByYW5nZXMpIHsNCiAgICAgICAgcmV0dXJuIHJhbmdlcy5zb21lKGZ1bmN0aW9uIChyKSB7DQogICAgICAgICAgcmV0dXJuIGNvZGVQb2ludCA+PSByWzBdICYmIGNvZGVQb2ludCA8PSByWzFdOw0KICAgICAgICB9KTsNCiAgICAgIH0NCg0KICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogICAgICAvLyAzLiBESVJFQ1RJT04gREVURUNUSU9ODQogICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICAgICAgLyoqDQogICAgICAgKiBEZXRlY3QgdGV4dCBkaXJlY3Rpb24gYmFzZWQgb24gZmlyc3Qgc3Ryb25nIGRpcmVjdGlvbmFsIGNoYXJhY3Rlci4NCiAgICAgICAqIFJldHVybnMgJ3J0bCcsICdsdHInLCBvciBudWxsIGlmIG5vIHN0cm9uZyBjaGFyYWN0ZXJzIGZvdW5kLg0KICAgICAgICovDQogICAgICBmdW5jdGlvbiBkZXRlY3REaXJlY3Rpb24odGV4dCkgew0KICAgICAgICBpZiAoIXRleHQpIHJldHVybiBudWxsOw0KICAgICAgICAvLyBTdHJpcCB3aGl0ZXNwYWNlLCBkaWdpdHMsIGFuZCBjb21tb24gcHVuY3R1YXRpb24NCiAgICAgICAgdGV4dCA9IHRleHQucmVwbGFjZSgvW1xzXGRcdTAwMjAtXHUwMDQwXHUwMDVCLVx1MDA2MFx1MDA3Qi1cdTAwQkZdL2csICcnKTsNCiAgICAgICAgLy8gQ2hlY2sgZmlyc3QgMTAwIGNoYXJhY3RlcnMgZm9yIHBlcmZvcm1hbmNlDQogICAgICAgIGZvciAodmFyIGkgPSAwOyBpIDwgTWF0aC5taW4odGV4dC5sZW5ndGgsIDEwMCk7IGkrKykgew0KICAgICAgICAgIHZhciBjcCA9IHRleHQuY29kZVBvaW50QXQoaSk7DQogICAgICAgICAgaWYgKGluUmFuZ2UoY3AsIFJUTF9SQU5HRVMpKSByZXR1cm4gJ3J0bCc7DQogICAgICAgICAgaWYgKGluUmFuZ2UoY3AsIExUUl9SQU5HRVMpKSByZXR1cm4gJ2x0cic7DQogICAgICAgIH0NCiAgICAgICAgcmV0dXJuIG51bGw7DQogICAgICB9DQoNCiAgICAgIC8vID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KICAgICAgLy8gNC4gQ09ERSBCTE9DSyBERVRFQ1RJT04NCiAgICAgIC8vID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQogICAgICAvKioNCiAgICAgICAqIENoZWNrIGlmIGVsZW1lbnQgaXMgaW5zaWRlIGEgY29kZSBibG9jaywgbWF0aCBmb3JtdWxhLCBvciBTVkcuDQogICAgICAgKiBUaGVzZSBzaG91bGQgYWx3YXlzIHJlbWFpbiBMVFIuDQogICAgICAgKi8NCiAgICAgIGZ1bmN0aW9uIGlzQ29kZUNvbnRleHQoZWwpIHsNCiAgICAgICAgcmV0dXJuIGVsICYmIGVsLmNsb3Nlc3QgJiYgISFlbC5jbG9zZXN0KA0KICAgICAgICAgICdwcmUsIGNvZGUsIFtjbGFzcyo9Y29kZV0sIFtjbGFzcyo9Q29kZV0sICcgKw0KICAgICAgICAgICdbZGF0YS1sYW5ndWFnZV0sIFtjbGFzcyo9bGFuZ3VhZ2UtXSwgJyArDQogICAgICAgICAgJy5rYXRleCwgLk1hdGhKYXgsIHN2ZycNCiAgICAgICAgKTsNCiAgICAgIH0NCg0KICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogICAgICAvLyA1LiBET00gUFJPQ0VTU0lORw0KICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQoNCiAgICAgIC8vIElubGluZSBlbGVtZW50cyB0aGF0IHNob3VsZCBOT1QgYmUgdHJlYXRlZCBhcyBibG9jayBjb250YWluZXJzLg0KICAgICAgdmFyIElOTElORV9UQUdTID0gWw0KICAgICAgICAnU1BBTicsICdTVFJPTkcnLCAnRU0nLCAnQicsICdJJywgJ0EnLCAnTUFSSycsICdTTUFMTCcsDQogICAgICAgICdTVUInLCAnU1VQJywgJ0FCQlInLCAnQ0lURScsICdERUwnLCAnSU5TJywgJ1MnLCAnVScsICdCUicNCiAgICAgIF07DQoNCiAgICAgIC8qKg0KICAgICAgICogV2FsayBhbGwgdGV4dCBub2RlcyBpbiB0aGUgZG9jdW1lbnQuDQogICAgICAgKiBGb3IgZWFjaCB0ZXh0IG5vZGUgd2l0aCBkaXJlY3Rpb25hbCBjb250ZW50Og0KICAgICAgICogICAxLiBGaW5kIHRoZSBuZWFyZXN0IGJsb2NrLWxldmVsIGFuY2VzdG9yDQogICAgICAgKiAgIDIuIFNldCBkaXIsIGRpcmVjdGlvbiwgdW5pY29kZS1iaWRpLCB0ZXh0LWFsaWduDQogICAgICAgKiAgIDMuIFdhbGsgdXAgdG8gNCBwYXJlbnQgbGV2ZWxzIHRvIHNldCBkaXJlY3Rpb24gb24NCiAgICAgICAqICAgICAgY29udGFpbmVyIGVsZW1lbnRzIChVTCwgT0wsIEJMT0NLUVVPVEUsIERJVikNCiAgICAgICAqLw0KICAgICAgZnVuY3Rpb24gcHJvY2Vzc0VsZW1lbnRzKCkgew0KICAgICAgICB0cnkgew0KICAgICAgICAgIGlmICghZG9jdW1lbnQuYm9keSkgcmV0dXJuOw0KDQogICAgICAgICAgdmFyIHdhbGtlciA9IGRvY3VtZW50LmNyZWF0ZVRyZWVXYWxrZXIoDQogICAgICAgICAgICBkb2N1bWVudC5ib2R5LA0KICAgICAgICAgICAgTm9kZUZpbHRlci5TSE9XX1RFWFQsDQogICAgICAgICAgICBudWxsLA0KICAgICAgICAgICAgZmFsc2UNCiAgICAgICAgICApOw0KDQogICAgICAgICAgdmFyIG5vZGU7DQogICAgICAgICAgd2hpbGUgKG5vZGUgPSB3YWxrZXIubmV4dE5vZGUoKSkgew0KICAgICAgICAgICAgdmFyIHRleHQgPSBub2RlLnRleHRDb250ZW50Ow0KICAgICAgICAgICAgaWYgKCF0ZXh0IHx8ICF0ZXh0LnRyaW0oKSkgY29udGludWU7DQoNCiAgICAgICAgICAgIHZhciBkaXIgPSBkZXRlY3REaXJlY3Rpb24odGV4dCk7DQogICAgICAgICAgICBpZiAoIWRpcikgY29udGludWU7DQoNCiAgICAgICAgICAgIC8vIFNraXAgY29kZSBibG9ja3MNCiAgICAgICAgICAgIHZhciBlbCA9IG5vZGUucGFyZW50RWxlbWVudDsNCiAgICAgICAgICAgIGlmICghZWwgfHwgaXNDb2RlQ29udGV4dChlbCkpIGNvbnRpbnVlOw0KDQogICAgICAgICAgICAvLyBXYWxrIHVwIHBhc3QgaW5saW5lIGVsZW1lbnRzIHRvIGZpbmQgYmxvY2sgcGFyZW50DQogICAgICAgICAgICB2YXIgYmxvY2sgPSBlbDsNCiAgICAgICAgICAgIHdoaWxlIChibG9jayAmJiBJTkxJTkVfVEFHUy5pbmRleE9mKGJsb2NrLnRhZ05hbWUpICE9PSAtMSkgew0KICAgICAgICAgICAgICBibG9jayA9IGJsb2NrLnBhcmVudEVsZW1lbnQ7DQogICAgICAgICAgICB9DQogICAgICAgICAgICBpZiAoIWJsb2NrIHx8IGJsb2NrID09PSBkb2N1bWVudC5ib2R5KSBjb250aW51ZTsNCiAgICAgICAgICAgIGlmIChpc0NvZGVDb250ZXh0KGJsb2NrKSkgY29udGludWU7DQoNCiAgICAgICAgICAgIC8vIEFwcGx5IGRpcmVjdGlvbiB0byBibG9jayBlbGVtZW50DQogICAgICAgICAgICBibG9jay5zZXRBdHRyaWJ1dGUoJ2RpcicsIGRpcik7DQogICAgICAgICAgICBibG9jay5zdHlsZS5kaXJlY3Rpb24gPSBkaXI7DQogICAgICAgICAgICBibG9jay5zdHlsZS51bmljb2RlQmlkaSA9ICdwbGFpbnRleHQnOw0KICAgICAgICAgICAgYmxvY2suc3R5bGUudGV4dEFsaWduID0gZGlyID09PSAncnRsJyA/ICdyaWdodCcgOiAnbGVmdCc7DQoNCiAgICAgICAgICAgIC8vIFdhbGsgdXAgdG8gNCBwYXJlbnQgbGV2ZWxzIGZvciBjb250YWluZXIgZWxlbWVudHMNCiAgICAgICAgICAgIHZhciBwYXJlbnQgPSBibG9jay5wYXJlbnRFbGVtZW50Ow0KICAgICAgICAgICAgdmFyIGxldmVscyA9IDA7DQogICAgICAgICAgICB3aGlsZSAocGFyZW50ICYmIGxldmVscyA8IDQgJiYgcGFyZW50ICE9PSBkb2N1bWVudC5ib2R5KSB7DQogICAgICAgICAgICAgIGlmIChpc0NvZGVDb250ZXh0KHBhcmVudCkpIGJyZWFrOw0KICAgICAgICAgICAgICB2YXIgdGFnID0gcGFyZW50LnRhZ05hbWU7DQogICAgICAgICAgICAgIGlmICh0YWcgPT09ICdVTCcgfHwgdGFnID09PSAnT0wnIHx8IHRhZyA9PT0gJ0JMT0NLUVVPVEUnIHx8IHRhZyA9PT0gJ0RJVicpIHsNCiAgICAgICAgICAgICAgICBwYXJlbnQuc2V0QXR0cmlidXRlKCdkaXInLCBkaXIpOw0KICAgICAgICAgICAgICAgIHBhcmVudC5zdHlsZS5kaXJlY3Rpb24gPSBkaXI7DQogICAgICAgICAgICAgICAgcGFyZW50LnN0eWxlLnRleHRBbGlnbiA9IGRpciA9PT0gJ3J0bCcgPyAncmlnaHQnIDogJ2xlZnQnOw0KICAgICAgICAgICAgICB9DQogICAgICAgICAgICAgIHBhcmVudCA9IHBhcmVudC5wYXJlbnRFbGVtZW50Ow0KICAgICAgICAgICAgICBsZXZlbHMrKzsNCiAgICAgICAgICAgIH0NCiAgICAgICAgICB9DQogICAgICAgIH0gY2F0Y2ggKGUpIHsNCiAgICAgICAgICBjb25zb2xlLmVycm9yKCdbUlRMIHByb2NdJywgZSk7DQogICAgICAgIH0NCiAgICAgIH0NCg0KICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogICAgICAvLyA2LiBJTlBVVCBIQU5ETEVSDQogICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICAgICAgZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcignaW5wdXQnLCBmdW5jdGlvbiAoZSkgew0KICAgICAgICB0cnkgew0KICAgICAgICAgIHZhciB0YXJnZXQgPSBlLnRhcmdldDsNCiAgICAgICAgICBpZiAoIXRhcmdldCkgcmV0dXJuOw0KICAgICAgICAgIGlmICh0YXJnZXQudGFnTmFtZSA9PT0gJ1RFWFRBUkVBJyB8fCB0YXJnZXQudGFnTmFtZSA9PT0gJ0lOUFVUJyB8fCB0YXJnZXQuaXNDb250ZW50RWRpdGFibGUpIHsNCiAgICAgICAgICAgIHZhciB0ZXh0ID0gdGFyZ2V0LnRleHRDb250ZW50IHx8IHRhcmdldC5pbm5lclRleHQgfHwgdGFyZ2V0LnZhbHVlIHx8ICcnOw0KICAgICAgICAgICAgdmFyIGRpciA9IGRldGVjdERpcmVjdGlvbih0ZXh0KTsNCiAgICAgICAgICAgIGlmIChkaXIpIHsNCiAgICAgICAgICAgICAgdGFyZ2V0LnNldEF0dHJpYnV0ZSgnZGlyJywgZGlyKTsNCiAgICAgICAgICAgICAgdGFyZ2V0LnN0eWxlLmRpcmVjdGlvbiA9IGRpcjsNCiAgICAgICAgICAgICAgdGFyZ2V0LnN0eWxlLnRleHRBbGlnbiA9IGRpciA9PT0gJ3J0bCcgPyAncmlnaHQnIDogJ2xlZnQnOw0KICAgICAgICAgICAgfQ0KICAgICAgICAgIH0NCiAgICAgICAgfSBjYXRjaCAoZSkgeyAvKiBzd2FsbG93IGlucHV0IGVycm9ycyAqLyB9DQogICAgICB9LCB0cnVlKTsNCg0KICAgICAgLy8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQogICAgICAvLyA3LiBNVVRBVElPTiBPQlNFUlZFUiAoZm9yIHN0cmVhbWluZyByZXNwb25zZXMpDQogICAgICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICAgICAgdmFyIGRlYm91bmNlVGltZXIgPSBudWxsOw0KICAgICAgbmV3IE11dGF0aW9uT2JzZXJ2ZXIoZnVuY3Rpb24gKG11dGF0aW9ucykgew0KICAgICAgICB2YXIgaGFzQ2hhbmdlcyA9IGZhbHNlOw0KICAgICAgICBmb3IgKHZhciBpID0gMDsgaSA8IG11dGF0aW9ucy5sZW5ndGg7IGkrKykgew0KICAgICAgICAgIGlmIChtdXRhdGlvbnNbaV0uYWRkZWROb2Rlcy5sZW5ndGggfHwgbXV0YXRpb25zW2ldLnR5cGUgPT09ICdjaGFyYWN0ZXJEYXRhJykgew0KICAgICAgICAgICAgaGFzQ2hhbmdlcyA9IHRydWU7DQogICAgICAgICAgICBicmVhazsNCiAgICAgICAgICB9DQogICAgICAgIH0NCiAgICAgICAgaWYgKGhhc0NoYW5nZXMpIHsNCiAgICAgICAgICBjbGVhclRpbWVvdXQoZGVib3VuY2VUaW1lcik7DQogICAgICAgICAgZGVib3VuY2VUaW1lciA9IHNldFRpbWVvdXQocHJvY2Vzc0VsZW1lbnRzLCAxMDApOw0KICAgICAgICB9DQogICAgICB9KS5vYnNlcnZlKGRvY3VtZW50LmJvZHksIHsNCiAgICAgICAgY2hpbGRMaXN0OiB0cnVlLA0KICAgICAgICBzdWJ0cmVlOiB0cnVlLA0KICAgICAgICBjaGFyYWN0ZXJEYXRhOiB0cnVlDQogICAgICB9KTsNCg0KICAgICAgLy8gSW5pdGlhbCBwcm9jZXNzaW5nDQogICAgICBwcm9jZXNzRWxlbWVudHMoKTsNCiAgICAgIGNvbnNvbGUubG9nKCdbUlRMIHYxMV0gQWN0aXZlJyk7DQoNCiAgICB9IGNhdGNoIChlKSB7DQogICAgICBjb25zb2xlLmVycm9yKCdbUlRMIHYxMSBpbml0XScsIGUpOw0KICAgIH0NCiAgfQ0KDQogIC8vID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KICAvLyA4LiBFTlRSWSBQT0lOVA0KICAvLyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KICBpZiAoZG9jdW1lbnQucmVhZHlTdGF0ZSA9PT0gJ2xvYWRpbmcnKSB7DQogICAgZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcignRE9NQ29udGVudExvYWRlZCcsIGluaXRSVEwpOw0KICB9IGVsc2Ugew0KICAgIGluaXRSVEwoKTsNCiAgfQ0KDQp9KSgpOw0KCjwvc2NyaXB0Pg==
'@

# -----------------------------------------------------------------------------
# RTL INJECTION PAYLOAD (legacy - kept for .vite/build/*.js, harmless no-op)
# -----------------------------------------------------------------------------
$RTL_INJECTION_CODE = @'
// --- CLAUDE RTL PATCH START (claude-desktop-rtl v1.0.0) ---
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

# -----------------------------------------------------------------------------
# DEPENDENCY MANAGEMENT
# -----------------------------------------------------------------------------
function Ensure-Dependencies {
    <#
    .SYNOPSIS
        Checks all required dependencies and installs missing ones automatically.
        Returns the path to the asar executable.
    #>
    Write-Step "Checking dependencies..."

    $AllGood = $true

    # --- 1. Claude Desktop ---
    $claudePkg = Get-AppxPackage | Where-Object { $_.Name -like '*Claude*' } | Select-Object -First 1
    if ($claudePkg) {
        Write-Success "Claude Desktop: v$($claudePkg.Version)"
    } else {
        Write-Host ""
        Write-Host "  [X] Claude Desktop is NOT installed!" -ForegroundColor Red
        Write-Host "      Install from: https://claude.ai/download" -ForegroundColor Yellow
        Write-Host "      Or from the Microsoft Store." -ForegroundColor Yellow
        $AllGood = $false
    }

    # --- 2. Node.js ---
    $NodePath = $null
    $NpmPath = $null
    $NpxPath = $null

    # Check standard locations + PATH
    $NodeCandidates = @(
        (Get-Command "node.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\nodejs\node.exe",
        "${env:ProgramFiles(x86)}\nodejs\node.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe",
        "$env:APPDATA\nvm\current\node.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($NodeCandidates) {
        $NodePath = $NodeCandidates
        $NodeDir = Split-Path $NodePath -Parent
        $NpmPath = Join-Path $NodeDir "npm.cmd"
        $NpxPath = Join-Path $NodeDir "npx.cmd"
        $nodeVersion = & $NodePath --version 2>$null
        Write-Success "Node.js: $nodeVersion ($NodePath)"

        # Ensure node dir is in PATH for this session (fixes Admin elevation PATH issues)
        if ($env:PATH -notlike "*$NodeDir*") {
            $env:PATH = "$NodeDir;$env:PATH"
            Write-Log "Added Node.js to session PATH."
        }
    } else {
        Write-Warn "Node.js: NOT FOUND"
        Write-Log "Attempting to install Node.js via winget..."

        $wingetAvailable = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if ($wingetAvailable) {
            try {
                Write-Log "Running: winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements"
                $installResult = cmd.exe /c "winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>&1"
                Write-Host $installResult

                # Refresh PATH after install
                $machPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
                $env:PATH = "$machPath;$userPath"

                # Re-check
                $NodePath = (Get-Command "node.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
                if (-not $NodePath) { $NodePath = "$env:ProgramFiles\nodejs\node.exe" }

                if (Test-Path $NodePath) {
                    $NodeDir = Split-Path $NodePath -Parent
                    $NpmPath = Join-Path $NodeDir "npm.cmd"
                    $NpxPath = Join-Path $NodeDir "npx.cmd"
                    if ($env:PATH -notlike "*$NodeDir*") { $env:PATH = "$NodeDir;$env:PATH" }
                    $nodeVersion = & $NodePath --version 2>$null
                    Write-Success "Node.js installed: $nodeVersion"
                } else {
                    Write-Host "  [X] Node.js installation completed but node.exe not found." -ForegroundColor Red
                    Write-Host "      You may need to restart PowerShell or reboot." -ForegroundColor Yellow
                    Write-Host "      Then re-run this script." -ForegroundColor Yellow
                    $AllGood = $false
                }
            } catch {
                Write-Host "  [X] Failed to install Node.js via winget: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      Install manually from: https://nodejs.org" -ForegroundColor Yellow
                $AllGood = $false
            }
        } else {
            Write-Host "  [X] Node.js is required but winget is not available for auto-install." -ForegroundColor Red
            Write-Host "      Install Node.js manually from: https://nodejs.org" -ForegroundColor Yellow
            $AllGood = $false
        }
    }

    # --- 3. @electron/asar ---
    $AsarCmd = $null

    if ($NodePath) {
        # Strategy A: Check for local node_modules (project bundled)
        $LocalAsar = Join-Path $global:ScriptDir "node_modules\.bin\asar.cmd"
        $LocalAsar2 = Join-Path $global:ScriptDir "node_modules\@electron\asar\bin\asar.js"

        if (Test-Path $LocalAsar) {
            $AsarCmd = $LocalAsar
            $asarVer = & cmd.exe /c "`"$AsarCmd`" --version 2>&1"
            Write-Success "@electron/asar: $asarVer (local)"
        } elseif (Test-Path $LocalAsar2) {
            $AsarCmd = "node `"$LocalAsar2`""
            Write-Success "@electron/asar: local (node_modules)"
        } else {
            # Strategy B: Check global npx
            try {
                $npxTest = & cmd.exe /c "npx --yes @electron/asar --version 2>&1"
                if ($LASTEXITCODE -eq 0 -and $npxTest -match '^\d') {
                    $AsarCmd = "npx --yes @electron/asar"
                    Write-Success "@electron/asar: $npxTest (npx)"
                } else {
                    throw "npx failed"
                }
            } catch {
                # Strategy C: Install locally via npm
                Write-Log "@electron/asar not found. Installing locally..."
                $packageJson = Join-Path $global:ScriptDir "package.json"
                if (Test-Path $packageJson) {
                    Write-Log "Running: npm install (in $global:ScriptDir)"
                    Push-Location $global:ScriptDir
                    & cmd.exe /c "npm install --no-audit --no-fund --ignore-scripts 2>&1" | Out-Null
                    Pop-Location
                } else {
                    Write-Log "Running: npm install @electron/asar"
                    Push-Location $global:ScriptDir
                    & cmd.exe /c "npm install @electron/asar --no-audit --no-fund --ignore-scripts 2>&1" | Out-Null
                    Pop-Location
                }

                $LocalAsar = Join-Path $global:ScriptDir "node_modules\.bin\asar.cmd"
                if (Test-Path $LocalAsar) {
                    $AsarCmd = $LocalAsar
                    $asarVer = & cmd.exe /c "`"$AsarCmd`" --version 2>&1"
                    Write-Success "@electron/asar: $asarVer (just installed)"
                } else {
                    Write-Host "  [X] Failed to install @electron/asar." -ForegroundColor Red
                    Write-Host "      Try manually: npm install @electron/asar" -ForegroundColor Yellow
                    $AllGood = $false
                }
            }
        }
    }

    # --- 4. PowerShell version ---
    $psVer = $PSVersionTable.PSVersion
    if ($psVer.Major -ge 5) {
        Write-Success "PowerShell: $psVer"
    } else {
        Write-Warn "PowerShell $psVer detected. Version 5.1+ recommended."
    }

    # --- Summary ---
    if (-not $AllGood) {
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Red
        Write-Host "  Missing dependencies! Fix the above" -ForegroundColor Red
        Write-Host "  issues and re-run the script." -ForegroundColor Red
        Write-Host "  ========================================" -ForegroundColor Red
        throw "Missing required dependencies."
    }

    Write-Success "All dependencies satisfied."
    return $AsarCmd
}

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
    $fs = $null
    $br = $null
    try {
        $fs = [System.IO.File]::OpenRead($AsarPath)
        $br = New-Object System.IO.BinaryReader($fs)
        $fs.Seek(12, [System.IO.SeekOrigin]::Begin) | Out-Null
        $jsonSize = $br.ReadUInt32()
        if ($jsonSize -le 0 -or $jsonSize -gt 10485760) {
            throw "Abnormal ASAR header size: $jsonSize"
        }
        $jsonBytes = $br.ReadBytes($jsonSize)

        $jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($jsonStr))
        return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    } finally {
        if ($br) { $br.Close() }
        if ($fs) { $fs.Close() }
    }
}

# -----------------------------------------------------------------------------
# INSTALL
# -----------------------------------------------------------------------------
function Install-Patch {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Desktop RTL Patcher v$VERSION — levy-n" -ForegroundColor Cyan
    Write-Host "  Installing RTL support..." -ForegroundColor Cyan
    Write-Host "========================================================`n" -ForegroundColor Cyan

    # Phase 0: Dependencies
    $AsarCmd = Ensure-Dependencies

    $ClaudeDir = Find-ClaudeDir
    if (-not $ClaudeDir) { throw "Claude Desktop not found." }
    Write-Success "Found: $ClaudeDir"

    $AppDir = Join-Path $ClaudeDir "app"
    $ResourcesDir = Join-Path $AppDir "resources"
    $AsarPath = Join-Path $ResourcesDir "app.asar"
    $ExePath = Join-Path $AppDir "claude.exe"
    $CoworkSvcPath = Join-Path $ResourcesDir "cowork-svc.exe"

    if (-not (Test-Path $AsarPath)) { throw "app.asar not found!" }

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
        & $AsarCmd extract $AsarPath $global:TmpDir
        if ($LASTEXITCODE -ne 0) { throw "ASAR extraction failed (exit code $LASTEXITCODE)." }
        if (-not (Test-Path $global:TmpDir)) { throw "ASAR extraction failed - output directory not created." }

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
            if ($Injected -gt 0) { Write-Success "Injected RTL into $Injected JS files (legacy, no-op in main process)." }
            else { Write-Warn "Already patched or no JS files found." }
        }

        # Inject into renderer HTML files (browser context with DOM access)
        $RendererDir = Join-Path $global:TmpDir ".vite\renderer"
        if (Test-Path $RendererDir) {
            $HtmlFiles = Get-ChildItem -Path $RendererDir -Filter "*.html" -Recurse
            $HtmlInjected = 0
            $HtmlRTL = [System.Text.Encoding]::UTF8.GetString(
                [System.Convert]::FromBase64String($RTL_RENDERER_B64)
            )
            foreach ($hf in $HtmlFiles) {
                $hc = Get-Content $hf.FullName -Raw
                if ($hc -notmatch "__rtlV11") {
                    if ($hc -match "</head>") {
                        $hc = $hc.Replace("</head>", "$HtmlRTL</head>")
                    } elseif ($hc -match "</body>") {
                        $hc = $hc.Replace("</body>", "$HtmlRTL</body>")
                    }
                    $u8 = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllText($hf.FullName, $hc, $u8)
                    $HtmlInjected++
                }
            }
            if ($HtmlInjected -gt 0) { Write-Success "Injected RTL into $HtmlInjected renderer HTML files." }
            else { Write-Warn "No renderer HTML files found or already patched." }
        } else {
            Write-Warn "Renderer directory not found at $RendererDir"
        }

        $TmpAsarPath = "$AsarPath.new"
        Write-Log "Repacking ASAR..."
        & $AsarCmd pack $global:TmpDir $TmpAsarPath
        if ($LASTEXITCODE -ne 0) { throw "ASAR repacking failed (exit code $LASTEXITCODE)." }
        if (-not (Test-Path $TmpAsarPath)) { throw "ASAR repacking failed - output file not created." }

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

            Write-Log ('Certificate found at offset 0x{0} ({1} bytes)' -f [Convert]::ToString($StartPos, 16), $OldCertSize)

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
                    Write-Success ('Certificate fits ({0} <= {1} bytes)' -f $NewCertBytes.Length, $OldCertSize)
                } else {
                    Write-Warn ('Too large ({0} bytes), retrying...' -f $NewCertBytes.Length)
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
        Write-Step "Phase 3/3: Cleanup and Launch"
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
        # Also clean up Root store in case older versions placed certs there
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
    Write-Host "  github.com/levy-n/claude-desktop-rtl" -ForegroundColor DarkGray
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

        Write-Host "`n  Press Enter to exit"
        $null = Read-Host
    }
    elseif ($choice -eq '3') { Exit }
    else { Show-Menu }
}

Show-Menu
