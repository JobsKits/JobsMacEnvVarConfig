#!/bin/zsh

set -euo pipefail

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

# ---------- 默认配置 ----------
CURRENT_SECTION=""
JAVA_VERSION="17"
JAVA_CANDIDATES="temurin@17,zulu@17,openjdk@17"
ANDROID_SDK_DEFAULT='$HOME/Library/Android/sdk'
USE_FVM="true"
FLUTTER_CANDIDATES='$HOME/fvm/default/bin,$HOME/development/flutter/bin'
ENABLE_PNPM="true"
ENABLE_COREPACK="true"
NVM_DIR='$HOME/.nvm'
ENABLE_CARGO="true"
CARGO_HOME='$HOME/.cargo'
ENABLE_PYENV="true"
PYENV_ROOT='$HOME/.pyenv'
ENABLE_RBENV="true"
RBENV_ROOT='$HOME/.rbenv'
ENABLE_GO="true"
GOPATH='$HOME/go'
PATH_LIST=()
ALIAS_LIST=()

# ---------- 通用工具 ----------
ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

write_file_if_changed() {
  local target="$1"
  local content="$2"
  local tmp=""

  tmp="$(mktemp)"
  printf "%s" "$content" > "$tmp"

  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    info_echo "无变化，跳过：$target"
    return 0
  fi

  mv "$tmp" "$target"
  success_echo "已写入：$target"
}

copy_file_if_changed() {
  local src="$1"
  local target="$2"

  [[ -f "$src" ]] || {
    error_echo "缺少文件：$src"
    exit 1
  }

  write_file_if_changed "$target" "$(cat "$src")"
}

get_cpu_arch() {
  uname -m
}

find_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  local candidate=""
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

profile_file_for_shell() {
  local shell_path="${SHELL##*/}"

  case "$shell_path" in
    zsh)  print -r -- "$HOME/.zprofile" ;;
    bash) print -r -- "$HOME/.bash_profile" ;;
    *)    print -r -- "$HOME/.profile" ;;
  esac
}

inject_shellenv_block() {
  local profile_file="$1"
  local shellenv="$2"
  local id="homebrew_env"
  local header="# >>> ${id} 环境变量 >>>"
  local footer="# <<< ${id} 环境变量 <<<"

  if [[ -z "$profile_file" || -z "$shellenv" ]]; then
    error_echo "缺少参数：inject_shellenv_block <profile_file> <shellenv>"
    return 1
  fi

  ensure_dir "$(dirname "$profile_file")"
  touch "$profile_file"

  if grep -Fq "$header" "$profile_file"; then
    info_echo "Homebrew 环境变量块已存在：$profile_file"
  elif grep -Fq "$shellenv" "$profile_file"; then
    info_echo "Homebrew shellenv 已存在：$profile_file"
  else
    {
      echo ""
      echo "$header"
      echo "$shellenv"
      echo "$footer"
    } >> "$profile_file"
    success_echo "已写入 Homebrew 环境变量：$profile_file"
  fi

  eval "$shellenv"
  success_echo "Homebrew shellenv 已在当前终端生效"
}

install_homebrew() {
  local arch="$(get_cpu_arch)"
  local profile_file="$(profile_file_for_shell)"
  local brew_bin=""
  local shellenv_cmd=""
  local confirm=""

  if brew_bin="$(find_brew_bin 2>/dev/null)"; then
    shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""
    inject_shellenv_block "$profile_file" "$shellenv_cmd"

    info_echo "Homebrew 已安装：$brew_bin"
    log "👉 直接按 [Enter]：跳过 Homebrew 更新"
    log "👉 输入任意字符后回车：执行 brew update && brew upgrade && brew cleanup && brew doctor && brew -v"
    IFS= read -r confirm

    if [[ -z "$confirm" ]]; then
      note_echo "已跳过 Homebrew 更新"
      return 0
    fi

    info_echo "正在更新 Homebrew..."
    brew update  || { error_echo "brew update 失败"; return 1; }
    brew upgrade || { error_echo "brew upgrade 失败"; return 1; }
    brew cleanup || { error_echo "brew cleanup 失败"; return 1; }
    brew doctor  || warn_echo "brew doctor 有警告/错误，请按提示处理"
    brew -v      || warn_echo "打印 brew 版本失败，可忽略"
    success_echo "Homebrew 更新流程完成"
    return 0
  fi

  warn_echo "未检测到 Homebrew，开始安装...（架构：$arch）"

  if [[ "$arch" == "arm64" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      error_echo "Homebrew 安装失败（arm64）"
      exit 1
    }
    brew_bin="/opt/homebrew/bin/brew"
  else
    arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      error_echo "Homebrew 安装失败（x86_64）"
      exit 1
    }
    brew_bin="/usr/local/bin/brew"
  fi

  [[ -x "$brew_bin" ]] || {
    error_echo "Homebrew 安装后仍未找到 brew：$brew_bin"
    exit 1
  }

  shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""
  inject_shellenv_block "$profile_file" "$shellenv_cmd"
  success_echo "Homebrew 安装完成"
}

# ---------- 配置解析 ----------
parse_sync_file() {
  local file="$1"

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line=""
    line="$(trim "$raw_line")"

    [[ -z "$line" ]] && continue
    [[ "${line[1]}" == "#" ]] && continue

    # zsh 对未闭合/转义不当的 [] glob 很敏感，这里不用 [[ "$line" == \[*\] ]]。
    # 直接判断首尾字符，稳定识别 sync_env.txt 的 [SECTION]。
    if (( ${#line} >= 2 )) && [[ "${line[1]}" == "[" && "${line[-1]}" == "]" ]]; then
      CURRENT_SECTION="${line[2,-2]}"
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
  local item=""
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

  local item=""
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

# ---------- Java ----------
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
  local answer=""

  if has_java_version "$version"; then
    success_echo "已检测到 JDK ${version}，跳过安装"
    return 0
  fi

  warn_echo "系统未检测到 JDK ${version}"
  log "👉 直接按 [Enter]：跳过 JDK ${version} 安装"
  log "👉 输入任意字符后回车：自动安装 JDK ${version}"
  IFS= read -r answer

  if [[ -z "$answer" ]]; then
    note_echo "已跳过 JDK ${version} 自动安装"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    error_echo "未检测到 Homebrew，无法自动安装 JDK ${version}"
    return 1
  fi

  local candidate=""
  for candidate in ${(s:,:)candidates_csv}; do
    candidate="$(trim "$candidate")"
    [[ -n "$candidate" ]] || continue

    info_echo "尝试安装：$candidate"
    if install_jdk_formula_or_cask "$candidate"; then
      if has_java_version "$version"; then
        success_echo "JDK ${version} 安装完成"
      else
        warn_echo "$candidate 安装完成，但系统暂未识别到 JDK ${version}，继续后续流程"
      fi
      return 0
    fi

    warn_echo "$candidate 安装失败，继续尝试下一个"
  done

  error_echo "JDK ${version} 自动安装失败，请手动安装后再执行 source ~/.zshrc"
  return 0
}

# ---------- Scripts ----------
resolve_script_file() {
  local scripts_dir="$1"
  local script_name="$2"
  local nested_file="$scripts_dir/$script_name/$script_name"
  local flat_file="$scripts_dir/$script_name"

  if [[ -f "$nested_file" ]]; then
    print -r -- "$nested_file"
    return 0
  fi

  if [[ -f "$flat_file" ]]; then
    print -r -- "$flat_file"
    return 0
  fi

  return 1
}

copy_script_bundle() {
  local source_scripts_dir="$1"
  local target_scripts_dir="$2"
  local script_name="$3"
  local source_bundle="$source_scripts_dir/$script_name"
  local source_file=""
  local target_bundle="$target_scripts_dir/$script_name"
  local target_file="$target_bundle/$script_name"

  ensure_dir "$target_scripts_dir"
  rm -rf "$target_bundle"
  ensure_dir "$target_bundle"

  if [[ -d "$source_bundle" ]]; then
    cp -R "$source_bundle/." "$target_bundle/"
  elif [[ -f "$source_bundle" ]]; then
    cp "$source_bundle" "$target_file"
  else
    error_echo "缺少脚本：$source_bundle"
    exit 1
  fi

  source_file="$(resolve_script_file "$target_scripts_dir" "$script_name")" || {
    error_echo "脚本复制失败：$script_name"
    exit 1
  }

  chmod +x "$source_file"
  success_echo "已同步脚本：$script_name"
}

copy_all_script_bundles() {
  local source_scripts_dir="$1"
  local target_scripts_dir="$2"
  local item=""
  local script_name=""

  [[ -d "$source_scripts_dir" ]] || {
    error_echo "缺少目录：$source_scripts_dir"
    exit 1
  }

  rm -rf "$target_scripts_dir"
  ensure_dir "$target_scripts_dir"

  for item in "$source_scripts_dir"/*.command(N); do
    if [[ -d "$item" || -f "$item" ]]; then
      script_name="$(basename "$item")"
      copy_script_bundle "$source_scripts_dir" "$target_scripts_dir" "$script_name"
    fi
  done

  copy_scripts_private_libs "$source_scripts_dir" "$target_scripts_dir"
}

copy_scripts_private_libs() {
  local source_scripts_dir="$1"
  local target_scripts_dir="$2"
  local source_lib_dir="$source_scripts_dir/_lib"
  local target_lib_dir="$target_scripts_dir/_lib"

  if [[ -d "$source_lib_dir" ]]; then
    rm -rf "$target_lib_dir"
    cp -R "$source_lib_dir" "$target_lib_dir"
    success_echo "已同步 Scripts 私有库：$target_lib_dir"
  fi
}

verify_scripts_modules() {
  local scripts_dir="$1"
  local required_files=(
    entrypoints.command
    runtime_init.command
    list.command
    m5c.command
    flat.command
    trs.command
    gif.command
    install_jdk17.command
    simios.command
    pods.command
    clean.command
    df.command
    cor.command
    decode.command
    ts.command
    download.command
    to.command
    install.command
    update.command
    shell.command
    zz.command
    x.command
    save.command
    rb.command
    a.command
    b.command
    i.command
    flutter_project.command
    fixfvm.command
    check1.command
    check.command
    c.command
    d.command
    buildCheck.command
    apk.command
    ipa.command
    config.command
  )

  [[ -d "$scripts_dir" ]] || {
    error_echo "Scripts 模块目录不存在：$scripts_dir"
    exit 1
  }

  local missing=()
  local file=""
  for file in "${required_files[@]}"; do
    if ! resolve_script_file "$scripts_dir" "$file" >/dev/null 2>&1; then
      missing+=("$file")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    error_echo "Scripts 模块同步不完整：${missing[*]}"
    error_echo "当前目录：$scripts_dir"
    exit 1
  fi

  local required_libs=(
    _lib/jobs_path_lib.zsh
    _lib/jobs_session_lib.zsh
    _lib/jobs_flutter_lib.zsh
  )

  for file in "${required_libs[@]}"; do
    if [[ ! -f "$scripts_dir/$file" ]]; then
      missing+=("$file")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    error_echo "Scripts 私有库同步不完整：${missing[*]}"
    error_echo "当前目录：$scripts_dir"
    exit 1
  fi

  success_echo "Scripts 模块自检通过：$scripts_dir"
}

warn_if_command_conflict() {
  local bin_name="$1"
  local target_bin_dir="$2"
  local existing=""
  local target_path="$target_bin_dir/$bin_name"

  existing="$(command -v "$bin_name" 2>/dev/null || true)"
  if [[ -n "$existing" && "$existing" != "$target_path" ]]; then
    warn_echo "命令名可能冲突：$bin_name -> $existing"
    warn_echo "本次仍会写入：$target_path；如调用结果不符合预期，请检查 PATH 顺序或 alias / function。"
  fi
}

install_bin_entry() {
  local source_scripts_dir="$1"
  local target_bin_dir="$2"
  local script_name="$3"
  local bin_name="$4"
  local source_file=""

  warn_if_command_conflict "$bin_name" "$target_bin_dir"

  source_file="$(resolve_script_file "$source_scripts_dir" "$script_name")" || {
    error_echo "缺少入口脚本：$script_name"
    exit 1
  }

  copy_file_if_changed "$source_file" "$target_bin_dir/$bin_name"
  chmod +x "$target_bin_dir/$bin_name"
  success_echo "已安装命令入口：$target_bin_dir/$bin_name"
}

remove_obsolete_bin_entry() {
  local target_bin_dir="$1"
  local bin_name="$2"
  local target_path="$target_bin_dir/$bin_name"

  [[ -e "$target_path" ]] || return 0

  if [[ -f "$target_path" ]] && grep -Eq 'flutter\.command|jobs_flutter_show_readme|JOBS_MAC_ENV|jobs_dq_|dq\.command|com\.apple\.quarantine' "$target_path" 2>/dev/null; then
    rm -f "$target_path"
    note_echo "已移除旧的独立命令入口：$target_path"
    return 0
  fi

  warn_echo "检测到 $target_path，但它不像 JobsMacEnv 旧入口，已保留。"
}

remove_obsolete_script_bin_entry() {
  local source_scripts_dir="$1"
  local target_bin_dir="$2"
  local script_name="$3"
  local bin_name="$4"
  local target_path="$target_bin_dir/$bin_name"
  local source_file=""

  [[ -e "$target_path" ]] || return 0

  if ! source_file="$(resolve_script_file "$source_scripts_dir" "$script_name" 2>/dev/null)"; then
    warn_echo "检测到 $target_path，但找不到可比对的源脚本：$script_name，已保留。"
    return 0
  fi

  if [[ -f "$target_path" ]] && cmp -s "$source_file" "$target_path"; then
    rm -f "$target_path"
    note_echo "已移除旧的独立命令入口：$target_path"
    return 0
  fi

  warn_echo "检测到 $target_path，但它不是 JobsMacEnv 旧入口副本，已保留。"
}

# ---------- 交互 ----------
show_intro_and_wait() {
  clear

  cat <<'EOFINSTALL' | tee -a "$LOG_FILE"
============================================================
🌍 JobsMacEnvVarConfig 安装 / 同步工具
============================================================

这是 install.command 内置自述，不读取外部 README.md。
作用：把当前目录里的终端环境配置、Scripts 脚本模块、快捷命令同步到本机。

------------------------------------------------------------
一、同步位置
------------------------------------------------------------

会同步到：

  ~/.JobsMacEnv/

主要内容包括：

  ~/.JobsMacEnv/zsh/
  ~/.JobsMacEnv/Scripts/
  ~/.JobsMacEnv/sync_env.txt
  ~/.JobsMacEnv/README.md
  ~/.JobsMacEnv/install.command

快捷命令会安装到：

  ~/.local/bin/

------------------------------------------------------------
二、核心命令
------------------------------------------------------------

大部分终端可输入的自定义命令会安装到 ~/.local/bin，
并同步到 ~/.JobsMacEnv/Scripts/<命令>.command/<命令>.command。

例外：
  - flutter_project.command 保持原版位置，只由 list 菜单按需加载；不会生成 ~/.local/bin/flutter，避免覆盖系统 Flutter。
  - install_jdk17.command 保持原版脚本位置；不会生成 ~/.local/bin/jdk17。

可执行：

  list

查看完整菜单。list 自己不在菜单中显示；脚本功能和可输入命令都会按“功能入口”展示。

说明：
  list 是总入口，用 fzf 展示菜单。
  clean / cor / decode / ts / download / install / update / shell 等均已独立成 command。
  to / mp4 / mov / webm / mp3 等复用 to.command，用于 FFmpeg 媒体格式转换。

------------------------------------------------------------
三、交互规则
------------------------------------------------------------

普通安装 / 更新 / 升级步骤：

  直接按 Enter              跳过
  输入任意字符后回车        执行

危险操作：

  必须输入 YES 才执行

不会用普通回车触发危险操作。

------------------------------------------------------------
四、Homebrew
------------------------------------------------------------

脚本会检查 Homebrew。

未安装：
  自动安装 Homebrew
  自动写入 shellenv
  当前终端立即生效

已安装：
  直接按 Enter              跳过 Homebrew 更新
  输入任意字符后回车        执行 brew update / upgrade / cleanup / doctor

------------------------------------------------------------
五、JDK 17
------------------------------------------------------------

脚本会检查 JDK 17。

如果不存在，会询问是否通过 Homebrew 自动安装：

  直接按 Enter              跳过安装
  输入任意字符后回车        自动安装

------------------------------------------------------------
六、Scripts 结构
------------------------------------------------------------

Scripts 目录采用脚本独立文件夹结构：

  Scripts/
    xxx.command/
      xxx.command
      README.md

安装时会同步整个脚本文件夹，并保留每个脚本自己的 README.md。
内部复用逻辑放在 Scripts/_lib/ 私有库中，不作为终端命令展示。

------------------------------------------------------------
七、功能菜单
------------------------------------------------------------

安装完成后，输入：

  list

即可打开功能菜单。

list 会检查：

  brew 是否可用
  fzf 是否可用
  fzf 是否需要安装

fzf 来源 Homebrew。

------------------------------------------------------------
八、zshrc
------------------------------------------------------------

脚本会生成轻量入口文件：

  ~/.JobsMacEnv/.zshrc

之后会询问是否替换：

  ~/.zshrc

规则：

  直接按 Enter              跳过替换
  输入 YES 后回车           备份并替换 ~/.zshrc

------------------------------------------------------------
九、流程
------------------------------------------------------------

  启动 install.command
        ↓
  显示本内置自述并等待回车
        ↓
  解析 sync_env.txt
        ↓
  检查 Homebrew
        ↓
  检查 JDK 17
        ↓
  同步 ~/.JobsMacEnv
        ↓
  同步 zsh 配置
        ↓
  同步 Scripts 脚本模块
        ↓
  安装全部自定义命令入口
        ↓
  询问是否替换 ~/.zshrc
        ↓
  完成

============================================================
EOFINSTALL

  log ""
  warm_echo "按回车继续安装 / 同步..."
  local _answer=""
  IFS= read -r _answer
}

prompt_replace_system_zshrc() {
  local generated_zshrc="$1"
  local system_zshrc="$HOME/.zshrc"
  local answer=""

  log ""
  warn_echo "是否替换系统当前 ~/.zshrc？"
  log "👉 直接按 [Enter]：跳过替换"
  log "👉 输入 YES 后回车：备份并替换 ~/.zshrc"
  IFS= read -r answer

  if [[ "$answer" != "YES" ]]; then
    note_echo "已跳过替换系统 .zshrc"
    return 0
  fi

  if [[ -f "$system_zshrc" ]]; then
    local backup="$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
    cp "$system_zshrc" "$backup"
    success_echo "已备份当前 .zshrc：$backup"
  fi

  cp "$generated_zshrc" "$system_zshrc"
  success_echo "已替换系统 .zshrc：$system_zshrc"
}

# ---------- 主流程 ----------
main() {
  local source_dir="$SCRIPT_DIR"
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
  local source_scripts_dir="$source_dir/Scripts"

  if [[ ! -f "$source_zshrc" && -f "$source_dir/.zshrc" ]]; then
    source_zshrc="$source_dir/.zshrc"
  fi

  show_intro_and_wait

  [[ -f "$sync_file" ]] || { error_echo "缺少 sync_env.txt"; exit 1; }
  [[ -f "$source_zshrc" ]] || { error_echo "缺少文件：$source_zshrc"; exit 1; }

  parse_sync_file "$sync_file"
  install_homebrew
  install_jdk17_if_needed "$JAVA_VERSION" "$JAVA_CANDIDATES"

  highlight_echo "开始同步 JobsMacEnv 到：$target_root"

  ensure_dir "$target_root"
  ensure_dir "$target_zsh_dir"
  ensure_dir "$target_custom_dir"
  ensure_dir "$target_bin_dir"
  ensure_dir "$target_root/assets"

  rm -rf "$old_target_scripts_dir" 2>/dev/null || true

  copy_file_if_changed "$source_zshrc" "$target_zshrc_template"
  copy_file_if_changed "$source_dir/README.md" "$target_readme"
  copy_file_if_changed "$source_dir/install.command" "$target_install"
  copy_file_if_changed "$source_dir/sync_env.txt" "$target_sync_file"

  copy_all_script_bundles "$source_scripts_dir" "$target_scripts_dir"

  copy_file_if_changed "$source_dir/zsh/bootstrap.zsh" "$target_zsh_dir/bootstrap.zsh"
  copy_file_if_changed "$source_dir/zsh/env_methods.zsh" "$target_zsh_dir/env_methods.zsh"
  copy_file_if_changed "$source_dir/zsh/user_mounts.zsh" "$target_zsh_dir/user_mounts.zsh"
  copy_file_if_changed "$source_dir/zsh/custom/shell_behavior.zsh" "$target_custom_dir/shell_behavior.zsh"

  if [[ -f "$source_dir/zsh/custom/path_drag_resolver.zsh" ]]; then
    copy_file_if_changed "$source_dir/zsh/custom/path_drag_resolver.zsh" "$target_custom_dir/path_drag_resolver.zsh"
  fi

  copy_file_if_changed "$source_dir/zsh/custom/local.zsh" "$target_custom_dir/local.zsh"

  if [[ -f "$target_custom_dir/legacy_functions.zsh" ]]; then
    rm -f "$target_custom_dir/legacy_functions.zsh"
    note_echo "已移除旧文件：$target_custom_dir/legacy_functions.zsh"
  fi

  write_file_if_changed "$target_env" "$(generate_env_content)"
  write_file_if_changed "$target_aliases" "$(generate_aliases_content)"
  write_file_if_changed "$target_zshrc_template" "$(generate_minimal_zshrc)"

  chmod +x "$target_install"

  verify_scripts_modules "$target_scripts_dir"

  install_bin_entry "$target_scripts_dir" "$target_bin_dir" list.command list
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" m5c.command m5c
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" flat.command flat
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" trs.command trs
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" gif.command gif
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" simios.command simios
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" pods.command pods
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" clean.command clean
  remove_obsolete_bin_entry "$target_bin_dir" dq
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" df.command df

  local old_long_entry="$target_bin_dir/dequarantine"
  if [[ -f "$old_long_entry" ]] && grep -Eq 'jobs_dq_|jobs_dequarantine_|解除 macOS quarantine|com\.apple\.quarantine' "$old_long_entry" 2>/dev/null; then
    rm -f "$old_long_entry"
    note_echo "已移除旧长命令入口：$old_long_entry"
  fi

  install_bin_entry "$target_scripts_dir" "$target_bin_dir" cor.command cor
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" decode.command decode
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" ts.command ts
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" download.command download

  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command to
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command mp4
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command mov
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command webm
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command mkv
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command avi
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command m4v
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command mp3
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command m4a
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command aac
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command wav
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command flac
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command ogg
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" to.command opus
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" install.command install
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" update.command update
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" shell.command shell
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" zz.command zz
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" x.command x
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" save.command save
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" rb.command rb
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" a.command a
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" b.command b
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" i.command i
  remove_obsolete_bin_entry "$target_bin_dir" flutter
  remove_obsolete_script_bin_entry "$target_scripts_dir" "$target_bin_dir" install_jdk17.command jdk17
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" fixfvm.command fixfvm
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" check1.command check1
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" check.command check
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" c.command c
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" d.command d
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" buildCheck.command buildCheck
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" apk.command apk
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" ipa.command ipa
  install_bin_entry "$target_scripts_dir" "$target_bin_dir" config.command config


  success_echo "已生成轻量入口文件：$target_zshrc_template"
  success_echo "已同步 Scripts 模块目录：$target_scripts_dir"

  prompt_replace_system_zshrc "$target_zshrc_template"

  if [[ -f "$HOME/.zshrc" ]]; then
    note_echo "如需立即生效，请执行：source ~/.zshrc"
  fi

  success_echo "同步完成"
  gray_echo "日志路径：$LOG_FILE"
}

main "$@"
