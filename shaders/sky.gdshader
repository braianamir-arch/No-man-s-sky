shader_type sky;

uniform vec3 atmo_color : source_color = vec3(0.45, 0.65, 1.0);
uniform float atmo_density : hint_range(0.0, 1.0) = 0.0;
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 nebula_color : source_color = vec3(0.35, 0.12, 0.55);
uniform float seed = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sp = d * 180.0;
	vec3 cell = floor(sp);
	float h = hash(cell + seed);
	float star = 0.0;
	if (h > 0.982) {
		vec3 c = cell + vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
		star = smoothstep(0.4, 0.0, length(sp - c)) * (h - 0.982) * 70.0;
	}
	float neb = vnoise(d * 2.5 + seed) * 0.6 + vnoise(d * 6.0 - seed) * 0.4;
	neb = smoothstep(0.45, 0.85, neb);
	vec3 space = vec3(0.003, 0.004, 0.01) + nebula_color * neb * 0.3 + vec3(star);

	vec3 up = normalize(up_dir);
	float hu = dot(d, up);
	float day = 1.0;
	float sun_d = 0.0;
	if (LIGHT0_ENABLED) {
		day = smoothstep(-0.25, 0.3, dot(up, LIGHT0_DIRECTION));
		sun_d = max(dot(d, LIGHT0_DIRECTION), 0.0);
	}
	vec3 horizon = atmo_color * 1.1 + vec3(0.12);
	vec3 zenith = atmo_color * 0.5;
	vec3 atmo = mix(horizon, zenith, clamp(hu, 0.0, 1.0));
	float sunset = 1.0 - abs(dot(up, LIGHT0_DIRECTION));
	atmo += vec3(1.0, 0.45, 0.2) * pow(sun_d, 5.0) * sunset * 0.6;
	atmo *= mix(0.03, 1.0, day);
	vec3 col = mix(space, atmo, atmo_density * mix(0.6, 1.0, day));
	col += LIGHT0_COLOR * (pow(sun_d, 900.0) * 12.0 + pow(sun_d, 60.0) * 0.2);
	COLOR = col;
}
