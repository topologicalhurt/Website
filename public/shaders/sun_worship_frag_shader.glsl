#define PI 3.14159265359
#define N_PASSES 20.
#define ROT_DELAY 2.

uniform float iTime;
uniform vec2 iResolution;
varying vec2 vUv;

// Vectors that define the changing color pallet
const vec3 palA = vec3(1., 0., 1.);
const vec3 palB = vec3(1., 0.5, 0.);
const vec3 palC = vec3(1., 0.5, 0.);
const vec3 palD = vec3(1., 0.5, 0.);

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 2.*PI*(c*t+d) );
}

void main()
{
    vec2 fragCoord = vUv * iResolution * 1.1;
	// vec2 uv = vec2(fragCoord * 2. - iResolution.xy) / iResolution.y;
    vec2 uv = (fragCoord - .5 * 1.1 * iResolution.x) + vec2(0, .5 * 1.1);
    vec2 uv0 = uv;
    vec3 c = vec3(.2, 0.1, 0.1);
    float rt = iTime/ROT_DELAY;
    float uv0Length = length(uv0);
    float cRt = cos(rt);
    float sRt = sin(rt);
    
    for(float i = 0.; i < N_PASSES; i++) {
    
        float uvDot = dot(uv, uv0);
        float uvLength = length(uv);
        vec3 crossProdNorm = normalize(cross(vec3(uv0.x, uv.y , uvLength),
            vec3(uv.x, uv0.y, uv0Length)));
            
        // Fancy ROT(uv + uv0)
        uv = fract( (uv0 - uv) * (1. + 0.25 * abs(sRt)) * mat2(cRt, -sRt, sRt, cRt)
         + ( (pow(uvDot, 3.) * crossProdNorm.z) / crossProdNorm.xy)) - 0.5;

        c += 0.001/palette( pow((uvLength - uv0Length), 3.), palA, palB, palC, palD) +
         0.001/palette(uvLength - uv0Length, palA, palB, palC, palD);
    }
       
	gl_FragColor = vec4(c,1.);
}