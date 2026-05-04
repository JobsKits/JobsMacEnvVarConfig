# 从你原来的 .zshrc 拆出的自定义能力
# 现在不再直接堆进主 .zshrc，而是作为外挂模块加载

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

# ================================== update 菜单化：fzf 模块更新 ==================================
# 设计目标：
# 1. update 默认走 fzf 菜单；如果没有 fzf，则退化为“默认全量更新，不含 OpenClaw”。
# 2. 默认全量更新是激进更新：除 OpenClaw 之外，尽量更新所有开发环境工具链。
# 3. OpenClaw 是源码仓库同步 + 构建，耗时和副作用更高，所以默认全量不包含它。
# 4. Go 不进入 update：Go 没有可靠的“枚举并升级所有全局工具”的标准命令。

JOBS_UPDATE_OPTION_DEFAULT="01. 🚀 默认全量更新，不含 OpenClaw"
JOBS_UPDATE_OPTION_FULL_WITH_OPENCLAW="02. 🌕 全量更新，包含 OpenClaw"
JOBS_UPDATE_OPTION_OPENCLAW="03. 🦞 OpenClaw：同步源码并构建"
JOBS_UPDATE_OPTION_HOMEBREW="04. 🍺 Homebrew：更新 brew / formula / cask / cleanup / doctor"
JOBS_UPDATE_OPTION_ANDROID="05. 🤖 Android SDK：更新 sdkmanager 管理的 Android 工具链"
JOBS_UPDATE_OPTION_FLUTTER="06. 🐦 Flutter：升级 Flutter SDK"
JOBS_UPDATE_OPTION_DART_FVM="07. 🎯 Dart / FVM：更新 FVM"
JOBS_UPDATE_OPTION_NODE="08. 🟢 Node / npm / pnpm / corepack：更新 Node 全局生态"
JOBS_UPDATE_OPTION_RUST="09. 🦀 Rust / Cargo：更新 Rust toolchain 和 cargo 全局工具"
JOBS_UPDATE_OPTION_PYTHON="10. 🐍 Python / pip / pyenv：更新 Python 工具链和 pip 全局包"
JOBS_UPDATE_OPTION_RUBYGEMS="11. 💎 RubyGems：更新 gem 并清理旧版本"
JOBS_UPDATE_OPTION_COCOAPODS="12. 🥥 CocoaPods：更新 Specs 仓库"
JOBS_UPDATE_OPTION_RBENV="13. 💠 rbenv / ruby-build：更新 Ruby 版本管理工具"

jobs_update_print_section() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

jobs_update_warn() {
  echo "⚠️  $*"
}

jobs_update_has_brew_formula() {
  command -v brew >/dev/null 2>&1 || return 1
  brew list --formula "$1" >/dev/null 2>&1
}

jobs_update_run_module() {
  local title="$1"
  local func="$2"
  local module_status=0

  jobs_update_print_section "$title"

  if ! typeset -f "$func" >/dev/null 2>&1; then
    jobs_update_warn "缺少模块函数：$func"
    return 0
  fi

  "$func"
  module_status=$?
  if (( module_status != 0 )); then
    jobs_update_warn "$title 执行失败，继续后续 update 模块"
  fi
  return 0
}

jobs_update_print_plan() {
  local title="$1"
  shift
  local total=$#
  local item=""
  local i=1

  jobs_update_print_section "$title"
  echo "本次将依次执行 $total 个子模块："
  for item in "$@"; do
    printf "  [%02d/%02d] %s\n" "$i" "$total" "$item"
    (( i++ ))
  done
}

# ------------------------------ Homebrew ------------------------------
jobs_update_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    jobs_update_warn "[brew] not installed, skip Homebrew update"
    return 0
  fi

  brew_update_third_party
}

# ------------------------------ Android SDK ------------------------------
jobs_find_android_sdkmanager() {
  emulate -L zsh
  setopt null_glob

  local candidate=""
  local brew_prefix=""
  local -a candidates

  if command -v sdkmanager >/dev/null 2>&1; then
    whence -p sdkmanager
    return 0
  fi

  if command -v brew >/dev/null 2>&1 && brew list --formula android-commandlinetools >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix android-commandlinetools 2>/dev/null || true)"
  fi

  candidates=(
    "${ANDROID_HOME:-}/cmdline-tools/latest/bin/sdkmanager"
    "${ANDROID_SDK_ROOT:-}/cmdline-tools/latest/bin/sdkmanager"
    "$HOME/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager"
    "$HOME/Library/Android/sdk/tools/bin/sdkmanager"
    "$brew_prefix/bin/sdkmanager"
    "$brew_prefix/cmdline-tools/latest/bin/sdkmanager"
    "$HOME/Library/Android/sdk/cmdline-tools"/*/bin/sdkmanager(N)
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    printf "%s\n" "$candidate"
    return 0
  done

  return 1
}

jobs_update_android_sdk() {
  local sdkmanager=""
  local package_list=""
  local latest_build_tools=""
  local latest_platform=""
  local -a packages

  sdkmanager="$(jobs_find_android_sdkmanager 2>/dev/null || true)"
  if [[ -z "$sdkmanager" ]]; then
    jobs_update_warn "未找到 sdkmanager，跳过 Android SDK 更新"
    jobs_update_warn "常见位置：$HOME/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager"
    return 0
  fi

  echo "✅ sdkmanager：$sdkmanager"

  echo "➤ 接受 Android SDK licenses"
  yes | "$sdkmanager" --licenses >/dev/null 2>&1 || jobs_update_warn "licenses 处理失败或无需处理，继续"

  echo "➤ sdkmanager --update"
  "$sdkmanager" --update || jobs_update_warn "sdkmanager --update failed，继续"

  echo "➤ 扫描 latest Android platform / build-tools"
  package_list="$("$sdkmanager" --list 2>/dev/null || true)"

  latest_build_tools="$(printf "%s\n" "$package_list" \
    | awk -F'|' '/^ *build-tools;[0-9]/ {pkg=$1; gsub(/^[ \t]+|[ \t]+$/, "", pkg); print pkg}' \
    | tail -n 1)"

  latest_platform="$(printf "%s\n" "$package_list" \
    | awk -F'|' '/^ *platforms;android-[0-9]+/ {pkg=$1; gsub(/^[ \t]+|[ \t]+$/, "", pkg); n=pkg; sub(/^platforms;android-/, "", n); print n "\t" pkg}' \
    | sort -n \
    | tail -n 1 \
    | cut -f2-)"

  packages=(
    "platform-tools"
    "cmdline-tools;latest"
    "emulator"
  )
  [[ -n "$latest_build_tools" ]] && packages+=("$latest_build_tools")
  [[ -n "$latest_platform" ]] && packages+=("$latest_platform")

  echo "➤ 安装/更新 Android SDK packages："
  printf "   %s\n" "${packages[@]}"
  yes | "$sdkmanager" --install "${packages[@]}" || jobs_update_warn "Android SDK package 安装/更新失败，继续"
}

# ------------------------------ Flutter / Dart / FVM ------------------------------
jobs_update_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    jobs_update_warn "[flutter] not installed, skip Flutter update"
    return 0
  fi

  flutter upgrade || jobs_update_warn "flutter upgrade failed，继续"
}

jobs_update_dart_fvm() {
  if ! command -v dart >/dev/null 2>&1; then
    jobs_update_warn "[dart] not installed, skip FVM update"
    return 0
  fi

  dart pub global activate fvm || jobs_update_warn "dart pub global activate fvm failed，继续"
}

# ------------------------------ Node / npm / pnpm / corepack ------------------------------
jobs_force_remove_dir() {
  emulate -L zsh

  local target="$1"

  [[ -n "$target" && -e "$target" ]] || return 0

  # 第一轮：普通删除。
  rm -rf -- "$target" 2>/dev/null && return 0

  # 第二轮：处理 Homebrew / npm 残留目录里常见的只读权限、ACL、immutable flag。
  chmod -R u+rwX -- "$target" 2>/dev/null || true
  if command -v chflags >/dev/null 2>&1; then
    chflags -R nouchg,noschg -- "$target" 2>/dev/null || true
  fi
  rm -rf -- "$target" 2>/dev/null && return 0

  # 第三轮：不再询问，直接 sudo 删除。这里仅针对 npm 全局残留目录调用，路径由脚本扫描得出。
  if command -v sudo >/dev/null 2>&1; then
    echo "➤ sudo rm -rf $target"
    sudo rm -rf -- "$target" && return 0
  fi

  return 1
}

jobs_npm_cleanup_global_temp_dirs() {
  emulate -L zsh
  setopt null_glob

  local npm_root="$1"
  local tmp_dir=""
  local base=""

  [[ -n "$npm_root" && -d "$npm_root" ]] || return 0

  # npm update -g 有时会把上一次失败残留的隐藏临时目录当成包名，例如：
  #   .quicktype-zaTqycTW
  # 这种包名以点开头，npm 会报 EINVALIDPACKAGENAME。这里仅清理这类 npm 残留，保留 .bin。
  for tmp_dir in "$npm_root"/.*(N); do
    base="${tmp_dir:t}"
    [[ "$base" == "." || "$base" == ".." || "$base" == ".bin" || "$base" == ".cache" ]] && continue

    if [[ "$base" == .*-* ]]; then
      echo "➤ 清理 npm 全局残留目录：$tmp_dir"
      if jobs_force_remove_dir "$tmp_dir"; then
        echo "✅ 已删除 npm 残留目录：$tmp_dir"
      else
        jobs_update_warn "无法删除 npm 残留目录：$tmp_dir；已在 npm 包枚举里忽略隐藏目录，不会再触发 EINVALIDPACKAGENAME"
      fi
    fi
  done
}

jobs_npm_read_package_name() {
  local package_json="$1"
  [[ -f "$package_json" ]] || return 1

  if command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs"); const p=process.argv[1]; try { const data=JSON.parse(fs.readFileSync(p,"utf8")); if (data && data.name) console.log(data.name); } catch (_) {}' "$package_json" 2>/dev/null
  else
    sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$package_json" | head -n 1
  fi
}

jobs_npm_global_package_names() {
  emulate -L zsh
  setopt null_glob

  local npm_root="$1"
  local dir=""
  local scoped_dir=""
  local base=""
  local name=""

  [[ -n "$npm_root" && -d "$npm_root" ]] || return 0

  for dir in "$npm_root"/*(N/); do
    base="${dir:t}"
    [[ -z "$base" || "$base" == .* ]] && continue

    if [[ "$base" == @* ]]; then
      for scoped_dir in "$dir"/*(N/); do
        name="$(jobs_npm_read_package_name "$scoped_dir/package.json")"
        [[ -n "$name" ]] || continue
        [[ "$name" == .* || "$name" == "npm" || "$name" == "pnpm" || "$name" == "openclaw" ]] && continue
        printf "%s\n" "$name"
      done
    else
      name="$(jobs_npm_read_package_name "$dir/package.json")"
      [[ -n "$name" ]] || continue
      [[ "$name" == .* || "$name" == "npm" || "$name" == "pnpm" || "$name" == "openclaw" ]] && continue
      printf "%s\n" "$name"
    fi
  done | sort -u
}

jobs_npm_package_dir_for_name() {
  emulate -L zsh

  local npm_root="$1"
  local package="$2"

  [[ -n "$npm_root" && -n "$package" ]] || return 1
  printf "%s/%s
" "$npm_root" "$package"
}

jobs_npm_repair_package_permissions() {
  emulate -L zsh

  local package="$1"
  local npm_root="$2"
  local package_dir=""

  package_dir="$(jobs_npm_package_dir_for_name "$npm_root" "$package")"

  # npm 安装全局包时经常需要在 node_modules 里 rename 包目录到 .xxx 临时目录。
  # 如果历史安装产生了 root-owned 文件，会触发 EACCES；这里直接修复当前包目录和父目录的用户写权限。
  [[ -d "$npm_root" ]] && chmod u+rwx -- "$npm_root" 2>/dev/null || true
  [[ -e "$package_dir" ]] && chmod -R u+rwX -- "$package_dir" 2>/dev/null || true

  if command -v chflags >/dev/null 2>&1; then
    [[ -d "$npm_root" ]] && chflags nouchg,noschg -- "$npm_root" 2>/dev/null || true
    [[ -e "$package_dir" ]] && chflags -R nouchg,noschg -- "$package_dir" 2>/dev/null || true
  fi
}

jobs_npm_install_global_latest() {
  emulate -L zsh

  local package="$1"
  local npm_root="$2"

  [[ -n "$package" ]] || return 0

  echo "➤ npm install -g ${package}@latest"
  if npm install -g "${package}@latest"; then
    return 0
  fi

  jobs_update_warn "npm 全局包第一次更新失败：$package；清理残留并修复权限后重试"
  jobs_npm_cleanup_global_temp_dirs "$npm_root"
  jobs_npm_repair_package_permissions "$package" "$npm_root"

  echo "➤ npm install -g ${package}@latest retry"
  if npm install -g "${package}@latest"; then
    return 0
  fi

  # 激进全量更新模式：仍失败时，不再询问，直接 sudo 重试。
  if command -v sudo >/dev/null 2>&1; then
    jobs_update_warn "npm 全局包普通权限仍失败：$package；直接 sudo 重试"
    echo "➤ sudo npm install -g ${package}@latest"
    sudo npm install -g "${package}@latest" && return 0
  fi

  jobs_update_warn "npm 全局包更新失败：$package，继续"
  return 0
}

jobs_update_npm_global_packages() {
  emulate -L zsh

  local npm_root=""
  local package=""
  local packages_text=""
  local -a packages

  if ! command -v npm >/dev/null 2>&1; then
    jobs_update_warn "[npm] not installed，跳过 npm 全局包更新"
    return 0
  fi

  npm_root="$(npm root -g 2>/dev/null || true)"
  if [[ -z "$npm_root" || ! -d "$npm_root" ]]; then
    jobs_update_warn "无法解析 npm 全局 node_modules 目录，跳过 npm 全局包更新"
    return 0
  fi

  jobs_npm_cleanup_global_temp_dirs "$npm_root"

  packages_text="$(jobs_npm_global_package_names "$npm_root")"
  packages=("${(@f)packages_text}")
  if (( ${#packages[@]} == 0 )); then
    echo "✅ npm 没有发现可更新的全局包"
    return 0
  fi

  echo "➤ npm 全局包逐个升级到 latest（替代 npm update -g，避免隐藏残留目录导致 EINVALIDPACKAGENAME）"
  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    jobs_npm_install_global_latest "$package" "$npm_root"
  done
}

jobs_update_node_npm_pnpm_corepack() {
  if command -v brew >/dev/null 2>&1; then
    if brew list --formula node >/dev/null 2>&1; then
      echo "➤ brew upgrade node"
      brew upgrade node || jobs_update_warn "brew upgrade node failed，继续"
    else
      echo "ℹ️  brew 未管理 node，跳过 brew upgrade node"
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    echo "➤ npm install -g npm@latest"
    npm install -g npm@latest || jobs_update_warn "npm 自升级失败，继续"

    echo "ℹ️  npm 全局包升级会跳过 npm / pnpm / openclaw；openclaw 只由 03. OpenClaw 模块处理"
    jobs_update_npm_global_packages
  else
    jobs_update_warn "[npm] not installed，跳过 npm 全局生态更新"
  fi

  # pnpm 不能无脑 npm install -g，否则会和 Homebrew/corepack 已经放在 /opt/homebrew/bin 的 pnpm 撞文件。
  if command -v brew >/dev/null 2>&1 && brew list --formula pnpm >/dev/null 2>&1; then
    echo "➤ brew upgrade pnpm"
    brew upgrade pnpm || jobs_update_warn "brew upgrade pnpm failed，继续"
  elif command -v corepack >/dev/null 2>&1; then
    echo "➤ corepack enable"
    corepack enable || jobs_update_warn "corepack enable failed，继续"

    echo "➤ corepack prepare pnpm@latest --activate"
    corepack prepare pnpm@latest --activate || jobs_update_warn "corepack prepare pnpm@latest --activate failed，继续"
  elif command -v pnpm >/dev/null 2>&1; then
    echo "ℹ️  已检测到 pnpm：$(whence -p pnpm 2>/dev/null || command -v pnpm)"
    pnpm --version 2>/dev/null || true
    echo "ℹ️  pnpm 已存在但不确定由谁管理，跳过 npm install -g pnpm@latest，避免 EEXIST 覆盖 Homebrew 文件"
  elif command -v npm >/dev/null 2>&1; then
    echo "➤ npm install -g pnpm@latest"
    npm install -g pnpm@latest || jobs_update_warn "npm install -g pnpm@latest failed，继续"
  else
    jobs_update_warn "未检测到 npm / corepack / pnpm，跳过 pnpm 更新"
  fi
}

# ------------------------------ Rust / Cargo ------------------------------
jobs_update_rust_cargo() {
  if command -v rustup >/dev/null 2>&1; then
    echo "➤ rustup update"
    rustup update || jobs_update_warn "rustup update failed，继续"
  else
    jobs_update_warn "[rustup] not installed，跳过 Rust toolchain 更新"
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    jobs_update_warn "[cargo] not installed，跳过 cargo 全局工具更新"
    return 0
  fi

  if ! cargo install-update --help >/dev/null 2>&1; then
    echo "➤ 安装 cargo-update"
    cargo install cargo-update || {
      jobs_update_warn "cargo-update 安装失败，跳过 cargo install-update -a"
      return 0
    }
  fi

  echo "➤ cargo install-update -a"
  cargo install-update -a || jobs_update_warn "cargo install-update -a failed，继续"
}

# ------------------------------ Python / pip / pyenv ------------------------------
jobs_pip_supports_break_system_packages() {
  python3 -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'
}

jobs_pip_upgrade_one() {
  local package="$1"
  local -a pip_args
  [[ -n "$package" ]] || return 0

  pip_args=(install --upgrade --user)
  if jobs_pip_supports_break_system_packages; then
    pip_args+=(--break-system-packages)
  fi
  pip_args+=("$package")

  echo "➤ python3 -m pip ${pip_args[*]}"
  python3 -m pip "${pip_args[@]}" || jobs_update_warn "pip package 用户级升级失败：$package"
}

jobs_update_python_pip_pyenv() {
  local outdated_packages=""
  local package=""

  if command -v brew >/dev/null 2>&1; then
    if brew list --formula pyenv >/dev/null 2>&1; then
      echo "➤ brew upgrade pyenv"
      brew upgrade pyenv || jobs_update_warn "brew upgrade pyenv failed，继续"
    else
      echo "ℹ️  brew 未管理 pyenv，跳过 brew upgrade pyenv"
    fi
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    jobs_update_warn "[python3] not installed，跳过 Python / pip 更新"
    return 0
  fi

  echo "ℹ️  pip 使用用户级升级：--user；如当前 Python 受 Homebrew/PEP668 管理，则自动追加 --break-system-packages"
  jobs_pip_upgrade_one pip
  jobs_pip_upgrade_one setuptools
  jobs_pip_upgrade_one wheel

  echo "➤ 扫描 pip outdated packages"
  outdated_packages="$(python3 -m pip list --outdated --format=json 2>/dev/null \
    | python3 -c 'import sys,json; data=json.load(sys.stdin); print("\n".join(item["name"] for item in data))' 2>/dev/null || true)"

  if [[ -z "$outdated_packages" ]]; then
    echo "✅ pip 没有发现可升级的包"
    return 0
  fi

  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    jobs_pip_upgrade_one "$package"
  done <<< "$outdated_packages"
}

# ------------------------------ RubyGems / CocoaPods / rbenv ------------------------------
jobs_update_rubygems() {
  local gem_home=""

  if ! command -v gem >/dev/null 2>&1; then
    jobs_update_warn "[gem] not installed，跳过 RubyGems 更新"
    return 0
  fi

  gem_home="$(gem env home 2>/dev/null || true)"
  if [[ "$gem_home" == /Library/Ruby/Gems/* || "$gem_home" == /System/Library/* ]]; then
    jobs_update_warn "当前 gem 指向 macOS 系统 Ruby：$gem_home"
    jobs_update_warn "跳过 gem update，避免污染系统 Ruby；请先让 rbenv Ruby 在 PATH 中优先"
    return 0
  fi

  echo "✅ RubyGems Home：$gem_home"
  gem update || jobs_update_warn "gem update failed，继续"
  gem clean || jobs_update_warn "gem clean failed，继续"
}

jobs_update_cocoapods() {
  if ! command -v pod >/dev/null 2>&1; then
    jobs_update_warn "[pod] not installed，跳过 CocoaPods Specs 更新"
    return 0
  fi

  pod repo update || jobs_update_warn "pod repo update failed，继续"
}

jobs_update_rbenv_ruby_build() {
  if ! command -v brew >/dev/null 2>&1; then
    jobs_update_warn "[brew] not installed，无法更新 rbenv / ruby-build"
    return 0
  fi

  if brew list --formula rbenv >/dev/null 2>&1 || brew list --formula ruby-build >/dev/null 2>&1; then
    brew upgrade rbenv ruby-build || jobs_update_warn "brew upgrade rbenv ruby-build failed，继续"
  else
    jobs_update_warn "brew 未管理 rbenv / ruby-build，跳过"
  fi
}

# ================================== OpenClaw 更新（供 update 调用） ==================================
# 记录文件：第一次输入有效 openclaw 仓库目录后写入；后续 update 可直接回车沿用。
: "${JOBS_OPENCLAW_REPO_RECORD_FILE:=$HOME/.JobsMacEnv/openclaw_repo_path}"
: "${JOBS_OPENCLAW_REMOTE_URL:=https://github.com/openclaw/openclaw}"

jobs_openclaw_trim_text() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf "%s" "$s"
}

jobs_openclaw_normalize_path() {
  emulate -L zsh
  setopt no_nomatch

  local raw="$*"
  local path=""
  local resolved=""

  raw="$(jobs_openclaw_trim_text "$raw")"

  # Finder 拖入终端时，可能带单/双引号，也可能把空格转义成 \ 。
  if typeset -f jobs_unescape_dragged_path >/dev/null 2>&1; then
    path="$(jobs_unescape_dragged_path "$raw")"
  else
    # zsh quote-removal：安全处理拖入路径里的反斜杠、空格、括号、引号等。
    path="${(Q)raw}"
    [[ "$path" == "~"* ]] && path="${~path}"
  fi

  if [[ -e "$path" || -L "$path" ]]; then
    if typeset -f jobs_resolve_drag_target >/dev/null 2>&1; then
      resolved="$(jobs_resolve_drag_target "$path" 2>/dev/null || true)"
    elif command -v realpath >/dev/null 2>&1; then
      resolved="$(realpath "$path" 2>/dev/null || true)"
    fi
  fi

  [[ -n "$resolved" ]] && path="$resolved"
  printf "%s\n" "${path%/}"
}

jobs_openclaw_canonical_remote_url() {
  emulate -L zsh

  local url="$1"
  url="$(jobs_openclaw_trim_text "$url")"

  # GitHub 同一个仓库可能有 HTTPS / SSH 两种 remote 写法：
  #   https://github.com/openclaw/openclaw.git
  #   git@github.com:openclaw/openclaw.git
  #   ssh://git@github.com/openclaw/openclaw.git
  # 校验时统一归一化成 https://github.com/<owner>/<repo> 再比较。
  if [[ "$url" == git@github.com:* ]]; then
    url="${url#git@github.com:}"
    url="https://github.com/$url"
  elif [[ "$url" == ssh://git@github.com/* ]]; then
    url="${url#ssh://git@github.com/}"
    url="https://github.com/$url"
  elif [[ "$url" == http://github.com/* ]]; then
    url="https://${url#http://}"
  fi

  while [[ "$url" == */ ]]; do
    url="${url%/}"
  done
  url="${url%.git}"
  while [[ "$url" == */ ]]; do
    url="${url%/}"
  done

  printf "%s" "$url"
}

jobs_openclaw_validate_repo() {
  emulate -L zsh

  local repo_path="$1"
  local remote_name=""
  local remote=""
  local remote_names=""
  local remote_urls=""
  local normalized_remote=""
  local detected_remotes=""

  if [[ -z "$repo_path" ]]; then
    echo "⚠️  OpenClaw 目录为空"
    return 1
  fi

  if [[ ! -d "$repo_path" ]]; then
    echo "⚠️  OpenClaw 目录不存在：$repo_path"
    return 1
  fi

  if [[ ! -d "$repo_path/.git" ]]; then
    echo "⚠️  这不是 Git 仓库目录：$repo_path"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "⚠️  缺少 git，无法校验 OpenClaw 仓库"
    return 1
  fi

  remote_names="$(git -C "$repo_path" remote 2>/dev/null || true)"
  while IFS= read -r remote_name; do
    [[ -n "$remote_name" ]] || continue

    remote_urls="$(git -C "$repo_path" remote get-url --all "$remote_name" 2>/dev/null || true)"
    while IFS= read -r remote; do
      [[ -n "$remote" ]] || continue
      normalized_remote="$(jobs_openclaw_canonical_remote_url "$remote")"
      detected_remotes+="   ${remote_name}: ${remote}\n"

      if [[ "$normalized_remote" == "$JOBS_OPENCLAW_REMOTE_URL" ]]; then
        return 0
      fi
    done <<< "$remote_urls"
  done <<< "$remote_names"

  echo "⚠️  这不是 OpenClaw 官方仓库"
  echo "   需要指向：$JOBS_OPENCLAW_REMOTE_URL"
  if [[ -n "$detected_remotes" ]]; then
    printf "%b" "   检测到远程：\n$detected_remotes"
  else
    echo "   未检测到任何 git remote"
  fi
  return 1
}

jobs_openclaw_read_recorded_repo_path() {
  local saved=""
  [[ -f "$JOBS_OPENCLAW_REPO_RECORD_FILE" ]] || return 0
  saved="$(cat "$JOBS_OPENCLAW_REPO_RECORD_FILE" 2>/dev/null || true)"
  [[ -n "$saved" ]] || return 0
  jobs_openclaw_normalize_path "$saved"
}

jobs_openclaw_save_repo_path() {
  local repo_path="$1"
  mkdir -p "${JOBS_OPENCLAW_REPO_RECORD_FILE:h}"
  printf "%s\n" "$repo_path" > "$JOBS_OPENCLAW_REPO_RECORD_FILE"
  echo "✅ 已记录 OpenClaw 仓库目录：$repo_path"
}

jobs_openclaw_choose_repo_path() {
  emulate -L zsh

  local saved=""
  local input=""
  local repo_path=""

  saved="$(jobs_openclaw_read_recorded_repo_path)"

  # 首次运行：没有历史记录时，必须拿到一个有效的 openclaw/openclaw 本地仓库目录。
  while [[ -z "$saved" ]]; do
    echo ""
    echo "🦞 第一次运行 OpenClaw 更新，需要拖入/输入 openclaw 的 git clone 本地目录后回车："
    read -r input

    if [[ -z "$input" ]]; then
      echo "⚠️  第一次运行必须提供 OpenClaw 仓库目录。"
      continue
    fi

    repo_path="$(jobs_openclaw_normalize_path "$input")"
    if jobs_openclaw_validate_repo "$repo_path"; then
      OPENCLAW_REPO_PATH="$repo_path"
      jobs_openclaw_save_repo_path "$OPENCLAW_REPO_PATH"
      return 0
    fi
  done

  # 非首次运行：只询问一次。
  # - 输入新目录：校验通过后使用并覆盖记录；校验失败则跳过本次 OpenClaw 操作。
  # - 直接回车：尝试沿用历史记录；如果历史目录已失效，则中断 OpenClaw 相关操作，不再反复追问。
  echo ""
  echo "🦞 OpenClaw 仓库目录：拖入/输入新目录后回车；直接回车则沿用已记录目录："
  echo "   $saved"
  read -r input

  if [[ -z "$input" ]]; then
    if jobs_openclaw_validate_repo "$saved"; then
      OPENCLAW_REPO_PATH="$saved"
      echo "✅ 使用已记录 OpenClaw 仓库目录：$OPENCLAW_REPO_PATH"
      return 0
    fi

    echo "⚠️  已记录的 OpenClaw 目录已失效，本次中断 OpenClaw 相关操作。"
    echo "👉 下次执行 update 时，请拖入/输入新的 openclaw/openclaw 本地仓库目录。"
    return 1
  fi

  repo_path="$(jobs_openclaw_normalize_path "$input")"
  if jobs_openclaw_validate_repo "$repo_path"; then
    OPENCLAW_REPO_PATH="$repo_path"
    jobs_openclaw_save_repo_path "$OPENCLAW_REPO_PATH"
    return 0
  fi

  echo "⚠️  本次输入的 OpenClaw 目录未通过校验，跳过本次 OpenClaw 相关操作。"
  return 1
}

jobs_openclaw_retry_run() {
  local desc="$1"
  local retries="$2"
  shift 2

  local i=1
  while (( i <= retries )); do
    echo "➤ $desc（第 $i/$retries 次）"
    "$@" && {
      echo "✅ $desc 成功"
      return 0
    }
    echo "⚠️  $desc 失败"
    (( i++ ))
    sleep 1
  done

  echo "❌ $desc 最终失败"
  return 1
}

jobs_openclaw_brew_install_if_needed() {
  local cmd="$1"
  local formula="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ $cmd 已安装"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ 缺少 $cmd，且 Homebrew 不可用，无法自动安装 $formula"
    return 1
  fi

  jobs_openclaw_retry_run "安装 $formula" 2 brew install "$formula"
}

jobs_openclaw_sync_repo() {
  emulate -L zsh

  local repo_path="$1"
  local branch=""
  local upstream=""

  if ! command -v git >/dev/null 2>&1; then
    echo "❌ 缺少 git，无法同步 OpenClaw 代码"
    return 1
  fi

  branch="$(git -C "$repo_path" branch --show-current 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    echo "❌ 当前 OpenClaw 仓库不是普通分支状态，无法自动同步代码：$repo_path"
    return 1
  fi

  upstream="$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  if [[ -n "$upstream" ]]; then
    jobs_openclaw_retry_run "同步 OpenClaw 代码" 2 git -C "$repo_path" pull --ff-only --autostash
    return $?
  fi

  echo "ℹ️  当前分支未设置 upstream，尝试从 origin/$branch 同步"
  jobs_openclaw_retry_run "获取 OpenClaw 远端代码" 2 git -C "$repo_path" fetch origin --prune || return 1

  if ! git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    echo "❌ 远端不存在 origin/$branch，无法自动同步 OpenClaw 代码"
    return 1
  fi

  jobs_openclaw_retry_run "同步 OpenClaw 代码" 2 git -C "$repo_path" pull --ff-only --autostash origin "$branch"
}

jobs_openclaw_fix_path_if_needed() {
  if command -v openclaw >/dev/null 2>&1; then
    echo "✅ openclaw 命令可用"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "⚠️  npm 不可用，跳过 openclaw PATH 修复"
    return 0
  fi

  local bin="$(npm config get prefix 2>/dev/null)/bin"
  [[ -d "$bin" ]] || {
    echo "⚠️  npm 全局 bin 目录不存在，跳过 PATH 修复：$bin"
    return 0
  }

  local line="export PATH=\"$bin:\$PATH\""
  touch "$HOME/.zprofile"
  if ! grep -Fqx "$line" "$HOME/.zprofile" 2>/dev/null; then
    print "" >> "$HOME/.zprofile"
    print -r -- "$line" >> "$HOME/.zprofile"
    echo "✅ 已写入 PATH：$HOME/.zprofile"
  fi

  export PATH="$bin:$PATH"

  if command -v openclaw >/dev/null 2>&1; then
    echo "✅ openclaw 命令可用"
  else
    echo "⚠️  PATH 已修复；如果当前终端仍无法识别 openclaw，请重新打开终端。"
  fi
}

jobs_openclaw_daemon_seems_ok() {
  emulate -L zsh
  setopt null_glob

  local plist=""
  local label=""

  if [[ "$OSTYPE" == darwin* ]] && command -v launchctl >/dev/null 2>&1; then
    for plist in "$HOME"/Library/LaunchAgents/*openclaw*.plist(N); do
      label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || plutil -extract Label raw "$plist" 2>/dev/null || true)"
      if [[ -n "$label" ]] && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        echo "✅ 检测到 OpenClaw LaunchAgent 正常：$label"
        return 0
      fi
    done

    if launchctl list 2>/dev/null | grep -qi "openclaw"; then
      echo "✅ launchctl 中检测到 OpenClaw 服务"
      return 0
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user list-units --type=service --state=running --no-legend 2>/dev/null | grep -qi "openclaw"; then
      echo "✅ systemd user service 中检测到 OpenClaw 服务"
      return 0
    fi
  fi

  if command -v pgrep >/dev/null 2>&1; then
    if pgrep -fl "[o]penclaw" >/dev/null 2>&1; then
      echo "✅ 进程列表中检测到 OpenClaw"
      return 0
    fi
  fi

  return 1
}

jobs_openclaw_onboard_if_needed() {
  emulate -L zsh

  local repo_path="$1"
  local answer=""

  if jobs_openclaw_daemon_seems_ok; then
    echo "✅ OpenClaw daemon 看起来正常，跳过 onboard"
    return 0
  fi

  echo ""
  echo "⚠️  未检测到正常运行的 OpenClaw daemon。"
  echo "👉 回车执行：pnpm openclaw onboard --install-daemon"
  echo "👉 输入任意字符则跳过 daemon 安装/修复"
  read -r answer

  if [[ -n "$answer" ]]; then
    echo "⏭️  已跳过 OpenClaw onboard"
    return 0
  fi

  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw onboard / install daemon" 2 pnpm openclaw onboard --install-daemon
  )
}

jobs_update_openclaw() {
  emulate -L zsh

  local repo_path=""

  if ! jobs_openclaw_choose_repo_path; then
    echo "⚠️  跳过 OpenClaw 更新"
    return 0
  fi

  repo_path="$OPENCLAW_REPO_PATH"

  echo ""
  echo "🦞 开始更新 OpenClaw：$repo_path"

  jobs_openclaw_sync_repo "$repo_path" || return 1
  jobs_openclaw_brew_install_if_needed "node" "node" || return 1
  jobs_openclaw_brew_install_if_needed "pnpm" "pnpm" || return 1

  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "pnpm install" 2 pnpm install || exit 1
    jobs_openclaw_retry_run "pnpm ui:build" 2 pnpm ui:build || exit 1
    jobs_openclaw_retry_run "pnpm build" 2 pnpm build || exit 1
  ) || return 1

  if command -v npm >/dev/null 2>&1; then
    jobs_openclaw_retry_run "安装/更新 openclaw CLI" 2 npm install -g openclaw || return 1
  else
    echo "⚠️  npm 不可用，跳过 openclaw CLI 安装/更新"
  fi

  jobs_openclaw_fix_path_if_needed
  jobs_openclaw_onboard_if_needed "$repo_path" || return 1

  echo "✅ OpenClaw 更新完成"
  echo "👉 如需打开面板，手动执行：openclaw dashboard"
}

# ------------------------------ update 聚合入口 ------------------------------
jobs_update_default_all_without_openclaw() {
  jobs_update_print_plan "$JOBS_UPDATE_OPTION_DEFAULT" \
    "$JOBS_UPDATE_OPTION_HOMEBREW" \
    "$JOBS_UPDATE_OPTION_ANDROID" \
    "$JOBS_UPDATE_OPTION_FLUTTER" \
    "$JOBS_UPDATE_OPTION_DART_FVM" \
    "$JOBS_UPDATE_OPTION_NODE" \
    "$JOBS_UPDATE_OPTION_RUST" \
    "$JOBS_UPDATE_OPTION_PYTHON" \
    "$JOBS_UPDATE_OPTION_RUBYGEMS" \
    "$JOBS_UPDATE_OPTION_COCOAPODS" \
    "$JOBS_UPDATE_OPTION_RBENV"

  jobs_update_run_module "$JOBS_UPDATE_OPTION_HOMEBREW" "jobs_update_homebrew"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_ANDROID" "jobs_update_android_sdk"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_FLUTTER" "jobs_update_flutter"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_DART_FVM" "jobs_update_dart_fvm"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_NODE" "jobs_update_node_npm_pnpm_corepack"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RUST" "jobs_update_rust_cargo"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_PYTHON" "jobs_update_python_pip_pyenv"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RUBYGEMS" "jobs_update_rubygems"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_COCOAPODS" "jobs_update_cocoapods"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RBENV" "jobs_update_rbenv_ruby_build"
}

jobs_update_full_with_openclaw() {
  jobs_update_print_plan "$JOBS_UPDATE_OPTION_FULL_WITH_OPENCLAW" \
    "$JOBS_UPDATE_OPTION_HOMEBREW" \
    "$JOBS_UPDATE_OPTION_ANDROID" \
    "$JOBS_UPDATE_OPTION_FLUTTER" \
    "$JOBS_UPDATE_OPTION_DART_FVM" \
    "$JOBS_UPDATE_OPTION_NODE" \
    "$JOBS_UPDATE_OPTION_RUST" \
    "$JOBS_UPDATE_OPTION_PYTHON" \
    "$JOBS_UPDATE_OPTION_RUBYGEMS" \
    "$JOBS_UPDATE_OPTION_COCOAPODS" \
    "$JOBS_UPDATE_OPTION_RBENV" \
    "$JOBS_UPDATE_OPTION_OPENCLAW"

  jobs_update_run_module "$JOBS_UPDATE_OPTION_HOMEBREW" "jobs_update_homebrew"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_ANDROID" "jobs_update_android_sdk"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_FLUTTER" "jobs_update_flutter"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_DART_FVM" "jobs_update_dart_fvm"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_NODE" "jobs_update_node_npm_pnpm_corepack"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RUST" "jobs_update_rust_cargo"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_PYTHON" "jobs_update_python_pip_pyenv"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RUBYGEMS" "jobs_update_rubygems"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_COCOAPODS" "jobs_update_cocoapods"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_RBENV" "jobs_update_rbenv_ruby_build"
  jobs_update_run_module "$JOBS_UPDATE_OPTION_OPENCLAW" "jobs_update_openclaw"
}

jobs_update_select_with_fzf() {
  emulate -L zsh

  local choice=""
  local -a options

  options=(
    "$JOBS_UPDATE_OPTION_DEFAULT"
    "$JOBS_UPDATE_OPTION_FULL_WITH_OPENCLAW"
    "$JOBS_UPDATE_OPTION_OPENCLAW"
    "$JOBS_UPDATE_OPTION_HOMEBREW"
    "$JOBS_UPDATE_OPTION_ANDROID"
    "$JOBS_UPDATE_OPTION_FLUTTER"
    "$JOBS_UPDATE_OPTION_DART_FVM"
    "$JOBS_UPDATE_OPTION_NODE"
    "$JOBS_UPDATE_OPTION_RUST"
    "$JOBS_UPDATE_OPTION_PYTHON"
    "$JOBS_UPDATE_OPTION_RUBYGEMS"
    "$JOBS_UPDATE_OPTION_COCOAPODS"
    "$JOBS_UPDATE_OPTION_RBENV"
  )

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf "%s\n" "${options[@]}" | fzf \
      --prompt="update > " \
      --height=70% \
      --border \
      --ansi \
      --no-sort \
      --layout=reverse \
      --header=$'Jobs update 菜单：↑/↓ 选择，回车执行。默认推荐执行 01；OpenClaw 不包含在 01 中。' \
      --header-first)"
    if [[ -z "$choice" ]]; then
      echo "⏹️  已取消 update"
      return 0
    fi
  else
    echo "⚠️  未检测到 fzf，自动执行：$JOBS_UPDATE_OPTION_DEFAULT"
    choice="$JOBS_UPDATE_OPTION_DEFAULT"
  fi

  case "$choice" in
    "$JOBS_UPDATE_OPTION_DEFAULT")
      jobs_update_default_all_without_openclaw
      ;;
    "$JOBS_UPDATE_OPTION_FULL_WITH_OPENCLAW")
      jobs_update_full_with_openclaw
      ;;
    "$JOBS_UPDATE_OPTION_OPENCLAW")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_OPENCLAW" "jobs_update_openclaw"
      ;;
    "$JOBS_UPDATE_OPTION_HOMEBREW")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_HOMEBREW" "jobs_update_homebrew"
      ;;
    "$JOBS_UPDATE_OPTION_ANDROID")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_ANDROID" "jobs_update_android_sdk"
      ;;
    "$JOBS_UPDATE_OPTION_FLUTTER")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_FLUTTER" "jobs_update_flutter"
      ;;
    "$JOBS_UPDATE_OPTION_DART_FVM")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_DART_FVM" "jobs_update_dart_fvm"
      ;;
    "$JOBS_UPDATE_OPTION_NODE")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_NODE" "jobs_update_node_npm_pnpm_corepack"
      ;;
    "$JOBS_UPDATE_OPTION_RUST")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_RUST" "jobs_update_rust_cargo"
      ;;
    "$JOBS_UPDATE_OPTION_PYTHON")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_PYTHON" "jobs_update_python_pip_pyenv"
      ;;
    "$JOBS_UPDATE_OPTION_RUBYGEMS")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_RUBYGEMS" "jobs_update_rubygems"
      ;;
    "$JOBS_UPDATE_OPTION_COCOAPODS")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_COCOAPODS" "jobs_update_cocoapods"
      ;;
    "$JOBS_UPDATE_OPTION_RBENV")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_RBENV" "jobs_update_rbenv_ruby_build"
      ;;
    *)
      jobs_update_warn "未知 update 选项：$choice"
      ;;
  esac
}

# 🔥 update（fzf 菜单化）🔥
update() {
  jobs_update_select_with_fzf
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
  
  _ensure_xcode_cli_tools() {
    # 判断 CLT 是否已安装：xcode-select -p 返回路径即为已装
    if xcode-select -p >/dev/null 2>&1; then
      _ok "Xcode Command Line Tools 已存在：$(xcode-select -p)"
      return 0
    fi

    _i "开始安装 Xcode Command Line Tools..."
    xcode-select --install || true
    _w "若弹窗已出现，请完成安装；安装完成后可再次执行 install() 继续。"
  }

  _ensure_ohmyzsh() {
    # 常见安装位置：~/.oh-my-zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      _ok "Oh My Zsh 已存在：$HOME/.oh-my-zsh"
      return 0
    fi

    _i "开始安装 Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    _ok "Oh My Zsh 安装完成"
  }

  # -------- main flow --------
  _ensure_ohmyzsh
  _ensure_xcode_cli_tools
  _ensure_homebrew
  _i "更新 Homebrew..."
  brew update

  xcode-select --install
  softwareupdate --install-rosetta --agree-to-license

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
  
  # 下载Xcode模拟器配件
  rm -rf ~/Library/Caches/com.apple.dt.Xcode
  rm -rf ~/Library/Developer/CoreSimulator/Caches

  xcodebuild -downloadPlatform iOS -verbose
}

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

# 🔥 启动时安全初始化@jenv / rbenv（避免再引入 bash completion）🔥
if command -v jenv >/dev/null 2>&1; then
  eval "$(jenv init -)"
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

# 🔥 Completion 🔥
[[ -f "$JOBS_DART_CLI_COMPLETION_FILE" ]] && source "$JOBS_DART_CLI_COMPLETION_FILE" || true

export PATH="$HOME/.jenv/bin:$PATH"

eval "$(jenv init -)"
