extends Node2D
## 追踪弹道的投射物；炮弹命中时造成范围伤害。

var target: Node2D = null
var speed := 300.0
var damage := 0.0
var splash := 0.0
var hit_tex: Texture2D = null
var hit_size := 0.03
var sprite: Sprite2D


func setup(from_pos: Vector2, tgt: Node2D, spd: float, dmg: float, spl: float, tex: Texture2D, display_size: float, p_hit_tex: Texture2D = null, p_hit_size := 0.03) -> void:
	position = from_pos + Vector2(0, -10)
	target = tgt
	speed = spd
	damage = dmg
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


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var tp: Vector2 = target.global_position
	var d := tp - global_position
	var step := speed * delta
	sprite.rotation = d.angle() + PI / 2.0
	if d.length() <= step + 4.0:
		_hit(tp)
		queue_free()
	else:
		global_position += d.normalized() * step


func _hit(pos: Vector2) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if splash > 0.0:
		if game != null:
			game.spawn_explosion(pos)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) <= splash:
				e.take_damage(damage)
	else:
		if game != null:
			game.spawn_particles(pos, {"texture": hit_tex if hit_tex != null else game.FX_DOT,
				"color": Color("fff3b0"), "count": 6, "speed": 110.0,
				"size": hit_size, "gravity": 300.0, "lifetime": 0.35, "add": true, "rand_angle": true})
		if is_instance_valid(target):
			target.take_damage(damage)
