/**
 * Claude Desktop RTL Injection — Full Version
 * claude-desktop-rtl
 *
 * Smart RTL support with MutationObserver for streamed responses.
 * Auto-detects Hebrew/Arabic text. Code blocks stay LTR.
 *
 * Can be used as:
 * - DevTools console injection
 * - ASAR preload script
 * - CDP Runtime.evaluate payload
 */

(function() {
    'use strict';

    if (window.__claudeRTLInjected) return;
    window.__claudeRTLInjected = true;

    // ---- CSS ----
    const RTL_CSS = `
/* Claude Desktop RTL Support — levy-n */

/* Auto-direction on message containers */
[data-message-author-role="assistant"] .prose,
[data-message-author-role="assistant"] .font-claude-message,
[data-message-author-role="assistant"] [class*="Message"],
[data-message-author-role="assistant"] > div > div,
.prose p, .prose li,
.prose h1, .prose h2, .prose h3, .prose h4, .prose h5, .prose h6,
.prose blockquote, .prose td, .prose th {
    direction: auto;
    unicode-bidi: plaintext;
}

/* Input area */
textarea,
[contenteditable="true"],
.ProseMirror,
[role="textbox"],
div[data-placeholder] {
    direction: auto;
    unicode-bidi: plaintext;
    text-align: start;
}

/* Code blocks: ALWAYS LTR */
pre, code, .code-block, [class*="code"], [class*="Code"],
.hljs, [class*="highlight"], [data-language],
.font-mono, pre *, code *,
.monaco-editor, .monaco-editor * {
    direction: ltr !important;
    unicode-bidi: embed !important;
    text-align: left !important;
}

:not(pre) > code {
    direction: ltr !important;
    unicode-bidi: embed !important;
}

/* Lists */
.prose ul, .prose ol {
    direction: auto;
    unicode-bidi: plaintext;
}

/* Tables */
.prose table {
    direction: auto;
}

/* Math & SVG: LTR */
.katex, .MathJax, [class*="math"], [class*="Math"], svg {
    direction: ltr !important;
}
`;

    // ---- Inject CSS ----
    function injectCSS() {
        const existing = document.getElementById('claude-rtl-styles');
        if (existing) existing.remove();

        const style = document.createElement('style');
        style.id = 'claude-rtl-styles';
        style.textContent = RTL_CSS;
        document.head.appendChild(style);
    }

    // ---- RTL Detection ----
    const RTL_REGEX = /[\u0590-\u05FF\u0600-\u06FF\u0700-\u074F\uFB50-\uFDFF\uFE70-\uFEFF]/;

    function applyAutoDir(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return;

        const tagName = element.tagName.toLowerCase();
        if (['pre', 'code', 'svg', 'script', 'style'].includes(tagName)) return;
        if (element.closest('pre') || element.closest('code')) return;

        const textContent = element.textContent || '';
        if (RTL_REGEX.test(textContent)) {
            const leafTags = ['p', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'td', 'th', 'blockquote'];
            if (leafTags.includes(tagName) && !element.getAttribute('dir')) {
                element.setAttribute('dir', 'auto');
            }
        }
    }

    // ---- MutationObserver ----
    function setupObserver() {
        const observer = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        applyAutoDir(node);
                        node.querySelectorAll('p, li, h1, h2, h3, h4, h5, h6, td, th, blockquote')
                            .forEach(applyAutoDir);
                    }
                }
            }
        });

        observer.observe(document.body, { childList: true, subtree: true });
        return observer;
    }

    // ---- Apply to existing content ----
    function applyToExisting() {
        document.querySelectorAll(
            '.prose p, .prose li, .prose h1, .prose h2, .prose h3, ' +
            '.prose h4, .prose h5, .prose h6, .prose td, .prose th, .prose blockquote'
        ).forEach(applyAutoDir);
    }

    // ---- Init ----
    function init() {
        injectCSS();
        applyToExisting();
        setupObserver();
        console.log('[RTL] Claude Desktop RTL support active! (claude-desktop-rtl)');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
