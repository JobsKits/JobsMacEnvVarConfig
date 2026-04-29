# z <path>
# 支持：
# - macOS Finder 替身（alias）
# - Unix 软链接（symlink）
# - 普通目录
# 行为：
# - 解析到真实路径
# - 如果目标是文件，则 cd 到其所在目录
# - 输出最终真实目录

zz() {
  emulate -L zsh
  setopt no_nomatch

  local input_path resolved_path final_dir

  if (( $# == 0 )); then
    echo "usage: zr <path>"
    return 1
  fi

  input_path="$*"

  if [[ "$input_path" == "~"* ]]; then
    input_path="${~input_path}"
  fi

  # Finder 拖进终端时最常见的是空格被转义
  input_path="${input_path//\\ / }"

  if [[ ! -e "$input_path" && ! -L "$input_path" ]]; then
    echo "zr: path not found: $input_path"
    return 1
  fi

  # 1) 先用 Cocoa 解析 macOS alias file
  resolved_path="$(/usr/bin/osascript 2>/dev/null <<EOF
use framework "Foundation"
use scripting additions

set p to "$input_path"
set u to current application's NSURL's fileURLWithPath:p
set {r, e} to current application's NSURL's URLByResolvingAliasFileAtURL:u options:0 |error|:(reference)
if r is missing value then
  return ""
else
  return (r's |path|()) as text
end if
EOF
)"

  # 2) 如果不是 Finder alias，再处理 Unix symlink / 普通路径
  if [[ -z "$resolved_path" ]]; then
    if command -v /usr/bin/realpath >/dev/null 2>&1; then
      resolved_path="$(/usr/bin/realpath "$input_path" 2>/dev/null)"
    fi
  fi

  # 3) 最后兜底
  [[ -n "$resolved_path" ]] || resolved_path="$input_path"
  resolved_path="${resolved_path%/}"

  if [[ -d "$resolved_path" ]]; then
    final_dir="$resolved_path"
  elif [[ -f "$resolved_path" ]]; then
    final_dir="${resolved_path:h}"
  else
    echo "zr: invalid resolved target: $resolved_path"
    return 1
  fi

  builtin cd "$final_dir" || return 1
  /bin/pwd
}

# x <file>
# 支持：
# - 终端里直接拖入 .command / .sh / 可执行文件
# 行为：
# - 自动处理 Finder 拖入路径里的转义空格
# - 自动 chmod +x
# - 直接执行该文件
x() {
  emulate -L zsh
  setopt no_nomatch

  local input_path

  if (( $# == 0 )); then
    echo "usage: x <file>"
    return 1
  fi

  input_path="$*"

  if [[ "$input_path" == "~"* ]]; then
    input_path="${~input_path}"
  fi

  input_path="${input_path//\\ / }"

  if [[ ! -e "$input_path" ]]; then
    echo "x: file not found: $input_path"
    return 1
  fi

  if [[ -d "$input_path" ]]; then
    echo "x: target is a directory, not a file: $input_path"
    return 1
  fi

  chmod +x "$input_path" || {
    echo "x: chmod failed: $input_path"
    return 1
  }

  "$input_path"
}

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
