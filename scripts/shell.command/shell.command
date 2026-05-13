#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# 🔥 Shell 切换器：shell 🔥
# 运行时扫描当前机器可用 shell，用 fzf 列成「目前可用的终端 / Shell」列表，再切换默认登录 shell。
jobs_shell_current_login_shell() {
  emulate -L zsh

  local current="${SHELL:-}"
  if command -v dscl >/dev/null 2>&1; then
    local dscl_shell
    dscl_shell="$(dscl . -read "$HOME" UserShell 2>/dev/null | awk '{print $2}')"
    [[ -n "$dscl_shell" ]] && current="$dscl_shell"
  fi
  print -r -- "$current"
}

jobs_shell_label_for_path() {
  emulate -L zsh

  local path="$1"
  local name="${path:t}"
  case "$name" in
    zsh) print -r -- "zsh" ;;
    bash) print -r -- "bash" ;;
    sh) print -r -- "sh" ;;
    fish) print -r -- "fish" ;;
    nu) print -r -- "nu / Nushell" ;;
    pwsh) print -r -- "pwsh / PowerShell" ;;
    tcsh) print -r -- "tcsh" ;;
    csh) print -r -- "csh" ;;
    ksh) print -r -- "ksh" ;;
    dash) print -r -- "dash" ;;
    elvish) print -r -- "elvish" ;;
    xonsh) print -r -- "xonsh" ;;
    *) print -r -- "$name" ;;
  esac
}

jobs_shell_add_candidate() {
  emulate -L zsh

  local path="$1"
  local label="${2:-}"
  local note="${3:-}"

  [[ -n "$path" ]] || return 0
  [[ "$path" == /* ]] || return 0
  [[ -x "$path" ]] || return 0

  if [[ -z "$label" ]]; then
    label="$(jobs_shell_label_for_path "$path")"
  fi

  print -r -- "${label}	${path}	${note}"
}

jobs_shell_scan_available() {
  emulate -L zsh
  setopt no_nomatch

  local -A seen
  local current
  current="$(jobs_shell_current_login_shell)"

  local line path label note name

  # 1) /etc/shells 是 macOS chsh 官方认可的来源。
  if [[ -r /etc/shells ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line//[[:space:]]/}"
      [[ -n "$line" && "$line" == /* ]] || continue
      [[ -x "$line" ]] || continue
      [[ -z "${seen[$line]:-}" ]] || continue
      seen[$line]=1

      label="$(jobs_shell_label_for_path "$line")"
      note="/etc/shells"
      [[ "$line" == "$current" ]] && note="当前默认 · /etc/shells"
      jobs_shell_add_candidate "$line" "$label" "$note"
    done < /etc/shells
  fi

  # 2) 再扫描 PATH 和 Homebrew 常见目录，补上 nu/fish/pwsh 等可能没有写进 /etc/shells 的 shell。
  local cmd resolved
  for cmd in zsh bash sh fish nu pwsh tcsh csh ksh dash elvish xonsh; do
    resolved="$(command -v "$cmd" 2>/dev/null || true)"
    [[ -n "$resolved" ]] || continue
    [[ "$resolved" == /* ]] || continue
    resolved="$(cd "${resolved:h}" 2>/dev/null && pwd -P)/${resolved:t}"
    [[ -z "${seen[$resolved]:-}" ]] || continue
    seen[$resolved]=1

    label="$(jobs_shell_label_for_path "$resolved")"
    note="PATH"
    grep -Fxq "$resolved" /etc/shells 2>/dev/null && note="/etc/shells"
    [[ "$resolved" == "$current" ]] && note="当前默认 · $note"
    jobs_shell_add_candidate "$resolved" "$label" "$note"
  done

  local dir candidate
  for dir in /opt/homebrew/bin /usr/local/bin /opt/local/bin /bin /usr/bin; do
    [[ -d "$dir" ]] || continue
    for name in zsh bash sh fish nu pwsh tcsh csh ksh dash elvish xonsh; do
      candidate="$dir/$name"
      [[ -x "$candidate" ]] || continue
      candidate="$(cd "${candidate:h}" 2>/dev/null && pwd -P)/${candidate:t}"
      [[ -z "${seen[$candidate]:-}" ]] || continue
      seen[$candidate]=1

      label="$(jobs_shell_label_for_path "$candidate")"
      note="扫描到"
      grep -Fxq "$candidate" /etc/shells 2>/dev/null && note="/etc/shells"
      [[ "$candidate" == "$current" ]] && note="当前默认 · $note"
      jobs_shell_add_candidate "$candidate" "$label" "$note"
    done
  done

  # 3) Oh My Zsh 不是独立 shell，本质仍是 zsh。这里单独列出来，方便你按名字选择。
  if [[ -d "$HOME/.oh-my-zsh" || -n "${ZSH:-}" ]]; then
    local zsh_path=""
    if command -v zsh >/dev/null 2>&1; then
      zsh_path="$(command -v zsh)"
    elif [[ -x /bin/zsh ]]; then
      zsh_path="/bin/zsh"
    fi

    if [[ -n "$zsh_path" && -x "$zsh_path" ]]; then
      local oh_note="Oh My Zsh 基于 zsh，不是独立登录 shell"
      [[ "$zsh_path" == "$current" ]] && oh_note="当前默认 · $oh_note"
      jobs_shell_add_candidate "$zsh_path" "ohmyzsh / zsh + Oh My Zsh" "$oh_note"
    fi
  fi
}

jobs_shell_ensure_in_etc_shells() {
  emulate -L zsh

  local target_shell="$1"

  if grep -Fxq "$target_shell" /etc/shells 2>/dev/null; then
    return 0
  fi

  print -P "%F{yellow}⚠️  $target_shell 不在 /etc/shells。macOS 的 chsh 通常会拒绝这种路径。%f"
  read -r "answer?是否用 sudo 把它追加到 /etc/shells？输入 y 确认："
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    print -P "%F{red}❌ 已取消，未修改默认 shell。%f"
    return 1
  fi

  print -r -- "$target_shell" | sudo tee -a /etc/shells >/dev/null || {
    print -P "%F{red}❌ 写入 /etc/shells 失败。%f"
    return 1
  }

  print -P "%F{green}✅ 已加入 /etc/shells：$target_shell%f"
}

shell() {
  emulate -L zsh

  if ! command -v fzf >/dev/null 2>&1; then
    print -P "%F{red}❌ 未检测到 fzf。先安装：brew install fzf%f"
    return 1
  fi

  local list selected label target_shell note
  list="$(jobs_shell_scan_available)"

  if [[ -z "$list" ]]; then
    print -P "%F{red}❌ 没有扫描到可用 shell。%f"
    return 1
  fi

  selected="$(print -r -- "$list" | fzf \
    --prompt='Shell ➜ ' \
    --header='目前可用的终端 / Shell：↑↓ 选择，Enter 切换，Esc 取消' \
    --delimiter=$'\t' \
    --with-nth=1,2,3 \
    --height=80% \
    --border)"

  if [[ -z "$selected" ]]; then
    print -P "%F{yellow}已取消 shell 切换。%f"
    return 0
  fi

  IFS=$'\t' read -r label target_shell note <<< "$selected"

  if [[ -z "$target_shell" || ! -x "$target_shell" ]]; then
    print -P "%F{red}❌ 无效 shell：$target_shell%f"
    return 1
  fi

  jobs_shell_ensure_in_etc_shells "$target_shell" || return 1

  print -P "%F{cyan}🔧 正在切换默认 shell：$label -> $target_shell%f"
  chsh -s "$target_shell" || {
    print -P "%F{red}❌ chsh 执行失败。%f"
    return 1
  }

  print -P "%F{green}✅ 默认 shell 已更新。重新打开终端后生效。%f"
  if command -v dscl >/dev/null 2>&1; then
    dscl . -read "$HOME" UserShell 2>/dev/null || true
  fi
}
