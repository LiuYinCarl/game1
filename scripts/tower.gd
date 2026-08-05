extends Node2D
## 防御塔：自动索敌（选取射程内路径进度最靠前的敌人），炮塔转向目标并发射弹道。

signal fired(tower, target)

const LEVEL_DMG_MUL := [1.0, 1.6, 2.4]
const LEVEL_RANGE_BONUS := [0.0, 12.0, 24.0]
const MAX_LEVEL := 3

var type := ""
var level := 1
var base_cost := 0
var base_damage := 0.0
var base_range := 0.0
var fire_rate := 1.0
var proj_speed := 300.0
var proj_tex: Texture2D
var proj_size := 12.0
var hit_tex: Texture2D
var hit_size := 0.03
var splash := 0.0
var color := Color.WHITE
var invested := 0

var current_damage := 0.0
var current_range := 0.0
var cooldown := 0.0
var turret: Sprite2D
var last_target: Node2D = null
var idle_phase := 0.0
var elapsed := 0.0


func setup(type_name: String, data: Dictionary) -> void:
	type = type_name
	base_cost = data["cost"]
	base_damage = data["damage"]
	base_range = data["range"]
	fire_rate = data["rate"]
	proj_speed = data["proj_speed"]
	proj_tex = data["proj"]
	proj_size = data.get("proj_size", 12.0)
	if data.has("hit_tex"):
		hit_tex = load(data["hit_tex"])
	hit_size = data.get("hit_size", 0.03)
	splash = data["splash"]
	color = data["color"]
	invested = base_cost
	var base := Sprite2D.new()
	base.texture = data["base"]
	base.scale = Vector2.ONE * 1.1
	add_child(base)
	turret = Sprite2D.new()
	turret.texture = data["turret"]
	turret.scale = Vector2.ONE * 1.15
	add_child(turret)
	_refresh()


func _ready() -> void:
	# 扫视相位按位置错开，避免所有塔同步摆动
	idle_phase = position.x * 0.01 + position.y * 0.013


func _refresh() -> void:
	current_damage = base_damage * LEVEL_DMG_MUL[level - 1]
	current_range = base_range + LEVEL_RANGE_BONUS[level - 1]
	queue_redraw()


func upgrade_cost() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(round(base_cost * (0.9 if level == 1 else 1.3)))


func apply_upgrade() -> void:
	invested += upgrade_cost()
	level += 1
	_refresh()


func sell_value() -> int:
	return int(invested * 0.7)


func _process(delta: float) -> void:
	elapsed += delta
	cooldown -= delta
	if cooldown <= 0.0:
		var target := _pick_target()
		if target != null:
			last_target = target
			cooldown = fire_rate
			# 开炮后座
			var tw := create_tween()
			tw.tween_property(turret, "scale", Vector2.ONE * 1.35, 0.05)
			tw.tween_property(turret, "scale", Vector2.ONE * 1.15, 0.15)
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
	# 等级标记
	for i in level:
		draw_circle(Vector2(-8.0 + i * 8.0, 22.0), 3.0, Color.YELLOW)
