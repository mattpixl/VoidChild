extends CharacterBody2D

# Values are px/s for a 320x180 view, based on Celeste's own numbers.
@export_group("Run")
@export var max_run: float = 90.0
@export var run_accel: float = 1000.0
@export var run_reduce: float = 400.0     # slowing down when over max speed (e.g. after a dash)
@export var air_mult: float = 0.65        # less control in the air

@export_group("Jump")
@export var gravity: float = 900.0
@export var max_fall: float = 160.0
@export var half_grav_threshold: float = 40.0  # floaty hang time near the jump apex (while holding jump)
@export var jump_speed: float = -105.0
@export var var_jump_time: float = 0.2    # hold jump up to this long for a higher jump
@export var jump_h_boost: float = 100.0    # small horizontal kick when jumping
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var boost_decay: float = 500.0
@export var jump_v_boost: float = 100.0    # extra upward speed at takeoff
@export var v_boost_decay: float = 400.0  # how fast that extra upward speed bleeds off

@export_group("Dash")
@export var dash_speed: float = 240.0
@export var dash_time: float = 0.15
@export var dash_end_speed: float = 160.0

@export var camera_lerp: float = 8.0   # higher = snappier follow
var _cam_pos := Vector2.ZERO

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _var_jump_timer := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector2.ZERO
var _can_dash := true
var _facing := 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Only adds actions that don't already exist, so the Input Map can override these.
	_ensure_action("move_left",  [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_up",    [KEY_W, KEY_UP])
	_ensure_action("move_down",  [KEY_S, KEY_DOWN])
	_ensure_action("jump",       [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_action("dash",       [KEY_SHIFT, KEY_K])
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0

func _ensure_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		_facing = signf(input_x)

	# Timers
	if is_on_floor():
		_coyote_timer = coyote_time
		if _dash_timer <= 0.0:
			_can_dash = true
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Dash start
	if Input.is_action_just_pressed("dash") and _can_dash and _dash_timer <= 0.0:
		var aim := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_dash_dir = aim.normalized() if aim != Vector2.ZERO else Vector2(_facing, 0.0)
		_dash_timer = dash_time
		_can_dash = false
		_var_jump_timer = 0.0

	# Dashing overrides everything else
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
		if _dash_timer <= 0.0:
			velocity = _dash_dir * dash_end_speed
			if velocity.y < 0.0:
				velocity.y *= 0.75
		move_and_slide()
		_update_animation(input_x)
		return

	# Horizontal: snappy accel, fast decay of boost speed
	var mult := 1.0 if is_on_floor() else air_mult
	var over_speed := absf(velocity.x) > max_run and signf(velocity.x) == input_x
	if over_speed:
		var decay := run_reduce if is_on_floor() else boost_decay
		velocity.x = move_toward(velocity.x, max_run * input_x, decay * delta)
	else:
		velocity.x = move_toward(velocity.x, max_run * input_x, run_accel * mult * delta)

		# Gravity: half strength at the apex while jump is held, capped fall speed
	if not is_on_floor():
		var g := gravity
		if absf(velocity.y) < half_grav_threshold and Input.is_action_pressed("jump"):
			g *= 0.5
		velocity.y = move_toward(velocity.y, max_fall, g * delta)

	# ---- VARIABLE JUMP BLOCK ----
	if _var_jump_timer > 0.0:
		# Bleed off the takeoff burst toward the normal jump speed
		if velocity.y < jump_speed:
			velocity.y = move_toward(velocity.y, jump_speed, v_boost_decay * delta)
		if Input.is_action_pressed("jump"):
			velocity.y = minf(velocity.y, jump_speed)
		else:
			_var_jump_timer = 0.0
		_var_jump_timer = maxf(_var_jump_timer - delta, 0.0)

	# ---- JUMP BLOCK ----
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_speed - jump_v_boost
		velocity.x += jump_h_boost * input_x
		_var_jump_timer = var_jump_time
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	move_and_slide()
	_update_animation(input_x)

func _update_animation(input_x: float) -> void:
	var anim := "idle"
	if _dash_timer > 0.0:
		anim = "dash"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif input_x != 0.0:
		anim = "run"

	sprite.flip_h = _facing < 0.0

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
