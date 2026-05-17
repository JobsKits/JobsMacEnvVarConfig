# check1.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

打印 Dart / FVM / Flutter 的路径和版本信息，用于快速确认 Flutter 环境是否串线。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./check1.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
check1
check1 [参数...]
```

## 三、结构约定

运行时说明和核心流程已经写在 `check1.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 四、流程图

```mermaid
flowchart TD
    A([启动 check1.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[读取 Dart / FVM / Flutter 路径]
    B --> C
    D[读取版本信息]
    C --> D
    E[输出环境检查结果]
    D --> E
    F([结束])
    E --> F
```
