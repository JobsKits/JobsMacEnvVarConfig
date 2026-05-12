#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# 通用：try_run
try_run() {
  local cmd="$1"; shift
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ [$cmd] detected, running: $*"
    eval "$@"
  else
    echo "⚠️  [$cmd] not installed, skip: $*"
  fi
}

# Homebrew 第三方更新（formula/cask/tap）
brew_update_third_party() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "⚠️  [brew] not installed, skip update"
    return 0
  fi

  echo "➤ 🍺 brew update"
  brew update || echo "⚠️  brew update failed (ignored)"

  echo "➤ 📌 brew tap (refresh)"
  brew tap --repair >/dev/null 2>&1 || true

  echo "➤ ⬆️  brew upgrade (formula + cask)"
  brew upgrade || echo "⚠️  brew upgrade failed (ignored)"
  brew upgrade --cask || echo "⚠️  brew upgrade --cask failed (ignored)"

  echo "➤ 🧹 brew cleanup"
  brew cleanup || echo "⚠️  brew cleanup failed (ignored)"

  echo "➤ 🩺 brew doctor (optional)"
  brew doctor || echo "⚠️  brew doctor warnings (ignored)"

  echo "✅ brew third-party update done"
}
