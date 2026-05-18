# clr.command

## 功能

清空 Google Chrome 浏览器下载历史，不删除已经下载到本地的真实文件。

## 命令

```zsh
clr
```

## 现实结论

Chrome 没有给普通 macOS 命令行提供稳定的「清空下载历史」接口。坐标点击 `chrome://downloads/` 右上角「全部清除」不稳定；直接改 Chrome `History` 数据库也不能稳定影响正在运行的 Chrome 内存状态。

这一版改为可靠方案：使用一个极小的本地 Chrome 扩展，通过 Chrome `downloads` API 清除下载历史。

## v6 修正

- manifest.json 使用合法固定 `key`，固定扩展 ID 为：`fglcbiaddbchgemaegkjejejikhilpon`。
- 同时兼容已经加载过的旧版扩展 ID，会从 Chrome `Preferences` / `Secure Preferences` 自动识别。
- 如果 Chrome 扩展页已经显示装好了，但 `clr` 仍识别不到，可手动保存一次扩展 ID。

```zsh
clr --extension-id 扩展卡片里显示的32位ID
```

例如你当前截图里的 ID 可执行：

```zsh
clr --extension-id bceffimgdjebjemfhcfkombngddhmdee
```

## 第一次使用

```zsh
clr --install-extension
```

然后按提示操作：

1. 打开 Chrome 的 `chrome://extensions/`
2. 开启右上角「开发者模式」
3. 点击「加载未打包的扩展程序」
4. 选择脚本提示的扩展目录
5. 加载完成后重新执行：

```zsh
clr
```

如果之前加载过旧版且仍不生效，先在 `chrome://extensions/` 移除旧的 `Jobs Clear Chrome Downloads`，再重新加载目录。

## 常用参数

```zsh
clr
clr --install-extension
clr --extension-id bceffimgdjebjemfhcfkombngddhmdee
clr --open-only
clr --open
clr --yes
```

说明：

- `clr`：触发下载历史清理。
- `clr --install-extension`：生成并打开本地 Chrome 扩展安装指引。
- `clr --extension-id ID`：手动指定并保存 Chrome 扩展卡片里的 32 位 ID。
- `clr --open-only`：只打开 `chrome://downloads/`，不清理。
- `clr --open`：清理触发后打开 `chrome://downloads/` 查看结果。
- `clr --yes`：跳过回车确认，适合脚本化调用。

## 边界

- 只清除 Chrome 下载历史。
- 不删除 `~/Downloads` 或其它目录里的真实文件。
- 不退出 Chrome。
- 不备份 Chrome History 数据库。
- 不关闭或替换原来的网页。

## 日志

```text
/tmp/clr.log
```
