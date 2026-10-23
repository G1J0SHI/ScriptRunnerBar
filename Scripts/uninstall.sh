#!/bin/zsh
# Removes a ./Scripts/install.sh install and its preferences. Never touches
# your scripts. (Homebrew installs: `brew uninstall ScriptRunnerBar`.)

set -euo pipefail

APP_NAME="ScriptRunnerBar"
APP_BUNDLE="${HOME}/Applications/${APP_NAME}.app"
BUNDLE_ID="com.ScriptRunnerBar.app"

print_ok() { print -P "    %F{green}ok%f $1"; }

print -P "\n%B${APP_NAME} uninstaller%b\n"

BINARY_PATH="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if pgrep -f "${BINARY_PATH}" >/dev/null 2>&1; then
  pkill -f "${BINARY_PATH}" || true
  sleep 1
  print_ok "quit the running app"
fi

if [[ -d "${APP_BUNDLE}" ]]; then
  rm -rf "${APP_BUNDLE}"
  print_ok "removed ${APP_BUNDLE}"
else
  print_ok "no app bundle found (already removed)"
fi

if defaults read "${BUNDLE_ID}" >/dev/null 2>&1; then
  defaults delete "${BUNDLE_ID}" 2>/dev/null || true
  print_ok "removed saved preferences"
fi

# `leftover`, not `path`: in zsh, `path` is tied to PATH.
for leftover in \
  "${HOME}/Library/Caches/${BUNDLE_ID}" \
  "${HOME}/Library/HTTPStorages/${BUNDLE_ID}" \
  "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
do
  if [[ -e "${leftover}" ]]; then
    rm -rf "${leftover}"
    print_ok "removed $(basename "${leftover}")"
  fi
done

print ""
print "    Uninstalled."
print ""
print "    Your scripts in ~/Scripts were left untouched."
print ""
