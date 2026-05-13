#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

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
