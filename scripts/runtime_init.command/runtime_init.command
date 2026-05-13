#!/bin/zsh
# JobsMacEnv runtime initialization.
# 只放交互式 shell 启动时需要初始化的轻量内容。

# jenv / rbenv：存在才初始化，避免新机器首次启动报错。
if command -v jenv >/dev/null 2>&1; then
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

# Dart completion：路径由 Flutter 独立命令脚本中的 JOBS_DART_CLI_COMPLETION_FILE 配置。
if [[ -n "${JOBS_DART_CLI_COMPLETION_FILE:-}" && -f "$JOBS_DART_CLI_COMPLETION_FILE" ]]; then
  source "$JOBS_DART_CLI_COMPLETION_FILE"
fi
