extends CharacterBody2D
## Player: moves, swings a sword, has health.
## Works even if the scene has no sprite: a blue placeholder body is drawn instead.

@export var speed := 120.0
@export var max_health := 5
@export var world: Node2D              # optional: found automatically if player is under Objects under World
@export var player_texture: Texture2D  # optional: drag your player sprite here (used if the Sprite2D is empty)

@export_group("Sword")
@export var sword_texture: Texture2D   # draw it pointing RIGHT, handle on the left edge
@export var sword_damage := 1
@export var sword_range := 40.0
@export var sword_arc_degrees := 140.0
@export var attack_cooldown := 0.35

var health := 0
var _facing := Vector2.DOWN
var _attack_cd := 0.0
var _invuln := 0.0
var _sword: Node2D
var _swing_tween: Tween
var _hp_label: Label
var _has_sprite := false


func _ready() -> void:
	health = max_health
	if world == null:
		world = get_parent().get_parent()

	# make sure nothing is accidentally hiding us
	visible = true
	modulate = Color.WHITE
	show_behind_parent = false

	_setup_sprite()
	_setup_camera()
	_build_sword()
	_build_hud()
	queue_redraw()


# ---------- setup ----------

func _setup_sprite() -> void:
	var sprite: Sprite2D = null
	for child in get_children():
		if child is Sprite2D:
			sprite = child
			break

	if sprite == null and player_texture != null:
		sprite = Sprite2D.new()
		add_child(sprite)

	if sprite != null:
		if sprite.texture == null:
			sprite.texture = player_texture
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.show_behind_parent = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sprite.scale.length() < 0.01:
			sprite.scale = Vector2.ONE
		_has_sprite = sprite.texture != null


func _setup_camera() -> void:
	var cam: Camera2D = null
	for child in get_children():
		if child is Camera2D:
			cam = child
			break
	if cam == null:
		cam = Camera2D.new()
		add_child(cam)
	cam.enabled = true
	cam.position_smoothing_enabled = false
	cam.make_current()


func _draw() -> void:
	if _has_sprite:
		return
	# placeholder body: blue box with a lighter head, feet at (0, 0)
	draw_rect(Rect2(-6, -14, 12, 14), Color("2e86de"))
	draw_rect(Rect2(-5, -20, 10, 8), Color("ffd8a8"))


# ---------- game loop ----------

func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)

	# WASD or arrow keys
	var dir := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	)
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		_facing = dir
	var motion := dir * speed * delta

	# Block deep water (shallow is walkable); per axis so you slide along shores
	if world:
		if world.is_deep_water_at(global_position + Vector2(motion.x, 0)):
			motion.x = 0
		if world.is_deep_water_at(global_position + Vector2(0, motion.y)):
			motion.y = 0

	global_position += motion


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var d := get_global_mouse_position() - global_position
		_attack(d.normalized() if d.length() > 1.0 else _facing)   # click = swing toward mouse
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_attack(_facing)                                           # space = swing the way you walk


# ---------- combat ----------

func _attack(dir: Vector2) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown
	_facing = dir
	_play_swing(dir.angle())

	var half_arc := cos(deg_to_rad(sword_arc_degrees / 2.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector2 = e.global_position - global_position
		var d := to_e.length()
		if d <= sword_range and (d < 8.0 or dir.dot(to_e / d) >= half_arc):
			e.take_damage(sword_damage, global_position)


func take_damage(amount: int, _from_pos: Vector2) -> void:
	if _invuln > 0.0:
		return
	health -= amount
	_invuln = 0.8
	_update_hud()
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)
	if health <= 0:
		get_tree().reload_current_scene.call_deferred()   # restart on death


func _play_swing(angle: float) -> void:
	if _swing_tween:
		_swing_tween.kill()
	_sword.visible = true
	_sword.rotation = angle - 1.2
	_swing_tween = create_tween()
	_swing_tween.tween_property(_sword, "rotation", angle + 1.2, 0.15)
	_swing_tween.tween_callback(func(): _sword.visible = false)


func _build_sword() -> void:
	_sword = Node2D.new()
	_sword.visible = false
	_sword.position = Vector2(0, -8)   # swing from about chest height
	_sword.z_index = 1
	add_child(_sword)
	if sword_texture:
		var s := Sprite2D.new()
		s.texture = sword_texture
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.offset = Vector2(0, -sword_texture.get_height() / 2.0)
		_sword.add_child(s)
	else:
		var p := Polygon2D.new()   # placeholder blade until you add a sprite
		p.polygon = PackedVector2Array([Vector2(4, -2), Vector2(26, -2), Vector2(32, 0), Vector2(26, 2), Vector2(4, 2)])
		p.color = Color("d9e2ec")
		_sword.add_child(p)


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hp_label = Label.new()
	_hp_label.position = Vector2(8, 8)
	layer.add_child(_hp_label)
	_update_hud()


func _update_hud() -> void:
	_hp_label.text = "HP: %d / %d" % [maxi(health, 0), max_health]
