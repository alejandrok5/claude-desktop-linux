const path = require('path');
const Module = require('module');
const { app, BrowserWindow } = require('electron');

const resourcesDir = path.join(__dirname, 'resources');
const asarPath = path.join(resourcesDir, 'app.asar');

// Override resourcesPath so locale files, fonts, migrations, etc. resolve correctly
Object.defineProperty(process, 'resourcesPath', {
  value: resourcesDir,
  configurable: true,
});

// Override getAppPath so preload scripts and HTML files resolve inside the asar
app.getAppPath = () => asarPath;

// Force packaged mode so the app uses process.resourcesPath paths
Object.defineProperty(app, 'isPackaged', {
  get: () => true,
  configurable: true,
});

// Set app name for correct userData path (~/.config/Claude/)
app.setName('Claude');

// Enable remote debugging if requested via env var
if (process.env.ELECTRON_REMOTE_DEBUGGING_PORT) {
  app.commandLine.appendSwitch('remote-debugging-port', process.env.ELECTRON_REMOTE_DEBUGGING_PORT);
  app.commandLine.appendSwitch('remote-allow-origins', '*');
}

// --- Linux platform patches ---
if (process.platform === 'linux') {
  // Auto-detect Claude Code CLI binary so the built-in integration works without
  // attempting a download (the upstream manifest has no Linux entries).
  if (!process.env.CLAUDE_CODE_LOCAL_BINARY) {
    try {
      const { execSync } = require('child_process');
      const claudePath = execSync('which claude', { encoding: 'utf8', timeout: 3000 }).trim();
      if (claudePath) {
        process.env.CLAUDE_CODE_LOCAL_BINARY = claudePath;
        console.log('[linux-patch] Found Claude Code binary:', claudePath);
      }
    } catch {
      // claude not in PATH — the app will show "not available for your device"
    }
  }

  // Patch the upstream bundle at load-time to add Linux platform support.
  // Without this, getHostPlatform() throws "Unsupported platform: linux-x64"
  // which crashes the ClaudeCode IPC handlers (prepare, getStatus).
  const _compile = Module.prototype._compile;
  Module.prototype._compile = function (content, filename) {
    if (filename.includes('.vite/build/index.js')) {
      // 1. Add Linux to getHostPlatform()
      content = content.replace(
        'if(process.platform==="win32")return e==="arm64"?"win32-arm64":"win32-x64";throw new Error(`Unsupported platform: ${process.platform}-${e}`)',
        'if(process.platform==="win32")return e==="arm64"?"win32-arm64":"win32-x64";if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";throw new Error(`Unsupported platform: ${process.platform}-${e}`)'
      );

      // 2. Add common Linux paths to the shell PATH builder (Utn) so the app
      //    can find node, git, python, etc. The upstream returns [] for Linux.
      content = content.replace(
        'Git\\\\mingw64\\\\bin`]:[]}',
        'Git\\\\mingw64\\\\bin`]:process.platform==="linux"?[require("os").homedir()+"/.nvm/versions/node/*/bin","/usr/local/bin","/usr/bin","/snap/bin"]:[]}'
      );

      // Restore original _compile after patching — no need to check every file
      Module.prototype._compile = _compile;
      console.log('[linux-patch] Patched index.js for Linux platform support');
    }
    return _compile.call(this, content, filename);
  };

  // Enable titlebar window controls — the upstream app only sets
  // titleBarOverlay for win32, leaving a controls-less titlebar on Linux.
  app.on('browser-window-created', (_event, win) => {
    try {
      win.setTitleBarOverlay({
        color: '#00000000',
        symbolColor: '#000000',
        height: 40
      });
    } catch {
      // titlebar overlay not enabled on this window
    }

    // The outer frame (index.html) has a 36px drag div (.nc-drag) that covers the
    // full window width. It blocks clicks on the tab bar (Chat/Directs/Code) in
    // the inner frame. Hide it — the inner Claude page already has its own drag
    // region with proper no-drag holes for the tab buttons.
    win.webContents.on('did-finish-load', () => {
      win.webContents.insertCSS('.nc-drag { display: none !important; }');
    });
  });
}

// Load the real app entry point
require(path.join(asarPath, '.vite', 'build', 'index.pre.js'));
