shader_type canvas_item;

uniform float time_scale : hint_range(0.0, 5.0) = 0.6;
uniform float distortion : hint_range(0.0, 0.05) = 0.008;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : hint_default_black;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment(){
    vec2 suv = SCREEN_UV;
    vec2 nuv = UV * 2.0 + vec2(0.0, TIME * time_scale);
    vec2 n = texture(noise_tex, nuv).rg - 0.5;
    vec2 wobble = n * distortion;

    float edge_soft = smoothstep(reveal - 0.12, reveal + 0.02, UV.y);
    float edge_glow = smoothstep(reveal - 0.02, reveal + 0.02, UV.y)
                    - smoothstep(reveal + 0.02, reveal + 0.05, UV.y);

    vec4 under = texture(SCREEN_TEXTURE, suv + wobble);
    vec3 col = mix(vec3(0.0), under.rgb, edge_soft);
    col += vec3(1.0, 0.55, 0.15) * edge_glow * 0.25;

    COLOR = vec4(col, 1.0);
}
