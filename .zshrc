# 🔥 仅交互式 shell 才执行（避免跑脚本时也乱 cd）🔥
if [[ -o interactive ]]; then
  if [[ -d "$HOME/Desktop" ]]; then
    cd "$HOME/Desktop"
  fi
fi

# 🔥 Oh My Zsh 基本设置 🔥
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# 🔥 Homebrew（芯片自检 + 路径兜底；不装则安静跳过）🔥
init_homebrew() {
  local arch brew_bin

  arch="$(uname -m)"

  # 先按芯片给默认路径（更符合直觉）
  if [[ "$arch" == "arm64" ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  else
    brew_bin="/usr/local/bin/brew"
  fi

  # 再做事实兜底：如果默认不存在，就在常见路径里找
  if [[ ! -x "$brew_bin" ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      brew_bin="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
      brew_bin="/usr/local/bin/brew"
    else
      return 0
    fi
  fi

  eval "$("$brew_bin" shellenv)"
}
init_homebrew

# ================================== CONFIG（硬编码绝对路径：你只改这里）==================================
# ✅ 直接写死绝对路径：复制粘贴后只改这一行就行
JOBS_FLUTTER_PROJECT_DIR="/Users/jobs/Documents/Github/flutter_tiyu_app"

# （可选）dart completion 路径也别写死 /Users/mac 了
JOBS_DART_CLI_COMPLETION_FILE="/Users/jobs/.dart-cli-completion/zsh-config.zsh"

# ================================== 通用：项目目录自检与解析 ==================================
# 用法：
#   _get_project_dir                 -> 用默认 JOBS_FLUTTER_PROJECT_DIR
#   _get_project_dir "/abs/path"     -> 用你传入的绝对路径（会自检）
_get_project_dir() {
  local dir="${1:-$JOBS_FLUTTER_PROJECT_DIR}"

  # 允许你传 "~" 这种写法（虽然你说要绝对路径，但顺手兼容）
  eval "dir=\"$dir\""

  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "❌ 项目目录不存在：$dir" >&2
    echo "👉 请修改 JOBS_FLUTTER_PROJECT_DIR 为真实绝对路径" >&2
    return 1
  fi

  # Flutter 项目轻自检（不强制失败，主要是提示你配错目录）
  if [[ ! -f "$dir/pubspec.yaml" || ! -d "$dir/lib" ]]; then
    echo "⚠️  目录存在，但不像 Flutter 项目（缺少 pubspec.yaml 或 lib/）：$dir" >&2
  fi

  printf "%s\n" "$dir"
}

# ================================== Homebrew 第三方更新（formula/cask/tap） ==================================
brew_update_third_party() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "⚠️  [brew] not installed, skip update"
    return 0
  fi

  echo "➤ 🍺 brew update"
  brew update || echo "⚠️  brew update failed (ignored)"

  echo "➤ 📌 brew tap (refresh)"
  brew tap --repair >/dev/null 2>&1 || true

  echo "➤ ⬆️  brew upgrade (formula + cask)"
  brew upgrade || echo "⚠️  brew upgrade failed (ignored)"
  brew upgrade --cask || echo "⚠️  brew upgrade --cask failed (ignored)"

  echo "➤ 🧹 brew cleanup"
  brew cleanup || echo "⚠️  brew cleanup failed (ignored)"

  echo "➤ 🩺 brew doctor (optional)"
  brew doctor || echo "⚠️  brew doctor warnings (ignored)"

  echo "✅ brew third-party update done"
}

# 🔥 通用：try_run 🔥
try_run() {
  local cmd="$1"; shift
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ [$cmd] detected, running: $*"
    eval "$@"
  else
    echo "⚠️  [$cmd] not installed, skip: $*"
  fi
}

# 🔥 save（手动用，不再自启动）🔥
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

# 🔥 flutter() 重载（优先 FVM）🔥
flutter() {
  emulate -L zsh
  setopt no_aliases

  local d="$PWD"
  local root=""

  while [[ "$d" != "/" ]]; do
    if [[ -f "$d/.fvmrc" || -x "$d/.fvm/flutter_sdk/bin/flutter" || -f "$d/.fvm/fvm_config.json" ]]; then
      root="$d"
      break
    fi
    d="${d:h}"
  done

  if [[ -n "$root" && -x "$root/.fvm/flutter_sdk/bin/flutter" ]]; then
    command "$root/.fvm/flutter_sdk/bin/flutter" "$@"
    return $?
  fi

  if [[ -n "$root" && ( -f "$root/.fvmrc" || -f "$root/.fvm/fvm_config.json" ) ]]; then
    if command -v fvm >/dev/null 2>&1; then
      command fvm flutter "$@"
      return $?
    fi
    print -u2 "✖ 检测到 FVM 项目，但找不到 fvm 命令。请先安装 fvm。"
    return 127
  fi

  if command -v flutter >/dev/null 2>&1; then
    command flutter "$@"
    return $?
  fi

  print -u2 "✖ flutter: command not found（未安装系统 Flutter，且当前目录不在 FVM 项目内）"
  return 127
}

# 🔥 fvm 修复（与 Dart 内核匹配）🔥
fixfvm() {
  echo "🔍 修复 fvm 与 Dart SDK 的内核版本不匹配..."
  dart pub global deactivate fvm || true
  rm -rf ~/.pub-cache/bin/fvm* ~/.pub-cache/global_packages/fvm
  dart pub global activate fvm
  hash -r
  echo "✅ fvm 已重新安装并与当前 Dart SDK 匹配"
}

# 🔥 版本检查 🔥
check1() {
  echo "================ Dart =================="
  which dart; dart --version 2>/dev/null; echo
  echo "================ FVM ==================="
  which fvm; fvm --version 2>/dev/null; echo
  echo "================ Flutter ==============="
  if whence -v flutter | grep -q "shell function"; then
    echo "📍 flutter 是 shell function，函数体："
    functions flutter
    echo "📍 可执行路径（忽略函数）："; whence -p flutter || echo "（仅有函数）"
  else
    echo "📍 flutter 路径："; whence -p flutter
  fi
  echo "🔖 flutter --version:"; flutter --version
}

# 🔥 快捷命令 🔥
rb() { exec -l "$SHELL"; }
a()  { open "$HOME/.bash_profile"; }
b()  { open "$HOME/.zshrc"; }
i()  { open -a Simulator; }

# ✅ d：默认进入你写死的项目目录（可传参覆盖）
d()  {
  local dir; dir="$(_get_project_dir "${1:-}")" || return 1
  cd "$dir" || return 1
  echo "📍 已进入：$dir"
}

# ✅ check：也基于默认项目目录执行（可传参）
check() {
  local dir; dir="$(_get_project_dir "${1:-}")" || return 1
  cd "$dir" || return 1

  echo; java -version; echo
  echo "JAVA_HOME=$JAVA_HOME"; echo

  fvm use 3.24.5 --force
  flutter doctor -v
}

# 🔥 JDK17 锁定到项目（c）🔥
# ✅ 默认项目目录改为硬编码常量 + 自检
c() {
  local project_dir; project_dir="$(_get_project_dir "${1:-}")" || return 1
  local want_major="17"

  cd "$project_dir" || { echo "❌ cd 失败：$project_dir"; return 1; }
  command -v jenv >/dev/null 2>&1 || { echo "❌ 未检测到 jenv（brew install jenv）"; return 1; }
  [[ -e ~/.jenv/shims/.jenv-shim ]] && rm -f ~/.jenv/shims/.jenv-shim
  try_run jenv 'eval "$(jenv init -)"'
  try_run jenv 'jenv enable-plugin export >/dev/null 2>&1'

  local jdk_home
  jdk_home="$((/usr/libexec/java_home -v "$want_major") 2>/dev/null)"
  [[ -n "$jdk_home" && -d "$jdk_home" ]] || { echo "❌ 未找到本机 JDK $want_major。建议：brew install --cask temurin17"; return 1; }

  if ! jenv versions --bare | grep -Eq "^$want_major(\.|$)"; then
    try_run jenv "jenv add \"$jdk_home\"" || return 1
    try_run jenv "jenv rehash"
  fi
  local jdk_label
  jdk_label="$(jenv versions --bare | awk -v m="$want_major" '$0 ~ "^"m"(\\.|$)" {print; exit}')"
  [[ -n "$jdk_label" ]] || jdk_label="$(jenv versions --bare | awk '/17/{print; exit}')"
  [[ -n "$jdk_label" ]] || { echo "❌ 无法解析 JDK$want_major 标签（jenv versions 看看）"; return 1; }

  try_run jenv "jenv local \"$jdk_label\""  || return 1
  try_run jenv "jenv shell \"$jdk_label\""  || return 1
  try_run jenv "jenv rehash"

  echo "✅ 已锁定 JDK：$jdk_label"
  echo "✅ JAVA_HOME：${JAVA_HOME:-<未导出>}"
  command -v java >/dev/null 2>&1 && java -version

  typeset -f check >/dev/null && check "$project_dir"
}

# 🔥 update（自检后再跑）🔥
update() {
  try_run "flutter" "flutter upgrade"
  try_run "brew" "brew_update_third_party"
  try_run "dart" "dart pub global activate fvm"
  try_run "gem" "gem update && gem clean"
  try_run "pod" "pod repo update --verbose"
  try_run "rbenv" "brew upgrade rbenv ruby-build"
}

# 🔥 启动时安全初始化@jenv / rbenv（避免再引入 bash completion）🔥
if command -v jenv >/dev/null 2>&1; then
  eval "$(jenv init -)"
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

# 🔥 Completion 🔥
[[ -f "$JOBS_DART_CLI_COMPLETION_FILE" ]] && source "$JOBS_DART_CLI_COMPLETION_FILE" || true
