# JobsMacEnv 启动层
# 这里放最基础、最稳定、适合全局执行的初始化逻辑

# 仅交互式 shell 处理 UI / cd / 提示等动作
[[ -o interactive ]] || return 0

# Oh My Zsh（存在才启用）
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
  : "${ZSH_THEME:=robbyrussell}"
  typeset -ga plugins
  if (( ${plugins[(Ie)git]} == 0 )); then
    plugins+=(git)
  fi
  source "$ZSH/oh-my-zsh.sh"
fi

# Homebrew shellenv（Apple Silicon / Intel 自动兼容）
jobs_bootstrap_brew() {
  local brew_bin=""

  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin="/usr/local/bin/brew"
  elif command -v brew >/dev/null 2>&1; then
    brew_bin="$(command -v brew)"
  fi

  [[ -n "$brew_bin" ]] || return 0
  eval "$($brew_bin shellenv)"
}

jobs_bootstrap_brew
