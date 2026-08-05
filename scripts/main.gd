extends Node2D
## 游戏主管理器：地图、波次、金币/生命、建造菜单与胜负结算。

const Enemy = preload("res://scripts/enemy.gd")
const Tower = preload("res://scripts/tower.gd")
const Projectile = preload("res://scripts/projectile.gd")

# Kenney Tower Defense (Top-Down) 素材（CC0）
const TEX_SPOT = preload("res://assets/td/towerDefense_tile182.png")
const TEX_BUSH = preload("res://assets/td/towerDefense_tile130.png")
const TEX_BUSH_SMALL = preload("res://assets/td/towerDefense_tile131.png")
const TEX_PLANT = preload("res://assets/td/towerDefense_tile132.png")
const TEX_TREE = preload("res://assets/td/towerDefense_tile134.png")
const TEX_ROCK1 = preload("res://assets/td/towerDefense_tile135.png")
const TEX_ROCK2 = preload("res://assets/td/towerDefense_tile136.png")
const TEX_ROCK3 = preload("res://assets/td/towerDefense_tile137.png")

# Kenney Particle Pack 粒子贴图（CC0）
const FX_FLAME = preload("res://assets/fx/flame_05.png")
const FX_SMOKE = preload("res://assets/fx/smoke_04.png")
const FX_SMOKE2 = preload("res://assets/fx/smoke_05.png")
const FX_MUZZLE = preload("res://assets/fx/muzzle_02.png")
const FX_DOT = preload("res://assets/fx/circle_05.png")
const FX_STAR = preload("res://assets/fx/star_02.png")
const FX_LIGHTNING = preload("res://assets/fx/spark_05.png")

var SCREEN := Vector2(1920, 1080)

var PATH_POINTS := PackedVector2Array([
	Vector2(-60, 200), Vector2(480, 200), Vector2(480, 780),
	Vector2(960, 780), Vector2(960, 320), Vector2(1400, 320),
	Vector2(1400, 820), Vector2(1980, 820),
])

var CASTLE_POS := Vector2(1860, 820)

var BUILD_SPOTS: Array[Vector2] = [
	Vector2(300, 340), Vector2(300, 80), Vector2(640, 140),
	Vector2(640, 500), Vector2(340, 870), Vector2(640, 940),
	Vector2(800, 600), Vector2(1100, 480), Vector2(1100, 150),
	Vector2(840, 320), Vector2(1540, 200), Vector2(1540, 600),
	Vector2(1280, 930), Vector2(1600, 960), Vector2(1700, 650),
]

var ENEMY_TYPES := {
	"grunt": {"hp": 35.0, "speed": 55.0, "reward": 12, "damage": 1, "radius": 13.0, "color": Color("6aa84f"),
		"texture": preload("res://assets/td/towerDefense_tile245.png"), "sprite_scale": 1.0},
	"wolf": {"hp": 24.0, "speed": 105.0, "reward": 9, "damage": 1, "radius": 13.0, "color": Color("b7b7b7"),
		"texture": preload("res://assets/td/towerDefense_tile270.png"), "sprite_scale": 0.75},
	"orc": {"hp": 100.0, "speed": 44.0, "reward": 20, "damage": 1, "radius": 15.0, "color": Color("38761d"),
		"texture": preload("res://assets/td/towerDefense_tile247.png"), "sprite_scale": 1.15},
	"ogre": {"hp": 550.0, "speed": 26.0, "reward": 100, "damage": 3, "radius": 22.0, "color": Color("674ea7"),
		"texture": preload("res://assets/td/towerDefense_tile250.png"), "sprite_scale": 1.5},
}

var TOWER_TYPES := {
	"archer": {"name": "箭塔", "cost": 70, "range": 200.0, "damage": 9.0, "rate": 0.45, "proj_speed": 480.0, "splash": 0.0, "color": Color("c07f2a"),
		"base": preload("res://assets/td/towerDefense_tile180.png"),
		"turret": preload("res://assets/td/towerDefense_tile226.png"), "proj": preload("res://assets/td/towerDefense_tile272.png"), "proj_size": 14.0, "hit_size": 0.025, "hit_tex": "res://assets/fx/circle_05.png"},
	"mage": {"name": "法师塔", "cost": 100, "range": 190.0, "damage": 26.0, "rate": 1.15, "proj_speed": 340.0, "splash": 0.0, "color": Color("7a5fd0"),
		"base": preload("res://assets/td/towerDefense_tile180.png"),
		"turret": preload("res://assets/td/towerDefense_tile203.png"), "proj": preload("res://assets/td/towerDefense_tile251.png"), "proj_size": 42.0, "hit_size": 0.09, "hit_tex": "res://assets/fx/spark_05.png"},
	"cannon": {"name": "炮塔", "cost": 125, "range": 190.0, "damage": 20.0, "rate": 1.6, "proj_speed": 300.0, "splash": 70.0, "color": Color("555555"),
		"base": preload("res://assets/td/towerDefense_tile180.png"),
		"turret": preload("res://assets/td/towerDefense_tile228.png"), "proj": preload("res://assets/td/towerDefense_tile274.png"), "proj_size": 18.0},
}

const START_GOLD := 230
const START_LIVES := 20

const WAVES := [
	[{"type": "grunt", "count": 6, "interval": 1.1}],
	[{"type": "grunt", "count": 8, "interval": 0.9}, {"type": "wolf", "count": 3, "interval": 0.8, "delay": 3.0}],
	[{"type": "grunt", "count": 6, "interval": 0.8}, {"type": "orc", "count": 3, "interval": 1.3, "delay": 2.0}],
	[{"type": "wolf", "count": 8, "interval": 0.5}, {"type": "grunt", "count": 6, "interval": 0.9, "delay": 4.0}],
	[{"type": "orc", "count": 6, "interval": 1.0}, {"type": "grunt", "count": 6, "interval": 0.7, "delay": 2.0}],
	[{"type": "wolf", "count": 10, "interval": 0.4}, {"type": "orc", "count": 4, "interval": 1.0, "delay": 3.0}],
	[{"type": "orc", "count": 8, "interval": 0.8}, {"type": "wolf", "count": 6, "interval": 0.5, "delay": 2.0}, {"type": "grunt", "count": 8, "interval": 0.6, "delay": 5.0}],
	[{"type": "ogre", "count": 1, "interval": 1.0}, {"type": "orc", "count": 6, "interval": 0.9, "delay": 3.0}, {"type": "wolf", "count": 8, "interval": 0.5, "delay": 6.0}],
]

var gold: int
var lives: int
var next_wave := 0  # 已开始的波次数
var wave_active := false
var game_ended := false
var spawn_events: Array = []
var spawn_hp_scale := 1.0
var wave_time := 0.0
var towers := {}  # spot_index -> Tower
var selected_spot := -1
var smoke_test := false
var smoke_shots := {}

var map_drawer: Node2D
var ui_root: Control
var gold_label: Label
var lives_label: Label
var wave_label: Label
var gold_badge: Control
var lives_badge: Control
var wave_badge: Control
var last_gold := -1
var last_lives := -1
var last_wave := -1
var start_button: Button
var hint_label: Label
var menu_panel: PanelContainer
var speed_button: Button
var debug_panel: PanelContainer
var music_player: AudioStreamPlayer

const SPEEDS := [1.0, 2.0, 3.0]
var speed_idx := 0


class MapDrawer extends Node2D:
	var main: Node2D

	func _draw() -> void:
		var pts: PackedVector2Array = main.PATH_POINTS
		# 草地
		draw_rect(Rect2(Vector2.ZERO, main.SCREEN), Color("7fae4e"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 110:
			var p := Vector2(rng.randf_range(0, main.SCREEN.x), rng.randf_range(0, main.SCREEN.y))
			if main.dist_to_path(p) < 60.0:
				continue
			draw_circle(p, rng.randf_range(6, 18), Color("74a244"))
		# 道路（先描边后内芯，拐角处补圆）
		draw_polyline(pts, Color("8b6b43"), 64.0)
		for p in pts:
			draw_circle(p, 32.0, Color("8b6b43"))
		draw_polyline(pts, Color("cbaa6e"), 54.0)
		for p in pts:
			draw_circle(p, 27.0, Color("cbaa6e"))
		# 建造点
		for s in main.BUILD_SPOTS:
			draw_set_transform(s, 0.0, Vector2.ONE * 0.9)
			draw_texture(main.TEX_SPOT, -main.TEX_SPOT.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 树木、灌木与石头装饰
		var deco_tex: Array = [main.TEX_TREE, main.TEX_BUSH, main.TEX_BUSH_SMALL, main.TEX_PLANT,
			main.TEX_ROCK1, main.TEX_ROCK2, main.TEX_ROCK3]
		rng.seed = 7
		for i in 80:
			var p := Vector2(rng.randf_range(20, main.SCREEN.x - 20), rng.randf_range(20, main.SCREEN.y - 20))
			if main.dist_to_path(p) < 85.0 or p.distance_to(main.CASTLE_POS) < 120.0:
				continue
			var near_spot := false
			for s in main.BUILD_SPOTS:
				if p.distance_to(s) < 70.0:
					near_spot = true
					break
			if near_spot:
				continue
			var tex: Texture2D = deco_tex[rng.randi_range(0, deco_tex.size() - 1)]
			draw_set_transform(p, 0.0, Vector2.ONE * rng.randf_range(0.6, 1.1))
			draw_texture(tex, -tex.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 出怪口
		var spawn_pos := Vector2(10, pts[0].y)
		draw_circle(spawn_pos, 34.0, Color("2e2e38"))
		draw_arc(spawn_pos, 34.0, 0.0, TAU, 32, Color("55555f"), 3.0)
		# 城堡
		var c: Vector2 = main.CASTLE_POS
		draw_rect(Rect2(c.x - 52, c.y - 70, 20, 85), Color("8a8a95"))
		draw_rect(Rect2(c.x + 32, c.y - 70, 20, 85), Color("8a8a95"))
		draw_rect(Rect2(c.x - 40, c.y - 55, 80, 70), Color("9a9aa5"))
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 54, c.y - 70), Vector2(c.x - 30, c.y - 70), Vector2(c.x - 42, c.y - 92)]), Color("b03a2e"))
		draw_colored_polygon(PackedVector2Array([Vector2(c.x + 30, c.y - 70), Vector2(c.x + 54, c.y - 70), Vector2(c.x + 42, c.y - 92)]), Color("b03a2e"))
		for k in 4:
			draw_rect(Rect2(c.x - 36 + k * 20, c.y - 63, 10, 10), Color("9a9aa5"))
		draw_rect(Rect2(c.x - 12, c.y - 20, 24, 35), Color("4a3320"))
		# 选中塔的射程预览
		if main.selected_spot >= 0 and main.towers.has(main.selected_spot):
			var t = main.towers[main.selected_spot]
			draw_circle(t.position, t.current_range, Color(1, 1, 1, 0.10))
			draw_arc(t.position, t.current_range, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.0)


func _ready() -> void:
	Engine.time_scale = 1.0  # 重开时重置倍速
	add_to_group("game")
	dot_texture = _make_dot_texture()
	gold = START_GOLD
	lives = START_LIVES
	smoke_test = OS.get_cmdline_user_args().has("--smoke")
	map_drawer = MapDrawer.new()
	map_drawer.main = self
	add_child(map_drawer)
	_build_ui()
	_setup_music()
	_update_hud()
	if smoke_test:
		# 顺带覆盖调试功能路径
		_cycle_speed()
		_debug_add_gold(100)
		_debug_add_lives(5)
		_debug_toggle_music()
		_toggle_debug_panel()
		_toggle_debug_panel()
		_debug_toggle_pause()
		_debug_toggle_pause()
		Engine.time_scale = 10.0
	if OS.get_cmdline_user_args().has("--shot"):
		gold = 500
		_build_tower(0, "archer")
		_build_tower(4, "mage")
		_build_tower(1, "cannon")
		_update_hud()
		start_wave()
		spawn_enemy("ogre")
		await get_tree().create_timer(0.8).timeout
		spawn_enemy("orc")
		await get_tree().create_timer(0.8).timeout
		spawn_enemy("wolf")
		# 慢速测试弹，便于截图确认弹道可见
		var first_enemy = get_tree().get_nodes_in_group("enemies")[0]
		for i in 3:
			var key: String = ["archer", "mage", "cannon"][i]
			var d: Dictionary = TOWER_TYPES[key]
			var tp = Projectile.new()
			tp.setup(Vector2(80, 300 + i * 40), first_enemy, 35.0, 0.0, 0.0, d["proj"], d["proj_size"])
			add_child(tp)
		await get_tree().create_timer(2.0).timeout
		# 手动触发特效，便于截图确认
		spawn_explosion(Vector2(330, 200))
		spawn_float_text(Vector2(330, 200), "+12 金", Color("f1c40f"))
		await get_tree().create_timer(0.18).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_shot.png")
		# 建造/升级菜单界面
		_open_menu(2)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_menu_build.png")
		_open_menu(0)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_menu_tower.png")


func _process(delta: float) -> void:
	if game_ended:
		return
	if wave_active:
		wave_time += delta
		while not spawn_events.is_empty() and spawn_events[0]["time"] <= wave_time:
			spawn_enemy(spawn_events[0]["type"])
			spawn_events.pop_front()
		if spawn_events.is_empty() and get_tree().get_nodes_in_group("enemies").is_empty():
			_end_wave()
	elif smoke_test:
		start_wave()


func _unhandled_input(event: InputEvent) -> void:
	if game_ended:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		var idx := _spot_at(pos)
		if idx >= 0:
			_open_menu(idx)
		else:
			_close_menu()


# ---------- 波次 ----------

func start_wave() -> void:
	if wave_active or game_ended or next_wave >= WAVES.size():
		return
	wave_active = true
	wave_time = 0.0
	spawn_events.clear()
	var t := 0.0
	for group in WAVES[next_wave]:
		t += group.get("delay", 0.0)
		for i in group["count"]:
			spawn_events.append({"time": t, "type": group["type"]})
			t += group["interval"]
	spawn_hp_scale = 1.0 + 0.07 * next_wave
	next_wave += 1
	if smoke_test:
		print("[smoke] wave %d started, gold=%d lives=%d" % [next_wave, gold, lives])
		_smoke_build()
	start_button.disabled = true
	start_button.text = "第 %d 波进攻中…" % next_wave
	hint_label.text = ""
	_update_hud()


func _smoke_build() -> void:
	var order := ["archer", "cannon", "mage"]
	var n := 0
	for i in BUILD_SPOTS.size():
		if towers.has(i):
			var t = towers[i]
			if t.level < 3 and i % 2 == 0 and gold >= t.upgrade_cost():
				gold -= t.upgrade_cost()
				t.apply_upgrade()
			continue
		var key: String = order[n % 3]
		if gold >= TOWER_TYPES[key]["cost"]:
			_build_tower(i, key)
			n += 1


func _end_wave() -> void:
	wave_active = false
	if next_wave >= WAVES.size():
		game_over(true)
		return
	var bonus := 15 + next_wave * 5
	gold += bonus
	start_button.disabled = false
	start_button.text = "开始第 %d 波" % (next_wave + 1)
	hint_label.text = "守住了！奖励 %d 金币" % bonus
	_update_hud()


func spawn_enemy(type_name: String) -> void:
	var e = Enemy.new()
	e.setup(type_name, PATH_POINTS, ENEMY_TYPES[type_name], spawn_hp_scale)
	e.died.connect(_on_enemy_died)
	e.reached_end.connect(_on_enemy_reached_end)
	add_child(e)


func _on_enemy_died(e) -> void:
	gold += e.reward
	spawn_particles(e.global_position, {"texture": FX_SMOKE2, "count": 10, "speed": 80.0,
		"size": 0.08, "gravity": 20.0, "lifetime": 0.8, "grow": 1.8,
		"turb_strength": 1.5, "rand_angle": true,
		"ramp": [[0.0, Color(0.45, 0.45, 0.45, 0.7)], [0.7, Color(0.55, 0.55, 0.55, 0.35)], [1.0, Color(0.6, 0.6, 0.6, 0.0)]]})
	spawn_float_text(e.global_position, "+%d 金" % e.reward, Color("f1c40f"))
	_update_hud()


func _on_enemy_reached_end(e) -> void:
	lives = maxi(0, lives - e.damage)
	_flash_red()
	_update_hud()
	if lives <= 0:
		game_over(false)


# ---------- 建造 / 升级 / 出售 ----------

func _spot_at(pos: Vector2) -> int:
	for i in BUILD_SPOTS.size():
		if BUILD_SPOTS[i].distance_to(pos) <= 30.0:
			return i
	return -1


func _open_menu(idx: int) -> void:
	_close_menu()
	selected_spot = idx
	map_drawer.queue_redraw()
	menu_panel = PanelContainer.new()
	var pstyle := _panel_style(Color(0.10, 0.11, 0.14, 0.92), Color(0.85, 0.65, 0.25, 0.9), 12)
	pstyle.content_margin_left = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_top = 8
	pstyle.content_margin_bottom = 8
	menu_panel.add_theme_stylebox_override("panel", pstyle)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	menu_panel.add_child(vbox)
	if towers.has(idx):
		var t: Node2D = towers[idx]
		var title := Label.new()
		title.text = "%s  Lv.%d" % [TOWER_TYPES[t.type]["name"], t.level]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		vbox.add_child(title)
		if t.level < 3:
			var up_btn := Button.new()
			up_btn.text = "升级（%d 金）" % t.upgrade_cost()
			up_btn.custom_minimum_size = Vector2(150, 36)
			up_btn.disabled = gold < t.upgrade_cost()
			_style_button(up_btn)
			up_btn.pressed.connect(_upgrade_tower.bind(idx))
			vbox.add_child(up_btn)
		else:
			var max_label := Label.new()
			max_label.text = "已满级"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
			vbox.add_child(max_label)
		var sell_btn := Button.new()
		sell_btn.text = "出售（+%d 金）" % t.sell_value()
		sell_btn.custom_minimum_size = Vector2(150, 36)
		_style_button(sell_btn)
		sell_btn.pressed.connect(_sell_tower.bind(idx))
		vbox.add_child(sell_btn)
	else:
		for key in TOWER_TYPES:
			var d: Dictionary = TOWER_TYPES[key]
			var btn := Button.new()
			btn.text = "%s  %d 金" % [d["name"], d["cost"]]
			btn.custom_minimum_size = Vector2(150, 36)
			btn.disabled = gold < d["cost"]
			_style_button(btn)
			btn.pressed.connect(_build_tower.bind(idx, key))
			vbox.add_child(btn)
	ui_root.add_child(menu_panel)
	# 菜单定位在建造点旁，并夹在屏幕内
	menu_panel.reset_size()
	var size := menu_panel.get_combined_minimum_size()
	var pos: Vector2 = BUILD_SPOTS[idx] + Vector2(30, -size.y / 2.0)
	pos.x = clampf(pos.x, 8.0, SCREEN.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, SCREEN.y - size.y - 8.0)
	menu_panel.position = pos
	menu_panel.size = size


func _close_menu() -> void:
	if menu_panel != null:
		menu_panel.queue_free()
		menu_panel = null
	selected_spot = -1
	map_drawer.queue_redraw()


func _build_tower(idx: int, key: String) -> void:
	var d: Dictionary = TOWER_TYPES[key]
	if gold < d["cost"]:
		return
	gold -= d["cost"]
	var t = Tower.new()
	t.setup(key, d)
	t.position = BUILD_SPOTS[idx]
	t.fired.connect(_on_tower_fired)
	add_child(t)
	towers[idx] = t
	# 尘土 + 弹出动画
	spawn_particles(t.position, {"texture": FX_SMOKE2, "color": Color("c8b08a"), "count": 12,
		"speed": 130.0, "size": 0.07, "gravity": 250.0, "lifetime": 0.6,
		"turb_strength": 1.0, "rand_angle": true})
	t.scale = Vector2.ZERO
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_close_menu()
	_update_hud()


func _upgrade_tower(idx: int) -> void:
	var t = towers.get(idx)
	if t == null or t.level >= 3 or gold < t.upgrade_cost():
		return
	gold -= t.upgrade_cost()
	t.apply_upgrade()
	spawn_particles(t.position, {"texture": FX_STAR, "color": Color("f7dc6f"), "count": 10,
		"speed": 130.0, "size": 0.06, "gravity": 40.0, "lifetime": 0.7, "add": true,
		"rand_angle": true, "spin": 120.0})
	_update_hud()
	_open_menu(idx)


func _sell_tower(idx: int) -> void:
	var t = towers.get(idx)
	if t == null:
		return
	gold += t.sell_value()
	t.queue_free()
	towers.erase(idx)
	_close_menu()
	_update_hud()


func _on_tower_fired(tower, target) -> void:
	if smoke_test:
		smoke_shots[tower.type] = smoke_shots.get(tower.type, 0) + 1
	# 炮口焰
	var dir: Vector2 = (target.global_position - tower.global_position).normalized()
	spawn_particles(tower.global_position + dir * 30.0, {"texture": FX_MUZZLE,
		"color": Color(1, 0.9, 0.6), "count": 1, "speed": 0.0, "size": 0.075,
		"lifetime": 0.12, "add": true, "gravity": 0.0, "angle_deg": rad_to_deg(dir.angle()) + 90.0})
	var p = Projectile.new()
	p.setup(tower.global_position, target, tower.proj_speed, tower.current_damage, tower.splash, tower.proj_tex, tower.proj_size, tower.hit_tex, tower.hit_size)
	add_child(p)


# ---------- 特效 ----------

var dot_texture: Texture2D


func _make_dot_texture() -> Texture2D:
	# 生成一张 smoothstep 径向渐变的柔光圆点，作为粒子贴图
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)  # smoothstep 边缘更柔
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## 通用一次性粒子。opts 支持：
##   color/color_end  两段渐变（color_end 缺省时尾部透明度淡出）
##   ramp             多段渐变 [[t, Color], ...]，优先级最高
##   count/speed/size/lifetime/gravity/damping
##   grow             尺寸曲线 0.5→n（膨胀，烟尘用）
##   shrink           尺寸曲线 1.0→n（收缩，火球用）
##   turb_strength/turb_scale  湍流扰动（烟雾飘动用）
##   shape="sphere"/shape_radius  球面发射（默认单点）
##   hue              色相抖动幅度
##   spin             角速度上限（碎屑翻滚用）
##   add              叠加发光混合
##   texture          自定义粒子贴图
func spawn_particles(pos: Vector2, opts: Dictionary) -> void:
	var p := GPUParticles2D.new()
	p.texture = opts.get("texture", dot_texture)
	p.amount = opts.get("count", 12)
	p.lifetime = opts.get("lifetime", 0.6)
	p.one_shot = true
	p.explosiveness = 1.0
	p.visibility_rect = Rect2(-400, -400, 800, 800)
	var mat := ParticleProcessMaterial.new()
	mat.spread = 180.0
	# 发射形状
	if opts.get("shape", "point") == "sphere":
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = opts.get("shape_radius", 10.0)
	# 运动
	var speed: float = opts.get("speed", 120.0)
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, opts.get("gravity", 250.0), 0)
	var damping: float = opts.get("damping", 0.0)
	mat.damping_min = damping * 0.7
	mat.damping_max = damping
	if opts.get("spin", 0.0) > 0.0:
		mat.angular_velocity_min = -opts["spin"]
		mat.angular_velocity_max = opts["spin"]
	# 湍流
	if opts.has("turb_strength"):
		mat.turbulence_enabled = true
		mat.turbulence_noise_strength = opts["turb_strength"]
		mat.turbulence_noise_scale = opts.get("turb_scale", 1.5)
	# 尺寸
	var size: float = opts.get("size", 1.5)
	mat.scale_min = size * 0.7
	mat.scale_max = size
	# 随机初始角度（火焰/烟雾方向随机化）
	if opts.get("rand_angle", false):
		mat.angle_min = -180.0
		mat.angle_max = 180.0
	# 固定初始角度（炮口焰朝向用）
	if opts.has("angle_deg"):
		mat.angle_min = opts["angle_deg"]
		mat.angle_max = opts["angle_deg"]
	if opts.has("grow") or opts.has("shrink"):
		var curve := Curve.new()
		if opts.has("grow"):
			curve.add_point(Vector2(0, 0.5))
			curve.add_point(Vector2(1, opts["grow"]))
		else:
			curve.add_point(Vector2(0, 1.0))
			curve.add_point(Vector2(1, opts["shrink"]))
		var ct := CurveTexture.new()
		ct.curve = curve
		mat.scale_curve = ct
	# 颜色渐变
	var grad := Gradient.new()
	if opts.has("ramp"):
		var ramp: Array = opts["ramp"]
		grad.set_color(0, ramp[0][1])
		grad.remove_point(1)
		for i in range(1, ramp.size()):
			grad.add_point(ramp[i][0], ramp[i][1])
	else:
		var c: Color = opts.get("color", Color.WHITE)
		grad.set_color(0, c)
		if opts.has("color_end"):
			grad.set_color(1, opts["color_end"])
		else:
			grad.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	# 色相抖动
	if opts.get("hue", 0.0) > 0.0:
		mat.hue_variation_min = -opts["hue"]
		mat.hue_variation_max = opts["hue"]
	p.process_material = mat
	if opts.get("add", false):
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = cm
	p.position = pos
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func spawn_explosion(pos: Vector2) -> void:
	# 冲击波环
	var ring := ShockRing.new()
	ring.position = pos
	add_child(ring)
	# 闪光核心（枪口焰贴图，叠加发光，短促膨胀）
	spawn_particles(pos, {"texture": FX_MUZZLE, "color": Color(1, 0.95, 0.75), "count": 5,
		"speed": 40.0, "size": 0.12, "gravity": 0.0, "lifetime": 0.22, "add": true,
		"grow": 1.8, "shape": "sphere", "shape_radius": 8.0, "rand_angle": true})
	# 火球（火焰舌贴图，叠加发光）：白→黄→橙→暗红透明，整体收缩
	spawn_particles(pos, {"texture": FX_FLAME, "count": 18, "speed": 210.0, "size": 0.13,
		"gravity": 30.0, "damping": 180.0, "lifetime": 0.55, "shrink": 0.3, "add": true,
		"shape": "sphere", "shape_radius": 16.0, "hue": 0.03, "rand_angle": true,
		"ramp": [[0.0, Color(1, 1, 0.9)], [0.2, Color(1, 0.85, 0.3)],
			[0.55, Color(0.95, 0.45, 0.1)], [1.0, Color(0.4, 0.08, 0.02, 0.0)]]})
	# 火星（柔光点发光、受重力下落）
	spawn_particles(pos, {"texture": FX_DOT, "count": 14, "speed": 380.0, "size": 0.028,
		"gravity": 600.0, "lifetime": 0.8, "add": true,
		"ramp": [[0.0, Color(1, 0.95, 0.6)], [0.4, Color(1, 0.75, 0.25)], [1.0, Color(1, 0.4, 0.1, 0.0)]]})
	# 烟尘（烟雾贴图）：湍流扰动、慢速上升、膨胀、淡出
	spawn_particles(pos, {"texture": FX_SMOKE, "count": 7, "speed": 50.0, "size": 0.11,
		"gravity": -45.0, "lifetime": 1.1, "grow": 2.2, "turb_strength": 2.0, "turb_scale": 1.5,
		"shape": "sphere", "shape_radius": 12.0, "rand_angle": true, "spin": 60.0,
		"ramp": [[0.0, Color(0.3, 0.3, 0.3, 0.55)], [0.7, Color(0.4, 0.4, 0.4, 0.3)], [1.0, Color(0.5, 0.5, 0.5, 0.0)]]})


class ShockRing extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta / 0.35
		if t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var r := lerpf(12.0, 95.0, t)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.5, (1.0 - t) * 0.7), 3.0 * (1.0 - t) + 1.0)


func spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.position = pos + Vector2(-15, -30)
	ui_root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 36.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


func _flash_red() -> void:
	var r := ColorRect.new()
	r.color = Color(0.9, 0.1, 0.1, 0.22)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.5)
	tw.tween_callback(r.queue_free)


# ---------- 工具 ----------

func _setup_music() -> void:
	var stream = load("res://assets/audio/the_builder.mp3")
	if stream == null:
		return
	stream.loop = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = -8.0
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	music_player.play()


func dist_to_path(p: Vector2) -> float:
	var best := INF
	for i in PATH_POINTS.size() - 1:
		var cp := Geometry2D.get_closest_point_to_segment(p, PATH_POINTS[i], PATH_POINTS[i + 1])
		best = minf(best, p.distance_to(cp))
	return best


# ---------- UI ----------

func _panel_style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _style_button(btn: Button, accent := false) -> void:
	var normal := _panel_style(Color(0.13, 0.14, 0.18, 0.95), Color(0.85, 0.65, 0.25, 0.9), 10)
	var hover := _panel_style(Color(0.22, 0.23, 0.28, 0.97), Color(1.0, 0.8, 0.35, 0.95), 10)
	var pressed := _panel_style(Color(0.08, 0.09, 0.11, 0.97), Color(0.6, 0.45, 0.18, 0.9), 10)
	var disabled := _panel_style(Color(0.12, 0.12, 0.14, 0.55), Color(0.4, 0.4, 0.4, 0.5), 10)
	if accent:
		normal = _panel_style(Color(0.72, 0.52, 0.12, 0.97), Color(1.0, 0.85, 0.4, 0.95), 10)
		hover = _panel_style(Color(0.84, 0.63, 0.18, 1.0), Color(1.0, 0.9, 0.5, 1.0), 10)
		pressed = _panel_style(Color(0.58, 0.41, 0.08, 1.0), Color(0.9, 0.7, 0.3, 0.95), 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.15, 0.11, 0.05) if accent else Color(0.95, 0.93, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.02) if accent else Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.15, 0.11, 0.05) if accent else Color(0.9, 0.88, 0.8))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(ui_root)
	# 系统中文字体，避免默认字体缺字
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	ui_root.theme = theme

	# 徽章式状态栏：金币 / 生命 / 波次
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 12)
	bar.add_theme_constant_override("separation", 12)
	ui_root.add_child(bar)
	var gold_b := _make_badge(load("res://assets/ui/coins.png"), Color(1.0, 0.78, 0.2))
	var lives_b := _make_badge(load("res://assets/ui/crowned-heart.png"), Color(0.95, 0.3, 0.3))
	var wave_b := _make_badge(load("res://assets/ui/crossed-swords.png"), Color(0.75, 0.8, 0.9))
	bar.add_child(gold_b["panel"])
	bar.add_child(lives_b["panel"])
	bar.add_child(wave_b["panel"])
	gold_badge = gold_b["panel"]
	lives_badge = lives_b["panel"]
	wave_badge = wave_b["panel"]
	gold_label = gold_b["label"]
	lives_label = lives_b["label"]
	wave_label = wave_b["label"]

	start_button = Button.new()
	start_button.text = "开始第 1 波"
	start_button.custom_minimum_size = Vector2(220, 52)
	start_button.position = Vector2((SCREEN.x - 220) / 2.0, SCREEN.y - 64)
	start_button.icon = load("res://assets/ui/crossed-swords.png")
	start_button.expand_icon = true
	start_button.add_theme_constant_override("icon_max_width", 26)
	start_button.add_theme_font_size_override("font_size", 20)
	_style_button(start_button, true)
	start_button.pressed.connect(start_wave)
	ui_root.add_child(start_button)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, 54)
	hint_label.size = Vector2(SCREEN.x, 24)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hint_label.add_theme_constant_override("shadow_offset_x", 1)
	hint_label.add_theme_constant_override("shadow_offset_y", 1)
	ui_root.add_child(hint_label)

	# 倍速切换
	speed_button = Button.new()
	speed_button.text = "x1 倍速"
	speed_button.custom_minimum_size = Vector2(150, 52)
	speed_button.position = Vector2((SCREEN.x - 220) / 2.0 + 240, SCREEN.y - 64)
	speed_button.icon = load("res://assets/ui/fast-forward.png")
	speed_button.expand_icon = true
	speed_button.add_theme_constant_override("icon_max_width", 24)
	speed_button.add_theme_font_size_override("font_size", 18)
	_style_button(speed_button)
	speed_button.pressed.connect(_cycle_speed)
	ui_root.add_child(speed_button)

	# 测试面板开关
	var debug_toggle := Button.new()
	debug_toggle.text = "测试"
	debug_toggle.custom_minimum_size = Vector2(130, 48)
	debug_toggle.position = Vector2(SCREEN.x - 142, 12)
	debug_toggle.icon = load("res://assets/ui/settings-knobs.png")
	debug_toggle.expand_icon = true
	debug_toggle.add_theme_constant_override("icon_max_width", 24)
	debug_toggle.add_theme_font_size_override("font_size", 18)
	_style_button(debug_toggle)
	debug_toggle.pressed.connect(_toggle_debug_panel)
	ui_root.add_child(debug_toggle)


func _make_badge(icon_tex: Texture2D, icon_color: Color) -> Dictionary:
	var panel := PanelContainer.new()
	var style := _panel_style(Color(0.10, 0.11, 0.14, 0.88), Color(0.85, 0.65, 0.25, 0.9), 12)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.modulate = icon_color
	hbox.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	hbox.add_child(label)
	return {"panel": panel, "label": label}


func _punch_badge(panel: Control) -> void:
	# 数值变化时缩放弹跳一下
	panel.pivot_offset = panel.size / 2.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18)


func _cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % SPEEDS.size()
	Engine.time_scale = SPEEDS[speed_idx]
	speed_button.text = "x%d 倍速" % int(SPEEDS[speed_idx])


func _toggle_debug_panel() -> void:
	if debug_panel != null:
		debug_panel.queue_free()
		debug_panel = null
		return
	debug_panel = PanelContainer.new()
	debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var pstyle := _panel_style(Color(0.10, 0.11, 0.14, 0.92), Color(0.85, 0.65, 0.25, 0.9), 12)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	debug_panel.add_theme_stylebox_override("panel", pstyle)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_panel.add_child(vbox)
	var title := Label.new()
	title.text = "测试面板"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	vbox.add_child(title)
	for entry in [
		["金币 +100", _debug_add_gold.bind(100)],
		["金币 +1000", _debug_add_gold.bind(1000)],
		["生命 +5", _debug_add_lives.bind(5)],
		["清空场上敌人", _debug_clear_enemies],
	]:
		var btn := Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(160, 36)
		_style_button(btn)
		btn.pressed.connect(entry[1])
		vbox.add_child(btn)
	var pause_btn := Button.new()
	pause_btn.text = "继续" if get_tree().paused else "暂停"
	pause_btn.custom_minimum_size = Vector2(160, 36)
	_style_button(pause_btn)
	pause_btn.pressed.connect(_debug_toggle_pause.bind(pause_btn))
	vbox.add_child(pause_btn)
	var music_btn := Button.new()
	music_btn.text = "音乐 开/关"
	music_btn.custom_minimum_size = Vector2(160, 36)
	_style_button(music_btn)
	music_btn.pressed.connect(_debug_toggle_music)
	vbox.add_child(music_btn)
	ui_root.add_child(debug_panel)
	debug_panel.reset_size()
	debug_panel.position = Vector2(SCREEN.x - debug_panel.get_combined_minimum_size().x - 12, 70)
	debug_panel.size = debug_panel.get_combined_minimum_size()


func _debug_toggle_pause(btn: Button = null) -> void:
	get_tree().paused = not get_tree().paused
	if btn != null:
		btn.text = "继续" if get_tree().paused else "暂停"


func _debug_add_gold(amount: int) -> void:
	gold += amount
	_update_hud()


func _debug_add_lives(amount: int) -> void:
	lives += amount
	_update_hud()


func _debug_clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(999999.0)


func _debug_toggle_music() -> void:
	if music_player != null:
		music_player.stream_paused = not music_player.stream_paused


func _update_hud() -> void:
	if gold != last_gold:
		gold_label.text = str(gold)
		if last_gold >= 0:
			_punch_badge(gold_badge)
		last_gold = gold
	if lives != last_lives:
		lives_label.text = str(lives)
		lives_label.add_theme_color_override("font_color",
			Color("ff6b6b") if lives <= 5 else Color(0.95, 0.93, 0.85))
		if last_lives >= 0:
			_punch_badge(lives_badge)
		last_lives = lives
	if next_wave != last_wave:
		wave_label.text = "%d/%d" % [next_wave, WAVES.size()]
		if last_wave >= 0:
			_punch_badge(wave_badge)
		last_wave = next_wave


func game_over(win: bool) -> void:
	game_ended = true
	if smoke_test:
		print("[smoke] game over win=%s gold=%d lives=%d towers=%d shots=%s" % [win, gold, lives, towers.size(), str(smoke_shots)])
	_close_menu()
	get_tree().paused = true
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var pstyle := _panel_style(Color(0.10, 0.11, 0.14, 0.95), Color(0.85, 0.65, 0.25, 0.95), 16)
	pstyle.content_margin_left = 36
	pstyle.content_margin_right = 36
	pstyle.content_margin_top = 28
	pstyle.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", pstyle)
	ui_root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	if win:
		title.text = "胜利！王国守住了！"
		title.add_theme_color_override("font_color", Color("2ecc71"))
	else:
		title.text = "城堡陷落了…"
		title.add_theme_color_override("font_color", Color("ff6b6b"))
	vbox.add_child(title)
	var restart := Button.new()
	restart.text = "重新开始"
	restart.custom_minimum_size = Vector2(200, 52)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override("font_size", 20)
	_style_button(restart, true)
	restart.pressed.connect(_on_restart)
	vbox.add_child(restart)
	panel.reset_size()
	panel.position = (SCREEN - panel.get_combined_minimum_size()) / 2.0
	panel.size = panel.get_combined_minimum_size()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
