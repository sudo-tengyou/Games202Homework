#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uLightPos;
uniform vec3 uCameraPos;

varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;

// pack函数用于将深度值的浮点数按照字节分别存储在RGBA中
vec4 pack (float depth) {
    // 使用rgba 4字节共32位来存储z值,1个字节精度为1/256
    const vec4 bitShift = vec4(1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0);
    const vec4 bitMask = vec4(1.0/256.0, 1.0/256.0, 1.0/256.0, 0.0);
    // gl_FragCoord:片元的坐标,fract():返回数值的小数部分
    vec4 rgbaDepth = fract(depth * bitShift);
    rgbaDepth -= rgbaDepth.gbaa * bitMask; // 分别提取第1234个字节的内容, 并存储在RGBA的第一个字节中
    return rgbaDepth;
}

void main(){

  //gl_FragColor = vec4( 1.0, 0.0, 0.0, gl_FragCoord.z);
  gl_FragColor = pack(gl_FragCoord.z);
}