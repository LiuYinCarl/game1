extends Node2D
## 沿固定路径移动的敌人：物理/魔法抗性、飞行单位、被兵营士兵拦截后驻停对拼。

signal died(enemy)
signal reached_end(enemy)

const FLY_HEIGHT := 24.0

var type := ""
var max_hp := 1.0
var hp := 1.0
var speed := 50.0
var reward := 0
var damage := 1
var radius := 10.0
var armor := {}  # {"physical": 0.5, ...}，缺省 1.0
var soldier_dmg := 8.0  # 拦截战中对士兵的每次攻击
var flying := false
var tint := Color.WHITE

var path := PackedVector2Array()
var seg_lengths := PackedFloat32Array()
var seg := 0
var seg_progress := 0.0
var progress := 0.0  # 已走过的总路程，用于防御塔选取"最靠前"目标
var dead := false
var blocked_by: Node2D = null  # 拦截自己的士兵，非空时驻停作战
var attack_cd := 0.0
var selected := false

var sprite: Sprite2D
var anim_time := 0.0
var anim_frames := 1
var sprite_scale := 1.0
var base_rot := 0.0  # 朝向基准角，行进颠簸/受击摆动叠加在其上


func setup(type_name: String, pts: PackedVector2Array, data: Dictionary, hp_scale: float) -> void:
	type = type_name
	path = pts
	max_hp = data["hp"] * hp_scale
	hp = max_hp
	speed = data["speed"]
	reward = data["reward"]
	damage = data["damage"]
	radius = data["radius"]
	armor = data.get("armor", {})
	soldier_dmg = data.get("soldier_dmg", 8.0)
	flying = data.get("flying", false)
	tint = data.get("tint", Color.WHITE)
	position = path[0]
	for i in path.size() - 1:
		seg_lengths.append(path[i].distance_to(path[i + 1]))
	add_to_group("enemies")
	sprite = Sprite2D.new()
	sprite.texture = data["texture"]
	anim_frames = int(data.get("anim_frames", 1))
	sprite.hframes = anim_frames
	sprite_scale = data["sprite_scale"]
	sprite.modulate = tint
	sprite.scale = Vector2.ZERO
	add_child(sprite)
	# 出场弹出
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE * sprite_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if dead:
		return
	attack_cd -= delta
	# 被士兵拦截：驻停对拼，不推进
	if blocked_by != null:
		if not is_instance_valid(blocked_by):
			blocked_by = null
		else:
			# 序列帧贴图朝下，朝向角为 dir.angle() - PI/2
			var fdir: float = (blocked_by.global_position - global_position).angle() - PI / 2.0
			base_rot = lerp_angle(base_rot, fdir, minf(1.0, delta * 8.0))
			_bob(delta, 1.2)
			if attack_cd <= 0.0:
				attack_cd = 1.15
				blocked_by.take_damage(soldier_dmg)
			return
	var move := speed * delta
	while move > 0.0:
		var left := seg_lengths[seg] - seg_progress
		if move < left:
			seg_progress += move
			progress += move
			move = 0.0
		else:
			move -= left
			progress += left
			seg += 1
			seg_progress = 0.0
			if seg >= seg_lengths.size():
				dead = true
				if is_instance_valid(blocked_by):
					blocked_by.on_target_gone()
				reached_end.emit(self)
				queue_free()
				return
	var dir: Vector2 = (path[seg + 1] - path[seg]).normalized()
	position = path[seg] + dir * seg_progress
	base_rot = dir.angle() - PI / 2.0  # 序列帧贴图朝下
	# 行进动效：速度越快颠簸越急，飞行单位悬空更高、上下浮动更明显
	_bob(delta, 2.6 if flying else 1.5)


func _bob(delta: float, amp: float) -> void:
	anim_time += delta
	var freq := speed * 0.22
	var hover := FLY_HEIGHT if flying else 0.0
	sprite.position.y = sin(anim_time * freq) * amp - hover + sin(anim_time * 2.0) * (2.0 if flying else 0.0)
	sprite.rotation = base_rot + sin(anim_time * freq * 0.5) * 0.06
	# 行走序列帧动画
	if anim_frames > 1:
		sprite.frame = int(anim_time * 10.0) % anim_frames


func take_damage(amount: float, dtype: String = "physical") -> void:
	if dead:
		return
	hp -= amount * float(armor.get(dtype, 1.0))
	if hp <= 0.0:
		dead = true
		if is_instance_valid(blocked_by):
			blocked_by.on_target_gone()
		died.emit(self)
		queue_free()
	else:
		# 受击闪白：温和超亮，保留轮廓（过强会把小贴图饱和成白色方块）
		sprite.modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", tint, 0.15)
		queue_redraw()


func armor_mult(dtype: String) -> float:
	return float(armor.get(dtype, 1.0))


func _draw() -> void:
	# 落地阴影：飞行单位投在更远的地面
	var sh_y := 10.0 + FLY_HEIGHT if flying else 10.0
	draw_set_transform(Vector2(2, sh_y), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, radius * (0.9 if flying else 1.15), Color(0, 0, 0, 0.28 if not flying else 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 选中高亮圈
	if selected:
		var cy := -FLY_HEIGHT if flying else 0.0
		draw_arc(Vector2(0, cy), radius + 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 2.0)
	# 血条：描边底槽 + 明暗渐变血量，血量越低颜色越红
	var w := radius * 2.4
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var top := -radius - 11.0 - (FLY_HEIGHT if flying else 0.0)
	draw_rect(Rect2(-w / 2.0 - 1.0, top - 1.0, w + 2.0, 6.0), Color(0.08, 0.05, 0.05, 0.85))
	draw_rect(Rect2(-w / 2.0, top, w, 4.0), Color("3a0d0d"))
	var bar_col: Color
	if ratio > 0.5:
		bar_col = Color("76d84f").lerp(Color("c8d84f"), (1.0 - ratio) * 2.0)
	else:
		bar_col = Color("e8a33d").lerp(Color("e05244"), 1.0 - ratio * 2.0)
	draw_rect(Rect2(-w / 2.0, top, w * ratio, 4.0), bar_col)
	if ratio > 0.04:
		# 血条上缘高光线
		draw_rect(Rect2(-w / 2.0, top, w * ratio, 1.2), Color(1, 1, 1, 0.35))
