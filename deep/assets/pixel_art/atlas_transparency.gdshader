shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float spread = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	if (spread < 0.035 && min(c.r, min(c.g, c.b)) > 0.82) {
		c.a = 0.0;
	}
	COLOR = c;
}

