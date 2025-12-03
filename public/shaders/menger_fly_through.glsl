#ifdef GL_ES
precision highp float;
#endif

uniform float iTime;
uniform vec2 iResolution;
uniform float iRandomSeed;  // Random seed from JavaScript, changes each page load
varying vec2 vUv;

#define PI 3.14159265359

// Session random seed - computed in main() and passed to functions
float sessionSeed;

float maxcomp(in vec3 p) { return max(p.x, max(p.y, p.z)); }

float sdfBox(vec3 p, vec3 b)
{
    vec3 di = abs(p) - b;
    float mc = maxcomp(di);
    return min(mc, length(max(di, 0.0)));
}

vec3 map(in vec3 p)
{
    float d = sdfBox(p, vec3(1.0));

    float s = 1.0;
    int n_iters = int(20.0 * abs(2.0 * fract(iTime / 5.0) - 1.0) + 5.0);
    for(int m = 0; m < 10; m++)
    {
        if(m >= n_iters) break;
        vec3 a = mod(p * s, 2.0) - 1.0;
        s *= 2.0;
        vec3 r = abs(1.0 - 3.0 * abs(a));

        float da = max(r.x, r.y);
        float db = max(r.y, r.z);
        float dc = max(r.z, r.x);
        float c = (min(da, min(db, dc)) - 1.0) / s;

        d = max(d, c);
    }

    return vec3(d, 1.0, 1.0);
}

vec3 intersect(in vec3 ro, in vec3 rd)
{
    for(float t = 0.0; t < 10.0;)
    {
        vec3 h = map(ro + rd * t);
        if(h.x < 0.001)
            return vec3(t, h.yz);
        t += h.x;
    }
    return vec3(-1.0);
}

// Calculate normal for lighting
vec3 calcNormal(in vec3 pos)
{
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(pos + e.xyy).x - map(pos - e.xyy).x,
        map(pos + e.yxy).x - map(pos - e.yxy).x,
        map(pos + e.yyx).x - map(pos - e.yyx).x
    ));
}

// Soft shadows for depth
float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 32; i++)
    {
        if(t >= maxt) break;
        float h = map(ro + rd * t).x;
        if(h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float calcAO(vec3 pos, vec3 nor)
{
    float occ = 0.0;
    float sca = 1.0;
    for(int i = 0; i < 5; i++)
    {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = map(pos + h * nor).x;
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

// Color palette function
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d)
{
    return a + b * cos(2.0 * PI * (c * t + d));
}

// Hash functions for noise
float hash(float n) { return fract(sin(n) * 43758.5453123); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123); }

vec3 hash3(vec3 p)
{
    return fract(sin(vec3(
        dot(p, vec3(127.1, 311.7, 74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6))
    )) * 43758.5453);
}

// 3D Value noise
float noise3D(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
            mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
        mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
            mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Fractal Brownian Motion - optimized 3 iterations
float fbm(vec3 p)
{
    float value = 0.5 * noise3D(p);
    p *= 2.0;
    value += 0.25 * noise3D(p);
    p *= 2.0;
    value += 0.125 * noise3D(p);
    return value;
}

// Rotation matrix around arbitrary axis
mat2 rot2D(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// Vibrant expanded color palette - purples, magentas, varied blues and reds
vec3 hubbleColor(float seed)
{
    float idx = hash(seed) * 30.0;
    
    // PURPLES & MAGENTAS
    if(idx < 1.0) return vec3(0.7, 0.2, 0.9);       // Vivid purple
    if(idx < 2.0) return vec3(0.5, 0.1, 0.7);       // Deep violet
    if(idx < 3.0) return vec3(0.9, 0.3, 0.8);       // Hot magenta
    if(idx < 4.0) return vec3(0.6, 0.3, 0.9);       // Blue-violet
    if(idx < 5.0) return vec3(0.8, 0.1, 0.6);       // Magenta-pink
    if(idx < 6.0) return vec3(0.4, 0.2, 0.6);       // Dark purple
    
    // BLUES - varied intensities
    if(idx < 7.0) return vec3(0.2, 0.4, 1.0);       // Bright blue
    if(idx < 8.0) return vec3(0.1, 0.3, 0.9);       // Deep blue
    if(idx < 9.0) return vec3(0.4, 0.7, 1.0);       // Sky blue
    if(idx < 10.0) return vec3(0.3, 0.5, 0.95);     // Royal blue
    if(idx < 11.0) return vec3(0.5, 0.8, 1.0);      // Light cyan-blue
    if(idx < 12.0) return vec3(0.2, 0.6, 0.9);      // Azure
    
    // REDS & PINKS - varied intensities  
    if(idx < 13.0) return vec3(1.0, 0.2, 0.3);      // Bright red
    if(idx < 14.0) return vec3(0.9, 0.1, 0.2);      // Deep crimson
    if(idx < 15.0) return vec3(1.0, 0.4, 0.5);      // Coral pink
    if(idx < 16.0) return vec3(1.0, 0.3, 0.6);      // Hot pink
    if(idx < 17.0) return vec3(0.8, 0.2, 0.4);      // Rose red
    if(idx < 18.0) return vec3(1.0, 0.5, 0.6);      // Salmon pink
    
    // ORANGES & YELLOWS
    if(idx < 19.0) return vec3(1.0, 0.5, 0.2);      // Bright orange
    if(idx < 20.0) return vec3(1.0, 0.7, 0.3);      // Gold
    if(idx < 21.0) return vec3(1.0, 0.85, 0.5);     // Yellow
    if(idx < 22.0) return vec3(0.95, 0.6, 0.3);     // Amber
    
    // CYANS & TEALS
    if(idx < 23.0) return vec3(0.2, 0.9, 0.9);      // Bright cyan
    if(idx < 24.0) return vec3(0.3, 0.8, 0.7);      // Teal
    if(idx < 25.0) return vec3(0.4, 1.0, 0.9);      // Aqua
    
    // MIXED/SPECIAL
    if(idx < 26.0) return vec3(0.9, 0.7, 1.0);      // Lavender
    if(idx < 27.0) return vec3(1.0, 0.6, 0.8);      // Pink-salmon
    if(idx < 28.0) return vec3(0.6, 0.9, 0.6);      // Pale green
    if(idx < 29.0) return vec3(0.9, 0.4, 0.9);      // Orchid
    
    return vec3(0.8, 0.5, 1.0);                      // Violet-pink
}

// Turbulent FBM for complex gas structures
float turbulentFbm(vec3 p)
{
    float value = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 4; i++)
    {
        value += amp * abs(noise3D(p) * 2.0 - 1.0);
        p *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// ============================================================================
// DISCRETE STAR FIELD - generates actual point-like stars, not smooth noise
// Returns brightness of nearest star and distance to it
// ============================================================================
vec2 starField(vec2 uv, float density, float seed)
{
    // Grid-based approach for discrete stars
    vec2 gridSize = vec2(density);
    vec2 gridUV = uv * gridSize;
    vec2 gridCell = floor(gridUV);
    vec2 gridFract = fract(gridUV);
    
    float minDist = 1.0;
    float starBright = 0.0;
    
    // Check 3x3 neighborhood
    for(float y = -1.0; y <= 1.0; y++)
    {
        for(float x = -1.0; x <= 1.0; x++)
        {
            vec2 neighbor = vec2(x, y);
            vec2 cell = gridCell + neighbor;
            
            // Random position within cell
            float cellHash = hash(cell + seed);
            vec2 starPos = hash3(vec3(cell, seed)).xy;
            
            // Only some cells have stars (sparse)
            if(cellHash > 0.7)  // 30% of cells have stars
            {
                vec2 diff = neighbor + starPos - gridFract;
                float dist = length(diff);
                
                if(dist < minDist)
                {
                    minDist = dist;
                    // Vary star brightness
                    starBright = 0.5 + hash(cell.x * 13.0 + cell.y * 57.0 + seed) * 0.5;
                }
            }
        }
    }
    
    // Sharp star point - very small radius
    float star = smoothstep(0.08, 0.01, minDist) * starBright;
    
    return vec2(star, minDist);
}

// Multi-scale star field for different star populations
float multiStarField(vec2 uv, float seed)
{
    float stars = 0.0;
    
    // Bright sparse stars
    vec2 s1 = starField(uv, 30.0, seed);
    stars += s1.x * 1.2;
    
    // Medium density stars
    vec2 s2 = starField(uv, 60.0, seed + 100.0);
    stars += s2.x * 0.8;
    
    // Dense faint star background
    vec2 s3 = starField(uv, 120.0, seed + 200.0);
    stars += s3.x * 0.5;
    
    // Very dense tiny stars
    vec2 s4 = starField(uv, 200.0, seed + 300.0);
    stars += s4.x * 0.3;
    
    return min(stars, 1.5);
}

// Swirling gas texture - creates visible gas lanes and structure
float swirlGas(vec2 uv, float ang, float r, float seed, float tightness)
{
    // Spiral coordinate
    float spiralAng = ang - r * tightness;
    
    // Multiple layers of turbulent gas
    float gas = 0.0;
    
    // Large scale gas lanes
    float lane1 = sin(spiralAng * 2.0 + seed) * 0.5 + 0.5;
    lane1 = pow(lane1, 0.7);
    
    // Medium turbulence
    vec3 p = vec3(uv * 15.0, seed);
    float turb1 = turbulentFbm(p);
    
    // Fine turbulence
    float turb2 = turbulentFbm(p * 3.0 + 10.0);
    
    gas = lane1 * (0.6 + turb1 * 0.4) * (0.8 + turb2 * 0.2);
    
    return gas;
}

// Complex emission nebula - like Hubble images
vec4 renderNebula(vec3 rd, vec3 center, float size, float seed)
{
    vec3 toCenter = rd - center;
    float dist = length(toCenter);
    if(dist > size * 3.0) return vec4(0.0);
    
    vec3 localP = toCenter / size;
    
    // Multi-layered turbulent structure
    float turb1 = turbulentFbm(localP * 3.0 + vec3(seed));
    float turb2 = turbulentFbm(localP * 6.0 + vec3(seed * 1.3));
    float turb3 = turbulentFbm(localP * 12.0 + vec3(seed * 1.7));
    
    // Wispy, filamentary structure
    float wisps = pow(turb1, 1.5) + pow(turb2, 2.0) * 0.5 + pow(turb3, 2.5) * 0.25;
    
    // Edge enhancement for that characteristic nebula look
    float edge = smoothstep(size * 2.5, size * 0.5, dist);
    float density = wisps * edge * edge;
    
    // Dark lanes (absorption)
    float darkLanes = 1.0 - pow(turb2, 0.5) * 0.6;
    density *= darkLanes;
    
    // Color: warm in dense regions, blue in thin ionized edges
    vec3 warmCol = hubbleColor(seed);
    vec3 coolCol = hubbleColor(seed + 5.0);
    vec3 hotCol = vec3(1.0, 0.9, 0.8); // Hot star illumination
    
    float colorMix = turb1;
    vec3 col = mix(warmCol, coolCol, colorMix);
    
    // Bright rims and edges (ionization fronts)
    float rim = smoothstep(size * 0.8, size * 1.5, dist) * smoothstep(size * 2.0, size * 1.5, dist);
    col = mix(col, hotCol, rim * 0.5);
    
    return vec4(col * density * 1.5, density);
}

// Sharp, detailed galaxy rendering - like actual Hubble images
vec4 renderGalaxy(vec3 rd, vec3 galaxyPos, float galaxySize, float seed, float time)
{
    seed = seed + sessionSeed;
    
    // Quick rejection for galaxies far from view direction (no visible boundary)
    float viewDist = length(rd - normalize(galaxyPos));
    if(viewDist > galaxySize * 3.0) return vec4(0.0);
    
    // Galaxy orientation - VARIED viewing angles
    // Use seed to determine inclination - some face-on, some edge-on, some tilted
    float inclinationType = hash(seed * 5.5);
    vec3 n;
    
    if(inclinationType < 0.25)
    {
        // Face-on (looking down the axis) - ~25%
        n = normalize(rd);  // Normal points toward camera
        n += (hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) - 0.5) * 0.3;  // Small random tilt
        n = normalize(n);
    }
    else if(inclinationType < 0.45)
    {
        // Edge-on (~20%)
        vec3 randDir = normalize(hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) * 2.0 - 1.0);
        n = normalize(cross(rd, randDir));  // Perpendicular to view
        n += (hash3(vec3(seed * 4.1, seed * 5.3, seed * 6.7)) - 0.5) * 0.2;
        n = normalize(n);
    }
    else
    {
        // Random tilt (~55%) - the default varied orientation
        n = normalize(hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) * 2.0 - 1.0);
    }
    
    vec3 t = normalize(cross(n, vec3(0.0, 1.0, 0.1)));
    if(length(cross(n, vec3(0.0, 1.0, 0.1))) < 0.1) t = normalize(cross(n, vec3(1.0, 0.0, 0.1)));
    vec3 b = cross(n, t);
    
    vec3 localRd = rd - normalize(galaxyPos);
    float planeDist = dot(localRd, n);
    vec2 uv = vec2(dot(localRd, t), dot(localRd, b));
    
    float r = length(uv);
    
    // Early exit if outside galaxy radius - no visible edge artifact
    if(r > galaxySize * 1.2) return vec4(0.0);
    
    float ang = atan(uv.y, uv.x);
    
    // Unique per-galaxy parameters
    float rotAng = seed * 10.0 + time * (hash(seed * 8.0) - 0.5) * 0.2;
    float gtype = hash(seed * 7.0);
    
    vec3 color = vec3(0.0);
    float bright = 0.0;
    
    // Noise coordinates
    vec2 nuv = uv / galaxySize;
    
    // DISCRETE STAR FIELD for visible individual stars
    float stars = multiStarField(nuv * 1.2, seed);
    
    // Gas and dust textures
    float gasNoise = turbulentFbm(vec3(nuv * 10.0, seed * 2.1));
    float dustNoise = turbulentFbm(vec3(nuv * 15.0, seed * 2.5));
    float gasSwirl = swirlGas(nuv, ang, r / galaxySize, seed, 5.0);
    
    // GALAXY TYPE SELECTION - much more variety
    if(gtype < 0.30)
    {
        // === GRAND DESIGN SPIRAL (M51/Whirlpool style) ===
        float numArms = 2.0;
        float pitch = 0.35 + hash(seed * 14.0) * 0.25;
        
        // Logarithmic spiral arms
        float logR = log(r / galaxySize * 20.0 + 1.0);
        float spiralAngle = ang + rotAng - logR / pitch;
        
        // THIN arm structure - narrower arms like in real spirals
        float armPhase = mod(spiralAngle * numArms / 6.28 + 0.5, 1.0);
        float armBase = smoothstep(0.38, 0.46, armPhase) * smoothstep(0.62, 0.54, armPhase);
        
        // Add noise to arm edges for irregular, wispy look
        float armNoise = noise3D(vec3(nuv * 50.0 + spiralAngle, seed * 3.0));
        float arm = armBase * (0.6 + armNoise * 0.6);
        arm *= max(0.0, 1.0 - r / galaxySize);
        arm *= arm;  // Square it to make arms more defined with darker gaps
        
        // Thin dust lanes
        float dustPhase = mod(spiralAngle * numArms / 6.28 + 0.51, 1.0);
        float dustBase = smoothstep(0.42, 0.46, dustPhase) * smoothstep(0.52, 0.48, dustPhase);
        float dust = dustBase * (0.4 + dustNoise * 0.6);
        dust *= smoothstep(galaxySize * 0.08, galaxySize * 0.35, r);
        dust *= max(0.0, 1.0 - r / (galaxySize * 0.8));
        
        // Small bright HII knots scattered in arms
        float hiiKnots = 0.0;
        for(float k = 0.0; k < 20.0; k++)
        {
            float kSeed = seed + k * 73.0;
            float kAng = hash(kSeed) * 6.28;
            float kR = (0.12 + hash(kSeed + 1.0) * 0.65) * galaxySize;
            vec2 kPos = vec2(cos(kAng + rotAng), sin(kAng + rotAng)) * kR;
            float kDist = length(uv - kPos);
            float kSize = galaxySize * (0.004 + hash(kSeed + 3.0) * 0.012);  // Smaller knots
            float knot = smoothstep(kSize, kSize * 0.1, kDist);  // Sharper edges
            hiiKnots += knot * arm * hash(kSeed + 2.0);
        }
        
        // Blue star clusters - small and bright
        float blueClusters = 0.0;
        for(float s = 0.0; s < 15.0; s++)
        {
            float sSeed = seed + s * 91.0 + 500.0;
            float sAng = hash(sSeed) * 6.28;
            float sR = (0.15 + hash(sSeed + 1.0) * 0.6) * galaxySize;
            vec2 sPos = vec2(cos(sAng + rotAng), sin(sAng + rotAng)) * sR;
            float sDist = length(uv - sPos);
            float sSize = galaxySize * (0.003 + hash(sSeed + 2.0) * 0.01);  // Smaller
            blueClusters += smoothstep(sSize, sSize * 0.1, sDist) * arm * hash(sSeed + 3.0);
        }
        
        // Compact central bulge
        float bulge = smoothstep(galaxySize * 0.12, galaxySize * 0.01, r);
        bulge *= bulge;  // Make it more concentrated
        
        // Bright compact core
        float core = smoothstep(galaxySize * 0.025, galaxySize * 0.002, r);
        
        // Stars appear as sparse points within the arm structure
        float armStars = arm * stars;
        float bulgeStars = bulge * stars;
        
        bright = armStars * 0.8 + bulgeStars * 0.6 + core * 0.5 + hiiKnots * 0.7 + blueClusters * 0.5;
        bright = max(bright - dust * 0.4, 0.0);
        
        // === RICH COLOR MIXING ===
        // Arm colors vary with radius (bluer outer, redder inner)
        float radialGrad = r / galaxySize;
        vec3 innerArmCol = vec3(1.0, 0.85, 0.7);   // Warm inner arms
        vec3 outerArmCol = vec3(0.6, 0.75, 1.0);   // Blue outer arms
        vec3 armCol = mix(innerArmCol, outerArmCol, radialGrad);
        
        // Add color variation from gas
        vec3 gasCol1 = hubbleColor(seed * 10.0);
        vec3 gasCol2 = hubbleColor(seed * 11.0);
        armCol = mix(armCol, gasCol1, gasNoise * 0.3);
        armCol = mix(armCol, gasCol2, (1.0 - gasNoise) * stars * 0.2);
        
        // Bulge gradient (yellow center to red edge)
        vec3 bulgeInner = vec3(1.0, 0.95, 0.85);
        vec3 bulgeOuter = vec3(1.0, 0.75, 0.5);
        vec3 bulgeCol = mix(bulgeInner, bulgeOuter, r / (galaxySize * 0.2));
        
        // Core is hot white/blue
        vec3 coreCol = vec3(1.0, 0.98, 1.0);
        
        // HII regions are pink/magenta
        vec3 hiiCol = mix(vec3(1.0, 0.3, 0.5), vec3(1.0, 0.5, 0.7), hash(seed * 20.0));
        
        // Blue clusters
        vec3 blueCol = vec3(0.4, 0.6, 1.0);
        
        // Dust is dark brown/red
        vec3 dustCol = vec3(0.25, 0.12, 0.06);
        
        // Combine all colors
        color = armCol * armStars * 1.0;
        color += bulgeCol * bulgeStars * 0.8;
        color = mix(color, coreCol * 0.6, core * 0.4);
        color = mix(color, dustCol, dust * 0.3);
        color += hiiCol * hiiKnots * 1.0;
        color += blueCol * blueClusters * 0.9;
    }
    else if(gtype < 0.45)
    {
        // === BARRED SPIRAL (NGC 1300 style) ===
        vec2 ruv = uv * rot2D(seed * 2.0 + rotAng * 0.1);
        float barLen = 0.3 * galaxySize;
        float barWidth = 0.06 * galaxySize;  // Thinner bar
        
        // Bar structure with sparse stars
        float barBase = smoothstep(barWidth, barWidth * 0.3, abs(ruv.y));
        barBase *= smoothstep(barLen, barLen * 0.5, abs(ruv.x));
        barBase *= barBase;  // Sharper edges
        float barStars = barBase * stars;
        
        // Thin dust lanes
        float barDust = smoothstep(barWidth * 0.5, barWidth * 0.15, abs(ruv.y));
        barDust *= smoothstep(barLen * 0.2, barLen * 0.75, abs(ruv.x));
        barDust *= dustNoise * 0.6;
        
        // THINNER arms emerging from bar ends
        float arms = 0.0;
        for(float side = -1.0; side <= 1.0; side += 2.0)
        {
            vec2 armStart = vec2(side * barLen * 0.8, 0.0);
            vec2 toP = ruv - armStart;
            float armR = length(toP);
            float armA = atan(toP.y, toP.x * side);
            
            float spiral = armA - armR * 3.0 / galaxySize;
            float armNoise = noise3D(vec3(toP / galaxySize * 30.0, seed * 4.0));
            float armVal = smoothstep(0.5, 0.35, abs(mod(spiral, 3.14) - 1.57));  // Thinner
            armVal *= (0.5 + armNoise * 0.6);
            armVal *= max(0.0, 1.0 - armR / galaxySize);
            armVal *= armVal;  // Sharper
            arms += armVal;
        }
        
        // Small HII knots
        float hii = 0.0;
        for(float k = 0.0; k < 12.0; k++)
        {
            float kSeed = seed + k * 67.0;
            vec2 kPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 1.2;
            float kDist = length(uv - kPos);
            float kSize = galaxySize * (0.004 + hash(kSeed + 1.0) * 0.01);  // Smaller
            hii += smoothstep(kSize, kSize * 0.1, kDist) * arms * hash(kSeed + 2.0);
        }
        
        float core = smoothstep(galaxySize * 0.06, galaxySize * 0.005, r);
        
        // Sparse star points
        float armStars = arms * stars;
        bright = barStars * 0.6 + armStars * 0.7 + core * 0.5 + hii * 0.6;
        bright = max(bright - barDust * 0.35, 0.0);
        
        // Rich color mixing
        vec3 barInner = vec3(1.0, 0.9, 0.75);
        vec3 barOuter = vec3(0.9, 0.7, 0.5);
        vec3 barCol = mix(barInner, barOuter, abs(ruv.x) / barLen);
        barCol *= (0.8 + stars * 0.4);
        
        vec3 armCol = mix(vec3(0.7, 0.8, 1.0), vec3(0.9, 0.85, 0.8), gasNoise);
        vec3 coreCol = vec3(1.0, 0.95, 0.9);
        vec3 hiiCol = vec3(1.0, 0.4, 0.6);
        vec3 dustCol = vec3(0.2, 0.1, 0.05);
        
        color = barCol * barStars * 1.0;
        color += armCol * armStars * 1.0;
        color = mix(color, coreCol * 0.6, core * 0.4);
        color = mix(color, dustCol, barDust * 0.25);
        color += hiiCol * hii * 1.0;
    }
    else if(gtype < 0.55)
    {
        // === EDGE-ON SPIRAL (NGC 4565 style) ===
        vec2 ruv = uv * rot2D(seed * 3.0);
        
        // THIN edge-on disk with sparse stars
        float diskHeight = 0.018 * galaxySize;  // Thinner
        float diskBase = smoothstep(diskHeight * 1.5, diskHeight * 0.15, abs(ruv.y));
        diskBase *= max(0.0, 1.0 - abs(ruv.x) / galaxySize);
        diskBase *= diskBase;  // Sharper edges
        float diskStars = diskBase * stars;
        
        // Sharp dust lane
        float dustLane = smoothstep(diskHeight * 0.8, diskHeight * 0.1, abs(ruv.y));
        dustLane *= smoothstep(galaxySize * 0.08, galaxySize * 0.55, abs(ruv.x));
        dustLane *= (0.4 + dustNoise * 0.6);
        
        // Compact bulge
        float bulgeBase = smoothstep(galaxySize * 0.08, galaxySize * 0.005, length(ruv));
        bulgeBase *= bulgeBase;
        float bulgeStars = bulgeBase * stars;
        
        bright = diskStars * 0.7 + bulgeStars * 0.6;
        bright = max(bright - dustLane * 0.5, 0.0);
        
        // Color gradient along disk
        float xGrad = abs(ruv.x) / galaxySize;
        vec3 diskInner = vec3(1.0, 0.9, 0.75);
        vec3 diskOuter = vec3(0.7, 0.8, 1.0);
        vec3 diskCol = mix(diskInner, diskOuter, xGrad);
        
        vec3 bulgeCol = vec3(1.0, 0.88, 0.7);
        vec3 dustCol = vec3(0.15, 0.08, 0.03);
        
        color = diskCol * diskStars * 1.1;
        color += bulgeCol * bulgeStars * 0.9;
        color = mix(color, dustCol, dustLane * 0.25);
    }
    else if(gtype < 0.70)
    {
        // === INTERACTING GALAXIES (Arp 248 style) ===
        // Primary galaxy with spiral structure
        float r1 = r;
        float ang1 = ang;
        float spiral1 = 0.5 + 0.5 * sin(ang1 * 2.0 - r1 * 5.0 / galaxySize + rotAng);
        float gal1Base = smoothstep(galaxySize * 0.4, galaxySize * 0.02, r1);
        gal1Base *= gal1Base;  // More concentrated
        gal1Base *= (0.5 + spiral1 * 0.5);
        float gal1Stars = gal1Base * stars;
        float core1 = smoothstep(galaxySize * 0.05, galaxySize * 0.005, r1);
        
        // Secondary galaxy
        vec2 g2Offset = vec2(0.6, 0.35) * galaxySize * (hash(seed * 24.0) * 0.4 + 0.6);
        g2Offset *= rot2D(seed * 5.0);
        float r2 = length(uv - g2Offset);
        float ang2 = atan(uv.y - g2Offset.y, uv.x - g2Offset.x);
        float spiral2 = 0.5 + 0.5 * sin(ang2 * 2.0 + r2 * 6.0 / galaxySize);
        vec2 nuv2 = (uv - g2Offset) / galaxySize;
        float stars2 = pow(noise3D(vec3(nuv2 * 300.0, seed * 5.0)), 3.0);
        stars2 = smoothstep(0.2, 0.8, stars2);
        float gal2Base = smoothstep(galaxySize * 0.35, galaxySize * 0.02, r2);
        gal2Base *= gal2Base;
        gal2Base *= (0.4 + spiral2 * 0.5);
        float gal2Stars = gal2Base * stars2;
        float core2 = smoothstep(galaxySize * 0.04, galaxySize * 0.003, r2);
        
        // THIN WISPY tidal tails like in Arp 248
        float tailAng = atan(g2Offset.y, g2Offset.x);
        
        // Tail 1 - thin stream
        float t1Phase = ang1 - tailAng - r1 * 2.0 / galaxySize;
        float tail1Width = smoothstep(0.5, 0.1, abs(mod(t1Phase + 3.14, 6.28) - 3.14));  // Thinner
        tail1Width *= smoothstep(0.0, 0.15 * galaxySize, r1);
        tail1Width *= max(0.0, 1.0 - r1 / (galaxySize * 1.5));
        tail1Width *= tail1Width;  // Square for sharper edges
        float tail1Stars = tail1Width * stars * 0.6;
        
        // Tail 2 - thin stream
        float t2Phase = ang2 - tailAng + 3.14 + r2 * 2.5 / galaxySize;
        float tail2Width = smoothstep(0.45, 0.1, abs(mod(t2Phase + 3.14, 6.28) - 3.14));
        tail2Width *= smoothstep(0.0, 0.12 * galaxySize, r2);
        tail2Width *= max(0.0, 1.0 - r2 / (galaxySize * 1.3));
        tail2Width *= tail2Width;
        float tail2Stars = tail2Width * stars2 * 0.5;
        
        // Thin bridge connecting galaxies
        vec2 bridgeDir = normalize(g2Offset);
        float bridgeDist = dot(uv, bridgeDir);
        float bridgePerp = abs(dot(uv, vec2(-bridgeDir.y, bridgeDir.x)));
        float bridgeLen = length(g2Offset);
        float bridgeBase = smoothstep(galaxySize * 0.025, galaxySize * 0.005, bridgePerp);  // Much thinner
        bridgeBase *= smoothstep(0.0, bridgeLen * 0.25, bridgeDist);
        bridgeBase *= smoothstep(bridgeLen, bridgeLen * 0.65, bridgeDist);
        float bridgeStars = bridgeBase * stars * 0.4;
        
        // Small bright blue knots along tails/bridge
        float knots = 0.0;
        for(float k = 0.0; k < 15.0; k++)
        {
            float kSeed = seed + k * 47.0;
            float kT = hash(kSeed) * 0.9 + 0.05;
            vec2 kPos = mix(vec2(0.0), g2Offset, kT);
            kPos += (hash3(vec3(kSeed)).xy - 0.5) * 0.15 * galaxySize;
            float kDist = length(uv - kPos);
            float kSize = galaxySize * (0.003 + hash(kSeed + 3.0) * 0.008);  // Smaller knots
            knots += smoothstep(kSize, kSize * 0.1, kDist) * (tail1Width + tail2Width + bridgeBase) * hash(kSeed + 2.0);
        }
        
        bright = gal1Stars * 0.7 + gal2Stars * 0.6 + core1 * 0.5 + core2 * 0.4;
        bright += tail1Stars * 0.8 + tail2Stars * 0.7 + bridgeStars * 0.6 + knots * 0.8;
        
        // Colors
        float radGrad1 = r1 / (galaxySize * 0.4);
        float radGrad2 = r2 / (galaxySize * 0.35);
        vec3 gal1Inner = vec3(1.0, 0.85, 0.65);
        vec3 gal1Outer = vec3(0.6, 0.75, 1.0);
        vec3 gal1Col = mix(gal1Inner, gal1Outer, radGrad1);
        
        vec3 gal2Inner = vec3(1.0, 0.8, 0.6);
        vec3 gal2Outer = vec3(0.55, 0.7, 1.0);
        vec3 gal2Col = mix(gal2Inner, gal2Outer, radGrad2);
        
        vec3 coreCol = vec3(1.0, 0.95, 0.85);
        vec3 tailCol = vec3(0.65, 0.8, 1.0);  // Bluish tails
        vec3 knotCol = vec3(0.5, 0.7, 1.0);   // Blue knots
        
        color = gal1Col * gal1Stars * 1.1 + gal2Col * gal2Stars * 1.0;
        color = mix(color, coreCol, (core1 + core2) * 0.4);
        color += tailCol * (tail1Stars + tail2Stars + bridgeStars) * 1.0;
        color += knotCol * knots * 0.9;
    }
    else if(gtype < 0.82)
    {
        // === ELLIPTICAL GALAXY ===
        float ellip = 0.3 + hash(seed * 26.0) * 0.5;
        vec2 euv = uv * rot2D(seed * 4.0);
        euv.y /= ellip;
        float eR = length(euv);
        
        // Elliptical - sparse star points
        float profileBase = max(0.0, 1.0 - eR / (galaxySize * 0.4));
        profileBase = profileBase * profileBase * profileBase;  // More concentrated
        float profileStars = profileBase * stars;
        float core = smoothstep(galaxySize * 0.05, galaxySize * 0.003, eR);
        
        bright = profileStars * 0.7 + core * 0.5;
        
        // Color gradient from center outward
        float colorGrad = eR / (galaxySize * 0.4);
        vec3 coreCol = vec3(1.0, 0.95, 0.88);
        vec3 midCol = vec3(1.0, 0.82, 0.6);
        vec3 outerCol = vec3(0.85, 0.6, 0.45);
        vec3 ellipCol = mix(coreCol, midCol, min(colorGrad, 1.0));
        ellipCol = mix(ellipCol, outerCol, max(0.0, colorGrad - 0.5) * 2.0);
        ellipCol *= (0.85 + stars * 0.3);
        
        color = ellipCol * profileStars * 1.0;
        color = mix(color, coreCol * 0.6, core * 0.4);
    }
    else if(gtype < 0.92)
    {
        // === RING GALAXY (Hoag's Object style) ===
        float ringR = 0.5 * galaxySize;
        float ringW = 0.04 * galaxySize;  // Thinner ring
        
        // Ring - stars defines visible individual stars
        float ringBase = smoothstep(ringW, ringW * 0.1, abs(r - ringR));
        float ringStars = ringBase * stars;
        
        // Star forming knots around ring - use stars
        float knotSum = 0.0;
        for(float k = 0.0; k < 12.0; k++)
        {
            float kSeed = seed + k * 53.0;
            float kAng = k * 6.28 / 12.0 + hash(kSeed) * 0.5;
            vec2 kPos = vec2(cos(kAng), sin(kAng)) * ringR;
            float kDist = length(uv - kPos);
            float kSize = galaxySize * (0.01 + hash(kSeed + 1.0) * 0.015);  // Smaller knots
            knotSum += smoothstep(kSize * 1.2, kSize * 0.15, kDist) * hash(kSeed + 2.0);
        }
        float knots = knotSum * ringBase * stars;  // Knots also use stars
        
        // Central elliptical with star texture
        float coreBase = smoothstep(galaxySize * 0.08, galaxySize * 0.01, r);  // Smaller core
        float coreStars = coreBase * stars * 0.7;
        
        bright = ringStars * 0.5 + knots * 0.4 + coreStars * 0.4;
        
        // Ring is blue with pink knots
        vec3 ringCol = vec3(0.5, 0.7, 1.0);
        vec3 knotCol = vec3(1.0, 0.45, 0.65);
        vec3 coreCol = vec3(1.0, 0.88, 0.72);
        
        color = ringCol * ringStars * 1.0;
        color += knotCol * knots * 0.9;
        color += coreCol * coreStars * 0.7;
    }
    else
    {
        // === IRREGULAR GALAXY (LMC/SMC style) ===
        // Use sparse stars for visible individual stars
        
        // Chaotic structure noise
        float n1 = turbulentFbm(vec3(nuv * 3.0, seed * 3.0));
        float n2 = turbulentFbm(vec3(nuv * 5.0 + 10.0, seed * 3.5));
        float n3 = turbulentFbm(vec3(nuv * 7.0 + 20.0, seed * 4.0));
        
        // Chaotic structural mask - stars only visible where structure is
        float structMask = smoothstep(0.3, 0.6, n1) + smoothstep(0.4, 0.7, n2) * 0.5;
        structMask *= max(0.0, 1.0 - r / galaxySize);
        structMask *= structMask;
        
        // Stars define the visible structure - use sparse stars
        float visibleStars = structMask * stars;
        
        // Clumps are high-density star regions with point-like stars
        float clump1 = smoothstep(0.55, 0.8, n1 * n2) * stars;
        float clump2 = smoothstep(0.5, 0.75, n2 * n3) * stars;
        
        // Star forming regions - bright blue knots
        float sfr = smoothstep(0.6, 0.9, n2 * n3) * structMask * stars;
        
        bright = visibleStars * 0.4 + clump1 * 0.3 + clump2 * 0.25 + sfr * 0.3;
        
        // Color palette
        vec3 baseCol = hubbleColor(seed * 22.0);
        vec3 clump1Col = hubbleColor(seed * 23.0 + 8.0);
        vec3 clump2Col = hubbleColor(seed * 24.0 + 15.0);
        vec3 sfrCol = vec3(0.5, 0.7, 1.0);  // Blue star forming regions
        
        // Color follows the star structure
        color = baseCol * visibleStars * 0.9;
        color += clump1Col * clump1 * 0.8;
        color += clump2Col * clump2 * 0.7;
        color += sfrCol * sfr * 0.9;
    }
    
    // Final output - balanced brightness
    vec3 finalColor = color * 1.2;
    
    // Clamp to prevent blowout
    finalColor = clamp(finalColor, 0.0, 0.75);
    
    return vec4(finalColor, bright);
}

// ============================================================================
// ULTRA-DETAILED NEARFIELD GALAXY - Like actual Hubble images
// This is for 1-3 massive galaxies that fill a significant portion of view
// ============================================================================
vec4 renderNearfieldGalaxy(vec3 rd, vec3 galaxyPos, float galaxySize, float seed, float time)
{
    seed = seed + sessionSeed;
    
    // Quick rejection
    float viewDist = length(rd - normalize(galaxyPos));
    if(viewDist > galaxySize * 2.5) return vec4(0.0);
    
    // Galaxy plane orientation - bias toward face-on for detail visibility
    float inclinationType = hash(seed * 5.5);
    vec3 n;
    
    if(inclinationType < 0.6)
    {
        // Mostly face-on to show arm detail
        n = normalize(rd);
        n += (hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) - 0.5) * 0.4;
        n = normalize(n);
    }
    else if(inclinationType < 0.8)
    {
        // Tilted - like the reference image
        n = normalize(rd);
        n += (hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) - 0.5) * 0.8;
        n = normalize(n);
    }
    else
    {
        // Edge-on
        vec3 randDir = normalize(hash3(vec3(seed * 1.1, seed * 2.3, seed * 3.7)) * 2.0 - 1.0);
        n = normalize(cross(rd, randDir));
    }
    
    vec3 t = normalize(cross(n, vec3(0.0, 1.0, 0.1)));
    if(length(cross(n, vec3(0.0, 1.0, 0.1))) < 0.1) t = normalize(cross(n, vec3(1.0, 0.0, 0.1)));
    vec3 b = cross(n, t);
    
    vec3 localRd = rd - normalize(galaxyPos);
    vec2 uv = vec2(dot(localRd, t), dot(localRd, b));
    float r = length(uv);
    
    if(r > galaxySize * 1.3) return vec4(0.0);
    
    float ang = atan(uv.y, uv.x);
    vec2 nuv = uv / galaxySize;
    
    // ========== DISCRETE STAR FIELD - actual point-like stars ==========
    float stars = multiStarField(nuv * 1.5, seed);
    
    // Additional very bright foreground stars
    vec2 brightStar = starField(nuv * 0.8, 15.0, seed + 500.0);
    stars += brightStar.x * 1.5;
    
    // ========== SWIRLING GAS TEXTURE ==========
    float armTightness = 5.0 + hash(seed * 12.0) * 3.0;
    float gasSwirl = swirlGas(nuv, ang, r / galaxySize, seed, armTightness);
    
    // Multi-scale gas turbulence
    float gas1 = turbulentFbm(vec3(nuv * 8.0, seed * 2.5));
    float gas2 = turbulentFbm(vec3(nuv * 20.0, seed * 2.8));
    float gas3 = noise3D(vec3(nuv * 50.0, seed * 3.1));
    float gasNoise = gas1 * 0.5 + gas2 * 0.3 + gas3 * 0.2;
    
    // Dust lanes - dark absorption
    float dust1 = turbulentFbm(vec3(nuv * 12.0, seed * 3.5));
    float dust2 = noise3D(vec3(nuv * 25.0, seed * 3.8));
    float dustNoise = dust1 * 0.6 + dust2 * 0.4;
    
    vec3 color = vec3(0.0);
    float bright = 0.0;
    
    // Force barred spiral like reference image (or regular spiral)
    float gtype = hash(seed * 7.0);
    
    if(gtype < 0.7)
    {
        // ===== BARRED SPIRAL (like Hubble reference image) =====
        
        float barAng = seed * 3.14159;
        mat2 barRot = rot2D(barAng);
        vec2 ruv = barRot * uv;
        
        float barLen = galaxySize * 0.35;
        float barWidth = galaxySize * 0.1;
        
        // Bar shape
        float barX = abs(ruv.x) / barLen;
        float barTaper = 1.0 - smoothstep(0.5, 1.0, barX);
        float barY = abs(ruv.y) / (barWidth * barTaper + 0.001);
        float bar = smoothstep(1.0, 0.6, max(barX, barY * 0.8));
        
        // Dark dust lane through bar
        float barDustLane = smoothstep(barWidth * 0.4, barWidth * 0.05, abs(ruv.y));
        barDustLane *= smoothstep(0.0, barLen * 0.7, abs(ruv.x));
        
        // ===== SPIRAL ARMS with visible structure =====
        float numArms = 2.0;
        float arms = 0.0;
        
        for(float a = 0.0; a < numArms; a++)
        {
            float armPhase = a * 3.14159 + barAng;
            float armAng = ang - armPhase - r * armTightness / galaxySize;
            
            // Arm core
            float armWave = 0.5 + 0.5 * sin(armAng * numArms);
            float armWidth = 0.15 + gas2 * 0.1;  // Vary width with gas
            float armCore = smoothstep(0.5 - armWidth, 0.5 - armWidth * 0.3, armWave);
            armCore *= smoothstep(0.5 + armWidth, 0.5 + armWidth * 0.3, armWave);
            
            // Feathery edges from gas turbulence
            armCore *= (0.5 + gas1 * 0.5);
            
            // Arm fades at center and outer edge
            float armFade = smoothstep(galaxySize * 0.12, galaxySize * 0.2, r);
            armFade *= smoothstep(galaxySize * 1.1, galaxySize * 0.6, r);
            
            arms += armCore * armFade;
        }
        arms = min(arms, 1.0);
        
        // ===== DARK DUST LANES winding through =====
        float dustLanes = smoothstep(0.4, 0.6, dustNoise) * arms * 0.8;
        dustLanes += barDustLane * (1.0 - bar * 0.5) * 0.6;
        
        // ===== PINK HII REGIONS scattered in arms =====
        float hii = 0.0;
        for(float h = 0.0; h < 40.0; h++)
        {
            float hSeed = seed + h * 89.0;
            float hAng = hash(hSeed) * 6.28;
            float hR = galaxySize * (0.15 + hash(hSeed + 1.0) * 0.6);
            vec2 hPos = vec2(cos(hAng), sin(hAng)) * hR;
            float hDist = length(uv - hPos);
            float hSize = galaxySize * (0.006 + hash(hSeed + 2.0) * 0.012);
            
            // Irregular clumpy shape
            float hShape = smoothstep(hSize * 1.3, hSize * 0.15, hDist);
            hShape *= (arms * 0.7 + 0.3);  // Preferentially in arms
            hii += hShape * (0.5 + hash(hSeed + 3.0) * 0.5);
        }
        hii = min(hii, 1.0);
        
        // ===== BLUE STAR CLUSTERS =====
        float blueClusters = 0.0;
        for(float c = 0.0; c < 25.0; c++)
        {
            float cSeed = seed + c * 127.0 + 1000.0;
            float cAng = hash(cSeed) * 6.28;
            float cR = galaxySize * (0.2 + hash(cSeed + 1.0) * 0.55);
            vec2 cPos = vec2(cos(cAng), sin(cAng)) * cR;
            float cDist = length(uv - cPos);
            float cSize = galaxySize * (0.003 + hash(cSeed + 2.0) * 0.006);
            
            float cluster = smoothstep(cSize * 1.2, cSize * 0.1, cDist);
            cluster *= (arms * 0.6 + 0.4);
            blueClusters += cluster * hash(cSeed + 3.0);
        }
        blueClusters = min(blueClusters, 0.8);
        
        // ===== CENTRAL BULGE =====
        float bulgeSize = galaxySize * 0.12;
        float bulge = smoothstep(bulgeSize, bulgeSize * 0.05, r);
        bulge = bulge * bulge * bulge;  // Concentrated
        
        // Nucleus
        float nucleus = smoothstep(galaxySize * 0.015, galaxySize * 0.001, r);
        
        // ===== COMBINE with DISCRETE STARS visible =====
        // Stars are visible where structure is, modulated by gas
        float armStars = arms * stars * (0.6 + gasSwirl * 0.4);
        float barStars = bar * stars * 0.7;
        float bulgeStars = bulge * stars * 0.5;
        
        // Gas glow (diffuse emission)
        float gasGlow = arms * gasSwirl * 0.3;
        gasGlow += bar * gas1 * 0.2;
        
        // Apply dust extinction
        float extinction = 1.0 - dustLanes * 0.6;
        extinction = max(extinction, 0.2);
        
        bright = (armStars + barStars + bulgeStars) * extinction + gasGlow;
        bright += hii * 0.5 + blueClusters * 0.4 + nucleus * 0.6;
        
        // ===== COLORS =====
        float radialGrad = r / galaxySize;
        vec3 innerArmCol = vec3(1.0, 0.9, 0.8);
        vec3 outerArmCol = vec3(0.6, 0.75, 1.0);
        vec3 armCol = mix(innerArmCol, outerArmCol, radialGrad);
        
        vec3 barCol = mix(vec3(1.0, 0.92, 0.8), vec3(0.95, 0.8, 0.6), abs(ruv.x) / barLen);
        vec3 bulgeCol = mix(vec3(1.0, 0.98, 0.95), vec3(1.0, 0.85, 0.65), r / bulgeSize);
        vec3 hiiCol = vec3(1.0, 0.35, 0.55);
        vec3 blueCol = vec3(0.6, 0.8, 1.0);
        vec3 dustCol = vec3(0.15, 0.08, 0.03);
        
        // Gas emission color (reddish/pink nebulosity)
        vec3 gasCol = vec3(0.9, 0.6, 0.7);
        
        color = armCol * armStars * extinction;
        color += barCol * barStars * extinction * 0.8;
        color += bulgeCol * bulgeStars * 0.6;
        color += gasCol * gasGlow * 0.5;  // Visible gas emission
        color = mix(color, vec3(1.0, 0.98, 1.0), nucleus * 0.4);
        color += hiiCol * hii * 1.0;
        color += blueCol * blueClusters * 0.9;
        color = mix(color, dustCol, dustLanes * 0.4);  // Dust darkening
    }
    else
    {
        // ===== GRAND DESIGN SPIRAL (no bar) =====
        float numArms = 2.0;
        
        float arms = 0.0;
        for(float a = 0.0; a < numArms; a++)
        {
            float armPhase = a * 3.14159;
            float armAng = ang - armPhase - r * armTightness / galaxySize;
            float armWave = 0.5 + 0.5 * sin(armAng * numArms);
            
            float armWidth = 0.12 + gas2 * 0.08;
            float armCore = smoothstep(0.5 - armWidth, 0.5 - armWidth * 0.3, armWave);
            armCore *= smoothstep(0.5 + armWidth, 0.5 + armWidth * 0.3, armWave);
            armCore *= (0.5 + gas1 * 0.5);  // Turbulent edges
            
            float armFade = smoothstep(galaxySize * 0.08, galaxySize * 0.15, r);
            armFade *= smoothstep(galaxySize * 1.1, galaxySize * 0.6, r);
            
            arms += armCore * armFade;
        }
        arms = min(arms, 1.0);
        
        // Dust lanes
        float dustLanes = smoothstep(0.45, 0.55, gasNoise) * arms * 0.7;
        
        // HII regions
        float hii = 0.0;
        for(float h = 0.0; h < 35.0; h++)
        {
            float hSeed = seed + h * 89.0;
            float hAng = hash(hSeed) * 6.28;
            float hR = galaxySize * (0.15 + hash(hSeed + 1.0) * 0.65);
            vec2 hPos = vec2(cos(hAng), sin(hAng)) * hR;
            float hDist = length(uv - hPos);
            float hSize = galaxySize * (0.006 + hash(hSeed + 2.0) * 0.012);
            float hRegion = smoothstep(hSize * 1.3, hSize * 0.1, hDist) * arms;
            hii += hRegion * hash(hSeed + 3.0);
        }
        hii = min(hii, 1.0);
        
        // Bulge
        float bulge = smoothstep(galaxySize * 0.12, galaxySize * 0.02, r);
        bulge = bulge * bulge;
        float nucleus = smoothstep(galaxySize * 0.015, galaxySize * 0.002, r);
        
        // Gas glow
        float gasGlow = arms * gasSwirl * 0.3;
        
        // Combine with discrete stars
        float armStars = arms * stars * (0.6 + gasSwirl * 0.4);
        float bulgeStars = bulge * stars * 0.5;
        float extinction = 1.0 - dustLanes * 0.6;
        extinction = max(extinction, 0.2);
        
        bright = (armStars + bulgeStars) * extinction + gasGlow;
        bright += hii * 0.5 + nucleus * 0.5;
        
        // Colors
        float radialGrad = r / galaxySize;
        vec3 armCol = mix(vec3(1.0, 0.88, 0.75), vec3(0.55, 0.7, 1.0), radialGrad);
        vec3 bulgeCol = mix(vec3(1.0, 0.97, 0.92), vec3(1.0, 0.82, 0.6), r / (galaxySize * 0.12));
        vec3 hiiCol = vec3(1.0, 0.38, 0.58);
        
        color = armCol * armStars * extinction * 1.0;
        color += bulgeCol * bulgeStars * 0.6;
        color = mix(color, vec3(1.0, 0.98, 1.0), nucleus * 0.35);
        color += hiiCol * hii * 1.0;
    }
    
    // Balanced brightness - visible but not glowing
    color *= 1.4;
    color = clamp(color, 0.0, 0.75);
    
    return vec4(color, bright);
}

// Cosmic filament structure (large scale structure of universe)
float cosmicWeb(vec3 rd, float time)
{
    float web = 0.0;
    
    // Multiple scales of filaments
    for(float scale = 1.0; scale <= 3.0; scale += 1.0)
    {
        vec3 p = rd * scale * 2.0;
        float filament = fbm(p + time * 0.01);
        filament = pow(filament, 2.0);
        web += filament / scale;
    }
    
    return web * 0.15;
}

// Giant void regions
float cosmicVoid(vec3 rd)
{
    float voids = 0.0;
    
    // Several void centers
    for(float i = 0.0; i < 4.0; i++)
    {
        vec3 voidCenter = hash3(vec3(i * 100.0)) * 2.0 - 1.0;
        float voidSize = 0.3 + hash(i * 50.0) * 0.4;
        float dist = length(rd - normalize(voidCenter));
        voids += smoothstep(voidSize, voidSize * 0.3, dist);
    }
    
    return clamp(voids, 0.0, 1.0);
}

// Generate node positions for cosmic web
vec3 getNode(float id)
{
    return normalize(hash3(vec3(id * 127.1, id * 311.7, id * 74.7)) * 2.0 - 1.0);
}

// Distance to a line segment
float distToSegment(vec3 p, vec3 a, vec3 b)
{
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Pillars of Creation style gas columns near galaxies
vec4 renderGasPillars(vec3 rd, vec3 galaxyPos, float seed, float depthScale)
{
    vec3 toGalaxy = rd - galaxyPos;
    float distToGalaxy = length(toGalaxy);
    
    // Only render pillars near galaxies
    float pillarRange = 0.15 * depthScale;
    if(distToGalaxy > pillarRange) return vec4(0.0);
    
    vec3 color = vec3(0.0);
    float totalDensity = 0.0;
    
    // Number of pillars based on seed
    float numPillars = 2.0 + floor(hash(seed) * 4.0);
    
    for(float p = 0.0; p < 6.0; p++)
    {
        if(p >= numPillars) break;
        
        // Pillar position offset from galaxy
        float pSeed = seed + p * 137.0;
        vec3 pillarOffset = (hash3(vec3(pSeed)) - 0.5) * 0.1 * depthScale;
        vec3 pillarBase = galaxyPos + pillarOffset;
        
        // Pillar direction - mostly pointing away from galaxy center
        vec3 pillarDir = normalize(pillarOffset + vec3(0.0, 0.0, 0.3) * (hash(pSeed + 1.0) - 0.3));
        
        // Pillar dimensions
        float pillarHeight = (0.03 + hash(pSeed + 2.0) * 0.05) * depthScale;
        float pillarWidth = (0.005 + hash(pSeed + 3.0) * 0.008) * depthScale;
        
        // Distance to pillar axis
        vec3 toBase = rd - pillarBase;
        float alongPillar = dot(toBase, pillarDir);
        
        // Only render along pillar length
        if(alongPillar < 0.0 || alongPillar > pillarHeight) continue;
        
        vec3 closestOnAxis = pillarBase + pillarDir * alongPillar;
        float distToAxis = length(rd - closestOnAxis);
        
        // Pillar tapers toward tip
        float taper = 1.0 - alongPillar / pillarHeight;
        float currentWidth = pillarWidth * (0.3 + taper * 0.7);
        
        if(distToAxis > currentWidth * 2.0) continue;
        
        // Density falloff
        float density = exp(-distToAxis * distToAxis / (currentWidth * currentWidth));
        
        // Add some edge detail
        float edge = 1.0 - smoothstep(currentWidth * 0.5, currentWidth, distToAxis);
        density *= edge;
        
        // Color for this pillar - pick from palette
        float colorIdx = hash(pSeed + 10.0);
        vec3 pillarColor;
        if(colorIdx < 0.2) pillarColor = vec3(0.6, 0.3, 0.1);      // Orange/brown
        else if(colorIdx < 0.4) pillarColor = vec3(0.2, 0.1, 0.05); // Dark brown
        else if(colorIdx < 0.6) pillarColor = vec3(0.4, 0.2, 0.3);  // Dusty rose
        else if(colorIdx < 0.8) pillarColor = vec3(0.3, 0.25, 0.15);// Tan
        else pillarColor = vec3(0.5, 0.15, 0.1);                    // Rust
        
        // Bright rim lighting on edges
        float rim = smoothstep(currentWidth * 0.3, currentWidth * 0.8, distToAxis);
        vec3 rimColor = vec3(1.0, 0.7, 0.4); // Golden rim light
        pillarColor = mix(pillarColor, rimColor, rim * 0.5 * taper);
        
        // Stars forming at pillar tips
        if(alongPillar > pillarHeight * 0.7)
        {
            float starGlow = (alongPillar - pillarHeight * 0.7) / (pillarHeight * 0.3);
            starGlow = pow(starGlow, 2.0);
            vec3 starColor = vec3(1.0, 0.9, 0.7);
            pillarColor = mix(pillarColor, starColor, starGlow * 0.6);
        }
        
        color += pillarColor * density;
        totalDensity += density;
    }
    
    return vec4(color, totalDensity);
}

// Galaxy cluster node with multiple galaxies at varying depths
vec4 renderGalaxyNode(vec3 rd, vec3 nodePos, float seed, float time, float depthScale)
{
    seed = seed + sessionSeed;
    
    vec3 color = vec3(0.0);
    float totalBright = 0.0;
    
    // 3-6 galaxies per cluster
    float numGalaxies = 3.0 + floor(hash(seed * 1.7) * 4.0);
    
    for(float g = 0.0; g < 6.0; g++)
    {
        if(g >= numGalaxies) break;
        
        // Scatter galaxies around node center
        float spread = 0.08 + hash(seed + g * 13.0) * 0.12;
        vec3 offset = (hash3(vec3(seed * 1.3 + g * 17.0, seed * 2.1 + g * 23.0, seed * 3.7 + g * 31.0)) - 0.5) * spread * depthScale;
        vec3 galaxyPos = nodePos + offset;
        
        // MUCH LARGER galaxy sizes in clusters
        float sizeVar = hash(seed * 4.1 + g * 41.0);
        float galaxySize = (0.03 + sizeVar * sizeVar * 0.08) * depthScale;
        
        float galSeed = seed * 137.0 + g * 251.0 + hash(seed + g) * 1000.0;
        
        vec4 gal = renderGalaxy(rd, galaxyPos, galaxySize, galSeed, time);
        color += gal.rgb;
        totalBright += gal.a;
    }
    
    return vec4(color, totalBright);
}

// Chaotic Hubble deep field style - galaxies, clusters, filaments only
vec3 cosmicWebBackground(vec3 rd, float time)
{
    // ========== LAYER DISTANCE/SIZE CONSTANTS ==========
    // Adjust these to control how close/large each layer appears
    
    // Layer 1: Very distant - tiny fuzzy blobs
    const float LAYER1_COUNT = 80.0;
    const float LAYER1_MIN_SIZE = 0.003;
    const float LAYER1_MAX_SIZE = 0.008;
    const float LAYER1_BRIGHTNESS = 0.4;
    
    // Layer 2: Medium distance - should start showing some shape
    const float LAYER2_COUNT = 40.0;
    const float LAYER2_MIN_SIZE = 0.025;
    const float LAYER2_MAX_SIZE = 0.06;
    const float LAYER2_BRIGHTNESS = 0.5;
    
    // Layer 3: Galaxy groups/clusters
    const float LAYER3_COUNT = 40.0;
    const float LAYER3_SCALE = 2.5;
    const float LAYER3_BRIGHTNESS = 0.6;
    
    // Layer 4: Prominent nearby - clearly visible structure
    const float LAYER4_COUNT = 15.0;
    const float LAYER4_MIN_SIZE = 1.0;
    const float LAYER4_MAX_SIZE = 1.0;
    const float LAYER4_BRIGHTNESS = 0.8;
    
    // Layer 5: Nearfield - detailed galaxies
    const float LAYER5_COUNT = 8.0;
    const float LAYER5_MIN_SIZE = 1.0;
    const float LAYER5_MAX_SIZE = 1.0;
    const float LAYER5_BRIGHTNESS = 1.0;
    
    // Dark background
    vec3 color = vec3(0.002, 0.001, 0.004);
    
    // ========== LAYER 1: DISTANT TINY GALAXIES ==========
    for(float i = 0.0; i < LAYER1_COUNT; i++)
    {
        float seed = sessionSeed + i * 271.0;
        vec3 gPos = normalize(hash3(vec3(seed, seed * 1.7, seed * 2.3)) * 2.0 - 1.0);
        float gSize = LAYER1_MIN_SIZE + hash(seed * 1.2) * (LAYER1_MAX_SIZE - LAYER1_MIN_SIZE);
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 100.0, time);
        color += g.rgb * LAYER1_BRIGHTNESS;
    }
    
    // ========== LAYER 2: MEDIUM DISTANCE GALAXIES ==========
    // These should show basic shape - spiral vs elliptical distinguishable
    for(float i = 0.0; i < LAYER2_COUNT; i++)
    {
        float seed = sessionSeed * 2.0 + i * 337.0;
        vec3 gPos = normalize(hash3(vec3(seed * 1.3, seed * 2.1, seed * 0.7)) * 2.0 - 1.0);
        float gSize = LAYER2_MIN_SIZE + hash(seed * 2.2) * (LAYER2_MAX_SIZE - LAYER2_MIN_SIZE);
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 137.0, time);
        color += g.rgb * LAYER2_BRIGHTNESS;
    }
    
    // ========== LAYER 3: GALAXY GROUPS ==========
    for(float i = 0.0; i < LAYER3_COUNT; i++)
    {
        float seed = sessionSeed * 3.0 + i * 457.0;
        vec3 nodePos = normalize(hash3(vec3(seed, seed * 1.5, seed * 2.7)) * 2.0 - 1.0);
        vec4 cluster = renderGalaxyNode(rd, nodePos, seed * 777.0, time, LAYER3_SCALE);
        color += cluster.rgb * LAYER3_BRIGHTNESS;
    }
    
    // ========== LAYER 4: PROMINENT NEARBY GALAXIES ==========
    // Clearly visible spiral arms, bars, dust lanes
    for(float i = 0.0; i < LAYER4_COUNT; i++)
    {
        float seed = sessionSeed * 4.0 + i * 523.0;
        vec3 gPos = normalize(hash3(vec3(seed * 0.9, seed * 1.8, seed * 2.5)) * 2.0 - 1.0);
        float gSize = LAYER4_MIN_SIZE + hash(seed * 4.2) * (LAYER4_MAX_SIZE - LAYER4_MIN_SIZE);
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 199.0, time);
        color += g.rgb * LAYER4_BRIGHTNESS;
    }
    
    // ========== LAYER 5: VERY NEARFIELD GALAXIES ==========
    // These are HUGE - should dominate portions of the sky with full detail
    for(float i = 0.0; i < LAYER5_COUNT; i++)
    {
        float seed = sessionSeed * 10.0 + i * 777.0;
        // Spread them around the sky
        float angH = hash(seed * 0.5) * 6.28;
        float angV = (hash(seed * 1.2) - 0.5) * 1.5;
        vec3 gPos = normalize(vec3(cos(angH), angV, sin(angH)));
        float gSize = LAYER5_MIN_SIZE + hash(seed * 4.5) * (LAYER5_MAX_SIZE - LAYER5_MIN_SIZE);
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 311.0, time);
        color += g.rgb * LAYER5_BRIGHTNESS;
    }
    
    // ========== LAYER 0: ULTRA-NEARFIELD (Hubble-quality detail) ==========
    // 2-4 MASSIVE galaxies with full structural detail like the reference image
    const float LAYER0_COUNT = 3.0;
    const float LAYER0_MIN_SIZE = 0.6;
    const float LAYER0_MAX_SIZE = 1.2;
    const float LAYER0_BRIGHTNESS = 1.2;
    
    for(float i = 0.0; i < LAYER0_COUNT; i++)
    {
        float seed = sessionSeed * 20.0 + i * 997.0;
        // Well-spaced positions to avoid overlap
        float angH = (i / LAYER0_COUNT) * 6.28 + hash(seed * 0.3) * 1.5;
        float angV = (hash(seed * 1.5) - 0.5) * 1.2;
        vec3 gPos = normalize(vec3(cos(angH), angV, sin(angH)));
        float gSize = LAYER0_MIN_SIZE + hash(seed * 5.5) * (LAYER0_MAX_SIZE - LAYER0_MIN_SIZE);
        
        // Use the ultra-detailed nearfield renderer
        vec4 g = renderNearfieldGalaxy(rd, gPos, gSize, seed * 419.0, time);
        color += g.rgb * LAYER0_BRIGHTNESS;
    }
    
    // No foreground stars - only large scale cosmic structure
    // No nebulae - focus on clean galaxy rendering
    
    // No globular clusters or tiny blobs - only detailed galaxies
    
    // FINAL CLAMP - balanced visibility
    color = clamp(color, 0.0, 0.85);
    
    return color;
}

// Get a position that's always in a hole of the Menger sponge
vec3 getMengerHolePosition(float t)
{
    // The Menger sponge has holes along all three axes
    // At any level, positions at 1/3 and 2/3 (scaled) are in holes
    // We'll create a path that stays in the central cross-holes
    
    float cycle = t * 0.3;
    float pathSelect = mod(cycle, 6.0);
    
    // Scale factor - how deep into the sponge
    float depth = 0.5 + 0.4 * sin(t * 0.2);
    
    // Six main tunnel paths through the sponge center
    vec3 pos;
    
    if(pathSelect < 1.0) {
        // Travel along X axis through center hole
        float p = mix(-1.2, 1.2, fract(cycle));
        pos = vec3(p, 0.0, 0.0) * depth;
    } else if(pathSelect < 2.0) {
        // Transition X to Y
        float blend = fract(cycle);
        pos = mix(vec3(1.2, 0.0, 0.0), vec3(0.0, 1.2, 0.0), blend) * depth;
    } else if(pathSelect < 3.0) {
        // Travel along Y axis through center hole
        float p = mix(1.2, -1.2, fract(cycle));
        pos = vec3(0.0, p, 0.0) * depth;
    } else if(pathSelect < 4.0) {
        // Transition Y to Z
        float blend = fract(cycle);
        pos = mix(vec3(0.0, -1.2, 0.0), vec3(0.0, 0.0, 1.2), blend) * depth;
    } else if(pathSelect < 5.0) {
        // Travel along Z axis through center hole
        float p = mix(1.2, -1.2, fract(cycle));
        pos = vec3(0.0, 0.0, p) * depth;
    } else {
        // Transition Z to X
        float blend = fract(cycle);
        pos = mix(vec3(0.0, 0.0, -1.2), vec3(-1.2, 0.0, 0.0), blend) * depth;
    }
    
    // Add small wobble that stays within hole bounds
    float wobble = 0.08;
    pos.x += sin(t * 1.7) * wobble * (1.0 - abs(pos.x));
    pos.y += cos(t * 1.3) * wobble * (1.0 - abs(pos.y));
    pos.z += sin(t * 1.1 + 1.0) * wobble * (1.0 - abs(pos.z));
    
    return pos;
}

void main()
{
    vec2 fragCoord = vUv * iResolution;
    
    // Initialize session seed from JavaScript random value - truly random per page load
    sessionSeed = iRandomSeed;
    
    // Camera orbits outside the cube to show both cube and universe
    float angle = iTime * 0.15;
    float angle2 = iTime * 0.1;
    
    // Orbit distance varies - sometimes closer, sometimes farther to see more universe
    float orbitCycle = sin(iTime * 0.08) * 0.5 + 0.5;
    float orbitDist = mix(3.0, 6.0, orbitCycle);
    
    vec3 cam_pos = vec3(
        cos(angle) * cos(angle2 * 0.3) * orbitDist,
        sin(angle) * cos(angle2 * 0.5) * orbitDist,
        sin(angle2) * orbitDist * 0.6
    );
    
    // Look towards the cube with slight offset
    vec3 lookAt = vec3(sin(iTime * 0.05) * 0.3, cos(iTime * 0.07) * 0.3, 0.0);
    vec3 cam_dir = normalize(lookAt - cam_pos);
    
    // Camera basis vectors
    vec3 cam_up = vec3(0.0, 0.0, 1.0);
    vec3 cam_x = normalize(cross(cam_dir, cam_up));
    vec3 cam_y = cross(cam_x, cam_dir);
    
    // UV coordinates with aspect ratio correction
    vec2 uv = -1.0 + 2.0 * fragCoord / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    
    // Field of view adjustment based on distance from center
    float distFromCenter = length(cam_pos);
    float fov = mix(1.2, 0.9, smoothstep(0.0, 2.0, distFromCenter));
    vec3 ray_dir = normalize(cam_dir * fov + uv.x * cam_x + uv.y * cam_y);
    
    // Ray march
    vec3 c = intersect(cam_pos, ray_dir);
    
    vec3 color = vec3(0.0);
    
    if(c.x > 0.0) {
        vec3 hitPos = cam_pos + ray_dir * c.x;
        vec3 normal = calcNormal(hitPos);
        
        // Multiple light sources for rich lighting
        vec3 lightPos1 = vec3(3.0 * sin(iTime * 0.7), 3.0 * cos(iTime * 0.5), 2.0);
        vec3 lightPos2 = vec3(-2.0, -2.0 * sin(iTime * 0.3), 3.0 * cos(iTime * 0.4));
        vec3 lightDir1 = normalize(lightPos1 - hitPos);
        vec3 lightDir2 = normalize(lightPos2 - hitPos);
        
        // Light colors - warm and cool
        vec3 lightCol1 = vec3(1.0, 0.7, 0.4); // Warm orange
        vec3 lightCol2 = vec3(0.4, 0.6, 1.0); // Cool blue
        
        // Diffuse lighting
        float diff1 = max(dot(normal, lightDir1), 0.0);
        float diff2 = max(dot(normal, lightDir2), 0.0);
        
        // Specular highlights (Blinn-Phong)
        vec3 viewDir = normalize(cam_pos - hitPos);
        vec3 halfDir1 = normalize(lightDir1 + viewDir);
        vec3 halfDir2 = normalize(lightDir2 + viewDir);
        float spec1 = pow(max(dot(normal, halfDir1), 0.0), 32.0);
        float spec2 = pow(max(dot(normal, halfDir2), 0.0), 32.0);
        
        // Soft shadows
        float shadow1 = softShadow(hitPos + normal * 0.01, lightDir1, 0.02, 5.0, 16.0);
        float shadow2 = softShadow(hitPos + normal * 0.01, lightDir2, 0.02, 5.0, 16.0);
        
        // Ambient occlusion
        float ao = calcAO(hitPos, normal);
        
        // Fresnel rim lighting for glow effect
        float fresnel = pow(1.0 - max(dot(viewDir, normal), 0.0), 3.0);
        
        // Base color using position and time for variation
        float colorT = length(hitPos) * 0.5 + iTime * 0.1;
        vec3 baseColor = palette(colorT,
            vec3(0.5, 0.5, 0.5),
            vec3(0.5, 0.5, 0.5),
            vec3(1.0, 1.0, 1.0),
            vec3(0.0, 0.1, 0.2)
        );
        
        // Combine lighting
        vec3 ambient = vec3(0.08, 0.06, 0.1) * ao;
        vec3 diffuse = baseColor * (diff1 * lightCol1 * shadow1 + diff2 * lightCol2 * shadow2);
        vec3 specular = (spec1 * lightCol1 * shadow1 + spec2 * lightCol2 * shadow2) * 0.5;
        
        // Rim glow with shifting hue
        vec3 rimColor = palette(iTime * 0.2 + fresnel,
            vec3(0.5, 0.5, 0.5),
            vec3(0.5, 0.5, 0.5),
            vec3(1.0, 0.7, 0.4),
            vec3(0.0, 0.15, 0.2)
        );
        vec3 rim = fresnel * rimColor * 0.8;
        
        // Inner glow when close to surface
        float innerGlow = exp(-c.x * 2.0) * 0.3;
        vec3 glowColor = palette(iTime * 0.15,
            vec3(0.8, 0.5, 0.4),
            vec3(0.2, 0.4, 0.2),
            vec3(2.0, 1.0, 1.0),
            vec3(0.0, 0.25, 0.25)
        );
        
        color = ambient + diffuse + specular + rim + innerGlow * glowColor;
        
        // Depth fog with colored atmosphere
        float fog = 1.0 - exp(-c.x * 0.2);
        vec3 fogColor = vec3(0.02, 0.01, 0.05); // Deep purple-black
        color = mix(color, fogColor, fog);
        
        // Tone mapping
        color = color / (color + vec3(1.0));
        
        // Subtle vignette glow
        color += innerGlow * glowColor * 0.2;
        
    } else {
        // Background - Cosmic web with galaxies connected by massive gas filaments
        color = cosmicWebBackground(ray_dir, iTime);
    }
    
    // Gamma correction
    color = pow(color, vec3(0.8));
    
    gl_FragColor = vec4(color, 1.0);
}
