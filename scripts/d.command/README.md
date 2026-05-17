# d.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

进入默认 Flutter 项目目录；传入路径时用传入路径覆盖默认目录。

该脚本适合 `.command` 双击运行，也可以在终端中执行。启动后的说明展示、依赖检查和核心流程都写在脚本内部。

## 二、运行

```zsh
./d.command
```

如果已经自行加入 PATH，也可以执行：

```zsh
d
d [参数...]
```

## 三、结构约定

运行时说明和核心流程已经写在 `d.command` 内部，不依赖同级 `README.md`。

本 README 只用于源码浏览、维护说明和当前流程说明。

## 四、流程图

```mermaid
flowchart TD
    A([启动 d.command])
    B[打印脚本内置自述并等待回车]
    A --> B
    C[加载 Flutter 项目辅助库]
    B --> C
    D[解析默认项目目录或传入路径]
    C --> D
    E[cd 到目标目录]
    D --> E
    F([结束])
    E --> F
```
