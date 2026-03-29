#!/usr/bin/env bash
set -euo pipefail

# Claude Desktop for Linux — one-shot setup and update script
# Usage: ./setup.sh [--update]
#
# First run:  downloads installer, extracts resources, installs Electron, creates .desktop entry
# With --update: re-downloads the latest MSIX and re-extracts resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/resources"
DESKTOP_FILE="$HOME/.local/share/applications/claude-desktop.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
check_deps() {
  local missing=()
  command -v node  >/dev/null 2>&1 || missing+=(node)
  command -v npm   >/dev/null 2>&1 || missing+=(npm)
  command -v curl  >/dev/null 2>&1 || missing+=(curl)
  command -v unzip >/dev/null 2>&1 || missing+=(unzip)

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required dependencies: ${missing[*]}"
    echo ""
    echo "Install them with your package manager, e.g.:"
    echo "  sudo apt install ${missing[*]}"
    echo "  sudo dnf install ${missing[*]}"
    echo "  sudo pacman -S ${missing[*]}"
    exit 1
  fi

  # Check Node version >= 22
  local node_major
  node_major=$(node -e 'console.log(process.versions.node.split(".")[0])')
  if [[ "$node_major" -lt 22 ]]; then
    echo "ERROR: Node.js >= 22 required (found v$(node -v))"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Install npm dependencies (Electron)
# ---------------------------------------------------------------------------
install_deps() {
  if [[ ! -d "$SCRIPT_DIR/node_modules/electron" ]]; then
    echo "Installing Electron..."
    cd "$SCRIPT_DIR"
    npm install
  else
    echo "Electron already installed"
  fi
}

# ---------------------------------------------------------------------------
# Extract resources from the installer
# ---------------------------------------------------------------------------
extract_resources() {
  echo "Extracting resources..."
  cd "$SCRIPT_DIR"
  node scripts/extract.mjs
}

# ---------------------------------------------------------------------------
# Check if Electron version matches the app's requirement
# ---------------------------------------------------------------------------
check_electron_version() {
  local required
  required=$(node -e "
    const fs = require('fs');
    const buf = fs.readFileSync('$RESOURCES_DIR/app.asar');
    const hs = buf.readUInt32LE(4);
    const h = JSON.parse(buf.subarray(16, 16 + hs - 8).toString('utf8').replace(/\0+$/,''));
    const e = h.files['package.json'];
    const c = buf.subarray(16 + hs - 8 + parseInt(e.offset), 16 + hs - 8 + parseInt(e.offset) + e.size);
    const p = JSON.parse(c.toString('utf8'));
    console.log(p.devDependencies?.electron || '');
  ")

  local installed
  installed=$(node -e "console.log(require('$SCRIPT_DIR/node_modules/electron/package.json').version)")

  if [[ -n "$required" && "$required" != "$installed" ]]; then
    echo "Electron version mismatch: app requires $required, installed $installed"
    echo "Updating Electron..."
    cd "$SCRIPT_DIR"
    npm install "electron@$required"
  else
    echo "Electron version OK: $installed"
  fi
}

# ---------------------------------------------------------------------------
# Create .desktop file and install icon
# ---------------------------------------------------------------------------
install_desktop_entry() {
  local icon_src="$RESOURCES_DIR/icon.png"
  if [[ ! -f "$icon_src" ]]; then
    echo "Warning: icon.png not found, skipping .desktop entry"
    return
  fi

  mkdir -p "$ICON_DIR"
  cp "$icon_src" "$ICON_DIR/claude-desktop.png"

  local electron_bin="$SCRIPT_DIR/node_modules/electron/dist/electron"
  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Claude
Comment=Claude Desktop by Anthropic
Exec=$electron_bin $SCRIPT_DIR --no-sandbox %U
Icon=claude-desktop
Type=Application
Categories=Development;Utility;
StartupWMClass=Claude
MimeType=x-scheme-handler/claude;
EOF

  # Update desktop database if available
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  fi

  echo "Desktop entry installed: $DESKTOP_FILE"
}

# ---------------------------------------------------------------------------
# Print app version info
# ---------------------------------------------------------------------------
print_version() {
  node -e "
    const fs = require('fs');
    const buf = fs.readFileSync('$RESOURCES_DIR/app.asar');
    const hs = buf.readUInt32LE(4);
    const h = JSON.parse(buf.subarray(16, 16 + hs - 8).toString('utf8').replace(/\0+$/,''));
    const e = h.files['package.json'];
    const c = buf.subarray(16 + hs - 8 + parseInt(e.offset), 16 + hs - 8 + parseInt(e.offset) + e.size);
    const p = JSON.parse(c.toString('utf8'));
    console.log('  App version: ' + p.version);
    console.log('  Electron:    ' + (p.devDependencies?.electron || 'unknown'));
  "
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "=== Claude Desktop for Linux ==="
  echo ""

  check_deps
  install_deps
  extract_resources
  check_electron_version
  install_desktop_entry

  echo ""
  echo "=== Setup complete ==="
  print_version
  echo ""
  echo "Launch with:"
  echo "  npm start"
  echo ""
  echo "Or find 'Claude' in your application launcher."
}

main "$@"
