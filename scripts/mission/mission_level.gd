extends Node2D
class_name SilentBladeMissionLevel

const StealthZoneScript = preload("res://scripts/stealth/stealth_zone.gd")
const MissionInteractableScript = preload("res://scripts/mission/mission_interactable.gd")

var enemy_spawns: Array[Dictionary] = []
var grapple_anchors: Array[Vector2] = []
var interactables: Array[SilentBladeMissionInteractable] = []
var world_width := 6200.0
var _leaves: Array[Dictionary] = []
var _leaf_refresh := 0.0

func build(stealth_system: SilentBladeStealthSystem) -> void:
	var config := _load_mission_data()
	world_width = float(config.get("world_width", 6200.0))
	for entry in config.get("enemy_spawns", []):
		if entry is Dictionary:
			enemy_spawns.append(entry.duplicate(true))
	grapple_anchors = [
		Vector2(520, 220), Vector2(900, 205), Vector2(1320, 205), Vector2(1770, 185),
		Vector2(2210, 205), Vector2(2650, 190), Vector2(3100, 180), Vector2(3500, 205),
		Vector2(3970, 180), Vector2(4390, 190), Vector2(4880, 210), Vector2(5360, 185), Vector2(5780, 210)
	]
	_build_parallax()
	_build_geometry()
	_build_dressing()
	_build_stealth_environment(stealth_system)
	_build_interactables()
	for index in range(18):
		_leaves.append({"position": Vector2(randf_range(0.0, world_width), randf_range(100.0, 520.0)), "speed": randf_range(12.0, 29.0), "sway": randf_range(7.0, 21.0), "phase": randf_range(0.0, TAU)})
	queue_redraw()

func _load_mission_data() -> Dictionary:
	var path := "res://data/missions/mission_01.json"
	if not FileAccess.file_exists(path):
		push_error("Mission data missing: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Mission data must be a JSON object")
		return {}
	return parsed

func _build_geometry() -> void:
	_add_platform(Vector2(world_width * 0.5, 650), Vector2(world_width, 60), Color("242536"))
	# A — Outer perimeter: low stone ledges and a grass line keep the first sightline readable.
	_add_platform(Vector2(300, 515), Vector2(280, 28), Color("4a4148"))
	_add_platform(Vector2(650, 435), Vector2(240, 26), Color("4b4148"))
	_add_platform(Vector2(930, 545), Vector2(190, 24), Color("393748"))
	# B — Residential quarter: staggered roof levels provide a genuine elevated route.
	_add_platform(Vector2(1210, 462), Vector2(440, 28), Color("51404a"))
	_add_platform(Vector2(1650, 365), Vector2(320, 26), Color("51404a"))
	_add_platform(Vector2(1990, 475), Vector2(270, 26), Color("51404a"))
	_add_platform(Vector2(2130, 555), Vector2(180, 22), Color("3d3742"))
	# C — Guarded courtyard: tower balconies and a raised wall form intersecting patrol lanes.
	_add_platform(Vector2(2445, 485), Vector2(360, 28), Color("49414b"))
	_add_platform(Vector2(2920, 410), Vector2(330, 28), Color("59444b"))
	_add_platform(Vector2(3370, 485), Vector2(300, 28), Color("49414b"))
	_add_platform(Vector2(3500, 555), Vector2(180, 22), Color("393747"))
	# D — Archive: roof access, upper walkway and a ground-floor entrance.
	_add_platform(Vector2(3850, 485), Vector2(300, 28), Color("50434b"))
	_add_platform(Vector2(4230, 395), Vector2(440, 28), Color("60444a"))
	_add_platform(Vector2(4510, 500), Vector2(250, 24), Color("463c46"))
	# E — Evacuation: a high roof route reconnects with the lower exit path.
	_add_platform(Vector2(4860, 490), Vector2(340, 26), Color("49404b"))
	_add_platform(Vector2(5290, 390), Vector2(430, 28), Color("57444c"))
	_add_platform(Vector2(5730, 490), Vector2(340, 26), Color("49404b"))
	# Small stepping platforms are physical, not painted ladder art.
	for step in range(4):
		_add_platform(Vector2(1080 + step * 44, 575 - step * 30), Vector2(72, 18), Color("65504d"))
	for step in range(4):
		_add_platform(Vector2(3580 + step * 42, 575 - step * 29), Vector2(68, 18), Color("65504d"))

func _build_dressing() -> void:
	for pos in [Vector2(170, 650), Vector2(470, 650), Vector2(820, 650), Vector2(1130, 650), Vector2(1530, 650), Vector2(1900, 650), Vector2(2320, 650), Vector2(2740, 650), Vector2(3150, 650), Vector2(3560, 650), Vector2(3890, 650), Vector2(4310, 650), Vector2(4680, 650), Vector2(5050, 650), Vector2(5480, 650), Vector2(5920, 650)]:
		_add_lantern(pos)
	for pos in [Vector2(1330, 650), Vector2(1820, 650), Vector2(4050, 650), Vector2(4470, 650), Vector2(5200, 650)]:
		_add_house(pos)
	_add_watch_tower(Vector2(3065, 650))
	_add_archive_facade(Vector2(4210, 650))
	for pos in [Vector2(320, 650), Vector2(500, 650), Vector2(1010, 650), Vector2(2170, 650), Vector2(2540, 650), Vector2(3420, 650), Vector2(4770, 650), Vector2(5530, 650)]:
		_add_bamboo_cluster(pos)

func _build_stealth_environment(stealth_system: SilentBladeStealthSystem) -> void:
	_add_stealth_zone(stealth_system, "GRASS", Vector2(440, 610), Vector2(280, 96))
	_add_stealth_zone(stealth_system, "GRASS", Vector2(1010, 610), Vector2(180, 94))
	_add_stealth_zone(stealth_system, "GRASS", Vector2(2180, 610), Vector2(220, 92))
	_add_stealth_zone(stealth_system, "GRASS", Vector2(2760, 610), Vector2(240, 94))
	_add_stealth_zone(stealth_system, "GRASS", Vector2(4840, 610), Vector2(260, 94))
	_add_stealth_zone(stealth_system, "GRASS", Vector2(5580, 610), Vector2(220, 94))
	_add_stealth_zone(stealth_system, "DARK", Vector2(780, 590), Vector2(250, 122))
	_add_stealth_zone(stealth_system, "DARK", Vector2(1760, 585), Vector2(250, 122))
	_add_stealth_zone(stealth_system, "DARK", Vector2(2500, 590), Vector2(240, 120))
	_add_stealth_zone(stealth_system, "DARK", Vector2(3600, 590), Vector2(240, 120))
	_add_stealth_zone(stealth_system, "DARK", Vector2(4770, 590), Vector2(220, 118))
	_add_stealth_zone(stealth_system, "LIGHT", Vector2(1300, 590), Vector2(180, 150))
	_add_stealth_zone(stealth_system, "LIGHT", Vector2(2380, 590), Vector2(210, 150))
	_add_stealth_zone(stealth_system, "LIGHT", Vector2(3160, 590), Vector2(220, 150))
	_add_stealth_zone(stealth_system, "LIGHT", Vector2(4250, 590), Vector2(240, 150))
	_add_stealth_zone(stealth_system, "LIGHT", Vector2(5350, 590), Vector2(190, 142))
	_add_cover_obstacle(Vector2(870, 605), Vector2(58, 86))
	_add_cover_obstacle(Vector2(1560, 605), Vector2(66, 84))
	_add_cover_obstacle(Vector2(2630, 605), Vector2(60, 86))
	_add_cover_obstacle(Vector2(3580, 605), Vector2(58, 82))
	_add_cover_obstacle(Vector2(4620, 605), Vector2(62, 86))
	_add_cover_obstacle(Vector2(5420, 605), Vector2(62, 84))
	_add_stealth_zone(stealth_system, "COVER", Vector2(870, 605), Vector2(136, 136))
	_add_stealth_zone(stealth_system, "COVER", Vector2(1560, 605), Vector2(142, 134))
	_add_stealth_zone(stealth_system, "COVER", Vector2(2630, 605), Vector2(136, 136))
	_add_stealth_zone(stealth_system, "COVER", Vector2(3580, 605), Vector2(132, 132))
	_add_stealth_zone(stealth_system, "COVER", Vector2(4620, 605), Vector2(138, 136))
	_add_stealth_zone(stealth_system, "COVER", Vector2(5420, 605), Vector2(138, 134))

func _build_interactables() -> void:
	_add_interactable("village_gate", "door", "ОТКРЫТЬ", false, Vector2(2280, 650))
	_add_interactable("hidden_passage", "door", "ОТКРЫТЬ", false, Vector2(3560, 650), "signal_disabled", "ОТКЛЮЧИТЕ СИГНАЛ")
	_add_interactable("signal_console", "alarm", "ОТКЛЮЧИТЬ", true, Vector2(3210, 610))
	_add_interactable("hidden_cache", "cache", "ТАЙНИК", true, Vector2(1650, 328))
	_add_interactable("field_report", "document", "ЗАПИСКА", true, Vector2(3020, 355))
	_add_interactable("archive_side_door", "door", "ОТКРЫТЬ", false, Vector2(3840, 650))
	_add_interactable("archive_orders", "archive", "ЗАБРАТЬ", true, Vector2(4260, 585))
	_add_interactable("village_checkpoint", "checkpoint", "СОХРАНИТЬ", true, Vector2(2160, 615))
	_add_interactable("archive_checkpoint", "checkpoint", "СОХРАНИТЬ", true, Vector2(3940, 615))
	_add_interactable("evacuation_exit", "evacuation", "ЭВАКУАЦИЯ", false, Vector2(5760, 610), "mission_ready_for_evacuation", "ЗАБЕРИТЕ ПЛАНЫ И ОТКЛЮЧИТЕ СИГНАЛ")

func _add_interactable(id: String, object_kind: String, action_prompt: String, one_shot: bool, pos: Vector2, needs_flag: String = "", locked_text: String = "ЗАКРЫТО") -> void:
	var prop: SilentBladeMissionInteractable = MissionInteractableScript.new()
	prop.name = "Interact_%s" % id
	prop.configure(id, object_kind, action_prompt, one_shot, needs_flag, locked_text)
	prop.position = pos
	add_child(prop)
	interactables.append(prop)

func _add_stealth_zone(stealth_system: SilentBladeStealthSystem, kind: String, center: Vector2, size: Vector2) -> void:
	var zone: SilentBladeStealthZone = StealthZoneScript.new()
	zone.name = "%s_Zone" % kind
	zone.zone_type = kind
	zone.zone_size = size
	zone.position = center
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	zone.add_child(shape)
	add_child(zone)
	stealth_system.register_zone(zone)

func _add_cover_obstacle(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "OpaqueCover"
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, size.y * 0.5), Vector2(-size.x * 0.5, size.y * 0.5)])
	art.color = Color("594331")
	body.add_child(art)
	var plank := Line2D.new()
	plank.points = PackedVector2Array([Vector2(-size.x * 0.42, -size.y * 0.08), Vector2(size.x * 0.42, -size.y * 0.08)])
	plank.default_color = Color("b18a5c")
	plank.width = 4.0
	body.add_child(plank)
	add_child(body)

func _add_platform(center: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, size.y * 0.5), Vector2(-size.x * 0.5, size.y * 0.5)])
	art.color = color
	body.add_child(art)
	var trim := Line2D.new()
	trim.points = PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.5)])
	trim.default_color = Color("c6a879")
	trim.width = 4.0
	body.add_child(trim)
	add_child(body)

func _add_house(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -2
	add_child(node)
	node.draw.connect(func():
		node.draw_rect(Rect2(-105, -210, 210, 210), Color("171d34"))
		node.draw_colored_polygon(PackedVector2Array([Vector2(-130, -210), Vector2(0, -295), Vector2(130, -210)]), Color("101629"))
		node.draw_line(Vector2(-125, -208), Vector2(125, -208), Color("6d4b48"), 9.0)
		for wx in [-60, 0, 60]:
			node.draw_rect(Rect2(wx - 12, -165, 24, 48), Color("db8742"))
		node.draw_rect(Rect2(-18, -70, 36, 70), Color("0c1224"))
	)

func _add_lantern(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -1
	add_child(node)
	node.draw.connect(func():
		node.draw_line(Vector2(0, -68), Vector2(0, -5), Color("28253b"), 3.0)
		node.draw_rect(Rect2(-10, -36, 20, 30), Color("e99a45"))
		node.draw_rect(Rect2(-7, -33, 14, 24), Color("ffd18a"))
		node.draw_circle(Vector2(0, -21), 31, Color(1.0, 0.53, 0.18, 0.08))
	)

func _add_bamboo_cluster(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -1
	add_child(node)
	node.draw.connect(func():
		for stalk in range(5):
			var x := float(stalk - 2) * 17.0
			var height := 105.0 + float((stalk * 23) % 55)
			node.draw_line(Vector2(x, -5), Vector2(x + sin(float(stalk)) * 10.0, -height), Color("29483f"), 5.0)
			for segment in range(1, 4):
				var y := -height * float(segment) / 4.0
				node.draw_line(Vector2(x - 4, y), Vector2(x + 5, y), Color("66805b"), 2.0)
			node.draw_line(Vector2(x, -height * 0.65), Vector2(x - 27, -height * 0.83), Color("456e56"), 4.0)
			node.draw_line(Vector2(x, -height * 0.48), Vector2(x + 24, -height * 0.67), Color("456e56"), 4.0)
	)

func _add_watch_tower(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -1
	add_child(node)
	node.draw.connect(func():
		node.draw_rect(Rect2(-58, -292, 116, 292), Color("211d2c"))
		node.draw_rect(Rect2(-72, -306, 144, 24), Color("654451"))
		node.draw_colored_polygon(PackedVector2Array([Vector2(-84, -306), Vector2(0, -370), Vector2(84, -306)]), Color("151a29"))
		for x in [-34.0, 0.0, 34.0]:
			node.draw_rect(Rect2(x - 8, -260, 16, 38), Color("c77b44"))
	)

func _add_archive_facade(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -2
	add_child(node)
	node.draw.connect(func():
		node.draw_rect(Rect2(-145, -245, 290, 245), Color("181c2d"))
		node.draw_colored_polygon(PackedVector2Array([Vector2(-175, -245), Vector2(0, -340), Vector2(175, -245)]), Color("351f30"))
		node.draw_line(Vector2(-165, -243), Vector2(165, -243), Color("b74c56"), 10.0)
		node.draw_rect(Rect2(-38, -125, 76, 125), Color("2f202b"))
		node.draw_rect(Rect2(-26, -113, 52, 104), Color("ad754e"))
		for y in [-190.0, -160.0, -130.0]:
			node.draw_line(Vector2(-105, y), Vector2(-60, y), Color("b68a63"), 5.0)
			node.draw_line(Vector2(60, y), Vector2(105, y), Color("b68a63"), 5.0)
	)

func _build_parallax() -> void:
	var background := ParallaxBackground.new()
	background.name = "VillageParallax"
	background.layer = -5
	add_child(background)
	var far_layer := ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.12, 0.28)
	var far_art := Node2D.new()
	far_art.draw.connect(func():
		far_art.draw_circle(Vector2(2860, 160), 66, Color("d3def0", 0.75))
		far_art.draw_circle(Vector2(2888, 143), 60, Color("0b1730", 0.92))
		far_art.draw_colored_polygon(PackedVector2Array([Vector2(0, 600), Vector2(430, 320), Vector2(850, 590), Vector2(1330, 300), Vector2(1840, 600), Vector2(2360, 290), Vector2(2920, 600), Vector2(3550, 340), Vector2(4160, 600), Vector2(4770, 320), Vector2(5400, 600), Vector2(6200, 330), Vector2(6200, 720), Vector2(0, 720)]), Color("14213a"))
	)
	far_layer.add_child(far_art)
	background.add_child(far_layer)
	var mid_layer := ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.30, 0.48)
	var mid_art := Node2D.new()
	mid_art.draw.connect(func():
		for x in range(180, 6400, 520):
			mid_art.draw_rect(Rect2(x, 420, 150, 180), Color("111b30"))
			mid_art.draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 420), Vector2(x + 75, 345), Vector2(x + 180, 420)]), Color("0d1729"))
			mid_art.draw_rect(Rect2(x + 28, 468, 22, 42), Color("663548"))
	)
	mid_layer.add_child(mid_art)
	background.add_child(mid_layer)

func _process(delta: float) -> void:
	_leaf_refresh -= delta
	for leaf in _leaves:
		var pos: Vector2 = leaf["position"]
		pos.y += float(leaf["speed"]) * delta
		pos.x += sin(_leaf_refresh + float(leaf["phase"])) * float(leaf["sway"]) * delta
		if pos.y > 650.0:
			pos.y = randf_range(80.0, 180.0)
			pos.x = randf_range(0.0, world_width)
		leaf["position"] = pos
	if _leaf_refresh <= 0.0:
		_leaf_refresh = 0.15
		queue_redraw()

func _draw() -> void:
	# Thin translucent fog bands and slow falling leaves are intentionally low-cost on mobile.
	for i in range(4):
		var y := 520.0 + float(i) * 31.0
		draw_rect(Rect2(0, y, world_width, 19), Color(0.54, 0.63, 0.75, 0.025 + float(i) * 0.009))
	for leaf in _leaves:
		var pos: Vector2 = leaf["position"]
		draw_line(pos, pos + Vector2(7, 3), Color(0.74, 0.65, 0.43, 0.48), 2.0)
	draw_rect(Rect2(0, 646, world_width, 4), Color("9c8062"))
