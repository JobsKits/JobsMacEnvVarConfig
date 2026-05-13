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
jobs_decode_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
decode - URL 解码
============================================================

这是 decode.command 的内置自述，不读取同级 README.md。

功能：
  交互式 URL Decode，并自动复制结果到剪贴板。

结构：
  Scripts/decode.command/decode.command
  Scripts/decode.command/README.md

运行：
  decode
  decode [参数...]

说明：
  - 终端可输入的自定义命令都应独立收进 Scripts。
  - README.md 只作为源码说明；运行时展示的是脚本内置自述。
  - 日志路径：/tmp/decode.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 decode..."
    local _answer=""
    IFS= read -r _answer
  fi
}


# ---------- 命令实现 ----------
# 🔥 URL Decode REPL（decode -> 解码 + 自动 pbcopy）🔥
decode() {
  emulate -L zsh
  setopt no_aliases

  local input decoded

  # 统一提示
  print -P "%F{cyan}🔤 decode%f：粘贴要转的字符串/URL（支持 %E8%B6%85...）"
  print -P "%F{cyan}        回车=解码并复制到剪切板；q/quit/exit=退出%f"

  while true; do
    # -r：不转义反斜杠；?prompt：zsh 的提示符
    read -r "?👉 输入： " input || break

    # 退出指令
    case "$input" in
      q|Q|quit|QUIT|exit|EXIT)
        print -P "%F{green}✅ 已退出 decode%f"
        return 0
        ;;
    esac

    # 空输入：继续下一轮
    if [[ -z "$input" ]]; then
      print -P "%F{yellow}⚠️  请输入内容（或 q 退出）%f"
      continue
    fi

    # 用 python3 解码（macOS 基本都有；比 perl 更稳）
    decoded="$(python3 - <<'PY' "$input" 2>/dev/null
import sys, urllib.parse
print(urllib.parse.unquote(sys.argv[1]))
PY
)" || decoded=""

    if [[ -z "$decoded" ]]; then
      print -P "%F{red}❌ 解码失败：请确认你粘贴的是一整串内容%f"
      continue
    fi

    # 显示 + 复制
    print -P "%F{green}✅ 解码结果：%f$decoded"
    print -r -- "$decoded" | pbcopy
    print -P "%F{magenta}📋 已复制到剪切板%f"
  done
}

# ---------- 主流程统一收口 ----------
jobs_decode_main() {
  jobs_decode_show_readme_and_wait
  decode "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_decode_main "$@"
fi
