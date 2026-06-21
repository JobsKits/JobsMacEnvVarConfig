#!/bin/zsh
# 脚本自述：
# - 脚本名称：clean.command
# - 核心用途：执行“clean”对应的清理任务。
# - 影响范围：可能删除缓存、生成物、配置记录或解除已有跟踪关系。
# - 运行提示：运行后会先打印内置自述；终端模式按回车确认后继续，按 Ctrl+C 可取消。


# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
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
  # 展示脚本说明并等待用户确认影响范围。
  jobs_clean_show_readme_and_wait
  # 清理本次流程产生的临时内容或指定缓存。
  clean "$@"
}
# 打印脚本内置自述，并按运行入口决定是否等待用户确认。
show_script_intro_and_wait() {
  print -r -- '============================== 脚本内置自述 =============================='
  print -r -- '脚本名称：clean.command'
  print -r -- '核心用途：执行“clean”对应的自动化任务。'
  print -r -- '影响范围：可能修改当前项目、用户环境或脚本指定的目标。'
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。'
  print -r -- '============================================================================'
  if [[ ! -t 0 ]]; then
    print -u2 -r -- '当前没有可交互输入，请在终端中重新运行。'
    return 1
  fi
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _
}
# 统一收口脚本入口，仅委托已经拆分完成的业务流程。
main() {
  # 展示脚本内置自述，并按运行入口完成防误触确认。
  show_script_intro_and_wait
  # 清理当前流程产生的临时状态和文件。
  jobs_clean_main "$@"
}
# 初始化脚本运行环境，并集中承载原有的顶层执行逻辑。
initialize_script_module() {
  set -o pipefail
  setopt NO_NOMATCH
  : > "$LOG_FILE"
  if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
    main "$@"
  fi
}
# 加载模块时统一执行必要的初始化和入口分派。
initialize_script_module "$@"
