#version 330 core
precision highp float;

out vec4 fColor;

in vec3 vPos;
in vec3 vNormal;
in vec2 vTexCoords;

uniform vec3 uLightPos;
uniform vec3 uViewPos;
uniform vec3 uLightColor;

const float uAmbientStrength = 0.5;
const float uSpecularStrength = 1.0;

uniform sampler2D uTextureMap;

const vec4 color = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
  // ambient
  vec3 ambient = uAmbientStrength * uLightColor;

  // diffuse
  vec3 normal = normalize(vNormal);
  vec3 lightDir = normalize(uLightPos - vPos);
  float diff = max(dot(normal, lightDir), 0.0);
  vec3 diffuse = diff * uLightColor;

  // specular
  vec3 viewDir = normalize(uViewPos - vPos);
  vec3 reflectDir = reflect(-lightDir, normal);
  float spec = pow(max(dot(viewDir, reflectDir), 0.0), 128.0);
  vec3 specular = uSpecularStrength * spec * uLightColor;

  vec3 result = (ambient + diffuse + specular);
  vec2 texcoord = vec2(vTexCoords.s, vTexCoords.t);
  fColor = vec4(result, 1.0) * color;

  // fColor = color;
}