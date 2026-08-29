extends Node2D
## 兵营士兵：驻守集合点，拦截路面敌人近战对拼；阵亡后由兵营计时补充。

var tower: Node2D = null  # 所属兵营
var rally := Vector2.ZERO
var slot := Vector2.ZERO  # 相对集合点的站位偏移
var max_hp := 60.0
var hp := 60.0
var damage := 7.0
var speed := 95.0
var attack_cd := 0.0
var target: Node2D = null
var dead := false
var sprite: Sprite2D
var tint := Color(0.6, 0.78, 1.45)
var base_rot := 0.0
var anim_time := 0.0

const ENGAGE := 85.0  # 集合点周围的接敌半径


func setup(tower_ref: Node2D, rally_pos: Vector2, slot_off: Vector2, s_hp: float, s_dmg: float, s_tint: Color) -> void:
	tower = tower_ref
	rally = rally_pos
	slot = slot_off
	max_hp = s_hp
	hp = s_hp
	damage = s_dmg
	tint = s_tint
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/spire/soldier_wisp.png")
	sprite.hframes = 4
	sprite.modulate = tint
	sprite.scale = Vector2.ONE * 0.45
	add_child(sprite)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE * 0.55, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 随机攻击相位，避免多个士兵同步挥击/同步闪白
	attack_cd = randf_range(0.0, 0.9)


func _process(delta: float) -> void:
	if dead:
		return
	attack_cd -= delta
	anim_time += delta
	# 目标失效 / 离开接敌范围 / 已被别人拦截 → 放手
	if target != null and (not is_instance_valid(target) or target.dead or target.flying
			or target.global_position.distance_to(rally) > ENGAGE + 40.0
			or (target.blocked_by != null and target.blocked_by != self)):
		_release_target()
	if target == null:
		target = _pick_target()
	if target != null:
		var d: Vector2 = target.global_position - global_position
		base_rot = d.angle()
		if d.length() > 13.0:
			global_position += d.normalized() * speed * delta
		elif attack_cd <= 0.0:
			# 近战互殴：锁敌后原地输出
			target.blocked_by = self
			attack_cd = 1.0
			target.take_damage(damage, "physical")
			# 轻量命中小特效
			var game: Node2D = get_tree().get_first_node_in_group("game")
			if game != null:
				game.spawn_particles(target.global_position, {"texture": game.FX_DOT,
					"color": Color("ffe9a0"), "count": 4, "speed": 70.0, "size": 0.022,
					"gravity": 220.0, "lifetime": 0.22, "add": true, "rand_angle": true})
		# 灵体保持直立，只播放浮动动画
		sprite.rotation = sin(anim_time * 3.0) * 0.06
		sprite.frame = int(anim_time * 8.0) % 4
	elif is_instance_valid(tower) and tower.rally_active:
		var dest: Vector2 = rally + slot
		var d := dest - global_position
		if d.length() > 4.0:
			global_position += d.normalized() * speed * delta
		sprite.rotation = sin(anim_time * 3.0) * 0.06
		sprite.frame = int(anim_time * 8.0) % 4
	else:
		sprite.rotation = sin(anim_time * 3.0) * 0.06
		sprite.frame = int(anim_time * 8.0) % 4
	queue_redraw()


func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.flying:
			continue
		if e.blocked_by != null and e.blocked_by != self:
			continue
		var d: float = e.global_position.distance_to(rally)
		if d <= ENGAGE and d < best_d:
			best_d = d
			best = e
	return best


func _release_target() -> void:
	if is_instance_valid(target) and target.blocked_by == self:
		target.blocked_by = null
	target = null


## 敌人死亡或到达终点时由对方回调，立刻放手去找下一个
func on_target_gone() -> void:
	if target != null and not is_instance_valid(target):
		target = null


func set_rally(rally_pos: Vector2, slot_off: Vector2) -> void:
	rally = rally_pos
	slot = slot_off
	if target != null and (not is_instance_valid(target) or target.global_position.distance_to(rally) > ENGAGE + 40.0):
		_release_target()


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(2.2, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", tint, 0.15)
	if hp <= 0.0:
		dead = true
		_release_target()
		var game := get_tree().get_first_node_in_group("game")
		if game != null:
			game.spawn_particles(global_position, {"texture": game.FX_SMOKE2, "color": Color(0.55, 0.65, 0.9),
				"count": 8, "speed": 70.0, "size": 0.06, "gravity": 30.0, "lifetime": 0.6, "grow": 1.6,
				"turb_strength": 1.2, "rand_angle": true})
		if is_instance_valid(tower):
			tower.on_soldier_died(self)
		queue_free()


func _draw() -> void:
	# 落地阴影
	draw_set_transform(Vector2(2, 9), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 受损后显示迷你血条
	if hp < max_hp:
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-11, -22, 22, 4.0), Color(0.08, 0.05, 0.05, 0.85))
		draw_rect(Rect2(-11, -22, 22.0 * ratio, 4.0), Color("5fb0ff") if ratio > 0.4 else Color("e05244"))
