# JobsMacEnv

这版继续按你的要求收了一轮：

1. 去掉 `project_env`
2. 安装目录保持为隐藏目录 `~/.JobsMacEnv`
3. `zsh` 目录和文件名继续保持短命名
4. `install.command` 增加了 **JDK 17 检测与可选安装**

## 目录结构

```bash
~/.JobsMacEnv/
├── .zshrc
├── install.command
├── README.md
├── sync_env.txt
├── scripts/
│   └── install_jdk17.command
└── zsh/
    ├── bootstrap.zsh
    ├── env_methods.zsh
    ├── env.zsh
    ├── aliases.zsh
    ├── user_mounts.zsh
    └── custom/
        ├── shell_behavior.zsh
        ├── legacy_functions.zsh
        ├── path_drag_resolver.zsh
        └── local.zsh
```

## 主入口

系统 `~/.zshrc` 只负责加载：

```zsh
export JOBS_MAC_ENV_HOME="$HOME/.JobsMacEnv"

jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/bootstrap.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env_methods.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/env.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/aliases.zsh"
jobs_source_if_exists "$JOBS_MAC_ENV_HOME/zsh/user_mounts.zsh"
```

## 文件职责

- `zsh/bootstrap.zsh`：基础启动逻辑
- `zsh/env_methods.zsh`：公共方法
- `zsh/env.zsh`：由 `sync_env.txt` 自动生成
- `zsh/aliases.zsh`：由 `sync_env.txt` 自动生成
- `zsh/user_mounts.zsh`：外挂总入口
- `zsh/custom/shell_behavior.zsh`：终端行为
- `zsh/custom/legacy_functions.zsh`：旧函数迁移区
- `zsh/custom/path_drag_resolver.zsh`：拖入路径解析（Ctrl-G / 可选自动解析）
- `zsh/custom/local.zsh`：本机私有配置
- `scripts/install_jdk17.command`：单独安装 JDK 17

## 安装方式

```bash
cd ~/JobsMacEnv
chmod +x ./install.command
./install.command
```

执行后会：

1. 先显示简短安装提示
2. 你按回车后继续
3. 检测 JDK 17，不存在时可选安装
4. 同步内容到 `~/.JobsMacEnv`
5. 生成：
   - `~/.JobsMacEnv/zsh/env.zsh`
   - `~/.JobsMacEnv/zsh/aliases.zsh`
   - `~/.JobsMacEnv/.zshrc`
6. 最后询问是否替换系统当前 `~/.zshrc`

## JDK 17

- 默认优先尝试 `brew install --cask temurin@17`
- 失败时会回退尝试 `brew install --cask zulu@17`
- 再不行才尝试 `brew install openjdk@17`
- 也可以单独运行：

```bash
~/.JobsMacEnv/scripts/install_jdk17.command
```

## 推荐维护方式

- 改环境声明：`~/.JobsMacEnv/sync_env.txt`
- 改终端行为：`~/.JobsMacEnv/zsh/custom/shell_behavior.zsh`
- 改历史函数：`~/.JobsMacEnv/zsh/custom/legacy_functions.zsh`
- 改本机私有：`~/.JobsMacEnv/zsh/custom/local.zsh`


## 模板位置

- `Sys/.zshrc`：安装时使用的主入口模板
- `~/.JobsMacEnv/.zshrc`：同步后的模板副本
- `~/.zshrc`：选择替换后写入系统的实际入口


## 拖入替身 / symlink 解析

默认启用：

- 把文件或替身拖进终端后，按 `Ctrl-G`
- 会把当前命令行最后一个路径参数解析成真实路径

可选开启自动粘贴解析（只建议在 `Terminal.app` / `iTerm2` 自测稳定后再开）：

```zsh
# ~/.JobsMacEnv/zsh/custom/local.zsh
export JOBS_ALIAS_DRAG_AUTO_RESOLVE=true
```

如果你想改快捷键：

```zsh
# 默认是 Ctrl-G
export JOBS_ALIAS_DRAG_BINDKEY='^G'
```

## update 菜单

`update` 已改成 fzf 菜单入口。

菜单顺序：

```text
01. 🚀 默认全量更新，不含 OpenClaw
02. 🌕 全量更新，包含 OpenClaw
03. 🧩 OpenClaw：同步源码/依赖/UI 并重启 Gateway（不打开配置面板）
04. 🦞 OpenClaw：同步源码并构建
05. 🍺 Homebrew：更新 brew / formula / cask / cleanup / doctor
06. 🤖 Android SDK：更新 sdkmanager 管理的 Android 工具链
07. 🐦 Flutter：升级 Flutter SDK
08. 🎯 Dart / FVM：更新 FVM
09. 🟢 Node / npm / pnpm / corepack：更新 Node 全局生态
10. 🦀 Rust / Cargo：更新 Rust toolchain 和 cargo 全局工具
11. 🐍 Python / pip / pyenv：更新 Python 工具链和 pip 全局包
12. 💎 RubyGems：更新 gem 并清理旧版本
13. 🥥 CocoaPods：更新 Specs 仓库
14. 💠 rbenv / ruby-build：更新 Ruby 版本管理工具
```

说明：

- `fzf` 强制使用正序显示，从上到下就是 01 到 14。
- 顶部 header 会显示简单自述，避免菜单上方空白。
- 第一项是默认项，表示“除了 OpenClaw 以外的激进全量更新”。执行前会先打印总任务标题和子模块计划，避免误以为自己选中了某个子模块。
- 第二项是在第一项基础上追加 OpenClaw。
- 如果没有安装 `fzf`，`update` 会自动退化为第一项。
- Go 不进入菜单，因为 Go 没有可靠的标准命令可以枚举并升级所有全局工具。

本版对容易误伤系统环境的地方做了保护：

- `npm` 不再使用 `npm update -g`。该命令会扫描全局 `node_modules` 里的隐藏残留目录，遇到 `.quicktype-xxxx` 这类目录会触发 `EINVALIDPACKAGENAME`。现在改为先清理 npm 全局隐藏残留目录；普通权限删除失败时会尝试修复权限和 macOS flags，再失败会直接执行 `sudo rm -rf` 删除，不再交互询问。随后枚举真实全局包，逐个执行 `npm install -g 包名@latest`；如果普通权限安装失败，会清理残留、修复权限并重试，再失败会直接 `sudo npm install -g 包名@latest`。`npm` / `pnpm` / `openclaw` 会被跳过，其中 `openclaw` 源码构建由菜单第 04 项处理；第 03 项会复用同一个 OpenClaw 本地仓库记录，同步源码、依赖、运行时代码和 Control UI 静态资源，并刷新 Gateway 服务；它只使用 gateway install/restart，不自动打开 OpenClaw 配置面板。执行完成后会提示回车打开 OpenClaw 控制台，输入任意字符则跳过。
- `pnpm` 不再无脑执行 `npm install -g pnpm@latest`，优先使用 Homebrew 或 corepack；如果已经存在但管理来源不明确，则只显示版本并跳过，避免 `EEXIST` 覆盖 `/opt/homebrew/bin/pnpm`。
- `Python / pip` 使用用户级升级：`--user`；如果当前 Python 受 Homebrew / PEP668 管理，则自动追加 `--break-system-packages`，避免直接写 Homebrew 管理目录。
- `RubyGems` 如果检测到当前 `gem` 指向 macOS 系统 Ruby 的 `/Library/Ruby/Gems/...`，会直接跳过，不执行 `sudo gem update`，避免污染系统 Ruby。
- `CocoaPods` 默认使用 `pod repo update`，不再使用 `--verbose`，减少终端刷屏。
- `Android SDK` 增强了 `sdkmanager` 查找逻辑，会额外尝试 Homebrew `android-commandlinetools` 和 `~/Library/Android/sdk/cmdline-tools/*/bin/sdkmanager`。

OpenClaw 规则：

- 第一次运行如果没有本地仓库记录，会要求输入或拖入本地 `openclaw/openclaw` Git 仓库目录。
- 校验依据是 git remote 是否指向 OpenClaw 官方仓库，兼容以下地址：
  - `https://github.com/openclaw/openclaw`
  - `http://github.com/openclaw/openclaw`
  - 也兼容常见 `.git` 后缀和 SSH 写法。
- 有效目录会记录到 `~/.JobsMacEnv/openclaw_repo_path`。
- 后续运行时不再反复询问，会自动读取并使用已记录目录。
- 如果已记录目录不存在、不是 Git 仓库，或 remote 被改成了非 OpenClaw 官方仓库，会要求重新输入或拖入有效目录。
- 真正执行 `git pull` / `git fetch` 前，会再次校验目录是否存在、是否是 Git 仓库、remote 是否仍然指向 OpenClaw 官方仓库；校验失败会停止同步，避免对错误目录执行 git 操作。
- 第 04 项只要拿到有效目录，就会先执行 git 同步，再执行 pnpm install / ui:build / build。
- 第 03 项会复用同一个本地仓库记录，拿到有效目录后先执行 git 同步。
- 第 03 项会再自检 Homebrew；如果缺失，会按 Homebrew 官方安装脚本安装，并在当前 shell 加载 brew shellenv。
- 第 03 项会再自检 pnpm；如果缺失，会通过 `brew install pnpm` 安装。
- 第 03 项会运行 `pnpm install`，确保 git 同步后新增的 workspace 包、`package.json`、`pnpm-lock.yaml` 和本地 `node_modules` 链接全部对齐。
- 第 03 项会继续运行 `pnpm build` 和 `pnpm ui:build`，构建 Gateway 运行时代码和 dashboard 需要的 Control UI 静态资源；这些步骤不会打开 OpenClaw setup / onboard 配置面板。
- 第 03 项默认不会执行 `pnpm openclaw onboard --install-daemon`，因此不会打开 OpenClaw setup / Security disclaimer / provider / API key 等交互式配置面板。构建完成后会执行 `pnpm openclaw gateway install --force` 和 `pnpm openclaw gateway restart`，让 127.0.0.1:18789 上的 Gateway 重新读取新构建的 Control UI。
- 第 03 项只会做只读状态检查：`pnpm openclaw gateway status`、LaunchAgent / 进程状态、本机完成记录。检测不到也不会自动重配，只会打印手动命令。
- 确实需要让脚本执行一次 onboard 时，显式执行：`JOBS_OPENCLAW_FORCE_ONBOARD=1 update`，再选择第 03 项。
- 第一次通过脚本强制完成 onboard 后，会写入 `~/.JobsMacEnv/openclaw_onboard_done`。
- 第 04 项默认也不会执行 `pnpm openclaw onboard --install-daemon`；它只负责源码同步、构建和全局 CLI 更新。确实需要脚本进入 onboard 时，同样使用 `JOBS_OPENCLAW_FORCE_ONBOARD=1 update`。

