extends Node2D
## 追踪弹道的投射物；炮弹命中时造成范围伤害。

var target: Node2D = null
var speed := 300.0
var damage := 0.0
var damage_type := "physical"
var splash := 0.0
var slow_pct := 0.0  # 命中减速（冰霜塔）
var slow_time := 0.0
var pierce := 0  # 穿透：命中后继续飞向附近的下一个目标（箭塔 3 级）
var hit_list: Array = []
var hit_tex: Texture2D = null
var hit_size := 0.03
var sprite: Sprite2D
var trail: Line2D
var last_pos := Vector2.ZERO


func setup(from_pos: Vector2, tgt: Node2D, spd: float, dmg: float, spl: float, tex: Texture2D, display_size: float, p_hit_tex: Texture2D = null, p_hit_size := 0.03, p_dtype := "physical") -> void:
	position = from_pos + Vector2(0, -10)
	last_pos = position
	target = tgt
	speed = spd
	damage = dmg
	damage_type = p_dtype
	splash = spl
	hit_tex = p_hit_tex
	hit_size = p_hit_size
	# 弹体贴图留白多，按实际内容区域裁剪后再缩放到目标显示尺寸
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = tex.get_image().get_used_rect()
	sprite = Sprite2D.new()
	sprite.texture = atlas
	var content: Vector2 = atlas.region.size
	sprite.scale = Vector2.ONE * display_size / maxf(content.x, content.y)
	add_child(sprite)
	# 发光拖尾：淡入淡出的折线，宽度按弹体尺寸比例
	trail = Line2D.new()
	trail.width = display_size * 0.32
	trail.default_color = Color(1.0, 0.9, 0.55, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 0.0))
	grad.set_color(1, Color(1.0, 0.95, 0.7, 0.55))
	trail.gradient = grad
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = cm
	trail.z_index = -1
	add_child(trail)


func _ready() -> void:
	# 拖尾快速淡入（必须在入树后创建补间）
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: trail.modulate.a = a, 0.0, 1.0, 0.08)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var tp: Vector2 = target.global_position
	var d := tp - global_position
	var step := speed * delta
	sprite.rotation = d.angle() + PI / 2.0
	# 拖尾记录走过的点，限制长度并渐隐收尾
	if global_position.distance_to(last_pos) > 6.0:
		trail.add_point(global_position + Vector2(0, -10))
		last_pos = global_position
		while trail.get_point_count() > 10:
			trail.remove_point(0)
	if d.length() <= step + 4.0:
		_hit(tp)
		# 穿透：命中后飞向附近的下一个未命中目标
		if pierce > 0:
			pierce -= 1
			hit_list.append(target)
			var nxt: Node2D = null
			var nd := INF
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or e.dead or e in hit_list:
					continue
				var dd: float = e.global_position.distance_to(global_position)
				if dd <= 80.0 and dd < nd:
					nd = dd
					nxt = e
			if nxt != null:
				target = nxt
				return
		queue_free()
	else:
		global_position += d.normalized() * step


func _hit(pos: Vector2) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		if splash <= 0.0 and is_instance_valid(target):
			target.take_damage(damage)
		return
	if splash > 0.0:
		game.spawn_explosion(pos)
		game.play_sfx("explosion")
		game.shake_amp = maxf(game.shake_amp, 6.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) <= splash:
				e.take_damage(damage, damage_type)
	else:
		game.play_sfx("hit_magic" if damage_type == "magic" else "hit")
		game.spawn_particles(pos, {"texture": hit_tex if hit_tex != null else game.FX_DOT,
			"color": Color("fff3b0"), "count": 6, "speed": 110.0,
			"size": hit_size, "gravity": 300.0, "lifetime": 0.35, "add": true, "rand_angle": true})
		if is_instance_valid(target):
			target.take_damage(damage, damage_type)
			if slow_pct > 0.0:
				target.apply_slow(slow_pct, slow_time)
