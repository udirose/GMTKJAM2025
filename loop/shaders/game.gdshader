shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 10.0) = 5.0;
uniform vec3 laser_color : source_color = vec3(1.0, 0.2, 0.2);
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 glow_color : source_color = vec3(1.0, 0.4, 0.4);
uniform float beam_speed : hint_range(5.0, 30.0) = 15.0;
uniform float beam_thickness : hint_range(0.1, 0.8) = 0.3;
uniform float intensity : hint_range(1.0, 5.0) = 3.0;

// Noise function
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Fast laser beam streaks
float laser_beams(vec2 uv, float time) {
    float beams = 0.0;

    // Multiple laser beam layers for intensity
    for(int i = 0; i < 5; i++) {
        float offset = float(i) * 0.7;
        vec2 beam_uv = vec2(uv.x + offset * 0.1, uv.y + time * beam_speed + offset);

        // Create sharp vertical laser beams
        float beam = sin(beam_uv.x * 20.0) * 0.5 + 0.5;
        beam = pow(beam, 8.0); // Very sharp beams

        // Speed blur effect
        float speed_blur = sin(beam_uv.y * 3.0) * 0.5 + 0.5;
        speed_blur = pow(speed_blur, 2.0);

        beams += beam * speed_blur;
    }

    return beams / 5.0;
}

// Energy core with motion trails
float energy_core(vec2 uv, float time) {
    float center_dist = abs(uv.x - 0.5);

    // Central beam core
    float core = 1.0 - smoothstep(0.0, beam_thickness * 0.3, center_dist);

    // Moving energy pulses
    float pulse = sin(uv.y * 8.0 + time * beam_speed * 2.0) * 0.5 + 0.5;
    pulse += sin(uv.y * 12.0 - time * beam_speed * 1.5) * 0.3 + 0.7;

    return core * pulse;
}

// Speed lines and motion blur
float speed_lines(vec2 uv, float time) {
    float lines = 0.0;

    // Fast moving lines
    for(int i = 0; i < 3; i++) {
        float line_offset = float(i) * 0.3;
        float line_y = uv.y + time * beam_speed * (2.0 + line_offset) + line_offset;

        float line = sin(line_y * 40.0) * 0.5 + 0.5;
        line = pow(line, 6.0);

        // Fade lines based on distance from center
        float fade = 1.0 - abs(uv.x - 0.5) * 3.0;
        fade = max(0.0, fade);

        lines += line * fade;
    }

    return lines / 3.0;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;

    // Create laser beam effects
    float beams = laser_beams(uv, time);
    float core = energy_core(uv, time);
    float lines = speed_lines(uv, time);

    // Combine effects with different weights
    float beam_intensity = beams * 0.7 + lines * 0.3;
    float total_intensity = (beam_intensity + core) * intensity;

    // Create layered colors
    vec3 color = laser_color * beam_intensity;
    color += core_color * core * 0.8;
    color += glow_color * beam_intensity * 0.5;

    // Intense flickering
    float flicker = sin(time * 25.0) * 0.15 + 0.85;
    flicker *= sin(time * 17.0 + uv.y * 5.0) * 0.1 + 0.9;
    color *= flicker;

    // Outer glow
    float glow = 1.0 - smoothstep(0.0, beam_thickness * 2.0, abs(uv.x - 0.5));
    color += glow_color * glow * 0.3;

    // Saturation boost for laser effect
    color = mix(color, color * color, 0.3);

    COLOR = vec4(color, max(total_intensity, glow * 0.5));
}