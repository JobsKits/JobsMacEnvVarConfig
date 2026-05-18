# entrypoints.command
![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")
[toc]

## 一、功能

注册终端短命令包装器。真实命令实现统一位于 `Scripts/<命令>.command/<命令>.command`。

该文件主要作为 JobsMacEnv 的 shell 函数模块 / 入口注册模块使用，通常由 shell 配置或上层脚本 `source` 加载。

## 二、运行

```zsh
source Scripts/entrypoints.command/entrypoints.command
```

## 三、功能清单

当前注册的终端入口如下：

```text
list
m5c
flat
trs
gif
simios
pods
clean
dq
cor
decode
ts
download
to
mp4
mov
webm
mkv
avi
m4v
mp3
m4a
aac
wav
flac
ogg
opus
install
update
shell
zz
x
save
rb
a
b
i
fixfvm
check1
check
c
d
buildCheck
apk
ipa
config
```

## 四、交互规则

该文件主要被 shell 配置 source 加载，不是普通一次性执行脚本。它只负责注册入口函数，不承载真实业务实现。
`mp4` / `mov` / `webm` / `mp3` 等媒体格式短命令不单独维护脚本，统一复用 `Scripts/to.command/to.command`。`gif` 已作为录制入口保留；需要转换 GIF 时使用 `to gif 文件`。


## 五、结构约定

该文件位于 `Scripts/entrypoints.command/entrypoints.command`。

同级 `README.md` 只用于源码浏览、维护说明和当前流程说明，不参与运行时加载。

## 六、流程图

```mermaid
flowchart TD
    A([source entrypoints.command])
    B[注册命令包装函数]
    A --> B
    C[用户输入短命令]
    B --> C
    D[定位真实 .command 文件]
    C --> D
    E[执行脚本或 source 后调用 main 函数]
    D --> E
    F[恢复必要的包装入口]
    E --> F
    G([返回当前 shell])
    F --> G
```
