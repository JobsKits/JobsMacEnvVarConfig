# ========================
# 环境工具函数
# ========================

jobs_log() {
  echo "[jobs-env] $1"
}

jobs_detect_arch() {
  uname -m
}

jobs_brew_prefix() {
  if command -v brew >/dev/null 2>&1; then
    brew --prefix
  else
    echo ""
  fi
}

jobs_source_if_exists() {
  local file="$1"
  [[ -f "$file" ]] && source "$file"
}

jobs_path_has() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

jobs_path_add() {
  local dir="$1"
  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] || return 0
  jobs_path_has "$dir" || PATH="$dir:$PATH"
}

jobs_path_append() {
  local dir="$1"
  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] || return 0
  jobs_path_has "$dir" || PATH="$PATH:$dir"
}

jobs_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

jobs_resolve_java_home() {
  local version="$1"
  local java_home=""

  if [[ -x /usr/libexec/java_home ]]; then
    java_home=$(/usr/libexec/java_home -v "$version" 2>/dev/null || true)
  fi

  if [[ -n "$java_home" && -d "$java_home" ]]; then
    printf "%s" "$java_home"
    return 0
  fi

  local candidates=(
    "/Library/Java/JavaVirtualMachines/temurin-${version}.jdk/Contents/Home"
    "/Library/Java/JavaVirtualMachines/zulu-${version}.jdk/Contents/Home"
    "/Library/Java/JavaVirtualMachines/openjdk-${version}.jdk/Contents/Home"
    "/opt/homebrew/opt/openjdk@${version}/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk@${version}/libexec/openjdk.jdk/Contents/Home"
  )

  local item
  for item in "${candidates[@]}"; do
    if [[ -d "$item" ]]; then
      printf "%s" "$item"
      return 0
    fi
  done

  return 1
}

jobs_setup_java() {
  local version="$1"
  local java_home=""

  java_home="$(jobs_resolve_java_home "$version" 2>/dev/null || true)"

  if [[ -n "$java_home" && -d "$java_home" ]]; then
    export JAVA_HOME="$java_home"
    jobs_path_add "$JAVA_HOME/bin"
  fi
}

jobs_setup_android() {
  local sdk_dir="$1"
  [[ -d "$sdk_dir" ]] || return 0

  export ANDROID_SDK_ROOT="$sdk_dir"
  export ANDROID_HOME="$sdk_dir"

  jobs_path_add "$sdk_dir/platform-tools"
  jobs_path_add "$sdk_dir/cmdline-tools/latest/bin"
  jobs_path_add "$sdk_dir/emulator"
  jobs_path_add "$sdk_dir/tools"
  jobs_path_add "$sdk_dir/tools/bin"
}

jobs_setup_flutter() {
  local use_fvm="$1"
  local candidates_csv="$2"

  if [[ "$use_fvm" == "true" ]] && jobs_command_exists fvm; then
    flutter() {
      command fvm flutter "$@"
    }
    return 0
  fi

  local old_ifs="$IFS"
  IFS=','
  local item
  for item in $candidates_csv; do
    item="${item/#\$HOME/$HOME}"
    if [[ -d "$item" ]]; then
      jobs_path_add "$item"
      break
    fi
  done
  IFS="$old_ifs"
}

jobs_setup_node() {
  local enable_corepack="$1"
  local nvm_dir="$2"

  export NVM_DIR="$nvm_dir"

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  fi

  if [[ "$enable_corepack" == "true" ]] && jobs_command_exists corepack; then
    true
  fi
}

jobs_setup_rust() {
  local cargo_home="$1"
  export CARGO_HOME="$cargo_home"
  jobs_path_add "$CARGO_HOME/bin"
}

jobs_setup_pyenv() {
  local pyenv_root="$1"
  if [[ -d "$pyenv_root" ]]; then
    export PYENV_ROOT="$pyenv_root"
    jobs_path_add "$PYENV_ROOT/bin"
    if jobs_command_exists pyenv; then
      eval "$(pyenv init - zsh)"
    fi
  fi
}

jobs_setup_rbenv() {
  local rbenv_root="$1"
  if [[ -d "$rbenv_root" ]]; then
    export RBENV_ROOT="$rbenv_root"
    jobs_path_add "$RBENV_ROOT/bin"
    if jobs_command_exists rbenv; then
      eval "$(rbenv init - zsh)"
    fi
  fi
}

jobs_setup_go() {
  local gopath="$1"
  export GOPATH="$gopath"
  jobs_path_add "$GOPATH/bin"
}
