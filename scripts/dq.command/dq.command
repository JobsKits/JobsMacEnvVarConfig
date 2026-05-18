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
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

# ---------- 内置自述 ----------
jobs_dq_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
dq - 解除 macOS quarantine 隔离属性
============================================================

这是 dq.command 的内置自述，不读取同级 README.md。

功能：
  递归删除指定文件 / 目录上的 com.apple.quarantine 扩展属性。
  不传路径时，默认处理当前终端所在目录。

结构：
  Scripts/dq.command/dq.command
  Scripts/dq.command/README.md

运行：
  dq
  dq .
  dq ~/Downloads
  dq --dry-run
  dq --yes
  dq --restart-finder

安全说明：
  - 该操作会让下载文件不再触发 macOS 来源验证弹窗。
  - 默认必须输入 YES 才会真正执行。
  - --dry-run 只扫描并列出带 quarantine 属性的项目，不修改文件。
  - --yes 会跳过 YES 确认，只建议在可信目录中使用。
  - --restart-finder 会在完成后重启 Finder，用于刷新 Finder / 默认打开方式缓存。

说明：
  - 终端可输入的自定义命令都应独立收进 Scripts。
  - README.md 只作为源码说明；运行时展示的是脚本内置自述。
  - 日志路径：/tmp/dq.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 dq；按 Ctrl+C 取消。"
    local _answer=""
    IFS= read -r _answer
  fi
}

# ---------- 帮助 ----------
jobs_dq_print_usage() {
  cat <<'EOFUSAGE' | tee -a "$LOG_FILE"

用法：
  dq [选项] [文件或目录...]

默认：
  不传文件或目录时，递归处理当前目录。

选项：
  -y, --yes             跳过 YES 确认，直接执行
  -n, --dry-run         只扫描，不修改
  --restart-finder      完成后重启 Finder
  -h, --help            显示帮助

示例：
  dq
  dq .
  dq ~/Downloads
  dq --yes ~/Downloads
  dq --dry-run ~/Downloads
EOFUSAGE
}

# ---------- 通用工具 ----------
jobs_dq_require_xattr() {
  if command -v xattr >/dev/null 2>&1; then
    return 0
  fi

  error_echo "未检测到 xattr 命令。该工具只适用于 macOS。"
  return 1
}

jobs_dq_expand_path() {
  local raw="$1"

  if [[ "$raw" == "~" ]]; then
    print -r -- "$HOME"
    return 0
  fi

  if [[ "$raw" == ~/* ]]; then
    print -r -- "${HOME}${raw#~}"
    return 0
  fi

  print -r -- "$raw"
}

jobs_dq_list_items() {
  emulate -L zsh
  setopt no_nomatch null_glob

  local target="$1"
  local item=""

  if [[ -f "$target" || -L "$target" ]]; then
    if command xattr -p com.apple.quarantine "$target" >/dev/null 2>&1; then
      print -r -- "$target"
    fi
    return 0
  fi

  if [[ -d "$target" ]]; then
    find "$target" -print0 2>/dev/null | while IFS= read -r -d $'\0' item; do
      if command xattr -p com.apple.quarantine "$item" >/dev/null 2>&1; then
        print -r -- "$item"
      fi
    done
    return 0
  fi

  return 1
}

jobs_dq_dry_run() {
  local -a targets
  targets=("$@")

  local target=""
  local expanded=""
  local found=""
  local total=0

  highlight_echo "扫描 quarantine 属性"

  for target in "${targets[@]}"; do
    expanded="$(jobs_dq_expand_path "$target")"

    if [[ ! -e "$expanded" && ! -L "$expanded" ]]; then
      warn_echo "跳过，不存在：$expanded"
      continue
    fi

    note_echo "扫描：$expanded"
    while IFS= read -r found; do
      [[ -n "$found" ]] || continue
      total=$((total + 1))
      log "  $found"
    done < <(jobs_dq_list_items "$expanded")
  done

  if (( total == 0 )); then
    success_echo "未发现带 quarantine 属性的项目。"
  else
    success_echo "扫描完成，共发现 ${total} 个项目。"
  fi
}

jobs_dq_confirm() {
  local assume_yes="$1"
  shift
  local -a targets
  targets=("$@")

  [[ "$assume_yes" == "true" ]] && return 0

  log ""
  warn_echo "即将递归解除以下路径的 macOS quarantine 属性："
  local target=""
  for target in "${targets[@]}"; do
    log "  $(jobs_dq_expand_path "$target")"
  done

  log ""
  warn_echo "这会绕过这些下载文件的来源验证弹窗。"
  warm_echo "确认执行请输入 YES："

  local answer=""
  IFS= read -r answer

  if [[ "$answer" != "YES" ]]; then
    warn_echo "已取消。"
    return 1
  fi

  return 0
}

jobs_dq_apply_one() {
  local target="$1"
  local expanded=""
  local err_file=""
  local meaningful_err=""

  expanded="$(jobs_dq_expand_path "$target")"

  if [[ ! -e "$expanded" && ! -L "$expanded" ]]; then
    warn_echo "跳过，不存在：$expanded"
    return 0
  fi

  err_file="${TMPDIR:-/tmp}/dq.${$}.${RANDOM}.err"
  note_echo "处理中：$expanded"

  command xattr -dr com.apple.quarantine "$expanded" 2>"$err_file"
  meaningful_err="$(grep -v 'No such xattr' "$err_file" 2>/dev/null | sed '/^[[:space:]]*$/d' || true)"
  rm -f "$err_file" 2>/dev/null || true

  if [[ -n "$meaningful_err" ]]; then
    warn_echo "部分项目处理时出现提示："
    log "$meaningful_err"
    return 0
  fi

  success_echo "已处理：$expanded"
}

jobs_dq_restart_finder() {
  if command -v killall >/dev/null 2>&1; then
    note_echo "正在重启 Finder..."
    killall Finder 2>/dev/null || true
    success_echo "Finder 已刷新。"
  else
    warn_echo "未检测到 killall，已跳过 Finder 刷新。"
  fi
}

# ---------- 命令实现 ----------
dq() {
  emulate -L zsh
  setopt no_nomatch

  local assume_yes="false"
  local dry_run="false"
  local restart_finder="false"
  local show_help="false"
  local -a targets
  targets=()

  while (( $# > 0 )); do
    case "$1" in
      -y|--yes)
        assume_yes="true"
        shift
        ;;
      -n|--dry-run)
        dry_run="true"
        shift
        ;;
      --restart-finder)
        restart_finder="true"
        shift
        ;;
      -h|--help)
        show_help="true"
        shift
        ;;
      --)
        shift
        while (( $# > 0 )); do
          targets+=("$1")
          shift
        done
        ;;
      -*)
        error_echo "未知参数：$1"
        jobs_dq_print_usage
        return 1
        ;;
      *)
        targets+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    jobs_dq_print_usage
    return 0
  fi

  if (( ${#targets[@]} == 0 )); then
    targets=("$PWD")
  fi

  jobs_dq_require_xattr || return 1

  if [[ "$dry_run" == "true" ]]; then
    jobs_dq_dry_run "${targets[@]}"
    return 0
  fi

  jobs_dq_confirm "$assume_yes" "${targets[@]}" || return 1

  local target=""
  for target in "${targets[@]}"; do
    jobs_dq_apply_one "$target"
  done

  if [[ "$restart_finder" == "true" ]]; then
    jobs_dq_restart_finder
  fi

  gray_echo "日志路径：$LOG_FILE"
}

# ---------- 主流程统一收口 ----------
jobs_dq_main() {
  jobs_dq_show_readme_and_wait
  dq "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_dq_main "$@"
fi
