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
var color := Color.WHITE
var invested := 0

var current_damage := 0.0
var current_range := 0.0
var fire_rate := 1.0
var splash := 0.0
var cooldown := 0.0
var turret: Sprite2D
var turret_textures: Array = []
var turret_tints: Array = []
var turret_scale := 1.15
var last_target: Node2D = null
var idle_phase := 0.0
var elapsed := 0.0

# 兵营专用
var rally_point := Vector2.ZERO
var rally_dir := Vector2.RIGHT
var rally_active := false
var soldiers: Array = []
var respawn_timer := 0.0

const SOLDIER_TINTS := [Color(0.6, 0.78, 1.45), Color(0.5, 0.9, 1.35), Color(1.4, 1.15, 0.55)]


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
	color = data["color"]
	invested = base_cost
	var base := Sprite2D.new()
	base.texture = data["base"]
	base.scale = Vector2.ONE * 1.1
	add_child(base)
	turret_textures = data["turrets"]
	turret_tints = data["tints"]
	turret = Sprite2D.new()
	add_child(turret)
	_refresh()


func _ready() -> void:
	# 扫视相位按位置错开，避免所有塔同步摆动
	idle_phase = position.x * 0.01 + position.y * 0.013


func _refresh() -> void:
	var lv: Dictionary = stats_levels[level - 1]
	current_damage = lv.get("damage", 0.0)
	fire_rate = lv.get("rate", 1.0)
	current_range = lv.get("range", 0.0)
	splash = lv.get("splash", 0.0)
	# 等级外观：换贴图/染色/放大
	turret.texture = turret_textures[level - 1]
	turret.modulate = turret_tints[level - 1]
	turret_scale = (1.35 if type == "barracks" else 1.15) + (level - 1) * 0.1
	turret.scale = Vector2.ONE * turret_scale
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
	elapsed += delta
	if type == "barracks":
		_process_barracks(delta)
		return
	cooldown -= delta
	if cooldown <= 0.0:
		var target := _pick_target()
		if target != null:
			last_target = target
			cooldown = fire_rate
			# 开炮后座
			var tw := create_tween()
			tw.tween_property(turret, "scale", Vector2.ONE * turret_scale * 1.2, 0.05)
			tw.tween_property(turret, "scale", Vector2.ONE * turret_scale, 0.15)
			fired.emit(self, target)
		else:
			cooldown = 0.1
	# 平滑转向：有目标瞄准目标，无目标缓慢扫视
	var desired := 0.0
	if is_instance_valid(last_target) and not last_target.dead \
			and global_position.distance_to(last_target.global_position) <= current_range:
		desired = (last_target.global_position - global_position).angle() + PI / 2.0
	else:
		last_target = null
		desired = sin(elapsed * 0.8 + idle_phase) * 0.5
	turret.rotation = lerp_angle(turret.rotation, desired, minf(1.0, delta * 8.0))


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
	tw.tween_property(turret, "scale", Vector2.ONE * turret_scale * 1.15, 0.08)
	tw.tween_property(turret, "scale", Vector2.ONE * turret_scale, 0.2)


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
