#!/bin/zsh

set -euo pipefail

# ============================================================
# JDK 17 安装脚本
# - 检测并安装 JDK 17
# - 优先使用 Homebrew Cask：temurin@17 / zulu@17
# - 兜底使用 Homebrew Formula：openjdk@17
# ============================================================

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

# ---------- 彩色日志 ----------
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
color_echo()     { log "\033[1;32m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warm_echo()      { log "\033[1;33m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
err_echo()       { log "\033[1;31m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
gray_echo()      { log "\033[0;90m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
bold_echo()      { log "\033[1m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
underline_echo() { log "\033[4m$1\033[0m"; }

# ---------- 常量 ----------
readonly JDK_VERSION="17"
typeset -r -a JAVA_CANDIDATES=("temurin@17" "zulu@17" "openjdk@17")

# ---------- 基础工具 ----------
press_enter_to_continue() {
  local prompt="${1:-按 Enter 继续...}"
  echo ""
  warm_echo "$prompt"
  local _answer
  IFS= read -r _answer
}

# 展示脚本用途和影响范围，并在执行前等待用户确认。
show_readme() {
  clear
  bold_echo "🌍 JDK 17 安装脚本"
  gray_echo "脚本路径：$SCRIPT_PATH"
  gray_echo "日志路径：$LOG_FILE"
  echo ""
  note_echo "功能说明"
  log "  1. 检测系统是否已经存在 JDK 17。"
  log "  2. 未安装时，通过 Homebrew 自动安装。"
  log "  3. 安装顺序：temurin@17 → zulu@17 → openjdk@17。"
  log "  4. 若使用 openjdk@17，会尝试补齐 /usr/libexec/java_home 可识别的软链接。"
  echo ""
  note_echo "交互规则"
  log "  - Homebrew 已安装时：回车跳过更新，输入任意字符后回车执行更新。"
  log "  - 安装 JDK 属于脚本目标流程，会在未检测到 JDK 17 时自动执行。"
  echo ""
  press_enter_to_continue "确认要继续，请按 Enter..."
  clear
}

# 解析并返回后续流程需要的目标信息。
get_cpu_arch() {
  uname -m
}

# 解析并返回后续流程需要的目标信息。
get_profile_file() {
  case "${SHELL##*/}" in
    zsh)  echo "$HOME/.zprofile" ;;
    bash) echo "$HOME/.bash_profile" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

# 检查当前运行条件是否满足后续流程要求。
ensure_file_exists() {
  local file_path="$1"
  [[ -f "$file_path" ]] || touch "$file_path"
}

# ---------- Homebrew ----------
find_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  local candidate
  for candidate in "/opt/homebrew/bin/brew" "/usr/local/bin/brew"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# 封装 inject_shellenv_block 对应的独立处理逻辑。
inject_shellenv_block() {
  local profile_file="$1"
  local brew_bin="$2"
  local block_id="homebrew_env"
  local header="# >>> ${block_id} 环境变量 >>>"
  local footer="# <<< ${block_id} 环境变量 <<<"
  local shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""

  ensure_file_exists "$profile_file"

  if grep -Fq "$header" "$profile_file"; then
    info_echo "Homebrew 环境变量块已存在：$profile_file"
  elif grep -Fq "$shellenv_cmd" "$profile_file"; then
    info_echo "Homebrew shellenv 已存在：$profile_file"
  else
    {
      echo ""
      echo "$header"
      echo "$shellenv_cmd"
      echo "$footer"
    } >> "$profile_file"
    success_echo "已写入 Homebrew 环境变量：$profile_file"
  fi

  eval "$($brew_bin shellenv)"
  success_echo "Homebrew 环境变量已在当前会话生效"
}

# 执行对应的环境配置或同步处理。
install_homebrew_if_needed() {
  local arch shell_path profile_file brew_bin
  arch="$(get_cpu_arch)"
  shell_path="${SHELL##*/}"
  profile_file="$(get_profile_file)"

  if brew_bin="$(find_brew_bin 2>/dev/null)"; then
    inject_shellenv_block "$profile_file" "$brew_bin"
    info_echo "Homebrew 已安装：$brew_bin"
    echo ""
    info_echo "是否执行 Homebrew 更新？"
    log "👉 按 Enter：跳过更新"
    log "👉 输入任意字符后回车：执行 brew update && brew upgrade && brew cleanup && brew doctor && brew -v"

    local confirm
    IFS= read -r confirm
    if [[ -z "$confirm" ]]; then
      note_echo "已跳过 Homebrew 更新"
      return 0
    fi

    info_echo "正在更新 Homebrew..."
    brew update  || { error_echo "brew update 失败"; return 1; }
    brew upgrade || { error_echo "brew upgrade 失败"; return 1; }
    brew cleanup || { error_echo "brew cleanup 失败"; return 1; }
    brew doctor  || warn_echo "brew doctor 有警告，请按提示处理"
    brew -v      || warn_echo "打印 brew 版本失败，可忽略"
    success_echo "Homebrew 更新流程完成"
    return 0
  fi

  warn_echo "未检测到 Homebrew，开始安装...（架构：$arch，Shell：$shell_path）"

  if [[ "$arch" == "arm64" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      error_echo "Homebrew 安装失败（arm64）"
      return 1
    }
    brew_bin="/opt/homebrew/bin/brew"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      error_echo "Homebrew 安装失败（x86_64）"
      return 1
    }
    brew_bin="/usr/local/bin/brew"
  fi

  [[ -x "$brew_bin" ]] || {
    error_echo "Homebrew 安装后仍未找到 brew：$brew_bin"
    return 1
  }

  inject_shellenv_block "$profile_file" "$brew_bin"
  success_echo "Homebrew 安装完成"
}

# ---------- JDK 检测 ----------
has_java17() {
  [[ -x /usr/libexec/java_home ]] || return 1
  /usr/libexec/java_home -v "$JDK_VERSION" >/dev/null 2>&1
}

# 解析并返回后续流程需要的目标信息。
get_java17_home() {
  /usr/libexec/java_home -v "$JDK_VERSION" 2>/dev/null || true
}

# 封装 print_java17_info 对应的独立处理逻辑。
print_java17_info() {
  local java_home
  java_home="$(get_java17_home)"
  [[ -n "$java_home" ]] || return 1

  success_echo "已检测到 JDK $JDK_VERSION"
  log "JAVA_HOME=$java_home"

  if [[ -x "$java_home/bin/java" ]]; then
    "$java_home/bin/java" -version 2>&1 | tee -a "$LOG_FILE" || true
  fi
}

# ---------- JDK 安装 ----------
install_jdk_candidate() {
  local candidate="$1"

  highlight_echo "尝试安装：$candidate"

  if [[ "$candidate" == openjdk@* ]]; then
    brew install "$candidate"
  else
    brew install --cask "$candidate"
  fi
}

# 封装 link_openjdk17_for_java_home 对应的独立处理逻辑。
link_openjdk17_for_java_home() {
  local brew_prefix openjdk_home link_path

  brew_prefix="$(brew --prefix openjdk@17 2>/dev/null || true)"
  [[ -n "$brew_prefix" ]] || return 0

  openjdk_home="$brew_prefix/libexec/openjdk.jdk"
  link_path="/Library/Java/JavaVirtualMachines/openjdk-17.jdk"

  [[ -d "$openjdk_home" ]] || return 0
  [[ -e "$link_path" ]] && return 0

  warn_echo "openjdk@17 已安装，但 java_home 可能无法识别，尝试创建系统软链接。"
  log "源路径：$openjdk_home"
  log "目标路径：$link_path"

  sudo mkdir -p "/Library/Java/JavaVirtualMachines" || return 1
  sudo ln -sfn "$openjdk_home" "$link_path" || return 1
  success_echo "已创建 openjdk@17 系统软链接"
}

# 执行对应的环境配置或同步处理。
install_jdk17_if_needed() {
  if has_java17; then
    print_java17_info
    return 0
  fi

  warn_echo "未检测到 JDK $JDK_VERSION，开始安装。"

  local candidate
  for candidate in "${JAVA_CANDIDATES[@]}"; do
    if install_jdk_candidate "$candidate"; then
      if [[ "$candidate" == "openjdk@17" ]]; then
        link_openjdk17_for_java_home || warn_echo "openjdk@17 软链接创建失败，请按日志手动处理"
      fi

      if has_java17; then
        print_java17_info
        return 0
      fi

      warn_echo "$candidate 安装完成，但系统暂未识别到 JDK $JDK_VERSION，继续尝试下一个候选项。"
    else
      warn_echo "$candidate 安装失败，继续尝试下一个候选项。"
    fi
  done

  error_echo "JDK $JDK_VERSION 自动安装失败"
  err_echo "建议手动执行：brew install --cask temurin@17"
  return 1
}

# ---------- 收尾 ----------
finish_script() {
  echo ""
  gray_echo "日志文件：$LOG_FILE"
}

# ---------- 主流程入口 ----------
run_main_flow() {
  : > "$LOG_FILE"

  show_readme
  install_homebrew_if_needed
  install_jdk17_if_needed
  finish_script

  success_echo "JDK $JDK_VERSION 检查 / 安装流程结束"
}

# 统一收口脚本入口，仅委托已经拆分完成的业务流程。
main() {
  # 主入口只负责委托完整业务流程，复杂逻辑统一下沉。
  run_main_flow "$@"
}

main "$@"
