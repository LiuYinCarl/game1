class_name LevelData
extends RefCounted
## 静态关卡与单位数据表：调平衡只改这里。

const LEVELS := [
	# paths: 1-3 条路径（可共享尾段汇聚到王城）；gen: [波数, 预算]；seed: 建造点生成种子
	{"name": "翠绿小径", "gold": 230, "lives": 20, "hp_growth": 0.06, "gen": [8, 55.0], "seed": 1, "paths": [[
		Vector2(-60, 220), Vector2(480, 220), Vector2(480, 760), Vector2(1000, 760),
		Vector2(1000, 320), Vector2(1520, 320), Vector2(1520, 800), Vector2(1980, 800)]]},
	{"name": "蜿蜒河谷", "gold": 240, "lives": 20, "hp_growth": 0.065, "gen": [8, 59.0], "seed": 2, "paths": [[
		Vector2(-60, 560), Vector2(340, 560), Vector2(620, 300), Vector2(1020, 300),
		Vector2(1280, 580), Vector2(1620, 580), Vector2(1800, 780), Vector2(1980, 780)]]},
	{"name": "林地阶梯", "gold": 250, "lives": 20, "hp_growth": 0.07, "gen": [9, 63.0], "seed": 3, "paths": [[
		Vector2(-60, 160), Vector2(340, 160), Vector2(560, 380), Vector2(880, 380),
		Vector2(1100, 620), Vector2(1420, 620), Vector2(1620, 840), Vector2(1980, 840)]]},
	{"name": "双子河口", "gold": 260, "lives": 20, "hp_growth": 0.075, "gen": [9, 67.0], "seed": 4, "paths": [
		[Vector2(-60, 260), Vector2(680, 260), Vector2(680, 580), Vector2(1280, 580), Vector2(1280, 760), Vector2(1980, 760)],
		[Vector2(-60, 900), Vector2(680, 900), Vector2(680, 580), Vector2(1280, 580), Vector2(1280, 760), Vector2(1980, 760)]]},
	{"name": "回环林地", "gold": 270, "lives": 20, "hp_growth": 0.08, "gen": [9, 71.0], "seed": 5, "paths": [[
		Vector2(-60, 180), Vector2(1560, 180), Vector2(1560, 900), Vector2(420, 900),
		Vector2(420, 440), Vector2(1180, 440), Vector2(1180, 680), Vector2(1980, 680)]]},
	{"name": "峡谷要道", "gold": 280, "lives": 20, "hp_growth": 0.085, "gen": [10, 75.0], "seed": 6, "paths": [[
		Vector2(-60, 900), Vector2(300, 900), Vector2(300, 540), Vector2(700, 540), Vector2(700, 240),
		Vector2(1150, 240), Vector2(1150, 600), Vector2(1560, 600), Vector2(1560, 300), Vector2(1980, 300)]]},
	{"name": "双子河谷", "gold": 290, "lives": 20, "hp_growth": 0.09, "gen": [10, 79.0], "seed": 7, "paths": [
		[Vector2(-60, 320), Vector2(620, 320), Vector2(620, 640), Vector2(1300, 640), Vector2(1300, 300),
			Vector2(1700, 300), Vector2(1700, 560), Vector2(1980, 560)],
		[Vector2(-60, 880), Vector2(620, 880), Vector2(620, 640), Vector2(1300, 640), Vector2(1300, 300),
			Vector2(1700, 300), Vector2(1700, 560), Vector2(1980, 560)]]},
	{"name": "山道盘旋", "gold": 300, "lives": 20, "hp_growth": 0.095, "gen": [10, 83.0], "seed": 8, "paths": [[
		Vector2(-60, 140), Vector2(1700, 140), Vector2(1700, 420), Vector2(340, 420),
		Vector2(340, 700), Vector2(1400, 700), Vector2(1400, 930), Vector2(1980, 930)]]},
	{"name": "三岔峡谷", "gold": 310, "lives": 20, "hp_growth": 0.10, "gen": [11, 87.0], "seed": 9, "paths": [
		[Vector2(-60, 180), Vector2(560, 180), Vector2(560, 470), Vector2(1100, 470), Vector2(1100, 720),
			Vector2(1700, 720), Vector2(1700, 860), Vector2(1980, 860)],
		[Vector2(-60, 540), Vector2(560, 540), Vector2(560, 470), Vector2(1100, 470), Vector2(1100, 720),
			Vector2(1700, 720), Vector2(1700, 860), Vector2(1980, 860)],
		[Vector2(-60, 900), Vector2(560, 900), Vector2(560, 470), Vector2(1100, 470), Vector2(1100, 720),
			Vector2(1700, 720), Vector2(1700, 860), Vector2(1980, 860)]]},
	{"name": "帝国大道", "gold": 320, "lives": 20, "hp_growth": 0.105, "gen": [11, 91.0], "seed": 10, "paths": [[
		Vector2(-60, 540), Vector2(500, 540), Vector2(760, 380), Vector2(1180, 380),
		Vector2(1420, 600), Vector2(1980, 600)]]},
	{"name": "沼泽双径", "gold": 330, "lives": 20, "hp_growth": 0.11, "gen": [11, 95.0], "seed": 11, "paths": [
		[Vector2(-60, 240), Vector2(520, 240), Vector2(520, 520), Vector2(1080, 520), Vector2(1080, 300),
			Vector2(1620, 300), Vector2(1620, 560), Vector2(1980, 560)],
		[Vector2(-60, 860), Vector2(900, 860), Vector2(900, 660), Vector2(1080, 660), Vector2(1080, 520),
			Vector2(1620, 300), Vector2(1620, 560), Vector2(1980, 560)]]},
	{"name": "回旋走廊", "gold": 340, "lives": 20, "hp_growth": 0.115, "gen": [12, 99.0], "seed": 12, "paths": [[
		Vector2(-60, 700), Vector2(420, 700), Vector2(420, 340), Vector2(900, 340), Vector2(900, 760),
		Vector2(1380, 760), Vector2(1380, 420), Vector2(1980, 420)]]},
	{"name": "三路会师", "gold": 350, "lives": 20, "hp_growth": 0.12, "gen": [12, 103.0], "seed": 13, "paths": [
		[Vector2(-60, 200), Vector2(480, 200), Vector2(480, 480), Vector2(1000, 480), Vector2(1000, 760), Vector2(1980, 760)],
		[Vector2(-60, 540), Vector2(480, 540), Vector2(480, 480), Vector2(1000, 480), Vector2(1000, 760), Vector2(1980, 760)],
		[Vector2(-60, 880), Vector2(480, 880), Vector2(480, 480), Vector2(1000, 480), Vector2(1000, 760), Vector2(1980, 760)]]},
	{"name": "断桥峡谷", "gold": 360, "lives": 20, "hp_growth": 0.125, "gen": [12, 107.0], "seed": 14, "paths": [
		[Vector2(-60, 300), Vector2(700, 300), Vector2(960, 560), Vector2(1500, 560), Vector2(1500, 800), Vector2(1980, 800)],
		[Vector2(-60, 820), Vector2(700, 820), Vector2(960, 560), Vector2(1500, 560), Vector2(1500, 800), Vector2(1980, 800)]]},
	{"name": "迷雾盘径", "gold": 370, "lives": 20, "hp_growth": 0.13, "gen": [13, 111.0], "seed": 15, "paths": [[
		Vector2(-60, 160), Vector2(300, 160), Vector2(300, 460), Vector2(760, 460), Vector2(760, 160),
		Vector2(1240, 160), Vector2(1240, 460), Vector2(1660, 460), Vector2(1660, 780), Vector2(1980, 780)]]},
	{"name": "三面楚歌", "gold": 380, "lives": 20, "hp_growth": 0.135, "gen": [13, 115.0], "seed": 16, "paths": [
		[Vector2(-60, 540), Vector2(400, 540), Vector2(400, 300), Vector2(900, 300), Vector2(900, 560),
			Vector2(1400, 560), Vector2(1400, 780), Vector2(1980, 780)],
		[Vector2(900, -60), Vector2(900, 300), Vector2(900, 560), Vector2(1400, 560), Vector2(1400, 780), Vector2(1980, 780)],
		[Vector2(1400, 1140), Vector2(1400, 780), Vector2(1980, 780)]]},
	{"name": "双龙出海", "gold": 390, "lives": 20, "hp_growth": 0.14, "gen": [13, 119.0], "seed": 17, "paths": [
		[Vector2(-60, 180), Vector2(1500, 180), Vector2(1500, 540), Vector2(1980, 540)],
		[Vector2(-60, 900), Vector2(1500, 900), Vector2(1500, 540), Vector2(1980, 540)]]},
	{"name": "折返迷宫", "gold": 400, "lives": 20, "hp_growth": 0.145, "gen": [13, 123.0], "seed": 18, "paths": [[
		Vector2(-60, 220), Vector2(460, 220), Vector2(460, 560), Vector2(900, 560), Vector2(900, 220),
		Vector2(1340, 220), Vector2(1340, 560), Vector2(1980, 560)]]},
	{"name": "王城三径", "gold": 410, "lives": 20, "hp_growth": 0.15, "gen": [14, 127.0], "seed": 19, "paths": [
		[Vector2(-60, 300), Vector2(540, 300), Vector2(540, 540), Vector2(1100, 540), Vector2(1100, 300),
			Vector2(1600, 300), Vector2(1600, 540), Vector2(1980, 540)],
		[Vector2(-60, 760), Vector2(540, 760), Vector2(540, 540), Vector2(1100, 540), Vector2(1100, 300),
			Vector2(1600, 300), Vector2(1600, 540), Vector2(1980, 540)],
		[Vector2(540, -60), Vector2(540, 300), Vector2(1100, 540), Vector2(1600, 300), Vector2(1600, 540), Vector2(1980, 540)]]},
	{"name": "决战王城", "gold": 430, "lives": 20, "hp_growth": 0.16, "gen": [14, 131.0], "seed": 20, "paths": [
		[Vector2(-60, 540), Vector2(360, 540), Vector2(360, 260), Vector2(820, 260), Vector2(820, 560),
			Vector2(1280, 560), Vector2(1280, 300), Vector2(1980, 300)],
		[Vector2(-60, 120), Vector2(820, 120), Vector2(820, 260), Vector2(1280, 560), Vector2(1280, 300), Vector2(1980, 300)],
		[Vector2(-60, 960), Vector2(1280, 960), Vector2(1280, 560), Vector2(1280, 300), Vector2(1980, 300)]]},
]

const TOWER_TYPES := {
	"archer": {"name": "箭塔", "cost": 70, "damage_type": "physical", "proj_speed": 480.0,
		"levels": [
			{"damage": 9.0, "rate": 0.45, "range": 200.0},
			{"damage": 14.0, "rate": 0.40, "range": 212.0, "cost": 60},
			{"damage": 22.0, "rate": 0.35, "range": 224.0, "cost": 95, "pierce": 1},
		],
		"base": preload("res://assets/spire/tower_archer_base.png"),
		"weapons": [preload("res://assets/spire/tower_archer_w1.png"), preload("res://assets/spire/tower_archer_w2.png"), preload("res://assets/spire/tower_archer_w3.png")],
		"weapon_frames": 6, "weapon_scale": 0.85,
		"projs": [preload("res://assets/spire/tower_archer_p1.png"), preload("res://assets/spire/tower_archer_p2.png"), preload("res://assets/spire/tower_archer_p3.png")],
		"proj_size": 26.0, "hit_size": 0.025, "hit_tex": "res://assets/fx/circle_05.png"},
	"mage": {"name": "法师塔", "cost": 100, "damage_type": "magic", "proj_speed": 340.0,
		"levels": [
			{"damage": 26.0, "rate": 1.15, "range": 190.0},
			{"damage": 42.0, "rate": 1.05, "range": 202.0, "cost": 85},
			{"damage": 68.0, "rate": 0.95, "range": 214.0, "cost": 140, "chain": 2, "chain_damage": 0.6},
		],
		"base": preload("res://assets/spire/tower_mage_base.png"),
		"weapons": [preload("res://assets/spire/tower_mage_w1.png"), preload("res://assets/spire/tower_mage_w2.png"), preload("res://assets/spire/tower_mage_w3.png")],
		"weapon_frames": 8, "weapon_scale": 0.85,
		"projs": [preload("res://assets/spire/tower_mage_p1.png"), preload("res://assets/spire/tower_mage_p2.png"), preload("res://assets/spire/tower_mage_p3.png")],
		"proj_size": 16.0, "hit_size": 0.09, "hit_tex": "res://assets/fx/spark_05.png"},
	"cannon": {"name": "炮塔", "cost": 125, "damage_type": "physical", "proj_speed": 300.0,
		"levels": [
			{"damage": 20.0, "rate": 1.6, "range": 190.0, "splash": 70.0},
			{"damage": 34.0, "rate": 1.45, "range": 202.0, "splash": 80.0, "cost": 105},
			{"damage": 56.0, "rate": 1.30, "range": 214.0, "splash": 90.0, "cost": 170, "burst": 3},
		],
		"base": preload("res://assets/spire/tower_cannon_base.png"),
		"weapons": [preload("res://assets/spire/tower_cannon_w1.png"), preload("res://assets/spire/tower_cannon_w2.png"), preload("res://assets/spire/tower_cannon_w3.png")],
		"weapon_frames": 6, "weapon_scale": 0.95,
		"projs": [preload("res://assets/spire/tower_cannon_p1.png"), preload("res://assets/spire/tower_cannon_p2.png"), preload("res://assets/spire/tower_cannon_p3.png")],
		"proj_size": 26.0},
	"frost": {"name": "冰霜塔", "cost": 90, "damage_type": "magic", "proj_speed": 380.0,
		"slow_time": 2.0,
		"levels": [
			{"damage": 5.0, "rate": 1.0, "range": 200.0, "slow_pct": 0.4},
			{"damage": 9.0, "rate": 0.95, "range": 212.0, "slow_pct": 0.5, "cost": 80},
			{"damage": 14.0, "rate": 0.9, "range": 224.0, "slow_pct": 0.6, "cost": 130, "freeze_chance": 0.25, "freeze_time": 0.9},
		],
		"base": preload("res://assets/spire/tower_frost_base.png"),
		"weapons": [preload("res://assets/spire/tower_frost_w1.png"), preload("res://assets/spire/tower_frost_w2.png"), preload("res://assets/spire/tower_frost_w3.png")],
		"weapon_frames": [6, 7, 9], "weapon_scale": 0.9,
		"projs": [preload("res://assets/spire/tower_frost_p.png"), preload("res://assets/spire/tower_frost_p.png"), preload("res://assets/spire/tower_frost_p.png")],
		"proj_size": 22.0, "hit_size": 0.05, "hit_tex": "res://assets/fx/spark_05.png"},
	"poison": {"name": "毒塔", "cost": 110, "damage_type": "magic", "proj_speed": 340.0,
		"poison_time": 3.0, "weapon_tint": Color(0.7, 1.35, 0.7),
		"levels": [
			{"damage": 8.0, "rate": 1.1, "range": 200.0, "poison_dps": 10.0},
			{"damage": 12.0, "rate": 1.05, "range": 212.0, "poison_dps": 18.0, "cost": 85},
			{"damage": 18.0, "rate": 1.0, "range": 224.0, "poison_dps": 30.0, "cost": 140},
		],
		"base": preload("res://assets/spire/tower_poison_base.png"),
		"weapons": [preload("res://assets/spire/tower_poison_w1.png"), preload("res://assets/spire/tower_poison_w2.png"), preload("res://assets/spire/tower_poison_w3.png")],
		"weapon_frames": [17, 17, 17], "weapon_scale": 0.75,
		"projs": [preload("res://assets/spire/tower_poison_p.png"), preload("res://assets/spire/tower_poison_p.png"), preload("res://assets/spire/tower_poison_p.png")],
		"proj_size": 24.0, "hit_size": 0.05, "hit_tex": "res://assets/fx/circle_05.png"},
	"barracks": {"name": "兵营", "cost": 110, "damage_type": "physical",
		"levels": [
			{"soldiers": 2, "soldier_hp": 60.0, "soldier_dmg": 7.0, "respawn": 6.0, "range": 190.0},
			{"soldiers": 3, "soldier_hp": 95.0, "soldier_dmg": 12.0, "respawn": 5.0, "range": 190.0, "cost": 90},
			{"soldiers": 3, "soldier_hp": 150.0, "soldier_dmg": 19.0, "respawn": 4.0, "range": 190.0, "cost": 150},
		],
		"base": preload("res://assets/spire/tower_barracks_base.png"),
		"weapons": [null, null, null], "weapon_frames": 0, "weapon_scale": 1.0},
}

const ENEMY_TYPES := {
	"grunt": {"hp": 35.0, "speed": 55.0, "reward": 12, "damage": 1, "radius": 15.0,
		"texture": preload("res://assets/spire/enemy_leafbug.png"), "anim_frames": 6, "sprite_scale": 1.2},
	"sapper": {"hp": 26.0, "speed": 88.0, "reward": 10, "damage": 1, "radius": 11.0,
		"texture": preload("res://assets/spire/enemy_leafbug.png"), "anim_frames": 6, "sprite_scale": 0.9,
		"tint": Color(1.55, 1.35, 0.55)},
	"orc": {"hp": 105.0, "speed": 44.0, "reward": 20, "damage": 1, "radius": 18.0,
		"armor": {"physical": 1.25}, "soldier_dmg": 12.0,
		"texture": preload("res://assets/spire/enemy_scorpion.png"), "anim_frames": 8, "sprite_scale": 1.3},
	"shaman": {"hp": 90.0, "speed": 48.0, "reward": 24, "damage": 1, "radius": 14.0,
		"armor": {"magic": 0.4, "physical": 1.25}, "soldier_dmg": 14.0,
		"texture": preload("res://assets/spire/enemy_firebug.png"), "anim_frames": 6, "sprite_scale": 1.05,
		"tint": Color(1.2, 0.75, 1.55)},
	"knight": {"hp": 170.0, "speed": 36.0, "reward": 30, "damage": 2, "radius": 20.0,
		"armor": {"physical": 0.45, "magic": 1.6}, "soldier_dmg": 18.0,
		"texture": preload("res://assets/spire/enemy_magma.png"), "anim_frames": 8, "sprite_scale": 1.4},
	"raider": {"hp": 130.0, "speed": 72.0, "reward": 28, "damage": 2, "radius": 16.0,
		"armor": {"physical": 0.6, "magic": 1.1}, "soldier_dmg": 16.0,
		"texture": preload("res://assets/spire/enemy_scorpion.png"), "anim_frames": 8, "sprite_scale": 1.2,
		"tint": Color(1.45, 0.95, 0.6)},
	"ogre": {"hp": 550.0, "speed": 26.0, "reward": 65, "damage": 3, "radius": 26.0,
		"armor": {"physical": 0.85, "magic": 0.85}, "soldier_dmg": 30.0,
		"texture": preload("res://assets/spire/enemy_magma.png"), "anim_frames": 8, "sprite_scale": 1.9,
		"tint": Color(1.05, 0.9, 1.05)},
	"troll": {"hp": 950.0, "speed": 30.0, "reward": 90, "damage": 5, "radius": 30.0,
		"armor": {"magic": 0.5}, "soldier_dmg": 45.0,
		"texture": preload("res://assets/spire/enemy_magma.png"), "anim_frames": 8, "sprite_scale": 2.5,
		"tint": Color(0.95, 0.6, 0.6)},
	"saucer": {"hp": 60.0, "speed": 75.0, "reward": 14, "damage": 1, "radius": 13.0,
		"flying": true, "armor": {"magic": 1.3, "physical": 0.9},
		"texture": preload("res://assets/spire/enemy_voidfly.png"), "anim_frames": 6, "sprite_scale": 1.05},
	"recon": {"hp": 45.0, "speed": 125.0, "reward": 14, "damage": 1, "radius": 13.0,
		"flying": true, "armor": {"physical": 1.4, "magic": 0.9},
		"texture": preload("res://assets/spire/enemy_locust.png"), "anim_frames": 5, "sprite_scale": 1.0},
	"bomber": {"hp": 150.0, "speed": 60.0, "reward": 30, "damage": 3, "radius": 16.0,
		"flying": true, "armor": {"physical": 0.7, "magic": 1.2},
		"texture": preload("res://assets/spire/enemy_clampfly.png"), "anim_frames": 8, "sprite_scale": 1.35},
	"phantom": {"hp": 85.0, "speed": 70.0, "reward": 26, "damage": 2, "radius": 14.0,
		"flying": true, "armor": {"physical": 0.2, "magic": 1.8},
		"texture": preload("res://assets/spire/enemy_voidfly.png"), "anim_frames": 6, "sprite_scale": 1.1,
		"tint": Color(0.75, 0.85, 1.6, 0.62)},
}

const ENEMY_NAMES := {
	"grunt": "叶甲虫", "sapper": "花粉虫", "orc": "毒蝎", "shaman": "妖火虫",
	"knight": "熔甲蟹", "raider": "赤蝎", "ogre": "巨铠蟹", "troll": "暴君巨蟹",
	"saucer": "虚空蝶", "recon": "铁头飞蝗", "bomber": "钳击飞甲", "phantom": "幽蝶",
}

## 抗性 armor：受到该类型伤害的倍率（<1 抗性 / >1 虚弱）；flying 飞行单位无法被士兵拦截
## anim_frames：行走序列帧数（assets/spire 下的横条序列图，朝右）

const TOWER_ROLE := {
	"archer": "单体速射 · 物理伤害", "mage": "高伤爆发 · 魔法伤害",
	"cannon": "范围溅射 · 物理伤害", "frost": "减速控场 · 魔法伤害",
	"poison": "持续毒伤 · 魔法伤害",
	"barracks": "派出士兵拦截敌人",
}

const DMG_TYPE_NAMES := {"physical": "物理", "magic": "魔法"}
