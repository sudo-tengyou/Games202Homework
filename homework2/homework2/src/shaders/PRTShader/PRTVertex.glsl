attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute mat3 aPrecomputeLT;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat3 uPrecomputeL[3];

varying highp vec3 vColor;
varying highp vec3 vNormal;

float L_dot_LT(mat3 precomputeL, mat3 precomputeLT) {
  vec3 L_0 = precomputeL[0];
  vec3 L_1 = precomputeL[1];
  vec3 L_2 = precomputeL[2];
  vec3 LT_0 = precomputeLT[0];
  vec3 LT_1 = precomputeLT[1];
  vec3 LT_2 = precomputeLT[2];
  return dot(L_0, LT_0) + dot(L_1, LT_1) + dot(L_2, LT_2);
}

void main(void) {
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;
  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);
  
  for(int i = 0; i < 3;  i++) {
    vColor[i] = L_dot_LT(uPrecomputeL[i], aPrecomputeLT);
  }
}