# Godot 引擎相关坑

## canvas_item shader 会替换节点绘制内容

**现象**：把暗角（vignette）shader 直接挂到绘制地图的 `MapDrawer` 节点上，整个地图消失，只剩一层暗色。

**原因**：canvas_item shader 的 `fragment()` 如果只输出自己计算的颜色、不采样 `TEXTURE`，就等于**完全替换**了该节点 `_draw()` 的所有内容。暗角这种"叠加"效果写法只对 ColorRect 这类本来就要被覆盖的节点成立。

**修复**：暗角放在独立的半透明 ColorRect 上，单独一层 CanvasLayer（地图之上、UI 之下）。叠加类全屏效果（暗角、色偏、扫描线）都应这样做，不要挂在内容节点上。

## 无头模式（--headless）的几个限制

- `await RenderingServer.frame_post_draw` 在无头模式下**永远不触发**——没有渲染帧。任何放在它后面的逻辑（截图、调试输出）都不会执行，而且不报错。需要截图的调试必须用带窗口模式跑。
- 无头模式帧率不锁，帧间隔很小；同时首帧可能有一个巨大的 delta。依赖 `delta` 做移动的逻辑要对首帧 spike 有心理准备。
- `--quit-after N` 的 N 是**帧数**不是秒数。后期关卡波次多，10 倍速冒烟测试 7200 帧不够跑完，后期关卡要给 18000+。

## GDScript 类型推断报错

`for sx in [-1.0, 1.0]:` 循环变量是 Variant，`var tx := c.x + sx * 54.0` 会报
"Cannot infer the type of variable because the value doesn't have a set type"。
修复：显式声明 `var tx: float = ...`。遍历无类型容器里的元素做算术时都要注意。

## 存档位置（Steam 版 Godot）

Steam 版 Godot 的编辑器数据（含导出模板）不在标准的
`~/Library/Application Support/Godot/`，而在 Steam 安装目录：
`~/Library/Application Support/Steam/steamapps/common/Godot Engine/editor_data/`。
导出模板（export_templates）就在里面，`--export-release` 会自动找到。
