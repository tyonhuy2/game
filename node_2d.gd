extends Node2D

const WORLD_SIZE = 2000
const TREE_COUNT = 100
const ROCK_COUNT = 50

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	generate_world()

func generate_world():
	# Grass background
	var ground = ColorRect.new()
	ground.color = Color("#579447")
	ground.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	ground.position = Vector2(-WORLD_SIZE / 2, -WORLD_SIZE / 2)
	add_child(ground)
	ground.z_index = -10

	# Random grass decorations
	for i in range(400):
		var grass = Polygon2D.new()
		var x = rng.randf_range(-WORLD_SIZE/2, WORLD_SIZE/2)
		var y = rng.randf_range(-WORLD_SIZE/2, WORLD_SIZE/2)

		grass.polygon = PackedVector2Array([
			Vector2(x, y),
			Vector2(x + 4, y - 8),
			Vector2(x + 8, y)
		])
		grass.color = Color("#80b95b")
		grass.z_index = -5
		add_child(grass)

	# Trees
	for i in range(TREE_COUNT):
		create_tree(Vector2(
			rng.randf_range(-900, 900),
			rng.randf_range(-900, 900)
		))

	# Rocks
	for i in range(ROCK_COUNT):
		create_rock(Vector2(
			rng.randf_range(-900, 900),
			rng.randf_range(-900, 900)
		))

	# Pond
	create_pond(Vector2(300, 200))


func create_tree(pos):
	var tree = StaticBody2D.new()
	tree.position = pos
	add_child(tree)

	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-8, 0),
		Vector2(8, 0),
		Vector2(6, 25),
		Vector2(-6, 25)
	])
	trunk.color = Color("#754522")
	tree.add_child(trunk)

	var leaves = Polygon2D.new()
	leaves.polygon = PackedVector2Array([
		Vector2(-25, 5),
		Vector2(-18, -20),
		Vector2(0, -35),
		Vector2(20, -20),
		Vector2(27, 5),
		Vector2(15, 15),
		Vector2(-15, 15)
	])
	leaves.color = Color("#246b35")
	tree.add_child(leaves)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	collision.position = Vector2(0, 15)
	tree.add_child(collision)


func create_rock(pos):
	var rock = Polygon2D.new()
	rock.position = pos
	rock.polygon = PackedVector2Array([
		Vector2(-12, 5),
		Vector2(-8, -8),
		Vector2(5, -12),
		Vector2(14, -2),
		Vector2(10, 8),
		Vector2(-5, 12)
	])
	rock.color = Color("#858585")
	add_child(rock)


func create_pond(pos):
	var water = Polygon2D.new()
	water.position = pos
	water.polygon = PackedVector2Array([
		Vector2(-130, -70),
		Vector2(-80, -110),
		Vector2(20, -100),
		Vector2(110, -60),
		Vector2(130, 10),
		Vector2(70, 80),
		Vector2(-40, 90),
		Vector2(-120, 35)
	])
	water.color = Color("#318dc4")
	add_child(water)
	
	
	
	
