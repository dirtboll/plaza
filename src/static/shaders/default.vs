#version 330 core

precision highp float;
precision highp int;

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aTexCoords;

out vec3 vPos;
out vec3 vNormal;
out vec2 vTexCoords;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

void main() {
  vPos = vec3(uModel * vec4(aPos, 1.0));
  vNormal = mat3(transpose(inverse(uModel))) * aNormal;
  vTexCoords = aTexCoords;
  // vColor = aColor;

  gl_Position = uProjection * uView * vec4(vPos, 1.0);
}