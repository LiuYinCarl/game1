# 打包分发相关坑

## macOS universal 导出要求开启 ETC2/ASTC

**现象**：`--export-release "macOS"` 报错：禁用 ETC2 ASTC 纹理格式时无法为 universal 和 arm64 进行导出。

**原因**：Apple Silicon 不支持 S3TC/BPTC 压缩纹理，导出 universal/arm64 包时要求项目开启 ETC2/ASTC 纹理导入。

**修复**：`project.godot` 的 `[rendering]` 加
`textures/vram_compression/import_etc2_astc=true`，然后跑一次 `--import` 让资源重新导入。

## Windows EXE 图标 / 元数据需要 rcedit

在 macOS 上交叉导出 Windows 包时，改 EXE 内嵌图标、产品名、版本信息依赖 rcedit + wine。没有的话把预设里 `application/modify_resources` 设为 `false` 跳过（EXE 用 Godot 默认图标）。**在 Windows 本机导出则不需要 wine**，可以原生改——所以两边脚本对同一份 `export_presets.cfg` 的这个开关预期不同。

## cmd 批处理（.bat）的两个硬要求

- **CRLF 行尾**：cmd 对 LF 行尾的 `goto` 标签解析有历史兼容问题。仓库若全局 `eol=lf`，要在 `.gitattributes` 加 `*.bat text eol=crlf` 例外，否则 Windows 检出时会被规范成 LF。
- **纯 ASCII 内容**：bat 对编码极其敏感（cmd 用 OEM 代码页解析），中文输出/注释极易乱码甚至破坏语法。脚本内输出一律用英文。

另外 `Program Files (x86)` 路径里的括号会破坏 bat 的括号块解析，取这个环境变量要用延迟展开 `!ProgramFiles(x86)!`，不能裸写进 `for` 的列表里。

## 交叉导出的可行性

- **mac → Windows**：Godot 4 直接支持，`--export-release "Windows"` 即可出单文件 EXE（`binary_format/embed_pck=true` 内嵌资源），无需 wine。
- **mac → macOS**：原生支持，建议 ad-hoc 签名（codesign identity 留空即默认），否则 Apple Silicon 拒绝运行完全未签名的二进制。
- **Windows → macOS**：能出包但无法签名，接收方需要"右键 → 打开"绕过 Gatekeeper。

## 冒烟测试的帧数上限

`--quit-after` 按帧数计，无头模式帧率不锁但后期关卡波次多、逻辑重，L5 需要 18000+ 帧才能跑完全程，否则测试"无声无息"地没跑完就退出（没有任何报错，只能从输出里发现少了 game over 行）。
