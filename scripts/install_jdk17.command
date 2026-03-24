#!/usr/bin/env bash

set -euo pipefail

has_java17() {
  [[ -x /usr/libexec/java_home ]] || return 1
  /usr/libexec/java_home -v 17 >/dev/null 2>&1
}

if has_java17; then
  echo "[OK] 已检测到 JDK 17，跳过安装。"
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[ERR] 未检测到 Homebrew，无法自动安装 JDK 17。"
  exit 1
fi

for candidate in "temurin@17" "zulu@17" "openjdk@17"; do
  echo "[TRY] $candidate"
  if [[ "$candidate" == openjdk@* ]]; then
    if brew install "$candidate"; then
      break
    fi
  else
    if brew install --cask "$candidate"; then
      break
    fi
  fi
done

if has_java17; then
  echo "[OK] JDK 17 安装完成。"
else
  echo "[ERR] 自动安装失败，请手动安装 JDK 17。"
  exit 1
fi
