# 塔防（tafang）

仿《王国保卫战》的 2D 塔防 Demo，使用 **Godot 4.7**（GDScript）开发。
单关卡完整可玩：8 波敌人、3 种防御塔、建造/升级/出售、金币与生命、胜负结算、
粒子特效、主题 UI、背景音乐。

## 打开与运行

1. 安装 Godot 4.7 或更高版本（本机使用 Steam 版 Godot 4.7.1）。
2. 打开 Godot 项目管理器 → **导入** → 选择本目录的 `project.godot`。
3. 打开项目后按 **F5**（或点击右上角运行按钮）开始游戏，主场景为 `scenes/main.tscn`。

命令行方式：

```bash
# 运行游戏
godot --path .

# 无头冒烟测试：10 倍速自动建造并打满 8 波，输出每波状态与各塔开火统计
godot --headless --path . --quit-after 5400 -- --smoke

# 截图模式：自动建塔开波，输出游戏/菜单/特效截图到 /tmp/tafang_*.png
godot --path . --quit-after 700 -- --shot
```

## 玩法操作

- 点击地图上的**石板建造点** → 弹出建造菜单（箭塔 70 / 法师塔 100 / 炮塔 125）
- 点击已建的塔 → **升级**（最高 3 级）或**出售**（返还 70% 造价）
- 底部按钮**开始下一波**；旁边按钮切换 **x1/x2/x3 倍速**
- 右上角**测试**按钮打开调试面板：加金币/生命、清空敌人、**暂停/继续**、音乐开关
- 敌人冲进城堡会扣生命（屏幕红闪提示），生命归零失败；守住全部 8 波获胜

## 代码架构

```
project.godot          项目配置（主场景、1920x1080 分辨率）
scenes/main.tscn       主场景（仅根节点，内容由代码生成）
scripts/
  main.gd              游戏主管理器（约 900 行）：
                       - 数据表（路径/建造点/敌人/塔/波次）
                       - MapDrawer 内部类：地图绘制（草地/道路/装饰/城堡/射程预览）
                       - 波次调度、金币生命、建造/升级/出售
                       - 特效系统（spawn_particles/spawn_explosion/飘字/红闪）
                       - 全部 UI（状态徽章/按钮/菜单/测试面板/结算）
  enemy.gd             敌人：沿路径移动、血条、受击闪白、出场/行进动效
  tower.gd             防御塔：索敌（优先路径进度最高者）、平滑转向、
                       待机扫视、开火后座、升级数值
  projectile.gd        投射物：追踪弹道、单体/溅射伤害、命中特效
assets/
  td/                  Kenney Tower Defense Top-Down 贴图（CC0）
  fx/                  Kenney Particle Pack 粒子贴图（CC0）
  ui/                  game-icons.net 图标（CC BY 3.0）
  audio/               背景音乐（CC BY 4.0）
```

### 关键设计

- **无场景文件依赖**：除 `main.tscn` 根节点外，所有节点（地图/塔/敌人/UI）
  都在代码中构建，改数据不用碰编辑器
- **数据驱动**：改平衡只动 `main.gd` 顶部的数据表：
  - `PATH_POINTS` / `BUILD_SPOTS` — 路径折点与建造点坐标
  - `ENEMY_TYPES` — 敌人血量/速度/赏金/贴图
  - `TOWER_TYPES` — 塔的造价/射程/伤害/射速/弹道与贴图
  - `WAVES` — 每波的敌人组成、数量、间隔、延迟
- **特效复用**：`spawn_particles(pos, opts)` 一个函数通过参数组合出
  爆炸/烟尘/火花/尘土/闪光，支持颜色渐变、湍流、尺寸曲线、ADD 发光混合
- **UI 样式复用**：`_panel_style()` / `_style_button()` 统一深色金边风格

## 素材与许可

| 素材 | 来源 | 许可 |
| --- | --- | --- |
| 塔/敌人/装饰贴图 | Kenney — Tower Defense (Top-Down) | CC0 |
| 粒子贴图 | Kenney — Particle Pack | CC0 |
| UI 图标 | game-icons.net | CC BY 3.0（需署名） |
| 背景音乐 The Builder | Kevin MacLeod（incompetech.com） | CC BY 4.0（需署名） |

署名详情见各目录下的 `CREDITS.txt`。发布游戏时请保留署名信息。

## 后续方向

- 平衡调优（当前满配布局可满血通关，建议提高难度）
- 音效（开火/爆炸/建造，可用 Kenney 免费音效包）
- 敌人行走序列帧动画（当前为静态贴图 + 程序化颠簸）
- 更多塔种/敌种、多关卡、路径分叉
