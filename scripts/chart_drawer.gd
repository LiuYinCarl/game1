class_name ChartDrawer
extends Control
var series: Array = []  # [{hp, gold, dps}, ...]
var title := ""

var cn_font := SystemFont.new()

func _ready() -> void:
	cn_font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var m := Vector2(150, 110)  # 边距
	var size_v := Vector2(1920, 1080)
	var plot_size := size_v - m * 2.0 - Vector2(40, 40)
	# 背景
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.09, 0.11, 0.08))
	var font := ThemeDB.fallback_font
	draw_string(cn_font, m + Vector2(0, -30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.95, 0.82, 0.4))
	# 坐标轴与网格（纵轴 = 波次序号，横轴 = 时间？改为：横轴 波次，纵轴 归一化强度）
	var n := series.size()
	draw_line(m, m + Vector2(plot_size.x, plot_size.y), Color(0.7, 0.7, 0.7), 2.0)
	draw_line(m, m + Vector2(0, plot_size.y), Color(0.7, 0.7, 0.7), 2.0)
	for g in range(1, 5):
		var gy := m.y + plot_size.y * g / 5.0
		draw_line(m + Vector2(0, plot_size.y * g / 5.0), m + Vector2(plot_size.x, plot_size.y * g / 5.0), Color(1, 1, 1, 0.08), 1.0)
		draw_string(cn_font, m + Vector2(-56, gy + 6), "%d%%" % (100 - g * 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
	# 横轴波次刻度
	for w in range(n):
		if n > 14 and w % 2 == 1:
			continue
		var wx := m.x + plot_size.x * (w + 0.5) / n
		draw_string(cn_font, Vector2(wx - 10, m.y + plot_size.y + 30), str(w + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))
	draw_string(cn_font, m + Vector2(plot_size.x / 2.0 - 40, m.y + plot_size.y + 62), "波次", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.8, 0.8))
	# 三条曲线
	var defs := [
		{"key": "hp", "color": Color(0.95, 0.35, 0.3), "label": "敌方总血量"},
		{"key": "dps", "color": Color(0.4, 0.7, 1.0), "label": "玩家预期输出"},
		{"key": "gold", "color": Color(1.0, 0.85, 0.3), "label": "敌方赏金"},
	]
	var li := 0
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
		# 图例
		var ly := m.y + 10.0 + li * 34.0
		draw_circle(Vector2(size_v.x - 330, ly), 8.0, def["color"])
		draw_string(cn_font, Vector2(size_v.x - 310, ly + 8), "%s（峰值 %.0f）" % [def["label"], vmax],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.92, 0.92, 0.92))
		li += 1

