shader_type spatial;
render_mode cull_disabled;

uniform sampler2D heightmap_texture : hint_default_black, filter_linear;
uniform sampler2D ndvi_texture : hint_default_black, filter_linear;

uniform float height_scale : hint_range(0.0, 100.0) = 15.0;
uniform float texel_size = 0.001;

vec3 get_ndvi_colormap(float val) {
	if (val < 0.3) {
		return mix(vec3(0.0, 0.2, 0.8), vec3(0.8, 0.2, 0.0), val / 0.3);
	} else if (val < 0.6) {
		return mix(vec3(0.8, 0.2, 0.0), vec3(0.9, 0.9, 0.1), (val - 0.3) / 0.3);
	} else {
		return mix(vec3(0.9, 0.9, 0.1), vec3(0.0, 0.5, 0.1), (val - 0.6) / 0.4);
	}
}

void vertex() {
	float height = texture(heightmap_texture, UV).r;
	VERTEX.y += height * height_scale;
	
	// Reconstrucción vectorial de la Normal
	float h_L = texture(heightmap_texture, UV + vec2(-texel_size, 0.0)).r * height_scale;
	float h_R = texture(heightmap_texture, UV + vec2(texel_size, 0.0)).r * height_scale;
	float h_D = texture(heightmap_texture, UV + vec2(0.0, -texel_size)).r * height_scale;
	float h_U = texture(heightmap_texture, UV + vec2(0.0, texel_size)).r * height_scale;
	
	NORMAL = normalize(vec3(h_L - h_R, 2.0, h_D - h_U));
}

void fragment() {
	float ndvi_val = texture(ndvi_texture, UV).r;
	ALBEDO = get_ndvi_colormap(ndvi_val);
	ROUGHNESS = 0.8;
}