#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

: > "$LOG_FILE"

# ---------- 彩色日志 ----------
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "[1;32m$1[0m"; }
info_echo()      { log "[1;34mℹ $1[0m"; }
success_echo()   { log "[1;32m✔ $1[0m"; }
warn_echo()      { log "[1;33m⚠ $1[0m"; }
warm_echo()      { log "[1;33m$1[0m"; }
note_echo()      { log "[1;35m➤ $1[0m"; }
error_echo()     { log "[1;31m✖ $1[0m"; }
err_echo()       { log "[1;31m$1[0m"; }
debug_echo()     { log "[1;35m🐞 $1[0m"; }
highlight_echo() { log "[1;36m🔹 $1[0m"; }
gray_echo()      { log "[0;90m$1[0m"; }
bold_echo()      { log "[1m$1[0m"; }
underline_echo() { log "[4m$1[0m"; }

# ---------- 内置自述 ----------
jobs_install_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
install - 新系统环境配置
============================================================

这是 install.command 的内置自述，不读取同级 README.md。

功能：
  安装和初始化常用开发环境依赖。注意：该命令名与系统 /usr/bin/install 有冲突风险。

结构：
  Scripts/install.command/install.command
  Scripts/install.command/README.md

运行：
  install
  install [参数...]

说明：
  - 终端可输入的自定义命令都应独立收进 Scripts。
  - README.md 只作为源码说明；运行时展示的是脚本内置自述。
  - 日志路径：/tmp/install.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 install..."
    local _answer=""
    IFS= read -r _answer
  fi
}


# ---------- 命令实现 ----------
# 🔥 新系统环境配置 🔥
install() {
  set -euo pipefail

  # -------- pretty output --------
  _i() { print -P "%F{cyan}ℹ️  %f$*"; }
  _ok(){ print -P "%F{green}✅ %f$*"; }
  _w() { print -P "%F{yellow}⚠️  %f$*"; }
  _e() { print -P "%F{red}❌ %f$*"; }

  # -------- helpers --------
  _has() { command -v "$1" >/dev/null 2>&1; }

  _append_once() {
    local line="$1"
    local file="${2:-$HOME/.zshrc}"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -Fqx "$line" "$file"; then
      return 0
    fi
    print "" >> "$file"
    print "$line" >> "$file"
  }

  _ensure_homebrew() {
    if _has brew; then
      _ok "Homebrew 已存在：$(brew --version | head -n 1)"
      return 0
    fi

    _i "开始安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    _ok "Homebrew 安装完成"

    # 让当前 shell 立刻可用（Apple Silicon: /opt/homebrew, Intel: /usr/local）
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      _append_once 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zshrc"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
      _append_once 'eval "$(/usr/local/bin/brew shellenv)"' "$HOME/.zshrc"
    fi
  }

  _brew_install_if_needed() {
    local formula="$1"
    if brew list --formula "$formula" >/dev/null 2>&1; then
      _ok "已安装：$formula"
    else
      _i "安装：$formula"
      brew install "$formula"
      _ok "安装完成：$formula"
    fi
  }

  _ensure_jenv_init() {
    # jenv 官方推荐：export PATH + eval init  (brew 安装后仍需要 init) :contentReference[oaicite:1]{index=1}
    _append_once 'export PATH="$HOME/.jenv/bin:$PATH"' "$HOME/.zshrc"
    _append_once 'eval "$(jenv init -)"' "$HOME/.zshrc"
  }

  _ensure_fvm() {
    if _has fvm; then
      _ok "FVM 已存在：$(fvm --version 2>/dev/null || echo "installed")"
      return 0
    fi

    _i "安装 FVM（Homebrew tap -> install）"
    # 常见方式：brew tap leoafarias/fvm && brew install fvm :contentReference[oaicite:2]{index=2}
    brew tap leoafarias/fvm
    brew install fvm
    _ok "FVM 安装完成"
  }

  _post_openjdk_hint() {
    _w "openjdk 安装完成后，若你想让系统 java 指向它："
    _w "  - 你可以用 jenv 管理 JAVA_HOME（推荐）"
    _w "  - 示例：jenv add \"$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk/Contents/Home\""
  }
  
  _ensure_xcode_cli_tools() {
    # 判断 CLT 是否已安装：xcode-select -p 返回路径即为已装
    if xcode-select -p >/dev/null 2>&1; then
      _ok "Xcode Command Line Tools 已存在：$(xcode-select -p)"
      return 0
    fi

    _i "开始安装 Xcode Command Line Tools..."
    xcode-select --install || true
    _w "若弹窗已出现，请完成安装；安装完成后可再次执行 install() 继续。"
  }

  _ensure_ohmyzsh() {
    # 常见安装位置：~/.oh-my-zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      _ok "Oh My Zsh 已存在：$HOME/.oh-my-zsh"
      return 0
    fi

    _i "开始安装 Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    _ok "Oh My Zsh 安装完成"
  }

  # -------- main flow --------
  _ensure_ohmyzsh
  _ensure_xcode_cli_tools
  _ensure_homebrew
  _i "更新 Homebrew..."
  brew update

  xcode-select --install
  softwareupdate --install-rosetta --agree-to-license

  # Flutter 环境（用 fvm 管理 Flutter 版本更稳）
  _ensure_fvm

  # Java / Ruby 工具链
  _brew_install_if_needed jenv      # :contentReference[oaicite:3]{index=3}
  _ensure_jenv_init

  _brew_install_if_needed rbenv     # :contentReference[oaicite:4]{index=4}
  _brew_install_if_needed openjdk   # :contentReference[oaicite:5]{index=5}
  _post_openjdk_hint

  _ok "基础工具安装完成。建议新开一个终端窗口，让 .zshrc 的初始化生效。"

  _i "关于 renv：这是 R 的项目依赖管理包（不是 brew 公式）。你可以在 R 里执行："
  _i '  install.packages("renv")'
  
  # 下载Xcode模拟器配件
  rm -rf ~/Library/Caches/com.apple.dt.Xcode
  rm -rf ~/Library/Developer/CoreSimulator/Caches

  xcodebuild -downloadPlatform iOS -verbose
}

# ---------- 主流程统一收口 ----------
jobs_install_main() {
  jobs_install_show_readme_and_wait
  install "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_install_main "$@"
fi
