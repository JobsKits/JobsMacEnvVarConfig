# runtime_init.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

提供 JobsMacEnv 启动时需要注册的轻量运行时逻辑，例如存在才初始化的 jenv / rbenv 与 Dart completion。

该文件主要作为 JobsMacEnv 的 shell 函数模块 / 入口注册模块使用，通常由 shell 配置或上层脚本 `source` 加载。

## 二、运行

```zsh
source Scripts/runtime_init.command/runtime_init.command
```

## 三、交互规则

该文件面向交互式 shell 启动流程，设计目标是轻量、幂等、存在才初始化，避免新机器首次启动报错。

## 四、结构约定

该文件位于 `Scripts/runtime_init.command/runtime_init.command`。

同级 `README.md` 只用于源码浏览、维护说明和当前流程说明，不参与运行时加载。

## 五、流程图

```mermaid
flowchart TD
    A([source runtime_init.command])
    B[检测交互式 shell 环境]
    A --> B
    C[存在 jenv 时初始化 jenv]
    B --> C
    D[存在 rbenv 时初始化 rbenv]
    C --> D
    E[按配置加载 Dart completion]
    D --> E
    F([保持幂等后返回调用方 shell])
    E --> F
```
