class_name ChartDrawer
extends Control
## 难度曲线图：三条曲线各自归一化到自身最大值，图例标注实际峰值。
## 文字一律用 Label 控件渲染（走 UI 主题字体，避免 draw_string 的字形缺字问题）。

var series: Array = []  # [{hp, gold, dps}, ...]
var title := ""

var cn_font: Font = load("res://assets/fonts/NotoSansSC-Regular.otf")

const M := Vector2(150, 110)  # 绘图边距
const SIZE_V := Vector2(1920, 1080)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_labels()


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font", cn_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _build_labels() -> void:
	var defs := [
		{"key": "hp", "label": "敌方总血量", "color": Color(0.95, 0.35, 0.3)},
		{"key": "dps", "label": "玩家预期输出", "color": Color(0.4, 0.7, 1.0)},
		{"key": "gold", "label": "敌方赏金", "color": Color(1.0, 0.85, 0.3)},
	]
	_label(title, Vector2(M.x, 40), Vector2(900, 60), 40, Color(0.95, 0.82, 0.4))
	_label("波次", Vector2(M.x + (SIZE_V.x - M.x * 2.0 - 40) / 2.0 - 30, M.y + (SIZE_V.y - M.y * 2.0 - 40) + 30), Vector2(120, 30), 22, Color(0.8, 0.8, 0.8))
	var vmax := {}
	for def in defs:
		var m := 0.001
		for d in series:
			m = maxf(m, float(d[def["key"]]))
		vmax[def["key"]] = m
	var li := 0
	for def in defs:
		var ly := M.y + 14.0 + li * 34.0
		_label("%s（峰值 %.0f）" % [def["label"], vmax[def["key"]]],
			Vector2(M.x + 310, ly - 10), Vector2(320, 32), 22, Color(0.92, 0.92, 0.92))
		li += 1


func _draw() -> void:
	var m := M
	var plot_size := SIZE_V - m * 2.0 - Vector2(40, 40)
	# 背景与坐标轴
	draw_rect(Rect2(Vector2.ZERO, SIZE_V), Color(0.09, 0.11, 0.08))
	draw_line(m + Vector2(0, plot_size.y), m + Vector2(plot_size.x, plot_size.y), Color(0.7, 0.7, 0.7), 2.0)
	draw_line(m, m + Vector2(0, plot_size.y), Color(0.7, 0.7, 0.7), 2.0)
	# 横向网格线与百分比刻度（数字与百分号用 draw_string，无缺字问题）
	var font: Font = cn_font
	for g in range(1, 5):
		var gy := m.y + plot_size.y * g / 5.0
		draw_line(m + Vector2(0, plot_size.y * g / 5.0), m + Vector2(plot_size.x, plot_size.y * g / 5.0), Color(1, 1, 1, 0.08), 1.0)
		draw_string(font, m + Vector2(-56, gy + 6), "%d%%" % (100 - g * 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
	# 横轴波次刻度
	var n := series.size()
	for w in range(n):
		if n > 14 and w % 2 == 1:
			continue
		var wx := m.x + plot_size.x * (w + 0.5) / n
		draw_string(font, Vector2(wx - 10, m.y + plot_size.y + 30), str(w + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
	# 三条曲线
	var defs := [
		{"key": "hp", "color": Color(0.95, 0.35, 0.3)},
		{"key": "dps", "color": Color(0.4, 0.7, 1.0)},
		{"key": "gold", "color": Color(1.0, 0.85, 0.3)},
	]
	for def in defs:
		var vals: Array = []
		var vmax := 0.001
		for d in series:
			vals.append(float(d[def["key"]]))
			vmax = maxf(vmax, float(d[def["key"]]))
		var pts := PackedVector2Array()
		for i in range(n):
			pts.append(m + Vector2(plot_size.x * (i + 0.5) / n, plot_size.y * (1.0 - vals[i] / vmax)))
		draw_polyline(pts, def["color"], 4.0)
		for p in pts:
			draw_circle(p, 5.0, def["color"])
	# 图例底板：不透明深色面板，避免曲线穿过图例文字
	var panel := Rect2(M.x + 240, M.y + 2, 386, defs.size() * 34 + 22)
	draw_rect(panel, Color(0.09, 0.11, 0.08, 0.92))
	draw_rect(panel, Color(0.85, 0.65, 0.25, 0.35), false, 2.0)
	# 图例色点（文字由 Label 渲染）
	for li in range(defs.size()):
		var ly := M.y + 24.0 + li * 34.0
		draw_circle(Vector2(M.x + 290, ly), 8.0, defs[li]["color"])
