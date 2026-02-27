# claude-desktop-rtl-natilevy

**RTL (Right-to-Left) support for Claude Desktop on Windows.**

Adds automatic Hebrew and Arabic text direction to Claude Desktop — code blocks stay LTR.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-0078d7.svg)

## What It Does

- Auto-detects Hebrew/Arabic text and sets RTL direction
- Keeps code blocks, math, and SVG in LTR
- Handles input box direction dynamically
- Works with MutationObserver for streamed responses
- Survives app restarts (persistent ASAR patch)

## Quick Install (One-Liner)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/natilevy/claude-desktop-rtl/main/install.ps1 | iex
```

This will auto-elevate to Administrator and patch Claude Desktop.

## Manual Install

1. Clone or download this repo
2. Right-click `patch.ps1` → **Run with PowerShell**
3. Select **1** (Install) and confirm with **Y**
4. Claude Desktop restarts with RTL support

## Requirements

- Windows 10/11
- Claude Desktop (MSIX from Microsoft Store)
- Node.js (for `npx asar` — [nodejs.org](https://nodejs.org))
- Administrator privileges

## How It Works

The patcher performs 3 phases:

| Phase | What | Why |
|-------|------|-----|
| **1. ASAR Injection** | Extracts `app.asar`, injects RTL JavaScript into all `.vite/build/*.js` files, repacks | The RTL logic runs on every page load |
| **2. Hash Update** | Computes new ASAR header hash, replaces old hash in `claude.exe` | Electron validates ASAR integrity via embedded hash |
| **3. Certificate Swap** | Generates self-signed cert, replaces Anthropic cert in `cowork-svc.exe`, re-signs both executables | The background service validates `claude.exe` signature |

## Alternative: DevTools Method (No Patching)

If you prefer not to modify any files:

1. Create `%APPDATA%\Claude\developer_settings.json` with:
   ```json
   {"allowDevTools": true}
   ```
2. Restart Claude Desktop
3. Press `Ctrl+Alt+I` → open DevTools Console
4. Paste contents of `scripts/devtools-inject.js` → Enter

**For repeat use:** In DevTools → Sources → Snippets → New → paste the script → save as `RTL`. Then each session: `Ctrl+Alt+I` → Sources → Snippets → right-click `RTL` → Run.

## Uninstall

Run `patch.ps1` and select **2** (Restore Original State).

Or manually:
```powershell
powershell -ExecutionPolicy Bypass -File patch.ps1
# Choose option 2
```

This restores all original files from `.bak` backups and removes custom certificates.

## After Claude Desktop Updates

Claude Desktop updates will overwrite the patch. Simply re-run `patch.ps1` after updating.

## File Structure

```
claude-desktop-rtl/
├── patch.ps1                    # Main patcher (install + restore)
├── install.ps1                  # One-liner installer (downloads & runs patch.ps1)
├── scripts/
│   ├── devtools-inject.js       # Manual DevTools injection (alternative method)
│   └── copy-to-clipboard.ps1    # Copy DevTools script to clipboard
├── src/
│   ├── rtl-inject.js            # Full RTL injection with MutationObserver
│   └── rtl-styles.css           # Standalone RTL CSS
├── README.md
├── README.rtl.md                # Hebrew documentation
├── LICENSE
└── .gitignore
```

## Credits

- Inspired by [shraga100/claude-desktop-rtl-patch](https://github.com/shraga100/claude-desktop-rtl-patch)
- ASAR header hash technique from the Electron community
- Certificate swap approach from reverse-engineering Claude Desktop's integrity chain

## License

MIT License — see [LICENSE](LICENSE).
