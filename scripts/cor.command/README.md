# cor.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

转换 HEX / RGB / RGBA / `0xAARRGGBB` 等颜色格式，并输出终端色块预览。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./cor.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
cor
cor [参数...]
```

## 三、结构约定

运行时说明和核心流程已经写在 `cor.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 四、流程图

```mermaid
flowchart TD
    A([启动 cor.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[读取颜色输入]
    B --> C
    D[识别颜色格式]
    C --> D
    E[转换为其他常用格式]
    D --> E
    F[输出色块预览]
    E --> F
    G([结束])
    F --> G
```
