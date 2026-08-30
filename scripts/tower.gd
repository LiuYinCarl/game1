extends Node2D
## 防御塔：索敌开火（箭塔/法师塔/炮塔）或派兵拦截（兵营）。
## 兵营不发射弹道，而是在集合点驻守士兵，阵亡后计时补充。

signal fired(tower, target)

const Soldier = preload("res://scripts/soldier.gd")
const MAX_LEVEL := 3

var type := ""
var level := 1
var base_cost := 0
var stats_levels: Array = []  # 逐级数值表（见 main.gd TOWER_TYPES 注释）
var proj_speed := 300.0
var proj_tex: Texture2D
var proj_size := 12.0
var hit_tex: Texture2D
var hit_size := 0.03
var damage_type := "physical"  # physical / magic
var invested := 0

var current_damage := 0.0
var current_range := 0.0
var fire_rate := 1.0
var splash := 0.0
var cooldown := 0.0
var base: Sprite2D
var weapons: Array = []
var weapon_frames_arr: Array = []  # 各级武器帧数（可不同）
var weapon_scale := 1.0
var projs: Array = []
var slow_pct := 0.0  # 冰霜塔：命中减速幅度/时长
var slow_time := 0.0
var pierce := 0  # 箭塔 3 级技能：穿透额外目标数
var freeze_chance := 0.0  # 冰霜塔 3 级：冻结概率/时长
var freeze_time := 0.0
var poison_dps := 0.0  # 毒塔：中毒持续伤害/时长
var poison_time := 0.0
var weapon_tint := Color.WHITE
var burst := 1  # 炮塔 3 级：弹幕连发数量
var chain := 0  # 法师塔 3 级：连锁闪电目标数
var chain_damage := 0.6
var turret: Sprite2D
var last_target: Node2D = null

# 兵营专用
var rally_point := Vector2.ZERO
var rally_dir := Vector2.RIGHT
var rally_active := false
var soldiers: Array = []
var respawn_timer := 0.0

const SOLDIER_TINTS := [Color.WHITE, Color(1.15, 1.05, 0.9), Color(1.4, 1.2, 0.6)]


func setup(type_name: String, data: Dictionary) -> void:
	type = type_name
	base_cost = data["cost"]
	stats_levels = data["levels"]
	damage_type = data.get("damage_type", "physical")
	proj_speed = data.get("proj_speed", 300.0)
	proj_tex = data.get("proj")
	proj_size = data.get("proj_size", 12.0)
	if data.has("hit_tex"):
		hit_tex = load(data["hit_tex"])
	hit_size = data.get("hit_size", 0.03)
	invested = base_cost
	# 底座：一张图含 1/2/3 级三个外观帧
	base = Sprite2D.new()
	base.texture = data["base"]
	base.hframes = 3
	base.frame = 0
	add_child(base)
	weapons = data.get("weapons", [null, null, null])
	var wf = data.get("weapon_frames", 0)
	weapon_frames_arr = wf if wf is Array else [wf, wf, wf]
	weapon_scale = float(data.get("weapon_scale", 1.0))
	projs = data.get("projs", [proj_tex, proj_tex, proj_tex])
	slow_pct = data.get("slow_pct", 0.0)
	slow_time = data.get("slow_time", 0.0)
	poison_dps = data.get("poison_dps", 0.0)
	poison_time = data.get("poison_time", 0.0)
	weapon_tint = data.get("weapon_tint", Color.WHITE)
	turret = Sprite2D.new()
	if weapons[0] != null:
		turret.texture = weapons[0]
		turret.hframes = weapon_frames_arr[0]
		turret.frame = 0
		turret.position = WEAPON_OFFSET
		turret.scale = Vector2.ONE * weapon_scale
		turret.z_index = 20
	add_child(turret)
	_refresh()


const WEAPON_OFFSET := Vector2(0, -30)


func _ready() -> void:
	pass
func _refresh() -> void:
	var lv: Dictionary = stats_levels[level - 1]
	current_damage = lv.get("damage", 0.0)
	fire_rate = lv.get("rate", 1.0)
	current_range = lv.get("range", 0.0)
	splash = lv.get("splash", 0.0)
	pierce = lv.get("pierce", 0)
	poison_dps = lv.get("poison_dps", poison_dps)
	freeze_chance = lv.get("freeze_chance", 0.0)
	freeze_time = lv.get("freeze_time", 0.0)
	burst = lv.get("burst", 1)
	chain = lv.get("chain", 0)
	chain_damage = lv.get("chain_damage", 0.6)
	# 等级外观：底座换帧 + 换武器贴图
	base.frame = level - 1
	turret.modulate = weapon_tint
	if weapons[level - 1] != null:
		turret.texture = weapons[level - 1]
		turret.hframes = weapon_frames_arr[level - 1]
		turret.frame = 0
	if projs[level - 1] != null:
		proj_tex = projs[level - 1]
	# 升级后同步在场士兵的攻击力（生命由下一次补充时生效）
	for s in soldiers:
		if is_instance_valid(s):
			s.damage = lv.get("soldier_dmg", s.damage)
	queue_redraw()


func upgrade_cost() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(stats_levels[level]["cost"])


func apply_upgrade() -> void:
	invested += upgrade_cost()
	level += 1
	_refresh()


func sell_value() -> int:
	return int(invested * 0.7)


func barracks_stats() -> Dictionary:
	return stats_levels[level - 1]


## 设置集合点（主程序把路径上的点换算好传入）
func set_rally(pos: Vector2, dir: Vector2) -> void:
	rally_point = pos
	rally_dir = dir
	rally_active = true
	var want := int(barracks_stats().get("soldiers", 2))
	for i in soldiers.size():
		if is_instance_valid(soldiers[i]):
			soldiers[i].set_rally(rally_point, _slot_offset(i, want))


func _slot_offset(i: int, n: int) -> Vector2:
	# 士兵沿路径垂直方向一字排开
	return rally_dir.orthogonal() * (float(i) - float(n - 1) * 0.5) * 26.0


func _process(delta: float) -> void:
	if type == "barracks":
		_process_barracks(delta)
		return
	cooldown -= delta
	if cooldown <= 0.0:
		var target := _pick_target()
		if target != null:
			last_target = target
			cooldown = fire_rate
			_play_attack_anim()
			fired.emit(self, target)
		else:
			cooldown = 0.1


## 播放武器攻击动画（帧序列播一遍后回到待机的第 0 帧）
func _play_attack_anim() -> void:
	var frames := int(weapon_frames_arr[level - 1])
	if frames <= 1 or not is_instance_valid(turret) or turret.texture == null:
		return
	var tw := create_tween()
	tw.tween_method(func(f: int) -> void: turret.frame = clampi(f, 0, frames - 1),
		0, frames - 1, 0.22)
	tw.tween_callback(func() -> void: turret.frame = 0)


func _process_barracks(delta: float) -> void:
	var lv := barracks_stats()
	var want := int(lv.get("soldiers", 2))
	soldiers = soldiers.filter(func(s: Node) -> bool: return is_instance_valid(s))
	respawn_timer -= delta
	if soldiers.size() < want and respawn_timer <= 0.0:
		_spawn_soldier()
		respawn_timer = float(lv.get("respawn", 6.0))


func _spawn_soldier() -> void:
	var lv := barracks_stats()
	var s := Soldier.new()
	var want := int(lv.get("soldiers", 2))
	s.setup(self, rally_point,
		_slot_offset(soldiers.size(), want), float(lv.get("soldier_hp", 60.0)),
		float(lv.get("soldier_dmg", 7.0)), SOLDIER_TINTS[level - 1])
	add_child(s)
	# 局部坐标出生（建造缩放动画期间设全局坐标会被除以近零缩放放大）
	s.position = Vector2(0, -8)
	soldiers.append(s)
	# 补兵小动效
	var tw := create_tween()
	tw.tween_property(base, "scale", Vector2.ONE * 1.06, 0.08)
	tw.tween_property(base, "scale", Vector2.ONE, 0.2)


func on_soldier_died(s) -> void:
	soldiers.erase(s)
	respawn_timer = maxf(respawn_timer, float(barracks_stats().get("respawn", 6.0)))


func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_progress := -1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) > current_range:
			continue
		if e.progress > best_progress:
			best_progress = e.progress
			best = e
	return best


func _draw() -> void:
	# 底座阴影（父节点绘制层级在贴图之下）
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 等级星标：深色描边 + 金色圆点
	for i in level:
		var p := Vector2(-8.0 + i * 8.0, 26.0)
		draw_circle(p, 4.5, Color(0.12, 0.08, 0.02, 0.65))
		draw_circle(p, 3.2, Color("ffd24a"))
