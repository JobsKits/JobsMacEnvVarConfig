#!/bin/zsh
# 脚本自述：
# - 脚本名称：download.command
# - 核心用途：执行“download”对应的自动化任务。
# - 影响范围：可能修改当前项目、用户环境或脚本指定的目标。
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
jobs_download_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
download - 媒体下载
============================================================

这是 download.command 的内置自述，不读取同级 README.md。

功能：
  调用 yt-dlp，自动使用默认浏览器 cookies 下载媒体。

结构：
  Scripts/download.command/download.command
  Scripts/download.command/README.md

运行：
  download
  download [参数...]

说明：
  - 终端可输入的自定义命令都应独立收进 Scripts。
  - README.md 只作为源码说明；运行时展示的是脚本内置自述。
  - 日志路径：/tmp/download.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 download..."
    local _answer=""
    IFS= read -r _answer
  fi
}
# ---------- 命令实现 ----------
# 检测 macOS 默认浏览器，并转换为 yt-dlp --cookies-from-browser 支持的名字
jobs_detect_default_browser_for_ytdlp() {
  emulate -L zsh

  local bundle_id

  bundle_id="$(osascript 2>/dev/null <<'EOF'
try
  id of application (path to default application for URL "https://www.youtube.com")
on error
  return ""
end try
EOF
)"

  case "$bundle_id" in
    com.google.Chrome)
      echo "chrome"
      ;;
    com.google.Chrome.canary)
      echo "chrome"
      ;;
    com.microsoft.edgemac)
      echo "edge"
      ;;
    org.mozilla.firefox)
      echo "firefox"
      ;;
    com.apple.Safari)
      echo "safari"
      ;;
    *)
      echo ""
      ;;
  esac
}
# download <url>
# 用法：
#   download "https://www.youtube.com/shorts/xxxx?feature=share"
#
# 行为：
# - 自动检测 macOS 默认浏览器
# - 自动带上浏览器 cookies
# - 本质执行：
#   yt-dlp --cookies-from-browser <browser> <url>
download() {
  emulate -L zsh

  if (( $# == 0 )); then
    echo "usage: download <url>"
    return 1
  fi

  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "download: yt-dlp not found"
    echo "install: brew install yt-dlp"
    return 127
  fi

  local browser
  browser="$(jobs_detect_default_browser_for_ytdlp)"

  if [[ -z "$browser" ]]; then
    echo "download: 未识别默认浏览器，回退使用 chrome cookies"
    browser="chrome"
  fi

  echo "download: using cookies from browser: $browser"

  yt-dlp --cookies-from-browser "$browser" "$@"
}
# ---------- 主流程统一收口 ----------
jobs_download_main() {
  # 展示脚本说明并等待用户确认影响范围。
  jobs_download_show_readme_and_wait
  download "$@"
}
# 打印脚本内置自述，并按运行入口决定是否等待用户确认。
show_script_intro_and_wait() {
  print -r -- '============================== 脚本内置自述 =============================='
  print -r -- '脚本名称：download.command'
  print -r -- '核心用途：执行“download”对应的自动化任务。'
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
  # 执行 jobs_download_main 对应的独立业务步骤。
  jobs_download_main "$@"
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
