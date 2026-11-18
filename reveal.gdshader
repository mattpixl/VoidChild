shader_type canvas_item;

uniform vec2 center = vec2(0.0);   // circle center in world coordinates
uniform float radius : hint_range(0.0, 300.0) = 40.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = distance(world_pos, center);
	COLOR.a *= 1.0 - step(radius, d);   // hard pixel edge: visible inside, gone outside
}
