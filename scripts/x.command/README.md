# x.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

给拖入的脚本执行 `chmod +x`，然后直接运行该脚本。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./x.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
x
x [参数...]
```

## 三、结构约定

运行时说明和核心流程已经写在 `x.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 四、流程图

```mermaid
flowchart TD
    A([启动 x.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[读取拖入脚本路径]
    B --> C
    D[执行 chmod +x]
    C --> D
    E[运行目标脚本]
    D --> E
    F([结束])
    E --> F
```
