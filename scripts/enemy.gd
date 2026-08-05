extends Node2D
## 沿固定路径移动的敌人，精灵图朝向移动方向，自带血条绘制。

signal died(enemy)
signal reached_end(enemy)

var type := ""
var max_hp := 1.0
var hp := 1.0
var speed := 50.0
var reward := 0
var damage := 1
var radius := 10.0
var color := Color.RED

var path := PackedVector2Array()
var seg_lengths := PackedFloat32Array()
var seg := 0
var seg_progress := 0.0
var progress := 0.0  # 已走过的总路程，用于防御塔选取"最靠前"目标
var dead := false
var sprite: Sprite2D
var anim_time := 0.0
var sprite_scale := 1.0


func setup(type_name: String, pts: PackedVector2Array, data: Dictionary, hp_scale: float) -> void:
	type = type_name
	path = pts
	max_hp = data["hp"] * hp_scale
	hp = max_hp
	speed = data["speed"]
	reward = data["reward"]
	damage = data["damage"]
	radius = data["radius"]
	color = data["color"]
	position = path[0]
	for i in path.size() - 1:
		seg_lengths.append(path[i].distance_to(path[i + 1]))
	add_to_group("enemies")
	sprite = Sprite2D.new()
	sprite.texture = data["texture"]
	sprite_scale = data["sprite_scale"]
	sprite.scale = Vector2.ZERO
	add_child(sprite)
	# 出场弹出
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE * sprite_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if dead:
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
				reached_end.emit(self)
				queue_free()
				return
	var dir: Vector2 = (path[seg + 1] - path[seg]).normalized()
	position = path[seg] + dir * seg_progress
	# 行进动效：速度越快颠簸越急，外加轻微摇摆
	anim_time += delta
	var freq := speed * 0.22
	sprite.position.y = sin(anim_time * freq) * 1.5
	sprite.rotation = dir.angle() + PI / 2.0 + sin(anim_time * freq * 0.5) * 0.06


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()
	else:
		# 受击闪白
		sprite.modulate = Color(4, 4, 4)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		queue_redraw()


func _draw() -> void:
	# 血条
	var w := radius * 2.2
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var top := -radius - 9.0
	draw_rect(Rect2(-w / 2.0, top, w, 4.0), Color("3a0d0d"))
	draw_rect(Rect2(-w / 2.0, top, w * ratio, 4.0), Color("5fd35f"))
