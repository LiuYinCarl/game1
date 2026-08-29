#!/bin/bash
# 一键打包脚本：导出 Windows 单文件 EXE（资源内嵌）与 macOS APP（zip 压缩包）
# 用法：./build.sh   （可用环境变量 GODOT_BIN 指定其他 Godot 可执行文件）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "未找到 Godot：$GODOT_BIN"
	echo "请用环境变量指定，例如：GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot $0"
	exit 1
fi

mkdir -p "$ROOT/builds"

echo "==> 同步资源导入…"
"$GODOT_BIN" --headless --path "$ROOT" --import > /dev/null 2>&1

echo "==> 导出 Windows（builds/tafang_windows.exe）…"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Windows" "$ROOT/builds/tafang_windows.exe"

echo "==> 导出 macOS（builds/tafang_mac.zip）…"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "macOS" "$ROOT/builds/tafang_mac.zip"

echo
echo "打包完成："
ls -lh "$ROOT/builds"
