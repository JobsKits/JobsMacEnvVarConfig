# 用户挂载入口
# 这里只负责按顺序加载外挂文件

export JOBS_USER_MOUNTS_DIR="$JOBS_MAC_ENV_HOME/zsh/custom"

jobs_source_if_exists() {
  local file="$1"
  [[ -f "$file" ]] && source "$file"
}

jobs_source_if_exists "$JOBS_USER_MOUNTS_DIR/shell_behavior.zsh"
jobs_source_if_exists "$JOBS_USER_MOUNTS_DIR/path_drag_resolver.zsh"
jobs_source_if_exists "$JOBS_USER_MOUNTS_DIR/legacy_functions.zsh"
jobs_source_if_exists "$JOBS_USER_MOUNTS_DIR/local.zsh"
