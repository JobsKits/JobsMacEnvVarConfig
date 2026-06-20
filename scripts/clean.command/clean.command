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
# 按当前输出级别记录终端信息，并同步写入脚本日志。
color_echo()     { log "[1;32m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
info_echo()      { log "[1;34mℹ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
success_echo()   { log "[1;32m✔ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warn_echo()      { log "[1;33m⚠ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warm_echo()      { log "[1;33m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
note_echo()      { log "[1;35m➤ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
error_echo()     { log "[1;31m✖ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
err_echo()       { log "[1;31m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
debug_echo()     { log "[1;35m🐞 $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
highlight_echo() { log "[1;36m🔹 $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
gray_echo()      { log "[0;90m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
bold_echo()      { log "[1m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
underline_echo() { log "[4m$1[0m"; }

# ---------- 内置自述 ----------
jobs_clean_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
clean - 终端清理
============================================================

这是 clean.command 的内置自述，不读取同级 README.md。

功能：
  清空 zsh 历史、zsh_sessions 残留，并在检测到 Homebrew 时顺手执行 brew cleanup。

结构：
  Scripts/clean.command/clean.command
  Scripts/clean.command/README.md

运行：
  clean
  clean [参数...]

说明：
  - 终端可输入的自定义命令都应独立收进 Scripts。
  - README.md 只作为源码说明；运行时展示的是脚本内置自述。
  - 日志路径：/tmp/clean.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 clean..."
    local _answer=""
    IFS= read -r _answer
  fi
}


# ---------- 命令实现 ----------

# 顺手清理 Homebrew 旧版本包和缓存；Homebrew 不存在或清理失败都不阻断 clean。
jobs_clean_homebrew_cleanup() {
  emulate -L zsh

  command -v brew >/dev/null 2>&1 || return 0

  print -P "%F{blue}ℹ 正在执行 brew cleanup...%f"
  if brew cleanup; then
    print -P "%F{green}✔ Homebrew 垃圾清理完成%f"
  else
    print -P "%F{yellow}⚠ brew cleanup 执行失败，已忽略，继续 clean%f"
  fi
}

# 执行对应的清理操作，并保留必要的安全检查。
clean() {
  emulate -L zsh
  setopt no_nomatch null_glob

  local old_histfile="${HISTFILE:-}"
  local hist_file="${old_histfile:-$HOME/.zsh_history}"
  local old_histsize="${HISTSIZE:-10000}"
  local old_savehist="${SAVEHIST:-$old_histsize}"
  local file
  local history_files=(
    "$hist_file"
    "$HOME/.zsh_history"
    "$HOME/.zsh_sessions"/*.history(N)
    "$HOME/.zsh_sessions"/*.historynew(N)
  )

  HISTSIZE=0
  SAVEHIST=0
  builtin fc -W "$hist_file" 2>/dev/null || true

  for file in "${history_files[@]}"; do
    [[ -n "$file" ]] || continue
    [[ -e "$file" || -L "$file" ]] || continue
    : >| "$file" 2>/dev/null || true
  done

  jobs_clean_homebrew_cleanup

  HISTSIZE="$old_histsize"
  SAVEHIST="$old_savehist"
  if [[ -n "$old_histfile" ]]; then
    HISTFILE="$old_histfile"
  else
    unset HISTFILE
  fi

  printf '\033[H\033[2J\033[3J'
  printf '\033]1337;ClearScrollback\007'
  printf '\033[H'
}

# ---------- 主流程统一收口 ----------
jobs_clean_main() {
  jobs_clean_show_readme_and_wait
  clean "$@"
}

# 统一收口脚本入口，仅委托已经拆分完成的业务流程。
main() {
  # 主入口只负责委托完整业务流程，复杂逻辑统一下沉。
  jobs_clean_main "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  main "$@"
fi
