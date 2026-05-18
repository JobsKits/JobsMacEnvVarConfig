# Jobs Clear Chrome Downloads

![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")

[toc]

这是 `clr` 命令配套的本地 Chrome 扩展。

用途：调用 Chrome `downloads` API 清除浏览器下载历史，不删除本地真实文件。

## v6 说明

manifest.json 使用合法固定 `key`，扩展 ID 固定为：

```text
fglcbiaddbchgemaegkjejejikhilpon
```

如果你之前已经加载过旧版，Chrome 扩展页里可能还是旧 ID。此时可以二选一：

1. 直接告诉 `clr` 使用旧 ID：

```zsh
clr --extension-id 旧版扩展卡片里显示的32位ID
```

2. 在 `chrome://extensions/` 移除旧的 `Jobs Clear Chrome Downloads`，然后重新加载本目录。
