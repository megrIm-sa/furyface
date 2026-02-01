# res://resources/weapons/revolver_resource.gd
class_name RevolverResource
extends WeaponResource

@export_group("Revolver Specific")
@export var bullet_speed: float = 800.0
@export var max_ammo_per_gun: int = 6
@export var reload_beats: float = 2.0
@export var bullet_lifetime: float = 2.0

@export_group("Effects")
@export var muzzle_flash_color: Color = Color(1.0, 0.9, 0.6, 1.0)
@export var bullet_trail_color: Color = Color(0.8, 0.9, 1.0, 0.5)
@export var bullet_trail_length: float = 30.0
