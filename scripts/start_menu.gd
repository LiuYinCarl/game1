extends Control
## 开始界面：标题 + 六关选择卡片（锁定/星级），点击进入对应关卡。

const TEX_TREE = preload("res://assets/td/towerDefense_tile134.png")
const TEX_BUSH = preload("res://assets/td/towerDefense_tile130.png")
const TEX_ROCK1 = preload("res://assets/td/towerDefense_tile135.png")

const LEVEL_NAMES := GameState.LEVEL_NAMES  # 关卡名由全局状态提供（20 关）


func _ready() -> void:
	_build_ui()
	if OS.get_cmdline_user_args().has("--shot"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_startmenu.png")


class Backdrop extends Node2D:
	func _draw() -> void:
		var size := Vector2(1920, 1080)
		var rng := RandomNumberGenerator.new()
		# 草地底色与大块明暗斑驳
		draw_rect(Rect2(Vector2.ZERO, size), Color("6d9c42"))
		rng.seed = 3
		for i in 70:
			var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
			var r := rng.randf_range(60, 190)
			var c: Color = Color("79a84c") if rng.randf() < 0.5 else Color("628e3a")
			draw_circle(p, r, Color(c.r, c.g, c.b, 0.32))
		# 蜿蜒小路
		var path := PackedVector2Array([Vector2(-60, 900), Vector2(420, 820), Vector2(760, 980),
			Vector2(1150, 760), Vector2(1500, 900), Vector2(2000, 700)])
		draw_polyline(path, Color(0, 0, 0, 0.15), 88.0)
		for p in path:
			draw_circle(p + Vector2(0, 9), 44.0, Color(0, 0, 0, 0.15))
		draw_polyline(path, Color("9c7c50"), 84.0)
		for p in path:
			draw_circle(p, 42.0, Color("9c7c50"))
		draw_polyline(path, Color("c8a76c"), 66.0)
		for p in path:
			draw_circle(p, 33.0, Color("c8a76c"))
		# 装饰（树/灌木/石头），避开中上部的标题与卡片区
		var deco: Array = [TEX_TREE, TEX_BUSH, TEX_ROCK1]
		rng.seed = 9
		for i in 26:
			var p := Vector2(rng.randf_range(30, size.x - 30), rng.randf_range(30, size.y - 30))
			if p.y > 130 and p.y < 950 and p.x > 240 and p.x < 1680:
				continue
			var tex: Texture2D = deco[rng.randi_range(0, deco.size() - 1)]
			var sc := rng.randf_range(0.7, 1.2)
			draw_set_transform(p + Vector2(3, 8 * sc), 0.0, Vector2(sc, sc * 0.4))
			draw_circle(Vector2.ZERO, tex.get_size().x * 0.32, Color(0, 0, 0, 0.2))
			draw_set_transform(p, 0.0, Vector2.ONE * sc)
			draw_texture(tex, -tex.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_ui() -> void:
	# 手绘草地背景
	var backdrop := Backdrop.new()
	add_child(backdrop)
	# 暗角，聚焦中心
	var vshader := Shader.new()
	vshader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	uv.x *= 1.78;
	float v = smoothstep(0.40, 0.95, length(uv) * 1.2);
	COLOR = vec4(0.02, 0.05, 0.01, v * 0.45);
}
"""
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	vmat.shader = vshader
	vignette.material = vmat
	add_child(vignette)

	# 中文系统字体
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 18
	theme = th

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "王国塔防"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.14, 0.02))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 6)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "— 选 择 关 卡 —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.03, 0.8))
	subtitle.add_theme_constant_override("outline_size", 6)
	vbox.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	for i in LEVEL_NAMES.size():
		grid.add_child(_make_level_card(i))

	var quit_btn := Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(190, 50)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_menu_button(quit_btn)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)


func _make_level_card(idx: int) -> Button:
	var locked := idx > GameState.unlocked
	var card := Button.new()
	card.custom_minimum_size = Vector2(236, 168)
	card.disabled = locked
	var star_str := ""
	for k in 3:
		star_str += "★" if k < GameState.stars[idx] else "☆"
	if locked:
		card.text = "第 %d 关 · %s\n\n未 解 锁" % [idx + 1, LEVEL_NAMES[idx]]
	else:
		card.text = "第 %d 关 · %s\n\n%s" % [idx + 1, LEVEL_NAMES[idx], star_str]
	card.add_theme_font_size_override("font_size", 20)
	card.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.03, 0.6))
	card.add_theme_constant_override("outline_size", 3)
	_style_menu_button(card)
	if not locked:
		card.pressed.connect(_on_level_chosen.bind(idx))
	return card


func _on_level_chosen(idx: int) -> void:
	GameState.current_level = idx
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _panel_style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _style_menu_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _panel_style(Color(0.13, 0.14, 0.18, 0.92), Color(0.85, 0.65, 0.25, 0.9), 12))
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.20, 0.21, 0.26, 0.96), Color(1.0, 0.82, 0.38, 0.95), 12))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.09, 0.11, 0.97), Color(0.6, 0.45, 0.18, 0.9), 12))
	btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.10, 0.10, 0.12, 0.55), Color(0.35, 0.35, 0.35, 0.45), 12))
	btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.8))
	# 悬停轻微放大，增强反馈
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled:
			btn.scale = Vector2(1.03, 1.03))
	btn.mouse_exited.connect(func() -> void: btn.scale = Vector2.ONE)
