shader_type spatial;
render_mode unshaded;

uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

void fragment() {
	// Probably wrong
	vec3 normal = 1.-textureLod(normal_texture, SCREEN_UV, 0.0).gbr;//*vec3(.5,.5,1.);//rbg//bgr//1-gbr
	ALBEDO = normal;
}
