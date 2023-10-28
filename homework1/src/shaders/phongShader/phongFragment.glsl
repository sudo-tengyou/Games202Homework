#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 150
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

// 泊松圆盘采样
void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

// 均匀圆盘采样
void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
  poissonDiskSamples(uv);

  float res = 0.0;
  float searchSize = 20.0;
  float filterRange = searchSize / 2048.0;
  float blockerDepthSum = 0.0;
  float blockerCount = 0.0;

  for (int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i++) {
    vec2 sampleuv = uv + poissonDisk[i] * filterRange;
    float shadowz = unpack(texture2D(shadowMap, sampleuv));
    if(shadowz + EPS <= zReceiver) {
      blockerDepthSum += shadowz;
      blockerCount++;
    }
  }
  if(blockerCount == 0.0) {
    return zReceiver;
  }
	return blockerDepthSum / blockerCount;
}

float PCF(sampler2D shadowMap, vec4 coords, float filterSize) {
  poissonDiskSamples(coords.xy);

  float res = 0.0;
  float filterRange = filterSize / 2048.0;

  for (int i = 0; i < NUM_SAMPLES; i++) {
    vec2 sampleuv = coords.xy + poissonDisk[i] * filterRange;
    float shadowz = unpack(texture2D(shadowMap, sampleuv));
    if(shadowz + 5.0 * EPS > coords.z)
      res += 1.0;
  }
  return res / float(NUM_SAMPLES);
}

#define LIGHTWIDTH 10.0
float PCSS(sampler2D shadowMap, vec4 coords) {

  // STEP 1: avgblocker depth
  float avgblockerDepth = clamp(findBlocker(shadowMap, coords.xy, coords.z), 1e-7, coords.z);
  // STEP 2: penumbra size
  float penumbraWidth = LIGHTWIDTH * (coords.z - avgblockerDepth) / avgblockerDepth;
  // STEP 3: filtering
  float filterSize = 2.0 * penumbraWidth;
  return PCF(shadowMap, coords, filterSize);
}

float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  float shadowz = unpack(texture2D(shadowMap, shadowCoord.xy));
  if(shadowz + EPS > shadowCoord.z)
    return 1.0;
  else
    return 0.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility;
  vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w;
  shadowCoord = (shadowCoord + 1.0) / 2.0;
  //visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));  // 60FPS
  visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0), 7.0);  // 30FPS
  //visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));  // 5.3FPS,disaster!

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
}