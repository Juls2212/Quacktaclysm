shader_type canvas_item;
// The red vignette and the red light flash of the possession sequence (Phase 15d), over the whole screen.
// `vignette_strength` darkens and reddens the edges; `flash_amount` is a capped, short red light (never white).

uniform vec4 vignette_color : source_color = vec4(0.75, 0.04, 0.03, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.15, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 offset = UV - vec2(0.5);
	float edge = smoothstep(0.22, 0.78, length(offset * vec2(1.0, 0.85)));
	float v = edge * vignette_strength;
	float total = clamp(v + flash_amount, 0.0, 1.0);
	vec3 rgb = (vignette_color.rgb * v + flash_color.rgb * flash_amount) / max(v + flash_amount, 0.0001);
	COLOR = vec4(rgb, total);
}
