#!/bin/zsh
# Builds ScriptRunnerBar from source and installs the .app.
#
#   ./Scripts/install.sh               install to ~/Applications and (re)launch
#   ./Scripts/install.sh --prefix DIR  install to DIR only, no launch (Homebrew)
#
# SWIFT_BUILD_FLAGS adds `swift build` flags; the formula passes --disable-sandbox.

set -euo pipefail

APP_NAME="ScriptRunnerBar"
SCRIPTS_DIR="${HOME}/Scripts"

INSTALL_DIR="${HOME}/Applications"
INTERACTIVE=true
if [[ "${1:-}" == "--prefix" ]]; then
  INSTALL_DIR="${2:?--prefix needs a directory}"
  INTERACTIVE=false
elif (( $# > 0 )); then
  print -u2 "usage: $0 [--prefix DIR]"
  exit 64
fi

APP_BUNDLE="${INSTALL_DIR}/${APP_NAME}.app"
BINARY_PATH="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
# Word-split on purpose: zsh's ${=VAR} turns "a b" into two arguments.
SWIFT_FLAGS=(-c release ${=SWIFT_BUILD_FLAGS:-})

print_step() { print -P "\n%F{blue}==>%f %B$1%b"; }
print_ok()   { print -P "    %F{green}ok%f $1"; }
print_err()  { print -P "    %F{red}error%f $1"; }

cd "$(dirname "$0")/.."

print -P "\n%B${APP_NAME} installer%b"

# --- Preflight ------------------------------------------------------------
print_step "Checking requirements"

OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if (( OS_MAJOR < 15 )); then
  print_err "macOS 15 or later required (found $(sw_vers -productVersion))"
  exit 1
fi
print_ok "macOS $(sw_vers -productVersion)"

if ! command -v swift >/dev/null 2>&1; then
  print_err "No Swift toolchain found. Install it, then re-run this script:"
  print "\n      xcode-select --install\n"
  exit 1
fi

SWIFT_MAJOR=$(swift --version 2>&1 | grep -o 'Swift version [0-9]*' | head -1 | grep -o '[0-9]*$')
if (( ${SWIFT_MAJOR:-0} < 6 )); then
  print_err "Swift 6 or later required (found $(swift --version 2>&1 | grep -o 'Swift version [0-9.]*' | head -1))"
  print "\n      Update Xcode or the Command Line Tools, then re-run this script.\n"
  exit 1
fi
print_ok "$(swift --version 2>&1 | grep -o 'Swift version [0-9.]*' | head -1)"

# --- Quit the running copy ------------------------------------------------
# Match the full binary path so this can never hit an unrelated process.
if $INTERACTIVE && pgrep -f "${BINARY_PATH}" >/dev/null 2>&1; then
  pkill -f "${BINARY_PATH}" || true
  sleep 1   # let it release the menu bar item before the new one appears
  print_ok "quit the running copy"
fi

# --- Build ----------------------------------------------------------------
print_step "Building"

if ! swift build "${SWIFT_FLAGS[@]}" 2>&1 | sed 's/^/    /'; then
  print_err "Build failed. Please open an issue with the output above."
  exit 1
fi
BINARY="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)/${APP_NAME}"

# --- Assemble the .app bundle ---------------------------------------------
# The bundle id is what notifications and Launch at Login require.
print_step "Installing to ${INSTALL_DIR}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${BINARY}" "${BINARY_PATH}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Apple silicon refuses unsigned code; a stable signature also keeps
# notification permission across rebuilds.
codesign --force --sign - "${APP_BUNDLE}"
print_ok "${APP_BUNDLE}"

if ! $INTERACTIVE; then
  exit 0
fi

# --- Scripts folder -------------------------------------------------------
if [[ ! -d "${SCRIPTS_DIR}" ]]; then
  mkdir -p "${SCRIPTS_DIR}"

  cat > "${SCRIPTS_DIR}/hello.sh" <<'SCRIPT'
#!/bin/zsh
# @name: Hello
# @description: Example script

echo "ScriptRunnerBar is working."
SCRIPT

  chmod 755 "${SCRIPTS_DIR}/hello.sh"
  print_ok "created ${SCRIPTS_DIR} with an example script"
fi

# --- Launch ---------------------------------------------------------------
open "${APP_BUNDLE}"

cat <<EOF

    Done. ${APP_NAME} is running (menu bar icon: terminal glyph).
    Scripts folder: ${SCRIPTS_DIR}
    To uninstall:   ./Scripts/uninstall.sh

EOF
