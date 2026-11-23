shader_type canvas_item;
// Screen-edge vignette plus a full-screen tint pulse, drawn as one translucent layer. The middle of
// the screen stays clear, so the play field keeps its readability.

uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 pulse_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = length((UV - vec2(0.5)) * vec2(1.0, 0.8)) * 1.6;
	float v = smoothstep(0.55, 1.15, d) * vignette_color.a;
	float p = pulse_color.a * pulse;
	float a = 1.0 - (1.0 - v) * (1.0 - p);
	vec3 rgb = (vignette_color.rgb * v * (1.0 - p) + pulse_color.rgb * p) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
