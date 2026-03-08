# claude-desktop-rtl

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

## Install

Just run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/levy-n/claude-desktop-rtl/master/install.ps1 | iex
```

That's it. The script downloads everything, checks dependencies, installs what's missing, and patches Claude Desktop automatically.

> **Already cloned the repo?** Right-click `patch.ps1` → Run with PowerShell → Select **1** (Install).

## Dependencies

The patcher automatically checks and installs these:

| Dependency | Required | Auto-Install |
|------------|----------|--------------|
| **Windows 10/11** | Yes | — |
| **Claude Desktop** | Yes | No — install from [claude.ai/download](https://claude.ai/download) or Microsoft Store |
| **Node.js** | Yes | Yes — via `winget install OpenJS.NodeJS.LTS` |
| **@electron/asar** | Yes | Yes — via `npm install` (local to project) or `npx` |
| **PowerShell 5.1+** | Yes | Included in Windows 10/11 |
| **Administrator** | Yes | Auto-elevates via UAC prompt |

**If you already have Node.js installed** — the script will detect it and use it.
**If Node.js is missing** — the script tries to install via `winget`. If `winget` is unavailable, it shows a download link.
**The `@electron/asar` tool** — first checks for a local `node_modules` copy (bundled with the project), then tries `npx`, then auto-installs locally.

## How It Works

The patcher performs 4 phases:

| Phase | What | Why |
|-------|------|-----|
| **0. Dependencies** | Checks Node.js, asar, Claude Desktop — installs missing | Everything needed before patching |
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
├── patch.ps1                    # Main patcher (install + restore + dependency check)
├── install.ps1                  # One-liner installer (downloads full project & runs)
├── package.json                 # Node.js deps (@electron/asar)
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



## Acknowledgments

This project is based on [shraga100/claude-desktop-rtl-patch](https://github.com/shraga100/claude-desktop-rtl-patch) by [@shraga100](https://github.com/shraga100), which introduced the core RTL injection approach, the 3-phase ASAR patching architecture, and the certificate swap technique for Claude Desktop.

This fork adds automatic dependency management, a one-liner installer, and additional improvements on top of that foundation.

## License

MIT License — see [LICENSE](LICENSE).
