float maxcomp(in vec3 p ) { return max(p.x,max(p.y,p.z));}

#define SHADOW_STRENGTH 5.
#define CUBE_SZ .5

uniform float iTime;
uniform vec2 iResolution;
varying vec2 vUv;

float sdfBox( vec3 p, vec3 b )
{
    vec3  di = abs(p) - b;
    // Equivalent
    // mc = length(max(di, 0));
    float mc = maxcomp(di);
    return min(mc,length(max(di,0.0))); // Negative inner SDF
}

vec3 map( in vec3 p )
{
    float d = sdfBox(p,vec3(CUBE_SZ));
    return vec3(d,0.0,0.0);
}

vec3 intersect( in vec3 ro, in vec3 rd )
{
    for(float t=0.0; t<10.0; )
    {
        vec3 h = map(ro + rd*t);
        if( h.x<0.001 )
            return vec3(t,h.yz);
        t += h.x;
    }
    return vec3(-1.0);
}

void main()
{ 
    vec2 fragCoord = vUv;
    vec3 cam_pos = 4.*vec3(cos(iTime), sin(iTime), .5);
    vec3 cam_dir = normalize(-cam_pos);
    vec3 cam_x = vec3(cam_dir.y, -cam_dir.x, 0); // Perp(cam_dir)
    vec3 cam_y = cross(cam_x, cam_dir); // Cross prod of perp(cam_dir)
    
    vec2 uv = 2. * fragCoord -1.;
    uv.x *= iResolution.x/min(iResolution.x, iResolution.y);
    uv.y *= iResolution.y/max(iResolution.x, iResolution.y);
    vec3 ray_dir = normalize(cam_dir + uv.x * cam_x + uv.y * cam_y);
    
    vec3 c = intersect(cam_pos, ray_dir);
    c = vec3(float(c.x)/float(SHADOW_STRENGTH));
    
    gl_FragColor = vec4(c,1.0);
}

