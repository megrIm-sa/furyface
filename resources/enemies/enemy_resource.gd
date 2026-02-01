class_name EnemyResource
extends Resource

@export_group("Basic Stats")
@export var enemy_name: String = "Enemy"
@export var max_health: float = 50.0
@export var move_speed: float = 80.0
@export var damage: float = 10.0

@export_group("Combat")
@export var attack_range: float = 60.0
@export var attack_arc: float = 60.0  # Угол атаки в градусах
@export var detection_range: float = 400.0
@export var windup_beats: int = 1  # Сколько битов замах

@export_group("Attack Shape")
@export_enum("Circle", "Rectangle") var attack_shape: String = "Circle"
@export var attack_width: float = 60.0   # Ширина прямоугольника
@export var attack_length: float = 100.0  # Длина прямоугольника (дальность)

@export_group("Knockback")
@export var knockback_force: float = 150.0
@export var knockback_resistance: float = 1.0  # Множитель получаемого knockback

@export_group("Visual")
@export var sprite: Texture2D
@export var scale_size: float = 1.0

@export_group("Audio")
@export var hit_sound: AudioStream
@export var attack_sound: AudioStream
@export var death_sound: AudioStream
