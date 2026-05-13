#!/bin/zsh
# JobsMacEnv executable command wrappers.
# 注册终端短命令；真实逻辑放在 Scripts/<脚本全名>/<脚本全名>。

_jobs_resolve_scripts_command() {
  emulate -L zsh

  local command_name="$1"
  local env_home="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"
  local scripts_dir="$env_home/Scripts"
  local script_file="${command_name}.command"
  local candidates=(
    "$scripts_dir/$script_file/$script_file"
    "$scripts_dir/$script_file"
  )

  local candidate=""
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

_jobs_run_scripts_command() {
  emulate -L zsh

  local command_name="$1"
  shift

  local script=""
  if ! script="$(_jobs_resolve_scripts_command "$command_name")"; then
    echo "$command_name: 主脚本不存在或不可执行" >&2
    echo "👉 请重新执行 JobsMacEnv 安装脚本" >&2
    return 127
  fi

  "$script" "$@"
}

# trs：macOS 原生翻译入口。
trs() { _jobs_run_scripts_command trs "$@"; }

# gif：终端 / 全屏录制并导出 GIF / MP4。
gif() { _jobs_run_scripts_command gif "$@"; }

# jdk17：检测并安装 JDK 17。
jdk17() { _jobs_run_scripts_command install_jdk17 "$@"; }

# simios：检测完整 Xcode 环境并下载 / 补齐 iOS Simulator Runtime。
simios() { _jobs_run_scripts_command simios "$@"; }

# list：打开 JobsMacEnv 功能菜单。
list() { _jobs_run_scripts_command list "$@"; }

# m5c：比较两个文件的 MD5，判断文件字节内容是否一致。
m5c() { _jobs_run_scripts_command m5c "$@"; }

# flat：URL 编码去乱码 / 解码，并自动复制到剪贴板。
flat() { _jobs_run_scripts_command '【MacOS】去乱码' "$@"; }
