<#
.SYNOPSIS
    Copy RTL DevTools injection script to clipboard
.DESCRIPTION
    Double-click this script, then paste in Claude Desktop DevTools Console.
    Steps: Ctrl+Alt+I → Console → Ctrl+V → Enter
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsFile = Join-Path $ScriptDir "devtools-inject.js"

if (Test-Path $jsFile) {
    $content = Get-Content $jsFile -Raw
    Set-Clipboard -Value $content
} else {
    # Fallback: inline minified version
    $rtl = @'
(function(){if(window.__claudeRTLInjected)return;window.__claudeRTLInjected=true;const css=`[data-message-author-role="assistant"] .prose,[data-message-author-role="assistant"] .font-claude-message,[data-message-author-role="assistant"] [class*="Message"],[data-message-author-role="assistant"]>div>div,.prose p,.prose li,.prose h1,.prose h2,.prose h3,.prose h4,.prose h5,.prose h6,.prose blockquote,.prose td,.prose th{direction:auto;unicode-bidi:plaintext}textarea,[contenteditable="true"],.ProseMirror,[role="textbox"],div[data-placeholder]{direction:auto;unicode-bidi:plaintext;text-align:start}pre,code,.code-block,[class*="code"],[class*="Code"],.hljs,[class*="highlight"],[data-language],.font-mono,pre *,code *{direction:ltr!important;unicode-bidi:embed!important;text-align:left!important}:not(pre)>code{direction:ltr!important;unicode-bidi:embed!important}.prose ul,.prose ol{direction:auto;unicode-bidi:plaintext}.katex,.MathJax,[class*="math"],[class*="Math"],svg{direction:ltr!important}`;const s=document.createElement('style');s.id='claude-rtl-styles';s.textContent=css;document.head.appendChild(s);const R=/[\u0590-\u05FF\u0600-\u06FF]/;function a(e){if(!e||e.nodeType!==1)return;const t=e.tagName.toLowerCase();if(['pre','code','svg','script','style'].includes(t)||e.closest('pre')||e.closest('code'))return;if(R.test(e.textContent||'')&&['p','li','h1','h2','h3','h4','h5','h6','td','th','blockquote'].includes(t)&&!e.getAttribute('dir'))e.setAttribute('dir','auto')}new MutationObserver(m=>{for(const x of m)for(const n of x.addedNodes)if(n.nodeType===1){a(n);n.querySelectorAll('p,li,h1,h2,h3,h4,h5,h6,td,th,blockquote').forEach(a)}}).observe(document.body,{childList:true,subtree:true});document.querySelectorAll('.prose p,.prose li,.prose h1,.prose h2,.prose h3,.prose h4,.prose h5,.prose h6,.prose td,.prose th,.prose blockquote').forEach(a);console.log('[RTL] Active!')})();
'@
    Set-Clipboard -Value $rtl
}

Write-Host ""
Write-Host "  RTL script copied to clipboard!" -ForegroundColor Green
Write-Host ""
Write-Host "  In Claude Desktop:" -ForegroundColor Cyan
Write-Host "    1. Ctrl+Alt+I  (open DevTools)" -ForegroundColor White
Write-Host "    2. Console tab" -ForegroundColor White
Write-Host "    3. Ctrl+V  (paste)" -ForegroundColor White
Write-Host "    4. Enter" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to close"
