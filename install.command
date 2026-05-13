#!/usr/bin/env bash

set -euo pipefail

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_MAGENTA='\033[35m'
C_RED='\033[31m'
C_GRAY='\033[90m'

cecho() {
  local color="$1"
  shift
  printf "%b%s%b\n" "$color" "$*" "$C_RESET"
}

log() {
  cecho "$C_GREEN" "[env-sync] $1"
}

warn() {
  cecho "$C_YELLOW" "[warn] $1"
}

err() {
  cecho "$C_RED" "[err] $1"
}

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

write_file_if_changed() {
  local target="$1"
  local content="$2"
  local tmp

  tmp="$(mktemp)"
  printf "%s" "$content" > "$tmp"

  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    log "无变化，跳过：$target"
    return 0
  fi

  mv "$tmp" "$target"
  log "已写入：$target"
}

copy_file_if_changed() {
  local src="$1"
  local target="$2"
  [[ -f "$src" ]] || { err "缺少文件：$src"; exit 1; }
  write_file_if_changed "$target" "$(cat "$src")"
}

CURRENT_SECTION=""
JAVA_VERSION="17"
JAVA_CANDIDATES="temurin@17,zulu@17,openjdk@17"
ANDROID_SDK_DEFAULT="\$HOME/Library/Android/sdk"
USE_FVM="true"
FLUTTER_CANDIDATES="\$HOME/fvm/default/bin,\$HOME/development/flutter/bin"
ENABLE_PNPM="true"
ENABLE_COREPACK="true"
NVM_DIR="\$HOME/.nvm"
ENABLE_CARGO="true"
CARGO_HOME="\$HOME/.cargo"
ENABLE_PYENV="true"
PYENV_ROOT="\$HOME/.pyenv"
ENABLE_RBENV="true"
RBENV_ROOT="\$HOME/.rbenv"
ENABLE_GO="true"
GOPATH="\$HOME/go"
PATH_LIST=()
ALIAS_LIST=()

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf "%s" "$s"
}

parse_sync_file() {
  local file="$1"

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line
    line="$(trim "$raw_line")"

    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    if [[ "$line" =~ ^\[.*\]$ ]]; then
      CURRENT_SECTION="${line#[}"
      CURRENT_SECTION="${CURRENT_SECTION%]}"
      continue
    fi

    case "$CURRENT_SECTION" in
      JAVA|ANDROID|FLUTTER|NODE|RUST|PYTHON|RUBY|GO)
        local key="${line%%=*}"
        local value="${line#*=}"
        case "$key" in
          JAVA_VERSION) JAVA_VERSION="$value" ;;
          JAVA_CANDIDATES) JAVA_CANDIDATES="$value" ;;
          ANDROID_SDK_DEFAULT) ANDROID_SDK_DEFAULT="$value" ;;
          USE_FVM) USE_FVM="$value" ;;
          FLUTTER_CANDIDATES) FLUTTER_CANDIDATES="$value" ;;
          ENABLE_PNPM) ENABLE_PNPM="$value" ;;
          ENABLE_COREPACK) ENABLE_COREPACK="$value" ;;
          NVM_DIR) NVM_DIR="$value" ;;
          ENABLE_CARGO) ENABLE_CARGO="$value" ;;
          CARGO_HOME) CARGO_HOME="$value" ;;
          ENABLE_PYENV) ENABLE_PYENV="$value" ;;
          PYENV_ROOT) PYENV_ROOT="$value" ;;
          ENABLE_RBENV) ENABLE_RBENV="$value" ;;
          RBENV_ROOT) RBENV_ROOT="$value" ;;
          ENABLE_GO) ENABLE_GO="$value" ;;
          GOPATH) GOPATH="$value" ;;
        esac
        ;;
      PATH)
        PATH_LIST+=("$line")
        ;;
      ALIASES)
        ALIAS_LIST+=("$line")
        ;;
    esac
  done < "$file"
}

generate_env_content() {
  cat <<EOFVARS
# ========================
# 自动生成，请勿手改
# 来源：sync_env.txt
# ========================

jobs_setup_java "${JAVA_VERSION}"
jobs_setup_android "${ANDROID_SDK_DEFAULT}"
jobs_setup_flutter "${USE_FVM}" "${FLUTTER_CANDIDATES}"
jobs_setup_node "${ENABLE_COREPACK}" "${NVM_DIR}"
EOFVARS

  [[ "$ENABLE_CARGO" == "true" ]] && echo "jobs_setup_rust \"${CARGO_HOME}\""
  [[ "$ENABLE_PYENV" == "true" ]] && echo "jobs_setup_pyenv \"${PYENV_ROOT}\""
  [[ "$ENABLE_RBENV" == "true" ]] && echo "jobs_setup_rbenv \"${RBENV_ROOT}\""
  [[ "$ENABLE_GO" == "true" ]] && echo "jobs_setup_go \"${GOPATH}\""

  echo ""
  echo "# PATH"
  local item
  for item in "${PATH_LIST[@]}"; do
    echo "jobs_path_add \"${item}\""
  done

  if [[ "$ENABLE_PNPM" == "true" ]]; then
    cat <<'EOFPNPM'
if command -v pnpm >/dev/null 2>&1; then
  PNPM_HOME="${HOME}/Library/pnpm"
  export PNPM_HOME
  jobs_path_add "$PNPM_HOME"
fi
EOFPNPM
  fi
}

generate_aliases_content() {
  echo "# 自动生成别名"
  local item
  for item in "${ALIAS_LIST[@]}"; do
    local name="${item%%=*}"
    local value="${item#*=}"
    echo "alias ${name}='${value}'"
  done
}

generate_minimal_zshrc() {
  cat <<'EOFZSHRC'
# JobsMacEnv 主入口
# 只保留最小入口，具体逻辑全部拆到 $HOME/.JobsMacEnv 下维护

export JOBS_MAC_ENV_HOME="$HOME/.JobsMacEnv"
[[ -n "${JOBS_MAC_ENV_HOME_OVERRIDE:-}" ]] && export JOBS_MAC_ENV_HOME="$JOBS_MAC_ENV_HOME_OVERRIDE"

jobs_source_if_exists() {
  local file="$1"
  [[ -f "$file" ]] && source "$file"
}

jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/bootstrap.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env_methods.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/aliases.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/user_mounts.zsh"
EOFZSHRC
}

show_intro_and_wait() {
  echo ""
  cecho "$C_BOLD$C_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  cecho "$C_BOLD$C_CYAN" "      JobsMacEnv 安装提示"
  cecho "$C_BOLD$C_CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  cecho "$C_BLUE" "1) 会同步到 ~/.JobsMacEnv"
  cecho "$C_BLUE" "2) 会从 Sys/.zshrc 生成轻量版 ~/.zshrc"
  cecho "$C_BLUE" "3) 会检测 JDK 17，可选自动安装"
  cecho "$C_BLUE" "4) 会同步 trs / gif / jdk17 / simios 命令入口到 ~/.JobsMacEnv/Scripts 和 ~/.local/bin"
  cecho "$C_BLUE" "5) 稍后会问你是否替换当前 ~/.zshrc"
  echo ""
  cecho "$C_MAGENTA" "结构："
  cecho "$C_GRAY" "  Sys/.zshrc               -> 模板入口"
  cecho "$C_GRAY" "  ~/.zshrc                 -> 系统主入口"
  cecho "$C_GRAY" "  ~/.JobsMacEnv/zsh        -> 配置目录"
  cecho "$C_GRAY" "  ~/.JobsMacEnv/Scripts    -> 安装脚本 / trs 翻译脚本 / gif 录制脚本"
  cecho "$C_GRAY" "  ~/.local/bin/trs         -> 终端翻译命令入口"
  cecho "$C_GRAY" "  ~/.local/bin/gif         -> 终端录制转 GIF 入口"
  echo ""
  cecho "$C_YELLOW" "按回车继续安装..."
  read -r _
}

has_java_version() {
  local version="$1"
  [[ -x /usr/libexec/java_home ]] || return 1
  /usr/libexec/java_home -v "$version" >/dev/null 2>&1
}

install_jdk_formula_or_cask() {
  local candidate="$1"

  if [[ "$candidate" == openjdk@* ]]; then
    brew install "$candidate"
  else
    brew install --cask "$candidate"
  fi
}

install_jdk17_if_needed() {
  local version="$1"
  local candidates_csv="$2"

  if has_java_version "$version"; then
    log "已检测到 JDK ${version}，跳过安装"
    return 0
  fi

  warn "系统未检测到 JDK ${version}"

  if ! command -v brew >/dev/null 2>&1; then
    warn "未检测到 Homebrew，无法自动安装 JDK ${version}"
    warn "你可以后续手动安装后再执行：source ~/.zshrc"
    return 0
  fi

  local answer=""
  read -r -p "是否现在自动安装 JDK ${version} ？回车安装，输入任意字符跳过: " answer
  if [[ -n "$answer" ]]; then
    warn "已跳过 JDK ${version} 自动安装"
    return 0
  fi

  local old_ifs="$IFS"
  IFS=','
  local candidate
  for candidate in $candidates_csv; do
    candidate="$(trim "$candidate")"
    [[ -n "$candidate" ]] || continue
    log "尝试安装：$candidate"
    if install_jdk_formula_or_cask "$candidate"; then
      IFS="$old_ifs"
      if has_java_version "$version"; then
        log "JDK ${version} 安装完成"
        return 0
      fi
      warn "$candidate 安装完成，但系统暂未识别到 JDK ${version}，继续后续流程"
      return 0
    fi
    warn "$candidate 安装失败，继续尝试下一个"
  done
  IFS="$old_ifs"

  err "JDK ${version} 自动安装失败，请手动安装后再执行 source ~/.zshrc"
  return 0
}

prompt_replace_system_zshrc() {
  local generated_zshrc="$1"
  local system_zshrc="$HOME/.zshrc"
  local answer=""

  echo ""
  read -r -p "是否对系统目前的 .zshrc 进行替换，回车就替换，输入任意字符就不替换: " answer

  if [[ -n "$answer" ]]; then
    log "已跳过替换系统 .zshrc"
    return 0
  fi

  if [[ -f "$system_zshrc" ]]; then
    local backup="$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
    cp "$system_zshrc" "$backup"
    log "已备份当前 .zshrc：$backup"
  fi

  cp "$generated_zshrc" "$system_zshrc"
  log "已替换系统 .zshrc：$system_zshrc"
}

verify_scripts_modules() {
  local scripts_dir="$1"
  local required_files=(
    common.command
    entrypoints.command
    path.command
    media.command
    session.command
    flutter_project.command
    update.command
    system_install.command
    color.command
    shell.command
    codec.command
    timestamp.command
    runtime_init.command
    simios.command
  )

  if [[ ! -d "$scripts_dir" ]]; then
    err "Scripts 模块目录不存在：$scripts_dir"
    exit 1
  fi

  local missing=()
  local file=""
  for file in "${required_files[@]}"; do
    if [[ ! -f "$scripts_dir/$file" ]]; then
      missing+=("$file")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    err "Scripts 模块同步不完整：${missing[*]}"
    err "当前目录：$scripts_dir"
    err "当前目录实际文件："
    find "$scripts_dir" -maxdepth 1 -type f -name '*.command' -print 2>/dev/null | sort | sed 's/^/[err]   /' || true
    exit 1
  fi

  log "Scripts 模块自检通过：$scripts_dir"
}

main() {
  local source_dir
  source_dir="$(cd "$(dirname "$0")" && pwd)"

  local target_root="$HOME/.JobsMacEnv"
  local target_zsh_dir="$target_root/zsh"
  local target_custom_dir="$target_zsh_dir/custom"
  local target_scripts_dir="$target_root/Scripts"
  local target_bin_dir="$HOME/.local/bin"
  local old_target_scripts_dir="$target_root/scripts"

  local sync_file="$source_dir/sync_env.txt"
  local target_sync_file="$target_root/sync_env.txt"
  local target_readme="$target_root/README.md"
  local target_install="$target_root/install.command"
  local target_zshrc_template="$target_root/.zshrc"
  local target_env="$target_zsh_dir/env.zsh"
  local target_aliases="$target_zsh_dir/aliases.zsh"
  local sys_dir="$source_dir/Sys"
  local source_zshrc="$sys_dir/.zshrc"

  if [[ ! -f "$source_zshrc" && -f "$source_dir/.zshrc" ]]; then
    source_zshrc="$source_dir/.zshrc"
  fi

  show_intro_and_wait

  [[ -f "$sync_file" ]] || { err "缺少 sync_env.txt"; exit 1; }
  [[ -f "$source_zshrc" ]] || { err "缺少文件：$source_zshrc"; exit 1; }
  parse_sync_file "$sync_file"
  install_jdk17_if_needed "$JAVA_VERSION" "$JAVA_CANDIDATES"

  log "开始同步 JobsMacEnv 到：$target_root"

  ensure_dir "$target_root"
  ensure_dir "$target_zsh_dir"
  ensure_dir "$target_custom_dir"
  ensure_dir "$target_bin_dir"
  ensure_dir "$target_root/assets"

  # macOS 默认文件系统通常大小写不敏感：scripts 与 Scripts 可能是同一个目录。
  # 必须先清理，再重建；不能创建 Scripts 后再 rm -rf scripts，否则会把新目录删掉。
  rm -rf "$target_scripts_dir" "$old_target_scripts_dir" 2>/dev/null || true
  ensure_dir "$target_scripts_dir"

  copy_file_if_changed "$source_zshrc" "$target_zshrc_template"
  copy_file_if_changed "$source_dir/README.md" "$target_readme"
  copy_file_if_changed "$source_dir/install.command" "$target_install"
  copy_file_if_changed "$source_dir/sync_env.txt" "$target_sync_file"
  local source_scripts_dir="$source_dir/Scripts"
  [[ -d "$source_scripts_dir" ]] || { err "缺少目录：$source_scripts_dir"; exit 1; }

  local script_file script_name
  for script_file in "$source_scripts_dir"/*.command; do
    [[ -f "$script_file" ]] || continue
    script_name="$(basename "$script_file")"
    copy_file_if_changed "$script_file" "$target_scripts_dir/$script_name"
    chmod +x "$target_scripts_dir/$script_name"
  done

  copy_file_if_changed "$source_scripts_dir/trs.command" "$target_bin_dir/trs"
  copy_file_if_changed "$source_scripts_dir/gif.command" "$target_bin_dir/gif"
  copy_file_if_changed "$source_scripts_dir/install_jdk17.command" "$target_bin_dir/jdk17"
  copy_file_if_changed "$source_scripts_dir/simios.command" "$target_bin_dir/simios"
  copy_file_if_changed "$source_dir/zsh/bootstrap.zsh" "$target_zsh_dir/bootstrap.zsh"
  copy_file_if_changed "$source_dir/zsh/env_methods.zsh" "$target_zsh_dir/env_methods.zsh"
  copy_file_if_changed "$source_dir/zsh/user_mounts.zsh" "$target_zsh_dir/user_mounts.zsh"
  copy_file_if_changed "$source_dir/zsh/custom/shell_behavior.zsh" "$target_custom_dir/shell_behavior.zsh"
  if [[ -f "$source_dir/zsh/custom/path_drag_resolver.zsh" ]]; then
    copy_file_if_changed "$source_dir/zsh/custom/path_drag_resolver.zsh" "$target_custom_dir/path_drag_resolver.zsh"
  fi
  copy_file_if_changed "$source_dir/zsh/custom/local.zsh" "$target_custom_dir/local.zsh"

  # 旧版本使用小写 scripts；新版本统一改为 Scripts。
  # 注意：在大小写不敏感的 macOS 文件系统中，不能在这里删除 scripts，
  # 因为它会等同于删除刚刚创建的 Scripts。

  # 旧版本的个人命令文件已经合并到 Scripts 模块。
  if [[ -f "$target_custom_dir/legacy_functions.zsh" ]]; then
    rm -f "$target_custom_dir/legacy_functions.zsh"
    log "已移除旧文件：$target_custom_dir/legacy_functions.zsh"
  fi

  write_file_if_changed "$target_env" "$(generate_env_content)"
  write_file_if_changed "$target_aliases" "$(generate_aliases_content)"
  write_file_if_changed "$target_zshrc_template" "$(generate_minimal_zshrc)"

  chmod +x "$target_install"
  chmod +x "$target_scripts_dir"/*.command 2>/dev/null || true
  chmod +x "$target_bin_dir/trs" "$target_bin_dir/gif" "$target_bin_dir/jdk17" "$target_bin_dir/simios"

  verify_scripts_modules "$target_scripts_dir"

  log "已生成轻量入口文件：$target_zshrc_template"
  log "已同步 Scripts 模块目录：$target_scripts_dir"
  log "已安装 trs 命令入口：$target_bin_dir/trs"
  log "已安装 gif 命令入口：$target_bin_dir/gif"
  log "已安装 jdk17 命令入口：$target_bin_dir/jdk17"
  log "已安装 simios 命令入口：$target_bin_dir/simios"
  prompt_replace_system_zshrc "$target_zshrc_template"

  if [[ -f "$HOME/.zshrc" ]]; then
    log "如需立即生效，请执行：source ~/.zshrc"
  fi

  log "同步完成"
}

main "$@"
