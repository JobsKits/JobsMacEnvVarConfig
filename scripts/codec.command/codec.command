#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# 🔥 URL Decode REPL（decode -> 解码 + 自动 pbcopy）🔥
decode() {
  emulate -L zsh
  setopt no_aliases

  local input decoded

  # 统一提示
  print -P "%F{cyan}🔤 decode%f：粘贴要转的字符串/URL（支持 %E8%B6%85...）"
  print -P "%F{cyan}        回车=解码并复制到剪切板；q/quit/exit=退出%f"

  while true; do
    # -r：不转义反斜杠；?prompt：zsh 的提示符
    read -r "?👉 输入： " input || break

    # 退出指令
    case "$input" in
      q|Q|quit|QUIT|exit|EXIT)
        print -P "%F{green}✅ 已退出 decode%f"
        return 0
        ;;
    esac

    # 空输入：继续下一轮
    if [[ -z "$input" ]]; then
      print -P "%F{yellow}⚠️  请输入内容（或 q 退出）%f"
      continue
    fi

    # 用 python3 解码（macOS 基本都有；比 perl 更稳）
    decoded="$(python3 - <<'PY' "$input" 2>/dev/null
import sys, urllib.parse
print(urllib.parse.unquote(sys.argv[1]))
PY
)" || decoded=""

    if [[ -z "$decoded" ]]; then
      print -P "%F{red}❌ 解码失败：请确认你粘贴的是一整串内容%f"
      continue
    fi

    # 显示 + 复制
    print -P "%F{green}✅ 解码结果：%f$decoded"
    print -r -- "$decoded" | pbcopy
    print -P "%F{magenta}📋 已复制到剪切板%f"
  done
}

