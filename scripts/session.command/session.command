#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

save() {
  local files=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
  )
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      source "$file"
      echo -e "\033[1;32m✅ 已加载配置文件：file://$file\033[0m"
    else
      echo -e "\033[1;33m⚠️ 未找到配置文件：file://$file\033[0m"
    fi
  done
  echo -e "\n📎 ⌘Command + 点击路径可打开对应文件（macOS Terminal 支持）"
}

rb() { exec -l "$SHELL"; }
a()  { open "$HOME/.bash_profile"; }
b()  { open "$HOME/.zshrc"; }
i()  { open -a Simulator; }
