#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
ENV_HOME="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"

: > "$LOG_FILE"

# ---------- 彩色日志 ----------
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
info_echo()      { log "[1;34mℹ $1[0m"; }
warm_echo()      { log "[1;33m$1[0m"; }
note_echo()      { log "[1;35m➤ $1[0m"; }
error_echo()     { log "[1;31m✖ $1[0m"; }
gray_echo()      { log "[0;90m$1[0m"; }
bold_echo()      { log "[1m$1[0m"; }

jobs_x_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
x - 执行文件
============================================================

这是 x.command 的内置自述，不读取同级 README.md。

功能：
  给拖入的脚本 chmod +x 并执行。

结构：
  Scripts/x.command/x.command
  Scripts/x.command/README.md

运行：
  x
  x [参数...]

说明：
  - 具体实现放在 Scripts 私有库和本命令入口中。
  - 终端可输入命令本身只通过本文件对外暴露。
  - 日志路径：/tmp/x.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 x..."
    local _answer=""
    IFS= read -r _answer
  fi
}

jobs_x_source_lib() {
  local lib_name="$1"
  local candidate=""
  local candidates=(
    "$SCRIPT_DIR/../_lib/$lib_name"
    "$ENV_HOME/Scripts/_lib/$lib_name"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      source "$candidate"
      return 0
    fi
  done

  error_echo "缺少私有库：$lib_name"
  error_echo "请重新执行 JobsMacEnv 安装脚本。"
  return 1
}

jobs_x_source_lib "jobs_path_lib.zsh" || { return 1 2>/dev/null || exit 1; }

x() {
  jobs_path_x_impl "$@"
}

jobs_x_main() {
  jobs_x_show_readme_and_wait
  x "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_x_main "$@"
fi
