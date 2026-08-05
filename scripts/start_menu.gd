extends Control
## 开始界面：标题 + 六关选择卡片（锁定/星级），点击进入对应关卡。

const LEVEL_NAMES := ["翠绿小径", "河畔弯道", "回旋谷", "双峰峡谷", "迷雾沼泽", "王城决战"]


func _ready() -> void:
	_build_ui()
	if OS.get_cmdline_user_args().has("--shot"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/tafang_startmenu.png")


func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color("3d5a2b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "王国塔防"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选 择 关 卡"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 0.8))
	vbox.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	for i in LEVEL_NAMES.size():
		grid.add_child(_make_level_card(i))

	var quit_btn := Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(180, 48)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_menu_button(quit_btn)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)


func _make_level_card(idx: int) -> Button:
	var locked := idx > GameState.unlocked
	var card := Button.new()
	card.custom_minimum_size = Vector2(230, 160)
	card.disabled = locked
	var star_str := ""
	for k in 3:
		star_str += "★" if k < GameState.stars[idx] else "☆"
	if locked:
		card.text = "第 %d 关\n%s\n未解锁" % [idx + 1, LEVEL_NAMES[idx]]
	else:
		card.text = "第 %d 关\n%s\n%s" % [idx + 1, LEVEL_NAMES[idx], star_str]
	card.add_theme_font_size_override("font_size", 20)
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
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _style_menu_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _panel_style(Color(0.13, 0.14, 0.18, 0.95), Color(0.85, 0.65, 0.25, 0.9), 12))
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.23, 0.28, 0.97), Color(1.0, 0.8, 0.35, 0.95), 12))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.09, 0.11, 0.97), Color(0.6, 0.45, 0.18, 0.9), 12))
	btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.10, 0.10, 0.12, 0.6), Color(0.35, 0.35, 0.35, 0.5), 12))
	btn.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
