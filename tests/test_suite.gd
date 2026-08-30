extends RefCounted
## 自动化测试套件：由游戏内 --test 开关触发（main.gd）。
## 运行：godot --headless --path . scenes/main.tscn -- --test
## 输出 PASS/FAILED，进程退出码 0/1，可直接接入 CI。

const TOL := 0.01


static func run(main: Node) -> int:
	var failures: Array[String] = []
	var checks := 0

	# ---------- 关卡数据 ----------
	checks += 1
	if main.LEVELS.size() != 20:
		failures.append("关卡数量应为 20，实际 %d" % main.LEVELS.size())
	checks += 1
	var names := {}
	for L in main.LEVELS:
		names[L["name"]] = names.get(L["name"], 0) + 1
	for n in names:
		if names[n] > 1:
			failures.append("关卡名重复: " + str(n))

	# 逐关加载并校验
	for i in range(main.LEVELS.size()):
		main._load_level(i)
		var tag := "L%d(%s)" % [i + 1, main.level_name]

		# 路径结构
		checks += 1
		if main.paths.is_empty() or main.paths.size() > 3:
			failures.append(tag + " 路径数量应在 1-3，实际 " + str(main.paths.size()))
		checks += 1
		var bad_pts := 0
		for pts: PackedVector2Array in main.paths:
			if pts.size() < 2:
				bad_pts += 1
				continue
			for p in pts:
				if p.x < -100 or p.x > 2020 or p.y < -100 or p.y > 1180:
					bad_pts += 1
		if bad_pts > 0:
			failures.append(tag + " 有 %d 个越界路径点" % bad_pts)

		# 所有路径汇聚到同一王城（终点相互距离 ≤ 150）
		checks += 1
		var end0: Vector2 = main.paths[0][main.paths[0].size() - 1]
		for pi in range(1, main.paths.size()):
			var endi: Vector2 = main.paths[pi][main.paths[pi].size() - 1]
			if endi.distance_to(end0) > 150.0:
				failures.append(tag + " 路径 %d 终点偏离主路径终点 %.0f px" % [pi, endi.distance_to(end0)])

		# 建造点：数量、可达性、间距
		checks += 1
		if main.build_spots.size() < 8 or main.build_spots.size() > 22:
			failures.append(tag + " 建造点数量异常: %d" % main.build_spots.size())
		checks += 1
		var unreachable := 0
		var too_close := 0
		for si in range(main.build_spots.size()):
			var s: Vector2 = main.build_spots[si]
			var d: float = main.dist_to_path(s)
			if d < 40.0 or d > 185.0:
				unreachable += 1
			for sj in range(si + 1, main.build_spots.size()):
				if s.distance_to(main.build_spots[sj]) < 70.0:
					too_close += 1
		if unreachable > 0:
			failures.append(tag + " 有 %d 个建造点距路径不合法（需 40-185px）" % unreachable)
		if too_close > 0:
			failures.append(tag + " 有 %d 对建造点间距 < 70px" % too_close)

		# 波次
		checks += 1
		if main.waves.is_empty():
			failures.append(tag + " 没有波次")
		checks += 1
		var used_paths := {}
		var wave_err := ""
		for w in range(main.waves.size()):
			var wave: Array = main.waves[w]
			if wave.is_empty():
				wave_err = "第 %d 波为空" % (w + 1)
				break
			for group: Dictionary in wave:
				if not main.ENEMY_TYPES.has(group["type"]):
					wave_err = "第 %d 波含未知敌人 %s" % [w + 1, group["type"]]
					break
				var pi: int = group.get("path", 0)
				if pi < 0 or pi >= main.paths.size():
					wave_err = "第 %d 波路径索引越界 %d" % [w + 1, pi]
					break
				used_paths[pi] = true
				if group["count"] <= 0 or group["interval"] <= 0:
					wave_err = "第 %d 波参数非法" % (w + 1)
					break
		if wave_err != "":
			failures.append(tag + " " + wave_err)

		# 最终波含 Boss
		checks += 1
		var last_wave: Array = main.waves[main.waves.size() - 1]
		var has_ogre := false
		var has_troll := false
		for group: Dictionary in last_wave:
			if group["type"] == "ogre": has_ogre = true
			if group["type"] == "troll": has_troll = true
		if not (has_ogre and has_troll):
			failures.append(tag + " 最终波缺少 Boss（ogre/troll）")

		# 多路径关卡：所有路径都有敌人经过
		if main.paths.size() > 1:
			checks += 1
			if used_paths.size() < main.paths.size():
				failures.append(tag + " %d 条路径中仅 %d 条有敌人经过" % [main.paths.size(), used_paths.size()])

	# ---------- 抗性乘算 ----------
	var e = load("res://scripts/enemy.gd").new()
	e.armor = {"physical": 0.45, "magic": 1.6}
	checks += 1
	if absf(e.armor_mult("physical") - 0.45) > TOL or absf(e.armor_mult("magic") - 1.6) > TOL:
		failures.append("armor_mult 返回值错误")
	checks += 1
	if absf(e.armor_mult("unknown") - 1.0) > TOL:
		failures.append("未知伤害类型的抗性应为 1.0")
	e.free()

	# ---------- 升级费用表 ----------
	for key in ["archer", "mage", "cannon", "barracks"]:
		var t = load("res://scripts/tower.gd").new()
		t.setup(key, main.TOWER_TYPES[key])
		checks += 1
		var c1: int = t.upgrade_cost()
		t.apply_upgrade()
		var c2: int = t.upgrade_cost()
		if c1 <= 0 or c2 <= c1:
			failures.append("塔 %s 升级费用不递增: %d → %d" % [key, c1, c2])
		t.apply_upgrade()
		checks += 1
		if t.upgrade_cost() != 0:
			failures.append("塔 %s 满级后升级费用应为 0" % key)
		checks += 1
		if t.sell_value() != int(t.invested * 0.7):
			failures.append("塔 %s 出售价应为投入的 70%%" % key)
		t.free()

	# ---------- 存档逻辑（不落盘） ----------
	var gs = GameState
	var old_unlocked: int = gs.unlocked
	var old_persist: bool = gs.persist
	gs.persist = false
	checks += 1
	gs.stars[3] = 0
	var earned: int = gs.complete_level(3, 20)
	if earned != 3 or gs.stars[3] != 3:
		failures.append("满生命通关应得 3 星")
	gs.stars[3] = 0
	earned = gs.complete_level(3, 5)
	if earned != 1 or gs.stars[3] != 1:
		failures.append("低生命通关应得 1 星")
	checks += 1
	if gs.unlocked != maxi(old_unlocked, 4):
		failures.append("通关后应解锁下一关")
	gs.unlocked = old_unlocked
	gs.stars[3] = 0
	gs.persist = old_persist

	# ---------- 波次预告文本 ----------
	main._load_level(0)
	checks += 1
	if not main._wave_preview_text().begins_with("第 1 波"):
		failures.append("波次预告文本格式错误: " + main._wave_preview_text())

	# ---------- 汇总 ----------
	for f in failures:
		print("[TEST][FAIL] ", f)
	print("[TEST] 共 %d 项检查，%d 项失败" % [checks, failures.size()])
	return failures.size()
