extends Node
## 全局游戏状态：当前关卡、解锁进度、星级与存档读写。

const SAVE_PATH := "user://save.json"
const LEVEL_COUNT := 20
const LEVEL_NAMES := [
	"翠绿小径", "蜿蜒河谷", "林地阶梯", "双子河口", "回环林地",
	"峡谷要道", "双子河谷", "山道盘旋", "三岔峡谷", "帝国大道",
	"沼泽双径", "回旋走廊", "三路会师", "断桥峡谷", "迷雾盘径",
	"三面楚歌", "双龙出海", "折返迷宫", "王城三径", "决战王城",
]

var current_level := 0
var unlocked := 0  # 已解锁的最高关卡（0 基）
var stars: Array[int] = []
var persist := true  # 测试模式置 false，避免污染真实存档


func _ready() -> void:
	stars.resize(LEVEL_COUNT)
	stars.fill(0)
	load_game()


func complete_level(idx: int, lives_remaining: int) -> int:
	var earned := 1
	if lives_remaining >= 18:
		earned = 3
	elif lives_remaining >= 12:
		earned = 2
	stars[idx] = maxi(stars[idx], earned)
	if idx < LEVEL_COUNT - 1:
		unlocked = maxi(unlocked, idx + 1)
	if persist:
		save_game()
	return earned


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"unlocked": unlocked, "stars": stars}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		unlocked = clampi(int(data.get("unlocked", 0)), 0, LEVEL_COUNT - 1)
		var s: Array = data.get("stars", [])
		for i in mini(s.size(), LEVEL_COUNT):
			stars[i] = int(s[i])
