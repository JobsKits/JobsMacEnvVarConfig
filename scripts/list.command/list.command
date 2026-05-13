#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
ENV_HOME="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"

if [[ -d "${SCRIPT_DIR}/../m5c.command" || -d "${SCRIPT_DIR}/../flat.command" ]]; then
  SCRIPTS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  SCRIPTS_ROOT="${ENV_HOME}/Scripts"
fi

FZF_BIN=""
MODULES_LOADED="false"
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
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }

ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }
get_cpu_arch() { uname -m; }

find_brew_bin() {
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

profile_file_for_shell() {
  case "${SHELL##*/}" in
    zsh)  print -r -- "$HOME/.zprofile" ;;
    bash) print -r -- "$HOME/.bash_profile" ;;
    *)    print -r -- "$HOME/.profile" ;;
  esac
}

inject_shellenv_block() {
  local profile_file="$1"
  local shellenv="$2"
  local id="homebrew_env"
  local header="# >>> ${id} 环境变量 >>>"
  local footer="# <<< ${id} 环境变量 <<<"

  ensure_dir "$(dirname "$profile_file")"
  touch "$profile_file"

  if ! grep -Fq "$header" "$profile_file" && ! grep -Fq "$shellenv" "$profile_file"; then
    {
      echo ""
      echo "$header"
      echo "$shellenv"
      echo "$footer"
    } >> "$profile_file"
  fi

  eval "$shellenv"
}

prompt_enter_skip_any_run() {
  local title="$1"
  local detail="$2"
  local answer=""

  log ""
  info_echo "$title"
  log "👉 直接按 [Enter]：跳过"
  log "👉 输入任意字符后回车：$detail"
  IFS= read -r answer

  [[ -n "$answer" ]]
}

resolve_script_file() {
  local script_name="$1"
  local nested_file="$SCRIPTS_ROOT/$script_name/$script_name"
  local flat_file="$SCRIPTS_ROOT/$script_name"

  if [[ -x "$nested_file" ]]; then
    print -r -- "$nested_file"
    return 0
  fi

  if [[ -x "$flat_file" ]]; then
    print -r -- "$flat_file"
    return 0
  fi

  return 1
}

resolve_module_file() {
  local module_name="$1"
  local nested_file="$SCRIPTS_ROOT/$module_name/$module_name"
  local flat_file="$SCRIPTS_ROOT/$module_name"

  if [[ -f "$nested_file" ]]; then
    print -r -- "$nested_file"
    return 0
  fi

  if [[ -f "$flat_file" ]]; then
    print -r -- "$flat_file"
    return 0
  fi

  return 1
}

ensure_homebrew() {
  local arch="$(get_cpu_arch)"
  local profile_file="$(profile_file_for_shell)"
  local brew_bin=""
  local shellenv_cmd=""

  if brew_bin="$(find_brew_bin 2>/dev/null)"; then
    shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""
    inject_shellenv_block "$profile_file" "$shellenv_cmd"
    return 0
  fi

  warn_echo "未检测到 Homebrew，fzf 需要通过 Homebrew 安装。"
  if ! prompt_enter_skip_any_run "是否安装 Homebrew？" "安装 Homebrew 并注入 shellenv"; then
    error_echo "已跳过 Homebrew 安装，无法继续启动 fzf 菜单。"
    return 1
  fi

  if [[ "$arch" == "arm64" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    brew_bin="/opt/homebrew/bin/brew"
  else
    arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    brew_bin="/usr/local/bin/brew"
  fi

  shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""
  inject_shellenv_block "$profile_file" "$shellenv_cmd"
}

find_fzf_bin() {
  if command -v fzf >/dev/null 2>&1; then
    command -v fzf
    return 0
  fi

  local brew_prefix=""
  brew_prefix="$(brew --prefix 2>/dev/null)" || return 1

  if [[ -x "$brew_prefix/bin/fzf" ]]; then
    print -r -- "$brew_prefix/bin/fzf"
    return 0
  fi

  return 1
}

is_fzf_installed_by_brew() {
  brew list --formula fzf >/dev/null 2>&1
}

ensure_fzf() {
  local fzf_bin=""

  if ! is_fzf_installed_by_brew; then
    warn_echo "未检测到 Homebrew 安装的 fzf。"
    if ! prompt_enter_skip_any_run "是否安装 fzf？" "执行 brew install fzf"; then
      error_echo "已跳过 fzf 安装，改用文本清单。"
      return 1
    fi

    brew install fzf || return 1
  fi

  if ! fzf_bin="$(find_fzf_bin)"; then
    warn_echo "已检测到 brew formula fzf，但当前 PATH 找不到 fzf，改用文本清单。"
    return 1
  fi

  FZF_BIN="$fzf_bin"
}


# ---------- JobsMacEnv 函数模块加载 ----------
load_function_modules() {
  [[ "$MODULES_LOADED" == "true" ]] && return 0

  local module_name=""
  local module_file=""
  local modules=(
    flutter_project.command
  )

  local previous_source_mode="${JOBS_MAC_ENV_SOURCE_MODE:-}"
  JOBS_MAC_ENV_SOURCE_MODE="1"

  for module_name in "${modules[@]}"; do
    if module_file="$(resolve_module_file "$module_name" 2>/dev/null)"; then
      source "$module_file" || warn_echo "模块加载失败：$module_name"
    fi
  done

  if [[ -n "$previous_source_mode" ]]; then
    JOBS_MAC_ENV_SOURCE_MODE="$previous_source_mode"
  else
    unset JOBS_MAC_ENV_SOURCE_MODE
  fi

  MODULES_LOADED="true"
}

build_menu_items() {
  cat <<'MENU'
文件校验	m5c	比较两个文件 MD5，判断字节内容是否一致	script	m5c.command
去乱码	flat	URL 百分号编码解码，并复制结果到剪贴板	script	flat.command
翻译	trs	macOS 原生翻译入口	script	trs.command
录制 / GIF	gif	终端 / 全屏录制并导出 GIF / MP4	script	gif.command
iOS 模拟器	simios	检测 Xcode 环境并下载 / 补齐 iOS Simulator Runtime	script	simios.command
终端清理	clean	清空终端历史、zsh_sessions，并执行 brew cleanup	script	clean.command
颜色转换	cor	颜色格式转换器，支持 HEX / RGB / RGBA / 0xAARRGGBB	script	cor.command
URL 解码	decode	交互式 URL Decode，并自动复制到剪贴板	script	decode.command
时间戳	ts	Unix 时间戳转换，支持秒 / 毫秒 / 微秒 / 纳秒	script	ts.command
媒体下载	download	调用 yt-dlp，自动使用默认浏览器 cookies 下载媒体	script	download.command
环境安装	install	新系统开发环境配置 / 依赖安装入口	script	install.command
环境更新	update	JobsMacEnv 更新菜单，批量更新开发工具链	script	update.command
Shell 切换	shell	扫描并切换可用 shell	script	shell.command
跳转路径	zz	解析 Finder 替身 / 软链接 / 文件路径并 cd 到真实目录	script	zz.command
执行文件	x	给拖入的脚本 chmod +x 并执行	script	x.command
重载配置	save	重新加载 bash / zsh 常见配置文件	script	save.command
重启 Shell	rb	重启当前登录 shell	script	rb.command
打开 bash 配置	a	打开 ~/.bash_profile	script	a.command
打开 zsh 配置	b	打开 ~/.zshrc	script	b.command
打开模拟器	i	打开 iOS Simulator	script	i.command
Flutter	flutter_project.command	优先使用项目 FVM Flutter，否则回退系统 flutter	function	flutter
修复 FVM	fixfvm	修复 / 检查 Flutter FVM 环境	script	fixfvm.command
Flutter 检查	check1	执行 Flutter 项目基础检查	script	check1.command
Flutter Doctor	check	执行项目相关检查 / flutter doctor	script	check.command
项目清理	c	Flutter 项目 clean / 依赖刷新	script	c.command
打开项目	d	打开当前配置的 Flutter 项目目录	script	d.command
构建检查	buildCheck	Flutter 构建前检查	script	buildCheck.command
构建 APK	apk	构建 Android APK	script	apk.command
构建 IPA	ipa	构建 iOS IPA	script	ipa.command
项目配置	config	打印 / 打开当前 Flutter 项目配置	script	config.command
退出菜单	quit	关闭 JobsMacEnv 功能菜单	builtin	quit
MENU
}

display_width() {
  local text="$1"
  local bytes="0"
  local chars="0"

  bytes="$(printf "%s" "$text" | LC_ALL=C wc -c | tr -d ' ')"
  chars="$(printf "%s" "$text" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')"

  if [[ -z "$bytes" || -z "$chars" ]]; then
    print -r -- "${#text}"
    return 0
  fi

  print -r -- $(( chars + (bytes - chars) / 2 ))
}

pad_right_visual() {
  local text="$1"
  local target_width="$2"
  local width="0"
  local pad_count="0"

  width="$(display_width "$text")"
  pad_count=$(( target_width - width ))
  (( pad_count < 1 )) && pad_count=1

  printf "%s%*s" "$text" "$pad_count" ""
}

build_fzf_items() {
  local title=""
  local command_name=""
  local description=""
  local run_type=""
  local target_name=""
  local display_title_text=""
  local display_title=""
  local display_command=""
  local display_line=""

  build_menu_items | while IFS=$'\t' read -r title command_name description run_type target_name; do
    display_title_text="$title"
    [[ "$display_title_text" == "__NO_TITLE__" ]] && display_title_text=""

    display_title="$(pad_right_visual "$display_title_text" 12)"
    display_command="$(printf "%-24s" "$command_name")"
    display_line="${display_title}${display_command}${description}"

    printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$title" "$command_name" "$description" "$run_type" "$target_name" "$display_line"
  done
}

fzf_supports_info_command() {
  "$FZF_BIN" --help 2>/dev/null | grep -q -- '--info-command'
}

print_command_table() {
  bold_echo "JobsMacEnv 功能菜单"
  log ""
  printf "%-22s %s\n" "入口" "含义" | tee -a "$LOG_FILE"
  printf "%-22s %s\n" "----------------------" "------------------------------------------------------------" | tee -a "$LOG_FILE"

  build_menu_items | while IFS=$'\t' read -r title command_name description run_type target_name; do
    [[ "$command_name" == "quit" ]] && continue
    printf "%-22s %s\n" "$command_name" "$description" | tee -a "$LOG_FILE"
  done
}

run_script_feature() {
  local script_name="$1"
  local script_file=""

  if ! script_file="$(resolve_script_file "$script_name")"; then
    error_echo "未找到功能脚本：$script_name"
    error_echo "请重新执行 JobsMacEnv 安装脚本。"
    return 1
  fi

  note_echo "执行：$script_file"
  "$script_file"
}

run_function_feature() {
  local function_name="$1"

  load_function_modules

  if ! typeset -f "$function_name" >/dev/null 2>&1; then
    error_echo "未找到自定义命令函数：$function_name"
    error_echo "请重新执行 JobsMacEnv 安装脚本，或执行：source ~/.zshrc"
    return 1
  fi

  note_echo "执行自定义命令：$function_name"
  "$function_name"
}

run_feature() {
  local command_name="$1"
  local run_type="$2"
  local target_name="$3"

  case "$run_type" in
    script)
      run_script_feature "$target_name"
      ;;
    function)
      run_function_feature "$target_name"
      ;;
    builtin)
      info_echo "已退出菜单。"
      return 2
      ;;
    *)
      error_echo "未知菜单执行类型：$run_type / $command_name"
      return 1
      ;;
  esac
}

show_text_menu() {
  print_command_table
  log ""
  warn_echo "fzf 不可用，已仅展示自定义命令清单。"
  gray_echo "日志路径：$LOG_FILE"
}

show_menu() {
  local selected=""
  local command_name=""
  local run_type=""
  local target_name=""
  local menu_status=0
  local feature_status=0

  local fzf_args=(
    --delimiter=$'\t'
    --with-nth=6
    --nth=6
    --prompt='JobsMacEnv > '
    --height=80%
    --border
    --no-sort
    --layout=reverse
    --header=$'JobsMacEnv 功能入口：↑/↓ 选择，Enter 执行，Esc 退出。'
  )

  if fzf_supports_info_command; then
    fzf_args+=(--info-command='pos="${FZF_POS:-0}"; info="${FZF_INFO:-0}"; total="${info##*/}"; [ -n "$total" ] || total="0"; printf "%s/%s " "$pos" "$total"')
  fi

  while true; do
    selected="$(build_fzf_items | "$FZF_BIN" "${fzf_args[@]}")"
    menu_status=$?

    if (( menu_status != 0 )) || [[ -z "$selected" ]]; then
      info_echo "已取消菜单。"
      break
    fi

    local title=""
    local description=""
    IFS=$'\t' read -r title command_name description run_type target_name <<< "$selected"

    run_feature "$command_name" "$run_type" "$target_name"
    feature_status=$?
    (( feature_status == 2 )) && break

    log ""
    warm_echo "按回车返回菜单；按 Ctrl+C 退出。"
    local _answer=""
    IFS= read -r _answer
  done
}

main() {
  if [[ "${1:-}" == "--plain" || "${1:-}" == "-p" ]]; then
    print_command_table
    gray_echo "日志路径：$LOG_FILE"
    return 0
  fi

  ensure_homebrew || {
    show_text_menu
    return 0
  }

  ensure_fzf || {
    show_text_menu
    return 0
  }

  show_menu
  gray_echo "日志路径：$LOG_FILE"
}

main "$@"
