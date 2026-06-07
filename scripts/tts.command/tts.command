#!/bin/zsh

setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

SUPERTONIC_VENV_DIR="${SUPERTONIC_VENV_DIR:-${HOME}/Desktop/supertonic-venv}"
SUPERTONIC_HOST="${SUPERTONIC_HOST:-127.0.0.1}"
SUPERTONIC_PORT="${SUPERTONIC_PORT:-7788}"
SUPERTONIC_VOICE="${SUPERTONIC_VOICE:-M1}"
SUPERTONIC_LANG="${SUPERTONIC_LANG:-auto}"
SUPERTONIC_STEPS="${SUPERTONIC_STEPS:-8}"
SUPERTONIC_SPEED="${SUPERTONIC_SPEED:-1.0}"
SUPERTONIC_OUTPUT_DIR="${SUPERTONIC_OUTPUT_DIR:-${SCRIPT_DIR}/outputs}"
SUPERTONIC_ZH_ENGINE="${SUPERTONIC_ZH_ENGINE:-say}"
SUPERTONIC_ZH_VOICE="${SUPERTONIC_ZH_VOICE:-}"
SUPERTONIC_ZH_RATE="${SUPERTONIC_ZH_RATE:-200}"

SERVER_URL="http://${SUPERTONIC_HOST}:${SUPERTONIC_PORT}"
SERVER_LOG="/tmp/${SCRIPT_BASENAME}.server.log"
SERVER_PID_FILE="/tmp/${SCRIPT_BASENAME}.server.pid"

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
show_readme_and_wait() {
  clear
  highlight_echo "==================== 【MacOS】🔊Supertonic 本地朗读 ===================="
  color_echo "用途：输入文本，调用本机 TTS 生成语音并立即播放。"
  echo ""
  info_echo "Supertonic 服务：${SERVER_URL}"
  info_echo "默认虚拟环境：${SUPERTONIC_VENV_DIR}"
  info_echo "英文等支持语言：走 Supertonic"
  info_echo "中文：默认走 macOS say，避免 Supertonic 中文发音错误"
  echo ""
  note_echo "常用输入："
  gray_echo "  直接输入文本            立即朗读，例如：fuck / 你好"
  gray_echo "  :zh-voices              查看本机中文语音"
  gray_echo "  :zh-voice Tingting      指定中文语音"
  gray_echo "  :zh-rate 200            指定中文语速"
  gray_echo "  :zh-engine say          中文走 macOS say，默认推荐"
  gray_echo "  :zh-engine supertonic   中文也强制走 Supertonic，不推荐"
  gray_echo "  :voice F1               切换 Supertonic 声音"
  gray_echo "  :lang en                切换 Supertonic 语言"
  gray_echo "  :docs                   打开本地接口文档"
  gray_echo "  :stop                   停止本脚本启动的后台服务"
  gray_echo "  :quit                   退出"
  echo ""
  warn_echo "说明：Supertonic 当前没有 zh 中文模型；中文默认交给 macOS say。"
  gray_echo "日志：${LOG_FILE}"
  highlight_echo "======================================================================="
  echo ""
  read -r "?👉 按回车进入朗读；按 Ctrl+C 取消：" _
}

ask_enter_to_run() {
  local message="$1"
  local answer=""
  read -r "?${message}（直接回车执行；输入任意字符后回车跳过）：" answer
  [[ -z "$answer" ]]
}

strip_outer_quotes() {
  local value="$1"
  value="${value%$'\r'}"
  value="${value%$'\n'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  print -r -- "$value"
}

python_bin() {
  print -r -- "${SUPERTONIC_VENV_DIR}/bin/python"
}

supertonic_bin() {
  print -r -- "${SUPERTONIC_VENV_DIR}/bin/supertonic"
}

require_command() {
  local cmd="$1"
  local tip="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error_echo "未找到命令：${cmd}"
    err_echo "$tip"
    return 1
  fi
  success_echo "已检测到 ${cmd}：$(command -v "$cmd")"
}

# ---------- 环境检查 ----------
install_or_repair_environment() {
  local py3=""
  py3="$(command -v python3 || true)"

  if [[ -z "$py3" ]]; then
    error_echo "未找到 python3，无法创建虚拟环境。"
    err_echo "请先安装 Python，例如：brew install python"
    return 1
  fi

  mkdir -p "$(dirname "$SUPERTONIC_VENV_DIR")"

  if [[ ! -d "$SUPERTONIC_VENV_DIR" ]]; then
    note_echo "开始创建虚拟环境：${SUPERTONIC_VENV_DIR}"
    "$py3" -m venv "$SUPERTONIC_VENV_DIR" >> "$LOG_FILE" 2>&1 || return 1
  fi

  local py="$(python_bin)"
  if [[ ! -x "$py" ]]; then
    error_echo "虚拟环境 Python 不可执行：${py}"
    return 1
  fi

  note_echo "开始安装 / 补齐 supertonic[serve] 依赖。"
  "$py" -m pip install --upgrade pip >> "$LOG_FILE" 2>&1 || return 1
  "$py" -m pip install 'supertonic[serve]' >> "$LOG_FILE" 2>&1 || return 1
  success_echo "Supertonic 依赖已安装 / 补齐。"
}

ensure_environment() {
  require_command "curl" "macOS 通常自带 curl，如果缺失请检查系统环境。" || return 1

  local py="$(python_bin)"
  local st="$(supertonic_bin)"

  if [[ ! -x "$py" || ! -x "$st" ]]; then
    warn_echo "未检测到可用的 Supertonic 虚拟环境：${SUPERTONIC_VENV_DIR}"
    gray_echo "当前脚本默认读取：~/Desktop/supertonic-venv"
    gray_echo "如果虚拟环境不在默认位置，可以这样指定："
    gray_echo "SUPERTONIC_VENV_DIR=/你的/venv/路径 ${SCRIPT_PATH}"
    echo ""
    if ask_enter_to_run "是否自动创建 / 修复虚拟环境并安装 supertonic[serve]"; then
      install_or_repair_environment || {
        error_echo "环境创建 / 修复失败。日志：${LOG_FILE}"
        return 1
      }
    else
      error_echo "已跳过安装，无法继续朗读。"
      return 1
    fi
  fi

  "$py" - <<'PY' >/dev/null 2>&1
import supertonic
PY
  if [[ $? -ne 0 ]]; then
    warn_echo "虚拟环境存在，但无法 import supertonic。"
    if ask_enter_to_run "是否自动重新安装 / 补齐 supertonic[serve]"; then
      install_or_repair_environment || return 1
    else
      error_echo "已跳过修复，无法继续朗读。"
      return 1
    fi
  fi

  success_echo "Supertonic 虚拟环境可用：${SUPERTONIC_VENV_DIR}"
}

# ---------- 服务管理 ----------
is_server_alive() {
  curl -fsS "${SERVER_URL}/docs" >/dev/null 2>&1
}

start_server_if_needed() {
  if is_server_alive; then
    success_echo "本地 Supertonic 服务已可用：${SERVER_URL}"
    return 0
  fi

  local st="$(supertonic_bin)"
  if [[ ! -x "$st" ]]; then
    error_echo "未找到 supertonic 可执行文件：${st}"
    return 1
  fi

  note_echo "正在后台启动 Supertonic 服务：${SERVER_URL}"
  gray_echo "首次运行可能会下载模型，服务日志：${SERVER_LOG}"
  : > "$SERVER_LOG"

  nohup "$st" serve --host "$SUPERTONIC_HOST" --port "$SUPERTONIC_PORT" >> "$SERVER_LOG" 2>&1 &
  local pid="$!"
  print -r -- "$pid" > "$SERVER_PID_FILE"

  local i=0
  while (( i < 420 )); do
    if is_server_alive; then
      success_echo "Supertonic 服务启动成功：${SERVER_URL}"
      return 0
    fi
    sleep 1
    (( i++ ))
  done

  error_echo "Supertonic 服务启动超时。"
  if command -v lsof >/dev/null 2>&1; then
    gray_echo "端口占用情况："
    lsof -nP -iTCP:"$SUPERTONIC_PORT" -sTCP:LISTEN 2>/dev/null | tee -a "$LOG_FILE" || true
  fi
  gray_echo "最近服务日志："
  tail -n 80 "$SERVER_LOG" 2>/dev/null | tee -a "$LOG_FILE"
  return 1
}

stop_started_server() {
  if [[ ! -f "$SERVER_PID_FILE" ]]; then
    warn_echo "未找到本脚本记录的服务 PID：${SERVER_PID_FILE}"
    return 0
  fi

  local pid="$(cat "$SERVER_PID_FILE" 2>/dev/null)"
  if [[ -z "$pid" ]]; then
    warn_echo "服务 PID 为空。"
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    rm -f "$SERVER_PID_FILE"
    success_echo "已停止本脚本启动的 Supertonic 服务：PID ${pid}"
  else
    rm -f "$SERVER_PID_FILE"
    warn_echo "记录的服务进程已不存在：PID ${pid}"
  fi
}

# ---------- 中文 fallback ----------
contains_chinese() {
  local text="$1"
  local py="$(python_bin)"
  "$py" - "$text" <<'PY'
import re
import sys
print("yes" if re.search(r"[\u4e00-\u9fff]", sys.argv[1]) else "no")
PY
}

list_macos_chinese_voices() {
  if ! command -v say >/dev/null 2>&1; then
    error_echo "当前系统未找到 macOS say 命令。"
    return 1
  fi
  note_echo "本机可疑中文语音如下；如果为空，请去系统设置里下载中文朗读声音。"
  say -v '?' 2>/dev/null | grep -Ei 'zh_|chinese|mandarin|cantonese|tingting|mei-?jia|sin-?ji|yu-?shu|li-?mu' | tee -a "$LOG_FILE" || true
}

pick_macos_chinese_voice() {
  if [[ -n "$SUPERTONIC_ZH_VOICE" ]]; then
    print -r -- "$SUPERTONIC_ZH_VOICE"
    return 0
  fi

  local voices
  voices="$(say -v '?' 2>/dev/null || true)"

  local preferred
  for preferred in Tingting Mei-Jia Meijia Sin-ji Sinji Yu-shu Yushu Li-mu Limu; do
    if print -r -- "$voices" | awk '{print $1}' | grep -Fxq "$preferred"; then
      print -r -- "$preferred"
      return 0
    fi
  done

  local detected
  detected="$(print -r -- "$voices" | awk 'BEGIN{IGNORECASE=1} /zh_|Chinese|Mandarin|Cantonese/ {print $1; exit}')"
  if [[ -n "$detected" ]]; then
    print -r -- "$detected"
    return 0
  fi

  return 1
}

speak_chinese_with_macos_say() {
  local raw_text="$1"
  local text="$(strip_outer_quotes "$raw_text")"

  if ! command -v say >/dev/null 2>&1; then
    error_echo "未找到 macOS say 命令，无法使用中文 fallback。"
    return 1
  fi

  local timestamp="$(date '+%Y%m%d_%H%M%S')"
  mkdir -p "$SUPERTONIC_OUTPUT_DIR"
  local output_file="${SUPERTONIC_OUTPUT_DIR}/macos_say_zh_${timestamp}.aiff"

  local voice=""
  voice="$(pick_macos_chinese_voice || true)"

  if [[ -n "$voice" ]]; then
    note_echo "检测到中文：使用 macOS say 朗读，voice=${voice} rate=${SUPERTONIC_ZH_RATE}"
    say -v "$voice" -r "$SUPERTONIC_ZH_RATE" -o "$output_file" "$text" >> "$LOG_FILE" 2>&1
  else
    warn_echo "未找到明确中文语音，使用 macOS 默认语音尝试朗读。"
    warn_echo "建议下载中文语音后执行 :zh-voices / :zh-voice。"
    say -r "$SUPERTONIC_ZH_RATE" -o "$output_file" "$text" >> "$LOG_FILE" 2>&1
  fi

  if [[ $? -ne 0 || ! -s "$output_file" ]]; then
    error_echo "macOS say 生成中文音频失败：${output_file}"
    return 1
  fi

  success_echo "中文语音已生成：${output_file}"

  if command -v afplay >/dev/null 2>&1; then
    afplay "$output_file"
  else
    open "$output_file"
  fi
}

# ---------- 语音生成 ----------
detect_lang() {
  local text="$1"
  local py="$(python_bin)"
  "$py" - "$text" <<'PY'
import re
import sys

text = sys.argv[1]
if re.search(r"[\u3040-\u30ff]", text):
    print("ja")
elif re.search(r"[\uac00-\ud7af]", text):
    print("ko")
elif re.search(r"[\u4e00-\u9fff]", text):
    print("na")
else:
    print("en")
PY
}

build_payload() {
  local text="$1"
  local lang="$2"
  local py="$(python_bin)"
  "$py" - "$text" "$SUPERTONIC_VOICE" "$lang" "$SUPERTONIC_STEPS" "$SUPERTONIC_SPEED" <<'PY'
import json
import sys

text, voice, lang, steps, speed = sys.argv[1:6]
payload = {
    "text": text,
    "voice": voice,
    "lang": lang,
    "steps": int(steps),
    "speed": float(speed),
    "response_format": "wav",
}
print(json.dumps(payload, ensure_ascii=False))
PY
}

speak_text() {
  local raw_text="$1"
  local text="$(strip_outer_quotes "$raw_text")"

  if [[ -z "$text" ]]; then
    warn_echo "空文本，已跳过。"
    return 0
  fi

  local has_chinese="$(contains_chinese "$text")"
  if [[ "$has_chinese" == "yes" && "$SUPERTONIC_ZH_ENGINE" == "say" ]]; then
    speak_chinese_with_macos_say "$text"
    return $?
  fi

  local lang="$SUPERTONIC_LANG"
  if [[ "$lang" == "auto" ]]; then
    lang="$(detect_lang "$text")"
  fi

  local timestamp="$(date '+%Y%m%d_%H%M%S')"
  mkdir -p "$SUPERTONIC_OUTPUT_DIR"
  local output_file="${SUPERTONIC_OUTPUT_DIR}/supertonic_${timestamp}.wav"
  local payload="$(build_payload "$text" "$lang")"

  note_echo "正在生成语音：voice=${SUPERTONIC_VOICE} lang=${lang} steps=${SUPERTONIC_STEPS} speed=${SUPERTONIC_SPEED}"

  curl -fsS -X POST "${SERVER_URL}/v1/tts" \
    -H 'content-type: application/json' \
    -d "$payload" \
    -o "$output_file" >> "$LOG_FILE" 2>&1

  if [[ $? -ne 0 || ! -s "$output_file" ]]; then
    error_echo "语音生成失败：${output_file}"
    gray_echo "最近服务日志："
    tail -n 80 "$SERVER_LOG" 2>/dev/null | tee -a "$LOG_FILE"
    return 1
  fi

  success_echo "语音已生成：${output_file}"

  if command -v afplay >/dev/null 2>&1; then
    afplay "$output_file"
  else
    open "$output_file"
  fi
}

# ---------- 菜单与交互 ----------
show_supported_languages() {
  cat <<'EOF' | tee -a "$LOG_FILE"
支持语言代码：
  en 英语    ko 韩语    ja 日语    ar 阿拉伯语
  bg 保加利亚语 cs 捷克语 da 丹麦语 de 德语
  el 希腊语  es 西班牙语 et 爱沙尼亚语 fi 芬兰语
  fr 法语    hi 印地语 hr 克罗地亚语 hu 匈牙利语
  id 印尼语  it 意大利语 lt 立陶宛语 lv 拉脱维亚语
  nl 荷兰语  pl 波兰语 pt 葡萄牙语 ro 罗马尼亚语
  ru 俄语    sk 斯洛伐克语 sl 斯洛文尼亚语 sv 瑞典语
  tr 土耳其语 uk 乌克兰语 vi 越南语
  na 未知 / fallback

注意：官方公开语言列表没有 zh / 中文。中文建议用 auto 或 na，但效果不保证。
EOF
}

show_runtime_config() {
  echo ""
  highlight_echo "============================== 当前配置 =============================="
  gray_echo "虚拟环境：${SUPERTONIC_VENV_DIR}"
  gray_echo "服务地址：${SERVER_URL}"
  gray_echo "声音角色：${SUPERTONIC_VOICE}"
  gray_echo "语言模式：${SUPERTONIC_LANG}"
  gray_echo "推理步数：${SUPERTONIC_STEPS}"
  gray_echo "语速倍数：${SUPERTONIC_SPEED}"
  gray_echo "输出目录：${SUPERTONIC_OUTPUT_DIR}"
  gray_echo "中文引擎：${SUPERTONIC_ZH_ENGINE}"
  gray_echo "中文语音：${SUPERTONIC_ZH_VOICE:-自动选择}"
  gray_echo "中文语速：${SUPERTONIC_ZH_RATE}"
  gray_echo "主日志：${LOG_FILE}"
  gray_echo "服务日志：${SERVER_LOG}"
  highlight_echo "======================================================================="
  echo ""
}

show_help() {
  cat <<'EOF' | tee -a "$LOG_FILE"
可用命令：
  直接输入文本        立即朗读，例如：fuck
  :lang en           切换语言，例如 en / ja / ko / es / na / auto
  :voice F1          切换声音，内置 M1-M5、F1-F5
  :speed 1.2         切换语速，建议 0.7-2.0
  :steps 10          切换质量步数，建议 5-12，越大越慢
  :list              查看官方支持的语言代码
  :docs              打开本地接口文档
  :config            查看当前配置
  :stop              停止本脚本启动的后台服务
  :quit              退出
EOF
}

interactive_loop() {
  show_runtime_config
  show_help
  echo ""

  while true; do
    local input=""
    read -r "?🔊 请输入要朗读的文本（直接回车退出）： " input
    input="$(strip_outer_quotes "$input")"

    if [[ -z "$input" ]]; then
      success_echo "已退出朗读循环。"
      break
    fi

    case "$input" in
      ":quit"|":q"|":exit")
        success_echo "已退出朗读循环。"
        break
        ;;
      ":help")
        show_help
        ;;
      ":list")
        show_supported_languages
        ;;
      ":docs")
        open "${SERVER_URL}/docs"
        ;;
      ":config")
        show_runtime_config
        ;;
      ":stop")
        stop_started_server
        ;;
      ":lang "*)
        SUPERTONIC_LANG="${input#":lang "}"
        success_echo "语言已切换为：${SUPERTONIC_LANG}"
        ;;
      ":zh-engine "*)
        SUPERTONIC_ZH_ENGINE="${input#":zh-engine "}"
        success_echo "中文引擎已切换为：${SUPERTONIC_ZH_ENGINE}"
        ;;
      ":zh-voices")
        list_macos_chinese_voices
        ;;
      ":zh-voice "*)
        SUPERTONIC_ZH_VOICE="${input#":zh-voice "}"
        success_echo "中文语音已切换为：${SUPERTONIC_ZH_VOICE}"
        ;;
      ":zh-rate "*)
        SUPERTONIC_ZH_RATE="${input#":zh-rate "}"
        success_echo "中文语速已切换为：${SUPERTONIC_ZH_RATE}"
        ;;
      ":voice "*)
        SUPERTONIC_VOICE="${input#":voice "}"
        success_echo "声音已切换为：${SUPERTONIC_VOICE}"
        ;;
      ":speed "*)
        SUPERTONIC_SPEED="${input#":speed "}"
        success_echo "语速已切换为：${SUPERTONIC_SPEED}"
        ;;
      ":steps "*)
        SUPERTONIC_STEPS="${input#":steps "}"
        success_echo "步数已切换为：${SUPERTONIC_STEPS}"
        ;;
      *)
        speak_text "$input"
        ;;
    esac
    echo ""
  done
}

main() {
  if [[ "$#" -gt 0 ]]; then
    ensure_environment || exit 1
    start_server_if_needed || exit 1
    speak_text "$*"
    return $?
  fi

  show_readme_and_wait
  ensure_environment || exit 1
  start_server_if_needed || exit 1
  interactive_loop
}

main "$@"
