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

jobs_fixfvm_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
fixfvm - 修复 FVM
============================================================

这是 fixfvm.command 的内置自述，不读取同级 README.md。

功能：
  重装 Dart pub 全局 fvm，修复 FVM 与 Dart SDK 内核版本不匹配。

结构：
  Scripts/fixfvm.command/fixfvm.command
  Scripts/fixfvm.command/README.md

运行：
  fixfvm
  fixfvm [参数...]

说明：
  - 具体实现放在 Scripts 私有库和本命令入口中。
  - 终端可输入命令本身只通过本文件对外暴露。
  - 日志路径：/tmp/fixfvm.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 fixfvm..."
    local _answer=""
    IFS= read -r _answer
  fi
}

jobs_fixfvm_source_lib() {
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

jobs_fixfvm_source_lib "jobs_flutter_lib.zsh" || { return 1 2>/dev/null || exit 1; }

fixfvm() {
  jobs_flutter_fixfvm_impl "$@"
}

jobs_fixfvm_main() {
  jobs_fixfvm_show_readme_and_wait
  fixfvm "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_fixfvm_main "$@"
fi
