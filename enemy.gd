extends Node2D
## Simple chasing enemy. world.gd creates these, you don't place them by hand.

var player = null
var world = null
var texture: Texture2D
var speed := 45.0
var health := 3
var touch_damage := 1
var aggro_range := 160.0   # starts chasing inside this distance
var touch_range := 14.0    # hurts the player inside this distance

var _visual: CanvasItem
var _knockback := Vector2.ZERO
var _wander_dir := Vector2.ZERO
var _wander_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	if texture:
		var s := Sprite2D.new()
		s.texture = texture
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.offset = Vector2(-floorf(texture.get_width() / 2.0), -texture.get_height())  # feet at origin
		add_child(s)
		_visual = s
	else:
		var p := Polygon2D.new()   # placeholder red box until you add a sprite
		p.polygon = PackedVector2Array([Vector2(-6, -12), Vector2(6, -12), Vector2(6, 0), Vector2(-6, 0)])
		p.color = Color("c0392b")
		add_child(p)
		_visual = p


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var vel := Vector2.ZERO

	if dist < aggro_range:
		vel = to_player.normalized() * speed
	else:
		_wander_time -= delta
		if _wander_time <= 0.0:
			_wander_time = randf_range(1.0, 3.0)
			_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
		vel = _wander_dir * speed * 0.4

	vel += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	_move(vel * delta)

	if dist < touch_range:
		player.take_damage(touch_damage, global_position)


func _move(m: Vector2) -> void:
	# enemies stay out of water (both lakes and ocean)
	if world:
		if world.is_water_at(global_position + Vector2(m.x, 0)):
			m.x = 0
		if world.is_water_at(global_position + Vector2(0, m.y)):
			m.y = 0
	global_position += m


func take_damage(amount: int, from_pos: Vector2) -> void:
	health -= amount
	_knockback = (global_position - from_pos).normalized() * 220.0
	_visual.modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.2)
	if health <= 0:
		queue_free()
