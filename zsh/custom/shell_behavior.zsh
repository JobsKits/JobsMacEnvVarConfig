# 交互式终端默认行为
# 单独拆出来，后面你想关掉某个行为，只改这个文件即可

# 打开终端默认进入桌面
if [[ -o interactive ]] && [[ -d "$HOME/Desktop" ]]; then
  cd "$HOME/Desktop"
fi

# clean
# 终端清理函数：
# - 清空当前 zsh 会话里的历史记录
# - 清空 HISTFILE 对应的历史文件
# - 顺带清空 macOS zsh_sessions 里残留的会话历史文件
# - 清空当前终端屏幕和滚动缓冲区
#
# 用法：
#   clean
#
# 注意：
# - 这个函数会真正清空历史文件，不做二次确认。
# - 执行后，本次 clean 之前的历史不会再通过方向键 / history 命令找回。
# - 后续新输入的命令会继续正常写入历史。
unalias clean 2>/dev/null
clean() {
  emulate -L zsh
  setopt no_nomatch null_glob

  local old_histfile="${HISTFILE:-}"
  local hist_file="${old_histfile:-$HOME/.zsh_history}"
  local old_histsize="${HISTSIZE:-10000}"
  local old_savehist="${SAVEHIST:-$old_histsize}"
  local file
  local history_files=(
    "$hist_file"
    "$HOME/.zsh_history"
    "$HOME/.zsh_sessions"/*.history(N)
    "$HOME/.zsh_sessions"/*.historynew(N)
  )

  # 先把内存历史缩到 0，再写出到 HISTFILE，避免旧历史在退出 shell 时被重新落盘。
  HISTSIZE=0
  SAVEHIST=0
  builtin fc -W "$hist_file" 2>/dev/null || true

  # 再显式清空常见历史文件。重复路径无害。
  for file in "${history_files[@]}"; do
    [[ -n "$file" ]] || continue
    [[ -e "$file" || -L "$file" ]] || continue
    : >| "$file" 2>/dev/null || true
  done

  # 恢复历史配置，让 clean 之后的新命令继续正常记录。
  HISTSIZE="$old_histsize"
  SAVEHIST="$old_savehist"
  if [[ -n "$old_histfile" ]]; then
    HISTFILE="$old_histfile"
  else
    unset HISTFILE
  fi

  # 模拟 macOS 终端 Command + K 的清屏体验：不调用 clear，而是清空可视区域 + scrollback。
  # CSI 2J 清当前可视区域，CSI 3J 清滚动缓冲区，CSI H 把光标放回左上角。
  # OSC 1337 是 iTerm2 的 ClearScrollback 扩展；其他终端不支持时会忽略。
  printf '\033[H\033[2J\033[3J'
  printf '\033]1337;ClearScrollback\007'
  printf '\033[H'
}

