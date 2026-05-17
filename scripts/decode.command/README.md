# decode.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

交互式执行 URL Decode，并自动复制解码结果到剪贴板。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./decode.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
decode
decode [参数...]
```

## 三、结构约定

运行时说明和核心流程已经写在 `decode.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 四、流程图

```mermaid
flowchart TD
    A([启动 decode.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[读取 URL 编码文本]
    B --> C
    D[执行 URL Decode]
    C --> D
    E[打印结果]
    D --> E
    F[复制到剪贴板]
    E --> F
    G([结束])
    F --> G
```
