extends Node2D
## Infinite procedural world: ocean, lakes, sand, grass, trees, rocks.
## Attach to the "World" node (needs child nodes "Terrain" and "Objects").

@export var player: Node2D
@export var tree_textures: Array[Texture2D] = []
@export var rock_textures: Array[Texture2D] = []
@export var world_seed := 0            # 0 = random every run
@export var tile_size := 16            # pixels per tile in the world
@export var chunk_tiles := 32          # tiles per chunk side
@export_range(1, 6) var view_distance := 3   # chunks around the player

@export_group("Terrain")
# Lower values = less water. Raise them for more ocean/lakes.
@export var deep_level := -0.30
@export var shallow_level := -0.18
@export var sand_level := -0.10

@export_group("Objects")
@export_range(0.0, 0.2) var tree_density := 0.06
@export_range(0.0, 0.2) var rock_density := 0.012

@export_group("Enemies")
@export var enemy_texture: Texture2D   # optional, a red box is used if empty
@export_range(0.0, 0.02) var enemy_density := 0.002
@export var enemy_health := 3
@export var enemy_speed := 45.0

enum Tile { DEEP, SHALLOW, SAND, GRASS }

const ENEMY_SCRIPT := preload("res://enemy.gd")

const COLORS := {
	Tile.DEEP: Color("1f4e8c"),
	Tile.SHALLOW: Color("3a7bc8"),
	Tile.SAND: Color("e0cf8e"),
	Tile.GRASS: Color("5da13c"),
}

@onready var terrain_root: Node2D = $Terrain
@onready var objects_root: Node2D = $Objects

var _detail := FastNoiseLite.new()     # small hills / lakes
var _continent := FastNoiseLite.new()  # big shapes -> oceans
var _forest := FastNoiseLite.new()     # where trees cluster

var chunks := {}                       # Vector2i -> { "terrain": Sprite2D, "objects": Array }
var _queue: Array[Vector2i] = []
var _last_chunk := Vector2i(999999, 999999)
var _spawn_pos := Vector2.ZERO


func _ready() -> void:
	if world_seed == 0:
		world_seed = randi()

	_detail.seed = world_seed
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.02
	_detail.fractal_octaves = 4

	_continent.seed = world_seed + 1
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent.frequency = 0.004

	_forest.seed = world_seed + 2
	_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest.frequency = 0.05

	terrain_root.z_index = -10            # terrain always behind everything
	objects_root.y_sort_enabled = true    # trees, enemies and player overlap by height

	_spawn_pos = _find_land(Vector2.ZERO)
	if player:
		player.global_position = _spawn_pos


func _process(_delta: float) -> void:
	if player == null:
		return
	var pc := _chunk_of(player.global_position)
	if pc != _last_chunk:
		_last_chunk = pc
		_refresh(pc)
	_build_next()  # one chunk per frame keeps movement smooth


# ---------- public helpers (use these from your player / enemies) ----------

func is_deep_water_at(world_pos: Vector2) -> bool:
	return _tile_kind(_tile_of(world_pos)) == Tile.DEEP


func is_water_at(world_pos: Vector2) -> bool:
	var k := _tile_kind(_tile_of(world_pos))
	return k == Tile.DEEP or k == Tile.SHALLOW


# ---------- world sampling ----------

func _height(t: Vector2i) -> float:
	return _detail.get_noise_2d(t.x, t.y) * 0.55 + _continent.get_noise_2d(t.x, t.y) * 0.75


func _tile_kind(t: Vector2i) -> Tile:
	var h := _height(t)
	if h < deep_level:
		return Tile.DEEP
	if h < shallow_level:
		return Tile.SHALLOW
	if h < sand_level:
		return Tile.SAND
	return Tile.GRASS


func _tile_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


func _chunk_of(world_pos: Vector2) -> Vector2i:
	var px := float(chunk_tiles * tile_size)
	return Vector2i(floori(world_pos.x / px), floori(world_pos.y / px))


func _find_land(origin: Vector2) -> Vector2:
	# Walk outward in a spiral until we hit grass.
	for r in range(0, 400, 2):
		for i in 16:
			var a := TAU * i / 16.0
			var p := origin + Vector2(cos(a), sin(a)) * r * tile_size
			if _tile_kind(_tile_of(p)) == Tile.GRASS:
				return p
	return origin


# ---------- chunk management ----------

func _refresh(pc: Vector2i) -> void:
	# Queue missing chunks near the player
	for dy in range(-view_distance, view_distance + 1):
		for dx in range(-view_distance, view_distance + 1):
			var c := pc + Vector2i(dx, dy)
			if not chunks.has(c) and not _queue.has(c):
				_queue.append(c)
	# Closest chunks first
	_queue.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(pc) < b.distance_squared_to(pc))

	# Unload far chunks
	var limit := view_distance + 1
	for c in chunks.keys():
		if maxi(absi(c.x - pc.x), absi(c.y - pc.y)) > limit:
			_free_chunk(c)


func _build_next() -> void:
	if _queue.is_empty():
		return
	var c: Vector2i = _queue.pop_front()
	if not chunks.has(c):
		_build_chunk(c)


func _free_chunk(c: Vector2i) -> void:
	var data: Dictionary = chunks[c]
	data["terrain"].queue_free()
	for o in data["objects"]:
		if is_instance_valid(o):
			o.queue_free()
	chunks.erase(c)


func _build_chunk(c: Vector2i) -> void:
	var img := Image.create_empty(chunk_tiles, chunk_tiles, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, world_seed))  # same chunk = same result, always

	var objects: Array = []
	var origin_tile := c * chunk_tiles

	for y in chunk_tiles:
		for x in chunk_tiles:
			var t := origin_tile + Vector2i(x, y)
			var kind := _tile_kind(t)

			# colour with a tiny random shade so it looks pixel-art-ish
			var col: Color = COLORS[kind]
			var k := 1.0 + rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, Color(col.r * k, col.g * k, col.b * k))

			# objects
			var pos := Vector2(t * tile_size) + Vector2(rng.randf() * tile_size, rng.randf() * tile_size)
			if kind == Tile.GRASS and player != null and enemy_density > 0.0 \
					and pos.distance_to(_spawn_pos) > 200.0 and rng.randf() < enemy_density:
				objects.append(_spawn_enemy(pos))
				continue
			if kind == Tile.GRASS and not tree_textures.is_empty():
				var f := _forest.get_noise_2d(t.x, t.y)
				if f > -0.1 and rng.randf() < tree_density * (1.0 + f * 2.0):
					objects.append(_spawn_object(tree_textures, pos, rng))
					continue
			if (kind == Tile.GRASS or kind == Tile.SAND) and not rock_textures.is_empty():
				if rng.randf() < rock_density:
					objects.append(_spawn_object(rock_textures, pos, rng))

	# terrain: one sprite per chunk, 1 pixel = 1 tile, scaled up
	var terrain := Sprite2D.new()
	terrain.texture = ImageTexture.create_from_image(img)
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain.centered = false
	terrain.scale = Vector2(tile_size, tile_size)
	terrain.position = Vector2(origin_tile * tile_size)
	terrain_root.add_child(terrain)

	chunks[c] = {"terrain": terrain, "objects": objects}


func _spawn_object(textures: Array[Texture2D], pos: Vector2, rng: RandomNumberGenerator) -> Sprite2D:
	var tex: Texture2D = textures[rng.randi() % textures.size()]
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height())  # bottom-center = "feet", whole pixels
	s.position = pos.round()
	objects_root.add_child(s)  # Objects is y-sorted, so trees overlap the player correctly
	return s


func _spawn_enemy(pos: Vector2) -> Node2D:
	var e = ENEMY_SCRIPT.new()   # untyped on purpose: we set script variables below
	e.player = player
	e.world = self
	e.texture = enemy_texture
	e.health = enemy_health
	e.speed = enemy_speed
	e.position = pos.round()
	objects_root.add_child(e)
	return e
