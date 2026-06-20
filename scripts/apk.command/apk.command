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
# 按当前输出级别记录终端信息，并同步写入脚本日志。
info_echo()      { log "[1;34mℹ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warm_echo()      { log "[1;33m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
note_echo()      { log "[1;35m➤ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
error_echo()     { log "[1;31m✖ $1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
gray_echo()      { log "[0;90m$1[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
bold_echo()      { log "[1m$1[0m"; }

# 展示脚本用途和影响范围，并在执行前等待用户确认。
jobs_apk_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
apk - 构建 APK
============================================================

这是 apk.command 的内置自述，不读取同级 README.md。

功能：
  检查 Flutter / FVM / JDK 17 后构建 Android APK。

结构：
  Scripts/apk.command/apk.command
  Scripts/apk.command/README.md

运行：
  apk
  apk [参数...]

说明：
  - 具体实现放在 Scripts 私有库和本命令入口中。
  - 终端可输入命令本身只通过本文件对外暴露。
  - 日志路径：/tmp/apk.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 apk..."
    local _answer=""
    IFS= read -r _answer
  fi
}

# 封装 jobs_apk_source_lib 对应的独立处理逻辑。
jobs_apk_source_lib() {
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

jobs_apk_source_lib "jobs_flutter_lib.zsh" || { return 1 2>/dev/null || exit 1; }

# 封装 apk 对应的独立处理逻辑。
apk() {
  jobs_flutter_apk_impl "$@"
}

# 编排完整业务流程，复杂步骤继续下沉到职责明确的函数。
jobs_apk_main() {
  jobs_apk_show_readme_and_wait
  apk "$@"
}

# 统一收口脚本入口，仅委托已经拆分完成的业务流程。
main() {
  # 主入口只负责委托完整业务流程，复杂逻辑统一下沉。
  jobs_apk_main "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  main "$@"
fi
