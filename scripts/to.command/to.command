#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

: > "$LOG_FILE"
FFMPEG_BIN=""

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

# ---------- 通用交互 ----------
ask_any_to_run() {
  emulate -L zsh

  local message="$1"
  local answer=""

  read -r "?${message}（直接回车跳过；输入任意字符后回车执行）：" answer
  [[ -n "$answer" ]]
}

strip_outer_quotes() {
  emulate -L zsh

  local value="$1"

  # 兼容终端拖入路径：read -r 会保留反斜杠，必须还原空格、括号、方括号等 shell 转义。
  value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  value="${value%$'\r'}"
  value="${value%$'\n'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  value="${(Q)value}"
  value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [[ "$value" == "~/"* ]]; then
    value="$HOME/${value#~/}"
  elif [[ "$value" == "~" ]]; then
    value="$HOME"
  fi

  print -r -- "$value"
}

show_readme_and_wait() {
  emulate -L zsh

  local readme_path="${SCRIPT_DIR}/README.md"

  clear 2>/dev/null || true
  if [[ -f "$readme_path" ]]; then
    highlight_echo "============================== README.md =============================="
    cat "$readme_path" | tee -a "$LOG_FILE"
    highlight_echo "======================================================================="
  else
    warn_echo "未找到 README.md，继续执行内置流程说明。"
    print_usage
  fi

  echo ""
  read -r "?👉 已阅读自述文件，按回车继续执行；按 Ctrl+C 取消：" _
}

# ---------- 依赖检查 ----------
find_brew_bin() {
  emulate -L zsh

  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  local candidate=""
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

find_ffmpeg_bin() {
  emulate -L zsh

  if command -v ffmpeg >/dev/null 2>&1; then
    command -v ffmpeg
    return 0
  fi

  local candidate=""
  for candidate in /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_ffmpeg() {
  emulate -L zsh

  FFMPEG_BIN=""
  if FFMPEG_BIN="$(find_ffmpeg_bin 2>/dev/null)"; then
    return 0
  fi

  warn_echo "未检测到 FFmpeg。"
  local brew_bin=""
  if ! brew_bin="$(find_brew_bin 2>/dev/null)"; then
    error_echo "未检测到 Homebrew，无法自动安装 FFmpeg。"
    gray_echo "可先执行：brew install ffmpeg"
    return 1
  fi

  if ask_any_to_run "是否通过 Homebrew 安装 FFmpeg？"; then
    "$brew_bin" install ffmpeg 2>&1 | tee -a "$LOG_FILE"
    local brew_status=${pipestatus[1]}
    (( brew_status == 0 )) || return "$brew_status"
  else
    error_echo "已跳过 FFmpeg 安装，无法继续转换。"
    gray_echo "可手动执行：brew install ffmpeg"
    return 1
  fi

  if FFMPEG_BIN="$(find_ffmpeg_bin 2>/dev/null)"; then
    return 0
  fi

  error_echo "FFmpeg 安装后仍不可用，请检查 PATH。"
  return 1
}

# ---------- 转换配置 ----------
normalize_ext() {
  emulate -L zsh

  local ext="$1"
  ext="${ext#.}"
  ext="${ext:l}"
  print -r -- "$ext"
}

is_format_shortcut() {
  emulate -L zsh

  local name="$(normalize_ext "$1")"
  local item=""
  local shortcuts=(mp4 mov webm mkv avi m4v mp3 m4a aac wav flac ogg opus gif)

  for item in "${shortcuts[@]}"; do
    [[ "$name" == "$item" ]] && return 0
  done

  return 1
}

next_output_path() {
  emulate -L zsh

  local dir="$1"
  local stem="$2"
  local ext="$3"
  local output="${dir}/${stem}.${ext}"
  local index=1

  while [[ -e "$output" ]]; do
    output="${dir}/${stem}_${index}.${ext}"
    ((index++))
  done

  print -r -- "$output"
}

print_usage() {
  cat <<'EOFUSAGE' | tee -a "$LOG_FILE"
============================================================
to - FFmpeg 通用媒体格式转换
============================================================

常用：
  mp4  <视频文件>
  mov  <视频文件>
  webm <视频文件>
  mp3  <视频文件或音频文件>

通用：
  to mp4  <视频文件>
  to m4a  <视频文件或音频文件>
  to webm <视频文件>

说明：
  - 输入命令和源文件后，脚本会要求输入输出文件名。
  - 输出文件名不需要写后缀。
  - 直接回车沿用原文件名。
  - 输入格式和输出格式相同，不执行转换。
  - 输出文件默认放在源文件同目录。
  - 目标文件已存在时，会自动追加 _1、_2，避免覆盖。

注意：
  - gif 已被 JobsMacEnv 用作录制命令，因此 GIF 转换请使用：to gif <文件>
  - 日志路径：/tmp/to.log 或 /tmp/<快捷命令>.log
============================================================
EOFUSAGE
}

read_target_ext() {
  emulate -L zsh

  local target_ext=""
  while [[ -z "$target_ext" ]]; do
    read -r "?👉 请输入目标格式，例如 mp4 / mov / webm / mp3：" target_ext
    target_ext="$(normalize_ext "$(strip_outer_quotes "$target_ext")")"
  done

  print -r -- "$target_ext"
}

read_input_paths() {
  emulate -L zsh

  local raw_line=""
  local whole_path=""
  local item=""
  local -a items
  local -a parsed_paths

  while true; do
    read -r "?👉 请拖入或输入源文件路径；多个文件可连续拖入后回车，输入 q 取消：" raw_line
    whole_path="$(strip_outer_quotes "$raw_line")"

    case "${whole_path:l}" in
      q|quit|exit)
        warn_echo "已取消输入源文件。"
        return 1
        ;;
    esac

    if [[ -z "$whole_path" ]]; then
      warn_echo "源文件路径为空：请拖入文件，或输入 q 取消。"
      continue
    fi

    # 单文件拖入 / 单文件手写：优先按整行还原，避免中文、空格、方括号路径被错误拆分。
    if [[ -f "$whole_path" ]]; then
      print -r -- "$whole_path"
      return 0
    fi

    # 多文件拖入：再按 zsh 词法拆分，并逐项还原 shell 转义。
    items=("${(@z)raw_line}")
    parsed_paths=()
    for item in "${items[@]}"; do
      item="$(strip_outer_quotes "$item")"
      [[ -n "$item" ]] && parsed_paths+=("$item")
    done

    if (( ${#parsed_paths[@]} == 0 )); then
      warn_echo "没有解析到有效路径，请重新拖入文件。"
      continue
    fi

    for item in "${parsed_paths[@]}"; do
      print -r -- "$item"
    done
    return 0
  done
}

prompt_output_stem() {
  emulate -L zsh

  local old_stem="$1"
  local target_ext="$2"
  local output_stem=""
  local entered_ext=""

  read -r "?👉 请输入输出文件名，不带 .${target_ext}；直接回车沿用原文件名：" output_stem
  output_stem="$(strip_outer_quotes "$output_stem")"

  if [[ -z "$output_stem" ]]; then
    output_stem="$old_stem"
  else
    if [[ "$output_stem" == */* ]]; then
      output_stem="${output_stem:t}"
    fi

    entered_ext="$(normalize_ext "${output_stem:e}")"
    if [[ -n "$entered_ext" && "$entered_ext" == "$target_ext" ]]; then
      output_stem="${output_stem:r}"
    fi
  fi

  print -r -- "$output_stem"
}

# ---------- FFmpeg 执行 ----------
run_and_log() {
  emulate -L zsh

  "$@" 2>&1 | tee -a "$LOG_FILE"
  return ${pipestatus[1]}
}

run_ffmpeg_convert() {
  emulate -L zsh

  local ffmpeg_bin="$1"
  local input_abs="$2"
  local output="$3"
  local target_ext="$4"

  case "$target_ext" in
    mp4)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c:v libx264 -c:a aac -movflags +faststart "$output"
      ;;
    mov)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c:v libx264 -c:a aac "$output"
      ;;
    webm)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c:v libvpx-vp9 -c:a libopus "$output"
      ;;
    mkv)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c copy "$output"
      ;;
    m4v)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c:v libx264 -c:a aac -movflags +faststart "$output"
      ;;
    avi)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -c:v mpeg4 -q:v 5 -c:a libmp3lame -q:a 2 "$output"
      ;;
    mp3)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a libmp3lame -q:a 2 "$output"
      ;;
    m4a)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a aac -b:a 192k "$output"
      ;;
    aac)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a aac -b:a 192k "$output"
      ;;
    wav)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a pcm_s16le "$output"
      ;;
    flac)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a flac "$output"
      ;;
    ogg)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a libvorbis -q:a 5 "$output"
      ;;
    opus)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vn -c:a libopus -b:a 128k "$output"
      ;;
    gif)
      run_and_log "$ffmpeg_bin" -i "$input_abs" -vf "fps=15,scale=720:-1:flags=lanczos" "$output"
      ;;
    *)
      warn_echo "未写入 ${target_ext} 的专用参数，改用 FFmpeg 自动推断。"
      run_and_log "$ffmpeg_bin" -i "$input_abs" "$output"
      ;;
  esac
}

convert_one() {
  emulate -L zsh

  local ffmpeg_bin="$1"
  local target_ext="$2"
  local input="$3"

  input="$(strip_outer_quotes "$input")"

  if [[ ! -f "$input" ]]; then
    error_echo "文件不存在：$input"
    return 1
  fi

  local input_abs="${input:A}"
  local dir="${input_abs:h}"
  local filename="${input_abs:t}"
  local old_stem="${filename:r}"
  local input_ext="$(normalize_ext "${filename:e}")"
  local output_stem=""
  local output=""

  if [[ -n "$input_ext" && "$input_ext" == "$target_ext" ]]; then
    warn_echo "输入文件已经是 .${target_ext} 格式，不执行转换：$input_abs"
    return 1
  fi

  log ""
  highlight_echo "输入：$input_abs"
  output_stem="$(prompt_output_stem "$old_stem" "$target_ext")"
  output="$(next_output_path "$dir" "$output_stem" "$target_ext")"
  highlight_echo "输出：$output"

  run_ffmpeg_convert "$ffmpeg_bin" "$input_abs" "$output" "$target_ext"
  local status=$?

  if (( status == 0 )); then
    success_echo "转换完成：$output"
    return 0
  fi

  error_echo "转换失败：$input_abs"
  if [[ -f "$output" ]]; then
    rm -f "$output" 2>/dev/null || true
    warn_echo "已清理失败产生的半成品文件：$output"
  fi
  return "$status"
}

convert_many() {
  emulate -L zsh

  local target_ext="$(normalize_ext "$1")"
  shift

  if [[ -z "$target_ext" ]]; then
    error_echo "缺少目标格式。"
    print_usage
    return 1
  fi

  if ! ensure_ffmpeg; then
    return 1
  fi

  local ffmpeg_bin="$FFMPEG_BIN"

  local input=""
  local failed=0

  for input in "$@"; do
    convert_one "$ffmpeg_bin" "$target_ext" "$input" || failed=1
  done

  gray_echo "日志路径：$LOG_FILE"
  return "$failed"
}

# ---------- 主流程统一收口 ----------
jobs_to_main() {
  emulate -L zsh

  local target_ext=""
  local -a inputs

  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    print_usage
    return 0
  fi

  if is_format_shortcut "$SCRIPT_BASENAME" && [[ "$SCRIPT_BASENAME" != "to" ]]; then
    target_ext="$(normalize_ext "$SCRIPT_BASENAME")"
    shift 0
  elif (( $# > 0 )); then
    target_ext="$(normalize_ext "$1")"
    shift
  else
    show_readme_and_wait
    target_ext="$(read_target_ext)"
  fi

  if (( $# > 0 )); then
    inputs=("$@")
  else
    inputs=("${(@f)$(read_input_paths)}")
  fi

  if (( ${#inputs[@]} == 0 )); then
    error_echo "没有拿到源文件路径。"
    return 1
  fi

  convert_many "$target_ext" "${inputs[@]}"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_to_main "$@"
fi
