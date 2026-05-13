# JobsMacEnv session private library. Do not call directly.
jobs_session_save_impl() {
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

jobs_session_rb_impl() { exec -l "$SHELL"; }
jobs_session_a_impl() { open "$HOME/.bash_profile"; }
jobs_session_b_impl() { open "$HOME/.zshrc"; }
jobs_session_i_impl() { open -a Simulator; }
