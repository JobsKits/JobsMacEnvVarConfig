# **MacOS** JobsMacEnv - **时间戳转换器**

<p align="left">
  <a><img src="https://img.shields.io/badge/macOS-command%20script-lightgrey" alt="macOS"/></a>
  <a><img src="https://img.shields.io/badge/Shell-zsh-critical" alt="zsh"/></a>
  <a><img src="https://img.shields.io/badge/JobsMacEnv-Scripts-blue" alt="JobsMacEnv"/></a>
</p>

![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")

[toc]

## 🔥 <font id=前言>前言</font>

> 当前总行数：

* 🔧 **工欲善其事必先利其器**

* 🌋 **站在巨人的肩膀上，才能看得更远**

* ✝️ **面向信仰编程**

* 本文是 `timestamp.command` 的脚本自述文件。

* 提供 ts 函数，交互式转换 Unix 时间戳并支持时区选择。

* 双击 `.command` 脚本运行时，会先显示自述文件并等待用户按回车，避免误操作。

## 一、🎯 项目白皮书 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

脚本定位：

* 脚本文件：`timestamp.command`
* 所属目录：`Scripts/timestamp.command/`
* 推荐入口：`source "$JOBS_MAC_ENV_HOME/Scripts/timestamp.command/timestamp.command"`
* 日志策略：可执行脚本默认写入 `/tmp/脚本名.log`，函数模块由调用方统一管理日志。

## 二、🧭 脚本执行流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```mermaid
graph TD
    A([开始]) --> B[显示自述文件并等待确认]
    B --> C[读取 Unix 时间戳]
    C --> D[识别秒 / 毫秒 / 微秒 / 纳秒]
    D --> E[选择系统时区或其他时区]
    E --> F[输出完整日期时间]
    F --> Z([结束])
```

## 三、🧩 功能清单 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 1、读取 Unix 时间戳

读取 Unix 时间戳。

### 2、识别秒 / 毫秒 / 微秒 / 纳秒

识别秒 / 毫秒 / 微秒 / 纳秒。

### 3、选择系统时区或其他时区

选择系统时区或其他时区。

### 4、输出完整日期时间

输出完整日期时间。

## 四、🚀 使用方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 1、双击执行

在 Finder 中双击：

```shell
Scripts/timestamp.command/timestamp.command
```

### 2、终端执行

```shell
"Scripts/timestamp.command/timestamp.command"
```

已完成 JobsMacEnv 安装后，推荐入口：

```shell
source "$JOBS_MAC_ENV_HOME/Scripts/timestamp.command/timestamp.command"
```

## 五、⚠️ 常见问题 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### 1、为什么要先显示自述文件？

为了防止双击误触后直接修改环境、安装依赖或执行耗时任务。

### 2、为什么每个脚本都单独放一个同名文件夹？

这样可以把脚本、自述文件和未来扩展资源放在同一处，避免 Scripts 目录长期失控。

## 六、✅ 总结 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`timestamp.command` 采用独立目录管理，便于阅读、维护、迁移和长期扩展。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

> 说明：脚本运行时展示的自述已内置在 `.command` 脚本中，不读取本 README.md；本文件仅用于仓库/文件夹阅读。
