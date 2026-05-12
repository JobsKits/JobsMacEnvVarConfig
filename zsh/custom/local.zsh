# JobsMacEnv 个人函数加载器
# local.zsh 只负责加载 Scripts/*.command，具体功能按模块维护。

export JOBS_MAC_ENV_HOME="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"
[[ -n "${JOBS_MAC_ENV_HOME_OVERRIDE:-}" ]] && export JOBS_MAC_ENV_HOME="$JOBS_MAC_ENV_HOME_OVERRIDE"

# 新目录 Scripts 优先；旧目录 scripts 仅作为兜底兼容。
_jobs_scripts_candidates=(
  "$JOBS_MAC_ENV_HOME/Scripts"
  "$HOME/.JobsMacEnv/Scripts"
  "$JOBS_MAC_ENV_HOME/scripts"
  "$HOME/.JobsMacEnv/scripts"
)

JOBS_MAC_ENV_SCRIPTS_DIR=""
for _jobs_scripts_dir in "${_jobs_scripts_candidates[@]}"; do
  if [[ -d "$_jobs_scripts_dir" ]]; then
    JOBS_MAC_ENV_SCRIPTS_DIR="$_jobs_scripts_dir"
    break
  fi
done

if [[ -z "$JOBS_MAC_ENV_SCRIPTS_DIR" ]]; then
  JOBS_MAC_ENV_SCRIPTS_DIR="$HOME/.JobsMacEnv/Scripts"
  print -u2 "JobsMacEnv: Scripts 模块目录不存在：$JOBS_MAC_ENV_SCRIPTS_DIR"
  print -u2 "JobsMacEnv: 请重新执行 install.command"
  unset _jobs_scripts_candidates _jobs_scripts_dir
  return 0 2>/dev/null || true
fi

_jobs_module_files=(
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
)

_jobs_missing_modules=()
_jobs_failed_modules=()

jobs_source_scripts_module() {
  local module_file_name="$1"
  local module_file="$JOBS_MAC_ENV_SCRIPTS_DIR/$module_file_name"

  if [[ ! -f "$module_file" ]]; then
    _jobs_missing_modules+=("$module_file_name")
    return 0
  fi

  if ! source "$module_file"; then
    _jobs_failed_modules+=("$module_file_name")
    return 0
  fi
}

for _jobs_module_file in "${_jobs_module_files[@]}"; do
  jobs_source_scripts_module "$_jobs_module_file"
done

if (( ${#_jobs_missing_modules[@]} > 0 )); then
  print -u2 "JobsMacEnv: Scripts 模块缺失：${_jobs_missing_modules[*]}"
  print -u2 "JobsMacEnv: 当前模块目录：$JOBS_MAC_ENV_SCRIPTS_DIR"
  print -u2 "JobsMacEnv: 请重新执行 install.command 修复。"
fi

if (( ${#_jobs_failed_modules[@]} > 0 )); then
  print -u2 "JobsMacEnv: Scripts 模块加载失败：${_jobs_failed_modules[*]}"
  print -u2 "JobsMacEnv: 当前模块目录：$JOBS_MAC_ENV_SCRIPTS_DIR"
  print -u2 "JobsMacEnv: 可执行：zsh -n $JOBS_MAC_ENV_SCRIPTS_DIR/模块名.command 定位语法问题。"
fi

unset _jobs_scripts_candidates _jobs_scripts_dir _jobs_module_files _jobs_module_file _jobs_missing_modules _jobs_failed_modules
unfunction jobs_source_scripts_module 2>/dev/null || true
