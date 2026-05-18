#!/bin/zsh

set -u
set -o pipefail
setopt NO_NOMATCH

# ============================================================
# update.command - macOS 开发环境升级维护
# ============================================================
# 原则：install.command 负责安装过的内容，update.command 必须体现并提供升级 / 刷新入口。
# 说明：
# 1. 适合 .command 双击运行，也可终端执行。
# 2. 启动后先显示内置 README，并等待回车确认。
# 3. 普通升级项统一为：直接回车执行升级，输入任意字符后回车跳过。
# 4. 单项失败不阻断后续更新项，但会写入日志。
# 5. 不存在的工具不在 update 中静默安装，只提示回到 install.command 补装。
# ============================================================

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

: > "$LOG_FILE"

# ---------- 全局配置：必须与 install.command 保持同源 ----------
readonly JOBS_SOFTWARE_REPO="https://github.com/JobsKits/JobsSoftware.MacOS.git"
readonly JOBS_ENV_REPO="https://github.com/JobsKits/JobsMacEnvVarConfig.git"
readonly JOBS_WORKSPACE="${HOME}/Desktop/JobsKits"

readonly -a BREW_CASKS=(
  hammerspoon
  flutter
  trex
  vlc
)

readonly -a BREW_FORMULAE=(
  git-lfs
  gh
  codex
  nushell
  rbenv
  ruby
  node
  jenv
  openjdk
  openjdk@17
  fvm
  pnpm
  python
  python3
  fastlane
  mysql
  hugo
  yt-dlp
  ffmpeg
  go-task
  uv
  fzf
  lazygit
  onlyoffice
  dufs
)

# ---------- 彩色日志 ----------
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

# ---------- 通用基础函数 ----------
print_divider() {
  gray_echo "------------------------------------------------------------------------"
}

jobs_update_has() {
  command -v "$1" >/dev/null 2>&1
}

jobs_update_prompt_run() {
  local title="$1"
  local detail="$2"
  local answer=""

  echo ""
  warn_echo "强提示：${title}"
  warm_echo "回车=执行升级 / 刷新；输入任意字符后回车=跳过"
  gray_echo "${detail}"

  if [[ ! -t 0 ]]; then
    warn_echo "当前不是交互式终端，已跳过：${title}"
    return 1
  fi

  IFS= read -r answer

  if [[ -z "$answer" ]]; then
    return 0
  fi

  note_echo "已跳过：${title}"
  return 1
}

jobs_update_run_step() {
  local title="$1"
  shift

  echo ""
  highlight_echo "$title"
  print_divider

  "$@"
  local exit_code=$?

  if (( exit_code == 0 )); then
    success_echo "$title：完成"
  else
    warn_echo "$title：返回非 0（${exit_code}），继续后续更新项"
  fi

  return 0
}

jobs_update_run_cmd() {
  local desc="$1"
  shift

  note_echo "$desc"
  debug_echo "执行命令：$*"

  "$@"
  local exit_code=$?

  if (( exit_code == 0 )); then
    success_echo "$desc：完成"
  else
    warn_echo "$desc：失败（exit code: ${exit_code}）"
  fi

  return $exit_code
}

jobs_update_run_sh() {
  local desc="$1"
  local cmd="$2"

  note_echo "$desc"
  debug_echo "执行命令：${cmd}"

  /bin/zsh -c "$cmd"
  local exit_code=$?

  if (( exit_code == 0 )); then
    success_echo "$desc：完成"
  else
    warn_echo "$desc：失败（exit code: ${exit_code}）"
  fi

  return $exit_code
}

append_once() {
  local line="$1"
  local file="${2:-$HOME/.zshrc}"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fqx "$line" "$file"; then
    return 0
  fi

  echo "" >> "$file"
  echo "$line" >> "$file"
}

append_comment_once() {
  local comment="$1"
  local file="$2"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fqx "$comment" "$file"; then
    return 0
  fi

  echo "" >> "$file"
  echo "$comment" >> "$file"
}

find_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

setup_brew_shellenv() {
  local brew_bin="$1"
  local shellenv_line="eval \"\$(${brew_bin} shellenv)\""

  if [[ ! -x "$brew_bin" ]]; then
    warn_echo "Homebrew 可执行文件不存在或不可执行：${brew_bin}"
    return 1
  fi

  local target_file
  for target_file in "${HOME}/.zprofile" "${HOME}/.zshrc"; do
    append_comment_once "# Homebrew shellenv" "$target_file"
    append_once "$shellenv_line" "$target_file"
    success_echo "已确认 Homebrew 环境变量配置：${target_file}"
  done

  eval "$($brew_bin shellenv)"
  hash -r 2>/dev/null || true
}

require_brew_or_skip() {
  local brew_bin=""

  if brew_bin="$(find_brew_bin)"; then
    setup_brew_shellenv "$brew_bin"
    return 0
  fi

  warn_echo "未检测到 Homebrew，跳过当前更新项。请先运行 install.command 安装 Homebrew。"
  return 1
}

setup_fzf_shellenv() {
  if ! jobs_update_has brew; then
    return 0
  fi

  local fzf_base=""
  fzf_base="$(brew --prefix fzf 2>/dev/null || true)"

  if [[ -n "$fzf_base" && -d "$fzf_base" ]]; then
    append_comment_once "# fzf" "${HOME}/.zshrc"
    append_once '[ -f "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"' "${HOME}/.zshrc"
    append_once '[ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/completion.zsh"' "${HOME}/.zshrc"
    success_echo "已确认 fzf shell 配置：${HOME}/.zshrc"
  fi
}

ensure_jenv_init() {
  append_comment_once "# jenv" "${HOME}/.zshrc"
  append_once 'export PATH="$HOME/.jenv/bin:$PATH"' "${HOME}/.zshrc"
  append_once 'eval "$(jenv init -)"' "${HOME}/.zshrc"
  success_echo "已确认 jenv 初始化配置：${HOME}/.zshrc"
}

ensure_rbenv_init() {
  append_comment_once "# rbenv" "${HOME}/.zshrc"
  append_once 'eval "$(rbenv init - zsh)"' "${HOME}/.zshrc"
  success_echo "已确认 rbenv 初始化配置：${HOME}/.zshrc"
}

post_openjdk_hint() {
  warm_echo "openjdk 更新完成后，如需让系统 java 指向 Homebrew openjdk，可按需执行："
  warm_echo '  sudo ln -sfn "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk'
  warm_echo "如果使用 jenv 管理 Java，推荐执行："
  warm_echo '  jenv add "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk/Contents/Home"'
}

jobs_update_source_nvm_if_needed() {
  if jobs_update_has nvm; then
    return 0
  fi

  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    source "$nvm_dir/nvm.sh"
  fi
}

get_node_major_version() {
  if ! jobs_update_has node; then
    echo "0"
    return 0
  fi

  local version=""
  version="$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
  [[ -n "$version" ]] && echo "$version" || echo "0"
}

ensure_node_for_opencli() {
  local major=""
  major="$(get_node_major_version)"

  if (( major >= 21 )); then
    success_echo "Node.js 版本满足 OpenCLI 要求：$(node --version)"
    return 0
  fi

  warn_echo "OpenCLI 需要 Node.js >= 21，当前版本：$(node --version 2>/dev/null || echo '未安装')"
  warn_echo "update.command 不会静默安装 Node，请先通过 Homebrew / nvm 升级 Node 后重试。"
  return 1
}

jobs_update_find_external_command() {
  local command_name="$1"
  local path_dir=""
  local candidate=""
  local candidate_real=""
  local script_real=""

  if [[ -n "${SCRIPT_PATH:-}" && -e "$SCRIPT_PATH" ]]; then
    script_real="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd -P)/$(basename "$SCRIPT_PATH")"
  fi

  for path_dir in ${(s.:.)PATH}; do
    [[ -n "$path_dir" ]] || continue
    candidate="$path_dir/$command_name"
    [[ -x "$candidate" ]] || continue

    candidate_real="$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)/$(basename "$candidate")"
    [[ -n "$script_real" && "$candidate_real" == "$script_real" ]] && continue

    print -r -- "$candidate"
    return 0
  done

  return 1
}

# ---------- 内置自述 ----------
jobs_update_show_readme_and_wait() {
  clear 2>/dev/null || true

  {
    cat <<'EOFREADME'
============================================================
update.command - macOS 开发环境升级维护
============================================================

核心原则：
  install.command 安装 / 初始化过的内容，update.command 必须体现并提供升级 / 刷新入口。

本脚本会按顺序询问是否更新：
  1. Xcode Command Line Tools / softwareupdate
  2. Xcode iOS 平台组件
  3. Oh My Zsh
  4. Homebrew
  5. brew cask：由 BREW_CASKS 自动生成
  6. brew formula：由 BREW_FORMULAE 自动生成
  7. Rosetta 2 状态检查
  8. FVM / Flutter SDK / flutter doctor
  9. Node / corepack / npm 基础维护
 10. npm 全局包：quicktype
 11. npm 全局包：OpenCLI
 12. Ruby / RubyGems
 13. gem 包：cocoapods
 14. Python / pip
 15. Dart pub 缓存
 16. Git LFS 初始化与大文件参数
 17. JobsKits 仓库：JobsSoftware.MacOS、JobsMacEnvVarConfig
 18. 手动下载页：VS Code、Android Studio、Python

交互规则：
  - 直接回车：执行当前升级 / 刷新项
  - 输入任意字符后回车：跳过当前项
  - 单项失败：记录警告，继续后续项
  - 工具不存在：提示回到 install.command 补装，不在 update 中静默安装

当前 BREW_CASKS：
EOFREADME

    local pkg
    for pkg in "${BREW_CASKS[@]}"; do
      echo "  - ${pkg}"
    done

    cat <<'EOFREADME'

当前 BREW_FORMULAE：
EOFREADME

    for pkg in "${BREW_FORMULAE[@]}"; do
      echo "  - ${pkg}"
    done

    cat <<'EOFREADME'

日志路径：/tmp/update.log
============================================================
EOFREADME
  } | tee -a "$LOG_FILE"

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    echo ""
    local _answer=""
    IFS= read -r "_answer?👉 已阅读自述文件，按回车开始逐项更新；按 Ctrl+C 取消："
  fi
}

# ---------- 更新项：系统 / Xcode / Shell ----------
jobs_update_clt() {
  if ! xcode-select -p >/dev/null 2>&1; then
    warn_echo "未检测到 Xcode Command Line Tools。update.command 不负责安装，请运行 install.command 补装。"
    return 0
  fi

  success_echo "Xcode Command Line Tools 已存在：$(xcode-select -p)"

  if jobs_update_has xcodebuild; then
    jobs_update_run_cmd "接受 Xcode License" sudo xcodebuild -license accept || true
  else
    warn_echo "未检测到 xcodebuild，跳过 Xcode License 接受步骤"
  fi

  warn_echo "softwareupdate --install --all 可能安装 macOS 可用系统更新，耗时较长。"
  jobs_update_run_cmd "安装 macOS 可用软件更新" sudo softwareupdate --install --all || true
}

jobs_update_xcode_ios_platform() {
  if ! jobs_update_has xcodebuild; then
    warn_echo "未检测到 xcodebuild，无法更新 Xcode iOS 平台组件。"
    return 0
  fi

  if xcodebuild -showsdks 2>/dev/null | grep -E "iphoneos|iphonesimulator" >/dev/null 2>&1; then
    success_echo "检测到 iOS SDK，开始刷新 iOS 平台组件。"
  else
    warn_echo "未检测到 iOS SDK，将尝试通过 xcodebuild 下载 iOS 平台组件。"
  fi

  jobs_update_run_sh "清理 Xcode 缓存" 'rm -rf ~/Library/Caches/com.apple.dt.Xcode' || true
  jobs_update_run_sh "清理 CoreSimulator 缓存" 'rm -rf ~/Library/Developer/CoreSimulator/Caches' || true
  jobs_update_run_cmd "下载 / 更新 iOS 模拟器平台" xcodebuild -downloadPlatform iOS -verbose || true
}

jobs_update_oh_my_zsh() {
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    warn_echo "未检测到 Oh My Zsh。update.command 不负责安装，请运行 install.command 补装。"
    return 0
  fi

  success_echo "Oh My Zsh 已存在：${HOME}/.oh-my-zsh"

  if [[ -f "${HOME}/.oh-my-zsh/tools/upgrade.sh" ]]; then
    jobs_update_run_sh "更新 Oh My Zsh" "ZSH='${HOME}/.oh-my-zsh' '${HOME}/.oh-my-zsh/tools/upgrade.sh'" || true
  else
    warn_echo "未找到 Oh My Zsh upgrade.sh，跳过更新"
  fi
}

jobs_update_rosetta() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    info_echo "当前不是 Apple Silicon，Rosetta 2 不适用。"
    return 0
  fi

  if /usr/sbin/pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    success_echo "Rosetta 2 已安装。Rosetta 2 通常通过 macOS 系统更新维护，无独立 upgrade 命令。"
  else
    warn_echo "未检测到 Rosetta 2。update.command 不负责安装，请运行 install.command 补装。"
  fi
}

# ---------- 更新项：Homebrew ----------
jobs_update_homebrew() {
  if ! require_brew_or_skip; then
    return 0
  fi

  jobs_update_run_cmd "brew update（更新软件列表）" brew update || true
  jobs_update_run_cmd "brew upgrade（升级已安装 formula）" brew upgrade || true
  jobs_update_run_cmd "brew upgrade --cask（升级已安装 cask）" brew upgrade --cask || true
  jobs_update_run_cmd "brew cleanup（清理旧版本缓存）" brew cleanup || true
  jobs_update_run_cmd "brew doctor（检查 Homebrew 健康状态）" brew doctor || true
  jobs_update_run_cmd "brew -v（输出 Homebrew 版本）" brew -v || true
}

brew_formula_install_arg() {
  local formula_name="$1"

  case "$formula_name" in
    go-task) echo "go-task/tap/go-task" ;;
    *) echo "$formula_name" ;;
  esac
}

brew_formula_tap_name() {
  local formula_name="$1"

  case "$formula_name" in
    fvm) echo "leoafarias/fvm" ;;
    go-task) echo "go-task/tap" ;;
    *) echo "" ;;
  esac
}

brew_formula_after_update() {
  local formula_name="$1"

  case "$formula_name" in
    rbenv) ensure_rbenv_init ;;
    jenv) ensure_jenv_init ;;
    openjdk|openjdk@17) post_openjdk_hint ;;
    fzf) setup_fzf_shellenv ;;
    *) return 0 ;;
  esac
}

jobs_update_brew_formula_one() {
  local formula_name="$1"
  local install_arg=""
  local tap_name=""

  if ! require_brew_or_skip; then
    return 0
  fi

  install_arg="$(brew_formula_install_arg "$formula_name")"
  tap_name="$(brew_formula_tap_name "$formula_name")"

  if ! brew list --formula --versions "$formula_name" >/dev/null 2>&1; then
    warn_echo "未安装 brew formula：${formula_name}，跳过升级。请运行 install.command 补装。"
    return 0
  fi

  if [[ -n "$tap_name" ]]; then
    jobs_update_run_cmd "确认 Homebrew Tap：${tap_name}" brew tap "$tap_name" || true
  fi

  jobs_update_run_cmd "升级 brew formula：${formula_name}" brew upgrade "$install_arg" || true
  brew_formula_after_update "$formula_name"
}

jobs_update_brew_formulae() {
  local pkg
  for pkg in "${BREW_FORMULAE[@]}"; do
    echo ""
    highlight_echo "brew formula：${pkg}"
    jobs_update_brew_formula_one "$pkg"
  done
}

jobs_update_brew_cask_one() {
  local cask_name="$1"

  if ! require_brew_or_skip; then
    return 0
  fi

  if ! brew list --cask --versions "$cask_name" >/dev/null 2>&1; then
    warn_echo "未安装 brew cask：${cask_name}，跳过升级。请运行 install.command 补装。"
    return 0
  fi

  jobs_update_run_cmd "升级 brew cask：${cask_name}" brew upgrade --cask "$cask_name" || true
}

jobs_update_brew_casks() {
  local pkg
  for pkg in "${BREW_CASKS[@]}"; do
    echo ""
    highlight_echo "brew cask：${pkg}"
    jobs_update_brew_cask_one "$pkg"
  done
}

# ---------- 更新项：语言 / 包管理 ----------
jobs_update_fvm_flutter() {
  local external_flutter=""

  if jobs_update_has brew && brew list --formula fvm >/dev/null 2>&1; then
    jobs_update_run_cmd "升级 FVM（Homebrew）" brew upgrade fvm || true
  elif jobs_update_has dart; then
    jobs_update_run_cmd "升级 FVM（Dart pub global）" dart pub global activate fvm || true
  else
    warn_echo "未检测到 brew formula fvm 或 dart，跳过 FVM 更新"
  fi

  if external_flutter="$(jobs_update_find_external_command flutter 2>/dev/null)"; then
    jobs_update_run_cmd "Flutter upgrade" "$external_flutter" upgrade || true
    jobs_update_run_cmd "Flutter doctor" "$external_flutter" doctor -v || true
  elif jobs_update_has fvm; then
    jobs_update_run_cmd "FVM Flutter doctor" fvm flutter doctor -v || true
  else
    warn_echo "未检测到外部 flutter / fvm，跳过 Flutter SDK 更新"
  fi
}

jobs_update_node_base() {
  jobs_update_source_nvm_if_needed

  if jobs_update_has nvm; then
    jobs_update_run_cmd "nvm 安装 / 更新 LTS" nvm install --lts --reinstall-packages-from=current || true
    jobs_update_run_cmd "nvm 设置 default=LTS" nvm alias default 'lts/*' || true
    jobs_update_run_cmd "nvm use default" nvm use default || true
  elif jobs_update_has node; then
    success_echo "检测到 Node：$(node --version 2>/dev/null || true)"
    warn_echo "未检测到 nvm；Node 版本升级已由 Homebrew formula：node 更新项负责。"
  else
    warn_echo "未检测到 node / nvm，跳过 Node 基础维护"
  fi

  if jobs_update_has corepack; then
    jobs_update_run_cmd "启用 corepack" corepack enable || true
  fi

  if jobs_update_has npm; then
    jobs_update_run_cmd "升级 npm 自身" npm install -g npm@latest || true
    jobs_update_run_cmd "输出 npm 版本" npm -v || true
  fi
}

jobs_update_npm_quicktype() {
  if ! jobs_update_has npm; then
    warn_echo "npm 不存在，无法更新 quicktype。请先运行 install.command 安装 node。"
    return 0
  fi

  if npm list -g quicktype --depth=0 >/dev/null 2>&1; then
    jobs_update_run_cmd "更新 npm 全局包 quicktype" sudo npm update -g quicktype || true
  else
    warn_echo "未检测到 npm 全局包 quicktype，跳过升级。请运行 install.command 补装。"
  fi
}

jobs_update_npm_opencli() {
  if ! jobs_update_has npm; then
    warn_echo "npm 不存在，无法更新 OpenCLI。请先运行 install.command 安装 node。"
    return 0
  fi

  if ! ensure_node_for_opencli; then
    return 0
  fi

  if npm list -g @jackwener/opencli --depth=0 >/dev/null 2>&1; then
    jobs_update_run_cmd "更新 npm 全局包 OpenCLI" sudo npm install -g @jackwener/opencli@latest || true
  else
    warn_echo "未检测到 npm 全局包 OpenCLI，跳过升级。请运行 install.command 补装。"
  fi

  if jobs_update_has opencli; then
    jobs_update_run_cmd "输出 OpenCLI 版本" opencli --version || true
    warm_echo "OpenCLI 浏览器自动化还需要手动维护 Browser Bridge 扩展，可执行：opencli doctor"
  else
    warn_echo "当前 PATH 仍找不到 opencli，建议重新打开终端或检查 npm global bin。"
  fi
}

jobs_update_ruby_base() {
  if jobs_update_has rbenv; then
    ensure_rbenv_init
    jobs_update_run_cmd "rbenv rehash" rbenv rehash || true
  fi

  if jobs_update_has gem; then
    jobs_update_run_cmd "gem update --system" gem update --system || true
    jobs_update_run_cmd "gem update" gem update || true
  else
    warn_echo "未检测到 gem，跳过 RubyGems 更新"
  fi
}

jobs_update_gem_cocoapods() {
  if ! jobs_update_has gem; then
    warn_echo "gem 不存在，无法更新 cocoapods。请先确认 Ruby 环境。"
    return 0
  fi

  if gem list -i cocoapods >/dev/null 2>&1; then
    jobs_update_run_cmd "更新 gem 包 cocoapods" sudo gem update cocoapods || true
  else
    warn_echo "未检测到 gem 包 cocoapods，跳过升级。请运行 install.command 补装。"
  fi

  if jobs_update_has pod; then
    jobs_update_run_cmd "pod repo update" pod repo update || true
  fi
}

jobs_update_python_base() {
  if jobs_update_has pyenv; then
    if pyenv commands | grep -qx update; then
      jobs_update_run_cmd "pyenv update" pyenv update || true
    else
      warn_echo "pyenv-update 插件不存在，跳过 pyenv update"
    fi
    jobs_update_run_cmd "pyenv rehash" pyenv rehash || true
  fi

  if jobs_update_has pipx; then
    jobs_update_run_cmd "pipx upgrade-all" pipx upgrade-all || true
  fi

  if jobs_update_has python3; then
    jobs_update_run_cmd "python3 pip 自升级" python3 -m pip install --upgrade pip || true
  elif jobs_update_has python; then
    jobs_update_run_cmd "python pip 自升级" python -m pip install --upgrade pip || true
  else
    warn_echo "未检测到 Python，跳过 Python 更新"
  fi
}

jobs_update_pub_cache() {
  if jobs_update_has dart; then
    jobs_update_run_cmd "Dart pub global list" dart pub global list || true
    jobs_update_run_cmd "Dart pub cache repair" dart pub cache repair || true
  else
    warn_echo "未检测到 dart，跳过 Dart pub cache 更新"
  fi
}

# ---------- 更新项：Git / JobsKits / 手动下载页 ----------
jobs_update_git_lfs_init() {
  if ! jobs_update_has git; then
    warn_echo "git 不存在，无法刷新 Git LFS。请先安装 Xcode Command Line Tools 或 git。"
    return 0
  fi

  if ! git lfs version >/dev/null 2>&1; then
    warn_echo "git-lfs 不存在，无法初始化。请先运行 install.command 安装 brew formula：git-lfs。"
    return 0
  fi

  jobs_update_run_cmd "初始化 / 刷新 Git LFS" git lfs install || true
  jobs_update_run_cmd "配置 Git core.compression=0" git config --global core.compression 0 || true
  jobs_update_run_cmd "配置 Git http.postBuffer=524288000" git config --global http.postBuffer 524288000 || true
}

jobs_update_repo() {
  local repo_name="$1"
  local repo_url="$2"
  local target_dir="$3"

  if [[ -d "${target_dir}/.git" ]]; then
    jobs_update_run_sh "更新仓库：${repo_name}" "cd '${target_dir}' && git pull --ff-only" || true
    return 0
  fi

  warn_echo "未检测到仓库：${target_dir}"
  warm_echo "update.command 不负责克隆新仓库。需要补装时请运行 install.command。"
  gray_echo "仓库地址：${repo_url}"
}

jobs_update_jobs_repos() {
  if ! jobs_update_has git; then
    warn_echo "git 不存在，跳过 JobsKits 仓库更新。"
    return 0
  fi

  jobs_update_repo "JobsSoftware.MacOS" "$JOBS_SOFTWARE_REPO" "${JOBS_WORKSPACE}/JobsSoftware.MacOS"
  jobs_update_repo "JobsMacEnvVarConfig" "$JOBS_ENV_REPO" "${JOBS_WORKSPACE}/JobsMacEnvVarConfig"

  local install_script="${JOBS_WORKSPACE}/JobsMacEnvVarConfig/install.command"
  if [[ -f "$install_script" ]]; then
    jobs_update_run_cmd "确认 JobsMacEnvVarConfig/install.command 可执行权限" chmod +x "$install_script" || true
    warn_echo "不会执行 ${install_script}，避免 install.command 递归调用。"
  fi
}

open_download_page() {
  local name="$1"
  local url="$2"

  if ! jobs_update_has open; then
    warn_echo "open 命令不存在，无法打开：${name}"
    return 0
  fi

  jobs_update_run_cmd "打开 ${name} 下载 / 更新页" open "$url" || true
}

jobs_update_manual_download_pages() {
  open_download_page "Visual Studio Code" "https://code.visualstudio.com/"
  open_download_page "Android Studio" "https://developer.android.com/studio?hl=zh-cn"
  open_download_page "Python" "https://www.python.org/downloads/"
}

# ---------- 命令实现 ----------
update() {
  local ran_count=0

  if jobs_update_prompt_run "是否更新 Xcode Command Line Tools / macOS softwareupdate？" "对应 install.command：Xcode Command Line Tools。"; then
    jobs_update_run_step "Xcode Command Line Tools / softwareupdate 更新" jobs_update_clt
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 Xcode iOS 平台组件？" "对应 install.command：Xcode iOS 平台组件。"; then
    jobs_update_run_step "Xcode iOS 平台组件更新" jobs_update_xcode_ios_platform
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 Oh My Zsh？" "对应 install.command：Oh My Zsh。"; then
    jobs_update_run_step "Oh My Zsh 更新" jobs_update_oh_my_zsh
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 Homebrew？" "执行 brew update / upgrade / cask upgrade / cleanup / doctor。"; then
    jobs_update_run_step "Homebrew 更新" jobs_update_homebrew
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否逐项升级 install.command 中的 brew cask？" "覆盖 BREW_CASKS：hammerspoon / flutter / trex / vlc。"; then
    jobs_update_run_step "brew cask 批量升级" jobs_update_brew_casks
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否逐项升级 install.command 中的 brew formula？" "覆盖 BREW_FORMULAE 内所有 formula。"; then
    jobs_update_run_step "brew formula 批量升级" jobs_update_brew_formulae
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否检查 Rosetta 2？" "Rosetta 2 无独立升级命令，只检查状态并说明维护方式。"; then
    jobs_update_run_step "Rosetta 2 状态检查" jobs_update_rosetta
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 FVM / Flutter？" "覆盖 install.command 中的 brew cask：flutter 与 brew formula：fvm 的后续 SDK 维护。"; then
    jobs_update_run_step "FVM / Flutter 更新" jobs_update_fvm_flutter
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否维护 Node / corepack / npm？" "覆盖 install.command 中的 brew formula：node / pnpm，并兼容 nvm。"; then
    jobs_update_run_step "Node / corepack / npm 维护" jobs_update_node_base
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 npm 全局包 quicktype？" "对应 install.command：npm 全局包 quicktype。"; then
    jobs_update_run_step "npm quicktype 更新" jobs_update_npm_quicktype
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 npm 全局包 OpenCLI？" "对应 install.command：npm 全局包 OpenCLI。"; then
    jobs_update_run_step "npm OpenCLI 更新" jobs_update_npm_opencli
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 Ruby / RubyGems？" "覆盖 install.command 中的 brew formula：ruby / rbenv 的后续维护。"; then
    jobs_update_run_step "Ruby / RubyGems 更新" jobs_update_ruby_base
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 CocoaPods？" "对应 install.command：gem 包 cocoapods，并执行 pod repo update。"; then
    jobs_update_run_step "CocoaPods 更新" jobs_update_gem_cocoapods
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 Python / pip？" "覆盖 install.command 中的 brew formula：python / python3 / uv 的后续维护。"; then
    jobs_update_run_step "Python / pip 更新" jobs_update_python_base
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否修复 Dart pub 缓存？" "覆盖 Flutter / FVM / Dart 生态的缓存维护。"; then
    jobs_update_run_step "Dart pub 缓存修复" jobs_update_pub_cache
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否刷新 Git LFS 初始化与大文件参数？" "对应 install.command：Git LFS 初始化。"; then
    jobs_update_run_step "Git LFS 初始化刷新" jobs_update_git_lfs_init
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否更新 JobsKits 仓库？" "对应 install.command：JobsSoftware.MacOS、JobsMacEnvVarConfig。"; then
    jobs_update_run_step "JobsKits 仓库更新" jobs_update_jobs_repos
    (( ran_count++ ))
  fi

  if jobs_update_prompt_run "是否打开手动下载 / 更新页面？" "对应 install.command：VS Code、Android Studio、Python 手动下载页。"; then
    jobs_update_run_step "手动下载 / 更新页面" jobs_update_manual_download_pages
    (( ran_count++ ))
  fi

  echo ""
  print_divider
  if (( ran_count == 0 )); then
    warn_echo "没有执行任何更新项"
  else
    success_echo "update 执行完成，共执行 ${ran_count} 个更新项"
  fi
  info_echo "日志文件位置：${LOG_FILE}"
  print_divider
}

# ---------- 主流程统一收口 ----------
jobs_update_main() {
  jobs_update_show_readme_and_wait
  update "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_update_main "$@"
fi
