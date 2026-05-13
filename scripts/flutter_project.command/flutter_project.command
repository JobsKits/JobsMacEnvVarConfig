#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# ================================== Flutter 项目辅助命令模块 ==================================
# 兼容原版位置：Scripts/flutter_project.command/flutter_project.command
# flutter 的具体实现复用当前版本的 Scripts/_lib/jobs_flutter_lib.zsh。

_jobs_flutter_project_module_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
_jobs_flutter_project_env_home="${JOBS_MAC_ENV_HOME:-$HOME/.JobsMacEnv}"
_jobs_flutter_project_lib_candidates=(
  "${_jobs_flutter_project_module_dir}/../_lib/jobs_flutter_lib.zsh"
  "${_jobs_flutter_project_env_home}/Scripts/_lib/jobs_flutter_lib.zsh"
)

_jobs_flutter_project_lib_loaded="false"
for _jobs_flutter_project_lib in "${_jobs_flutter_project_lib_candidates[@]}"; do
  if [[ -f "$_jobs_flutter_project_lib" ]]; then
    source "$_jobs_flutter_project_lib"
    _jobs_flutter_project_lib_loaded="true"
    break
  fi
done

if [[ "$_jobs_flutter_project_lib_loaded" != "true" ]]; then
  print -u2 "JobsMacEnv: 缺少 Flutter 私有库：jobs_flutter_lib.zsh"
  print -u2 "JobsMacEnv: 请重新执行 install.command"
  unset _jobs_flutter_project_module_dir _jobs_flutter_project_env_home _jobs_flutter_project_lib_candidates _jobs_flutter_project_lib _jobs_flutter_project_lib_loaded
  return 0 2>/dev/null || true
fi

# 🔥 flutter() 重载（优先 FVM）🔥
flutter() {
  jobs_flutter_flutter_impl "$@"
}

unset _jobs_flutter_project_module_dir _jobs_flutter_project_env_home _jobs_flutter_project_lib_candidates _jobs_flutter_project_lib _jobs_flutter_project_lib_loaded
