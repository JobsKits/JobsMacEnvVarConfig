# 交互式终端默认行为
# 单独拆出来，后面你想关掉某个行为，只改这个文件即可

# 打开终端默认进入桌面
if [[ -o interactive ]] && [[ -d "$HOME/Desktop" ]]; then
  cd "$HOME/Desktop"
fi
