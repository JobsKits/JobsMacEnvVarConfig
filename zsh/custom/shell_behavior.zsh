# 交互式终端默认行为
# 单独拆出来，后面你想关掉某个行为，只改这个文件即可。
# 注意：这里不再定义任何终端自定义命令。
# 终端可输入的自定义命令必须统一放在 Scripts/<命令>.command/<命令>.command。

# 打开终端默认进入桌面。
if [[ -o interactive ]] && [[ -d "$HOME/Desktop" ]]; then
  cd "$HOME/Desktop"
fi
