#define PI 3.14159265359
#define RES_SCALE 1.05
#define N_PASSES 12.
#define TIME_COEFF 10.

// TODO: I) Add gaussian blur or denoise algorithm
// II) Add ability to zoom in / out
// III) Add 'constellations'

uniform float iTime;
uniform vec2 iResolution;
varying vec2 vUv;
uniform sampler2D iChannel0;

// Vectors that define the changing color palette
const vec3 palA = vec3(1., 0., 1.);
const vec3 palB = vec3(1., 0.5, 0.);
const vec3 palC = vec3(1., 0.5, 0.);
const vec3 palD = vec3(1., 0.5, 0.);

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 2.*PI*(c*t+d) );
}

void drawSun() {
    // Fragcoord resolution scaling
    vec2 fragCoord = vUv * iResolution * RES_SCALE;
    vec2 uv = (fragCoord - .5 * RES_SCALE * iResolution.x) + vec2(0, .5 * RES_SCALE);
    vec2 uv0 = uv;

    // Define rotation matrix, time-step and other vars constant WRT the loop
    vec3 c = vec3(0.5, 0., 0.1);
    float rt = iTime/TIME_COEFF;
    float uv0Length = length(uv0);
    float cRt = cos(rt); float sRt = sin(rt);
    mat2 rot = mat2(cRt, -sRt, sRt, cRt);
    
    for(float i = 0.; i < N_PASSES; i++) {
    
        float uvDot = dot(uv, uv0);
        float uvLength = length(uv);
        vec3 crossUv0Uv = cross(vec3(uv0.x, uv.y, uvLength), vec3(uv.x, uv0.y, uv0Length));
            
        // Fancy ROT(uv + sign(uv . uv0) * uv0)
        uv = fract( ( uv0 + sign(uvDot) * uv ) * (1. + .25 * abs(sRt)) * rot
         + ( (pow(uvDot, 4.) * crossUv0Uv.z) / crossUv0Uv.xy)) - .5;
        
        // Determine the color
        float coeff = smoothstep(0., 1., 0.03 * abs(2.*fract(rt)-1.)) + 0.0001;
        c += coeff/palette( pow((uvLength - uv0Length), 2.), palA, palB, palC, palD) +
         (coeff * 2.)/palette(uv0Length / uvLength, palA, palB, palC, palD);
    }

    // Mask out centre ring for a texture
    if ((uv0Length >= .7 || uv0Length <= .35 || (c.x + c.y + c.z) >= .65)) {
        gl_FragColor += vec4(c, 1.);
    } else {
        vec2 imgCoords = (vUv * iResolution * 0.5) - vec2(1., 0.75);
        vec2 rotText = rot * (imgCoords) + vec2(0.5, 0.5);
        gl_FragColor += vec4(c - (smoothstep(0., .65, length(imgCoords)))
         + mix(texture(iChannel0, rotText).xyz, vec3(.25, .1, 0.), .5), 1.);
    }
}

void main()
{
    drawSun();
}