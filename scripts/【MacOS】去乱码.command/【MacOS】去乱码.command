#!/bin/zsh

set -u
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

# ---------- 运行配置 ----------
MODE="unquote"

# ---------- 交互 ----------
show_readme_and_wait() {
  clear
  bold_echo "flat - 去乱码 / URL 解码工具"
  gray_echo "脚本路径：$SCRIPT_PATH"
  gray_echo "日志路径：$LOG_FILE"
  log ""
  note_echo "功能说明"
  log "  1. 还原 URL 百分号编码文本，例如：%E4%BD%A0%E5%A5%BD。"
  log "  2. 支持命令参数直接解码，也支持交互输入。"
  log "  3. 解码结果会打印到终端。"
  log "  4. macOS 下检测到 pbcopy 时，会自动复制结果到剪贴板。"
  log ""
  note_echo "常用方式"
  log "  flat"
  log "  flat \"%E4%BD%A0%E5%A5%BD\""
  log "  flat --plus \"hello+world%21\""
  log ""
  note_echo "参数说明"
  log "  --plus    把 + 一并解析为空格，适合表单编码文本。"
  log "  -h        显示帮助。"
  log "  --help    显示帮助。"
  log ""
  note_echo "流程"
  log "  启动 flat"
  log "      ↓"
  log "  显示本内置自述并等待回车"
  log "      ↓"
  log "  读取参数或进入交互输入"
  log "      ↓"
  log "  使用 python3 或 ruby 解码"
  log "      ↓"
  log "  打印结果并复制到剪贴板"

  log ""
  warm_echo "已阅读内置自述，按回车继续执行；按 Ctrl+C 取消。"
  local _answer=""
  IFS= read -r _answer
}

pause_to_exit() {
  log ""
  warm_echo "按回车退出..."
  local _answer=""
  IFS= read -r _answer
}

print_usage() {
  cat <<'USAGE' | tee -a "$LOG_FILE"

用法：
  flat
  flat "URL编码文本"
  flat --plus "URL编码文本"

参数：
  --plus    把 + 一并解析为空格，适合表单编码文本。
  -h        显示帮助。
  --help    显示帮助。

示例：
  flat "%E4%BD%A0%E5%A5%BD"
  flat --plus "hello+world%21"
USAGE
}

# ---------- 文本处理 ----------
decode_text() {
  local mode="$1"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys
from urllib.parse import unquote, unquote_plus
mode = sys.argv[1]
data = sys.stdin.read()
fn = unquote_plus if mode == "plus" else unquote
sys.stdout.write(fn(data))
' "$mode"
    return $?
  fi

  if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "uri"
mode = ARGV[0]
data = STDIN.read
if mode == "plus"
  print URI.decode_www_form_component(data)
else
  print URI::DEFAULT_PARSER.unescape(data)
end
' "$mode"
    return $?
  fi

  error_echo "缺少 python3 或 ruby，无法解码。"
  return 1
}

copy_clipboard() {
  local text="$1"

  [[ -z "$text" ]] && return 0

  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$text" | pbcopy
    success_echo "已复制到系统剪贴板。"
  else
    warn_echo "未检测到 pbcopy，已跳过复制。"
  fi
}

handle_one() {
  local input="$1"
  local decoded=""

  decoded="$(printf "%s" "$input" | decode_text "$MODE")" || return 1

  success_echo "解码结果："
  printf "%s\n" "$decoded" | tee -a "$LOG_FILE"
  copy_clipboard "$decoded"
}

handle_arguments() {
  while (( $# > 0 )); do
    case "$1" in
      --plus)
        MODE="plus"
        shift
        ;;
      -h|--help)
        show_readme_and_wait
        print_usage
        pause_to_exit
        return 0
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  show_readme_and_wait
  [[ "$MODE" == "plus" ]] && warn_echo "已启用 --plus：+ 会被解析为空格。"

  if (( $# > 0 )); then
    local item=""
    for item in "$@"; do
      note_echo "原文：$item"
      handle_one "$item"
    done
    pause_to_exit
    return 0
  fi

  interactive_loop
}

interactive_loop() {
  local input=""

  while true; do
    log ""
    note_echo "请输入 URL 编码字符串。输入 q / quit / exit 退出。"
    IFS= read -r input

    case "$input" in
      q|quit|exit)
        info_echo "已退出。"
        break
        ;;
      "")
        continue
        ;;
      *)
        handle_one "$input"
        ;;
    esac
  done
}

# ---------- 主流程统一收口 ----------
main() {
  handle_arguments "$@"
  gray_echo "日志路径：$LOG_FILE"
}

main "$@"
