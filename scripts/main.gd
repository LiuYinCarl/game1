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

# 当前关卡状态（由 _load_level 填充）
var level_index := 0
var level_name := ""
var path_points := PackedVector2Array()  # 主路径（paths[0]）
var paths: Array = []  # 全部路径（1-3 条，可共享尾段）
var build_spots: Array = []
var castle_pos := Vector2.ZERO
var waves: Array = []
var hp_growth := 0.07
var start_gold := 230
var start_lives := 20



var gold: int
var lives: int
var next_wave := 0  # 已开始的波次数
var wave_active := false
var game_ended := false
var spawn_events: Array = []
var spawn_hp_scale := 1.0
var wave_time := 0.0
const WAVE_COOLDOWN := 20.0
var wave_cooldown := -1.0  # >=0 表示自动开波倒计时中
var wave_timer_bar: ProgressBar
var towers := {}  # spot_index -> Tower
var selected_spot := -1
var smoke_test := false
var smoke_shots := {}

var map_drawer: Node2D
var camera: Camera2D
var shake_amp := 0.0
var hovered_spot := -1
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
var menu_buttons: Array = []  # [[Button, 所需金币]]，金币变化时刷新可用状态
var selected_enemy: Node2D = null
var enemy_hp_label: Label
var enemy_info_labels: Array = []
var rally_pick_tower: Node2D = null  # 非 null 表示正在拾取兵营集合点
var speed_button: Button
var debug_panel: PanelContainer
var music_player: AudioStreamPlayer
var sfx_pool: Array = []
var sfx_streams := {}
var sfx_idx := 0

const SPEEDS := [1.0, 2.0, 3.0]
var speed_idx := 0


class MapDrawer extends Node2D:
	var main: Node2D

	func _draw() -> void:
		_draw_ground()
		_draw_road()
		_draw_spots()
		_draw_deco()
		_draw_portal()
		_draw_castle()
		_draw_overlays()

	func _draw_ground() -> void:
		var rng := RandomNumberGenerator.new()
		# 草地底色 + 大块明暗斑驳（错落的草地色块，避免纯色平涂感）
		draw_rect(Rect2(Vector2.ZERO, main.SCREEN), Color("77a549"))
		rng.seed = 11
		for i in 60:
			var p := Vector2(rng.randf_range(0, main.SCREEN.x), rng.randf_range(0, main.SCREEN.y))
			var r := rng.randf_range(60, 170)
			var c: Color = Color("7fae4e") if rng.randf() < 0.5 else Color("6f9f41")
			draw_circle(p, r, Color(c.r, c.g, c.b, 0.30))
		# 草地细碎纹理与草叶
		rng.seed = 42
		var detail: Array = [Color("74a244"), Color("82b355"), Color("699a3c"), Color("8cba5e")]
		for i in 340:
			var p := Vector2(rng.randf_range(0, main.SCREEN.x), rng.randf_range(0, main.SCREEN.y))
			if main.dist_to_path(p) < 62.0:
				continue
			var c: Color = detail[rng.randi_range(0, detail.size() - 1)]
			if rng.randf() < 0.3:
				# 小草叶：两笔短线
				var h := rng.randf_range(3.0, 6.0)
				var lean := rng.randf_range(-2.0, 2.0)
				draw_line(p, p + Vector2(lean, -h), Color(c.r, c.g, c.b, 0.55), 1.4)
				draw_line(p + Vector2(3, 1), p + Vector2(3 + lean, -h * 0.8), Color(c.r, c.g, c.b, 0.45), 1.2)
			else:
				draw_circle(p, rng.randf_range(2, 8), Color(c.r, c.g, c.b, 0.5))

	func _draw_road() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		# 每条路径都绘制道路（共享尾段会自然重叠融合）
		for pts: PackedVector2Array in main.paths:
			# 路面投影（往下一线，制造浮起感）
			var shadow := PackedVector2Array()
			for p in pts:
				shadow.append(p + Vector2(0, 10))
			draw_polyline(shadow, Color(0, 0, 0, 0.16), 64.0)
			for p in shadow:
				draw_circle(p, 32.0, Color(0, 0, 0, 0.16))
			# 路肩（深）→ 路面 → 中央磨损带（亮）
			draw_polyline(pts, Color("8a6a42"), 66.0)
			for p in pts:
				draw_circle(p, 33.0, Color("8a6a42"))
			draw_polyline(pts, Color("c8a76c"), 56.0)
			for p in pts:
				draw_circle(p, 28.0, Color("c8a76c"))
			draw_polyline(pts, Color("d6b87e"), 30.0)
			for p in pts:
				draw_circle(p, 15.0, Color("d6b87e"))
		# 碎石与车辙点缀（散布于所有路径）
		for pts: PackedVector2Array in main.paths:
			for i in 110:
				var si := rng.randi_range(0, pts.size() - 2)
				var p: Vector2 = pts[si].lerp(pts[si + 1], rng.randf())
				var n := (pts[si + 1] - pts[si]).normalized().orthogonal()
				p += n * rng.randf_range(-21.0, 21.0)
				if rng.randf() < 0.7:
					draw_circle(p, rng.randf_range(1.5, 3.5), Color(0.45, 0.34, 0.2, rng.randf_range(0.25, 0.5)))
				else:
					draw_circle(p, rng.randf_range(2.0, 4.0), Color(0.9, 0.8, 0.6, rng.randf_range(0.2, 0.4)))

	func _draw_spots() -> void:
		for i in main.build_spots.size():
			var s: Vector2 = main.build_spots[i]
			# 石板投影
			draw_set_transform(s + Vector2(0, 5), 0.0, Vector2(0.95, 0.5))
			draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.22))
			draw_set_transform(s, 0.0, Vector2.ONE * 0.9)
			draw_texture(main.TEX_SPOT, -main.TEX_SPOT.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# 悬停/选中高亮
			if i == main.hovered_spot or i == main.selected_spot:
				var sel: bool = i == main.selected_spot
				var col := Color(1.0, 0.85, 0.4, 0.95) if sel else Color(1, 1, 1, 0.65)
				draw_circle(s, 36.0, Color(1, 1, 0.85, 0.10 if sel else 0.06))
				draw_arc(s, 34.0, 0.0, TAU, 40, col, 2.5 if sel else 1.8)

	func _draw_deco() -> void:
		var deco_tex: Array = [main.TEX_TREE, main.TEX_BUSH, main.TEX_BUSH_SMALL, main.TEX_PLANT,
			main.TEX_ROCK1, main.TEX_ROCK2, main.TEX_ROCK3]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 80:
			var p := Vector2(rng.randf_range(20, main.SCREEN.x - 20), rng.randf_range(20, main.SCREEN.y - 20))
			if main.dist_to_path(p) < 85.0 or p.distance_to(main.castle_pos) < 120.0:
				continue
			var near_spot := false
			for s in main.build_spots:
				if p.distance_to(s) < 70.0:
					near_spot = true
					break
			if near_spot:
				continue
			var tex: Texture2D = deco_tex[rng.randi_range(0, deco_tex.size() - 1)]
			var sc := rng.randf_range(0.6, 1.1)
			# 落地投影
			draw_set_transform(p + Vector2(3, 7 * sc), 0.0, Vector2(sc, sc * 0.4))
			draw_circle(Vector2.ZERO, tex.get_size().x * 0.32, Color(0, 0, 0, 0.2))
			draw_set_transform(p, 0.0, Vector2.ONE * sc)
			draw_texture(tex, -tex.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_portal() -> void:
		# 每条路径一个出怪传送门，位于路径起点
		for pts: PackedVector2Array in main.paths:
			var sp := pts[0]
			# 洞口晕圈与深渊
			draw_circle(sp, 54.0, Color(0.08, 0.06, 0.1, 0.25))
			draw_circle(sp, 40.0, Color("241f2e"))
			draw_circle(sp, 29.0, Color("151220"))
			# 环绕的岩石圈
			for k in 10:
				var a := TAU * k / 10.0
				var rp := sp + Vector2(cos(a), sin(a)) * 37.0
				draw_circle(rp + Vector2(0, 3), 7.5, Color(0, 0, 0, 0.25))
				draw_circle(rp, 7.0, Color("4a4550"))
				draw_circle(rp + Vector2(0, -2), 4.5, Color("5f5a6a"))
			# 内圈幽光
			draw_arc(sp, 24.0, 0.0, TAU, 32, Color(0.5, 0.35, 0.7, 0.4), 2.0)

	func _draw_castle() -> void:
		var c: Vector2 = main.castle_pos
		var stone := Color("b5ae9f")
		var stone_dark := Color("9a9284")
		var stone_edge := Color("6e675c")
		var seam := Color(stone_edge.r, stone_edge.g, stone_edge.b, 0.35)
		# 地面阴影
		draw_set_transform(c + Vector2(0, 32), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 82.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 两侧后塔（先画，位于墙体后面）
		for sx in [-1.0, 1.0]:
			var tx: float = c.x + sx * 54.0
			draw_rect(Rect2(tx - 16, c.y - 96, 32, 112), stone_dark)
			for k in 3:
				draw_rect(Rect2(tx - 16 + k * 12, c.y - 108, 8, 14), stone_dark)
			draw_rect(Rect2(tx - 16, c.y - 96, 32, 3), Color(stone_edge.r, stone_edge.g, stone_edge.b, 0.5))
		# 主墙体 + 砖缝
		draw_rect(Rect2(c.x - 46, c.y - 62, 92, 80), stone)
		for row in 6:
			var yy := c.y - 56 + row * 12
			draw_rect(Rect2(c.x - 46, yy, 92, 1.5), seam)
			var off := 0.0 if row % 2 == 0 else 11.0
			for kx in 5:
				draw_rect(Rect2(c.x - 46 + off + kx * 22, yy, 1.5, 12), seam)
		# 墙顶雉堞
		for k in 5:
			draw_rect(Rect2(c.x - 46 + k * 20, c.y - 72, 12, 12), stone)
			draw_rect(Rect2(c.x - 46 + k * 20, c.y - 72, 12, 3), Color(0.95, 0.93, 0.88, 0.5))
		draw_rect(Rect2(c.x - 46, c.y - 62, 92, 3), stone_edge)
		# 城门（拱形木门 + 门框）
		draw_circle(Vector2(c.x, c.y - 22), 15.0, Color("3c2a18"))
		draw_rect(Rect2(c.x - 15, c.y - 22, 30, 40), Color("3c2a18"))
		draw_circle(Vector2(c.x, c.y - 22), 12.5, Color("5a4026"))
		draw_rect(Rect2(c.x - 12.5, c.y - 22, 25, 37), Color("5a4026"))
		for k in 3:
			draw_line(Vector2(c.x - 12 + k * 9, c.y - 20), Vector2(c.x - 12 + k * 9, c.y + 16), Color("3c2a18"), 1.5)
		# 旗帜
		for sx in [-1.0, 1.0]:
			var fx: float = c.x + sx * 54.0
			draw_line(Vector2(fx, c.y - 106), Vector2(fx, c.y - 132), Color("5c4a33"), 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(fx, c.y - 132), Vector2(fx + sx * 20.0, c.y - 125), Vector2(fx, c.y - 118)]), Color("b03a2e"))
			draw_circle(Vector2(fx, c.y - 133), 2.5, Color("f1c40f"))

	func _draw_overlays() -> void:
		# 选中塔的射程预览
		if main.selected_spot >= 0 and main.towers.has(main.selected_spot):
			var t = main.towers[main.selected_spot]
			draw_circle(t.position, t.current_range, Color(1, 1, 1, 0.08))
			draw_arc(t.position, t.current_range, 0.0, TAU, 96, Color(1, 1, 1, 0.55), 2.0)
			draw_arc(t.position, t.current_range - 6.0, 0.0, TAU, 96, Color(1, 1, 1, 0.18), 1.5)
		# 兵营集合点旗帜（选中兵营或拾取集合点时显示）
		var rally_tower: Node2D = null
		if main.rally_pick_tower != null and is_instance_valid(main.rally_pick_tower):
			rally_tower = main.rally_pick_tower
		elif main.selected_spot >= 0 and main.towers.has(main.selected_spot) \
				and main.towers[main.selected_spot].type == "barracks":
			rally_tower = main.towers[main.selected_spot]
		if rally_tower != null:
			var rp: Vector2 = rally_tower.rally_point
			draw_line(rally_tower.position, rp, Color(0.5, 0.75, 1.0, 0.45), 2.0)
			draw_arc(rp, 85.0, 0.0, TAU, 48, Color(0.55, 0.75, 1.0, 0.3), 1.5)
			draw_circle(rp, 10.0, Color(0.4, 0.65, 1.0, 0.22))
			draw_arc(rp, 12.0, 0.0, TAU, 24, Color(0.6, 0.8, 1.0, 0.9), 2.0)
			draw_line(rp + Vector2(0, 2), rp + Vector2(0, -16), Color("c8d8e8"), 2.0)
			draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -16), rp + Vector2(12, -12), rp + Vector2(0, -8)]), Color("4a80d0"))


func _ready() -> void:
	Engine.time_scale = 1.0  # 重开时重置倍速
	add_to_group("game")
	dot_texture = _make_dot_texture()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			GameState.current_level = int(arg.get_slice("=", 1))
	_load_level(GameState.current_level)
	gold = start_gold
	lives = start_lives
	smoke_test = OS.get_cmdline_user_args().has("--smoke")
	map_drawer = MapDrawer.new()
	map_drawer.main = self
	add_child(map_drawer)
	# 边缘暗角：独立全屏层（轻微压暗四角，聚焦画面中心），位于地图之上、UI 之下
	var vshader := Shader.new()
	vshader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	uv.x *= 1.78;
	float v = smoothstep(0.42, 0.95, length(uv) * 1.25);
	COLOR = vec4(0.03, 0.06, 0.02, v * 0.38);
}
"""
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 5
	add_child(vignette_layer)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	vmat.shader = vshader
	vignette.material = vmat
	vignette_layer.add_child(vignette)
	# 相机：用于受击/爆炸时的屏幕震动
	camera = Camera2D.new()
	camera.position = SCREEN / 2.0
	add_child(camera)
	camera.make_current()
	_build_ui()
	_setup_music()
	_setup_sfx()
	_update_hud()
	hint_label.text = "第 %d 关 · %s　|　%s" % [level_index + 1, level_name, _wave_preview_text()]
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
	# 战力曲线图：--chart=N 输出第 N 关的敌我强度曲线到 /tmp/tafang_chart_LN.png
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chart="):
			_load_level(clampi(int(arg.get_slice("=", 1)) - 1, 0, LevelData.LEVELS.size() - 1))
			var chart_layer := CanvasLayer.new()
			chart_layer.layer = 20
			add_child(chart_layer)
			var chart := ChartDrawer.new()
			chart.series = _build_chart_data()
			chart.title = "L%d %s 难度曲线" % [level_index + 1, level_name]
			chart_layer.add_child(chart)
			_do_chart_capture()
			return
	# 自动化测试：--test 运行测试套件并以退出码报告结果
	if OS.get_cmdline_user_args().has("--test"):
		var failures: int = load("res://tests/test_suite.gd").new().run(self)
		print("[TEST] ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
		get_tree().quit(0 if failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--shot"):
		gold = 999
		_build_tower(0, "archer")
		_build_tower(4, "mage")
		_build_tower(1, "cannon")
		_build_tower(2, "barracks")
		for i in 2:
			_upgrade_tower(0)
			_upgrade_tower(4)
			_upgrade_tower(1)
			_upgrade_tower(2)
		_close_menu()
		_update_hud()
		# 在兵营集合点旁放一个重甲武士，让士兵当场接敌（物理抗性耐久，方便截图）
		var bt = towers[2]
		var blocker: Node2D = null
		if not OS.get_cmdline_user_args().has("--no-blocker"):
			blocker = Enemy.new()
			blocker.setup("knight", path_points, LevelData.ENEMY_TYPES["knight"], 1.0)
			var target_p: Vector2 = bt.rally_point + Vector2(30, 0)
			var best_d := INF
			for i in path_points.size() - 1:
				var cp := Geometry2D.get_closest_point_to_segment(target_p, path_points[i], path_points[i + 1])
				var d := cp.distance_to(target_p)
				if d < best_d:
					best_d = d
					blocker.seg = i
					blocker.seg_progress = path_points[i].distance_to(cp)
			add_child(blocker)
			blocker.position = target_p
		start_wave()
		spawn_enemy("ogre")
		await get_tree().create_timer(0.8).timeout
		spawn_enemy("orc")
		await get_tree().create_timer(0.8).timeout
		spawn_enemy("saucer")
		# 慢速测试弹，便于截图确认弹道可见
		var first_enemy = get_tree().get_nodes_in_group("enemies")[0]
		for i in 3:
			var key: String = ["archer", "mage", "cannon"][i]
			var d: Dictionary = LevelData.TOWER_TYPES[key]
			var tp = Projectile.new()
			tp.setup(Vector2(80, 300 + i * 40), first_enemy, 35.0, 0.0, 0.0, d["projs"][0], d["proj_size"])
			add_child(tp)
		await get_tree().create_timer(2.0).timeout
		# 手动触发特效，便于截图确认
		spawn_explosion(Vector2(330, 200))
		spawn_float_text(Vector2(330, 200), "+12 金", Color("f1c40f"))
		await get_tree().create_timer(0.18).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_shot.png")
		# 敌人属性面板（抗性展示）
		if is_instance_valid(blocker):
			_open_enemy_menu(blocker)
			await get_tree().create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/tafang_enemy_info.png")
		# 建造/升级菜单界面
		_open_menu(2)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_menu_build.png")
		_open_menu(0)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_menu_tower.png")
		# 自动开波倒计时进度条
		_end_wave()
		await get_tree().create_timer(7.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_cooldown.png")


func _load_level(idx: int) -> void:
	level_index = clampi(idx, 0, LevelData.LEVELS.size() - 1)
	var L: Dictionary = LevelData.LEVELS[level_index]
	level_name = L["name"]
	paths = []
	for p in L["paths"]:
		paths.append(PackedVector2Array(p))
	path_points = paths[0]
	build_spots = _generate_spots(paths, int(L.get("seed", idx + 1)))
	start_gold = L["gold"]
	start_lives = L["lives"]
	hp_growth = L["hp_growth"]
	waves = _compose_waves(int(L["gen"][0]), L["gen"][1], paths.size())
	# 城堡位置按主路径末端方向自动推算
	var last: Vector2 = path_points[path_points.size() - 1]
	var prev: Vector2 = path_points[path_points.size() - 2]
	var dir := (last - prev).normalized()
	castle_pos = last - dir * 120.0
	castle_pos.x = clampf(castle_pos.x, 80.0, SCREEN.x - 80.0)
	castle_pos.y = clampf(castle_pos.y, 100.0, SCREEN.y - 60.0)


## 沿各路径自动生成建造点：长路段按间距布点，垂直偏移交替两侧，
## 过滤出界/过近（<85px）的点，保证全部建造点合法可达
func _generate_spots(path_list: Array, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var spots := []
	for pts in path_list:
		for si in range(pts.size() - 1):
			var a: Vector2 = pts[si]
			var b: Vector2 = pts[si + 1]
			var seg_len := a.distance_to(b)
			if seg_len < 200.0:
				continue
			var n := int(seg_len / 300.0) + 1
			var dir := (b - a).normalized()
			for k in range(n):
				var t := (k + 0.5) / n
				var base := a.lerp(b, t)
				var side := 1.0 if (si + k) % 2 == 0 else -1.0
				var off := rng.randf_range(105.0, 140.0) * side
				var spot := Vector2.ZERO
				var ok := false
				# 距离钳制到 50-170px：太远拉近、太近（压到其他路径）推远
				for attempt in range(5):
					spot = base + Vector2(-dir.y, dir.x) * off
					if spot.x < 60.0 or spot.x > SCREEN.x - 60.0 or spot.y < 60.0 or spot.y > SCREEN.y - 60.0:
						break
					var d := dist_to_path(spot)
					if d >= 50.0 and d <= 170.0:
						ok = true
						break
					if d < 50.0:
						off += (50.0 - d) + 6.0
					else:
						off -= (d - 170.0) + 6.0
				if not ok:
					continue
				if spot.x < 60.0 or spot.x > SCREEN.x - 60.0 or spot.y < 60.0 or spot.y > SCREEN.y - 60.0:
					continue
				var too_close := false
				for s in spots:
					if s.distance_to(spot) < 85.0:
						too_close = true
						break
				if not too_close:
					spots.append(spot)
	return spots


func _compose_waves(count: int, budget0: float, n_paths := 1) -> Array:
	# 参数化波次生成：预算随波次指数增长；敌人类型按波次逐步解锁，
	# share 为该类型在当波预算中的占比，boss 只出现在最后两波
	var schedule := [
		["grunt", 0, 0.30, 7.0, 20],
		["sapper", 1, 0.14, 6.0, 14],
		["saucer", 2, 0.10, 8.0, 10],
		["orc", 2, 0.26, 20.0, 10],
		["shaman", 3, 0.20, 24.0, 8],
		["recon", 4, 0.10, 9.0, 10],
		["knight", 4, 0.22, 30.0, 7],
		["phantom", 5, 0.14, 26.0, 8],
		["raider", 5, 0.18, 30.0, 6],
		["bomber", 6, 0.14, 34.0, 5],
	]
	var result := []
	for w in count:
		var budget := budget0 * pow(1.26, w)
		var groups := []
		# 最后两波加入 boss
		if w >= count - 2:
			var ogre_n := 1 + int(w == count - 1)
			budget -= 130.0 * ogre_n
			groups.append({"type": "ogre", "count": ogre_n, "interval": 2.5})
		if w == count - 1:
			budget -= 150.0
			groups.append({"type": "troll", "count": 1, "interval": 2.5, "delay": 4.0})
		var delay := 0.0
		var gi := 0
		for entry in schedule:
			var unlock: int = entry[1]
			if w < unlock:
				continue
			var cost: float = entry[3]
			var n := mini(int(budget * entry[2] / cost), entry[4])
			if n <= 0:
				continue
			groups.append({"type": entry[0], "count": n, "interval": maxf(0.45, 1.1 - w * 0.05),
				"delay": delay, "path": (w + gi) % n_paths})
			delay += 2.0
			gi += 1
		result.append(groups)
	return result


func _process(delta: float) -> void:
	if game_ended:
		return
	# 敌人信息面板：跟随生命变化，敌人死亡/离场自动关闭
	if selected_enemy != null:
		if is_instance_valid(selected_enemy) and not selected_enemy.dead:
			_update_enemy_panel()
		else:
			_close_menu()
	# 屏幕震动衰减
	if shake_amp > 0.03:
		shake_amp = lerpf(shake_amp, 0.0, minf(1.0, delta * 9.0))
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amp
	else:
		camera.offset = Vector2.ZERO
	if wave_active:
		wave_time += delta
		while not spawn_events.is_empty() and spawn_events[0]["time"] <= wave_time:
			spawn_enemy(spawn_events[0]["type"], spawn_events[0].get("path", 0))
			spawn_events.pop_front()
		if spawn_events.is_empty() and get_tree().get_nodes_in_group("enemies").is_empty():
			_end_wave()
	elif wave_cooldown > 0.0:
		# 自动开波倒计时
		wave_cooldown -= delta
		wave_timer_bar.value = WAVE_COOLDOWN - wave_cooldown
		start_button.text = "开始第 %d 波（%d 秒）" % [next_wave + 1, ceili(wave_cooldown)]
		if wave_cooldown <= 0.0:
			wave_cooldown = -1.0
			start_wave()
	elif smoke_test:
		start_wave()


func _unhandled_input(event: InputEvent) -> void:
	if game_ended:
		return
	if event is InputEventMouseMotion:
		# 悬停建造点高亮 + 手型光标
		var idx := _spot_at(get_global_mouse_position())
		if idx != hovered_spot:
			hovered_spot = idx
			map_drawer.queue_redraw()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if idx >= 0 else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		# 兵营集合点拾取模式：点道路生效，点其他位置取消
		if rally_pick_tower != null:
			if is_instance_valid(rally_pick_tower) and dist_to_path(pos) <= 60.0:
				var nr := _nearest_path_point(pos)
				rally_pick_tower.set_rally(nr["pt"], nr["dir"])
				play_sfx("build")
				hint_label.text = "集合点已更新"
			else:
				hint_label.text = "已取消"
			rally_pick_tower = null
			map_drawer.queue_redraw()
			return
		# 点击敌人：查看属性与抗性
		var e := _enemy_at(pos)
		if e != null:
			_open_enemy_menu(e)
			return
		var idx := _spot_at(pos)
		if idx >= 0:
			_open_menu(idx)
		else:
			_close_menu()


func _enemy_at(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 30.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var c: Vector2 = e.global_position + Vector2(0, -e.FLY_HEIGHT if e.flying else 0.0)
		var d: float = c.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_path_point(p: Vector2) -> Dictionary:
	var best_pt := Vector2.ZERO
	var best_d := INF
	var best_dir := Vector2.RIGHT
	for i in path_points.size() - 1:
		var a := path_points[i]
		var b := path_points[i + 1]
		var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(cp)
		if d < best_d:
			best_d = d
			best_pt = cp
			best_dir = (b - a).normalized()
	return {"pt": best_pt, "dir": best_dir}


# ---------- 波次 ----------

func start_wave() -> void:
	if wave_active or game_ended or next_wave >= waves.size():
		return
	# 提前开波奖励：倒计时剩余秒数折成金币
	if wave_cooldown > 0.0:
		var bonus := ceili(wave_cooldown)
		gold += bonus
		play_sfx("coin")
		spawn_float_text(Vector2(SCREEN.x / 2.0, SCREEN.y - 130.0), "+%d 金 提前开波" % bonus, Color("f1c40f"))
		_update_hud()
	wave_active = true
	wave_time = 0.0
	spawn_events.clear()
	var t := 0.0
	for group in waves[next_wave]:
		t += group.get("delay", 0.0)
		for i in group["count"]:
			spawn_events.append({"time": t, "type": group["type"], "path": group.get("path", 0)})
			t += group["interval"]
	spawn_hp_scale = 1.0 + hp_growth * next_wave
	next_wave += 1
	if smoke_test:
		print("[smoke] wave %d started, gold=%d lives=%d" % [next_wave, gold, lives])
		_smoke_build()
	wave_cooldown = -1.0
	wave_timer_bar.visible = false
	start_button.disabled = true
	start_button.text = "第 %d 波进攻中…" % next_wave
	hint_label.text = "第 %d 波来袭！" % next_wave
	_update_hud()


func _smoke_build() -> void:
	var order := ["archer", "cannon", "mage", "barracks", "frost"]
	var n := 0
	for i in build_spots.size():
		if towers.has(i):
			var t = towers[i]
			if t.level < 3 and i % 2 == 0 and gold >= t.upgrade_cost():
				gold -= t.upgrade_cost()
				t.apply_upgrade()
			continue
		var key: String = order[n % 3]
		if gold >= LevelData.TOWER_TYPES[key]["cost"]:
			_build_tower(i, key)
			n += 1


func _end_wave() -> void:
	wave_active = false
	if next_wave >= waves.size():
		game_over(true)
		return
	var bonus := 15 + next_wave * 5
	gold += bonus
	start_button.disabled = false
	start_button.text = "开始第 %d 波" % (next_wave + 1)
	hint_label.text = "守住了！奖励 %d 金币　|　%s" % [bonus, _wave_preview_text()]
	# 启动自动开波倒计时
	wave_cooldown = WAVE_COOLDOWN
	wave_timer_bar.value = 0.0
	wave_timer_bar.visible = true
	_update_hud()


func spawn_enemy(type_name: String, path_idx := 0) -> void:
	var e = Enemy.new()
	var pts: PackedVector2Array = paths[path_idx] if path_idx < paths.size() else path_points
	e.setup(type_name, pts, LevelData.ENEMY_TYPES[type_name], spawn_hp_scale)
	e.died.connect(_on_enemy_died)
	e.reached_end.connect(_on_enemy_reached_end)
	add_child(e)


func _on_enemy_died(e) -> void:
	gold += e.reward
	play_sfx("coin")
	spawn_particles(e.global_position, {"texture": FX_SMOKE2, "count": 10, "speed": 80.0,
		"size": 0.08, "gravity": 20.0, "lifetime": 0.8, "grow": 1.8,
		"turb_strength": 1.5, "rand_angle": true,
		"ramp": [[0.0, Color(0.45, 0.45, 0.45, 0.7)], [0.7, Color(0.55, 0.55, 0.55, 0.35)], [1.0, Color(0.6, 0.6, 0.6, 0.0)]]})
	spawn_float_text(e.global_position, "+%d 金" % e.reward, Color("f1c40f"))
	_update_hud()


func _on_enemy_reached_end(e) -> void:
	lives = maxi(0, lives - e.damage)
	play_sfx("leak")
	shake_amp = maxf(shake_amp, 9.0)
	_flash_red()
	_update_hud()
	if lives <= 0:
		game_over(false)


# ---------- 建造 / 升级 / 出售 ----------

func _spot_at(pos: Vector2) -> int:
	for i in build_spots.size():
		if build_spots[i].distance_to(pos) <= 30.0:
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
		title.text = "%s  Lv.%d" % [LevelData.TOWER_TYPES[t.type]["name"], t.level]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		vbox.add_child(title)
		# 当前属性一览
		var stats := Label.new()
		stats.text = _tower_stats_text(t)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 13)
		stats.add_theme_color_override("font_color", Color(0.82, 0.85, 0.78))
		vbox.add_child(stats)
		if t.level < 3:
			var up_btn := Button.new()
			up_btn.text = "升级（%d 金）" % t.upgrade_cost()
			up_btn.custom_minimum_size = Vector2(170, 36)
			up_btn.disabled = gold < t.upgrade_cost()
			_style_button(up_btn)
			up_btn.pressed.connect(_upgrade_tower.bind(idx))
			vbox.add_child(up_btn)
			menu_buttons.append([up_btn, t.upgrade_cost()])
			# 升级预览：数值变化一目了然
			var preview := Label.new()
			preview.text = _tower_upgrade_preview(t)
			preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			preview.add_theme_font_size_override("font_size", 12)
			preview.add_theme_color_override("font_color", Color("8fd35f"))
			vbox.add_child(preview)
		else:
			var max_label := Label.new()
			max_label.text = "已满级"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
			vbox.add_child(max_label)
		if t.type == "barracks":
			var rally_btn := Button.new()
			rally_btn.text = "移动集合点"
			rally_btn.custom_minimum_size = Vector2(170, 32)
			_style_button(rally_btn)
			rally_btn.pressed.connect(_start_rally_pick.bind(idx))
			vbox.add_child(rally_btn)
		var sell_btn := Button.new()
		sell_btn.text = "出售（+%d 金）" % t.sell_value()
		sell_btn.custom_minimum_size = Vector2(170, 36)
		_style_button(sell_btn)
		sell_btn.pressed.connect(_sell_tower.bind(idx))
		vbox.add_child(sell_btn)
	else:
		for key in LevelData.TOWER_TYPES:
			var d: Dictionary = LevelData.TOWER_TYPES[key]
			var btn := Button.new()
			btn.text = "%s  %d 金\n%s" % [d["name"], d["cost"], LevelData.TOWER_ROLE[key]]
			btn.custom_minimum_size = Vector2(170, 48)
			btn.disabled = gold < d["cost"]
			_style_button(btn)
			btn.pressed.connect(_build_tower.bind(idx, key))
			vbox.add_child(btn)
			menu_buttons.append([btn, d["cost"]])
	ui_root.add_child(menu_panel)
	# 菜单定位在建造点旁，并夹在屏幕内
	menu_panel.reset_size()
	var size := menu_panel.get_combined_minimum_size()
	var pos: Vector2 = build_spots[idx] + Vector2(30, -size.y / 2.0)
	pos.x = clampf(pos.x, 8.0, SCREEN.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, SCREEN.y - size.y - 8.0)
	menu_panel.position = pos
	menu_panel.size = size


## 点击敌人：显示生命/速度/赏金与抗性面板
func _open_enemy_menu(e: Node2D) -> void:
	_close_menu()
	selected_enemy = e
	e.selected = true
	map_drawer.queue_redraw()
	menu_panel = PanelContainer.new()
	var pstyle := _panel_style(Color(0.10, 0.11, 0.14, 0.92), Color(0.65, 0.75, 0.9, 0.9), 12)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 8
	pstyle.content_margin_bottom = 8
	menu_panel.add_theme_stylebox_override("panel", pstyle)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	menu_panel.add_child(vbox)
	var data: Dictionary = LevelData.ENEMY_TYPES[e.type]
	var title := Label.new()
	title.text = LevelData.ENEMY_NAMES.get(e.type, e.type)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)
	enemy_hp_label = Label.new()
	enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_hp_label.add_theme_font_size_override("font_size", 13)
	enemy_hp_label.add_theme_color_override("font_color", Color("8fd35f"))
	vbox.add_child(enemy_hp_label)
	enemy_info_labels.clear()
	for line in _enemy_info_lines(e):
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", line[1])
		l.text = line[0]
		vbox.add_child(l)
		enemy_info_labels.append(l)
	ui_root.add_child(menu_panel)
	menu_panel.reset_size()
	var size := menu_panel.get_combined_minimum_size()
	var pos: Vector2 = e.global_position + Vector2(34, -size.y / 2.0)
	pos.x = clampf(pos.x, 8.0, SCREEN.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, SCREEN.y - size.y - 8.0)
	menu_panel.position = pos
	menu_panel.size = size
	_update_enemy_panel()


func _enemy_info_lines(e: Node2D) -> Array:
	var data: Dictionary = LevelData.ENEMY_TYPES[e.type]
	var lines: Array = []
	var speed_txt: String = "飞行 %.0f" % e.speed if e.flying else "速度 %.0f" % e.speed
	lines.append([speed_txt + " · 赏金 %d" % e.reward, Color(0.82, 0.85, 0.78)])
	# 抗性：只显示非中性项
	var armor: Dictionary = e.armor
	var parts: Array = []
	if armor.get("physical", 1.0) != 1.0:
		var m: float = armor["physical"]
		parts.append("物理 ×%.2f" % m)
	if armor.get("magic", 1.0) != 1.0:
		var m2: float = armor["magic"]
		parts.append("魔法 ×%.2f" % m2)
	if parts.is_empty():
		lines.append(["无特殊抗性", Color(0.7, 0.72, 0.68)])
	else:
		lines.append([" · ".join(parts), Color("9b7fe8")])
	if e.flying:
		lines.append(["飞行单位：士兵无法拦截", Color("7fb8e8")])
	return lines


func _update_enemy_panel() -> void:
	if selected_enemy == null or not is_instance_valid(selected_enemy):
		return
	enemy_hp_label.text = "生命 %d / %d" % [ceili(selected_enemy.hp), int(selected_enemy.max_hp)]


func _start_rally_pick(idx: int) -> void:
	var t = towers.get(idx)
	if t == null or t.type != "barracks":
		return
	rally_pick_tower = t
	_close_menu_keep_rally()
	hint_label.text = "点击道路任意位置设置集合点（点空处取消）"
	map_drawer.queue_redraw()


func _close_menu() -> void:
	if menu_panel != null:
		menu_panel.queue_free()
		menu_panel = null
	menu_buttons.clear()
	enemy_hp_label = null
	if selected_enemy != null:
		if is_instance_valid(selected_enemy):
			selected_enemy.selected = false
		selected_enemy = null
	selected_spot = -1
	map_drawer.queue_redraw()


func _close_menu_keep_rally() -> void:
	# 关闭面板但保留集合点拾取状态
	var keep := rally_pick_tower
	_close_menu()
	rally_pick_tower = keep


func _build_tower(idx: int, key: String) -> void:
	var d: Dictionary = LevelData.TOWER_TYPES[key]
	if gold < d["cost"]:
		return
	gold -= d["cost"]
	play_sfx("build")
	var t = Tower.new()
	t.setup(key, d)
	t.position = build_spots[idx]
	if key == "barracks":
		# 兵营：集合点默认取离塔最近的道路点
		var nr := _nearest_path_point(t.position)
		t.set_rally(nr["pt"], nr["dir"])
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
	play_sfx("upgrade")
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
	play_sfx("shoot" if tower.type == "archer" else "shoot_" + tower.type)
	# 炮口焰
	var dir: Vector2 = (target.global_position - tower.global_position).normalized()
	spawn_particles(tower.global_position + dir * 30.0, {"texture": FX_MUZZLE,
		"color": Color(1, 0.9, 0.6), "count": 1, "speed": 0.0, "size": 0.075,
		"lifetime": 0.12, "add": true, "gravity": 0.0, "angle_deg": rad_to_deg(dir.angle()) + 90.0})
	var p = Projectile.new()
	p.setup(tower.global_position, target, tower.proj_speed, tower.current_damage, tower.splash, tower.proj_tex, tower.proj_size, tower.hit_tex, tower.hit_size, tower.damage_type)
	p.slow_pct = tower.slow_pct
	p.slow_time = tower.slow_time
	p.freeze_chance = tower.freeze_chance
	p.freeze_time = tower.freeze_time
	p.pierce = tower.pierce
	p.chain = tower.chain
	p.chain_damage = tower.chain_damage
	add_child(p)
	# 弹幕：剩余弹丸依次补射（目标死亡则射向目标最后已知位置）
	var aim0: Vector2 = target.global_position
	for i in range(tower.burst - 1):
		var delay := 0.14 * (i + 1)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(tower) or game_ended:
				return
			var tgt: Node2D = target if is_instance_valid(target) and not target.dead else null
			var pp = Projectile.new()
			pp.setup(tower.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
				tgt, tower.proj_speed, tower.current_damage, tower.splash, tower.proj_tex,
				tower.proj_size, tower.hit_tex, tower.hit_size, tower.damage_type)
			if tgt == null:
				pp.position = aim0
			add_child(pp)
			play_sfx("shoot_cannon", 0.9, 1.0))


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


## 难度曲线图：三条曲线各自归一化到自身最大值，图例标注实际峰值
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


## 连锁闪电：带抖动的折线电弧，短暂停留后消散
func spawn_lightning(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.65, 0.85, 1.0, 0.95)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = cm
	var seg := maxi(3, int(from.distance_to(to) / 40.0))
	line.add_point(from)
	for i in range(1, seg):
		var t := float(i) / seg
		var p := from.lerp(to, t) + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		line.add_point(p)
	line.add_point(to)
	add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)


func spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
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




func _tower_stats_text(t) -> String:
	var lv: Dictionary = LevelData.TOWER_TYPES[t.type]["levels"][t.level - 1]
	if t.type == "barracks":
		return "士兵 ×%d · 生命 %d · 攻击 %d（物理）\n补兵 %d 秒 · 在集合点拦截敌人" % [
			lv["soldiers"], int(lv["soldier_hp"]), int(lv["soldier_dmg"]), int(lv["respawn"])]
	var text := "伤害 %d · 攻速 %.1f/秒 · 射程 %d\n%s伤害" % [lv["damage"], 1.0 / lv["rate"], int(lv["range"]), LevelData.DMG_TYPE_NAMES[t.damage_type]]
	if lv.has("splash"):
		text += " · 溅射半径 %d" % int(lv["splash"])
	if lv.has("slow_pct"):
		text += "\n命中减速 %d%%（%.0f 秒）· 群体控场" % [int(lv["slow_pct"] * 100), t.slow_time]
	if t.pierce > 0:
		text += "\n穿透：弹道可命中 %d 个目标" % (t.pierce + 1)
	return text


func _tower_upgrade_preview(t) -> String:
	var levels: Array = LevelData.TOWER_TYPES[t.type]["levels"]
	var cur: Dictionary = levels[t.level - 1]
	var nxt: Dictionary = levels[t.level]
	if t.type == "barracks":
		return "士兵 %d→%d · 生命 %d→%d · 攻击 %d→%d" % [cur["soldiers"], nxt["soldiers"],
			int(cur["soldier_hp"]), int(nxt["soldier_hp"]), int(cur["soldier_dmg"]), int(nxt["soldier_dmg"])]
	var parts := ["伤害 %d→%d" % [cur["damage"], nxt["damage"]],
		"DPS %.0f→%.0f" % [cur["damage"] / cur["rate"], nxt["damage"] / nxt["rate"]],
		"射程 %d→%d" % [int(cur["range"]), int(nxt["range"])]]
	if nxt.has("splash"):
		parts.append("溅射 %d→%d" % [int(cur.get("splash", 0.0)), int(nxt["splash"])])
	if nxt.get("pierce", 0) > 0:
		parts.append("解锁穿透")
	return " · ".join(parts)


## 逐波统计：敌方总血量 / 敌方赏金 / 玩家累计金币可支撑的输出模型
func _build_chart_data() -> Array:
	var data := []
	var cum_gold := float(start_gold)
	for w in range(waves.size()):
		var hp_scale := 1.0 + hp_growth * w
		var total_hp := 0.0
		var wave_gold := 0.0
		for group: Dictionary in waves[w]:
			var d: Dictionary = LevelData.ENEMY_TYPES[group["type"]]
			total_hp += d["hp"] * hp_scale * group["count"]
			wave_gold += d["reward"] * group["count"]
		cum_gold += wave_gold + 15.0 + 5.0 * (w + 1)
		data.append({
			"hp": total_hp,
			"gold": wave_gold,
			"dps": cum_gold * 0.28,  # 模型：金币全部折算为箭塔输出（约 0.28 DPS/金）
		})
	return data


func _do_chart_capture() -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"/tmp/tafang_chart_L%d.png" % (level_index + 1))
	print("[chart] saved /tmp/tafang_chart_L%d.png" % (level_index + 1))
	get_tree().quit()


func _wave_preview_text() -> String:
	# 下一波构成预告："第 1 波：哥布林x6"（生成波次按类型归并数量）
	if next_wave >= waves.size():
		return ""
	var counts := {}
	for group in waves[next_wave]:
		var ty: String = group["type"]
		counts[ty] = counts.get(ty, 0) + int(group["count"])
	var parts: Array = []
	for ty in counts:
		parts.append("%s×%d" % [LevelData.ENEMY_NAMES.get(ty, ty), counts[ty]])
	parts.sort()
	return "第 %d 波：%s" % [next_wave + 1, " ".join(parts)]


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


# ---------- 音效（Kenney CC0 音效包，见 assets/sfx/CREDITS.txt） ----------

## 事件名 → 音效文件与音量；coin 有两个变体随机播放
const SFX_TABLE := {
	"shoot": {"file": "res://assets/sfx/sfx_shoot_arrow.ogg", "volume": -6.0},
	"shoot_mage": {"file": "res://assets/sfx/sfx_shoot_mage.ogg", "volume": -6.0},
	"shoot_cannon": {"file": "res://assets/sfx/sfx_shoot_cannon.ogg", "volume": -5.0},
	"shoot_frost": {"file": "res://assets/sfx/sfx_hit_magic.ogg", "volume": -8.0},
	"hit": {"file": "res://assets/sfx/sfx_hit.ogg", "volume": -12.0},
	"hit_magic": {"file": "res://assets/sfx/sfx_hit_magic.ogg", "volume": -10.0},
	"explosion": {"file": "res://assets/sfx/sfx_explosion.ogg", "volume": -6.0},
	"build": {"file": "res://assets/sfx/sfx_build.ogg", "volume": -6.0},
	"upgrade": {"file": "res://assets/sfx/sfx_upgrade.ogg", "volume": -6.0},
	"coin": {"file": "res://assets/sfx/sfx_coin.ogg", "volume": -8.0},
	"coin2": {"file": "res://assets/sfx/sfx_coin2.ogg", "volume": -8.0},
	"leak": {"file": "res://assets/sfx/sfx_leak.ogg", "volume": -4.0},
	"win": {"file": "res://assets/sfx/sfx_win.ogg", "volume": -4.0},
	"lose": {"file": "res://assets/sfx/sfx_lose.ogg", "volume": -4.0},
	"click": {"file": "res://assets/sfx/sfx_click.ogg", "volume": -10.0},
}

func _setup_sfx() -> void:
	for key: String in SFX_TABLE:
		var stream: AudioStream = load(SFX_TABLE[key]["file"])
		if stream == null:
			push_warning("音效缺失: " + key)
			continue
		sfx_streams[key] = {"stream": stream, "volume": SFX_TABLE[key]["volume"]}
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_pool.append(p)


func play_sfx(sfx_name: String, pitch_lo := 0.94, pitch_hi := 1.06) -> void:
	# coin 随机二选一，避免重复感
	if sfx_name == "coin" and randi() % 2 == 0:
		sfx_name = "coin2"
	if not sfx_streams.has(sfx_name):
		return
	var entry: Dictionary = sfx_streams[sfx_name]
	var p: AudioStreamPlayer = sfx_pool[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_pool.size()
	p.stream = entry["stream"]
	p.volume_db = entry["volume"]
	p.pitch_scale = randf_range(pitch_lo, pitch_hi)
	p.play()
func dist_to_path(p: Vector2) -> float:
	var best := INF
	for pts: PackedVector2Array in paths:
		for i in pts.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
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
	btn.pressed.connect(func() -> void: play_sfx("click"))


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
	# 自动开波倒计时进度条（嵌在按钮底部）
	wave_timer_bar = ProgressBar.new()
	wave_timer_bar.max_value = WAVE_COOLDOWN
	wave_timer_bar.show_percentage = false
	wave_timer_bar.position = Vector2(4, 42)
	wave_timer_bar.size = Vector2(212, 6)
	wave_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.45)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.85, 0.3)
	bar_fill.set_corner_radius_all(3)
	wave_timer_bar.add_theme_stylebox_override("background", bar_bg)
	wave_timer_bar.add_theme_stylebox_override("fill", bar_fill)
	wave_timer_bar.visible = false
	start_button.add_child(wave_timer_bar)

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

	# 返回主菜单
	var menu_btn := Button.new()
	menu_btn.text = "菜单"
	menu_btn.custom_minimum_size = Vector2(106, 48)
	menu_btn.position = Vector2(SCREEN.x - 142 - 118, 12)
	menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(menu_btn)
	menu_btn.pressed.connect(_on_back_to_menu)
	ui_root.add_child(menu_btn)

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
	# 打开中的建造/升级菜单随金币实时刷新可用状态
	for pair in menu_buttons:
		if is_instance_valid(pair[0]):
			pair[0].disabled = gold < int(pair[1])
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
		wave_label.text = "%d/%d" % [next_wave, waves.size()]
		if last_wave >= 0:
			_punch_badge(wave_badge)
		last_wave = next_wave


func game_over(win: bool) -> void:
	game_ended = true
	play_sfx("win" if win else "lose")
	if smoke_test:
		print("[smoke] game over win=%s gold=%d lives=%d towers=%d shots=%s" % [win, gold, lives, towers.size(), str(smoke_shots)])
	_close_menu()
	var earned := 0
	if win and not smoke_test:
		# 冒烟测试不写存档，避免污染真实进度
		earned = GameState.complete_level(level_index, lives)
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
	vbox.add_theme_constant_override("separation", 18)
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
	if win:
		var star_label := Label.new()
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_label.add_theme_font_size_override("font_size", 36)
		star_label.add_theme_color_override("font_color", Color("f1c40f"))
		star_label.text = "★".repeat(earned) + "☆".repeat(3 - earned)
		vbox.add_child(star_label)
	if win and level_index < LevelData.LEVELS.size() - 1:
		var next_btn := Button.new()
		next_btn.text = "下一关"
		next_btn.custom_minimum_size = Vector2(200, 52)
		next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_btn.add_theme_font_size_override("font_size", 20)
		_style_button(next_btn, true)
		next_btn.pressed.connect(_on_next_level)
		vbox.add_child(next_btn)
	elif win:
		var done_label := Label.new()
		done_label.text = "已通关全部关卡！"
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_label.add_theme_font_size_override("font_size", 22)
		done_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		vbox.add_child(done_label)
	var restart := Button.new()
	restart.text = "重玩本关" if win else "重试"
	restart.custom_minimum_size = Vector2(200, 48)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override("font_size", 20)
	_style_button(restart, not win)
	restart.pressed.connect(_on_restart)
	vbox.add_child(restart)
	var back := Button.new()
	back.text = "返回主菜单"
	back.custom_minimum_size = Vector2(200, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 20)
	_style_button(back)
	back.pressed.connect(_on_back_to_menu)
	vbox.add_child(back)
	panel.reset_size()
	panel.position = (SCREEN - panel.get_combined_minimum_size()) / 2.0
	panel.size = panel.get_combined_minimum_size()


func _on_next_level() -> void:
	GameState.current_level = level_index + 1
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
