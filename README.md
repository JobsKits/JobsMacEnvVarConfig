# 🌍 [**JobsMacEnvVarConfig**](https://github.com/JobsKits/JobsMacEnvVarConfig)

![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")

[toc]

## 🔥 <font id=前言>前言</font>

* 这是一个面向 **MacOS** 的个人开发环境配置同步项目。

* 它把零散堆在 `~/.zshrc`、`~/.bash_profile` 里的环境变量、PATH、别名和个人命令拆分成模块，并通过 `install.command` 同步到用户目录 `~/.JobsMacEnv`。

## 一、适合解决什么问题 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 新 Mac 初始化开发环境时，快速恢复常用 Shell 配置。
- 避免把所有配置都塞进一个巨大的 `~/.zshrc`。
- 统一管理 **Java**、**Android**、**Flutter**、**Node**、**Rust**、**Python**、**Ruby**、**Go** 等开发环境入口。
- 让系统级 `~/.zshrc` 保持轻量，只负责加载 `~/.JobsMacEnv`。
- 支持本机私有配置和公共配置分离。

## 二、目录结构 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
.
├── install.command                 # 主安装 / 同步脚本
├── sync_env.txt                    # 声明式环境配置
├── icon.png                        # 项目图标
├── Sys/
│   ├── .zshrc                      # 轻量 zsh 主入口模板
│   ├── .zprofile
│   ├── .zshenv
│   ├── .zlogin
│   ├── .zlogout
│   ├── .bashrc
│   └── .bash_profile
├── scripts/
│   └── install_jdk17.command       # JDK 17 独立安装脚本
└── zsh/
    ├── bootstrap.zsh               # 启动层：交互式环境、Oh My Zsh、Homebrew
    ├── env_methods.zsh             # 环境变量 / PATH 工具方法
    ├── aliases.zsh                 # 自动生成的别名文件
    ├── user_mounts.zsh             # 自定义模块挂载入口
    └── custom/
        ├── shell_behavior.zsh      # 交互式终端行为：默认 cd 桌面、clean 清屏清历史
        ├── path_drag_resolver.zsh  # macOS 拖入路径解析
        └── local.zsh               # 统一个人终端函数集合
```

安装后会同步到：

```text
~/.JobsMacEnv
├── .zshrc
├── install.command
├── sync_env.txt
├── README.md
├── scripts/
└── zsh/
```

## 三、安装方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入项目目录后执行：

```bash
chmod +x install.command
./install.command
```

也可以在 **Finder** 中双击 `install.command` 执行。

安装过程中会询问：

1. 是否继续安装
2. 是否自动安装 JDK 17
3. 是否替换当前系统 `~/.zshrc`

如果选择替换 `~/.zshrc`，脚本会先自动备份旧文件：

```text
~/.zshrc.backup.YYYYMMDDHHMMSS
```

安装完成后，立即生效：

```bash
source ~/.zshrc
```

## 四、安装流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```mermaid
flowchart TD
    A([开始])
    B[运行安装脚本]
    C[读取声明式配置]
    D{是否检测到 JDK 17}
    E[询问是否自动安装 JDK 17]
    F[同步到 ~/.JobsMacEnv]
    G[生成环境变量和别名]
    H{是否替换 ~/.zshrc}
    I[备份并替换 ~/.zshrc]
    J[保留当前 ~/.zshrc]
    K[提示 source ~/.zshrc]
    L([完成])

    A --> B --> C --> D
    D -- 已存在 --> F
    D -- 不存在 --> E --> F
    F --> G --> H
    H -- 是 --> I --> K
    H -- 否 --> J --> K
    K --> L
```

## 五、配置入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 1、声明式环境配置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

主要修改：

```text
sync_env.txt
```

示例：

```ini
[JAVA]
JAVA_VERSION=17
JAVA_CANDIDATES=temurin@17,zulu@17,openjdk@17

[ANDROID]
ANDROID_SDK_DEFAULT=$HOME/Library/Android/sdk

[FLUTTER]
USE_FVM=true
FLUTTER_CANDIDATES=$HOME/fvm/default/bin,$HOME/development/flutter/bin

[NODE]
ENABLE_PNPM=true
ENABLE_COREPACK=true
NVM_DIR=$HOME/.nvm

[PATH]
$HOME/bin
$HOME/.local/bin
$HOME/.pub-cache/bin
$HOME/.cargo/bin
$HOME/go/bin

[ALIASES]
ll=ls -alF
gs=git status
ga=git add .
gc=git commit
gp=git push
gl=git pull
```

执行安装脚本后，会根据 `sync_env.txt` 生成：

```text
~/.JobsMacEnv/zsh/env.zsh
~/.JobsMacEnv/zsh/aliases.zsh
```

因此不要直接长期手改这两个生成文件。需要变更时，优先改 `sync_env.txt`。

### 2、个人终端函数集合 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

个人终端函数和本机专属内容统一放这里：

```text
zsh/custom/local.zsh
```

适合放：

- 个人项目路径
- 私有别名
- 常用 zsh 函数
- 终端快捷命令
- 临时开关

例如开启拖入路径自动解析：

```zsh
export JOBS_ALIAS_DRAG_AUTO_RESOLVE=true
```

个人命令统一维护在 `local.zsh` 里，避免人为制造两套心智负担。

## 六、已支持的环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 类型 | 说明 |
|---|---|
| Java | 自动解析 JDK 版本，默认 JDK 17 |
| Android | 配置 Android SDK、platform-tools、emulator 等路径 |
| Flutter | 支持 FVM 优先，也支持普通 Flutter SDK 路径 |
| Node | 支持 NVM、Corepack、PNPM |
| Rust | 支持 Cargo 路径 |
| Python | 支持 pyenv |
| Ruby | 支持 rbenv |
| Go | 支持 GOPATH 和 Go bin 路径 |
| Homebrew | 自动兼容 Apple Silicon 和 Intel 路径 |

## 七、常用能力 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 1、轻量 zsh 主入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

系统 `~/.zshrc` 只负责加载：

```zsh
export JOBS_MAC_ENV_HOME="$HOME/.JobsMacEnv"

jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/bootstrap.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env_methods.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/aliases.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/user_mounts.zsh"
```

核心配置都在 `~/.JobsMacEnv` 下维护。

### 2、macOS 路径拖入解析 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`path_drag_resolver.zsh` 用来处理 Finder 拖入终端的路径。

默认快捷键：

```text
Ctrl + G
```

作用：把当前命令行最后一个路径参数解析成真实路径，支持：

- Finder 替身文件
- Unix 软链接
- 普通文件和目录
- 带空格、括号、转义字符的路径

### 3、终端相关自定义函数重点说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这些命令不是系统自带命令，而是本项目挂载到 zsh 里的个人终端能力。加载顺序在：

```zsh
zsh/user_mounts.zsh
```

默认顺序是：

```zsh
shell_behavior.zsh
path_drag_resolver.zsh
local.zsh
```

也就是说，`shell_behavior.zsh` 放终端默认行为，`path_drag_resolver.zsh` 放路径拖入解析，`local.zsh` 放统一的个人终端函数和项目命令。

#### 3.1 `clean`：清除终端历史 + Command+K 式清屏

来源文件：

```text
zsh/custom/shell_behavior.zsh
```

用法：

```zsh
clean
```

执行效果：

- 清空当前 zsh 会话里的历史记录。
- 清空 `HISTFILE` 指向的历史文件，默认通常是 `~/.zsh_history`。
- 顺带清空 macOS `~/.zsh_sessions/*.history`、`~/.zsh_sessions/*.historynew` 里残留的会话历史。
- 清空当前终端可视区域。
- 清空终端滚动缓冲区，也就是往上滚动时看到的旧输出。
- 清屏效果按 Command+K 的目标处理：不是普通 `clear`，而是连 scrollback 一起清掉。
- 执行后恢复原来的 `HISTSIZE` / `SAVEHIST` / `HISTFILE` 设置，因此后续新输入的命令仍然会正常记录历史。

适合场景：

- 终端里刚输入过 token、密码、私有路径、临时命令，不希望留在历史里。
- 录屏、截图、演示前，希望终端画面和滚动缓冲都干净。
- 想要一次性清掉历史文件，而不是只执行普通 `clear`。

注意：

- `clean` 是强清理命令，不做二次确认。
- 旧历史一旦被清空，就不要指望通过方向键、`history`、`~/.zsh_history` 再找回来。
- `clear` 只清当前可视区域，不清滚动缓冲；`clean` 使用 ANSI scrollback 清理序列和 iTerm2 ClearScrollback 扩展，目标效果对齐 Command+K。
- 这里没有调用 `clear` 命令，因此不是普通 clear 的效果。

#### 3.2 `zz <路径>`：跳转到真实目录

来源文件：

```text
zsh/custom/local.zsh
```

用法：

```zsh
zz <路径>
```

行为：

- 支持直接把 Finder 里的文件或目录拖进终端。
- 自动处理路径里的转义空格，例如 `My\ Folder`。
- 支持 `~` 展开。
- 支持 macOS Finder 替身文件 alias。
- 支持 Unix 软链接 symlink。
- 如果目标是目录，进入该目录。
- 如果目标是文件，进入文件所在目录。
- 最后输出真实目录路径，方便确认当前位置。

示例：

```zsh
zz ~/Desktop
zz /Applications/Xcode.app
zz /Users/jobs/Downloads/demo.command
```

适合场景：拖文件、拖目录、点到 Finder 替身、遇到软链接时，不用手动 `cd`、`dirname`、`realpath`。

#### 3.3 `x <脚本文件>`：给脚本加执行权限并立即执行

来源文件：

```text
zsh/custom/local.zsh
```

用法：

```zsh
x <脚本文件>
```

行为：

- 支持把 `.command`、`.sh` 或其他脚本文件直接拖进终端。
- 自动处理 Finder 拖入路径里的转义空格。
- 自动执行 `chmod +x <脚本文件>`。
- 立即执行目标脚本。
- 如果目标不存在或是目录，会直接报错并停止。

示例：

```zsh
x ./install.command
x ~/Downloads/test.sh
```

适合场景：下载了 `.command` / `.sh`，不想每次手动写 `chmod +x` 再执行。

#### 3.4 `cor`：颜色格式转换器

来源文件：

```text
zsh/custom/local.zsh
```

用法：

```zsh
cor
cor '#D2D4DE'
cor '#D2D4DE80'
cor 'rgb(210,212,222)'
cor 'rgba(210,212,222,0.5)'
cor '0x80D2D4DE'
```

行为：

- 无参数执行 `cor` 时进入交互模式，可以连续输入颜色值，输入 `q` / `quit` / `exit` 退出。
- 支持 `#RRGGBB`、`#RRGGBBAA`、`rgb()`、`rgba()`、`0xAARRGGBB`。
- 输出不透明 HEX、带透明 HEX、RGB、RGBA、Flutter / Dart 常用的 `0xAARRGGBB`。
- 在支持 TrueColor 的终端里显示原色色块；不支持时自动退化到 xterm-256 色。
- 纯 Shell 实现，依赖系统自带的 `bash`、`awk`、`sed`、`printf`。

注意：

- 命令行参数里 `#`、括号、逗号容易被 shell 解释，建议直接用交互模式，或者给颜色值加引号。
- `0xAARRGGBB` 的透明度在最前面，例如 `0x80D2D4DE`。

#### 3.5 `shell`：用 fzf 选择并切换默认 Shell

来源文件：

```text
zsh/custom/local.zsh
```

用法：

```zsh
shell
```

行为：

- 运行时扫描当前电脑已有的可用 shell，不写死固定列表。
- 优先读取 `/etc/shells`，这是 macOS `chsh` 官方认可的 shell 来源。
- 继续扫描 `PATH`、`/opt/homebrew/bin`、`/usr/local/bin`、`/opt/local/bin`、`/bin`、`/usr/bin`，补充 `zsh`、`bash`、`fish`、`nu`、`pwsh`、`tcsh`、`csh`、`ksh`、`dash`、`elvish`、`xonsh` 等可执行文件。
- 如果检测到 `~/.oh-my-zsh` 或当前 `ZSH` 变量，会额外列出 `ohmyzsh / zsh + Oh My Zsh`。
- fzf 列表标题是 `目前可用的终端 / Shell：↑↓ 选择，Enter 切换，Esc 取消`。
- 选中后执行 `chsh -s <shell路径>`，修改当前 macOS 用户的默认登录 shell。
- 如果目标 shell 不在 `/etc/shells`，会提示是否用 `sudo` 追加。不同意就取消，不会强行切换。

依赖：

```zsh
brew install fzf
```

重要说明：

- `ohmyzsh` 不是一个独立登录 shell，它是 zsh 的配置框架。选择 `ohmyzsh / zsh + Oh My Zsh` 时，实际切换的仍然是 `zsh` 路径。
- `nu` / Nushell 如果是 Homebrew 安装，常见路径是 `/opt/homebrew/bin/nu` 或 `/usr/local/bin/nu`。只要扫描到可执行文件，就会进列表；但作为默认登录 shell 前，macOS 仍要求它在 `/etc/shells` 里。
- 切换完成后，需要重新打开终端窗口才会完整生效。

#### 3.6 `download <url>`：用 yt-dlp 下载并自动带浏览器 cookies

来源文件：

```text
zsh/custom/local.zsh
```

用法：

```zsh
download "https://www.youtube.com/shorts/xxxx?feature=share"
```

行为：

- 检查本机是否安装 `yt-dlp`。
- 自动检测 macOS 默认浏览器。
- 支持识别 Chrome、Chrome Canary、Edge、Firefox、Safari。
- 调用 `yt-dlp --cookies-from-browser <browser> <url>` 下载。
- 默认浏览器识别失败时，回退使用 `chrome`。

依赖：

```zsh
brew install yt-dlp
```

适合场景：需要登录态 cookies 才能下载的视频链接，不想每次手动指定浏览器。

#### 3.7 `Ctrl + G`：把命令行最后一个路径参数解析成真实路径

来源文件：

```text
zsh/custom/path_drag_resolver.zsh
```

默认快捷键：

```text
Ctrl + G
```

行为：

- 读取当前命令行最后一个参数。
- 自动反转义 Finder 拖入路径里的空格、括号、引号等字符。
- 如果最后一个参数是有效路径，就解析成真实路径并回填到命令行。
- 支持 Finder 替身文件、Unix 软链接、普通文件、普通目录。
- 回填时使用 shell 安全转义，避免路径里的空格或特殊字符破坏命令。

示例流程：

```zsh
cd /Users/jobs/Desktop/My\ Link
# 按 Ctrl + G
cd /Users/jobs/RealProject
```

相关开关：

```zsh
export JOBS_ALIAS_DRAG_BINDKEY='^G'
export JOBS_ALIAS_DRAG_AUTO_RESOLVE=true
```

说明：

- `JOBS_ALIAS_DRAG_BINDKEY` 用来修改快捷键。
- `JOBS_ALIAS_DRAG_AUTO_RESOLVE=true` 后，粘贴 / 拖入单个有效路径时会尝试自动转成真实路径。
- 不想自动解析时，不设置 `JOBS_ALIAS_DRAG_AUTO_RESOLVE`，只保留 `Ctrl + G` 手动触发即可。

#### 3.8 `shell_behavior.zsh`：交互式终端默认行为

来源文件：

```text
zsh/custom/shell_behavior.zsh
```

当前默认行为：

- 只有交互式 zsh 才执行这里面的逻辑。
- 打开新终端时，如果存在 `~/Desktop`，默认进入桌面。
- 定义 `clean` 函数，用于清历史，并执行 Command+K 式清屏：清当前显示 + 清滚动缓冲区。

如果你不想打开终端默认进入桌面，直接注释这一段即可：

```zsh
if [[ -o interactive ]] && [[ -d "$HOME/Desktop" ]]; then
  cd "$HOME/Desktop"
fi
```

#### 3.9 `local.zsh`：统一个人终端函数和项目命令

来源文件：

```text
zsh/custom/local.zsh
```

这个文件统一放个人终端函数、项目命令和本机路径配置。里面有固定项目路径和比较强的环境假设，迁移到新机器前应先检查路径。

重点命令包括：

| 命令 | 作用 |
|---|---|
| `save` | 重新 source 常见 shell 配置文件，例如 `.bash_profile`、`.bashrc`、`.zshrc`、`.profile` |
| `flutter` | 重载 Flutter 命令，优先使用当前项目的 FVM Flutter SDK |
| `fixfvm` | 重新安装全局 fvm，修复 Dart SDK 内核版本不匹配问题 |
| `check1` | 输出 Dart / FVM / Flutter 的路径和版本信息 |
| `rb` | 重新登录当前 shell，相当于刷新终端会话 |
| `a` | 打开 `~/.bash_profile` |
| `b` | 打开 `~/.zshrc` |
| `i` | 打开 iOS Simulator |
| `d` | 进入默认 Flutter 项目目录，可传路径覆盖 |
| `check` | 进入项目后检查 Java / FVM / Flutter doctor |
| `c` | 在项目里通过 jenv 锁定 JDK 17，并执行检查 |
| `apk` | 构建 Flutter Android APK |
| `ipa` | 构建 Flutter iOS IPA |
| `config` | 打开配置文件目录，优先使用 Xcode |
| `update` | 菜单化更新 Homebrew、Android SDK、Flutter、Node、Rust、Python、Ruby、CocoaPods、OpenClaw 等模块 |
| `install` | 新系统环境配置入口 |
| `cor` | 颜色格式转换器，支持 HEX / RGB / RGBA / 0xAARRGGBB，带色块预览 |
| `shell` | fzf 选择当前电脑扫描到的 shell，并切换默认登录 shell |
| `decode` | URL Decode 交互式解码，并自动复制结果到剪贴板 |

迁移新机器前，优先检查文件开头这两个变量：

```zsh
JOBS_FLUTTER_PROJECT_DIR="/Users/jobs/Documents/Github/flutter_tiyu_app"
JOBS_DART_CLI_COMPLETION_FILE="/Users/jobs/.dart-cli-completion/zsh-config.zsh"
```

如果项目路径不对，`d`、`check`、`c`、`apk`、`ipa` 等项目相关命令就会失败或进入错误目录。

## 八、更新配置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

修改项目里的配置后，重新执行：

```bash
./install.command
```

脚本会把配置同步到：

```text
~/.JobsMacEnv
```

如果文件内容没有变化，会自动跳过重复写入。

## 九、注意事项 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 本项目主要面向 MacOS + zsh。
- 自动安装 JDK 17 依赖 [**Homebrew**](https://brew.sh/)。
- 替换 `~/.zshrc` 前会自动备份，但仍建议先确认当前配置没有重要未迁移内容。
- `env.zsh` 和 `aliases.zsh` 是生成文件，不建议直接长期手改。
- `zsh/custom/local.zsh` 是统一个人终端函数集合，里面可能包含固定项目路径；迁移到新机器后建议先检查再使用。
- 如果安装后没有立即生效，执行 `source ~/.zshrc`，或者重新打开终端。

## 10、推荐维护方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
公共、可复用配置     -> sync_env.txt / zsh/*.zsh
个人终端函数集合     -> zsh/custom/local.zsh
终端默认行为         -> zsh/custom/shell_behavior.zsh
路径拖入解析         -> zsh/custom/path_drag_resolver.zsh
系统入口             -> ~/.zshrc 只保留加载入口
实际运行目录         -> ~/.JobsMacEnv
```

**核心原则：**

```text
系统入口要轻，环境逻辑要拆；个人终端函数统一放一处，生成文件不要手改。
```

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
