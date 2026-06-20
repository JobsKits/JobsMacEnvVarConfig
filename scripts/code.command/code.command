#!/bin/zsh
# JobsMacEnv VS Code CLI wrapper.
# 用途：即使 VS Code 没有执行“Shell Command: Install 'code' command in PATH”，也能在终端使用：code .

emulate -L zsh
set -o pipefail
setopt NO_NOMATCH

jobs_code_self_path="${0:A}"

# 封装 jobs_code_exec_if_valid 对应的独立处理逻辑。
jobs_code_exec_if_valid() {
  local candidate="$1"
  shift
  [[ -n "$candidate" ]] || return 1
  [[ -x "$candidate" ]] || return 1

  # 避免 ~/.local/bin/code 包装脚本递归调用自己。
  if [[ "${candidate:A}" == "$jobs_code_self_path" ]]; then
    return 1
  fi

  exec "$candidate" "$@"
}

# 封装 jobs_code_resolve_from_app 对应的独立处理逻辑。
jobs_code_resolve_from_app() {
  local app_path="$1"
  local bin_path="$app_path/Contents/Resources/app/bin/code"
  local insiders_bin_path="$app_path/Contents/Resources/app/bin/code-insiders"

  if [[ -x "$bin_path" ]]; then
    print -r -- "$bin_path"
    return 0
  fi

  if [[ -x "$insiders_bin_path" ]]; then
    print -r -- "$insiders_bin_path"
    return 0
  fi

  return 1
}

# 编排完整业务流程，复杂步骤继续下沉到职责明确的函数。
jobs_code_main() {
  local candidate=""
  local app_path=""

  # 1. 优先查找 VS Code App 内置的官方 CLI。
  local fixed_candidates=(
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders"
    "$HOME/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders"
  )

  for candidate in "${fixed_candidates[@]}"; do
    jobs_code_exec_if_valid "$candidate" "$@" || true
  done

  # 2. 兼容用户之后又安装了官方 code 软链接的情况。
  local link_candidates=(
    "/usr/local/bin/code"
    "/opt/homebrew/bin/code"
  )

  for candidate in "${link_candidates[@]}"; do
    jobs_code_exec_if_valid "$candidate" "$@" || true
  done

  # 3. Spotlight 兜底：如果 VS Code 被放在非标准目录，尝试通过 Bundle ID 查找。
  if command -v mdfind >/dev/null 2>&1; then
    app_path="$(mdfind 'kMDItemCFBundleIdentifier == "com.microsoft.VSCode"' 2>/dev/null | head -n 1)"
    if [[ -n "$app_path" ]]; then
      candidate="$(jobs_code_resolve_from_app "$app_path" 2>/dev/null || true)"
      jobs_code_exec_if_valid "$candidate" "$@" || true
    fi

    app_path="$(mdfind 'kMDItemCFBundleIdentifier == "com.microsoft.VSCodeInsiders"' 2>/dev/null | head -n 1)"
    if [[ -n "$app_path" ]]; then
      candidate="$(jobs_code_resolve_from_app "$app_path" 2>/dev/null || true)"
      jobs_code_exec_if_valid "$candidate" "$@" || true
    fi
  fi

  cat >&2 <<'EOFERR'
code: 未找到 VS Code 的命令行入口。

已检查：
  /Applications/Visual Studio Code.app/Contents/Resources/app/bin/code
  ~/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code
  /usr/local/bin/code
  /opt/homebrew/bin/code

处理方式：
  1. 确认 Visual Studio Code.app 已安装在 /Applications 或 ~/Applications；
  2. 重新执行 JobsMacEnvVarConfigs/install.command；
  3. 或在 VS Code 中执行：Command Palette → Shell Command: Install 'code' command in PATH。
EOFERR
  return 127
}

# 统一收口脚本入口，仅委托已经拆分完成的业务流程。
main() {
  # 主入口只负责委托完整业务流程，复杂逻辑统一下沉。
  jobs_code_main "$@"
}

main "$@"
