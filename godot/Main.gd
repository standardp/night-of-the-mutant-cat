extends Control
# NIGHT OF THE MUTANT CAT — Godot 4 port
# 320x200 pixel art, verb-interface adventure. Same puzzle chain as the web build.

const ABIL := {"wes": "HACK", "tank": "LIFT", "vic": "CALM"}

const TEX := {
	"living_default": preload("res://assets/living_default.png"),
	"hall_off": preload("res://assets/hall_off.png"),
	"hall_on": preload("res://assets/hall_on.png"),
	"kitchen_default": preload("res://assets/kitchen_default.png"),
	"kitchen_open": preload("res://assets/kitchen_open.png"),
	"bathroom_dryer": preload("res://assets/bathroom_dryer.png"),
	"bathroom_nodryer": preload("res://assets/bathroom_nodryer.png"),
}

const ICON := {
	"dryer": preload("res://assets/icon_dryer.png"),
	"tuna": preload("res://assets/icon_tuna.png"),
}

const CAT_TEX := preload("res://assets/cat.png")

const SPR := {
	"wes": preload("res://assets/spr_wes.png"),
	"tank": preload("res://assets/spr_tank.png"),
	"vic": preload("res://assets/spr_vic.png"),
}

const ROOMS := {
	"living": {
		"exits": {"door_hall": "hall"},
		"spots": [
			{"id": "tank", "r": Rect2(78, 100, 62, 30)},
			{"id": "beast", "r": Rect2(86, 34, 54, 70)},
			{"id": "sofa", "r": Rect2(8, 118, 92, 42)},
			{"id": "laptop", "r": Rect2(126, 136, 26, 16)},
			{"id": "vacuum", "r": Rect2(203, 163, 28, 20)},
			{"id": "door_hall", "r": Rect2(282, 55, 36, 78)},
		],
	},
	"hall": {
		"exits": {"door_liv": "living", "door_kit": "kitchen", "door_bath": "bathroom"},
		"spots": [
			{"id": "fuse", "r": Rect2(180, 20, 38, 36)},
			{"id": "door_liv", "r": Rect2(12, 45, 40, 92)},
			{"id": "door_kit", "r": Rect2(130, 45, 40, 92)},
			{"id": "door_bath", "r": Rect2(260, 45, 40, 92)},
		],
	},
	"kitchen": {
		"exits": {"door_hall": "hall"},
		"spots": [
			{"id": "pantry", "r": Rect2(20, 40, 38, 66)},
			{"id": "freezer", "r": Rect2(198, 104, 94, 44)},
			{"id": "sink", "r": Rect2(100, 92, 32, 20)},
			{"id": "door_hall", "r": Rect2(278, 50, 38, 80)},
		],
	},
	"bathroom": {
		"exits": {"door_hall": "hall"},
		"spots": [
			{"id": "dryer", "r": Rect2(64, 94, 32, 14)},
			{"id": "outlet", "r": Rect2(106, 86, 22, 16)},
			{"id": "mirror", "r": Rect2(118, 20, 64, 44)},
			{"id": "tub", "r": Rect2(208, 98, 90, 44)},
			{"id": "door_hall", "r": Rect2(20, 50, 38, 80)},
		],
	},
}

var lang := "en"
var state := {
	"cat": "wes", "room": "living", "verb": "WALK", "item": "",
	"power": false, "freezer_open": false, "tuna_open": false, "tuna_in": false,
	"vacuum": false, "cat_kitchen": false, "calmed": false,
	"taken": {}, "steps": 0, "won": false,
}

var TX := {}

var bg: Sprite2D
var actor: Sprite2D
var cat_spr: Sprite2D
var stage: Control
var world: Node2D
var spot_layer: Control
var log_lbl: Label
var sent_lbl: Label
var verb_bar: HBoxContainer
var inv_bar: HBoxContainer
var meter: ProgressBar
var overlay: ColorRect
var crew_bar: HBoxContainer
var room_lbl: Label

func _ready() -> void:
	TX = _texts()
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_build()
	_layout()
	_refresh()
	_show_start()
	if "--solve" in OS.get_cmdline_user_args():
		_solve()

func _solve() -> void:
	await get_tree().create_timer(0.5).timeout
	_start("es")
	await get_tree().create_timer(0.3).timeout
	print("DBG vis=", actor.visible, " tex=", actor.texture, " pos=", actor.position, " gpos=", actor.global_position, " scale_world=", world.scale, " world_pos=", world.position, " stage=", stage.size)
	await get_tree().create_timer(0.4).timeout
	_switch("tank")
	_fuse()
	await get_tree().create_timer(0.3).timeout
	_go("bathroom")
	_dryer()
	_go("kitchen")
	await get_tree().create_timer(0.4).timeout
	_pantry()
	_open_tuna()
	state["item"] = "dryer"
	_freezer()
	state["item"] = "tuna"
	_freezer()
	_go("living")
	_switch("wes")
	_vacuum()
	_switch("vic")
	_calm()
	_go("kitchen")
	_freezer()
	print("SOLVE_RESULT won=", state["won"], " steps=", state["steps"], " lang=", lang)
	print("LAST_LOG=", log_lbl.text)
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0 if state["won"] else 1)

# ---------------------------------------------------------------- layout
func _build() -> void:
	var clear := ColorRect.new()
	clear.color = Color(0.04, 0.03, 0.05)
	clear.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(clear)

	# fuente pixel, sin suavizado
	var pf := FontFile.new()
	pf.load_dynamic_font("res://assets/font.ttf")
	pf.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pf.hinting = TextServer.HINTING_NONE
	pf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var th := Theme.new()
	th.default_font = pf
	th.default_font_size = 14
	theme = th

	# barra de personajes arriba
	crew_bar = HBoxContainer.new()
	crew_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	crew_bar.offset_bottom = 30
	crew_bar.add_theme_constant_override("separation", 6)
	add_child(crew_bar)
	for who in ["wes", "tank", "vic"]:
		var b := Button.new()
		b.flat = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _switch(who))
		crew_bar.add_child(b)

	# escenario
	stage = Control.new()
	stage.anchor_right = 1.0
	stage.anchor_bottom = 1.0
	stage.offset_top = 32
	stage.offset_bottom = -112
	stage.clip_contents = true
	add_child(stage)
	stage.resized.connect(_layout)

	world = Node2D.new()
	stage.add_child(world)

	bg = Sprite2D.new()
	bg.texture = TEX["living_default"]
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(bg)

	cat_spr = Sprite2D.new()
	cat_spr.texture = CAT_TEX
	cat_spr.centered = false
	cat_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cat_spr.visible = false
	world.add_child(cat_spr)

	spot_layer = Control.new()
	spot_layer.size = Vector2(320, 200)
	spot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(spot_layer)

	actor = Sprite2D.new()
	actor.texture = SPR["wes"]
	actor.centered = false
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.position = Vector2(260, 106)
	world.add_child(actor)

	# HUD abajo
	var hud := ColorRect.new()
	hud.color = Color(0.10, 0.08, 0.13)
	hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_top = -110
	add_child(hud)

	room_lbl = _label("", 13, Color(0.65, 0.6, 0.72), Vector2(10, 0), Vector2(300, 16))
	room_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	room_lbl.offset_top = -108
	room_lbl.offset_left = 10

	log_lbl = _label("", 14, Color(0.91, 0.71, 0.29), Vector2(10, 0), Vector2(10, 42))
	log_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_lbl.offset_left = 10
	log_lbl.offset_right = -10
	log_lbl.offset_top = -92
	log_lbl.offset_bottom = -50
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	sent_lbl = _label("", 13, Color(0.75, 0.7, 0.82), Vector2(10, 0), Vector2(10, 14))
	sent_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sent_lbl.offset_left = 10
	sent_lbl.offset_top = -46
	sent_lbl.offset_bottom = -32

	inv_bar = HBoxContainer.new()
	inv_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inv_bar.offset_left = 10
	inv_bar.offset_top = -196
	inv_bar.add_theme_constant_override("separation", 6)
	add_child(inv_bar)

	meter = ProgressBar.new()
	meter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	meter.offset_left = -160
	meter.offset_top = -196
	meter.offset_right = -10
	meter.offset_bottom = -188
	meter.max_value = 100
	meter.show_percentage = false
	add_child(meter)

	verb_bar = HBoxContainer.new()
	verb_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	verb_bar.offset_left = 200
	verb_bar.offset_top = -32
	verb_bar.offset_bottom = -4
	verb_bar.alignment = BoxContainer.ALIGNMENT_END
	verb_bar.add_theme_constant_override("separation", 6)
	add_child(verb_bar)

	var hint := Button.new()
	hint.text = "?"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -40
	hint.offset_top = -108
	hint.offset_right = -10
	hint.offset_bottom = -78
	hint.add_theme_font_size_override("font_size", 14)
	hint.pressed.connect(_hint)
	add_child(hint)

	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.04, 0.96)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

func _layout() -> void:
	if not is_instance_valid(world) or stage == null:
		return
	# escala por ancho y ancla el fondo: el piso y los personajes nunca se recortan
	var s := minf(stage.size.x / 320.0, stage.size.y / 200.0)
	world.scale = Vector2(s, s)
	world.position = Vector2(
		(stage.size.x - 320.0 * s) * 0.5,
		(stage.size.y - 200.0 * s) * 0.5
	)

func _label(txt: String, size: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

# ---------------------------------------------------------------- render
func _refresh() -> void:
	if not state["won"]:
		room_lbl.text = TX["rooms"][state["room"]]["n"]
		bg.texture = _bg_for(state["room"])
		actor.visible = true
		actor.texture = SPR[state["cat"]]
	else:
		actor.visible = false
	cat_spr.visible = false
	if state["cat_kitchen"] and state["room"] == "kitchen":
		cat_spr.visible = true
		cat_spr.position = Vector2(120, 106)
	elif not state["cat_kitchen"] and state["room"] == "living":
		cat_spr.visible = true
		cat_spr.position = Vector2(78, 52)
	_build_spots()
	_say(TX["rooms"][state["room"]]["d"])
	_build_verbs()
	_build_inv()
	meter.value = mini(100, state["steps"] * 4)

func _bg_for(r: String) -> Texture2D:
	match r:
		"hall":
			return TEX["hall_on"] if state["power"] else TEX["hall_off"]
		"kitchen":
			return TEX["kitchen_open"] if state["freezer_open"] else TEX["kitchen_default"]
		"bathroom":
			return TEX["bathroom_nodryer"] if state["taken"].has("dryer") else TEX["bathroom_dryer"]
	return TEX["living_default"]

func _build_spots() -> void:
	for c in spot_layer.get_children():
		c.queue_free()
	for s in ROOMS[state["room"]]["spots"]:
		if s["id"] == "beast" and state["cat_kitchen"]:
			continue
		var b := Button.new()
		b.flat = true
		b.position = s["r"].position
		b.size = s["r"].size
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _spot(s["id"]))
		b.mouse_entered.connect(func(): _hover(s["id"]))
		spot_layer.add_child(b)

func _build_verbs() -> void:
	for c in verb_bar.get_children():
		c.queue_free()
	var list := ["WALK", "LOOK", "TAKE", "USE", "OPEN", "TALK", ABIL[state["cat"]]]
	for v in list:
		var b := Button.new()
		b.text = TX["ab"][state["cat"]] if v == ABIL[state["cat"]] else TX["verbs"][v]
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		var sel: bool = state["verb"] == v
		b.modulate = Color(0.55, 0.85, 0.7) if sel else Color(1, 1, 1)
		b.pressed.connect(func(): _set_verb(v))
		verb_bar.add_child(b)
	var ck := ["wes", "tank", "vic"]
	for c in crew_bar.get_children():
		var k: String = ck[c.get_index()]
		c.text = TX["crew"][k][0]
		c.modulate = Color(0.91, 0.71, 0.29) if k == state["cat"] else Color(1, 1, 1)

func _build_inv() -> void:
	for c in inv_bar.get_children():
		c.queue_free()
	for it in state["taken"].keys():
		var b := Button.new()
		b.icon = ICON.get(it, null)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = TX["hs"].get(it, it)
		b.focus_mode = Control.FOCUS_NONE
		if state["item"] == it:
			b.modulate = Color(0.45, 1.0, 0.8)
		b.pressed.connect(func(): _tap_item(it))
		inv_bar.add_child(b)

func _say(t: String) -> void:
	log_lbl.text = t

func _hover(id: String) -> void:
	if state["item"] == "":
		sent_lbl.text = "%s · %s" % [TX["verbs"].get(state["verb"], state["verb"]), TX["hs"].get(id, id)]

# ---------------------------------------------------------------- input
func _set_verb(v: String) -> void:
	state["verb"] = "WALK" if state["verb"] == v else v
	if not ["USE", "LIFT", "HACK", "CALM"].has(state["verb"]):
		state["item"] = ""
	_build_verbs()
	_build_inv()
	sent_lbl.text = TX["verbs"].get(state["verb"], state["verb"])

func _switch(who: String) -> void:
	state["cat"] = who
	state["item"] = ""
	state["verb"] = "WALK"
	_refresh()

func _tap_item(it: String) -> void:
	if state["item"] == it:
		var act: String = "%s|%s" % [it, state["verb"]]
		if state["verb"] != "USE" and _actions().has(act):
			_actions()[act].call()
			return
		state["item"] = ""
	else:
		state["item"] = it
		state["verb"] = "USE"
	_build_verbs()
	_build_inv()

func _spot(id: String) -> void:
	if state["won"]:
		return
	if ROOMS[state["room"]]["exits"].has(id):
		_go(ROOMS[state["room"]]["exits"][id])
		return
	if state["verb"] == "WALK":
		actor.position.x = clampf(_spot_center(id), 16, 266)
		return
	if state["verb"] == "LOOK":
		_say(_look(id))
		return
	var key: String = "%s|%s" % [id, state["verb"]]
	if _actions().has(key):
		_actions()[key].call()
		return
	if _actions().has("%s|USE" % id):
		_actions()["%s|USE" % id].call()
		return
	if state["verb"] == "TALK":
		_say(TX["act"]["talk"].format({"who": _who()}))
		return
	_say(TX["act"]["nothing"].format({"who": _who(), "what": TX["hs"].get(id, id)}))
	state["steps"] += 1
	meter.value = mini(100, state["steps"] * 4)

func _spot_center(id: String) -> float:
	for s in ROOMS[state["room"]]["spots"]:
		if s["id"] == id:
			return s["r"].position.x + s["r"].size.x * 0.5
	return 150.0

func _who() -> String:
	return TX["crew"][state["cat"]][0]

func _look(id: String) -> String:
	if id == "beast" and state["cat_kitchen"]:
		return TX["look"]["beastGone"]
	return TX["look"].get(id, TX["look"]["door"])

func _go(room: String) -> void:
	state["room"] = room
	state["item"] = ""
	state["verb"] = "WALK"
	state["steps"] += 1
	_refresh()
	actor.position.x = 200

func _hint() -> void:
	var k: Array = TX["hints"]
	if not state["power"]:
		_say(k[0])
	elif not state["taken"].has("dryer"):
		_say(k[1])
	elif not state["freezer_open"]:
		_say(k[2])
	elif not state["taken"].has("tuna"):
		_say(k[3])
	elif not state["tuna_in"]:
		_say(k[4])
	elif not state["vacuum"]:
		_say(k[5])
	elif not state["calmed"]:
		_say(k[6])
	else:
		_say(k[7])

# ---------------------------------------------------------------- actions
func _actions() -> Dictionary:
	return {
		"fuse|LIFT": _fuse, "fuse|USE": _fuse,
		"dryer|TAKE": _dryer,
		"pantry|OPEN": _pantry, "pantry|USE": _pantry,
		"tuna|LIFT": _open_tuna,
		"freezer|USE": _freezer, "freezer|OPEN": _freezer,
		"laptop|HACK": _vacuum, "laptop|USE": _vacuum,
		"beast|CALM": _calm, "beast|USE": _calm,
		"beast|TALK": _talk_beast,
		"vacuum|USE": _look_vacuum,
	}

func _bump() -> void:
	state["steps"] += 1
	meter.value = mini(100, state["steps"] * 4)

func _fuse() -> void:
	if state["power"]:
		_say(TX["act"]["fuseDone"]); return
	if state["cat"] != "tank":
		_say(TX["act"]["fuseNoPower"].format({"who": _who()})); return
	state["power"] = true
	_bump(); _refresh(); _say(TX["act"]["fuseOn"])

func _dryer() -> void:
	if state["taken"].has("dryer"):
		_say(TX["act"]["dryerDone"]); return
	state["taken"]["dryer"] = true
	_bump(); _refresh(); _say(TX["act"]["dryerTake"])

func _pantry() -> void:
	if state["taken"].has("tuna"):
		_say(TX["act"]["pantryDone"]); return
	if state["cat"] != "tank":
		_say(TX["act"]["pantryNo"].format({"who": _who()})); return
	state["taken"]["tuna"] = true
	_bump(); _refresh(); _say(TX["act"]["pantryOn"])

func _open_tuna() -> void:
	if state["tuna_open"]:
		_say(TX["act"]["tunaDone"]); return
	if state["cat"] != "tank":
		_say(TX["act"]["tunaNo"].format({"who": _who()})); return
	state["tuna_open"] = true
	_bump(); _build_inv(); _say(TX["act"]["tunaOn"])

func _freezer() -> void:
	if state["item"] == "tuna":
		if not state["freezer_open"]:
			_say(TX["act"]["freezerNoHeat"]); return
		if state["tuna_in"]:
			_say(TX["act"]["freezerDone"]); return
		state["tuna_in"] = true
		state["taken"].erase("tuna")
		state["item"] = ""
		_bump(); _refresh(); _say(TX["act"]["tunaIn"])
		return
	if state["freezer_open"]:
		if not state["cat_kitchen"]:
			_say(TX["act"]["freezerNoTuna"]); return
		_bump(); _win(); return
	if not state["taken"].has("dryer"):
		_say(TX["act"]["freezerNoHeat"]); return
	if not state["power"]:
		_say(TX["act"]["freezerNoPower"]); return
	state["freezer_open"] = true
	_bump(); _refresh(); _say(TX["act"]["freezerOn"])

func _vacuum() -> void:
	if state["vacuum"]:
		_say(TX["act"]["vacuumDone"]); return
	if not state["power"]:
		_say(TX["act"]["vacuumNoPower"]); return
	if state["cat"] != "wes":
		_say(TX["act"]["vacuumNo"].format({"who": _who()})); return
	state["vacuum"] = true
	_bump(); _refresh(); _say(TX["act"]["vacuumOn"])

func _calm() -> void:
	if state["cat_kitchen"]:
		_say(TX["act"]["calmDone"]); return
	if state["cat"] != "vic":
		_say(TX["act"]["calmNo"].format({"who": _who()})); return
	if not state["tuna_in"]:
		_say(TX["act"]["calmNeedTuna"]); return
	state["calmed"] = true
	state["cat_kitchen"] = true
	_bump(); _refresh(); _say(TX["act"]["calmOn"])

func _talk_beast() -> void:
	_say(TX["act"]["calmDone"] if state["cat_kitchen"] else TX["act"]["beastNotHere"])

func _look_vacuum() -> void:
	_say(TX["act"]["vacuumDone"] if state["vacuum"] else TX["act"]["vacuumNoPower"])

func _win() -> void:
	state["won"] = true
	_refresh()
	_say(TX["winLog"])
	var box := VBoxContainer.new()
	box.position = Vector2(60, 110)
	box.size = Vector2(520, 300)
	overlay.add_child(box)
	var t := Label.new()
	t.text = TX["winTitle"]
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.91, 0.71, 0.29))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for line in [TX["winText"], TX["winText2"], TX["winSteps"].format({"n": state["steps"]})]:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 14)
		box.add_child(l)
	var again := Button.new()
	again.text = TX["again"]
	again.add_theme_font_size_override("font_size", 16)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(again)

func _start(l: String) -> void:
	lang = l
	TX = _texts()
	overlay.hide()
	_refresh()
	_say(TX["intro"])

# ---------------------------------------------------------------- texts
func _texts() -> Dictionary:
	if lang == "es":
		return {
			"title": "NOCHE DEL GATO MUTANTE",
			"verbs": {"WALK": "IR", "LOOK": "MIRAR", "TAKE": "TOMAR", "USE": "USAR", "OPEN": "ABRIR", "TALK": "HABLAR"},
			"ab": {"wes": "HACKEAR", "tank": "LEVANTAR", "vic": "CALMAR"},
			"crew": {"wes": ["WES", "hackea"], "tank": ["TANK", "levanta"], "vic": ["DRA. VIC", "calma"]},
			"intro": "El departamento está tibio, el acuario brilla verde y algo del tamaño de un labrador ya se está sacando del agua.",
			"rooms": {
				"living": {"n": "LA SALA", "d": "El sofá tiene tres hundimientos y la tele muestra un menú que nadie eligió. Entre el sofá y la ventana, el acuario tirita y burbujea."},
				"hall": {"n": "EL PASILLO", "d": "Tres puertas y una franja de alfombra gastada. La caja de fusibles está alta, con la palanca abajo."},
				"kitchen": {"n": "LA COCINA", "d": "Baldosas frías, un fregadero con dos tazas y una despensa mal cerrada. El congelador ocupa la pared del fondo bajo una tapa de escarcha."},
				"bathroom": {"n": "EL BAÑO", "d": "Chico, celeste, azulejado hasta el hombro. Un espejo que evitas y un secador colgado de su cable."},
			},
			"hs": {"beast": "el gato", "tank": "acuario", "sofa": "sofá", "laptop": "la laptop", "vacuum": "la aspiradora",
				"door_hall": "pasillo", "fuse": "caja de fusibles", "door_liv": "sala", "door_kit": "cocina",
				"door_bath": "baño", "pantry": "despensa", "freezer": "congelador", "sink": "fregadero", "dryer": "secador",
				"tuna": "atún", "outlet": "enchufe", "mirror": "espejo", "tub": "bañera"},
			"look": {"beast": "Te mira como el clima mira un picnic.", "beastGone": "Se fue a la cocina.",
				"tank": "El acuario del que bebió. Vacío, verde, todavía radiactivo.", "sofa": "Tres hundimientos, uno por persona.",
				"laptop": "La laptop de Wes. Abierta y tibia.", "vacuum": "Rosie, muerta en su base.",
				"fuse": "La palanca general, abajo, fuera de alcance.", "pantry": "Latas y el atún al fondo, detrás de las lentes.",
				"freezer": "La tapa está pegada por el hielo.", "sink": "Dos tazas y un tenedor.",
				"dryer": "Un secador con la boquilla rajada.", "outlet": "Un enchufe. Muerto.", "mirror": "Tres humanos y un gato de más.",
				"tub": "Seca. El gato está prohibido desde que dejó de entrar.", "door": "Una puerta."},
			"act": {"fuseNoPower": "{who} estira el brazo. La caja está un palmo más arriba.",
				"fuseOn": "Tank engancha la palanca y la baja tirando. Vuelve la luz.",
				"fuseDone": "La palanca ya está abajo.", "dryerTake": "Vic desenchufa el secador y te lo alcanza.",
				"dryerDone": "Ya lo tienes.", "pantryNo": "{who} se apoya en la puerta. Las lentes ganan.",
				"pantryOn": "Tank le pone el hombro y la lata de atún rueda afuera.", "pantryDone": "El atún ya está afuera.",
				"tunaNo": "{who} raspa la anilla con la uña. La lata no se abre.",
				"tunaOn": "Tank gira la anilla y la lata salta. El olor llega antes que el ruido.", "tunaDone": "Ya está abierta.",
				"freezerNoHeat": "Al hielo le dan igual las uñas. Necesita calor: el secador del baño.",
				"freezerNoPower": "El secador está muerto. No hay luz.", "freezerOn": "Vic apunta el secador. La escarcha se raja y la tapa cae.",
				"freezerNoTuna": "Abierto y frío, pero el gato sigue en el otro cuarto.",
				"freezerDone": "Ya está adentro.", "tunaIn": "Tank tira el atún dentro. Algo enorme deja de caminar para olfatear.",
				"vacuumNoPower": "La laptop está muerta sin luz.", "vacuumNo": "{who} aprieta teclas al azar. Wes sabe la secuencia.",
				"vacuumOn": "Wes escribe algo absurdo. Rosie arranca a dar vueltas.", "vacuumDone": "Rosie da vueltas.",
				"calmNo": "{who} se acerca. El gato levanta una pata del tamaño de un plato.",
				"calmNeedTuna": "Vic parpadea lento. El gato no va a ir sin motivo: primero el atún.",
				"calmOn": "Vic parpadea lento y el gato camina hacia el olor, a la cocina.", "calmDone": "Ya está en la cocina.",
				"talk": "{who} dice algo razonable.", "nothing": "{who} prueba con {what}. Nada.",
				"beastNotHere": "El gato no está en este cuarto."},
			"hints": ["No hay luz. La caja de fusibles está en el pasillo, alta: Tank levanta.",
				"El secador está en el baño. Tómalo.", "Apunta el secador al burlete del congelador.",
				"Tank puede abrir la despensa. Y la lata.", "Pon el atún abierto dentro del congelador abierto.",
				"Wes puede despertar a Rosie desde la laptop.", "Vic puede calmar al gato, pero solo con el atún adentro.",
				"El gato está en la cocina. Usa el congelador para bajar la tapa."],
			"winTitle": "GATO, CONGELADO",
			"winText": "La tapa baja. Rosie la choca, leal y tonta. Adentro, una forma enorme se pone rígida.",
			"winText2": "Ustedes tres se sientan en las baldosas a mirar cómo la escarcha vuelve a subir.",
			"winSteps": "Resuelto en {n} acciones.", "again": "JUGAR OTRA VEZ",
			"winLog": "La tapa baja sobre un gato enorme.",
		}
	return {
		"title": "NIGHT OF THE MUTANT CAT",
		"verbs": {"WALK": "WALK", "LOOK": "LOOK", "TAKE": "TAKE", "USE": "USE", "OPEN": "OPEN", "TALK": "TALK"},
		"ab": {"wes": "HACK", "tank": "LIFT", "vic": "CALM"},
		"crew": {"wes": ["WES", "hacks"], "tank": ["TANK", "lifts"], "vic": ["DR. VIC", "calms"]},
		"intro": "The flat is warm, the tank glows green, and something the size of a labrador is already pulling itself out of the water.",
		"rooms": {
			"living": {"n": "THE LIVING ROOM", "d": "Three dents in the sofa and a menu nobody chose on the television. Between the sofa and the window, the tank ticks."},
			"hall": {"n": "THE HALLWAY", "d": "Three doors and a strip of carpet worn into a path. The fuse box sits high, breaker down."},
			"kitchen": {"n": "THE KITCHEN", "d": "Cold tiles, two mugs in the sink and a pantry that has not shut properly since spring. The freezer squats under a lid of frost."},
			"bathroom": {"n": "THE BATHROOM", "d": "Small, blue, tiled to shoulder height. A mirror you avoid and a hair dryer hanging by its own cable."},
		},
		"hs": {"beast": "the cat", "tank": "fish tank", "sofa": "sofa", "laptop": "Wes's laptop", "vacuum": "robot vacuum",
			"door_hall": "hallway", "fuse": "fuse box", "door_liv": "living room", "door_kit": "kitchen",
			"door_bath": "bathroom", "pantry": "pantry", "freezer": "freezer", "sink": "sink", "dryer": "hair dryer",
			"tuna": "tuna", "outlet": "wall outlet", "mirror": "mirror", "tub": "bathtub"},
		"look": {"beast": "It watches you the way weather watches a picnic.", "beastGone": "Gone into the kitchen.",
			"tank": "The tank it drank from. Empty, green, faintly radioactive.", "sofa": "Three dents, one per person.",
			"laptop": "Wes's laptop. Open and warm.", "vacuum": "Rosie, dead on her dock.",
			"fuse": "The main breaker, down, a hand's width too high.", "pantry": "Tins and the tuna at the back, behind the lentils.",
			"freezer": "The lid is iced shut.", "sink": "Two mugs and a fork.",
			"dryer": "A hair dryer with a cracked nozzle.", "outlet": "A socket. Dead.", "mirror": "Three humans, one cat too many.",
			"tub": "Dry. The cat is banned since it stopped fitting.", "door": "A door."},
		"act": {"fuseNoPower": "{who} reaches up. Fingertips find air.",
			"fuseOn": "Tank hooks the breaker and drags it down. The lights come back.",
			"fuseDone": "The breaker is already down.", "dryerTake": "Vic unplugs the dryer and hands it over.",
			"dryerDone": "Already holding it.", "pantryNo": "{who} leans on the door. The lentils win.",
			"pantryOn": "Tank puts a shoulder in and a tin of tuna rolls out.", "pantryDone": "The tuna is already out.",
			"tunaNo": "{who} picks at the ring pull. The tin stays shut.",
			"tunaOn": "Tank twists the ring and the tin pops. The smell arrives first.", "tunaDone": "Already open.",
			"freezerNoHeat": "The ice needs heat, not nails. The hair dryer, from the bathroom.",
			"freezerNoPower": "The dryer is dead. There's no power.", "freezerOn": "Vic aims the dryer. The frost cracks and the lid drops.",
			"freezerNoTuna": "Open and cold, but the cat is still in the other room.",
			"freezerDone": "Already in there.", "tunaIn": "Tank drops the tuna in. Something enormous stops to sniff.",
			"vacuumNoPower": "The laptop is dead without power.", "vacuumNo": "{who} presses keys at random. Wes knows the sequence.",
			"vacuumOn": "Wes types something absurd. Rosie rolls off the dock.", "vacuumDone": "Rosie is circling.",
			"calmNo": "{who} approaches. The cat lifts a paw the size of a dinner plate.",
			"calmNeedTuna": "Vic slow-blinks. It isn't going anywhere without a reason. The tuna first.",
			"calmOn": "Vic slow-blinks and the cat walks toward the smell, into the kitchen.", "calmDone": "It's in the kitchen already.",
			"talk": "{who} says something reasonable.", "nothing": "{who} tries the {what}. Nothing gives.",
			"beastNotHere": "The cat isn't in this room."},
		"hints": ["No power. The fuse box is in the hallway, too high for anyone but Tank.",
			"The hair dryer is in the bathroom. Take it.", "Aim the hair dryer at the freezer seal.",
			"Tank can open the pantry. And the tin.", "Put the open tuna in the open freezer.",
			"Wes can wake Rosie from the laptop.", "Vic can calm the cat, but only once the tuna is in.",
			"The cat is in the kitchen. Use the freezer to bring the lid down."],
		"winTitle": "CAT, FROZEN",
		"winText": "The lid comes down. Rosie bumps into it, loyal and stupid. Inside, an enormous shape goes stiff.",
		"winText2": "The three of you sit on the tiles to watch the frost crawl back across the lid.",
		"winSteps": "Done in {n} actions.", "again": "PLAY AGAIN",
		"winLog": "The lid comes down on a very large cat.",
	}

# ---------------------------------------------------------------- start screen
func _show_start() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	overlay.add_child(box)
	var t := Label.new()
	t.text = "NIGHT OF THE MUTANT CAT"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.91, 0.71, 0.29))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var p := Label.new()
	p.text = "Three flatmates. One cat that drank from the fish tank.\n\nWES hacks  ·  TANK lifts  ·  DR. VIC calms"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_font_size_override("font_size", 14)
	box.add_child(p)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for pair in [["PLAY IN ENGLISH", "en"], ["JUGAR EN ESPAÑOL", "es"]]:
		var b := Button.new()
		b.text = pair[0]
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func(): box.queue_free(); _start(pair[1]))
		row.add_child(b)
