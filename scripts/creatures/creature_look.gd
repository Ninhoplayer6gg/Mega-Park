class_name CreatureLook
extends RefCounted
## Visual identity of an individual creature: mutation palette shader, form sheet (big mutations
## such as Xenoraptor Tempestade) and size. Shared by the park, battle, portraits and photos.

const SHADER := preload("res://assets/shaders/creature.gdshader")


## Always returns a material so the battle hit-flash works for every creature.
static func material_for(mutation: MutationData) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if mutation:
		m.set_shader_parameter("m_hue_shift", mutation.hue_shift)
		m.set_shader_parameter("m_saturation", mutation.saturation)
		m.set_shader_parameter("m_value", mutation.value)
		m.set_shader_parameter("m_tint", mutation.tint)
		m.set_shader_parameter("m_tint_amount", mutation.tint_amount)
		m.set_shader_parameter("m_pulse", mutation.pulse)
		m.set_shader_parameter("m_pulse_color", mutation.tint if mutation.tint != Color.WHITE else Color(0.5, 1.0, 0.9))
		m.set_shader_parameter("m_unstable", 1.0 if mutation.unstable else 0.0)
	return m


static func frames_for(c: CreatureInstance) -> SpriteFrames:
	return DataRegistry.sprite_frames_for(c.data, c.form_sheet())


static func scale_for(mutation: MutationData) -> float:
	return mutation.visual_scale if mutation else 1.0


## Whether the palette shader changes anything (small mutations); form sheets need no palette.
static func has_palette(mutation: MutationData) -> bool:
	return mutation != null and (mutation.tint_amount > 0.0 or mutation.pulse > 0.0 or mutation.unstable
		or not is_equal_approx(mutation.saturation, 1.0) or not is_equal_approx(mutation.value, 1.0)
		or not is_zero_approx(mutation.hue_shift))
