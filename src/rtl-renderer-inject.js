/**
 * Claude Desktop RTL Injection - Renderer Version
 *
 * PROBLEM:
 *   The original patch injects JavaScript into .vite/build/*.js files.
 *   These are main-process / preload scripts that run in Node.js context.
 *   They have NO access to the DOM (document, window, etc.).
 *
 *   The actual UI is rendered by Chromium in separate renderer processes,
 *   which load HTML files from .vite/renderer/*/index.html
 *
 * SOLUTION:
 *   Inject a <script> tag into the renderer HTML files instead.
 *   This code runs in the browser context with full DOM access.
 *
 * SAFETY:
 *   - Wrapped in DOMContentLoaded to ensure document.body exists
 *   - try/catch around all operations to prevent app crashes
 *   - Guard variable (__rtlV11) prevents double-execution
 *
 * INJECTION TARGET:
 *   .vite/renderer/main_window/index.html      (main chat window)
 *   .vite/renderer/quick_window/index.html      (quick input)
 *   .vite/renderer/about/index.html             (about dialog)
 *   .vite/renderer/find_in_page/index.html      (search dialog)
 *
 * Insert before </head> as: <script>{this code}</script>
 *
 * Fix by: SpeedGitHub (https://github.com/levy-n/claude-desktop-rtl/issues/1)
 */

;(function () {
  'use strict';

  // Prevent double-execution
  if (window.__rtlV11) return;
  window.__rtlV11 = true;

  function initRTL() {
    try {
      if (!document.body) return;

      // =========================================================
      // 1. INJECT GLOBAL CSS RULES
      // =========================================================
      var style = document.createElement('style');
      style.id = 'rtl-v11';
      style.textContent = [
        // RTL elements align right
        '[dir=rtl] { text-align: right !important }',
        '[dir=ltr] { text-align: left !important }',

        // RTL lists: flip padding
        'ul[dir=rtl], ol[dir=rtl] { padding-right: 2rem !important; padding-left: 0 !important }',

        // RTL blockquotes: border on right side
        'blockquote[dir=rtl] {',
        '  border-left: none !important;',
        '  border-right: 3px solid #565869 !important;',
        '  padding-left: 0 !important;',
        '  padding-right: 1em !important',
        '}',

        // Force code blocks to stay LTR
        'pre, pre *, code, code *,',
        '[class*=code] *, [class*=Code] *,',
        '[class*=hljs] *, [data-language] *,',
        '[class*=language-] *,',
        'kbd, samp, var, svg, svg * {',
        '  direction: ltr !important;',
        '  unicode-bidi: embed !important;',
        '  text-align: left !important',
        '}',

        // Input fields: auto-detect direction
        'textarea, [contenteditable=true], [role=textbox] {',
        '  unicode-bidi: plaintext',
        '}'
      ].join('\n');
      document.head.appendChild(style);

      // =========================================================
      // 2. UNICODE RANGE TABLES
      // =========================================================

      // RTL script ranges (Hebrew, Arabic, extended Arabic)
      var RTL_RANGES = [
        [0x0590, 0x05FF],   // Hebrew
        [0x0600, 0x06FF],   // Arabic
        [0x0750, 0x077F],   // Arabic Supplement
        [0x08A0, 0x08FF],   // Arabic Extended-A
        [0xFB50, 0xFDFF],   // Arabic Presentation Forms-A
        [0xFE70, 0xFEFF]    // Arabic Presentation Forms-B
      ];

      // LTR script ranges (Latin)
      var LTR_RANGES = [
        [0x41, 0x5A],       // A-Z
        [0x61, 0x7A]        // a-z
      ];

      function inRange(codePoint, ranges) {
        return ranges.some(function (r) {
          return codePoint >= r[0] && codePoint <= r[1];
        });
      }

      // =========================================================
      // 3. DIRECTION DETECTION
      // =========================================================

      /**
       * Detect text direction based on first strong directional character.
       * Returns 'rtl', 'ltr', or null if no strong characters found.
       */
      function detectDirection(text) {
        if (!text) return null;
        // Strip whitespace, digits, and common punctuation
        text = text.replace(/[\s\d\u0020-\u0040\u005B-\u0060\u007B-\u00BF]/g, '');
        // Check first 100 characters for performance
        for (var i = 0; i < Math.min(text.length, 100); i++) {
          var cp = text.codePointAt(i);
          if (inRange(cp, RTL_RANGES)) return 'rtl';
          if (inRange(cp, LTR_RANGES)) return 'ltr';
        }
        return null;
      }

      // =========================================================
      // 4. CODE BLOCK DETECTION
      // =========================================================

      /**
       * Check if element is inside a code block, math formula, or SVG.
       * These should always remain LTR.
       */
      function isCodeContext(el) {
        return el && el.closest && !!el.closest(
          'pre, code, [class*=code], [class*=Code], ' +
          '[data-language], [class*=language-], ' +
          '.katex, .MathJax, svg'
        );
      }

      // =========================================================
      // 5. DOM PROCESSING
      // =========================================================

      // Inline elements that should NOT be treated as block containers.
      var INLINE_TAGS = [
        'SPAN', 'STRONG', 'EM', 'B', 'I', 'A', 'MARK', 'SMALL',
        'SUB', 'SUP', 'ABBR', 'CITE', 'DEL', 'INS', 'S', 'U', 'BR'
      ];

      /**
       * Walk all text nodes in the document.
       * For each text node with directional content:
       *   1. Find the nearest block-level ancestor
       *   2. Set dir, direction, unicode-bidi, text-align
       *   3. Walk up to 4 parent levels to set direction on
       *      container elements (UL, OL, BLOCKQUOTE, DIV)
       */
      function processElements() {
        try {
          if (!document.body) return;

          var walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            null,
            false
          );

          var node;
          while (node = walker.nextNode()) {
            var text = node.textContent;
            if (!text || !text.trim()) continue;

            var dir = detectDirection(text);
            if (!dir) continue;

            // Skip code blocks
            var el = node.parentElement;
            if (!el || isCodeContext(el)) continue;

            // Walk up past inline elements to find block parent
            var block = el;
            while (block && INLINE_TAGS.indexOf(block.tagName) !== -1) {
              block = block.parentElement;
            }
            if (!block || block === document.body) continue;
            if (isCodeContext(block)) continue;

            // Apply direction to block element
            block.setAttribute('dir', dir);
            block.style.direction = dir;
            block.style.unicodeBidi = 'plaintext';
            block.style.textAlign = dir === 'rtl' ? 'right' : 'left';

            // Walk up to 4 parent levels for container elements
            var parent = block.parentElement;
            var levels = 0;
            while (parent && levels < 4 && parent !== document.body) {
              if (isCodeContext(parent)) break;
              var tag = parent.tagName;
              if (tag === 'UL' || tag === 'OL' || tag === 'BLOCKQUOTE' || tag === 'DIV') {
                parent.setAttribute('dir', dir);
                parent.style.direction = dir;
                parent.style.textAlign = dir === 'rtl' ? 'right' : 'left';
              }
              parent = parent.parentElement;
              levels++;
            }
          }
        } catch (e) {
          console.error('[RTL proc]', e);
        }
      }

      // =========================================================
      // 6. INPUT HANDLER
      // =========================================================

      document.addEventListener('input', function (e) {
        try {
          var target = e.target;
          if (!target) return;
          if (target.tagName === 'TEXTAREA' || target.tagName === 'INPUT' || target.isContentEditable) {
            var text = target.textContent || target.innerText || target.value || '';
            var dir = detectDirection(text);
            if (dir) {
              target.setAttribute('dir', dir);
              target.style.direction = dir;
              target.style.textAlign = dir === 'rtl' ? 'right' : 'left';
            }
          }
        } catch (e) { /* swallow input errors */ }
      }, true);

      // =========================================================
      // 7. MUTATION OBSERVER (for streaming responses)
      // =========================================================

      var debounceTimer = null;
      new MutationObserver(function (mutations) {
        var hasChanges = false;
        for (var i = 0; i < mutations.length; i++) {
          if (mutations[i].addedNodes.length || mutations[i].type === 'characterData') {
            hasChanges = true;
            break;
          }
        }
        if (hasChanges) {
          clearTimeout(debounceTimer);
          debounceTimer = setTimeout(processElements, 100);
        }
      }).observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true
      });

      // Initial processing
      processElements();
      console.log('[RTL v11] Active');

    } catch (e) {
      console.error('[RTL v11 init]', e);
    }
  }

  // =========================================================
  // 8. ENTRY POINT
  // =========================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initRTL);
  } else {
    initRTL();
  }

})();
