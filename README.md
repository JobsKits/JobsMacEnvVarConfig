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
