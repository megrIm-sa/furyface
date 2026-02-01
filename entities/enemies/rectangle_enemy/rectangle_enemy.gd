# res://scripts/enemies/rectangle_enemy.gd
class_name RectangleEnemy
extends Enemy

@export var debug_draw: bool = true
@export var telegraph_color_start: Color = Color(1, 1, 0, 0.3)  # Желтый
@export var telegraph_color_end: Color = Color(1, 0, 0, 0.6)    # Красный
@export var pulse_scale_min: float = 0.95
@export var pulse_scale_max: float = 1.05

var attack_windup_start_beat: int = -1
var attack_direction: Vector2 = Vector2.ZERO  # Направление атаки (фиксируется)
var current_pulse_scale: float = 1.0
var telegraph_node: Node2D = null
var attack_strike_performed: bool = false

# Ударная волна
var shockwave_progress: float = 0.0  # От 0 до 1
var shockwave_alpha: float = 0.0
var is_shockwave_active: bool = false

func _on_ready():
	# Создаем узел для визуализации telegraph
	telegraph_node = Node2D.new()
	telegraph_node.name = "Telegraph"
	add_child(telegraph_node)
	telegraph_node.visible = false
	
	# Запускаем начальную анимацию
	if anim and anim.has_animation("idle"):
		anim.play("idle")

func _process_state(delta: float):
	if not enemy_data:
		return
	
	match state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK_WINDUP:
			_state_attack_windup(delta)
		State.ATTACK_STRIKE:
			_state_attack_strike(delta)
	
	_update_animation()

func _state_idle(delta: float):
	stop_moving(delta)
	
	if target and is_target_in_range(enemy_data.detection_range):
		change_state(State.CHASE)

func _state_chase(delta: float):
	if not target:
		change_state(State.IDLE)
		return
	
	# Затухание knockback
	if velocity.length() > enemy_data.move_speed:
		velocity = velocity.move_toward(velocity.normalized() * enemy_data.move_speed, 500.0 * delta)
	
	if not is_target_in_range(enemy_data.detection_range * 1.5):
		change_state(State.IDLE)
		return
	
	# Проверяем дистанцию для атаки (используем attack_length)
	var distance = get_distance_to_target()
	if distance <= enemy_data.attack_length:
		stop_moving(delta)
	else:
		move_towards_target(delta)

func _state_attack_windup(delta: float):
	stop_moving(delta)
	
	var beats_passed = int(floor(current_beat)) - attack_windup_start_beat
	
	# Пульсация каждый бит
	var beat_progress = get_beat_progress()
	current_pulse_scale = lerp(pulse_scale_max, pulse_scale_min, beat_progress)
	
	# Синхронизируем кадры анимации с битами
	if anim and anim.has_animation("attack"):
		var animation_time = beats_passed * 0.1 + beat_progress * 0.1
		
		if anim.current_animation != "attack":
			anim.play("attack")
		
		if beats_passed < enemy_data.windup_beats:
			anim.pause()
			anim.seek(animation_time, true)
	
	# После windup_beats переходим к удару
	if beats_passed >= enemy_data.windup_beats and not attack_strike_performed:
		_perform_strike()

func _state_attack_strike(delta: float):
	stop_moving(delta)
	
	# Ждем завершения анимации атаки
	if anim and anim.is_playing() and anim.current_animation == "attack":
		return
	
	change_state(State.CHASE)

func _on_beat(beat: int):
	match state:
		State.CHASE:
			# Проверяем дистанцию для атаки
			var distance = get_distance_to_target()
			if distance <= enemy_data.attack_length:
				_start_attack_windup(beat)
		
		State.ATTACK_WINDUP:
			_pulse_telegraph()
			print("Rectangle windup pulse on beat ", beat, " (beat ", beat - attack_windup_start_beat + 1, " of ", enemy_data.windup_beats, ")")

func _start_attack_windup(beat: int):
	attack_windup_start_beat = beat
	current_pulse_scale = pulse_scale_max
	attack_strike_performed = false
	
	# Фиксируем направление атаки
	attack_direction = get_direction_to_target()
	
	change_state(State.ATTACK_WINDUP)
	attack_started.emit()
	
	# Показываем telegraph
	if telegraph_node:
		telegraph_node.visible = true
	
	# Начинаем анимацию attack
	if anim and anim.has_animation("attack"):
		anim.play("attack")
		anim.pause()
		anim.seek(0.0, true)
	
	print("Rectangle enemy starting attack on beat ", beat)

func _pulse_telegraph():
	"""Визуальная пульсация на каждый бит"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "current_pulse_scale", pulse_scale_max, 0.1)
	tween.tween_property(self, "current_pulse_scale", pulse_scale_min, 0.3)
	
	queue_redraw()

func _perform_strike():
	"""Выполняет удар"""
	if attack_strike_performed:
		return
	
	attack_strike_performed = true
	change_state(State.ATTACK_STRIKE)
	
	# Скрываем telegraph
	if telegraph_node:
		telegraph_node.visible = false
	
	# Проверяем попадание в прямоугольной зоне
	_check_rectangle_attack_hit()
	
	# Продолжаем анимацию с момента удара
	if anim and anim.has_animation("attack"):
		anim.play("attack")
		anim.seek(0.4, true)
	
	# Запускаем ударную волну
	_start_shockwave()
	
	print("Rectangle enemy performed strike!")

func _draw():
	if not debug_draw or not enemy_data or state == State.DEAD:
		return
	
	# Во время замаха рисуем прямоугольную зону атаки
	if state == State.ATTACK_WINDUP:
		var beats_passed = (current_beat - attack_windup_start_beat)
		var progress = beats_passed / enemy_data.windup_beats
		
		# Интерполяция цвета
		var color = telegraph_color_start.lerp(telegraph_color_end, progress)
		
		# Применяем пульсацию
		var pulsing_width = enemy_data.attack_width * current_pulse_scale
		var pulsing_length = enemy_data.attack_length * current_pulse_scale
		
		# Вычисляем угол направления
		var angle = attack_direction.angle()
		var half_width = pulsing_width * 0.5
		
		# ИСПРАВЛЕНО: Строим прямоугольник вдоль оси X (не Y)
		# Длина идет вдоль X (от 0 до pulsing_length)
		# Ширина распределена по Y (от -half_width до +half_width)
		var local_corners = [
			Vector2(0, -half_width),              # Ближний левый
			Vector2(0, half_width),               # Ближний правый
			Vector2(pulsing_length, half_width),  # Дальний правый
			Vector2(pulsing_length, -half_width)  # Дальний левый
		]
		
		# Поворачиваем углы в направлении атаки
		var world_corners = []
		for corner in local_corners:
			var rotated = corner.rotated(angle)
			world_corners.append(rotated)
		
		# Рисуем заполненный прямоугольник
		draw_colored_polygon(PackedVector2Array(world_corners), color)
		
		# Рисуем контур
		for i in range(4):
			var start = world_corners[i]
			var end = world_corners[(i + 1) % 4]
			draw_line(start, end, Color(color.r, color.g, color.b, 1.0), 3.0)
	
	# Во время удара рисуем ударную волну
	if is_shockwave_active and shockwave_progress > 0.0:
		var angle = attack_direction.angle()
		var half_width = enemy_data.attack_width * 0.5
		
		# Волна движется от врага вперед
		var wave_length = enemy_data.attack_length * shockwave_progress
		var wave_thickness = enemy_data.attack_length * 0.15
		var wave_start = max(0, wave_length - wave_thickness)
		
		# ИСПРАВЛЕНО: углы вдоль оси X
		var local_corners = [
			Vector2(wave_start, -half_width),
			Vector2(wave_start, half_width),
			Vector2(wave_length, half_width),
			Vector2(wave_length, -half_width)
		]
		
		var world_corners = []
		for corner in local_corners:
			world_corners.append(corner.rotated(angle))
		
		# Рисуем волну
		var wave_color = Color(1, 1, 1, shockwave_alpha * 0.5)
		draw_colored_polygon(PackedVector2Array(world_corners), wave_color)
		
		# Контур волны (передний край ярче)
		var border_color = Color(1, 1, 1, shockwave_alpha)
		# Передний край (между углами 2 и 3)
		draw_line(world_corners[2], world_corners[3], border_color, 5.0)
		# Боковые стороны
		draw_line(world_corners[0], world_corners[1], border_color, 2.0)
		draw_line(world_corners[1], world_corners[2], border_color, 3.0)
		draw_line(world_corners[3], world_corners[0], border_color, 3.0)

# Также обновите физическую форму:
func _check_rectangle_attack_hit():
	"""Проверяет попадание в прямоугольной зоне"""
	if not target or not enemy_data:
		return
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Создаём прямоугольник атаки
	var shape = RectangleShape2D.new()
	# Меняем местами: первый параметр - длина (вдоль оси X после поворота)
	shape.size = Vector2(enemy_data.attack_length, enemy_data.attack_width)
	query.shape = shape
	
	# Угол направления атаки
	var angle = attack_direction.angle()
	
	# Центр прямоугольника смещен на половину длины вперед
	var center_offset = attack_direction * (enemy_data.attack_length * 0.5)
	
	# Transform2D с правильным углом (без корректировки)
	query.transform = Transform2D(angle, global_position + center_offset)
	
	query.collision_mask = 1  # Layer 1 = player
	query.exclude = [get_rid()]
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var body = result.collider
		
		if body == target and not target.is_invulnerable:
			var knockback_dir = attack_direction
			var knockback_vel = knockback_dir * enemy_data.knockback_force
			
			if target.has_method("take_damage"):
				target.take_damage(enemy_data.damage, global_position, knockback_vel)
				attack_hit.emit(target, enemy_data.damage)
				print("Rectangle enemy hit player for ", enemy_data.damage, " damage")

func _start_shockwave():
	"""Запускает визуальную ударную волну в форме прямоугольника"""
	is_shockwave_active = true
	shockwave_progress = 0.0
	shockwave_alpha = 0.8
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Прогресс от 0 до 1
	tween.tween_property(self, "shockwave_progress", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Прозрачность убывает
	tween.tween_property(self, "shockwave_alpha", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	tween.finished.connect(func(): is_shockwave_active = false)

func _update_animation():
	"""Обновляет анимации в зависимости от состояния"""
	if not anim:
		return
	
	match state:
		State.IDLE:
			if anim.current_animation != "idle":
				anim.play("idle")
		
		State.CHASE:
			if velocity.length() > 10.0:
				if anim.current_animation != "walk":
					anim.play("walk")
			else:
				if anim.current_animation != "idle":
					anim.play("idle")
		
		State.ATTACK_WINDUP:
			pass
		
		State.ATTACK_STRIKE:
			pass
		
		State.DEAD:
			pass


func _process(_delta):
	if debug_draw and (state == State.ATTACK_WINDUP or is_shockwave_active):
		queue_redraw()

func _on_state_changed(old_state: State, new_state: State):
	super._on_state_changed(old_state, new_state)
	
	if old_state == State.ATTACK_WINDUP and telegraph_node:
		telegraph_node.visible = false
	
	if new_state == State.DEAD:
		_clear_all_visual_effects()
	
	if debug_draw:
		queue_redraw()

func _clear_all_visual_effects():
	"""Очищает все визуальные эффекты врага"""
	if telegraph_node:
		telegraph_node.visible = false
	
	is_shockwave_active = false
	shockwave_progress = 0.0
	shockwave_alpha = 0.0
	
	attack_windup_start_beat = -1
	attack_strike_performed = false
	current_pulse_scale = 1.0
	
	queue_redraw()

func _on_death():
	"""Проигрывание анимации смерти"""
	_clear_all_visual_effects()
	
	if anim and anim.has_animation("death"):
		anim.play("death")
		await anim.animation_finished
