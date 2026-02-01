# res://scripts/projectiles/fear_projectile.gd
class_name FearProjectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: float = 15.0
var lifetime: float = 5.0

var sprite: Sprite2D
var collision: CollisionShape2D

func _ready():
	# Создаем визуал
	sprite = Sprite2D.new()
	sprite.modulate = Color(0.8, 0.4, 1.0, 0.8)
	# Установите вашу текстуру снаряда
	add_child(sprite)
	
	# Создаем коллизию
	collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	add_child(collision)
	
	collision_layer = 4  # Слой врагов/снарядов
	collision_mask = 1  # Слой игрока
	
	body_entered.connect(_on_body_entered)
	
	# Автоудаление
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float):
	global_position += direction * speed * delta
	
	# Вращение снаряда
	if sprite:
		sprite.rotation += delta * 5.0

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position, direction * 200.0)
		queue_free()
