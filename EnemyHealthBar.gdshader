shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col_back : source_color = vec4(0.08,0.08,0.10,0.85);
uniform vec4 col_fill : source_color = vec4(0.20,0.85,0.25,1.0);
uniform vec4 col_border : source_color = vec4(0.00,0.00,0.00,1.0);
uniform float border = 0.08;
uniform float corner = 0.18;
uniform float hurt_flash : hint_range(0.0,1.0) = 0.0;

float rounded_box(vec2 uv, vec2 size, float r){
    vec2 q = abs(uv - vec2(0.5)) - size * 0.5 + vec2(r);
    return max(max(q.x, q.y), 0.0) - r;
}

void fragment(){
    vec2 uv = UV;

    float outer = step(rounded_box(uv, vec2(1.0,1.0), corner), 0.0);
    float inner_mask = step(rounded_box(uv, vec2(1.0 - 2.0*border, 1.0 - 2.0*border), corner*0.6), 0.0);

    vec3 col = mix(col_border.rgb, col_back.rgb, inner_mask);

    float x_in = step(uv.x, fill);
    float fill_mask = inner_mask * x_in;

    vec3 hot = mix(col_fill.rgb, vec3(0.95, 0.15, 0.10), hurt_flash);
    col = mix(col, hot, fill_mask);

    ALBEDO = col;
    ALPHA = outer;
}
