// ============================================
// Claude Desktop RTL — DevTools Console Injection
// claude-desktop-rtl
// ============================================
//
// SETUP (one-time):
//   1. Create %APPDATA%\Claude\developer_settings.json
//      with: {"allowDevTools": true}
//   2. Restart Claude Desktop
//
// USAGE (each session):
//   Option A — Snippet (recommended, one-time setup):
//     1. Ctrl+Alt+I → DevTools
//     2. Sources → Snippets → + New snippet → name it "RTL"
//     3. Paste this entire file → Ctrl+S
//     4. Each session: Ctrl+Alt+I → Sources → Snippets → right-click RTL → Run
//
//   Option B — Console paste:
//     1. Ctrl+Alt+I → Console tab
//     2. Paste this entire script → Enter
//
// ============================================

(function(){
    if(window.__claudeRTLInjected) { console.log('[RTL] Already active.'); return; }
    window.__claudeRTLInjected = true;

    // RTL CSS — auto-detect direction, keep code LTR
    const css = `
        [data-message-author-role="assistant"] .prose,
        [data-message-author-role="assistant"] .font-claude-message,
        [data-message-author-role="assistant"] [class*="Message"],
        [data-message-author-role="assistant"] > div > div,
        .prose p, .prose li,
        .prose h1, .prose h2, .prose h3, .prose h4, .prose h5, .prose h6,
        .prose blockquote, .prose td, .prose th,
        .font-claude-message p, .font-claude-message li,
        .font-claude-message h1, .font-claude-message h2, .font-claude-message h3,
        .font-claude-message h4, .font-claude-message h5, .font-claude-message h6
        { direction: auto; unicode-bidi: plaintext; }

        textarea, [contenteditable="true"], .ProseMirror,
        [role="textbox"], div[data-placeholder]
        { direction: auto; unicode-bidi: plaintext; text-align: start; }

        pre, code, .code-block, [class*="code"], [class*="Code"],
        .hljs, [class*="highlight"], [data-language],
        .font-mono, pre *, code *
        { direction: ltr !important; unicode-bidi: embed !important; text-align: left !important; }

        :not(pre) > code
        { direction: ltr !important; unicode-bidi: embed !important; }

        .prose ul, .prose ol
        { direction: auto; unicode-bidi: plaintext; }

        .katex, .MathJax, [class*="math"], [class*="Math"], svg
        { direction: ltr !important; }
    `;

    const style = document.createElement('style');
    style.id = 'claude-rtl-styles';
    style.textContent = css;
    document.head.appendChild(style);

    // Hebrew/Arabic detection
    const R = /[\u0590-\u05FF\u0600-\u06FF]/;

    function applyDir(el) {
        if (!el || el.nodeType !== 1) return;
        const tag = el.tagName.toLowerCase();
        if (['pre','code','svg','script','style'].includes(tag)) return;
        if (el.closest('pre') || el.closest('code')) return;
        if (R.test(el.textContent || '') &&
            ['p','li','h1','h2','h3','h4','h5','h6','td','th','blockquote'].includes(tag) &&
            !el.getAttribute('dir')) {
            el.setAttribute('dir', 'auto');
        }
    }

    // Watch for new content
    new MutationObserver(mutations => {
        for (const m of mutations) {
            for (const n of m.addedNodes) {
                if (n.nodeType === 1) {
                    applyDir(n);
                    n.querySelectorAll('p,li,h1,h2,h3,h4,h5,h6,td,th,blockquote').forEach(applyDir);
                }
            }
        }
    }).observe(document.body, { childList: true, subtree: true });

    // Apply to existing content
    document.querySelectorAll('.prose p,.prose li,.prose h1,.prose h2,.prose h3,.prose h4,.prose h5,.prose h6,.prose td,.prose th,.prose blockquote').forEach(applyDir);

    console.log('[RTL] Claude Desktop RTL support active! (claude-desktop-rtl)');
})();
