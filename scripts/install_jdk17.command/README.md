# install_jdk17.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

检测并安装 JDK 17。安装优先级为 `temurin@17` → `zulu@17` → `openjdk@17`。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./install_jdk17.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
install_jdk17
install_jdk17 [参数...]
```

## 三、交互规则

Homebrew 已安装时：回车跳过更新，输入任意字符后回车执行更新。未检测到 JDK 17 时，安装 JDK 是脚本目标流程，会自动进入安装。

## 四、结构约定

运行时说明和核心流程已经写在 `install_jdk17.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 五、流程图

```mermaid
flowchart TD
    A([启动 install_jdk17.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[检测当前 JDK 17]
    B --> C
    D[未安装时检测 / 安装 Homebrew]
    C --> D
    E[按 temurin@17 → zulu@17 → openjdk@17 尝试安装]
    D --> E
    F[必要时补齐 java_home 软链接]
    E --> F
    G[输出 JDK 17 信息]
    F --> G
    H([结束])
    G --> H
```
