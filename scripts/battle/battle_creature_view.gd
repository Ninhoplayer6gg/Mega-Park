class_name BattleCreatureView
extends Node2D
## A creature on the battle stage: idle/attack/hurt/defeat animations, hit flash and shakes.

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash * c.a), c.a) * COLOR;
}
"""

static var _shader: Shader

var data: CreatureData
var facing := 1            # 1 = looks right, -1 = looks left
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var home := Vector2.ZERO
var _mat: ShaderMaterial


func setup(species: CreatureData, face_right: bool) -> void:
	data = species
	facing = 1 if face_right else -1


func _ready() -> void:
	var s := data.battle_scale
	shadow = Sprite2D.new()
	shadow.texture = load("res://assets/effects/shadow.png")
	shadow.scale = Vector2(data.frame_size.x * 0.65 * s / 32.0, data.frame_size.x * 0.65 * s / 32.0 * 0.4)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = DataRegistry.sprite_frames_for(data)
	sprite.centered = false
	sprite.offset = Vector2(-data.frame_size.x * 0.5, -data.foot_y - 1)
	sprite.scale = Vector2(s, s)
	sprite.flip_h = facing < 0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	sprite.material = _mat
	add_child(sprite)
	sprite.play(&"idle")
	sprite.animation_finished.connect(_on_anim_finished)


func _on_anim_finished() -> void:
	if sprite.animation in [&"attack", &"hurt"]:
		sprite.play(&"idle")


func top_point() -> Vector2:
	return global_position + Vector2(0, -data.foot_y * data.battle_scale * 0.85)


func center_point() -> Vector2:
	return global_position + Vector2(0, -data.foot_y * data.battle_scale * 0.45)


func enter(from_offset: float, duration := 0.6) -> void:
	position = home + Vector2(from_offset, 0)
	sprite.play(&"walk")
	var tw := create_tween()
	tw.tween_property(self, "position", home, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): sprite.play(&"idle"))


## Lunge toward the opponent; returns after the impact moment.
func attack(distance := 90.0) -> void:
	sprite.play(&"attack")
	var tw := create_tween()
	tw.tween_property(self, "position", home + Vector2(-14 * facing, 0), 0.1)
	tw.tween_property(self, "position", home + Vector2(distance * facing, 0), 0.12).set_ease(Tween.EASE_IN)
	await tw.finished
	var back := create_tween()
	back.tween_interval(0.12)
	back.tween_property(self, "position", home, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func cast(color: Color) -> void:
	sprite.play(&"attack")
	_flash(color, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "position:y", home.y - 16, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", home.y, 0.18).set_ease(Tween.EASE_IN)
	await tw.finished


func hurt(heavy := false) -> void:
	sprite.play(&"hurt")
	_flash(Color.WHITE, 0.9)
	var amp := 10.0 if heavy else 6.0
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", home + Vector2(-amp * facing * (1 - i * 0.25), 0), 0.04)
		tw.tween_property(self, "position", home + Vector2(amp * 0.5 * facing, 0), 0.04)
	tw.tween_property(self, "position", home, 0.05)


func defeat() -> void:
	sprite.play(&"defeat")
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(sprite, "modulate", Color(0.6, 0.6, 0.7, 1), 0.4)
	await tw.finished


func celebrate() -> void:
	sprite.play(&"idle")
	var tw := create_tween().set_loops(3)
	tw.tween_property(self, "position:y", home.y - 18, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", home.y, 0.15).set_ease(Tween.EASE_IN)


func _flash(color: Color, strength: float) -> void:
	_mat.set_shader_parameter("flash_color", color)
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("flash", v), strength, 0.0, 0.3)
