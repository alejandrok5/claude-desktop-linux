# Claude Desktop for Linux

Run [Claude Desktop](https://claude.ai/download) on Linux by extracting the official Windows app and running it under a native Linux Electron runtime. No Wine, no VM — just the real Claude Desktop.

## Quick start

```bash
git clone https://github.com/alejandrok5/claude-desktop-linux.git
cd claude-desktop-linux
./setup.sh
```

That's it. The script downloads the latest Claude Desktop directly from Anthropic's servers, installs Electron, extracts the app, and creates a `.desktop` entry so Claude appears in your application launcher.

No Windows installer needed. No Wine. No manual downloads.

To launch:

```bash
npm start
# or click "Claude" in your app launcher
```

## Prerequisites

- **Node.js** >= 22
- **curl** and **unzip** (standard on most distros)

<details>
<summary>Install on Ubuntu/Debian</summary>

```bash
sudo apt install nodejs npm curl unzip
```
</details>

<details>
<summary>Install on Fedora</summary>

```bash
sudo dnf install nodejs npm curl unzip
```
</details>

<details>
<summary>Install on Arch</summary>

```bash
sudo pacman -S nodejs npm curl unzip
```
</details>

## Updating

When a new version of Claude Desktop is released, just re-run the setup:

```bash
./setup.sh
```

The script downloads the latest MSIX package from Anthropic's servers, re-extracts resources, and verifies the Electron version still matches. If the upstream app requires a new Electron version, it installs it automatically.

## How it works

### Extraction (`scripts/extract.mjs`)

Downloads the latest MSIX package directly from Anthropic's API (`https://claude.ai/api/desktop/win32/x64/msix/latest/redirect`), which is a ZIP containing the Electron app. Extracts `app.asar` and supporting files (locales, fonts, icons, migrations, Linux SSH binaries) into `resources/`.

Also supports the legacy Squirrel.Windows installer format if you place a `Claude Setup.exe` in the project root.

### Launcher (`main.js`)

A thin Electron entry point that patches the runtime before loading the real app:

- `process.resourcesPath` → `resources/` so locale files, fonts, and migrations resolve
- `app.getAppPath()` → `resources/app.asar` so preload scripts and HTML load from the asar
- `app.isPackaged` → `true` so the app uses production resource paths
- `app.name` → `Claude` so user data goes to `~/.config/Claude/`

On Linux, it also applies runtime patches to the bundled code:

- **Platform support** — Adds `linux-x64`/`linux-arm64` to `getHostPlatform()` so the Claude Code integration doesn't crash
- **Claude Code CLI** — Auto-detects a locally installed `claude` binary and sets `CLAUDE_CODE_LOCAL_BINARY`
- **Shell PATH** — Adds standard Linux paths (`~/.nvm/versions/node/*/bin`, `/usr/local/bin`, etc.) to the app's PATH builder
- **Titlebar** — Hides the outer-frame drag overlay that blocks tab clicks on Linux, and attempts to enable native window controls

## What works

- Full Claude chat UI (loads claude.ai in a BrowserView)
- **Claude Code integration** (Chat/Directs/Code tabs — requires `claude` CLI installed)
- Authentication (OAuth flow)
- System tray icon
- MCP (Model Context Protocol) server support
- Claude Code SSH integration (Linux binaries are bundled)
- All 56 locales
- SQLite storage (built into Electron 40.x via `node:sqlite`)
- Window management, keyboard shortcuts, find-in-page

## What doesn't work

These features depend on platform-specific native modules. The app handles their absence gracefully:

| Feature | Reason | Behavior |
|---|---|---|
| Computer Use | Requires `@ant/claude-native` (Windows .node binary) | Shows "not available" |
| Quick Entry overlay | Requires `@ant/claude-swift` (macOS/Windows) | Silently skipped |
| Office integration | Windows registry / COM automation | Silently skipped |
| Auto-updates | Uses MSIX/Squirrel updaters | Run `./setup.sh` to update |
| Cowork VM | Requires Windows Hyper-V | Silently skipped |

## Project structure

```
.
├── setup.sh                  # One-shot setup and update script
├── package.json              # Pins Electron version
├── main.js                   # Electron launcher with Linux patches
├── scripts/
│   └── extract.mjs           # Resource extraction (Squirrel + MSIX)
├── resources/                # Generated (not committed)
│   ├── app.asar              # Core Electron app (~18 MB)
│   ├── *.json                # Locale files
│   ├── icon.png              # App icon
│   ├── fonts/                # Anthropic fonts
│   ├── drizzle/              # SQLite migrations
│   ├── seed/                 # Seed data
│   └── claude-ssh/           # Linux SSH binaries
└── .gitignore
```

## Configuration

Claude Desktop stores its configuration at `~/.config/Claude/claude_desktop_config.json`. This is where MCP servers and other settings are configured.

## Troubleshooting

**App crashes on startup**: Ensure you're running Electron `40.4.1` (or whatever version the extracted `app.asar` requires). Run `./setup.sh` to auto-detect and install the correct version.

**"Unsupported platform: linux-x64"**: The patches in `main.js` should handle this. If you see this error, the patched strings may have changed in a new version. Please open an issue.

**Claude Code tab not working**: Install the Claude Code CLI (`npm install -g @anthropic-ai/claude-code`) and ensure `claude` is in your PATH.

**Can't click Chat/Code tabs**: The outer-frame drag overlay fix should handle this. If tabs are unclickable, the CSS class name may have changed. Please open an issue.

## License

This project is a wrapper/launcher only. Claude Desktop and all extracted assets are property of [Anthropic PBC](https://anthropic.com). This project does not redistribute any Anthropic code or assets.
