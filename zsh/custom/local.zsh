# 个人终端函数集合
# 这里统一放 JobsMacEnv 挂载到 zsh 里的自定义函数，所有个人命令放一起维护。
# 修改项目路径、私有命令、快捷函数时，优先改这个文件。

# ================================== 日常终端工具 ==================================
# z <path>
# 支持：
# - macOS Finder 替身（alias）
# - Unix 软链接（symlink）
# - 普通目录
# 行为：
# - 解析到真实路径
# - 如果目标是文件，则 cd 到其所在目录
# - 输出最终真实目录

zz() {
  emulate -L zsh
  setopt no_nomatch

  local input_path resolved_path final_dir

  if (( $# == 0 )); then
    echo "usage: zz <path>"
    return 1
  fi

  input_path="$*"

  if [[ "$input_path" == "~"* ]]; then
    input_path="${~input_path}"
  fi

  # Finder 拖进终端时最常见的是空格被转义
  input_path="${input_path//\\ / }"

  if [[ ! -e "$input_path" && ! -L "$input_path" ]]; then
    echo "zz: path not found: $input_path"
    return 1
  fi

  # 1) 先用 Cocoa 解析 macOS alias file
  resolved_path="$(/usr/bin/osascript 2>/dev/null <<EOF
use framework "Foundation"
use scripting additions

set p to "$input_path"
set u to current application's NSURL's fileURLWithPath:p
set {r, e} to current application's NSURL's URLByResolvingAliasFileAtURL:u options:0 |error|:(reference)
if r is missing value then
  return ""
else
  return (r's |path|()) as text
end if
EOF
)"

  # 2) 如果不是 Finder alias，再处理 Unix symlink / 普通路径
  if [[ -z "$resolved_path" ]]; then
    if command -v /usr/bin/realpath >/dev/null 2>&1; then
      resolved_path="$(/usr/bin/realpath "$input_path" 2>/dev/null)"
    fi
  fi

  # 3) 最后兜底
  [[ -n "$resolved_path" ]] || resolved_path="$input_path"
  resolved_path="${resolved_path%/}"

  if [[ -d "$resolved_path" ]]; then
    final_dir="$resolved_path"
  elif [[ -f "$resolved_path" ]]; then
    final_dir="${resolved_path:h}"
  else
    echo "zz: invalid resolved target: $resolved_path"
    return 1
  fi

  builtin cd "$final_dir" || return 1
  /bin/pwd
}

# x <file>
# 支持：
# - 终端里直接拖入 .command / .sh / 可执行文件
# 行为：
# - 自动处理 Finder 拖入路径里的转义空格
# - 自动 chmod +x
# - 直接执行该文件
x() {
  emulate -L zsh
  setopt no_nomatch

  local input_path

  if (( $# == 0 )); then
    echo "usage: x <file>"
    return 1
  fi

  input_path="$*"

  if [[ "$input_path" == "~"* ]]; then
    input_path="${~input_path}"
  fi

  input_path="${input_path//\\ / }"

  if [[ ! -e "$input_path" ]]; then
    echo "x: file not found: $input_path"
    return 1
  fi

  if [[ -d "$input_path" ]]; then
    echo "x: target is a directory, not a file: $input_path"
    return 1
  fi

  chmod +x "$input_path" || {
    echo "x: chmod failed: $input_path"
    return 1
  }

  "$input_path"
}

# 检测 macOS 默认浏览器，并转换为 yt-dlp --cookies-from-browser 支持的名字
jobs_detect_default_browser_for_ytdlp() {
  emulate -L zsh

  local bundle_id

  bundle_id="$(osascript 2>/dev/null <<'EOF'
try
  id of application (path to default application for URL "https://www.youtube.com")
on error
  return ""
end try
EOF
)"

  case "$bundle_id" in
    com.google.Chrome)
      echo "chrome"
      ;;
    com.google.Chrome.canary)
      echo "chrome"
      ;;
    com.microsoft.edgemac)
      echo "edge"
      ;;
    org.mozilla.firefox)
      echo "firefox"
      ;;
    com.apple.Safari)
      echo "safari"
      ;;
    *)
      echo ""
      ;;
  esac
}

# download <url>
# 用法：
#   download "https://www.youtube.com/shorts/xxxx?feature=share"
#
# 行为：
# - 自动检测 macOS 默认浏览器
# - 自动带上浏览器 cookies
# - 本质执行：
#   yt-dlp --cookies-from-browser <browser> <url>
download() {
  emulate -L zsh

  if (( $# == 0 )); then
    echo "usage: download <url>"
    return 1
  fi

  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "download: yt-dlp not found"
    echo "install: brew install yt-dlp"
    return 127
  fi

  local browser
  browser="$(jobs_detect_default_browser_for_ytdlp)"

  if [[ -z "$browser" ]]; then
    echo "download: 未识别默认浏览器，回退使用 chrome cookies"
    browser="chrome"
  fi

  echo "download: using cookies from browser: $browser"

  yt-dlp --cookies-from-browser "$browser" "$@"
}

# ================================== 项目 / 开发环境命令 ==================================
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
JOBS_UPDATE_OPTION_OPENCLAW_GATEWAY="03. 🧩 OpenClaw：同步源码/依赖/UI 并重启 Gateway（不打开配置面板）"
JOBS_UPDATE_OPTION_OPENCLAW="04. 🦞 OpenClaw：同步源码并构建"
JOBS_UPDATE_OPTION_HOMEBREW="05. 🍺 Homebrew：更新 brew / formula / cask / cleanup / doctor"
JOBS_UPDATE_OPTION_ANDROID="06. 🤖 Android SDK：更新 sdkmanager 管理的 Android 工具链"
JOBS_UPDATE_OPTION_FLUTTER="07. 🐦 Flutter：升级 Flutter SDK"
JOBS_UPDATE_OPTION_DART_FVM="08. 🎯 Dart / FVM：更新 FVM"
JOBS_UPDATE_OPTION_NODE="09. 🟢 Node / npm / pnpm / corepack：更新 Node 全局生态"
JOBS_UPDATE_OPTION_RUST="10. 🦀 Rust / Cargo：更新 Rust toolchain 和 cargo 全局工具"
JOBS_UPDATE_OPTION_PYTHON="11. 🐍 Python / pip / pyenv：更新 Python 工具链和 pip 全局包"
JOBS_UPDATE_OPTION_RUBYGEMS="12. 💎 RubyGems：更新 gem 并清理旧版本"
JOBS_UPDATE_OPTION_COCOAPODS="13. 🥥 CocoaPods：更新 Specs 仓库"
JOBS_UPDATE_OPTION_RBENV="14. 💠 rbenv / ruby-build：更新 Ruby 版本管理工具"

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
# 记录文件：第一次输入有效 openclaw 仓库目录后写入；后续 update 会自动沿用。
# 注意：真正执行 git pull 前仍会重新校验目录是否存在、是否是 Git 仓库、remote 是否指向 OpenClaw 官方仓库。
: "${JOBS_OPENCLAW_REPO_RECORD_FILE:=$HOME/.JobsMacEnv/openclaw_repo_path}"
: "${JOBS_OPENCLAW_REMOTE_URL:=https://github.com/openclaw/openclaw}"
: "${JOBS_OPENCLAW_REMOTE_URL_HTTP:=http://github.com/openclaw/openclaw}"
: "${JOBS_OPENCLAW_ONBOARD_MARKER_FILE:=$HOME/.JobsMacEnv/openclaw_onboard_done}"

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

  # GitHub 同一个仓库可能有多种 remote 写法：
  #   https://github.com/openclaw/openclaw.git
  #   http://github.com/openclaw/openclaw.git
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

jobs_openclaw_expected_canonical_remote_url() {
  jobs_openclaw_canonical_remote_url "$JOBS_OPENCLAW_REMOTE_URL"
}

jobs_openclaw_validate_repo() {
  emulate -L zsh

  local repo_path="$1"
  local expected_remote=""
  local remote_name=""
  local remote=""
  local remote_names=""
  local remote_urls=""
  local normalized_remote=""
  local detected_remotes=""

  expected_remote="$(jobs_openclaw_expected_canonical_remote_url)"

  if [[ -z "$repo_path" ]]; then
    echo "⚠️  OpenClaw 目录为空"
    return 1
  fi

  if [[ ! -d "$repo_path" ]]; then
    echo "⚠️  OpenClaw 目录不存在：$repo_path"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "⚠️  缺少 git，无法校验 OpenClaw 仓库"
    return 1
  fi

  if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "⚠️  这不是 Git 仓库目录：$repo_path"
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

      if [[ "$normalized_remote" == "$expected_remote" ]]; then
        return 0
      fi
    done <<< "$remote_urls"
  done <<< "$remote_names"

  echo "⚠️  这不是 OpenClaw 官方仓库"
  echo "   允许远程：$JOBS_OPENCLAW_REMOTE_URL 或 $JOBS_OPENCLAW_REMOTE_URL_HTTP"
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

jobs_openclaw_prompt_repo_path_until_valid() {
  emulate -L zsh

  local input=""
  local repo_path=""

  while true; do
    echo ""
    echo "🦞 请拖入/输入 openclaw 的 git clone 本地目录后回车："
    echo "   目录 remote 需要指向："
    echo "   - $JOBS_OPENCLAW_REMOTE_URL"
    echo "   - $JOBS_OPENCLAW_REMOTE_URL_HTTP"
    echo "   直接回车则取消本次 OpenClaw 操作。"
    read -r input

    if [[ -z "$input" ]]; then
      echo "⚠️  未提供 OpenClaw 仓库目录，取消本次 OpenClaw 操作。"
      return 1
    fi

    repo_path="$(jobs_openclaw_normalize_path "$input")"
    if jobs_openclaw_validate_repo "$repo_path"; then
      OPENCLAW_REPO_PATH="$repo_path"
      jobs_openclaw_save_repo_path "$OPENCLAW_REPO_PATH"
      return 0
    fi

    echo "⚠️  当前目录未通过校验，请重新输入。"
  done
}

jobs_openclaw_choose_repo_path() {
  emulate -L zsh

  local saved=""

  saved="$(jobs_openclaw_read_recorded_repo_path)"

  # 后续运行：不再打断用户询问；先自动使用已记录目录。
  # 但在任何 git pull / onboard / build 前，都会重新校验目录是否存在、是否仍然指向 openclaw/openclaw。
  if [[ -n "$saved" ]]; then
    echo "🦞 检查已记录的 OpenClaw 仓库目录：$saved"
    if jobs_openclaw_validate_repo "$saved"; then
      OPENCLAW_REPO_PATH="$saved"
      echo "✅ 使用已记录 OpenClaw 仓库目录：$OPENCLAW_REPO_PATH"
      return 0
    fi

    echo "⚠️  已记录的 OpenClaw 目录已失效或 remote 不匹配，需要重新指定。"
    echo "   记录文件：$JOBS_OPENCLAW_REPO_RECORD_FILE"
  else
    echo "🦞 未找到已记录的 OpenClaw 仓库目录。"
  fi

  # 首次运行，或历史目录失效：要求用户拖入/输入一个有效本地仓库，并通过 remote 校验后写入记录文件。
  jobs_openclaw_prompt_repo_path_until_valid
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

jobs_openclaw_load_homebrew_shellenv() {
  emulate -L zsh

  local brew_bin=""

  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      return 0
    fi
  done

  return 1
}

jobs_openclaw_install_homebrew_if_needed() {
  emulate -L zsh

  jobs_openclaw_load_homebrew_shellenv >/dev/null 2>&1 || true

  if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew 已安装：$(brew --version | head -n 1)"
    return 0
  fi

  if [[ "$OSTYPE" != darwin* ]]; then
    echo "❌ 当前系统不是 macOS，无法按 Homebrew 流程自动安装依赖"
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "❌ 缺少 curl，无法自动安装 Homebrew"
    echo "👉 可先执行：xcode-select --install"
    return 1
  fi

  echo ""
  echo "🍺 未检测到 Homebrew，开始安装 Homebrew。这个过程可能需要输入系统密码。"
  jobs_openclaw_retry_run "安装 Homebrew" 1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1

  jobs_openclaw_load_homebrew_shellenv >/dev/null 2>&1 || true

  if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew 已安装：$(brew --version | head -n 1)"
    return 0
  fi

  echo "❌ Homebrew 安装后当前 shell 仍不可用"
  echo "👉 请重新打开终端，或检查 /opt/homebrew/bin/brew、/usr/local/bin/brew 是否存在"
  return 1
}

jobs_openclaw_ensure_pnpm_by_brew() {
  emulate -L zsh

  if command -v pnpm >/dev/null 2>&1; then
    echo "✅ pnpm 已安装：$(pnpm --version 2>/dev/null)"
    return 0
  fi

  jobs_openclaw_install_homebrew_if_needed || return 1

  echo "📦 未检测到 pnpm，使用 Homebrew 安装 pnpm"
  jobs_openclaw_retry_run "安装 pnpm" 2 brew install pnpm || return 1

  if command -v pnpm >/dev/null 2>&1; then
    echo "✅ pnpm 已安装：$(pnpm --version 2>/dev/null)"
    return 0
  fi

  echo "❌ pnpm 安装后当前 shell 仍不可用"
  echo "👉 请重新打开终端后再执行 update，或检查 brew 的 shellenv 是否已写入 ~/.zprofile"
  return 1
}

jobs_openclaw_brew_install_if_needed() {
  local cmd="$1"
  local formula="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ $cmd 已安装"
    return 0
  fi

  jobs_openclaw_install_homebrew_if_needed || {
    echo "❌ 缺少 $cmd，且 Homebrew 不可用，无法自动安装 $formula"
    return 1
  }

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

  # 关键防护：真正做 git pull / fetch 前重新校验本地目录，避免历史记录失效、目录被删、remote 被改。
  jobs_openclaw_validate_repo "$repo_path" || {
    echo "❌ OpenClaw 仓库目录校验失败，已停止 git pull：$repo_path"
    return 1
  }

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

jobs_openclaw_sync_dependencies() {
  emulate -L zsh

  local repo_path="$1"

  if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
    echo "❌ OpenClaw 仓库目录不存在，无法同步依赖：$repo_path"
    return 1
  fi

  if [[ ! -f "$repo_path/package.json" ]]; then
    echo "❌ OpenClaw 仓库目录缺少 package.json：$repo_path"
    return 1
  fi

  # git pull 后 package.json / pnpm-lock.yaml / pnpm-workspace.yaml 可能已经变化。
  # 不先执行 pnpm install，后续 pnpm openclaw 会在自动构建时找不到新增 workspace 包。
  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw 依赖同步 pnpm install" 2 pnpm install || exit 1
  )
}

jobs_openclaw_build_runtime() {
  emulate -L zsh

  local repo_path="$1"

  if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
    echo "❌ OpenClaw 仓库目录不存在，无法构建运行时代码：$repo_path"
    return 1
  fi

  if [[ ! -f "$repo_path/package.json" ]]; then
    echo "❌ OpenClaw 仓库目录缺少 package.json：$repo_path"
    return 1
  fi

  # git pull 后 TypeScript 源码可能已经变化；如果 Gateway 服务通过已构建 dist 运行，
  # 只 pnpm install / pnpm ui:build 不够，必须先刷新 runtime dist。
  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw 运行时代码构建 pnpm build" 2 pnpm build || exit 1
  )
}

jobs_openclaw_build_control_ui_assets() {
  emulate -L zsh

  local repo_path="$1"

  if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
    echo "❌ OpenClaw 仓库目录不存在，无法构建 Control UI：$repo_path"
    return 1
  fi

  if [[ ! -f "$repo_path/package.json" ]]; then
    echo "❌ OpenClaw 仓库目录缺少 package.json：$repo_path"
    return 1
  fi

  # dashboard 访问 127.0.0.1:18789 时需要已生成的 Control UI 静态资源。
  # 这和 onboard 配置面板不是一回事；不执行 onboard 也必须执行 pnpm ui:build。
  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw Control UI 构建 pnpm ui:build" 2 pnpm ui:build || exit 1
  )
}

jobs_openclaw_launchctl_kickstart_existing_gateway() {
  emulate -L zsh
  setopt null_glob

  [[ "$OSTYPE" == darwin* ]] || return 1
  command -v launchctl >/dev/null 2>&1 || return 1

  local plist=""
  local label=""
  local uid="$(id -u)"
  local restarted=1

  for plist in "$HOME"/Library/LaunchAgents/*openclaw*.plist(N); do
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || plutil -extract Label raw "$plist" 2>/dev/null || true)"
    [[ -n "$label" ]] || continue

    echo "🔄 尝试重启已有 OpenClaw LaunchAgent：$label"
    if launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1; then
      echo "✅ 已通过 launchctl kickstart 重启：$label"
      restarted=0
    else
      echo "⚠️  launchctl kickstart 失败：$label"
    fi
  done

  return $restarted
}

jobs_openclaw_refresh_gateway_service() {
  emulate -L zsh

  local repo_path="$1"

  if jobs_openclaw_skip_gateway_restart_enabled; then
    echo "⏭️  已设置 JOBS_OPENCLAW_SKIP_GATEWAY_RESTART=1，跳过 Gateway 服务重装/重启"
    return 0
  fi

  if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
    echo "❌ OpenClaw 仓库目录不存在，无法刷新 Gateway 服务：$repo_path"
    return 1
  fi

  if [[ ! -f "$repo_path/package.json" ]]; then
    echo "❌ OpenClaw 仓库目录缺少 package.json：$repo_path"
    return 1
  fi

  # 注意：这里使用 gateway install/restart，而不是 onboard --install-daemon。
  # 前者只刷新/重启 Gateway 服务，不会打开 OpenClaw setup 配置面板；
  # 作用是让 127.0.0.1:18789 的 Gateway 进程重新读取刚构建好的 dist/control-ui。
  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw Gateway 服务刷新 pnpm openclaw gateway install --force" 1 pnpm openclaw gateway install --force || exit 1
    jobs_openclaw_retry_run "OpenClaw Gateway 服务重启 pnpm openclaw gateway restart" 1 pnpm openclaw gateway restart || exit 1
  ) && return 0

  echo "⚠️  pnpm openclaw gateway install/restart 失败，尝试对已有 LaunchAgent 做 kickstart"
  if jobs_openclaw_launchctl_kickstart_existing_gateway; then
    return 0
  fi

  echo "⚠️  未能自动重启 Gateway。Control UI 已构建，但 18789 可能仍由旧 Gateway 进程提供服务。"
  print -r -- "👉 可手动执行：cd "$repo_path" && pnpm openclaw gateway install --force && pnpm openclaw gateway restart"
  return 1
}

jobs_openclaw_skip_gateway_restart_enabled() {
  emulate -L zsh

  case "${JOBS_OPENCLAW_SKIP_GATEWAY_RESTART:-0}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
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

jobs_openclaw_gateway_status_ok() {
  emulate -L zsh

  local repo_path="$1"

  if [[ -n "$repo_path" && -d "$repo_path" ]] && command -v pnpm >/dev/null 2>&1; then
    if (
      cd "$repo_path" || exit 1
      pnpm openclaw gateway status >/dev/null 2>&1
    ); then
      echo "✅ OpenClaw Gateway status 正常，跳过 onboard"
      return 0
    fi
  fi

  if command -v openclaw >/dev/null 2>&1; then
    if openclaw gateway status >/dev/null 2>&1; then
      echo "✅ OpenClaw Gateway status 正常，跳过 onboard"
      return 0
    fi
  fi

  return 1
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


jobs_openclaw_prompt_open_dashboard() {
  emulate -L zsh

  local repo_path="$1"
  local answer=""

  echo ""
  if [[ ! -t 0 ]]; then
    echo "👉 如需打开控制台，手动执行：openclaw dashboard"
    return 0
  fi

  read -r "?👉 回车打开 OpenClaw 控制台；输入任意字符跳过: " answer
  if [[ -n "$answer" ]]; then
    echo "⏭️  已跳过打开 OpenClaw 控制台"
    return 0
  fi

  echo "🚀 正在打开 OpenClaw 控制台..."
  if command -v openclaw >/dev/null 2>&1; then
    openclaw dashboard
    return $?
  fi

  if command -v pnpm >/dev/null 2>&1 && [[ -n "$repo_path" && -d "$repo_path" ]]; then
    (
      cd "$repo_path" || exit 1
      pnpm openclaw dashboard
    )
    return $?
  fi

  echo "❌ 找不到 openclaw / pnpm，无法打开 OpenClaw 控制台"
  return 1
}

jobs_openclaw_onboard_marker_exists() {
  emulate -L zsh

  local repo_path="$1"

  [[ -f "$JOBS_OPENCLAW_ONBOARD_MARKER_FILE" ]] || return 1
  grep -Fqx "repo_path=$repo_path" "$JOBS_OPENCLAW_ONBOARD_MARKER_FILE" 2>/dev/null
}

jobs_openclaw_write_onboard_marker() {
  emulate -L zsh

  local repo_path="$1"

  mkdir -p "${JOBS_OPENCLAW_ONBOARD_MARKER_FILE:h}" 2>/dev/null || true
  {
    print -r -- "repo_path=$repo_path"
    print -r -- "completed_at=$(date '+%Y-%m-%d %H:%M:%S %z')"
  } >| "$JOBS_OPENCLAW_ONBOARD_MARKER_FILE" 2>/dev/null || true
}

jobs_openclaw_force_onboard_enabled() {
  emulate -L zsh

  case "${JOBS_OPENCLAW_FORCE_ONBOARD:-0}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

jobs_openclaw_onboard_if_needed() {
  emulate -L zsh

  local repo_path="$1"

  # 这一步只做状态判断，不再默认进入 OpenClaw 的交互式 setup / onboard 面板。
  # 原因：pnpm openclaw onboard --install-daemon 是强交互命令，检测不到 Gateway / daemon 时会弹出
  # Security disclaimer、模型/provider、API key 等配置流程；update 不能替用户反复打开这个面板。
  if jobs_openclaw_gateway_status_ok "$repo_path"; then
    return 0
  fi

  if jobs_openclaw_daemon_seems_ok; then
    echo "✅ OpenClaw daemon 看起来正常，跳过 onboard"
    return 0
  fi

  if jobs_openclaw_onboard_marker_exists "$repo_path"; then
    echo "✅ 已记录 OpenClaw onboard 完成过，跳过交互配置"
    return 0
  fi

  if ! jobs_openclaw_force_onboard_enabled; then
    echo "⏭️  未检测到 OpenClaw Gateway / daemon 完成状态；按当前策略，不自动打开 OpenClaw 配置面板。"
    print -r -- "👉 真要重配时，手动执行：cd \"$repo_path\" && pnpm openclaw onboard --install-daemon"
    echo "👉 或临时允许本脚本执行一次：JOBS_OPENCLAW_FORCE_ONBOARD=1 update"
    return 0
  fi

  echo "⚠️  已开启 JOBS_OPENCLAW_FORCE_ONBOARD=1，本次才会进入 OpenClaw onboard 配置面板"
  (
    cd "$repo_path" || exit 1
    jobs_openclaw_retry_run "OpenClaw onboard / install daemon" 1 pnpm openclaw onboard --install-daemon
  ) || return 1

  jobs_openclaw_write_onboard_marker "$repo_path"
}

jobs_update_openclaw_gateway_daemon() {
  emulate -L zsh

  local repo_path=""

  if ! jobs_openclaw_choose_repo_path; then
    echo "⚠️  跳过 OpenClaw Gateway / daemon 配置"
    return 0
  fi

  repo_path="$OPENCLAW_REPO_PATH"

  echo ""
  echo "🧩 开始同步 OpenClaw 源码、依赖、Control UI 并刷新 Gateway（不打开配置面板）：$repo_path"

  # 03 项和 04 项共用同一份 OpenClaw 本地仓库记录。
  # 先校验并同步本地源码；本项默认不再执行交互式 onboard。
  jobs_openclaw_sync_repo "$repo_path" || return 1

  jobs_openclaw_install_homebrew_if_needed || return 1
  jobs_openclaw_ensure_pnpm_by_brew || return 1

  # 先同步依赖，避免源码更新后 workspace 链接仍是旧状态。
  jobs_openclaw_sync_dependencies "$repo_path" || return 1

  # 源码模式下 Gateway 服务通常读取已构建的 runtime dist。
  # git pull 后如果不先 pnpm build，后台服务可能继续使用旧 runtime。
  jobs_openclaw_build_runtime "$repo_path" || return 1

  # 再构建 Control UI 静态资源。否则 dashboard 可能报：
  # Control UI assets not found. Build them with `pnpm ui:build`.
  # 这一步不会进入 OpenClaw setup / onboard 配置面板。
  jobs_openclaw_build_control_ui_assets "$repo_path" || return 1

  # 最后刷新 Gateway 服务，让 127.0.0.1:18789 重新读取刚构建好的 dist/control-ui。
  # 这里明确使用 gateway install/restart，不调用 onboard --install-daemon，避免打开配置面板。
  jobs_openclaw_refresh_gateway_service "$repo_path" || return 1

  # 只做只读状态检查；默认不执行 pnpm openclaw onboard --install-daemon，避免打开配置面板。
  # 如确实要由脚本执行一次配置，显式使用 JOBS_OPENCLAW_FORCE_ONBOARD=1。
  jobs_openclaw_onboard_if_needed "$repo_path" || return 1

  echo "✅ OpenClaw 源码/依赖/runtime/Control UI/Gateway 刷新完成"
  print -r -- "👉 可检查状态：cd \"$repo_path\" && pnpm openclaw gateway status"
  jobs_openclaw_prompt_open_dashboard "$repo_path"
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
  jobs_openclaw_prompt_open_dashboard "$repo_path"
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
    "$JOBS_UPDATE_OPTION_OPENCLAW_GATEWAY"
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
    "$JOBS_UPDATE_OPTION_OPENCLAW_GATEWAY")
      jobs_update_run_module "$JOBS_UPDATE_OPTION_OPENCLAW_GATEWAY" "jobs_update_openclaw_gateway_daemon"
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



# 🔥 颜色格式转换器：cor 🔥
# 用法：
# - cor                         进入交互模式，可连续输入颜色值
# - cor '#D2D4DE'               转换单个颜色，# 开头建议加引号
# - cor 'rgba(210,212,222,0.5)' 转换 rgba，括号内容建议加引号
#
# 注意：这里不要再用 bash heredoc 包一层脚本。
# heredoc 会占用 bash 的 stdin，导致交互模式里的 read 读不到键盘输入。
jobs_cor_supports_truecolor() {
  emulate -L zsh
  [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]
}

jobs_cor_title_color() {
  emulate -L zsh

  local esc=$'\033'
  if jobs_cor_supports_truecolor; then
    printf "%s" "${esc}[38;2;210;212;222m"
  else
    printf "%s" "${esc}[37m"
  fi
}

jobs_cor_to_hex() {
  emulate -L zsh
  printf "%02X" "$1"
}

jobs_cor_hex_to_dec() {
  emulate -L zsh
  printf "%d" "$(( 16#$1 ))"
}

jobs_cor_alpha_float_to_255() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%d", (v * 255) + 0.5) }'
}

jobs_cor_alpha_255_to_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { printf("%.2f", v / 255) }'
}

jobs_cor_clamp_alpha_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%.2f", v) }'
}

jobs_cor_sanitize_input() {
  emulate -L zsh
  print -r -- "$1" | tr -d '[:space:]' | tr -d '"' | tr -d "'"
}

jobs_cor_upper_hex() {
  emulate -L zsh
  print -r -- "$1" | tr '[:lower:]' '[:upper:]'
}

jobs_cor_rel_luma() {
  emulate -L zsh
  awk -v r="$1" -v g="$2" -v b="$3" 'BEGIN { printf("%.0f", 0.2126 * r + 0.7152 * g + 0.0722 * b) }'
}

jobs_cor_pick_fg_code() {
  emulate -L zsh

  local l
  l="$(jobs_cor_rel_luma "$1" "$2" "$3")"
  if (( l > 186 )); then
    print -r -- "30"
  else
    print -r -- "97"
  fi
}

jobs_cor_rgb_to_ansi256() {
  emulate -L zsh

  local r="$1" g="$2" b="$3"
  if (( r == g && g == b )); then
    if (( r < 8 )); then
      print -r -- 16
      return 0
    elif (( r > 248 )); then
      print -r -- 231
      return 0
    else
      print -r -- $(( 232 + ((r - 8) * 24 / 247) ))
      return 0
    fi
  fi

  local rc=$(( r * 5 / 255 ))
  local gc=$(( g * 5 / 255 ))
  local bc=$(( b * 5 / 255 ))
  print -r -- $(( 16 + 36 * rc + 6 * gc + bc ))
}

jobs_cor_show_block() {
  emulate -L zsh

  local rr="$1" gg="$2" bb="$3" label="$4" fg idx
  fg="$(jobs_cor_pick_fg_code "$rr" "$gg" "$bb")"

  if jobs_cor_supports_truecolor; then
    printf "\033[48;2;%d;%d;%dm" "$rr" "$gg" "$bb"
  else
    idx="$(jobs_cor_rgb_to_ansi256 "$rr" "$gg" "$bb")"
    printf "\033[48;5;%sm" "$idx"
  fi

  printf "\033[%sm" "$fg"
  printf "  %-18s  " "$label"
  printf "\033[0m"
}

jobs_cor_parse_input() {
  emulate -L zsh

  local raw="$1" input hex rr gg bb aa nums R G B A A255
  input="$(jobs_cor_sanitize_input "$raw")"

  if [[ "$input" =~ '^0[xX][0-9a-fA-F]{8}$' ]]; then
    hex="${input[3,-1]}"
    hex="$(jobs_cor_upper_hex "$hex")"
    aa="${hex[1,2]}"
    rr="${hex[3,4]}"
    gg="${hex[5,6]}"
    bb="${hex[7,8]}"

    typeset -g JOBS_COR_R="$(jobs_cor_hex_to_dec "$rr")"
    typeset -g JOBS_COR_G="$(jobs_cor_hex_to_dec "$gg")"
    typeset -g JOBS_COR_B="$(jobs_cor_hex_to_dec "$bb")"
    typeset -g JOBS_COR_AA_HEX="$aa"
    typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_alpha_255_to_float "$(jobs_cor_hex_to_dec "$aa")")"
    return 0
  fi

  if [[ "$input" =~ '^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$' ]]; then
    hex="${input[2,-1]}"
    hex="$(jobs_cor_upper_hex "$hex")"
    rr="${hex[1,2]}"
    gg="${hex[3,4]}"
    bb="${hex[5,6]}"

    typeset -g JOBS_COR_R="$(jobs_cor_hex_to_dec "$rr")"
    typeset -g JOBS_COR_G="$(jobs_cor_hex_to_dec "$gg")"
    typeset -g JOBS_COR_B="$(jobs_cor_hex_to_dec "$bb")"

    if (( ${#hex} == 8 )); then
      aa="${hex[7,8]}"
      typeset -g JOBS_COR_AA_HEX="$aa"
      typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_alpha_255_to_float "$(jobs_cor_hex_to_dec "$aa")")"
    else
      typeset -g JOBS_COR_AA_HEX="FF"
      typeset -g JOBS_COR_A_FLOAT="1.00"
    fi
    return 0
  fi

  if [[ "$input" =~ '^rgba?\(' ]]; then
    nums="$(print -r -- "$input" | sed -E 's/^rgba?\(|\)$//g')"
    local -a parts
    parts=("${(@s:,:)nums}")

    R="${parts[1]:-}"
    G="${parts[2]:-}"
    B="${parts[3]:-}"
    A="${parts[4]:-1}"

    [[ -n "$R" && -n "$G" && -n "$B" ]] || return 1

    typeset -g JOBS_COR_R="${R%%.*}"
    typeset -g JOBS_COR_G="${G%%.*}"
    typeset -g JOBS_COR_B="${B%%.*}"

    if ! [[ "$JOBS_COR_R" =~ '^[0-9]+$' && "$JOBS_COR_G" =~ '^[0-9]+$' && "$JOBS_COR_B" =~ '^[0-9]+$' ]]; then
      return 1
    fi

    if (( JOBS_COR_R < 0 || JOBS_COR_R > 255 || JOBS_COR_G < 0 || JOBS_COR_G > 255 || JOBS_COR_B < 0 || JOBS_COR_B > 255 )); then
      return 1
    fi

    if ! [[ "$A" =~ '^([0-9]+([.][0-9]+)?|[.][0-9]+)$' ]]; then
      return 1
    fi

    typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_clamp_alpha_float "$A")"
    A255="$(jobs_cor_alpha_float_to_255 "$JOBS_COR_A_FLOAT")"
    typeset -g JOBS_COR_AA_HEX="$(jobs_cor_to_hex "$A255")"
    return 0
  fi

  return 1
}

jobs_cor_format_and_print_all() {
  emulate -L zsh

  local raw="$1" RR GG BB AA
  RR="$(jobs_cor_to_hex "$JOBS_COR_R")"
  GG="$(jobs_cor_to_hex "$JOBS_COR_G")"
  BB="$(jobs_cor_to_hex "$JOBS_COR_B")"
  AA="$JOBS_COR_AA_HEX"

  printf "\n\033[1m输入：%s\033[0m\n" "$raw"
  printf "%s\n" "----------------------------------------"
  printf "HEX（不透明）:  #%s%s%s\n" "$RR" "$GG" "$BB"
  printf "HEX（含透明） :  #%s%s%s%s\n" "$RR" "$GG" "$BB" "$AA"
  printf "RGB           :  rgb(%d, %d, %d)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B"
  printf "RGBA          :  rgba(%d, %d, %d, %.2f)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "$JOBS_COR_A_FLOAT"
  printf "0x 格式       :  0x%s%s%s%s\n" "$AA" "$RR" "$GG" "$BB"
  jobs_cor_show_block "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "原色 #${RR}${GG}${BB}"
  printf "\n\n"
}

jobs_cor_print_title() {
  emulate -L zsh

  local c reset=$'\033[0m'
  c="$(jobs_cor_title_color)"
  printf "%b================== 颜色格式转换器 ==================%b\n" "$c" "$reset"
  printf "%b支持：#RRGGBB / #RRGGBBAA / rgb() / rgba() / 0xAARRGGBB%b\n" "$c" "$reset"
  printf "%b输出：HEX / RGB / RGBA / 0xAARRGGBB，并显示终端色块预览%b\n" "$c" "$reset"
  printf "\n"
}

jobs_cor_convert_once() {
  emulate -L zsh

  local user_input="$1"
  if jobs_cor_parse_input "$user_input"; then
    jobs_cor_format_and_print_all "$user_input"
  else
    print -P "%F{red}❌ 无法识别：$user_input%f"
    return 1
  fi
}

jobs_cor_interactive_loop() {
  emulate -L zsh

  local user_input
  while true; do
    read -r "user_input?请输入颜色值（q 退出）： " || {
      printf "\n"
      break
    }

    [[ -z "$user_input" ]] && continue

    case "$user_input" in
      q|Q|quit|QUIT|exit|EXIT)
        print -P "%F{green}✅ 已退出 cor%f"
        break
        ;;
    esac

    if jobs_cor_parse_input "$user_input"; then
      jobs_cor_format_and_print_all "$user_input"
    else
      print -P "%F{red}❌ 无法识别：$user_input%f"
      print -r -- "示例：#D2D4DE、#D2D4DE80、rgb(210,212,222)、rgba(210,212,222,0.5)、0x80D2D4DE"
      printf "\n"
    fi
  done
}

cor() {
  emulate -L zsh

  jobs_cor_print_title

  if (( $# > 0 )); then
    local failed=0 user_input
    for user_input in "$@"; do
      jobs_cor_convert_once "$user_input" || failed=1
    done
    return "$failed"
  fi

  jobs_cor_interactive_loop
}


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


# ================================== 时间戳转换 ==================================
# ts
# 交互式输入 Unix 时间戳，并输出完整时间：年、月、日、时、分、秒、周几、时区。
# 时区选择：直接回车使用当前系统时区；输入任意字符后用 fzf 选择其他时区。
# 自动识别常见时间戳精度：秒 / 毫秒 / 微秒 / 纳秒。
unalias ts 2>/dev/null
ts() {
  emulate -L zsh
  setopt no_nomatch

  local input tz_trigger selected_tz

  if ! command -v python3 >/dev/null 2>&1; then
    print -P "%F{red}❌ 未检测到 python3，无法转换时间戳%f"
    return 1
  fi

  _jobs_ts_read_line() {
    emulate -L zsh

    local prompt="$1"
    local ch line=""

    printf "%s" "$prompt" > /dev/tty

    while true; do
      if ! IFS= read -r -s -k 1 ch < /dev/tty; then
        printf "\n" > /dev/tty
        return 130
      fi

      case "$ch" in
        $'\e')
          printf "\n" > /dev/tty
          return 130
          ;;
        $'\n'|$'\r')
          printf "\n" > /dev/tty
          REPLY="$line"
          return 0
          ;;
        $'\177'|$'\b')
          if [[ -n "$line" ]]; then
            line="${line[1,-2]}"
            printf '\b \b' > /dev/tty
          fi
          ;;
        $'\003'|$'\004')
          printf "\n" > /dev/tty
          return 130
          ;;
        *)
          line+="$ch"
          printf "%s" "$ch" > /dev/tty
          ;;
      esac
    done
  }

  while true; do
    if ! _jobs_ts_read_line "请输入时间戳（Esc 退出）："; then
      print -P "%F{yellow}已取消%f"
      return 130
    fi

    input="$REPLY"

    if [[ -n "${input//[[:space:]]/}" ]]; then
      break
    fi

    print -P "%F{red}❌ 时间戳不能为空%f"
  done

  if ! _jobs_ts_read_line "时区：直接回车使用当前时区；输入任意字符后用 fzf 选择其他时区（Esc 退出）："; then
    print -P "%F{yellow}已取消%f"
    return 130
  fi

  tz_trigger="$REPLY"

  if [[ -n "${tz_trigger//[[:space:]]/}" ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      print -P "%F{red}❌ 未检测到 fzf。先安装：brew install fzf%f"
      return 1
    fi

    selected_tz="$(
      python3 - <<'PY' | fzf --prompt='选择时区：' --height=60% --border
import os

zones = set()
try:
    from zoneinfo import available_timezones
    zones.update(available_timezones())
except Exception:
    base = "/usr/share/zoneinfo"
    skip_dirs = {"posix", "right", "SystemV", "Etc"}
    skip_files = {"localtime", "posixrules", "leapseconds", "tzdata.zi", "zone.tab", "zone1970.tab", "iso3166.tab"}
    if os.path.isdir(base):
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in skip_dirs and not d.startswith(".")]
            for name in files:
                if name in skip_files or name.startswith("."):
                    continue
                full_path = os.path.join(root, name)
                rel_path = os.path.relpath(full_path, base)
                if os.path.sep in rel_path:
                    zones.add(rel_path.replace(os.path.sep, "/"))

for zone in sorted(zones):
    print(zone)
PY
    )"

    if [[ -z "$selected_tz" ]]; then
      print -P "%F{yellow}⚠️  未选择时区，已取消%f"
      return 130
    fi
  fi

  python3 - "$input" "$selected_tz" <<'PY'
import os
import sys
import time
from decimal import Decimal, InvalidOperation
from datetime import datetime

try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def local_zone_name(dt):
    for path in ("/etc/localtime", "/var/db/timezone/localtime"):
        try:
            real_path = os.path.realpath(path)
        except Exception:
            continue
        marker = "/zoneinfo/"
        if marker in real_path:
            return real_path.split(marker, 1)[1]
    return os.environ.get("TZ") or dt.tzname() or "当前系统时区"


def parse_timestamp(raw):
    value = raw.strip()
    if value.startswith("@"):
        value = value[1:]

    try:
        number = Decimal(value)
    except InvalidOperation:
        raise ValueError("时间戳格式不正确，只支持数字，例如 1715400000 或 1715400000000")

    plain_digits = value.lstrip("+-")
    unit = "秒"
    seconds = number

    if "." not in plain_digits and "e" not in plain_digits.lower():
        digits = plain_digits.lstrip("0") or "0"
        length = len(digits)
        if length >= 19:
            seconds = number / Decimal(1_000_000_000)
            unit = "纳秒"
        elif length >= 16:
            seconds = number / Decimal(1_000_000)
            unit = "微秒"
        elif length >= 13:
            seconds = number / Decimal(1_000)
            unit = "毫秒"

    return float(seconds), unit


def format_offset(dt):
    offset = dt.strftime("%z")
    if len(offset) == 5:
        return f"{offset[:3]}:{offset[3:]}"
    return offset or "未知偏移"


raw = sys.argv[1]
zone_name = sys.argv[2] if len(sys.argv) > 2 else ""

try:
    seconds, unit = parse_timestamp(raw)

    if zone_name:
        if ZoneInfo is not None:
            dt = datetime.fromtimestamp(seconds, ZoneInfo(zone_name))
        elif hasattr(time, "tzset"):
            os.environ["TZ"] = zone_name
            time.tzset()
            dt = datetime.fromtimestamp(seconds).astimezone()
        else:
            raise RuntimeError("当前 python3 不支持指定时区转换")
        zone_label = zone_name
    else:
        dt = datetime.fromtimestamp(seconds).astimezone()
        zone_label = local_zone_name(dt)

    print(f"时间戳：{raw.strip()}（识别为：{unit}）")
    print(f"完整时间：{dt.year:04d}年{dt.month:02d}月{dt.day:02d}日 {dt.hour:02d}:{dt.minute:02d}:{dt.second:02d} {WEEKDAYS[dt.weekday()]}")
    print(f"时区：{zone_label}（UTC{format_offset(dt)}，{dt.tzname() or '未知缩写'}）")
except Exception as exc:
    print(f"❌ 转换失败：{exc}", file=sys.stderr)
    sys.exit(1)
PY
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
