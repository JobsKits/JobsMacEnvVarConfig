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

# 🔥 解析真实 Flutter 执行器（避免函数误判）🔥
_resolve_flutter_exec() {
  if [[ -x .fvm/flutter_sdk/bin/flutter ]]; then
    echo ".fvm/flutter_sdk/bin/flutter" ".fvm/flutter_sdk/bin/flutter"; return 0
  fi
  if command -v fvm >/dev/null 2>&1; then
    local fpath; fpath="$(fvm which flutter 2>/dev/null || true)"
    if [[ -n "$fpath" && -x "$fpath" ]]; then
      echo "fvm" "fvm flutter"; return 0
    fi
    echo "fvm" "fvm flutter"; return 0
  fi
  local sysbin; sysbin="$(whence -p flutter 2>/dev/null || true)"
  if [[ -n "$sysbin" && -x "$sysbin" ]]; then
    echo "$sysbin" "$sysbin"; return 0
  fi
  return 1
}

_ensure_flutter_available() {
  local cmd prefix
  if read -r cmd prefix < <(_resolve_flutter_exec); then
    echo "🛠️  使用 Flutter 执行器：$prefix"
    echo "$cmd" "$prefix"; return 0
  fi
  echo "⚠️  未找到 Flutter，尝试修复 FVM..."
  if command -v dart >/dev/null 2>&1; then
    if typeset -f fixfvm >/dev/null; then fixfvm || true
    else
      dart pub global deactivate fvm >/dev/null 2>&1 || true
      dart pub global activate  fvm >/dev/null 2>&1 || true
      hash -r
    fi
  fi
  if read -r cmd prefix < <(_resolve_flutter_exec); then
    echo "🛠️  修复成功：$prefix"
    echo "$cmd" "$prefix"; return 0
  fi
  echo "❌ 仍不可用：请确保 .fvm/flutter_sdk 或 fvm 或系统 flutter 可用"; return 1
}


# 🔥 构建前置（智能 + 可选参数 + 强校验执行器）🔥
buildCheck() {
  emulate -L zsh
  set +o noglob
  local here="$PWD" project_path ans
  local auto=0 do_clean=1 do_get=1 do_doctor=1 force_get=0 skip_lock_check=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) auto=1 ;;
      --no-clean) do_clean=0 ;;
      --no-get) do_get=0 ;;
      --no-doctor) do_doctor=0 ;;
      --force-get) force_get=1 ;;
      --skip-lock-check) skip_lock_check=1 ;;
      *) echo "⚠️  未知参数：$1" ;;
    esac; shift
  done
  if [[ -d "$here/lib" && -f "$here/pubspec.yaml" ]]; then
    project_path="$here"
  else
    project_path="$(get_flutter_project_dir "$here")" || { echo "已取消"; return 1; }
    cd "$project_path" || { echo "❌ cd 失败：$project_path"; return 1; }
  fi
  echo "📍 项目：$project_path"

  local _cmd _prefix
  if ! read -r _cmd _prefix < <(_ensure_flutter_available); then return 1; fi

  if (( auto == 0 )); then
    read -r "?是否执行清理和依赖安装 (回车=执行，任意字符=跳过): " ans
    [[ -n "$ans" ]] && { echo "⏩ 用户选择跳过"; return 0; }
  fi

  local need_get=1
  if (( skip_lock_check == 0 && force_get == 0 )); then
    if [[ -f pubspec.yaml && -f pubspec.lock && pubspec.lock -nt pubspec.yaml ]]; then
      need_get=0
    fi
  fi
  (( force_get )) && need_get=1

  if (( do_clean )); then
    echo "🧹 清理：$_prefix clean"; try_run "$_cmd" "$_prefix clean"
  else
    echo "⏭️  跳过 clean"
  fi
  if (( do_get )); then
    if (( need_get )); then
      echo "📦 依赖：$_prefix pub get"; try_run "$_cmd" "$_prefix pub get"
    else
      echo "ℹ️  依赖未变化（pubspec.lock 新于 pubspec.yaml），跳过 pub get（--force-get 可强制）"
    fi
  else
    echo "⏭️  跳过 pub get"
  fi
  if (( do_doctor )); then
    echo "🩺 体检：$_prefix doctor -v"; try_run "$_cmd" "$_prefix doctor -v"
  else
    echo "⏭️  跳过 doctor"
  fi
}


# 🔥 Flutter 项目识别 & 目录选择 🔥
is_flutter_project() { local dir="$1"; [[ -d "$dir/lib" && -f "$dir/pubspec.yaml" ]]; }

get_flutter_project_dir() {
  local start="${1:-$PWD}" project_path="$start" input_path
  while ! is_flutter_project "$project_path"; do
    echo "❌ [$project_path] 不是 Flutter 项目目录（缺少 lib/ 或 pubspec.yaml）" >&2
    read -r "?👉 请输入 Flutter 项目路径（回车=继续询问，q=退出）: " input_path
    [[ "$input_path" == [Qq] ]] && return 1
    [[ -z "$input_path" ]] && continue
    eval "project_path=\"$input_path\""
    project_path="$(cd "$project_path" 2>/dev/null && pwd || echo "")"
    [[ -z "$project_path" ]] && echo "⚠️ 路径无效，请重试" >&2
  done
  printf "%s\n" "$project_path"
}

# 🔥 APK / IPA 构建（保持你的逻辑）🔥
set_flutter_cmd() {
  export PATH="$HOME/.pub-cache/bin:$PATH"
  if command -v fvm >/dev/null 2>&1; then flutter_cmd=(fvm flutter)
  else flutter_cmd=(flutter); fi
  echo "[INFO] flutter_cmd = ${flutter_cmd[*]}"
}

read_project_flutter_version() {
  local v=""
  if [[ -f .fvm/version ]]; then
    v="$(tr -d '\r' < .fvm/version | tr -d '[:space:]')"; [[ -n "$v" ]] && echo "$v" && return 0
  fi
  if [[ -f .fvmrc ]]; then
    if command -v jq >/dev/null 2>&1 && head -c1 .fvmrc | grep -q '{'; then
      v="$(jq -r '.flutter // .flutterSdkVersion // empty' .fvmrc 2>/dev/null | tr -d '[:space:]')"
      [[ -n "$v" ]] && echo "$v" && return 0
    fi
    v="$(sed -E 's/^[[:space:]]+|[[:space:]]+$//g' .fvmrc | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    [[ -n "$v" ]] && echo "$v" && return 0
  fi
  if [[ -f .fvm/fvm_config.json ]] && command -v jq >/dev/null 2>&1; then
    v="$(jq -r '.flutter // .flutterSdkVersion // empty' .fvm/fvm_config.json 2>/dev/null | tr -d '[:space:]')"
    [[ -n "$v" ]] && echo "$v" && return 0
  fi
  if [[ -x .fvm/flutter_sdk/bin/flutter ]]; then
    v="$(.fvm/flutter_sdk/bin/flutter --version 2>/dev/null | grep -Eo 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -n1)"
    [[ -n "$v" ]] && echo "$v" && return 0
  fi
  return 1
}

ensure_fvm_and_flutter_version_before_build() {
  if ! command -v fvm >/dev/null 2>&1; then
    echo "[INFO] 未检测到 fvm，准备安装"
    if ! command -v dart >/dev/null 2>&1; then echo "[ERROR] 未检测到 dart"; return 1; fi
    dart pub global deactivate fvm >/dev/null 2>&1 || true
    dart pub global activate  fvm || { echo "[ERROR] fvm 安装失败"; return 1; }
    echo "[OK] fvm 安装成功"
  else
    dart pub global activate fvm >/dev/null 2>&1 || true
    echo "[INFO] fvm 已就绪"
  fi

  set_flutter_cmd

  local desired_version=""
  if desired_version="$(read_project_flutter_version)"; then
    echo "[INFO] 项目已绑定 Flutter 版本：$desired_version"
  else
    echo "[INFO] 项目未绑定 Flutter 版本，尝试获取 stable 列表"
    local versions latest pick
    versions="$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json \
      | jq -r '.releases[] | select(.channel=="stable") | .version' | sort -V | uniq | tac)"
    latest="$(echo "$versions" | head -n1)"
    if command -v fzf >/dev/null 2>&1; then
      pick="$(echo "$versions" | fzf --prompt='选择 Flutter 版本：' --height=50% --border --ansi)"
      desired_version="$(echo "$pick" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+$')"
    fi
    desired_version="${desired_version:-$latest}"
    printf '{ "flutter": "%s" }\n' "$desired_version" > .fvmrc
    mkdir -p .fvm
    printf '{ "flutter": "%s", "flutterSdkVersion": "%s" }\n' "$desired_version" "$desired_version" > .fvm/fvm_config.json
    printf '%s\n' "$desired_version" > .fvm/version
    echo "[OK] 已写入 .fvmrc / .fvm/fvm_config.json / .fvm/version：$desired_version"
  fi

  echo "[INFO] 安装 Flutter $desired_version"
  fvm install "$desired_version" || { echo "[ERROR] fvm install 失败"; return 1; }
  fvm use "$desired_version" --force || { echo "[ERROR] fvm use 失败"; return 1; }
  set_flutter_cmd
  echo "[OK] Flutter $desired_version 就绪"
}

ensure_jdk17() {
  if ! /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
    echo "[ERROR] 系统未安装 JDK 17（建议：brew install --cask temurin17）" >&2
    return 1
  fi
  jenv add "$(/usr/libexec/java_home -v 17)" >/dev/null 2>&1 || true
  jenv rehash
  local pick_17; pick_17="$(jenv versions --bare | grep -E '(^|[[:space:]])(.*17(\.|$).*)' | head -n1 || true)"
  [[ -z "${pick_17:-}" ]] && { echo "[ERROR] jenv 中未发现 JDK 17" >&2; return 1; }
  jenv shell "$pick_17"
  export JENV_VERSION="$pick_17"
  export JAVA_HOME="$(jenv prefix)"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "$pick_17" > .java-version
  echo "JENV_VERSION=$JENV_VERSION"
  echo "JAVA_HOME=$JAVA_HOME"
  java -version
}

apk() {
  local project_path; project_path="$(get_flutter_project_dir "$PWD")" || return 1
  echo "[OK] 已确认 Flutter 项目目录: $project_path"
  cd "$project_path" || return 1
  typeset -f buildCheck >/dev/null && buildCheck -y || return $?
  ensure_fvm_and_flutter_version_before_build || return $?
  ensure_jdk17 || return $?
  if [[ -f "plugins/htprotect/pubspec.yaml" ]]; then
    echo "[INFO] 执行子插件依赖更新: plugins/htprotect"
    (cd plugins/htprotect && "${flutter_cmd[@]}" pub get) || return $?
  else
    echo "[WARN] 未找到 plugins/htprotect/pubspec.yaml，跳过 pub get"
  fi
  echo "[INFO] 开始构建 APK（release）..."
  "${flutter_cmd[@]}" build apk --release || return $?
  echo "[INFO] 打开输出目录: ./build/app/outputs/"; open "./build/app/outputs/"
}

ipa() {
  typeset -f buildCheck >/dev/null && buildCheck -y || return $?
  local project_path; project_path="$(get_flutter_project_dir "$PWD")" || return 1
  echo "✅ 已确认 Flutter 项目目录: $project_path"
  cd "$project_path" || return 1
  echo "🚀 开始构建 iOS（release）..."
  flutter build ipa --release || return $?
  echo "📂 打开输出目录: ./build/ios/ipa/"; open "./build/ios/ipa/"
}

# 🔥 config：用 Xcode 打开配置文件（无 Xcode 则用系统文本编辑器）🔥
config() {
  local arg="$1"
  local home_dir="${HOME}"
  local target=""
  local xcode_app="/Applications/Xcode.app"

  # 无参数：默认打开 ~/.zshrc
  if [[ -z "$arg" ]]; then
    target="${home_dir}/.zshrc"
  else
    if [[ "$arg" == .* ]]; then
      target="${home_dir}/${arg}"
    elif [[ "$arg" == /* ]]; then
      target="$arg"
    else
      target="${home_dir}/${arg}"
    fi
  fi

  if [[ ! -e "$target" ]]; then
    echo "❌ 找不到：$target"
    echo "👉 用法：config（打开 ~/.zshrc） / config .profile（打开 \$HOME/.profile）"
    return 1
  fi

  if [[ -d "$xcode_app" ]]; then
    open -a "Xcode" "$target"
  else
    open -e "$target"
  fi
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

# 🔥 新系统环境配置 🔥
install() {
  set -euo pipefail

  # -------- pretty output --------
  _i() { print -P "%F{cyan}ℹ️  %f$*"; }
  _ok(){ print -P "%F{green}✅ %f$*"; }
  _w() { print -P "%F{yellow}⚠️  %f$*"; }
  _e() { print -P "%F{red}❌ %f$*"; }

  # -------- helpers --------
  _has() { command -v "$1" >/dev/null 2>&1; }

  _append_once() {
    local line="$1"
    local file="${2:-$HOME/.zshrc}"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -Fqx "$line" "$file"; then
      return 0
    fi
    print "" >> "$file"
    print "$line" >> "$file"
  }

  _ensure_homebrew() {
    if _has brew; then
      _ok "Homebrew 已存在：$(brew --version | head -n 1)"
      return 0
    fi

    _i "开始安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    _ok "Homebrew 安装完成"

    # 让当前 shell 立刻可用（Apple Silicon: /opt/homebrew, Intel: /usr/local）
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      _append_once 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zshrc"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
      _append_once 'eval "$(/usr/local/bin/brew shellenv)"' "$HOME/.zshrc"
    fi
  }

  _brew_install_if_needed() {
    local formula="$1"
    if brew list --formula "$formula" >/dev/null 2>&1; then
      _ok "已安装：$formula"
    else
      _i "安装：$formula"
      brew install "$formula"
      _ok "安装完成：$formula"
    fi
  }

  _ensure_jenv_init() {
    # jenv 官方推荐：export PATH + eval init  (brew 安装后仍需要 init) :contentReference[oaicite:1]{index=1}
    _append_once 'export PATH="$HOME/.jenv/bin:$PATH"' "$HOME/.zshrc"
    _append_once 'eval "$(jenv init -)"' "$HOME/.zshrc"
  }

  _ensure_fvm() {
    if _has fvm; then
      _ok "FVM 已存在：$(fvm --version 2>/dev/null || echo "installed")"
      return 0
    fi

    _i "安装 FVM（Homebrew tap -> install）"
    # 常见方式：brew tap leoafarias/fvm && brew install fvm :contentReference[oaicite:2]{index=2}
    brew tap leoafarias/fvm
    brew install fvm
    _ok "FVM 安装完成"
  }

  _post_openjdk_hint() {
    _w "openjdk 安装完成后，若你想让系统 java 指向它："
    _w "  - 你可以用 jenv 管理 JAVA_HOME（推荐）"
    _w "  - 示例：jenv add \"$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk/Contents/Home\""
  }

  # -------- main flow --------
  _ensure_homebrew

  _i "更新 Homebrew..."
  brew update

  # Flutter 环境（用 fvm 管理 Flutter 版本更稳）
  _ensure_fvm

  # Java / Ruby 工具链
  _brew_install_if_needed jenv      # :contentReference[oaicite:3]{index=3}
  _ensure_jenv_init

  _brew_install_if_needed rbenv     # :contentReference[oaicite:4]{index=4}
  _brew_install_if_needed openjdk   # :contentReference[oaicite:5]{index=5}
  _post_openjdk_hint

  _ok "基础工具安装完成。建议新开一个终端窗口，让 .zshrc 的初始化生效。"

  _i "关于 renv：这是 R 的项目依赖管理包（不是 brew 公式）。你可以在 R 里执行："
  _i '  install.packages("renv")'
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
