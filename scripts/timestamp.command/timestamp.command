#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# ================================== 时间戳转换 ==================================
# ts
# 交互式输入 Unix 时间戳，并输出完整时间：年、月、日、时、分、秒、周几、时区。
# 时区选择：直接回车使用当前系统时区；输入任意字符后用 fzf 选择其他时区。
# 自动识别常见时间戳精度：秒 / 毫秒 / 微秒 / 纳秒。
unalias ts 2>/dev/null
ts() {
  emulate -L zsh
  setopt no_nomatch

  local input tz_trigger selected_tz

  if ! command -v python3 >/dev/null 2>&1; then
    print -P "%F{red}❌ 未检测到 python3，无法转换时间戳%f"
    return 1
  fi

  _jobs_ts_read_line() {
    emulate -L zsh

    local prompt="$1"
    local ch line=""

    printf "%s" "$prompt" > /dev/tty

    while true; do
      if ! IFS= read -r -s -k 1 ch < /dev/tty; then
        printf "\n" > /dev/tty
        return 130
      fi

      case "$ch" in
        $'\e')
          printf "\n" > /dev/tty
          return 130
          ;;
        $'\n'|$'\r')
          printf "\n" > /dev/tty
          REPLY="$line"
          return 0
          ;;
        $'\177'|$'\b')
          if [[ -n "$line" ]]; then
            line="${line[1,-2]}"
            printf '\b \b' > /dev/tty
          fi
          ;;
        $'\003'|$'\004')
          printf "\n" > /dev/tty
          return 130
          ;;
        *)
          line+="$ch"
          printf "%s" "$ch" > /dev/tty
          ;;
      esac
    done
  }

  while true; do
    if ! _jobs_ts_read_line "请输入时间戳（Esc 退出）："; then
      print -P "%F{yellow}已取消%f"
      return 130
    fi

    input="$REPLY"

    if [[ -n "${input//[[:space:]]/}" ]]; then
      break
    fi

    print -P "%F{red}❌ 时间戳不能为空%f"
  done

  if ! _jobs_ts_read_line "时区：直接回车使用当前时区；输入任意字符后用 fzf 选择其他时区（Esc 退出）："; then
    print -P "%F{yellow}已取消%f"
    return 130
  fi

  tz_trigger="$REPLY"

  if [[ -n "${tz_trigger//[[:space:]]/}" ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      print -P "%F{red}❌ 未检测到 fzf。先安装：brew install fzf%f"
      return 1
    fi

    selected_tz="$(
      python3 - <<'PY' | fzf --prompt='选择时区：' --height=60% --border
import os

zones = set()
try:
    from zoneinfo import available_timezones
    zones.update(available_timezones())
except Exception:
    base = "/usr/share/zoneinfo"
    skip_dirs = {"posix", "right", "SystemV", "Etc"}
    skip_files = {"localtime", "posixrules", "leapseconds", "tzdata.zi", "zone.tab", "zone1970.tab", "iso3166.tab"}
    if os.path.isdir(base):
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in skip_dirs and not d.startswith(".")]
            for name in files:
                if name in skip_files or name.startswith("."):
                    continue
                full_path = os.path.join(root, name)
                rel_path = os.path.relpath(full_path, base)
                if os.path.sep in rel_path:
                    zones.add(rel_path.replace(os.path.sep, "/"))

for zone in sorted(zones):
    print(zone)
PY
    )"

    if [[ -z "$selected_tz" ]]; then
      print -P "%F{yellow}⚠️  未选择时区，已取消%f"
      return 130
    fi
  fi

  python3 - "$input" "$selected_tz" <<'PY'
import os
import sys
import time
from decimal import Decimal, InvalidOperation
from datetime import datetime

try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def local_zone_name(dt):
    for path in ("/etc/localtime", "/var/db/timezone/localtime"):
        try:
            real_path = os.path.realpath(path)
        except Exception:
            continue
        marker = "/zoneinfo/"
        if marker in real_path:
            return real_path.split(marker, 1)[1]
    return os.environ.get("TZ") or dt.tzname() or "当前系统时区"


def parse_timestamp(raw):
    value = raw.strip()
    if value.startswith("@"):
        value = value[1:]

    try:
        number = Decimal(value)
    except InvalidOperation:
        raise ValueError("时间戳格式不正确，只支持数字，例如 1715400000 或 1715400000000")

    plain_digits = value.lstrip("+-")
    unit = "秒"
    seconds = number

    if "." not in plain_digits and "e" not in plain_digits.lower():
        digits = plain_digits.lstrip("0") or "0"
        length = len(digits)
        if length >= 19:
            seconds = number / Decimal(1_000_000_000)
            unit = "纳秒"
        elif length >= 16:
            seconds = number / Decimal(1_000_000)
            unit = "微秒"
        elif length >= 13:
            seconds = number / Decimal(1_000)
            unit = "毫秒"

    return float(seconds), unit


def format_offset(dt):
    offset = dt.strftime("%z")
    if len(offset) == 5:
        return f"{offset[:3]}:{offset[3:]}"
    return offset or "未知偏移"


raw = sys.argv[1]
zone_name = sys.argv[2] if len(sys.argv) > 2 else ""

try:
    seconds, unit = parse_timestamp(raw)

    if zone_name:
        if ZoneInfo is not None:
            dt = datetime.fromtimestamp(seconds, ZoneInfo(zone_name))
        elif hasattr(time, "tzset"):
            os.environ["TZ"] = zone_name
            time.tzset()
            dt = datetime.fromtimestamp(seconds).astimezone()
        else:
            raise RuntimeError("当前 python3 不支持指定时区转换")
        zone_label = zone_name
    else:
        dt = datetime.fromtimestamp(seconds).astimezone()
        zone_label = local_zone_name(dt)

    print(f"时间戳：{raw.strip()}（识别为：{unit}）")
    print(f"完整时间：{dt.year:04d}年{dt.month:02d}月{dt.day:02d}日 {dt.hour:02d}:{dt.minute:02d}:{dt.second:02d} {WEEKDAYS[dt.weekday()]}")
    print(f"时区：{zone_label}（UTC{format_offset(dt)}，{dt.tzname() or '未知缩写'}）")
except Exception as exc:
    print(f"❌ 转换失败：{exc}", file=sys.stderr)
    sys.exit(1)
PY
}

