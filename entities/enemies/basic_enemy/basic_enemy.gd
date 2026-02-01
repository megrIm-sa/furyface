# res://scripts/enemies/basic_enemy.gd
class_name BasicEnemy
extends Enemy

@export var debug_draw: bool = true
@export var telegraph_color_start: Color = Color(1, 1, 0, 0.3)  # Желтый
@export var telegraph_color_end: Color = Color(1, 0, 0, 0.6)    # Красный
@export var pulse_scale_min: float = 0.9
@export var pulse_scale_max: float = 1.1

var attack_windup_start_beat: int = -1
var current_pulse_scale: float = 1.0
var telegraph_node: Node2D = null
var attack_strike_performed: bool = false  # Флаг чтобы удар произошел один раз

var shockwave_radius: float = 0.0  # Текущий радиус ударной волны
var shockwave_alpha: float = 0.0   # Прозрачность ударной волны
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
	
	# Обновляем анимации
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
	
	if is_target_in_range(enemy_data.attack_range):
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
		# Вычисляем позицию в анимации на основе битов
		# 3 бита подготовки = 3 кадра по 0.1 секунды
		var animation_time = beats_passed * 0.1 + beat_progress * 0.1
		
		# Если анимация не играет или это не attack, запускаем
		if anim.current_animation != "attack":
			anim.play("attack")
		
		# Устанавливаем позицию анимации вручную (пауза + seek)
		if beats_passed < enemy_data.windup_beats:
			anim.pause()
			anim.seek(animation_time, true)
	
	# После windup_beats (3 бита) переходим к удару
	if beats_passed >= enemy_data.windup_beats and not attack_strike_performed:
		_perform_strike()

func _state_attack_strike(delta: float):
	stop_moving(delta)
	
	# Ждем завершения анимации атаки
	if anim and anim.is_playing() and anim.current_animation == "attack":
		return
	
	# Возвращаемся к chase
	change_state(State.CHASE)

func _on_beat(beat: int):
	match state:
		State.CHASE:
			# Проверяем на каждый бит, можем ли атаковать
			if is_target_in_range(enemy_data.attack_range):
				_start_attack_windup(beat)
		
		State.ATTACK_WINDUP:
			# Пульсация на каждый бит во время замаха
			_pulse_telegraph()
			print("Windup pulse on beat ", beat, " (beat ", beat - attack_windup_start_beat + 1, " of ", enemy_data.windup_beats, ")")

func _start_attack_windup(beat: int):
	attack_windup_start_beat = beat
	current_pulse_scale = pulse_scale_max
	attack_strike_performed = false
	
	change_state(State.ATTACK_WINDUP)
	attack_started.emit()
	
	# Показываем telegraph
	if telegraph_node:
		telegraph_node.visible = true
	
	# Начинаем анимацию attack (но будем управлять ей вручную)
	if anim and anim.has_animation("attack"):
		anim.play("attack")
		anim.pause()
		anim.seek(0.0, true)
	
	print("Enemy starting attack on beat ", beat)

func _pulse_telegraph():
	"""Визуальная пульсация на каждый бит"""
	# Анимация пульсации
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "current_pulse_scale", pulse_scale_max, 0.1)
	tween.tween_property(self, "current_pulse_scale", pulse_scale_min, 0.3)
	
	queue_redraw()

func _perform_strike():
	"""Выполняет удар на 4-м бите (после 3 битов подготовки)"""
	if attack_strike_performed:
		return
	
	attack_strike_performed = true
	change_state(State.ATTACK_STRIKE)
	
	# Скрываем telegraph
	if telegraph_node:
		telegraph_node.visible = false
	
	# Проверяем попадание в круговой области
	_check_circular_attack_hit()
	
	# ВАЖНО: Продолжаем анимацию с 0.4 секунды (момент удара)
	if anim and anim.has_animation("attack"):
		anim.play("attack")
		anim.seek(0.4, true)  # Переходим к кадру удара
	
	# Запускаем анимацию ударной волны
	_start_shockwave()
	
	print("Enemy performed strike!")

# Добавьте новый метод для запуска ударной волны:
func _start_shockwave():
	"""Запускает визуальную ударную волну"""
	is_shockwave_active = true
	shockwave_radius = 0.0
	shockwave_alpha = 0.8
	
	# Анимируем расширение волны
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Радиус расширяется от 0 до attack_range
	tween.tween_property(self, "shockwave_radius", enemy_data.attack_range, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Прозрачность убывает
	tween.tween_property(self, "shockwave_alpha", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# После завершения скрываем волну
	tween.finished.connect(func(): is_shockwave_active = false)

# Обновленный метод _draw:
func _draw():
	if not debug_draw or not enemy_data or state == State.DEAD:
		return
	
	# Во время замаха рисуем пульсирующую круговую зону атаки
	if state == State.ATTACK_WINDUP:
		var beats_passed = (current_beat - attack_windup_start_beat)
		var progress = beats_passed / enemy_data.windup_beats
		
		# Интерполяция цвета от жёлтого к красному
		var color = telegraph_color_start.lerp(telegraph_color_end, progress)
		
		# Применяем пульсацию
		var pulsing_radius = enemy_data.attack_range * current_pulse_scale
		
		# Рисуем заполненный круг (более видимый)
		draw_circle(Vector2.ZERO, pulsing_radius, color)
		
		# Рисуем границу круга (контур)
		draw_arc(Vector2.ZERO, pulsing_radius, 0, TAU, 32, Color(color.r, color.g, color.b, 1.0), 3.0)
	
	# Во время удара рисуем ударную волну
	if is_shockwave_active and shockwave_radius > 0.0:
		# Внутренний круг (заполненный)
		var fill_color = Color(1, 1, 1, shockwave_alpha * 0.3)
		draw_circle(Vector2.ZERO, shockwave_radius, fill_color)
		
		# Внешний контур (яркий)
		var border_color = Color(1, 1, 1, shockwave_alpha)
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 32, border_color, 4.0)
		
		# Дополнительный внутренний контур для эффекта "толщины"
		if shockwave_radius > 5.0:
			var inner_radius = shockwave_radius - 5.0
			draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, Color(1, 1, 1, shockwave_alpha * 0.5), 2.0)

# Обновите метод _process для постоянной перерисовки во время ударной волны:
func _process(_delta):
	# Постоянно обновляем рисование во время windup или ударной волны
	if debug_draw and (state == State.ATTACK_WINDUP or is_shockwave_active):
		queue_redraw()

func _check_circular_attack_hit():
	"""Проверяет попадание в круговой зоне вокруг врага"""
	if not target or not enemy_data:
		return
	
	# Используем PhysicsDirectSpaceState2D для круговой атаки
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Создаём круг атаки
	var shape = CircleShape2D.new()
	shape.radius = enemy_data.attack_range
	query.shape = shape
	
	# Позиция атаки - центр врага
	query.transform = Transform2D(0, global_position)
	
	query.collision_mask = 1  # Layer 1 = player
	query.exclude = [get_rid()]
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var body = result.collider
		
		if body == target:
			# Проверяем неуязвимость
			if not target.is_invulnerable:
				var knockback_dir = (target.global_position - global_position).normalized()
				var knockback_vel = knockback_dir * enemy_data.knockback_force
				
				if target.has_method("take_damage"):
					target.take_damage(enemy_data.damage, global_position, knockback_vel)
					attack_hit.emit(target, enemy_data.damage)
					print("Enemy hit player for ", enemy_data.damage, " damage")

func _update_animation():
	"""Обновляет анимации в зависимости от состояния"""
	if not anim:
		return
	
	match state:
		State.IDLE:
			if anim.current_animation != "idle":
				anim.play("idle")
		
		State.CHASE:
			# Проверяем, двигается ли враг
			if velocity.length() > 10.0:
				if anim.current_animation != "walk":
					anim.play("walk")
			else:
				if anim.current_animation != "idle":
					anim.play("idle")
		
		State.ATTACK_WINDUP:
			# Анимация attack управляется вручную в _state_attack_windup
			pass
		
		State.ATTACK_STRIKE:
			# Анимация attack уже играет с момента удара
			pass
		
		State.DEAD:
			# Анимация death играется в _on_death
			pass


func _on_state_changed(old_state: State, new_state: State):
	super._on_state_changed(old_state, new_state)
	
	# Скрываем telegraph при выходе из windup
	if old_state == State.ATTACK_WINDUP and telegraph_node:
		telegraph_node.visible = false
	
	# При смерти очищаем все эффекты
	if new_state == State.DEAD:
		_clear_all_visual_effects()
	
	# Обновляем отрисовку
	if debug_draw:
		queue_redraw()

func _on_death():
	"""Переопределяем метод смерти для проигрывания анимации и очистки эффектов"""
	# Очищаем все визуальные эффекты
	_clear_all_visual_effects()
	
	if anim and anim.has_animation("death"):
		anim.play("death")
		# Ждем завершения анимации смерти
		await anim.animation_finished
		
	
func _clear_all_visual_effects():
	"""Очищает все визуальные эффекты врага"""
	# Скрываем telegraph
	if telegraph_node:
		telegraph_node.visible = false
	
	# Останавливаем ударную волну
	is_shockwave_active = false
	shockwave_radius = 0.0
	shockwave_alpha = 0.0
	
	# Сбрасываем флаги атаки
	attack_windup_start_beat = -1
	attack_strike_performed = false
	current_pulse_scale = 1.0
	
	# Перерисовываем (очищаем круги)
	queue_redraw()
