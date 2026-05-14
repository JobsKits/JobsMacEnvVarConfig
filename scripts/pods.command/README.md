# pods.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

JobsMacEnv 本地 CocoaPods Pod 编译 / podspec lint 自检入口。

## 命令

```zsh
pods
```

## 位置

```text
Scripts/pods.command/pods.command
Scripts/pods.command/README.md
```

## 功能

- 检查某个本地 CocoaPods Pod 是否能在自身 podspec 环境下通过 `pod lib lint`。
- 记住上一次输入的本地 Pod 根目录，下次直接回车沿用。
- 单个 Pod 检查结束后不关闭窗口，可继续检查下一个 Pod。
- 智能分析目标 Pod 的真实本地依赖，默认只传必要的 `--include-podspecs`。
- 缺本地依赖时自动切换全量兼容模式重试一次。
- 区分源码编译失败、依赖解析失败、podspec 校验失败，避免把 `BUILD SUCCEEDED` 后的 lint 错误误判为编译失败。

## 日志

```text
/tmp/pods.log
/tmp/pods.pod-lib-lint-smart.log
/tmp/pods.pod-lib-lint-fallback-all.log
```

## 缓存

```text
~/.JobsMacEnv/cache/local_pod_lint_workspace_root.txt
```
