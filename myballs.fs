#version 300 es
#define MAX_METABALLS 32

precision highp float;
precision highp sampler2D;

in vec2 uv;
out vec4 out_color;

uniform vec2 u_resolution;
uniform vec3 u_metaballs[MAX_METABALLS];
uniform vec3 u_mbColors[MAX_METABALLS];

float calcDistanceSquared(vec2 fragCoord, vec2 mbPos, float aspectRatio) {
  vec2 scaledCoord = vec2(fragCoord.x * aspectRatio, fragCoord.y);
  vec2 scaledMbPos = vec2(mbPos.x * aspectRatio, mbPos.y);
  return distance(scaledCoord, scaledMbPos);
}

float applyBezierCurve(float x, float k) { return x * (x + (1.0 - x) * k); }

void main() {
  vec2 st = gl_FragCoord.xy / u_resolution;

  vec4 color = vec4(0.0);

  for (int i = 0; i < MAX_METABALLS; i++) {
    vec2 mbPos = u_metaballs[i].xy / u_resolution;
    float mbRadius = u_metaballs[i].z / distance(vec2(0), u_resolution);

    float dist =
        2.0 * mbRadius /
        calcDistanceSquared(st, mbPos, u_resolution.x / u_resolution.y);
    dist = clamp(dist, 0.0, 1.0);

    vec3 mbColor =
        u_mbColors[i] * applyBezierCurve(dist, 1.0 / float(MAX_METABALLS));
    color += vec4(mbColor, dist);
    color = clamp(color, vec4(0), vec4(1));
  }

  out_color = color;
}
