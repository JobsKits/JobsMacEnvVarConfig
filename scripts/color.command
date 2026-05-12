#!/bin/zsh
# JobsMacEnv function module.
# 本文件由 JobsMacEnv 加载；不要在这里写自动执行流程。

# 🔥 颜色格式转换器：cor 🔥
# 用法：
# - cor                         进入交互模式，可连续输入颜色值
# - cor '#D2D4DE'               转换单个颜色，# 开头建议加引号
# - cor 'rgba(210,212,222,0.5)' 转换 rgba，括号内容建议加引号
#
# 注意：这里不要再用 bash heredoc 包一层脚本。
# heredoc 会占用 bash 的 stdin，导致交互模式里的 read 读不到键盘输入。
jobs_cor_supports_truecolor() {
  emulate -L zsh
  [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]
}

jobs_cor_title_color() {
  emulate -L zsh

  local esc=$'\033'
  if jobs_cor_supports_truecolor; then
    printf "%s" "${esc}[38;2;210;212;222m"
  else
    printf "%s" "${esc}[37m"
  fi
}

jobs_cor_to_hex() {
  emulate -L zsh
  printf "%02X" "$1"
}

jobs_cor_hex_to_dec() {
  emulate -L zsh
  printf "%d" "$(( 16#$1 ))"
}

jobs_cor_alpha_float_to_255() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%d", (v * 255) + 0.5) }'
}

jobs_cor_alpha_255_to_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { printf("%.2f", v / 255) }'
}

jobs_cor_clamp_alpha_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%.2f", v) }'
}

jobs_cor_sanitize_input() {
  emulate -L zsh
  print -r -- "$1" | tr -d '[:space:]' | tr -d '"' | tr -d "'"
}

jobs_cor_upper_hex() {
  emulate -L zsh
  print -r -- "$1" | tr '[:lower:]' '[:upper:]'
}

jobs_cor_rel_luma() {
  emulate -L zsh
  awk -v r="$1" -v g="$2" -v b="$3" 'BEGIN { printf("%.0f", 0.2126 * r + 0.7152 * g + 0.0722 * b) }'
}

jobs_cor_pick_fg_code() {
  emulate -L zsh

  local l
  l="$(jobs_cor_rel_luma "$1" "$2" "$3")"
  if (( l > 186 )); then
    print -r -- "30"
  else
    print -r -- "97"
  fi
}

jobs_cor_rgb_to_ansi256() {
  emulate -L zsh

  local r="$1" g="$2" b="$3"
  if (( r == g && g == b )); then
    if (( r < 8 )); then
      print -r -- 16
      return 0
    elif (( r > 248 )); then
      print -r -- 231
      return 0
    else
      print -r -- $(( 232 + ((r - 8) * 24 / 247) ))
      return 0
    fi
  fi

  local rc=$(( r * 5 / 255 ))
  local gc=$(( g * 5 / 255 ))
  local bc=$(( b * 5 / 255 ))
  print -r -- $(( 16 + 36 * rc + 6 * gc + bc ))
}

jobs_cor_show_block() {
  emulate -L zsh

  local rr="$1" gg="$2" bb="$3" label="$4" fg idx
  fg="$(jobs_cor_pick_fg_code "$rr" "$gg" "$bb")"

  if jobs_cor_supports_truecolor; then
    printf "\033[48;2;%d;%d;%dm" "$rr" "$gg" "$bb"
  else
    idx="$(jobs_cor_rgb_to_ansi256 "$rr" "$gg" "$bb")"
    printf "\033[48;5;%sm" "$idx"
  fi

  printf "\033[%sm" "$fg"
  printf "  %-18s  " "$label"
  printf "\033[0m"
}

jobs_cor_parse_input() {
  emulate -L zsh

  local raw="$1" input hex rr gg bb aa nums R G B A A255
  input="$(jobs_cor_sanitize_input "$raw")"

  if [[ "$input" =~ '^0[xX][0-9a-fA-F]{8}$' ]]; then
    hex="${input[3,-1]}"
    hex="$(jobs_cor_upper_hex "$hex")"
    aa="${hex[1,2]}"
    rr="${hex[3,4]}"
    gg="${hex[5,6]}"
    bb="${hex[7,8]}"

    typeset -g JOBS_COR_R="$(jobs_cor_hex_to_dec "$rr")"
    typeset -g JOBS_COR_G="$(jobs_cor_hex_to_dec "$gg")"
    typeset -g JOBS_COR_B="$(jobs_cor_hex_to_dec "$bb")"
    typeset -g JOBS_COR_AA_HEX="$aa"
    typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_alpha_255_to_float "$(jobs_cor_hex_to_dec "$aa")")"
    return 0
  fi

  if [[ "$input" =~ '^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$' ]]; then
    hex="${input[2,-1]}"
    hex="$(jobs_cor_upper_hex "$hex")"
    rr="${hex[1,2]}"
    gg="${hex[3,4]}"
    bb="${hex[5,6]}"

    typeset -g JOBS_COR_R="$(jobs_cor_hex_to_dec "$rr")"
    typeset -g JOBS_COR_G="$(jobs_cor_hex_to_dec "$gg")"
    typeset -g JOBS_COR_B="$(jobs_cor_hex_to_dec "$bb")"

    if (( ${#hex} == 8 )); then
      aa="${hex[7,8]}"
      typeset -g JOBS_COR_AA_HEX="$aa"
      typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_alpha_255_to_float "$(jobs_cor_hex_to_dec "$aa")")"
    else
      typeset -g JOBS_COR_AA_HEX="FF"
      typeset -g JOBS_COR_A_FLOAT="1.00"
    fi
    return 0
  fi

  if [[ "$input" =~ '^rgba?\(' ]]; then
    nums="$(print -r -- "$input" | sed -E 's/^rgba?\(|\)$//g')"
    local -a parts
    parts=("${(@s:,:)nums}")

    R="${parts[1]:-}"
    G="${parts[2]:-}"
    B="${parts[3]:-}"
    A="${parts[4]:-1}"

    [[ -n "$R" && -n "$G" && -n "$B" ]] || return 1

    typeset -g JOBS_COR_R="${R%%.*}"
    typeset -g JOBS_COR_G="${G%%.*}"
    typeset -g JOBS_COR_B="${B%%.*}"

    if ! [[ "$JOBS_COR_R" =~ '^[0-9]+$' && "$JOBS_COR_G" =~ '^[0-9]+$' && "$JOBS_COR_B" =~ '^[0-9]+$' ]]; then
      return 1
    fi

    if (( JOBS_COR_R < 0 || JOBS_COR_R > 255 || JOBS_COR_G < 0 || JOBS_COR_G > 255 || JOBS_COR_B < 0 || JOBS_COR_B > 255 )); then
      return 1
    fi

    if ! [[ "$A" =~ '^([0-9]+([.][0-9]+)?|[.][0-9]+)$' ]]; then
      return 1
    fi

    typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_clamp_alpha_float "$A")"
    A255="$(jobs_cor_alpha_float_to_255 "$JOBS_COR_A_FLOAT")"
    typeset -g JOBS_COR_AA_HEX="$(jobs_cor_to_hex "$A255")"
    return 0
  fi

  return 1
}

jobs_cor_format_and_print_all() {
  emulate -L zsh

  local raw="$1" RR GG BB AA
  RR="$(jobs_cor_to_hex "$JOBS_COR_R")"
  GG="$(jobs_cor_to_hex "$JOBS_COR_G")"
  BB="$(jobs_cor_to_hex "$JOBS_COR_B")"
  AA="$JOBS_COR_AA_HEX"

  printf "\n\033[1m输入：%s\033[0m\n" "$raw"
  printf "%s\n" "----------------------------------------"
  printf "HEX（不透明）:  #%s%s%s\n" "$RR" "$GG" "$BB"
  printf "HEX（含透明） :  #%s%s%s%s\n" "$RR" "$GG" "$BB" "$AA"
  printf "RGB           :  rgb(%d, %d, %d)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B"
  printf "RGBA          :  rgba(%d, %d, %d, %.2f)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "$JOBS_COR_A_FLOAT"
  printf "0x 格式       :  0x%s%s%s%s\n" "$AA" "$RR" "$GG" "$BB"
  jobs_cor_show_block "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "原色 #${RR}${GG}${BB}"
  printf "\n\n"
}

jobs_cor_print_title() {
  emulate -L zsh

  local c reset=$'\033[0m'
  c="$(jobs_cor_title_color)"
  printf "%b================== 颜色格式转换器 ==================%b\n" "$c" "$reset"
  printf "%b支持：#RRGGBB / #RRGGBBAA / rgb() / rgba() / 0xAARRGGBB%b\n" "$c" "$reset"
  printf "%b输出：HEX / RGB / RGBA / 0xAARRGGBB，并显示终端色块预览%b\n" "$c" "$reset"
  printf "\n"
}

jobs_cor_convert_once() {
  emulate -L zsh

  local user_input="$1"
  if jobs_cor_parse_input "$user_input"; then
    jobs_cor_format_and_print_all "$user_input"
  else
    print -P "%F{red}❌ 无法识别：$user_input%f"
    return 1
  fi
}

jobs_cor_interactive_loop() {
  emulate -L zsh

  local user_input
  while true; do
    read -r "user_input?请输入颜色值（q 退出）： " || {
      printf "\n"
      break
    }

    [[ -z "$user_input" ]] && continue

    case "$user_input" in
      q|Q|quit|QUIT|exit|EXIT)
        print -P "%F{green}✅ 已退出 cor%f"
        break
        ;;
    esac

    if jobs_cor_parse_input "$user_input"; then
      jobs_cor_format_and_print_all "$user_input"
    else
      print -P "%F{red}❌ 无法识别：$user_input%f"
      print -r -- "示例：#D2D4DE、#D2D4DE80、rgb(210,212,222)、rgba(210,212,222,0.5)、0x80D2D4DE"
      printf "\n"
    fi
  done
}

cor() {
  emulate -L zsh

  jobs_cor_print_title

  if (( $# > 0 )); then
    local failed=0 user_input
    for user_input in "$@"; do
      jobs_cor_convert_once "$user_input" || failed=1
    done
    return "$failed"
  fi

  jobs_cor_interactive_loop
}

