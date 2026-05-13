# restore flutter / jdk17 layout

- `Scripts/jdk17.command/` 已恢复为原版位置 `Scripts/install_jdk17.command/`。
- 不再生成 `~/.local/bin/jdk17`，并会在安装时移除旧版 JobsMacEnv 生成的 `~/.local/bin/jdk17`。
- `Scripts/flutter.command/` 已移除，Flutter 逻辑回到原版函数模块位置 `Scripts/flutter_project.command/flutter_project.command`。
- 不再生成 `~/.local/bin/flutter`，并会移除旧版 JobsMacEnv 生成的 `~/.local/bin/flutter`，避免覆盖系统 Flutter。
- `list` 菜单改为展示“功能入口”，不再把 `jdk17` / `flutter` 当作独立终端命令展示；JDK 17 显示为 `install_jdk17.command`，Flutter 显示为 `flutter_project.command`。
- `list` 菜单隐藏 `install_jdk17.command` 左侧的 `JDK 17` 标题，只保留真实执行入口和说明。
- `list` 菜单改用视觉宽度补齐，`去乱码 flat`、`翻译 trs` 与 `文件校验 m5c` 的命令列对齐。
- `list` 菜单在支持 `--info-command` 的 fzf 版本中显示当前选择位置，例如 `1/32`、`5/32`，不再只显示固定匹配总数。
