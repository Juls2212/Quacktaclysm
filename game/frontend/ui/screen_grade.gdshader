shader_type canvas_item;
// Grades whatever the game drew under this rect: desaturates, darkens, tints and adds a
// vignette. `amount` fades the whole effect in and out (animated by the UI scripts).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.75;
uniform float darken : hint_range(0.0, 1.0) = 0.45;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(base, vec3(gray), desaturate);
	graded = mix(graded, gray * tint.rgb * 1.5, tint_amount);
	graded *= 1.0 - darken;
	float edge = smoothstep(0.3, 0.8, length(UV - vec2(0.5)) * 1.15) * vignette;
	graded *= 1.0 - clamp(edge, 0.0, 0.95);
	COLOR = vec4(mix(base, graded, amount), 1.0);
}
