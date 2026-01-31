class_name WeaponResource
extends Resource

@export_group("Basic Stats")
@export var weapon_name: String = "Weapon"
@export var weapon_type: Enums.WeaponType
@export var base_damage: float = 10.0
@export var attack_cooldown: float = 0.5
@export var range: float = 100.0

@export_group("Visual")
@export var icon: Texture2D
@export var attack_animation: String = "attack"

@export_group("Audio")
@export var attack_sound: AudioStream
@export var hit_sound: AudioStream

@export_group("Upgrade Branches")
@export var branch_1_name: String = "Branch 1"
@export var branch_2_name: String = "Branch 2"
@export var max_upgrade_level: int = 5
