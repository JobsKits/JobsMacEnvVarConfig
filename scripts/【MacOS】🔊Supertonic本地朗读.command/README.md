# `【MacOS】🔊Supertonic本地朗读.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 说明：终端启动时不会打印本 README 全文，只会打印脚本内部维护的简要自述。本 README 用于展开说明、后续维护和排查。

## 🔥 <font id=前言>前言</font> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这个脚本用于把 [**Supertonic**](https://github.com/supertone-inc/supertonic) 本地 TTS 封装成 MacOS 可双击 / 可终端调用的 `.command`。

核心目标很简单：

```shell
输入文本
电脑朗读
```

例如进入脚本后输入：

```text
fuck
```

脚本会调用本机 `http://127.0.0.1:7788/v1/tts` 生成 `wav`，然后用 MacOS 自带 `afplay` 直接播放。

---

## 一、适用场景 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 已经在本机安装过 `supertonic`，或者允许脚本按提示创建 `~/Desktop/supertonic-venv`。
- 希望不用反复输入 `curl`。
- 希望在终端里只输入要朗读的文本。
- 希望脚本自动检查本地服务，没启动就自动后台启动。
- 希望输出音频文件可追溯、日志可排查。

---

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 2.1、通过 `list` 菜单运行

安装 / 同步 `🌍JobsMacEnvVarConfigs` 后执行：

```shell
list
```

在菜单里选择：

```text
本地朗读    tts    调用【MacOS】🔊Supertonic本地朗读.command
```

### 2.2、通过终端短命令运行

安装 / 同步后可以直接执行：

```shell
tts "Hello, this is a local TTS test."
```

### 2.3、双击脚本运行

双击：

```text
【MacOS】🔊Supertonic本地朗读.command
```

按提示回车后，直接输入要朗读的文本即可。

---

## 三、执行前检查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

脚本默认读取这个虚拟环境：

```shell
~/Desktop/supertonic-venv
```

也就是你之前安装用的路径：

```shell
cd ~/Desktop
source supertonic-venv/bin/activate
python -m pip install 'supertonic[serve]'
```

如果你的虚拟环境不在这个位置，可以临时指定：

```shell
SUPERTONIC_VENV_DIR="/你的/venv/路径" ./"【MacOS】🔊Supertonic本地朗读.command"
```

---

## 四、交互命令 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入脚本后支持这些命令：

| 命令 | 作用 |
| --- | --- |
| `直接输入文本` | 立即朗读 |
| `:lang en` | 切换语言 |
| `:lang auto` | 自动判断，默认模式 |
| `:lang na` | Supertonic fallback 模式 |
| `:zh-engine say` | 中文走 macOS say，默认推荐 |
| `:zh-engine supertonic` | 中文也强制走 Supertonic，不推荐 |
| `:zh-voices` | 查看本机中文语音 |
| `:zh-voice Tingting` | 指定中文语音 |
| `:zh-rate 200` | 指定中文语速 |
| `:voice F1` | 切换声音 |
| `:speed 1.2` | 切换语速 |
| `:steps 10` | 切换质量步数 |
| `:list` | 查看支持语言 |
| `:docs` | 打开接口文档 |
| `:config` | 查看当前配置 |
| `:stop` | 停止本脚本启动的后台服务 |
| `:quit` | 退出脚本 |

---

## 五、语言说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Supertonic 可以通过 `lang` 调节语言。

但要注意：当前官方公开语言列表没有 `zh` / 中文。

脚本策略：

| 文本类型 | 自动语言 |
| --- | --- |
| 英文 / 拉丁字符 | `en` |
| 日文假名 | `ja` |
| 韩文 | `ko` |
| 中文汉字 | `na` |

中文默认不再走 Supertonic 的 `na` fallback，而是走 macOS 原生 `say` 中文语音。原因是 Supertonic 当前没有 `zh` 中文模型，`na` 只能出声，不能保证中文发音正确。英语、日语、韩语等支持语言仍走 Supertonic。

---

## 六、输出与日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

音频默认输出到：

```text
脚本所在目录/outputs/
```

主日志：

```text
/tmp/【MacOS】🔊Supertonic本地朗读.log
```

服务日志：

```text
/tmp/【MacOS】🔊Supertonic本地朗读.server.log
```

---

## 七、风险说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 脚本不会使用 `sudo`。
- 脚本不会删除你的文件。
- 如果本地服务没启动，脚本会后台启动 `supertonic serve`。
- 如果虚拟环境缺失，脚本会询问是否自动创建 / 修复；直接回车会跳过，不会默认安装。
- 退出脚本不一定关闭后台服务；需要关闭时输入 `:stop`。

---

## 八、未执行声明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

当前生成环境无法执行 MacOS 本机的 `supertonic serve`，因此未实际播放音频。

复制到 Mac 后建议执行：

```shell
zsh -n 'scripts/【MacOS】🔊Supertonic本地朗读.command/【MacOS】🔊Supertonic本地朗读.command'
```

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>


## macOS 中文语音设置

如果中文仍然发音不自然，先在脚本里执行：

```text
:zh-voices
```

如果没有列出中文语音，请到 macOS 系统设置里下载中文朗读声音。下载完成后重新打开终端，再执行：

```text
:zh-voices
:zh-voice Tingting
你好，这是中文朗读测试。
```

也可以临时强制中文继续走 Supertonic，但不推荐：

```text
:zh-engine supertonic
你好，这是中文朗读测试。
```
