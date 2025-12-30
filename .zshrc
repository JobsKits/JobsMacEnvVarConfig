source "$HOME/.bash_profile"
source "$HOME/.bashrc"
source "$HOME/.profile"
# -------------------- Oh My Zsh 基本设置 --------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# -------------------- jenv（启动时安全初始化） --------------------
# OPT: 仅在安装了 jenv 的情况下初始化，避免新机/容器报错
if command -v jenv >/dev/null 2>&1; then
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
fi

# -------------------- 通用：try_run --------------------
try_run() {
  local cmd="$1"; shift
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ [$cmd] detected, running: $*"
    eval "$@"
  else
    echo "⚠️  [$cmd] not installed, skip: $*"
  fi
}

# -------------------- save（手动用，不再自启动） --------------------
# OPT: 不再在 shell 启动时自动运行，避免每个新 shell 变慢/重复 source。
save() {
  local files=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
    # OPT: 避免重复 source oh-my-zsh 主文件；如需刷新插件，用 rb 重启更干净
    # "$HOME/.oh-my-zsh/oh-my-zsh.sh"
  )
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      # shellcheck disable=SC1090
      source "$file"
      echo -e "\033[1;32m✅ 已加载配置文件：file://$file\033[0m"
    else
      echo -e "\033[1;33m⚠️ 未找到配置文件：file://$file\033[0m"
    fi
  done
  echo -e "\n📎 ⌘Command + 点击路径可打开对应文件（macOS Terminal 支持）"
}

# -------------------- update（自检后再跑） --------------------
update() {
  try_run "flutter" "flutter upgrade"
  try_run "brew" "brew update && brew upgrade && brew cleanup && brew doctor && brew -v"
  try_run "dart" "dart pub global activate fvm"
  try_run "gem" "gem update && gem clean"
  try_run "pod" "pod repo update --verbose"
  try_run "rbenv" "brew upgrade rbenv ruby-build"
}

# -------------------- flutter() 重载（优先 FVM） --------------------
flutter() {
  emulate -L zsh
  setopt no_aliases

  # 向上寻找项目根：.fvmrc 或 .fvm/flutter_sdk
  local d="$PWD"
  local root=""

  while [[ "$d" != "/" ]]; do
    if [[ -f "$d/.fvmrc" || -x "$d/.fvm/flutter_sdk/bin/flutter" || -f "$d/.fvm/fvm_config.json" ]]; then
      root="$d"
      break
    fi
    d="${d:h}"
  done

  # 1) 最可靠：如果项目已有 .fvm/flutter_sdk，直接用它（不依赖系统 flutter，也不依赖 fvm 命令）
  if [[ -n "$root" && -x "$root/.fvm/flutter_sdk/bin/flutter" ]]; then
    command "$root/.fvm/flutter_sdk/bin/flutter" "$@"
    return $?
  fi

  # 2) 项目有 .fvmrc / fvm_config.json：走 fvm flutter（读取项目配置）
  if [[ -n "$root" && ( -f "$root/.fvmrc" || -f "$root/.fvm/fvm_config.json" ) ]]; then
    if command -v fvm >/dev/null 2>&1; then
      command fvm flutter "$@"
      return $?
    fi
    print -u2 "✖ 检测到 FVM 项目，但找不到 fvm 命令。请先安装 fvm。"
    return 127
  fi

  # 3) 非 FVM 项目：走系统 flutter（若存在）
  if command -v flutter >/dev/null 2>&1; then
    command flutter "$@"
    return $?
  fi

  print -u2 "✖ flutter: command not found（未安装系统 Flutter，且当前目录不在 FVM 项目内）"
  return 127
}


# -------------------- fvm 修复（与 Dart 内核匹配） --------------------
fixfvm() {
  echo "🔍 修复 fvm 与 Dart SDK 的内核版本不匹配..."
  dart pub global deactivate fvm || true
  rm -rf ~/.pub-cache/bin/fvm* ~/.pub-cache/global_packages/fvm
  dart pub global activate fvm
  hash -r
  echo "✅ fvm 已重新安装并与当前 Dart SDK 匹配"
}

# -------------------- 版本检查 --------------------
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

# -------------------- 快捷命令 --------------------
rb() { exec -l "$SHELL"; }               # OPT: 用 login shell 重启
a()  { open "$HOME/.bash_profile"; }
b()  { open "$HOME/.zshrc"; }
i()  { open -a Simulator; }
d()  { cd /Users/jobs/Documents/Github/flutter_tiyu_app || return 1; }

check(){
  echo; java -version; echo
  echo "JAVA_HOME=$JAVA_HOME"; echo
  fvm use 3.24.5 --force
  flutter doctor -v
}

# -------------------- JDK17 锁定到项目（c） --------------------
c() {
  local project_dir="${1:-/Users/jobs/Documents/Github/flutter_tiyu_app}"
  local want_major="17"
  [[ -d "$project_dir" ]] || { echo "❌ 项目目录不存在：$project_dir"; return 1; }
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

  typeset -f check >/dev/null && check
}

# -------------------- 解析真实 Flutter 执行器（避免函数误判） --------------------
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

# -------------------- 构建前置（智能 + 可选参数 + 强校验执行器） --------------------
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

# -------------------- Flutter 项目识别 & 目录选择 --------------------
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

# -------------------- APK / IPA 构建（保持你的逻辑） --------------------
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
  # OPT: 去掉未定义的 err；全部走 echo >&2，并返回非零而不是 exit，便于上层控制
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

# ============================== 查看本机局域网 IP(LAN) 与 外网 IP(WAN) ==============================
ip() {
  # ============================== 基础信息 ==============================
  local iface="en0"   # 常见：Wi-Fi 是 en0；如果你用网线可能是 en1/其它
  local lan_ip=""
  local wan_ip=""

  # ============================== 获取 LAN IP ==============================
  lan_ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"

  # 如果 en0 没拿到，尝试从当前默认路由对应网卡拿一次（更稳一点）
  if [[ -z "$lan_ip" ]]; then
    local default_iface
    default_iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
    if [[ -n "$default_iface" ]]; then
      lan_ip="$(ipconfig getifaddr "$default_iface" 2>/dev/null)"
      iface="$default_iface"
    fi
  fi

  # ============================== 获取 WAN IP ==============================
  # ifconfig.me 有时会抽风；这里再加一个兜底
  wan_ip="$(curl -s --max-time 5 ifconfig.me 2>/dev/null)"
  if [[ -z "$wan_ip" ]]; then
    wan_ip="$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)"
  fi

  # ============================== 输出 ==============================
  if [[ -n "$lan_ip" ]]; then
    echo "局域网 IP（LAN / 网卡 ${iface}）：${lan_ip}"
  else
    echo "局域网 IP（LAN）：未获取到（可能未连接网络，或网卡不是 en0/en1）"
  fi

  if [[ -n "$wan_ip" ]]; then
    echo "外网 IP（WAN / 公网 IP）：${wan_ip}"
  else
    echo "外网 IP（WAN / 公网 IP）：未获取到（检查网络或 DNS，或接口被墙/超时）"
  fi
}

# ================================== 内部工具：选择 JSON 文件 ==================================
_qt_select_json() {
  local files file raw

  # 如果传了参数就优先用参数（虽然目前 qt 不传，但保留以防以后复用）
  if [[ -n "$1" ]]; then
    local candidate="$1"
    # 展开 ~ 等（zsh 特性）
    candidate=${~candidate}
    if [[ -f "$candidate" ]]; then
      REPLY="$candidate"
      return 0
    else
      echo "⚠️ 找不到文件: $candidate" >&2
      # 不直接 return，继续走自动扫描 + 手动输入流程
    fi
  fi

  # 递归查找当前目录下的 *.json
  raw=$(find . -type f -name '*.json' -print 2>/dev/null)

  if [[ -n "$raw" ]]; then
    # 找到了至少一个
    local -a files
    files=("${(@f)${raw}}")

    if (( ${#files[@]} == 1 )); then
      # ✅ 只有一个 JSON，直接用，不要动 fzf
      file="${files[1]}"
    else
      # 多于 1 个，才有必要用 fzf 选
      if command -v fzf >/dev/null 2>&1; then
        file=$(printf '%s\n' "${files[@]}" | fzf \
          --prompt="选择 JSON 文件> " \
          --header="扫描到 ${#files[@]} 个 JSON 文件，↑↓ 选择，回车确认")
        [[ -z "$file" ]] && return 1
      else
        # 没有 fzf，又不止一个文件，只能报错+列表
        echo "❌ 找到多个 JSON 文件，但未安装 fzf，无法交互选择" >&2
        printf '%s\n' "${files[@]}"
        return 1
      fi
    fi

    REPLY="$file"
    return 0
  fi

  # 走到这里说明：当前目录及子目录里一个 *.json 都没找到
  # 改为循环询问用户手动输入路径，直到正确或退出
  while true; do
    echo -n "❓ 未找到任何 *.json，请手动输入 JSON 文件路径（或输入 q 退出）："
    local input
    read -r input

    # 直接回车就继续问
    if [[ -z "$input" ]]; then
      continue
    fi

    # 用户主动退出
    if [[ "$input" == "q" || "$input" == "Q" ]]; then
      echo "🚪 已取消"
      return 1
    fi

    # 展开 ~ 等
    input=${~input}

    if [[ -f "$input" ]]; then
      REPLY="$input"
      return 0
    else
      echo "❌ 仍然找不到文件: $input" >&2
    fi
  done
}

# ================================== 公共：检查 quicktype ==================================
_qt_require_quicktype() {
  if ! command -v quicktype >/dev/null 2>&1; then
    echo "❌ 未找到 quicktype 命令，请先安装：npm i -g quicktype" >&2
    return 1
  fi
}

# ================================== 主命令：qt（Swift / Dart） ==================================
# 用法：
#   qt          # 交互选择语言（swift/dart）+ 自动扫描 json（1 个直用、多于 1 个用 fzf）
#   qt swift    # 固定 swift，自动扫描 json
#   qt dart     # 固定 dart，自动扫描 json
qt() {
  local lang

  # 1️⃣ 解析语言参数 / 交互式选择
  if [[ -z "$1" ]]; then
    # 没有参数：用 fzf 或菜单 选择语言
    if command -v fzf >/dev/null 2>&1; then
      lang=$(printf '%s\n' swift dart | fzf \
        --prompt="选择输出语言> " \
        --header="quicktype 目标语言（ESC 取消）")
      if [[ -z "$lang" ]]; then
        echo "🚪 已取消"
        return 1
      fi
    else
      # 无 fzf：用简单菜单
      while true; do
        echo "请选择输出语言："
        echo "  1) swift"
        echo "  2) dart"
        printf "输入序号或名称（默认 1 / swift，输入 q 退出）："
        local ans
        read -r ans
        case "$ans" in
          ""|1|swift|Swift|SWIFT)
            lang="swift"
            break
            ;;
          2|dart|Dart|DART)
            lang="dart"
            break
            ;;
          q|Q)
            echo "🚪 已取消"
            return 1
            ;;
          *)
            echo "❌ 无效输入，请重试"
            ;;
        esac
      done
    fi
  else
    # 有参数：只接受 swift / dart，其他一律报错
    case "$1" in
      swift|Swift|SWIFT)
        lang="swift"
        ;;
      dart|Dart|DART)
        lang="dart"
        ;;
      *)
        echo "❌ 不支持的参数: $1（只支持：swift / dart）" >&2
        return 1
        ;;
    esac
    shift
  fi

  # 现在只允许 0 个额外参数，彻底砍掉 “qt path/to/a.json” 这种用法
  if [[ -n "$1" ]]; then
    echo "❌ 不支持的额外参数: $*（现在只支持：qt / qt swift / qt dart）" >&2
    return 1
  fi

  # 2️⃣ 检查 quicktype 是否存在
  _qt_require_quicktype || return 1

  # 3️⃣ 选择 JSON 文件（自动扫描：1 个直用，多于 1 个 fzf；没有则手动输入）
  local json_file
  if ! _qt_select_json; then
    return 1
  fi
  json_file="$REPLY"

  # 4️⃣ 计算输出文件名：和 JSON 同目录、同主名，不同后缀
  local dir base ext out_file
  dir="${json_file:h}"
  base="${json_file:t:r}"

  case "$lang" in
    swift) ext="swift" ;;
    dart)  ext="dart"  ;;
    *)
      echo "❌ 理论上不会到这里：未知语言 $lang" >&2
      return 1
      ;;
  esac

  out_file="${dir}/${base}.${ext}"

  echo "📝 JSON:   $json_file"
  echo "💡 语言:   $lang"
  echo "🎯 输出:   $out_file"

  # 5️⃣ 组装 quicktype 命令
  local -a cmd
  cmd=(quicktype "$json_file" --lang "$lang" -o "$out_file")

  case "$lang" in
    swift)
      # Swift：关掉 init & CodingKeys，生成更干净的模型
      cmd+=(--no-initializers --no-coding-keys)
      ;;
    dart)
      # Dart 先默认；后面你要接 json_serializable / freezed 再调参数
      ;;
  esac

  echo "⚙️ 执行: ${cmd[*]}"
  "${cmd[@]}"
}

# -------------------- 其它工具（保持不变） --------------------
alias n='touch'

x() {
  local _raw _dir _count=0
  print -n "👉 请拖入目录或输入路径（q 退出）： "; read -r _raw || { echo "❌ 读取输入失败"; return 1; }
  [[ -z "$_raw" || "$_raw" == [Qq] ]] && { echo "🙆 已退出"; return 0; }
  _raw="${_raw#"${_raw%%[![:space:]]*}"}"; _raw="${_raw%"${_raw##*[![:space:]]}"}"
  _dir="${(Q)_raw}"; _dir="${_dir%/}"; _dir=${~_dir}
  [[ -d "$_dir" ]] || { echo "❌ 目录不存在：$_dir"; return 1; }
  echo "🔎 目标目录：$_dir"; echo "🚀 正在赋予可执行权限（.sh / .command）..."
  while IFS= read -r -d '' f; do
    if chmod +x "$f"; then ((_count++)); echo "✅ 已处理：$f"; else echo "⚠️  失败：$f"; fi
  done < <(find "$_dir" -type f \( -name '*.sh' -o -name '*.command' \) -print0)
  (( _count == 0 )) && echo "ℹ️  未发现 .sh 或 .command 文件。" || echo "✔ 完成，共处理 ${_count} 个文件。"
}

cor() {
  emulate -L zsh; set +x +v; unsetopt XTRACE VERBOSE
  : "${TERM:=xterm-256color}"; local COR_MODE="${COR_MODE:-auto}"
  supports_truecolor() {
    case "$COR_MODE" in truecolor) return 0;; 256) return 1;; esac
    [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]] && return 0
    case "${TERM_PROGRAM:-}${TERM:-}" in *iTerm*|*WezTerm*|*Ghostty*|*kitty*|*xterm-kitty*|*Windows_Terminal*) return 0;; esac
    [[ "${TERM:-}" == *-truecolor || "${TERM:-}" == *direct ]] && return 0
    return 1
  }
  to_hex() { printf "%02X" "$1"; }
  alpha_f_to_255() { awk 'BEGIN{v='"$1"'; if(v<0)v=0;if(v>1)v=1; printf("%d",(v*255)+0.5)}'; }
  alpha_255_to_f() { awk 'BEGIN{printf("%.2f",'"$1"'/255)}'; }
  sanitize() { echo "$1" | tr -d '[:space:]' | tr -d '"' | tr -d "'"; }
  upper_hex() { echo "$1" | tr '[:lower:]' '[:upper:]'; }
  rel_luma() { awk 'BEGIN{r='"$1"';g='"$2"';b='"$3"'; printf("%.0f",0.2126*r+0.7152*g+0.0722*b)}'; }
  pick_fg() { local l; l=$(rel_luma "$1" "$2" "$3"); (( l > 186 )) && echo 30 || echo 97; }
  rgb_to_ansi256() { local r=$1 g=$2 b=$3
    if (( r==g && g==b )); then
      if   (( r < 8 )); then echo 16
      elif (( r > 248 )); then echo 231
      else echo $((232 + ( (r-8) * 24 / 247 ))); fi; return
    fi
    local rc=$(( (r * 5) / 255 )) gc=$(( (g * 5) / 255 )) bc=$(( (b * 5) / 255 ))
    echo $(( 16 + 36*rc + 6*gc + bc ))
  }
  show_block() {
    local rr=$1 gg=$2 bb=$3 label=$4 fg; fg=$(pick_fg "$rr" "$gg" "$bb")
    if supports_truecolor; then printf "\e[48;2;%d;%d;%dm" "$rr" "$gg" "$bb"
    else printf "\e[48;5;%sm" "$(rgb_to_ansi256 "$rr" "$gg" "$bb")"; fi
    printf "\e[%sm  %-18s  \e[0m" "$fg" "$label"
  }
  local r g b a_float aa_hex
  parse() {
    local raw="$1" input rr gg bb aa; input=$(sanitize "$raw")
    if [[ "$input" == 0x???????? ]]; then
      local hex="${input:2}"; hex=$(upper_hex "$hex")
      aa=${hex:0:2}; rr=${hex:2:2}; gg=${hex:4:2}; bb=${hex:6:2}
      r=$((16#$rr)); g=$((16#$gg)); b=$((16#$bb)); aa_hex="$aa"; a_float=$(alpha_255_to_f $((16#$aa))); return 0
    fi
    if [[ "$input" == \#???????? ]]; then
      local hex="${input:1}"; hex=$(upper_hex "$hex")
      rr=${hex:0:2}; gg=${hex:2:2}; bb=${hex:4:2}; aa=${hex:6:2}
      r=$((16#$rr)); g=$((16#$gg)); b=$((16#$bb)); aa_hex="$aa"; a_float=$(alpha_255_to_f $((16#$aa))); return 0
    fi
    if [[ "$input" == \#?????? ]]; then
      local hex="${input:1}"; hex=$(upper_hex "$hex")
      rr=${hex:0:2}; gg=${hex:2:2}; bb=${hex:4:2}
      r=$((16#$rr)); g=$((16#$gg)); b=$((16#$bb)); aa_hex="FF"; a_float="1.00"; return 0
    fi
    if [[ "$input" == rgb\(* || "$input" == rgba\(* ]]; then
      local nums; nums=$(echo "$input" | sed -E 's/^rgba?\(|\)$//g')
      local R G B A; IFS=',' read -r R G B A <<<"$nums"
      r=${R%%.*}; g=${G%%.*}; b=${B%%.*}; [[ -z "$A" ]] && A="1"
      a_float=$(awk 'BEGIN{v='"$A"'; if(v<0)v=0;if(v>1)v=1; printf("%.2f",v)}')
      aa_hex=$(to_hex "$(alpha_f_to_255 "$a_float")"); return 0
    fi
    return 1
  }
  echo "🎨 颜色查看器：支持 #RRGGBB[AA] / 0xAARRGGBB / rgb / rgba"
  echo "ℹ️  这里只输入颜色本体"
  echo "🔗 在线取色器：https://photokit.com/colors/color-picker/?lang=zh"
  while true; do
    echo
    builtin read -r "inp?请输入颜色值（q 退出）： " < /dev/tty
    [[ "$inp" == [Qq] ]] && { echo "✅ 已退出"; break; }
    [[ -z "$inp" ]] && continue
    if parse "$inp"; then
      local RR=$(to_hex "$r") GG=$(to_hex "$g") BB=$(to_hex "$b") AA="$aa_hex"
      echo; echo "----------------------------------------"
      echo "HEX（不透明）:  #${RR}${GG}${BB}"
      echo "HEX（含透明） :  #${RR}${GG}${BB}${AA}"
      echo "RGB           :  rgb(${r}, ${g}, ${b})"
      echo "RGBA          :  rgba(${r}, ${g}, ${b}, $(printf '%.2f' "$a_float"))"
      echo "0x 格式       :  0x${AA}${RR}${GG}${BB}"
      show_block "$r" "$g" "$b" "原色 #${RR}${GG}${BB}"; echo
    else
      echo "❌ 无法识别：$inp"
    fi
  done
}
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# >>> homebrew_env >>>
eval "$(/opt/homebrew/bin/brew shellenv)"
# <<< homebrew_env <<<

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f /Users/mac/.dart-cli-completion/zsh-config.zsh ]] && . /Users/mac/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]

