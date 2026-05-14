#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

: > "$LOG_FILE"

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

# ---------- 内置自述 ----------
jobs_update_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
update - 环境更新
============================================================

即将按菜单升级 / 维护：

  1. Homebrew
     brew update / brew upgrade / brew cleanup / brew doctor

  2. FVM / Flutter
     升级 FVM，执行 flutter upgrade / flutter doctor

  3. Node
     使用 nvm 更新 LTS，启用 corepack

  4. Python
     pyenv update、pipx upgrade-all、pip 自升级

  5. Ruby
     rbenv rehash、gem update

  6. CocoaPods
     pod repo update

  7. Dart pub 缓存
     dart pub cache repair

按回车继续执行 update...
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    local _answer=""
    IFS= read -r _answer
  fi
}

# ---------- 通用工具 ----------
jobs_update_has() {
  command -v "$1" >/dev/null 2>&1
}

jobs_update_prompt_run() {
  local title="$1"
  local detail="$2"
  local answer=""

  log ""
  info_echo "$title"
  log "👉 直接按 [Enter]：$detail"
  log "👉 输入任意字符后回车：跳过"
  IFS= read -r answer

  [[ -z "$answer" ]]
}

jobs_update_run_step() {
  local title="$1"
  shift

  highlight_echo "$title"
  "$@"
  local exit_code=$?

  if (( exit_code == 0 )); then
    success_echo "$title 完成"
  else
    warn_echo "$title 返回非 0：${exit_code}；继续后续更新项"
  fi

  return 0
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

jobs_update_find_external_command() {
  local command_name="$1"
  local path_dir=""
  local candidate=""
  local candidate_real=""
  local script_real=""

  if [[ -n "${SCRIPT_PATH:-}" && -e "$SCRIPT_PATH" ]]; then
    script_real="$(cd "${SCRIPT_PATH:h}" 2>/dev/null && pwd -P)/${SCRIPT_PATH:t}"
  fi

  for path_dir in ${(s.:.)PATH}; do
    [[ -n "$path_dir" ]] || continue
    candidate="$path_dir/$command_name"
    [[ -x "$candidate" ]] || continue

    candidate_real="$(cd "${candidate:h}" 2>/dev/null && pwd -P)/${candidate:t}"
    [[ -n "$script_real" && "$candidate_real" == "$script_real" ]] && continue

    print -r -- "$candidate"
    return 0
  done

  return 1
}

# ---------- 更新项 ----------
jobs_update_homebrew() {
  if ! jobs_update_has brew; then
    warn_echo "未检测到 Homebrew，跳过 Homebrew 更新"
    return 0
  fi

  brew update
  brew upgrade
  brew cleanup
  brew doctor || warn_echo "brew doctor 有警告，请按输出处理"
  brew -v || true
}

jobs_update_fvm_flutter() {
  local external_flutter=""

  if jobs_update_has brew && brew list --formula fvm >/dev/null 2>&1; then
    brew upgrade fvm || warn_echo "brew upgrade fvm 失败，继续后续步骤"
  elif jobs_update_has dart; then
    dart pub global activate fvm || warn_echo "dart pub global activate fvm 失败，继续后续步骤"
  else
    warn_echo "未检测到 brew formula fvm 或 dart，跳过 FVM 更新"
  fi

  if external_flutter="$(jobs_update_find_external_command flutter 2>/dev/null)"; then
    "$external_flutter" upgrade || warn_echo "flutter upgrade 失败，继续后续步骤"
    "$external_flutter" doctor -v || warn_echo "flutter doctor 有警告，请按输出处理"
  elif jobs_update_has fvm; then
    fvm flutter doctor -v || warn_echo "fvm flutter doctor 有警告，请按输出处理"
  else
    warn_echo "未检测到外部 flutter / fvm，跳过 Flutter 更新"
  fi
}

jobs_update_node() {
  jobs_update_source_nvm_if_needed

  if jobs_update_has nvm; then
    nvm install --lts --reinstall-packages-from=current
    nvm alias default 'lts/*'
    nvm use default
  elif jobs_update_has node; then
    warn_echo "检测到 node，但未检测到 nvm；不会擅自替换 Node 版本"
  else
    warn_echo "未检测到 node / nvm，跳过 Node 更新"
  fi

  if jobs_update_has corepack; then
    corepack enable || warn_echo "corepack enable 失败，继续后续步骤"
  fi

  if jobs_update_has npm; then
    npm -v || true
  fi
}

jobs_update_python() {
  if jobs_update_has pyenv; then
    if pyenv commands | grep -qx update; then
      pyenv update || warn_echo "pyenv update 失败，继续后续步骤"
    else
      warn_echo "pyenv-update 插件不存在，跳过 pyenv update"
    fi
    pyenv rehash || true
  fi

  if jobs_update_has pipx; then
    pipx upgrade-all || warn_echo "pipx upgrade-all 失败，继续后续步骤"
  fi

  if jobs_update_has python3; then
    python3 -m pip install --upgrade pip || warn_echo "pip 自升级失败，继续后续步骤"
  elif jobs_update_has python; then
    python -m pip install --upgrade pip || warn_echo "pip 自升级失败，继续后续步骤"
  else
    warn_echo "未检测到 Python，跳过 Python 更新"
  fi
}

jobs_update_ruby() {
  if jobs_update_has rbenv; then
    rbenv rehash || true
  fi

  if jobs_update_has gem; then
    gem update --system || warn_echo "gem update --system 失败，继续后续步骤"
    gem update || warn_echo "gem update 失败，继续后续步骤"
  else
    warn_echo "未检测到 gem，跳过 RubyGems 更新"
  fi
}

jobs_update_cocoapods() {
  if jobs_update_has pod; then
    pod repo update || warn_echo "pod repo update 失败，继续后续步骤"
  elif jobs_update_has gem; then
    warn_echo "未检测到 pod；可执行 gem install cocoapods 后再运行本项"
  else
    warn_echo "未检测到 pod / gem，跳过 CocoaPods 更新"
  fi
}

jobs_update_pub_cache() {
  if jobs_update_has dart; then
    dart pub global list || true
    dart pub cache repair || warn_echo "dart pub cache repair 失败，继续后续步骤"
  else
    warn_echo "未检测到 dart，跳过 Dart pub cache 更新"
  fi
}

# ---------- 命令实现 ----------
update() {
  emulate -L zsh

  local ran_count=0

  if jobs_update_prompt_run "是否更新 Homebrew？" "执行 brew update / upgrade / cleanup / doctor"; then
    jobs_update_run_step "Homebrew 更新" jobs_update_homebrew
    (( ran_count++ ))
  else
    note_echo "已跳过 Homebrew 更新"
  fi

  if jobs_update_prompt_run "是否更新 FVM / Flutter？" "更新 FVM，并执行 flutter upgrade / doctor"; then
    jobs_update_run_step "FVM / Flutter 更新" jobs_update_fvm_flutter
    (( ran_count++ ))
  else
    note_echo "已跳过 FVM / Flutter 更新"
  fi

  if jobs_update_prompt_run "是否更新 Node 工具链？" "使用 nvm 更新 LTS，并启用 corepack"; then
    jobs_update_run_step "Node 工具链更新" jobs_update_node
    (( ran_count++ ))
  else
    note_echo "已跳过 Node 工具链更新"
  fi

  if jobs_update_prompt_run "是否更新 Python 工具链？" "执行 pyenv update / pipx upgrade-all / pip 自升级"; then
    jobs_update_run_step "Python 工具链更新" jobs_update_python
    (( ran_count++ ))
  else
    note_echo "已跳过 Python 工具链更新"
  fi

  if jobs_update_prompt_run "是否更新 Ruby 工具链？" "执行 rbenv rehash / gem update"; then
    jobs_update_run_step "Ruby 工具链更新" jobs_update_ruby
    (( ran_count++ ))
  else
    note_echo "已跳过 Ruby 工具链更新"
  fi

  if jobs_update_prompt_run "是否更新 CocoaPods？" "执行 pod repo update"; then
    jobs_update_run_step "CocoaPods 更新" jobs_update_cocoapods
    (( ran_count++ ))
  else
    note_echo "已跳过 CocoaPods 更新"
  fi

  if jobs_update_prompt_run "是否修复 Dart pub 缓存？" "执行 dart pub cache repair"; then
    jobs_update_run_step "Dart pub 缓存修复" jobs_update_pub_cache
    (( ran_count++ ))
  else
    note_echo "已跳过 Dart pub 缓存修复"
  fi

  if (( ran_count == 0 )); then
    warn_echo "没有执行任何更新项"
  else
    success_echo "update 执行完成，共执行 ${ran_count} 个更新项"
  fi
}

# ---------- 主流程统一收口 ----------
jobs_update_main() {
  jobs_update_show_readme_and_wait
  update "$@"
  gray_echo "日志路径：$LOG_FILE"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_update_main "$@"
fi
