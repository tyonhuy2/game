extends Node2D
## The castle. world.gd creates it; kill it to win.
## Its health lives in world.gd, so it keeps its damage if you walk away and come back.

var world = null
var texture: Texture2D
var max_health := 100
var health := 100

var hit_radius := 48.0   # the sword can hit anywhere within this distance of the castle's middle
var _w := 96.0
var _h := 72.0


func _ready() -> void:
	add_to_group("enemies")   # reuse the player's sword code
	if texture:
		var s := Sprite2D.new()
		s.texture = texture
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.offset = Vector2(-floorf(texture.get_width() / 2.0), -texture.get_height())  # bottom-center at origin
		add_child(s)
		_w = texture.get_width()
		_h = texture.get_height()
	hit_radius = _w * 0.5
	queue_redraw()


func get_hit_center() -> Vector2:
	return global_position + Vector2(0, -_h * 0.5)


func take_damage(amount: int, _from_pos: Vector2) -> void:
	health = world.damage_castle(amount)
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	queue_redraw()
	if health <= 0:
		queue_free()


func _draw() -> void:
	if texture == null:
		# placeholder castle until you add a sprite
		draw_rect(Rect2(-48, -48, 96, 48), Color("8d8f94"))     # wall
		draw_rect(Rect2(-56, -72, 24, 72), Color("6f7176"))     # left tower
		draw_rect(Rect2(32, -72, 24, 72), Color("6f7176"))      # right tower
		for i in 3:
			draw_rect(Rect2(-56 + i * 10, -80, 6, 8), Color("6f7176"))   # battlements, left
			draw_rect(Rect2(32 + i * 10, -80, 6, 8), Color("6f7176"))    # battlements, right
		draw_rect(Rect2(-9, -26, 18, 26), Color("5b3a1e"))      # door
	# health bar
	var bar_y := -_h - 22.0
	draw_rect(Rect2(-32, bar_y, 64, 6), Color("2c2c2c"))
	draw_rect(Rect2(-32, bar_y, 64.0 * clampf(float(health) / float(max_health), 0.0, 1.0), 6), Color("e74c3c"))
