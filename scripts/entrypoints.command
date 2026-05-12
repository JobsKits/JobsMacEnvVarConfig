#!/bin/zsh
# JobsMacEnv executable command wrappers.
# 这里定义终端入口函数；真正执行逻辑放在 Scripts/*.command 可执行脚本里。

_jobs_run_scripts_command() {
  emulate -L zsh

  local command_name="$1"
  shift

  local env_home="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"
  local script="$env_home/Scripts/${command_name}.command"

  if [[ ! -x "$script" ]]; then
    echo "$command_name: 主脚本不存在或不可执行：$script" >&2
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
