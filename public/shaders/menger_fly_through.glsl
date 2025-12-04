#ifdef GL_ES
precision highp float;
#endif

uniform float iTime;
uniform vec2 iResolution;
uniform float iRandomSeed;  // Random seed from JavaScript, changes each page load
uniform float iConsoleMode;  // 1.0 = console mode, 0.0 = normal mode
uniform sampler2D iTextBuffer;  // Text buffer texture (128x4 = 512 chars max)
varying vec2 vUv;

#define PI 3.14159265359

// ============================================================================
// BLACK HOLE CONSTANTS - Must be declared before any functions use them
// ============================================================================
const float BLACK_HOLE_MASS = 1.0;        // Controls lensing strength (stronger)
const float EVENT_HORIZON = 0.02;          // Schwarzschild radius (larger)
const float ACCRETION_INNER = 0.03;        // Inner edge of accretion disk
const float ACCRETION_OUTER = 0.05;         // Outer edge of accretion disk
const vec3 BLACK_HOLE_POS = vec3(0.0);     // Center of the Menger cube - FIXED

// Session random seed - computed in main() and passed to functions
float sessionSeed;

// Global flag for camera inside cube - set in main(), used in map()
bool gCameraInsideCube = false;

// ============================================================================
// CONSOLE RENDERING - Terminal overlay when tilda is pressed
// ============================================================================

// Simple 5x7 bitmap font - returns 1.0 if pixel is set for character
float getChar(int charCode, vec2 p)
{
    // p is 0-1 within the character cell
    if(p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) return 0.0;
    
    int px = int(p.x * 5.0);
    int py = int((1.0 - p.y) * 7.0);  // Flip Y
    
    // Simple bitmap patterns for basic ASCII
    // Each character is 5 wide x 7 tall
    int pattern = 0;
    
    // Space
    if(charCode == 32) return 0.0;
    
    // Numbers 0-9 (ASCII 48-57)
    if(charCode == 48) { // 0
        if(py == 0 || py == 6) pattern = (px >= 1 && px <= 3) ? 1 : 0;
        else if(px == 0 || px == 4) pattern = 1;
        else pattern = 0;
    }
    else if(charCode == 49) { // 1
        if(px == 2) pattern = 1;
        else if(py == 6 && px >= 1 && px <= 3) pattern = 1;
        else if(py == 1 && px == 1) pattern = 1;
        else pattern = 0;
    }
    else if(charCode >= 50 && charCode <= 57) { // 2-9 simplified
        if(py == 0 || py == 3 || py == 6) pattern = 1;
        else if(py < 3 && px == 4) pattern = 1;
        else if(py > 3 && px == 0) pattern = 1;
        else pattern = 0;
    }
    
    // Letters A-Z (ASCII 65-90) and a-z (97-122)
    int letter = charCode;
    if(charCode >= 97) letter = charCode - 32; // lowercase to uppercase
    
    if(letter >= 65 && letter <= 90) {
        int idx = letter - 65;
        // Generic letter pattern - vertical bars with horizontal connections
        if(px == 0 || px == 4) pattern = 1;
        else if(py == 0 && idx != 20) pattern = (px >= 1 && px <= 3) ? 1 : 0; // Top bar (not U)
        else if(py == 3 && (idx == 0 || idx == 1 || idx == 4 || idx == 5 || idx == 7 || idx == 15 || idx == 17)) pattern = 1; // Middle bar for A,B,E,F,H,P,R
        else if(py == 6) pattern = (px >= 1 && px <= 3) ? 1 : 0; // Bottom bar
        else pattern = 0;
    }
    
    // Special characters
    if(charCode == 62) { // >
        if(py == 3) pattern = 1;
        else if(py == 1 && px == 2) pattern = 1;
        else if(py == 2 && px == 3) pattern = 1;
        else if(py == 4 && px == 3) pattern = 1;
        else if(py == 5 && px == 2) pattern = 1;
        else pattern = 0;
    }
    if(charCode == 95) { // _ (underscore/cursor)
        pattern = (py == 6) ? 1 : 0;
    }
    if(charCode == 124) { // | (pipe/cursor)
        pattern = (px == 2) ? 1 : 0;
    }
    if(charCode == 46) { // . (period)
        pattern = (py >= 5 && px == 2) ? 1 : 0;
    }
    if(charCode == 47) { // / (slash)
        pattern = (px == (6 - py) / 2) ? 1 : 0;
    }
    if(charCode == 45) { // - (dash)
        pattern = (py == 3 && px >= 1 && px <= 3) ? 1 : 0;
    }
    if(charCode == 58) { // : (colon)
        pattern = (px == 2 && (py == 2 || py == 5)) ? 1 : 0;
    }
    
    return float(pattern);
}

// Render console/terminal background
vec3 renderConsole(vec2 uv, float time)
{
    // Console colors
    vec3 bgColor = vec3(0.02, 0.02, 0.04);       // Dark blue-black
    vec3 textColor = vec3(0.2, 1.0, 0.3);        // Bright green terminal text
    vec3 cursorColor = vec3(0.4, 1.0, 0.5);      // Bright green cursor
    vec3 promptColor = vec3(0.3, 0.5, 1.0);      // Blue prompt
    
    vec3 color = bgColor;
    
    // CRT curvature
    vec2 crtUV = uv;
    vec2 centered = crtUV - 0.5;
    crtUV += centered * dot(centered, centered) * 0.1;
    
    // Scanline effect
    float scanline = 0.95 + 0.05 * sin(crtUV.y * iResolution.y * 2.0);
    
    // Character grid settings
    float charW = 12.0;  // Character width in pixels
    float charH = 20.0;  // Character height in pixels
    float marginX = 40.0;
    float marginY = 40.0;
    
    // Convert to pixel coordinates
    vec2 pixelCoord = crtUV * iResolution.xy;
    
    // Check if we're in the text area
    if(pixelCoord.x > marginX && pixelCoord.x < iResolution.x - marginX &&
       pixelCoord.y > marginY && pixelCoord.y < iResolution.y - marginY) {
        
        // Adjust for margin
        vec2 textPixel = pixelCoord - vec2(marginX, marginY);
        
        // Which character cell are we in?
        float col = floor(textPixel.x / charW);
        float row = floor((iResolution.y - 2.0 * marginY - textPixel.y) / charH);  // Flip Y, top row = 0
        
        // Position within character cell (0-1)
        vec2 cellPos = vec2(
            mod(textPixel.x, charW) / charW,
            mod(textPixel.y, charH) / charH
        );
        
        // Read character from texture buffer
        // Row 0 is the input line, stored in first row of texture
        if(row >= 0.0 && row < 8.0 && col >= 0.0 && col < 120.0) {
            float texX = (col + 0.5) / 128.0;
            float texY = (row + 0.5) / 8.0;
            
            vec4 charData = texture2D(iTextBuffer, vec2(texX, texY));
            float charCodeF = charData.r * 255.0;
            
            if(charCodeF > 31.0) {  // Printable character
                // Simple character rendering - make a block for any printable char
                float inChar = 0.0;
                
                // Leave small gaps between characters
                if(cellPos.x > 0.1 && cellPos.x < 0.85 && cellPos.y > 0.15 && cellPos.y < 0.85) {
                    // For letters/numbers, render a simple pattern
                    int charCode = int(charCodeF + 0.5);
                    
                    // Simple 5x7 grid representation
                    float gx = (cellPos.x - 0.1) / 0.75;  // 0-1 in char area
                    float gy = (cellPos.y - 0.15) / 0.7;
                    int px = int(gx * 5.0);
                    int py = int((1.0 - gy) * 7.0);
                    
                    // Space - empty
                    if(charCode == 32) {
                        inChar = 0.0;
                    }
                    // > prompt character
                    else if(charCode == 62) {
                        if((py == 1 || py == 5) && px == 1) inChar = 1.0;
                        else if((py == 2 || py == 4) && px == 2) inChar = 1.0;
                        else if(py == 3 && px == 3) inChar = 1.0;
                    }
                    // Generic character - render vertical bars
                    else {
                        // Make letters look like simple block characters
                        if(px == 0 || px == 4) inChar = 1.0;  // Side bars
                        else if(py == 0 || py == 6) inChar = 1.0;  // Top/bottom
                        else if(py == 3 && charCode != 73 && charCode != 105) inChar = 0.5;  // Middle bar (not for I/i)
                    }
                }
                
                // Color based on position (prompt vs text)
                if(col < 2.0) {
                    color = mix(color, promptColor, inChar);
                } else {
                    color = mix(color, textColor, inChar);
                }
            }
        }
        
        // Blinking cursor
        float cursorBlink = step(0.5, fract(time * 1.5));
        // Get cursor position from texture (stored at position 0 of row 7)
        vec4 cursorData = texture2D(iTextBuffer, vec2(0.5/128.0, 7.5/8.0));
        float cursorCol = cursorData.r * 255.0;
        
        if(row == 0.0 && abs(col - cursorCol) < 0.5 && cursorBlink > 0.5) {
            // Draw cursor block
            if(cellPos.x > 0.1 && cellPos.x < 0.9 && cellPos.y > 0.1 && cellPos.y < 0.9) {
                color = cursorColor;
            }
        }
    }
    
    // Apply scanlines
    color *= scanline;
    
    // Vignette
    float vignette = 1.0 - dot(centered, centered) * 1.5;
    color *= max(vignette, 0.3);
    
    // Screen flicker
    color *= 0.97 + 0.03 * sin(time * 50.0);
    
    // Phosphor glow
    color += bgColor * 0.3;
    
    return color;
}

float maxcomp(in vec3 p) { return max(p.x, max(p.y, p.z)); }

float sdfBox(vec3 p, vec3 b)
{
    vec3 di = abs(p) - b;
    float mc = maxcomp(di);
    return min(mc, length(max(di, 0.0)));
}

// Apply space distortion from black hole to a point (optimized)
vec3 distortSpaceAroundBlackHole(vec3 p)
{
    vec3 toHole = p - BLACK_HOLE_POS;
    float dist = length(toHole);
    
    if(dist < EVENT_HORIZON || dist > 2.5) return p;  // Early exit for far points
    
    float distortStrength = BLACK_HOLE_MASS / (dist * dist + 0.01);
    distortStrength = min(distortStrength, 0.8);
    
    vec3 pullDir = -normalize(toHole);
    float angle = distortStrength * 2.0 / (dist + 0.1);
    
    return p + pullDir * distortStrength * 0.15 + 
           vec3(toHole.y * sin(angle), toHole.z * sin(angle), toHole.x * sin(angle)) * distortStrength * 0.2;
}

vec3 map(in vec3 p)
{
    // NO black hole distortion on cube geometry - keeps it clean
    
    // Carve out sphere for black hole in center - nothing exists inside event horizon
    float blackHoleDist = length(p - BLACK_HOLE_POS);
    if(blackHoleDist < EVENT_HORIZON * 1.1) {
        return vec3(blackHoleDist - EVENT_HORIZON, 1.0, 1.0); // Empty space inside
    }
    
    float d = sdfBox(p, vec3(2.0));

    float s = 1.0;

    // Use constant 10 iterations when camera is inside cube (better detail, less clipping)
    // Otherwise vary iterations for visual effect when viewing from outside
    int n_iters = gCameraInsideCube ? 10 : int(mix(4.0, 8.0, abs(2.0 * fract(iTime / 5.0) - 1.0)));
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
    // Tighter threshold when inside cube to reduce clipping
    float hitThreshold = gCameraInsideCube ? 0.0005 : 0.002;
    float maxDist = gCameraInsideCube ? 20.0 : 15.0;
    
    for(float t = 0.0; t < maxDist;)
    {
        vec3 h = map(ro + rd * t);
        if(h.x < hitThreshold)
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

// Soft shadows for depth (optimized: 16 iterations)
float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 16; i++)
    {
        if(t >= maxt) break;
        float h = map(ro + rd * t).x;
        if(h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h * 1.5;  // Larger steps
    }
    return res;
}

// Ambient occlusion (optimized: 3 iterations)
float calcAO(vec3 pos, vec3 nor)
{
    float occ = 0.0;
    float sca = 1.0;
    for(int i = 0; i < 3; i++)
    {
        float h = 0.01 + 0.15 * float(i) / 2.0;
        float d = map(pos + h * nor).x;
        occ += (h - d) * sca;
        sca *= 0.9;
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

// Fractal Brownian Motion - optimized 2 iterations
float fbm(vec3 p)
{
    return 0.5 * noise3D(p) + 0.25 * noise3D(p * 2.0);
}

// Rotation matrix around arbitrary axis
mat2 rot2D(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// ============================================================================
// BLACK HOLE - Gravitational lensing at center of Menger cube
// ============================================================================

// Bend ray direction due to gravitational lensing
// Uses simplified Schwarzschild metric approximation
vec3 gravitationalLensing(vec3 rayPos, vec3 rayDir, float mass)
{
    vec3 toHole = BLACK_HOLE_POS - rayPos;
    float dist = length(toHole);
    
    // Skip if too far for noticeable effect
    if(dist > 3.0) return rayDir;
    
    vec3 toHoleNorm = toHole / dist;
    
    // Deflection angle based on Einstein's formula (simplified)
    // Real formula: alpha = 4GM/(c^2 * b) where b is impact parameter
    float impactParam = length(cross(rayDir, toHole));
    
    // Avoid division by zero and extreme bending very close
    impactParam = max(impactParam, EVENT_HORIZON * 0.5);
    
    // Deflection strength - stronger closer to black hole
    float deflection = mass / (impactParam * impactParam) * 0.5;
    deflection = min(deflection, 1.5); // Cap maximum bend
    
    // Calculate perpendicular direction toward black hole
    vec3 perpDir = toHoleNorm - rayDir * dot(rayDir, toHoleNorm);
    float perpLen = length(perpDir);
    if(perpLen > 0.001) {
        perpDir /= perpLen;
        // Bend ray toward black hole
        rayDir = normalize(rayDir + perpDir * deflection);
    }
    
    return rayDir;
}

// Check if ray hits event horizon (proper ray-sphere intersection)
bool hitsEventHorizon(vec3 rayPos, vec3 rayDir)
{
    vec3 oc = rayPos - BLACK_HOLE_POS;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(oc, rayDir);
    float c = dot(oc, oc) - EVENT_HORIZON * EVENT_HORIZON;
    float discriminant = b * b - 4.0 * a * c;
    
    if(discriminant < 0.0) return false;
    
    // Check if intersection is in front of ray
    float t = (-b - sqrt(discriminant)) / (2.0 * a);
    return t > 0.0;
}

// Render accretion disk - swirling hot matter around black hole
vec3 renderAccretionDisk(vec3 rayPos, vec3 rayDir, float time)
{
    vec3 color = vec3(0.0);
    
    // Disk lies in XZ plane at y=0 (roughly)
    // But tilted slightly for visual interest
    float tiltAngle = 0.3 + sin(time * 0.1) * 0.1;
    vec3 diskNormal = normalize(vec3(sin(tiltAngle) * 0.3, 1.0, cos(tiltAngle) * 0.2));
    
    // Find intersection with disk plane
    float denom = dot(rayDir, diskNormal);
    if(abs(denom) < 0.001) return color;
    
    float t = dot(BLACK_HOLE_POS - rayPos, diskNormal) / denom;
    if(t < 0.0) return color;
    
    vec3 hitPoint = rayPos + rayDir * t;
    vec3 toCenter = hitPoint - BLACK_HOLE_POS;
    float r = length(toCenter);
    
    // Only render within disk bounds
    if(r < ACCRETION_INNER || r > ACCRETION_OUTER) return color;
    
    // Angle around disk
    float angle = atan(toCenter.z, toCenter.x);
    
    // Swirling motion - inner parts orbit faster (Keplerian)
    float orbitSpeed = 1.0 / pow(r, 1.5);
    float swirl = angle + time * orbitSpeed * 2.0;
    
    // Spiral arm structure
    float arms = sin(swirl * 3.0 - r * 20.0) * 0.5 + 0.5;
    arms = pow(arms, 0.7);
    
    // Turbulent detail
    float turb = noise3D(vec3(toCenter.xz * 15.0 + time * 0.5, time * 0.2));
    
    // Temperature gradient - hotter (bluer/whiter) toward center
    float temp = smoothstep(ACCRETION_OUTER, ACCRETION_INNER, r);
    
    // Base disk brightness - brighter in the middle
    float brightness = smoothstep(ACCRETION_OUTER, ACCRETION_INNER * 1.5, r);
    brightness *= smoothstep(ACCRETION_INNER * 0.9, ACCRETION_INNER * 1.3, r);
    brightness *= (0.5 + arms * 0.5) * (0.7 + turb * 0.3);
    
    // Doppler beaming - approaching side brighter
    float doppler = 1.0 + sin(angle + time * orbitSpeed) * 0.3;
    brightness *= doppler;
    
    // Color based on temperature
    // Hot inner: blue-white, cooler outer: orange-red
    vec3 hotColor = vec3(0.8, 0.9, 1.0);     // Blue-white
    vec3 warmColor = vec3(1.0, 0.7, 0.3);    // Orange
    vec3 coolColor = vec3(1.0, 0.3, 0.1);    // Red
    
    vec3 diskColor = mix(coolColor, warmColor, smoothstep(0.0, 0.5, temp));
    diskColor = mix(diskColor, hotColor, smoothstep(0.5, 1.0, temp));
    
    // Add emission glow
    float glow = exp(-abs(dot(rayDir, diskNormal)) * 3.0);
    
    color = diskColor * brightness * (1.0 + glow * 0.5);
    
    // Fade at edges
    float edgeFade = smoothstep(ACCRETION_OUTER, ACCRETION_OUTER * 0.85, r);
    edgeFade *= smoothstep(ACCRETION_INNER, ACCRETION_INNER * 1.2, r);
    
    return color * edgeFade * 1.5;
}

// Render photon sphere glow - light orbiting just outside event horizon
vec3 renderPhotonSphere(vec3 rayPos, vec3 rayDir)
{
    vec3 toHole = BLACK_HOLE_POS - rayPos;
    float closestApproach = length(cross(rayDir, toHole));
    float distAlongRay = dot(toHole, rayDir);
    
    // Photon sphere at 1.5x event horizon
    float photonRadius = EVENT_HORIZON * 1.5;
    
    // Only render if ray passes near photon sphere and black hole is ahead
    if(distAlongRay < 0.0) return vec3(0.0);
    
    // Glow intensity based on how close ray passes to photon sphere
    float glowDist = abs(closestApproach - photonRadius);
    float glow = exp(-glowDist * glowDist / 0.002);
    
    // Also add glow for rays passing very close to event horizon
    float horizonGlow = exp(-closestApproach * closestApproach / (EVENT_HORIZON * EVENT_HORIZON * 0.3));
    horizonGlow *= smoothstep(EVENT_HORIZON * 0.5, EVENT_HORIZON * 1.5, closestApproach);
    
    // Reddened light from extreme gravitational redshift
    vec3 photonColor = vec3(1.0, 0.4, 0.1) * glow * 0.5;
    vec3 horizonColor = vec3(0.8, 0.2, 0.05) * horizonGlow * 0.8;
    
    return photonColor + horizonColor;
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Generate 3 harmonious colors for a galaxy based on seed
// Returns colors in a mat3 where each row is a color
// Uses color harmony rules: analogous, complementary, triadic, split-complementary
void getGalaxyPalette(float seed, out vec3 col1, out vec3 col2, out vec3 col3) {
    // Base hue - random for each galaxy
    float baseHue = hash(seed * 7.31);
    
    // Saturation and value variations
    float baseSat = 0.5 + hash(seed * 11.17) * 0.4;  // 0.5-0.9
    float baseVal = 0.7 + hash(seed * 13.29) * 0.3;  // 0.7-1.0
    
    // Choose harmony type
    float harmonyType = hash(seed * 17.41);
    
    float h1, h2, h3;
    float s1, s2, s3;
    float v1, v2, v3;
    
    if(harmonyType < 0.2) {
        // ANALOGOUS - colors next to each other on wheel (30-60 degrees apart)
        float spread = 0.08 + hash(seed * 19.0) * 0.1;  // 30-65 degrees
        h1 = baseHue;
        h2 = fract(baseHue + spread);
        h3 = fract(baseHue - spread);
        s1 = baseSat;
        s2 = baseSat * (0.7 + hash(seed * 21.0) * 0.3);
        s3 = baseSat * (0.8 + hash(seed * 23.0) * 0.2);
        v1 = baseVal;
        v2 = baseVal * (0.85 + hash(seed * 25.0) * 0.15);
        v3 = baseVal * (0.9 + hash(seed * 27.0) * 0.1);
    }
    else if(harmonyType < 0.4) {
        // COMPLEMENTARY - opposite colors (180 degrees)
        h1 = baseHue;
        h2 = fract(baseHue + 0.5);  // Opposite
        h3 = fract(baseHue + 0.5 + (hash(seed * 29.0) - 0.5) * 0.1);  // Near opposite
        s1 = baseSat;
        s2 = baseSat * 0.8;
        s3 = baseSat * 0.6;
        v1 = baseVal;
        v2 = baseVal * 0.9;
        v3 = baseVal;
    }
    else if(harmonyType < 0.6) {
        // TRIADIC - 3 colors evenly spaced (120 degrees)
        h1 = baseHue;
        h2 = fract(baseHue + 0.333);
        h3 = fract(baseHue + 0.666);
        s1 = baseSat;
        s2 = baseSat * (0.7 + hash(seed * 31.0) * 0.3);
        s3 = baseSat * (0.6 + hash(seed * 33.0) * 0.4);
        v1 = baseVal;
        v2 = baseVal * (0.8 + hash(seed * 35.0) * 0.2);
        v3 = baseVal * (0.85 + hash(seed * 37.0) * 0.15);
    }
    else if(harmonyType < 0.8) {
        // SPLIT-COMPLEMENTARY - base + two colors adjacent to complement
        h1 = baseHue;
        h2 = fract(baseHue + 0.5 - 0.083);  // 150 degrees
        h3 = fract(baseHue + 0.5 + 0.083);  // 210 degrees
        s1 = baseSat;
        s2 = baseSat * 0.85;
        s3 = baseSat * 0.75;
        v1 = baseVal;
        v2 = baseVal * 0.95;
        v3 = baseVal * 0.9;
    }
    else {
        // TETRADIC/DOUBLE-COMPLEMENTARY - rectangle on color wheel
        h1 = baseHue;
        h2 = fract(baseHue + 0.25);   // 90 degrees
        h3 = fract(baseHue + 0.5);    // 180 degrees
        s1 = baseSat;
        s2 = baseSat * (0.6 + hash(seed * 39.0) * 0.4);
        s3 = baseSat * (0.7 + hash(seed * 41.0) * 0.3);
        v1 = baseVal;
        v2 = baseVal * (0.85 + hash(seed * 43.0) * 0.15);
        v3 = baseVal * 0.95;
    }
    
    // Convert HSV to RGB
    col1 = hsv2rgb(vec3(h1, s1, v1));
    col2 = hsv2rgb(vec3(h2, s2, v2));
    col3 = hsv2rgb(vec3(h3, s3, v3));
    
    // Optional: Add some warmth/coolness bias based on another random
    float tempBias = hash(seed * 47.0);
    if(tempBias < 0.3) {
        // Warm bias - shift toward orange/red
        col1 = mix(col1, col1 * vec3(1.1, 0.95, 0.85), 0.2);
        col2 = mix(col2, col2 * vec3(1.1, 0.95, 0.85), 0.15);
        col3 = mix(col3, col3 * vec3(1.1, 0.95, 0.85), 0.1);
    } else if(tempBias > 0.7) {
        // Cool bias - shift toward blue
        col1 = mix(col1, col1 * vec3(0.9, 0.95, 1.1), 0.2);
        col2 = mix(col2, col2 * vec3(0.9, 0.95, 1.1), 0.15);
        col3 = mix(col3, col3 * vec3(0.9, 0.95, 1.1), 0.1);
    }
    
    // Clamp to valid range
    col1 = clamp(col1, 0.0, 1.0);
    col2 = clamp(col2, 0.0, 1.0);
    col3 = clamp(col3, 0.0, 1.0);
}

// Simplified Hubble color palette - key colors only
vec3 hubbleColor(float seed)
{
    float idx = hash(seed) * 8.0;
    if(idx < 1.0) return vec3(0.5, 0.7, 1.0);       // Blue arms
    if(idx < 2.0) return vec3(1.0, 0.4, 0.6);       // Pink HII regions
    if(idx < 3.0) return vec3(1.0, 0.9, 0.7);       // Warm core
    if(idx < 4.0) return vec3(0.6, 0.5, 1.0);       // Blue-violet
    if(idx < 5.0) return vec3(1.0, 0.6, 0.4);       // Orange
    if(idx < 6.0) return vec3(0.4, 0.6, 1.0);       // Deep blue
    if(idx < 7.0) return vec3(1.0, 0.5, 0.7);       // Magenta
    return vec3(0.7, 0.8, 1.0);                      // Pale blue
}

// Turbulent FBM for gas structures (optimized: 2 iterations)
float turbulentFbm(vec3 p)
{
    float value = 0.5 * abs(noise3D(p) * 2.0 - 1.0);
    value += 0.25 * abs(noise3D(p * 2.0) * 2.0 - 1.0);
    return value;
}

// Simple star field - returns brightness
float starField(vec2 uv, float density, float seed)
{
    vec2 gridUV = uv * density;
    vec2 gridCell = floor(gridUV);
    vec2 gridFract = fract(gridUV);
    
    float minDist = 1.0;
    float starBright = 0.0;
    
    for(float y = -1.0; y <= 1.0; y++)
    {
        for(float x = -1.0; x <= 1.0; x++)
        {
            vec2 cell = gridCell + vec2(x, y);
            float cellHash = hash(cell + seed);
            
            if(cellHash > 0.7)
            {
                vec2 starPos = hash3(vec3(cell, seed)).xy;
                vec2 diff = vec2(x, y) + starPos - gridFract;
                float dist = length(diff);
                
                if(dist < minDist)
                {
                    minDist = dist;
                    starBright = 0.5 + hash(cell.x * 13.0 + cell.y * 57.0 + seed) * 0.5;
                }
            }
        }
    }
    
    return smoothstep(0.04, 0.0, minDist) * starBright;
}

// Multi-scale star field (optimized: 2 scales)
float stars(vec2 uv, float seed)
{
    float s = starField(uv, 40.0, seed) * 1.0;
    s += starField(uv, 80.0, seed + 100.0) * 0.6;
    return min(s, 1.5);
}

// ============================================================================
// GALAXY RENDERER - Hubble-style with visible internal structure
// ============================================================================
vec4 renderGalaxy(vec3 rd, vec3 galaxyPos, float galaxySize, float seed, float time, int forceType)
{
    seed = seed + sessionSeed;
    
    // Quick rejection
    float viewDist = length(rd - normalize(galaxyPos));
    if(viewDist > galaxySize * 2.0) return vec4(0.0);
    
    // Galaxy orientation - random tilt for variety
    vec3 galaxyNormal = normalize(galaxyPos);
    float tiltX = (hash(seed * 1.1) - 0.5) * 1.2;  // More random tilt
    float tiltY = (hash(seed * 2.3) - 0.5) * 1.2;
    galaxyNormal = normalize(galaxyNormal + vec3(tiltX, tiltY, 0.0) * 0.5);
    
    vec3 t = normalize(cross(galaxyNormal, vec3(0.0, 1.0, 0.1)));
    if(length(cross(galaxyNormal, vec3(0.0, 1.0, 0.1))) < 0.1) 
        t = normalize(cross(galaxyNormal, vec3(1.0, 0.0, 0.1)));
    vec3 b = cross(galaxyNormal, t);
    
    vec3 localRd = rd - normalize(galaxyPos);
    vec2 uv = vec2(dot(localRd, t), dot(localRd, b));
    float r = length(uv);
    
    if(r > galaxySize * 1.3) return vec4(0.0);
    
    float ang = atan(uv.y, uv.x);
    vec2 nuv = uv / galaxySize;
    
    // Fine detail noise
    float turb = turbulentFbm(vec3(nuv * 8.0, seed));
    float dust = noise3D(vec3(nuv * 12.0, seed * 3.0));
    
    vec3 color = vec3(0.0);
    float alpha = 0.0;
    
    // Galaxy type - 0=spiral, 1=barred spiral, 2=elliptical, 3=irregular, 4=edge-on
    int gtype = forceType >= 0 ? forceType : int(hash(seed * 7.0) * 5.0);
    
    if(gtype == 0)
    {
        // === SPIRAL GALAXY - ANIMATED WITH FAST SPINNING, ARM MERGING, GAS SWIRLING ===
        
        // FAST VISIBLE ROTATION - each galaxy spins noticeably
        float spinSpeed = 0.15 + hash(seed * 6.1) * 0.2;  // Much faster spin
        float rotAng = seed * 10.0 + time * spinSpeed;
        
        // EXTREME randomization - every galaxy wildly unique
        
        // Random arm count (1-7, weighted)
        float armRand = hash(seed * 5.5);
        float numArms = armRand < 0.08 ? 1.0 : (armRand < 0.2 ? 2.0 : (armRand < 0.45 ? 3.0 : (armRand < 0.7 ? 4.0 : (armRand < 0.88 ? 5.0 : (armRand < 0.96 ? 6.0 : 7.0)))));
        
        // Spiral tightness - HUGE range from very open to extremely tight
        float spiralTightness = 0.5 + hash(seed * 12.0) * 8.0;
        
        // Arm width - extremely thin wispy to very thick fluffy
        float armWidth = 0.1 + hash(seed * 17.0) * 1.2;
        
        // Strong asymmetry - arms can be VERY different strengths
        float asymmetry = pow(hash(seed * 22.0), 0.7) * 0.95;
        
        // Flocculence - smooth to extremely patchy/broken
        float flocculence = pow(hash(seed * 27.0), 0.5) * 1.0;
        
        // Pitch variation - arms can wobble dramatically
        float pitchVar = hash(seed * 33.0) * 1.2;
        
        // Random overall warp/distortion - some galaxies very warped
        float warpStrength = pow(hash(seed * 38.0), 0.8) * 0.6;
        float warpFreq = 0.5 + hash(seed * 43.0) * 4.0;
        
        // NEW: Overall galaxy stretch/squash
        float stretchX = 0.7 + hash(seed * 48.0) * 0.6;
        float stretchY = 0.7 + hash(seed * 49.0) * 0.6;
        
        // Build spiral arms with EXTREME randomness
        // Apply stretch and random warp to UV coordinates
        vec2 warpedUV = nuv;
        warpedUV.x *= stretchX;
        warpedUV.y *= stretchY;
        
        // FAST SWIRLING GAS - visible movement
        float swirlTime = time * 0.3;
        warpedUV += vec2(
            sin(warpedUV.y * warpFreq * 10.0 + swirlTime * 2.0), 
            cos(warpedUV.x * warpFreq * 10.0 - swirlTime * 1.5)
        ) * warpStrength * 0.15;
        
        float warpedR = length(warpedUV) * galaxySize;
        float warpedAng = atan(warpedUV.y, warpedUV.x);
        
        float spiralAng = warpedAng + rotAng - log(max(warpedR / galaxySize, 0.01)) * spiralTightness;
        // Add pitch variation - animated fast
        spiralAng += sin(warpedR / galaxySize * 6.0 + seed + time * 0.2) * pitchVar;
        spiralAng += cos(warpedR / galaxySize * 11.0 + seed * 2.0 - time * 0.15) * pitchVar * 0.5;
        
        // FAST ARM MERGING - arms blend together visibly
        float mergePhase = sin(time * 0.4 + seed * 5.0) * 0.5 + 0.5;  // Faster oscillation
        float armMerge = 0.3 + mergePhase * 0.4;  // How much arms blend
        
        // Multi-arm structure with per-arm randomization and MERGING
        float arms = 0.0;
        float armAccum = 0.0;  // For soft merging
        for(float arm = 0.0; arm < 7.0; arm++)
        {
            if(arm >= numArms) break;
            // Each arm has random offset (not evenly spaced)
            float baseOffset = arm * 6.28 / numArms;
            float armJitter = (hash(seed + arm * 77.0) - 0.5) * 0.8;
            // Animated jitter - arms shift position fast
            armJitter += sin(time * 0.25 + arm * 2.0 + seed) * 0.2;
            float armOffset = baseOffset + armJitter;
            
            // Each arm has different strength AND different width
            float armStrength = 0.4 + hash(seed + arm * 13.0) * 0.6;
            // Animated strength variation - faster
            armStrength *= 0.7 + 0.3 * sin(time * 0.3 + arm * 1.5 + seed);
            armStrength *= (1.0 - asymmetry * sin(arm * 2.7 + seed));
            float thisArmWidth = armWidth * (0.6 + hash(seed + arm * 19.0) * 0.8);
            
            float armPhase = spiralAng * numArms / 2.0 + armOffset;
            float armWave = sin(armPhase);
            float thisArm = pow(max(armWave, 0.0), 1.0 + thisArmWidth);
            thisArm *= armStrength;
            
            // Accumulate for soft merging instead of hard max
            armAccum += thisArm;
            arms = max(arms, thisArm);
        }
        // Blend between max (distinct arms) and sum (merged arms)
        arms = mix(arms, min(armAccum * 0.5, 1.2), armMerge);
        
        // Radial falloff
        arms *= smoothstep(galaxySize * 0.98, galaxySize * 0.12, r);
        arms *= smoothstep(galaxySize * 0.02, galaxySize * 0.08, r);
        
        // Flocculence - breaks up the arms - FAST ANIMATION
        float floc1 = noise3D(vec3(nuv * 18.0 + time * 0.1, seed * 2.0));
        float floc2 = noise3D(vec3(nuv * 35.0 - time * 0.08, seed * 3.0));
        float flocBreak = mix(1.0, floc1 * floc2 * 4.0, flocculence);
        arms *= clamp(flocBreak, 0.2, 1.5);
        
        // Fine clumpy texture - fast swirling
        float fineNoise = noise3D(vec3(nuv * 40.0 + time * 0.05, seed * 4.0));
        arms *= (0.5 + fineNoise * 0.6);
        
        // Dust lanes - animated movement
        float dustPhase = spiralAng * numArms / 2.0 + 0.3 + hash(seed * 41.0) * 0.4;
        dustPhase += sin(time * 0.2 + seed) * 0.15;  // Visible dust lane movement
        float dustLane = smoothstep(0.2, 0.4, sin(dustPhase)) * smoothstep(0.6, 0.4, sin(dustPhase));
        dustLane *= smoothstep(galaxySize * 0.65, galaxySize * 0.08, r);
        dustLane *= (0.6 + turb * 0.5);
        
        // VERY SMALL central bulge - barely visible
        float bulgeR = galaxySize * (0.02 + hash(seed * 45.0) * 0.02);  // Tiny bulge
        float bulge = exp(-r * r / (bulgeR * bulgeR)) * 0.08;  // Nearly invisible
        
        // Pinpoint nucleus - extremely dim
        float nucleusR = galaxySize * 0.004;
        float nucleus = exp(-r * r / (nucleusR * nucleusR)) * 0.12;  // Barely there
        
        // HII regions scattered preferentially in arms (optimized: 8-15)
        float hii = 0.0;
        float numHII = 8.0 + hash(seed * 51.0) * 7.0;  // 8-15 HII regions
        for(float k = 0.0; k < 15.0; k++)
        {
            if(k >= numHII) break;
            float kSeed = seed + k * 73.0;
            float kAng = hash(kSeed) * 6.28;
            float kR = (0.06 + hash(kSeed + 1.0) * 0.8) * galaxySize;
            vec2 kPos = vec2(cos(kAng + rotAng), sin(kAng + rotAng)) * kR;
            float kDist = length(uv - kPos);
            float kSize = galaxySize * (0.0015 + hash(kSeed + 2.0) * 0.004);
            // Sharp cutoff
            float kBright = smoothstep(kSize, kSize * 0.08, kDist);
            hii += kBright * hash(kSeed + 3.0) * 0.9;
        }
        hii = min(hii, 2.0);
        
        // Star clusters - blue OB associations (optimized: 10-25)
        float clusters = 0.0;
        vec3 clusterTotalCol = vec3(0.0);
        float numClusters = 10.0 + hash(seed * 151.0) * 15.0;  // 10-25 clusters
        for(float k = 0.0; k < 25.0; k++)
        {
            if(k >= numClusters) break;
            float kSeed = seed + k * 97.0 + 500.0;
            vec2 cPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 1.9;
            // Some clusters follow arms, some scattered
            float followArm = hash(kSeed + 7.0);
            if(followArm > 0.4) {
                // Adjust position toward arms
                float armAng = atan(cPos.y, cPos.x);
                float armR = length(cPos);
                armAng += sin(armR / galaxySize * spiralTightness) * 0.3;
                cPos = vec2(cos(armAng), sin(armAng)) * armR;
            }
            float cDist = length(uv - cPos);
            float cSize = galaxySize * (0.001 + hash(kSeed + 2.0) * 0.005);
            // Sharp cutoff instead of smooth halo
            float clusterBright = smoothstep(cSize, cSize * 0.08, cDist) * (arms * 0.5 + 0.3);
            // Vary cluster colors - blue, cyan, white, pale yellow
            float cHue = hash(kSeed + 10.0);
            vec3 cCol;
            if(cHue < 0.3) cCol = vec3(0.5, 0.7, 1.0);       // Blue
            else if(cHue < 0.5) cCol = vec3(0.4, 0.85, 0.95); // Cyan
            else if(cHue < 0.75) cCol = vec3(0.95, 0.95, 1.0); // White
            else cCol = vec3(1.0, 0.95, 0.8);                  // Pale yellow
            // Subtle twinkling
            float twinkle = 0.8 + 0.2 * sin(time * (3.0 + hash(kSeed) * 8.0) + kSeed * 5.0);
            clusterTotalCol += cCol * clusterBright * twinkle;
            clusters += clusterBright * twinkle;
        }
        clusters = min(clusters, 2.5);
        
        // Individual stars (optimized: 12)
        float indivStars = 0.0;
        for(float k = 0.0; k < 12.0; k++)
        {
            float kSeed = seed + k * 31.0 + 800.0;
            vec2 sPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 1.9;
            float sDist = length(uv - sPos);
            float sSize = galaxySize * 0.0015;
            indivStars += smoothstep(sSize, sSize * 0.05, sDist) * hash(kSeed + 1.0) * 0.5;
        }
        indivStars = min(indivStars, 0.8);
        
        // GET UNIQUE HARMONIOUS COLOR PALETTE for this galaxy
        vec3 palCol1, palCol2, palCol3;
        getGalaxyPalette(seed * 61.0, palCol1, palCol2, palCol3);
        
        // Assign palette colors to galaxy components
        vec3 armCol = palCol1;           // Primary color for arms
        vec3 hiiCol = palCol2;           // Secondary color for HII regions
        vec3 bulgeCol = palCol3 * 0.9 + vec3(0.1);  // Tertiary + slight warmth for bulge
        
        // Derived colors
        vec3 coreCol = mix(bulgeCol, palCol1, 0.3) + vec3(0.05, 0.03, 0.0);  // Core blends
        vec3 starCol = mix(palCol1, vec3(1.0), 0.5);  // Stars tinted toward palette but bright
        
        // Assemble with color diversity
        color = armCol * arms * 0.6;
        color -= vec3(0.12, 0.06, 0.0) * dustLane * 0.6;
        color += bulgeCol * bulge * 0.15;  // Very subtle bulge
        color += coreCol * nucleus * 0.1;   // Barely visible nucleus
        color += hiiCol * hii * 0.9;
        color += clusterTotalCol * 0.7;  // Use varied cluster colors
        color += starCol * indivStars * 0.4;
        
        // Add subtle color variation across the disk using palette
        float diskColorVar = noise3D(vec3(nuv * 3.0, seed * 5.0));
        color += mix(palCol1, palCol2, diskColorVar) * diskColorVar * 0.08 * smoothstep(galaxySize, galaxySize * 0.2, r);
        
        alpha = arms * 0.4 + bulge * 0.2 + nucleus * 0.3 + hii * 0.5 + clusters * 0.3;
    }
    else if(gtype == 1)
    {
        // === BARRED SPIRAL - FAST ANIMATED ROTATION ===
        float spinSpeed = 0.12 + hash(seed * 6.2) * 0.15;
        float rotAng = seed * 8.0 + time * spinSpeed;
        vec2 ruv = uv * rot2D(rotAng);
        
        // Random bar properties
        float barLen = galaxySize * (0.2 + hash(seed * 51.0) * 0.25);
        float barWidth = galaxySize * (0.04 + hash(seed * 52.0) * 0.05);
        float barAngle = (hash(seed * 53.0) - 0.5) * 0.3;
        // Animated bar wobble - faster
        barAngle += sin(time * 0.25 + seed) * 0.08;
        vec2 barUV = ruv * rot2D(barAngle);
        
        float bar = smoothstep(barLen, barLen * 0.5, abs(barUV.x)) * 
                    smoothstep(barWidth, barWidth * 0.15, abs(barUV.y));
        // Add fast animated texture to bar
        float barNoise = noise3D(vec3(barUV * 25.0 + time * 0.1, seed));
        bar *= (0.5 + barNoise * 0.6);
        
        // Random spiral properties
        float spiralTight = 2.5 + hash(seed * 54.0) * 3.0;
        float armWidthVar = 0.8 + hash(seed * 55.0) * 0.8;
        
        // Arms emerge from bar ends with randomization
        float armAng1 = atan(barUV.y, barUV.x - barLen * 0.45);
        float armAng2 = atan(barUV.y, barUV.x + barLen * 0.45);
        float armR1 = length(barUV - vec2(barLen * 0.45, 0.0));
        float armR2 = length(barUV - vec2(-barLen * 0.45, 0.0));
        
        // Different tightness for each arm - fast animated variation
        float tight1 = spiralTight * (0.8 + hash(seed * 56.0) * 0.4 + sin(time * 0.2) * 0.15);
        float tight2 = spiralTight * (0.8 + hash(seed * 57.0) * 0.4 - sin(time * 0.2) * 0.15);
        
        float spiral1 = sin(armAng1 - log(max(armR1 / galaxySize, 0.04)) * tight1);
        float spiral2 = sin(armAng2 + PI - log(max(armR2 / galaxySize, 0.04)) * tight2);
        
        float arms = max(
            pow(max(spiral1, 0.0), armWidthVar) * smoothstep(galaxySize * 0.95, barLen * 0.4, armR1),
            pow(max(spiral2, 0.0), armWidthVar) * smoothstep(galaxySize * 0.95, barLen * 0.4, armR2)
        );
        arms *= smoothstep(galaxySize * 0.95, galaxySize * 0.2, r);
        // Fast animated turbulence
        arms *= (0.4 + turbulentFbm(vec3(nuv * 8.0 + time * 0.1, seed)) * 0.7);
        
        // Tiny nucleus - nearly invisible
        float nucleusR = galaxySize * 0.005;
        float nucleus = exp(-r * r / (nucleusR * nucleusR)) * 0.1;
        
        // Subtle bar bulge - extremely faint
        float bulgeR = galaxySize * 0.04;
        float bulge = exp(-r * r / (bulgeR * bulgeR)) * 0.05;
        
        // HII regions at bar ends and scattered in arms - NO HALO
        float hii = 0.0;
        vec2 barEnd1 = vec2(barLen * 0.45, 0.0);
        vec2 barEnd2 = vec2(-barLen * 0.45, 0.0);
        float hiiSize = galaxySize * 0.008;
        hii += smoothstep(hiiSize, hiiSize * 0.15, length(barUV - barEnd1)) * 0.6;
        hii += smoothstep(hiiSize, hiiSize * 0.15, length(barUV - barEnd2)) * 0.6;
        
        // More HII spots in arms (optimized: 8)
        for(float k = 0.0; k < 8.0; k++)
        {
            float kSeed = seed + k * 67.0;
            float kAng = hash(kSeed) * 6.28;
            float kR = (0.2 + hash(kSeed + 1.0) * 0.5) * galaxySize;
            vec2 kPos = vec2(cos(kAng), sin(kAng)) * kR;
            float kDist = length(barUV - kPos);
            float kSize = galaxySize * (0.002 + hash(kSeed + 2.0) * 0.004);
            hii += smoothstep(kSize, kSize * 0.15, kDist) * arms * hash(kSeed + 3.0);
        }
        hii = min(hii, 1.5);
        
        // Star clusters (optimized: 8-20)
        float clusters = 0.0;
        vec3 clusterTotalCol = vec3(0.0);
        float numClusters = 8.0 + hash(seed * 152.0) * 12.0;  // 8-20 clusters
        for(float k = 0.0; k < 20.0; k++)
        {
            if(k >= numClusters) break;
            float kSeed = seed + k * 89.0 + 400.0;
            vec2 cPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 1.6;
            float cDist = length(barUV - cPos);
            float cSize = galaxySize * (0.001 + hash(kSeed + 3.0) * 0.003);
            float clusterBright = smoothstep(cSize, cSize * 0.1, cDist) * (bar + arms) * 0.6;
            // Color variety
            float cHue = hash(kSeed + 11.0);
            vec3 cCol = cHue < 0.4 ? vec3(0.5, 0.75, 1.0) : (cHue < 0.7 ? vec3(0.6, 0.9, 0.95) : vec3(0.95, 0.95, 1.0));
            // Twinkling
            float twinkle = 0.85 + 0.15 * sin(time * (4.0 + hash(kSeed) * 10.0) + kSeed * 7.0);
            clusterTotalCol += cCol * clusterBright * twinkle;
            clusters += clusterBright * twinkle;
        }
        
        // Dust lanes along bar
        float dustLane = smoothstep(barWidth * 0.4, barWidth * 0.2, abs(ruv.y)) *
                         smoothstep(barLen * 0.8, 0.0, abs(ruv.x)) * 0.4;
        
        // GET UNIQUE HARMONIOUS COLOR PALETTE for this barred spiral
        vec3 palCol1, palCol2, palCol3;
        getGalaxyPalette(seed * 111.0, palCol1, palCol2, palCol3);
        
        // Assign palette colors - bar gets warmer tint of primary
        vec3 barCol = palCol3 * 0.8 + vec3(0.15, 0.1, 0.05);  // Warm tint
        vec3 armCol = palCol1;           // Primary for arms
        vec3 hiiCol = palCol2;           // Secondary for HII regions
        vec3 coreCol = mix(barCol, palCol1, 0.2) + vec3(0.05, 0.03, 0.0);
        
        color = barCol * bar * 0.5;
        color -= vec3(0.2, 0.1, 0.0) * dustLane;  // Dust lane in bar
        color += armCol * arms * 0.6;
        color += coreCol * nucleus * 0.15;  // Barely visible nucleus
        color += barCol * bulge * 0.1;      // Very subtle bulge
        color += hiiCol * hii * 0.9;
        color += clusterTotalCol * 0.65;  // Use varied cluster colors
        
        alpha = bar * 0.4 + arms * 0.4 + nucleus * 0.5 + bulge * 0.2 + hii * 0.5 + clusters * 0.3;
    }
    else if(gtype == 2)
    {
        // === ELLIPTICAL GALAXY - JUST GLOBULAR CLUSTERS, NO HALO ===
        float ellip = 0.3 + hash(seed * 26.0) * 0.65;  // More extreme ellipticity range
        vec2 euv = uv * rot2D(seed * 4.0 + hash(seed * 127.0) * 2.0);
        euv.y /= ellip;
        float eR = length(euv);
        
        // NO profile/halo - ellipticals are ONLY their star clusters
        
        // MANY globular clusters - NO HALO, sharp points - GORGEOUS
        float grain = 0.0;
        vec3 gcTotalCol = vec3(0.0);
        
        // GET UNIQUE HARMONIOUS COLOR PALETTE for this elliptical
        vec3 palCol1, palCol2, palCol3;
        getGalaxyPalette(seed * 151.0, palCol1, palCol2, palCol3);
        
        float numGC = 15.0 + hash(seed * 153.0) * 15.0;  // 15-30 globular clusters
        for(float k = 0.0; k < 30.0; k++)
        {
            if(k >= numGC) break;
            vec2 gPos = (hash3(vec3(seed + k * 31.0, k * 17.0, seed)).xy - 0.5) * galaxySize * 1.3;
            // Concentrate toward center with varied distribution
            float concentration = 0.25 + hash(seed + k * 51.0) * 0.75;
            gPos *= concentration;
            float gDist = length(uv - gPos);
            float gSize = galaxySize * (0.001 + hash(seed + k * 71.0) * 0.004);
            // Sharp cutoff
            float gBright = smoothstep(gSize, gSize * 0.1, gDist);
            // Brightness falls off with distance from center
            gBright *= exp(-length(gPos) * length(gPos) / (galaxySize * galaxySize * 0.6));
            gBright *= (0.4 + hash(seed + k * 91.0) * 0.6);
            // Globular cluster colors - blend between palette colors
            float gcBlend = hash(seed + k * 111.0);
            vec3 gcCol = gcBlend < 0.33 ? palCol1 : (gcBlend < 0.66 ? palCol2 : palCol3);
            gcCol = mix(gcCol, vec3(1.0), 0.2);  // Brighten slightly
            // Subtle twinkling
            float twinkle = 0.9 + 0.1 * sin(time * (2.0 + hash(seed + k) * 6.0) + k * 3.0);
            gcTotalCol += gcCol * gBright * twinkle;
            grain += gBright * twinkle;
        }
        grain = min(grain, 3.0);
        
        // Individual stars (optimized: 10)
        float stars = 0.0;
        for(float k = 0.0; k < 10.0; k++)
        {
            float kSeed = seed + k * 43.0 + 300.0;
            vec2 sPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 0.9;
            float sDist = length(uv - sPos);
            float sSize = galaxySize * 0.001;
            stars += smoothstep(sSize, sSize * 0.12, sDist) * exp(-length(sPos) / galaxySize) * 0.5;
        }
        
        // Star color from palette
        vec3 starCol = mix(palCol1, vec3(1.0), 0.6);
        
        color = gcTotalCol * 0.7;           // Globular clusters ARE the galaxy - no halo
        color += starCol * stars * 0.4;
        
        alpha = grain * 0.7 + stars * 0.3;
    }
    else if(gtype == 3)
    {
        // === IRREGULAR GALAXY - FAST ANIMATED SWIRLING CHAOS ===
        float irreg = 0.0;
        vec3 irregCol = vec3(0.0);
        
        // GET UNIQUE HARMONIOUS COLOR PALETTE for this irregular
        vec3 palCol1, palCol2, palCol3;
        getGalaxyPalette(seed * 160.0, palCol1, palCol2, palCol3);
        
        // Random overall shape distortion - FAST ANIMATED
        float shapeType = hash(seed * 160.0);
        vec2 distortedUV = uv;
        if(shapeType < 0.33) {
            // Elongated with fast animated stretch
            float stretchAmt = 0.5 + hash(seed * 161.5) * 0.5 + sin(time * 0.3) * 0.15;
            distortedUV.x *= stretchAmt;
        } else if(shapeType < 0.66) {
            // Warped with fast animated swirl
            float swirlAmt = galaxySize * (0.1 + sin(time * 0.25) * 0.05);
            distortedUV += vec2(sin(uv.y * 15.0 + time * 0.4), cos(uv.x * 15.0 - time * 0.3)) * swirlAmt;
        }
        // else: compact/round
        
        // Variable number of clumps (optimized: 3-8)
        float numClumps = 3.0 + hash(seed * 161.0) * 5.0;
        for(float k = 0.0; k < 8.0; k++)
        {
            if(k >= numClumps) break;
            float kSeed = seed + k * 47.0;
            // Clump positions drift fast over time
            vec2 clumpPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * (0.5 + hash(kSeed * 2.0) * 0.6);
            clumpPos += vec2(sin(time * 0.2 + k * 1.5), cos(time * 0.18 + k * 1.3)) * galaxySize * 0.08;
            
            float clumpDist = length(distortedUV - clumpPos);
            float clumpSize = galaxySize * (0.03 + hash(kSeed + 1.0) * 0.18);
            // Fast animated size pulsing
            clumpSize *= 0.85 + 0.15 * sin(time * 0.5 + k * 2.0);
            
            float sharpness = 0.5 + hash(kSeed + 5.0) * 1.5;
            float clump = exp(-pow(clumpDist / clumpSize, sharpness));
            // Fast animated turbulence
            clump *= (0.5 + turbulentFbm(vec3(nuv * 8.0 + time * 0.15, seed + k)) * 0.7);
            
            // Each clump gets color from harmonious palette with variation
            float clumpHue = hash(kSeed * 3.0);
            vec3 clumpColor;
            if(clumpHue < 0.33) {
                clumpColor = palCol1;
            } else if(clumpHue < 0.66) {
                clumpColor = palCol2;
            } else {
                clumpColor = palCol3;
            }
            // Add some brightness variation
            clumpColor *= (0.8 + hash(kSeed + 10.0) * 0.4);
            
            irregCol += clumpColor * clump * 1.0;
            irreg += clump;
        }
        
        // NO diffuse glow - irregulars are just clumps
        
        // Bright HII knots (optimized: 6)
        float hii = 0.0;
        vec3 hiiColor = vec3(0.0);
        for(float k = 0.0; k < 6.0; k++)
        {
            float kSeed = seed + k * 83.0 + 200.0;
            vec2 hiiPos = (hash3(vec3(kSeed)).xy - 0.5) * galaxySize * 0.65;
            float hiiDist = length(uv - hiiPos);
            float hiiSize = galaxySize * (0.005 + hash(kSeed) * 0.008);
            float thisHii = smoothstep(hiiSize, hiiSize * 0.2, hiiDist);
            hii += thisHii;
            // HII color from palette blend
            vec3 hc = mix(palCol2, palCol3, hash(kSeed + 5.0));
            hc = mix(hc, vec3(1.0), 0.3);  // Brighten
            hiiColor += hc * thisHii;
        }
        hii = min(hii, 2.5);
        
        color = irregCol;
        color += hiiColor * 0.6;
        
        alpha = irreg * 0.7 + hii * 0.4;
    }
    else
    {
        // === EDGE-ON SPIRAL - RANDOMIZED ===
        vec2 euv = uv * rot2D(seed * 5.0 + hash(seed * 181.5) * 1.5);
        
        // GET UNIQUE HARMONIOUS COLOR PALETTE for this edge-on
        vec3 palCol1, palCol2, palCol3;
        getGalaxyPalette(seed * 181.0, palCol1, palCol2, palCol3);
        
        // Random disk properties
        float diskThick = galaxySize * (0.025 + hash(seed * 182.0) * 0.04);  // Variable thickness
        float diskLen = galaxySize * (0.6 + hash(seed * 183.0) * 0.35);  // Variable length
        // Some edge-ons are slightly warped
        float warpAmt = hash(seed * 184.0) * 0.15;
        euv.y += sin(euv.x / galaxySize * 8.0) * warpAmt * galaxySize;
        float disk = smoothstep(diskThick, diskThick * 0.3, abs(euv.y)) *
                     smoothstep(diskLen, diskLen * 0.5, abs(euv.x));
        disk *= (0.7 + noise3D(vec3(euv * 20.0, seed)) * 0.4);
        
        // Central bulge - peanut shaped, very subtle
        float bulgeW = galaxySize * 0.06;
        float bulgeH = galaxySize * 0.04;
        float bulge = exp(-(euv.x * euv.x) / (bulgeW * bulgeW) - (euv.y * euv.y) / (bulgeH * bulgeH)) * 0.2;
        
        // Dust lane through center
        float dustLane = smoothstep(diskThick * 0.3, diskThick * 0.1, abs(euv.y)) *
                         smoothstep(diskLen * 0.8, 0.0, abs(euv.x));
        
        // Tiny nucleus - barely visible
        float nucleus = exp(-length(euv) * length(euv) / (galaxySize * 0.006)) * 0.08;
        
        // Assign palette colors to edge-on components
        vec3 diskCol = palCol1;          // Primary for disk
        vec3 bulgeCol = palCol3 * 0.85 + vec3(0.15, 0.1, 0.05);  // Warmer for bulge
        vec3 coreCol = mix(bulgeCol, palCol2, 0.3) + vec3(0.05, 0.03, 0.0);
        
        color = diskCol * disk * 0.8;
        color -= vec3(0.25, 0.15, 0.05) * dustLane * 0.6;  // Dark dust lane
        color += bulgeCol * bulge * 0.2;   // Subtle bulge
        color += coreCol * nucleus * 0.1;  // Barely visible nucleus
        
        alpha = disk * 0.6 + bulge * 1.0 + nucleus * 1.5;
    }
    
    // Ensure no negative colors from dust lanes
    color = max(color, vec3(0.0));
    
    return vec4(color, alpha);
}

// Cosmic filament structure - THIN CONNECTING LINES between galaxy nodes
float cosmicWeb(vec3 rd, float time)
{
    float web = 0.0;
    const float NUM_NODES = 12.0;
    
    for(float i = 0.0; i < NUM_NODES; i++)
    {
        vec3 node1 = normalize(hash3(vec3(i * 127.1, i * 311.7, i * 74.7)) * 2.0 - 1.0);
        
        for(float j = i + 1.0; j < min(i + 4.0, NUM_NODES); j++)
        {
            vec3 node2 = normalize(hash3(vec3(j * 127.1, j * 311.7, j * 74.7)) * 2.0 - 1.0);
            
            vec3 pa = rd - node1;
            vec3 ba = node2 - node1;
            float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
            float dist = length(pa - ba * h);
            
            float filament = smoothstep(0.08, 0.01, dist);
            float wisp = noise3D(vec3(h * 10.0 + time * 0.02, i, j)) * 0.5 + 0.5;
            web += filament * wisp * 0.4;
        }
    }
    
    return min(web, 1.0);
}

// Render GORGEOUS gaseous filament with SWIRLING, SHIFTING, GLITTERING animation
vec3 renderGasFilament(vec3 rd, vec3 p1, vec3 p2, float seed, float time)
{
    // Distance from ray to line segment
    vec3 pa = rd - p1;
    vec3 ba = p2 - p1;
    float segLen = length(ba);
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    vec3 closest = p1 + ba * h;
    float dist = length(rd - closest);
    
    // ANIMATED width - pulses and breathes
    float baseWidth = 0.03 + hash(seed) * 0.02;
    float widthPulse = 1.0 + sin(time * 0.4 + seed * 3.0) * 0.15;  // Breathing
    float widthWave = 1.0 + sin(h * 12.0 + time * 0.8 + seed * 5.0) * 0.25;  // Wave along length
    float width = baseWidth * widthPulse * widthWave;
    
    // SWIRLING displacement - filament curves and writhes
    float swirl1 = sin(h * 20.0 + time * 1.2 + seed) * 0.012;
    float swirl2 = cos(h * 15.0 - time * 0.9 + seed * 2.0) * 0.01;
    float swirl3 = sin(h * 35.0 + time * 1.8) * 0.006;  // Fine ripples
    float swirlDist = dist + swirl1 + swirl2 + swirl3;
    
    // Moderate core with swirl
    float coreWidth = width * 0.3;
    float core = exp(-swirlDist * swirlDist / (coreWidth * coreWidth)) * 0.9;
    
    // Soft diffuse glow
    float glow = exp(-swirlDist * swirlDist / (width * width)) * 0.5;
    
    // Faint outer halo
    float haloWidth = width * 2.0;
    float halo = exp(-swirlDist * swirlDist / (haloWidth * haloWidth)) * 0.15;
    
    // MOVING wispy structure - flows along filament
    float flowSpeed = 0.3 + hash(seed * 1.5) * 0.3;  // Each filament flows differently
    float wisp1 = noise3D(vec3(h * 15.0 + time * flowSpeed, seed * 2.0, dist * 20.0 + time * 0.2));
    float wisp2 = noise3D(vec3(h * 25.0 - time * flowSpeed * 0.8, seed * 3.0, dist * 35.0 - time * 0.15));
    float wisp3 = noise3D(vec3(h * 40.0 + time * flowSpeed * 1.5, seed * 4.0, dist * 50.0));  // Fast fine detail
    float wispiness = wisp1 * 0.5 + wisp2 * 0.35 + wisp3 * 0.15;
    
    // Combine - bright and visible
    float filament = core + glow * (0.5 + wispiness * 0.7) + halo;
    
    // Gentle end fade
    float endFade = smoothstep(-0.15, 0.25, h) * smoothstep(1.15, 0.75, h);
    filament *= endFade;
    
    // SHIFTING colors - animate through palette
    float colorTime = time * 0.3 + seed * 2.0;
    float colorShift = sin(colorTime) * 0.3 + cos(colorTime * 0.7) * 0.2;
    float hueShift = sin(h * 6.0 + time * 0.5 + seed) * 0.15;  // Color varies along length
    
    vec3 col1 = vec3(0.3 + colorShift * 0.2 + hueShift, 0.5, 1.0);    // Blue shifting
    vec3 col2 = vec3(0.7, 0.3 + colorShift * 0.15, 0.9 - hueShift * 0.2);   // Violet shifting
    vec3 col3 = vec3(1.0, 0.35 + colorShift * 0.2 + hueShift * 0.1, 0.6);   // Pink shifting
    vec3 col4 = vec3(0.4 + hueShift * 0.2, 0.8 - colorShift * 0.15, 0.9);   // Cyan shifting
    
    // Animated transitions along filament
    float t1 = smoothstep(0.0, 0.35, h + sin(time * 0.4) * 0.1);
    float t2 = smoothstep(0.25, 0.65, h + cos(time * 0.35) * 0.1);
    float t3 = smoothstep(0.55, 0.95, h - sin(time * 0.45) * 0.1);
    
    vec3 filColor = mix(col1, col2, t1);
    filColor = mix(filColor, col3, t2 * (0.5 + hash(seed + 1.0) * 0.5));
    filColor = mix(filColor, col4, t3 * hash(seed + 2.0));
    
    // GLITTERING emission knots (optimized: 6)
    float knots = 0.0;
    vec3 knotColors = vec3(0.0);
    for(float k = 0.0; k < 6.0; k++)
    {
        float kSeed = seed + k * 17.0;
        // Knots MOVE along the filament!
        float kBasePos = hash(kSeed);
        float kSpeed = 0.1 + hash(kSeed + 5.0) * 0.15;
        float kPos = fract(kBasePos + time * kSpeed);  // Moves along filament
        float kDist = abs(h - kPos);
        // Wrap-around distance
        kDist = min(kDist, 1.0 - kDist);
        float kSize = 0.04 + hash(kSeed + 23.0) * 0.04;
        float knot = smoothstep(kSize, kSize * 0.15, kDist);
        knot *= exp(-swirlDist * swirlDist / (width * width * 1.5));
        
        // GLITTER - rapid brightness fluctuation
        float glitterSpeed = 8.0 + hash(kSeed + 7.0) * 15.0;
        float glitter = 0.6 + 0.4 * sin(time * glitterSpeed + kSeed * 10.0);
        knot *= glitter;
        
        // Varied knot colors - some pink, some orange, some white
        float kHue = hash(kSeed + 30.0);
        vec3 kCol;
        if(kHue < 0.35) kCol = vec3(1.0, 0.45, 0.55);      // Pink
        else if(kHue < 0.6) kCol = vec3(1.0, 0.7, 0.4);   // Orange
        else if(kHue < 0.8) kCol = vec3(0.9, 0.85, 1.0);  // Pale violet
        else kCol = vec3(1.0, 0.95, 0.9);                  // White
        
        knotColors += kCol * knot * (0.4 + hash(kSeed + 31.0) * 0.5);
        knots += knot;
    }
    filColor += knotColors * 0.6;
    
    // Overall brightness pulse - subtle breathing
    float breathe = 0.9 + 0.1 * sin(time * 0.25 + seed * 4.0);
    
    return filColor * filament * 0.3 * breathe;  // Slightly brighter output
}

// Background with galaxies spread across sky - NO central blob
vec3 cosmicWebBackground(vec3 rd, float time)
{
    // Very dark background
    vec3 color = vec3(0.002, 0.001, 0.005);
    
    // Store galaxy positions for filament connections - SPREAD ALL AROUND THE SKY
    const int NUM_MAIN_GALAXIES = 20;
    vec3 gPositions[20];
    
    // === GALAXIES DISTRIBUTED ALL AROUND - HIGHLY VARIED SIZES ===
    // Front hemisphere (+Z)
    vec3 g1Pos = normalize(vec3(-0.6, 0.5, 0.6));
    gPositions[0] = g1Pos;
    color += renderGalaxy(rd, g1Pos, 0.08 + hash(sessionSeed * 1.1) * 0.08, sessionSeed + 10.0, time, 0).rgb;
    
    vec3 g2Pos = normalize(vec3(0.7, 0.2, 0.7));
    gPositions[1] = g2Pos;
    color += renderGalaxy(rd, g2Pos, 0.06 + hash(sessionSeed * 1.2) * 0.09, sessionSeed + 20.0, time, 1).rgb;
    
    vec3 g3Pos = normalize(vec3(0.1, -0.6, 0.75));
    gPositions[2] = g3Pos;
    color += renderGalaxy(rd, g3Pos, 0.09 + hash(sessionSeed * 1.3) * 0.1, sessionSeed + 30.0, time, 2).rgb;
    
    vec3 g4Pos = normalize(vec3(0.5, 0.6, 0.55));
    gPositions[3] = g4Pos;
    color += renderGalaxy(rd, g4Pos, 0.05 + hash(sessionSeed * 1.4) * 0.07, sessionSeed + 40.0, time, 4).rgb;
    
    // Back hemisphere (-Z)
    vec3 g5Pos = normalize(vec3(-0.5, 0.4, -0.7));
    gPositions[4] = g5Pos;
    color += renderGalaxy(rd, g5Pos, 0.07 + hash(sessionSeed * 1.5) * 0.09, sessionSeed + 50.0, time, 0).rgb;
    
    vec3 g6Pos = normalize(vec3(0.6, -0.3, -0.65));
    gPositions[5] = g6Pos;
    color += renderGalaxy(rd, g6Pos, 0.06 + hash(sessionSeed * 1.6) * 0.08, sessionSeed + 60.0, time, 1).rgb;
    
    vec3 g7Pos = normalize(vec3(-0.3, -0.5, -0.8));
    gPositions[6] = g7Pos;
    color += renderGalaxy(rd, g7Pos, 0.08 + hash(sessionSeed * 1.7) * 0.1, sessionSeed + 70.0, time, 2).rgb;
    
    vec3 g8Pos = normalize(vec3(0.2, 0.7, -0.65));
    gPositions[7] = g8Pos;
    color += renderGalaxy(rd, g8Pos, 0.05 + hash(sessionSeed * 1.8) * 0.07, sessionSeed + 80.0, time, 3).rgb;
    
    // Left hemisphere (-X)
    vec3 g9Pos = normalize(vec3(-0.8, 0.3, 0.2));
    gPositions[8] = g9Pos;
    color += renderGalaxy(rd, g9Pos, 0.07 + hash(sessionSeed * 1.9) * 0.09, sessionSeed + 90.0, time, 0).rgb;
    
    vec3 g10Pos = normalize(vec3(-0.75, -0.4, -0.3));
    gPositions[9] = g10Pos;
    color += renderGalaxy(rd, g10Pos, 0.06 + hash(sessionSeed * 2.0) * 0.08, sessionSeed + 100.0, time, 4).rgb;
    
    // Right hemisphere (+X)
    vec3 g11Pos = normalize(vec3(0.85, 0.1, 0.3));
    gPositions[10] = g11Pos;
    color += renderGalaxy(rd, g11Pos, 0.05 + hash(sessionSeed * 2.1) * 0.07, sessionSeed + 110.0, time, 2).rgb;
    
    vec3 g12Pos = normalize(vec3(0.8, -0.35, -0.25));
    gPositions[11] = g12Pos;
    color += renderGalaxy(rd, g12Pos, 0.07 + hash(sessionSeed * 2.2) * 0.09, sessionSeed + 120.0, time, 0).rgb;
    
    // Top hemisphere (+Y)
    vec3 g13Pos = normalize(vec3(0.2, 0.85, 0.3));
    gPositions[12] = g13Pos;
    color += renderGalaxy(rd, g13Pos, 0.06 + hash(sessionSeed * 2.3) * 0.08, sessionSeed + 130.0, time, 1).rgb;
    
    vec3 g14Pos = normalize(vec3(-0.25, 0.8, -0.35));
    gPositions[13] = g14Pos;
    color += renderGalaxy(rd, g14Pos, 0.05 + hash(sessionSeed * 2.4) * 0.07, sessionSeed + 140.0, time, 3).rgb;
    
    // Bottom hemisphere (-Y)
    vec3 g15Pos = normalize(vec3(0.15, -0.85, 0.25));
    gPositions[14] = g15Pos;
    color += renderGalaxy(rd, g15Pos, 0.07 + hash(sessionSeed * 2.5) * 0.09, sessionSeed + 150.0, time, 0).rgb;
    
    vec3 g16Pos = normalize(vec3(-0.3, -0.8, -0.3));
    gPositions[15] = g16Pos;
    color += renderGalaxy(rd, g16Pos, 0.06 + hash(sessionSeed * 2.6) * 0.08, sessionSeed + 160.0, time, 4).rgb;
    
    // Interacting pairs - varied sizes
    vec3 g17aPos = normalize(vec3(0.4, -0.45, 0.7));
    gPositions[16] = g17aPos;
    color += renderGalaxy(rd, g17aPos, 0.05 + hash(sessionSeed * 2.7) * 0.06, sessionSeed + 170.0, time, 0).rgb;
    
    vec3 g17bPos = normalize(vec3(0.48, -0.4, 0.68));
    gPositions[17] = g17bPos;
    color += renderGalaxy(rd, g17bPos, 0.03 + hash(sessionSeed * 2.8) * 0.04, sessionSeed + 171.0, time, 3).rgb;
    
    vec3 g18aPos = normalize(vec3(-0.45, 0.3, -0.75));
    gPositions[18] = g18aPos;
    color += renderGalaxy(rd, g18aPos, 0.05 + hash(sessionSeed * 2.9) * 0.06, sessionSeed + 180.0, time, 0).rgb;
    
    vec3 g18bPos = normalize(vec3(-0.38, 0.35, -0.78));
    gPositions[19] = g18bPos;
    color += renderGalaxy(rd, g18bPos, 0.03 + hash(sessionSeed * 3.0) * 0.04, sessionSeed + 181.0, time, 3).rgb;
    
    // === GASEOUS FILAMENTS connecting ALL nearby galaxies ===
    for(int i = 0; i < 20; i++)
    {
        for(int j = i + 1; j < 20; j++)
        {
            float separation = length(gPositions[i] - gPositions[j]);
            // Connect galaxies across the whole sky
            if(separation < 1.2 && separation > 0.08)
            {
                float filSeed = sessionSeed + float(i) * 100.0 + float(j) * 10.0;
                // Moderate filaments
                float strength = smoothstep(1.2, 0.15, separation) * 1.3 + 0.4;
                vec3 fil = renderGasFilament(rd, gPositions[i], gPositions[j], filSeed, time);
                color += fil * strength;
            }
        }
    }
    
    // Tidal streams between interacting pairs
    color += renderGasFilament(rd, g17aPos, g17bPos, sessionSeed + 500.0, time) * 3.0;
    color += renderGasFilament(rd, g18aPos, g18bPos, sessionSeed + 501.0, time) * 3.0;
    
    // === DENSE GALAXY CLUSTERS - multiple regions with MANY galaxies packed together ===
    // Each cluster has UNIQUE animation timing!
    
    // Cluster 1 - Rich cluster in front-right area (optimized: 8 galaxies)
    vec3 cluster1Center = normalize(vec3(0.55, 0.25, 0.65));
    float cluster1TimeScale = 1.4;
    float cluster1TimeOffset = 0.0;
    for(float i = 0.0; i < 8.0; i++)
    {
        float seed = sessionSeed * 3.0 + i * 73.0 + 1000.0;
        // Galaxies clustered tightly around center
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.25;
        // Galaxies orbit cluster center slowly
        float orbitSpeed = 0.02 + hash(seed * 1.5) * 0.03;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.xz += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.03;
        vec3 gPos = normalize(cluster1Center + offset);
        float gSize = 0.015 + hash(seed * 2.1) * 0.035;
        int gType = int(hash(seed * 3.1) * 5.0);
        // Unique time for this cluster
        float localTime = time * cluster1TimeScale + cluster1TimeOffset + hash(seed) * 10.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 137.0, localTime, gType);
        color += g.rgb * 0.6;
    }
    
    // Cluster 2 - Dense cluster in back-left area (optimized: 6 galaxies)
    vec3 cluster2Center = normalize(vec3(-0.6, 0.15, -0.7));
    float cluster2TimeScale = 0.6;
    float cluster2TimeOffset = 15.0;
    for(float i = 0.0; i < 6.0; i++)
    {
        float seed = sessionSeed * 3.5 + i * 89.0 + 2000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.22;
        // Orbital motion
        float orbitSpeed = 0.015 + hash(seed * 1.5) * 0.02;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.xy += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.025;
        vec3 gPos = normalize(cluster2Center + offset);
        float gSize = 0.012 + hash(seed * 2.2) * 0.03;
        int gType = int(hash(seed * 3.2) * 5.0);
        float localTime = time * cluster2TimeScale + cluster2TimeOffset + hash(seed) * 8.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 141.0, localTime, gType);
        color += g.rgb * 0.55;
    }
    
    // Cluster 3 - Massive cluster below (optimized: 8 galaxies)
    vec3 cluster3Center = normalize(vec3(0.1, -0.75, 0.4));
    for(float i = 0.0; i < 8.0; i++)
    {
        float seed = sessionSeed * 4.0 + i * 67.0 + 3000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.3;
        // More chaotic orbital motion
        float orbitSpeed = 0.01 + hash(seed * 1.5) * 0.05;  // Wide speed range
        float orbitPhase = hash(seed * 1.7) * 6.28;
        float orbitRadius = 0.02 + hash(seed * 1.9) * 0.04;
        offset += vec3(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed * 0.7 + orbitPhase), cos(time * orbitSpeed * 1.3)) * orbitRadius;
        vec3 gPos = normalize(cluster3Center + offset);
        float gSize = 0.01 + hash(seed * 2.3) * 0.04;
        int gType = int(hash(seed * 3.3) * 5.0);
        // Each galaxy in this cluster has VERY different time scale
        float localTimeScale = 0.5 + hash(seed * 4.1) * 1.5;
        float localTime = time * localTimeScale + hash(seed) * 20.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 149.0, localTime, gType);
        color += g.rgb * 0.5;
    }
    
    // Cluster 4 - Compact cluster upper-left (optimized: 5 galaxies)
    vec3 cluster4Center = normalize(vec3(-0.5, 0.7, 0.3));
    float cluster4TimeScale = 1.1;
    float cluster4Pulse = sin(time * 0.3) * 0.2;
    for(float i = 0.0; i < 5.0; i++)
    {
        float seed = sessionSeed * 4.5 + i * 97.0 + 4000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.18;
        // Breathing motion - galaxies move in/out from center
        float breathPhase = hash(seed * 1.6) * 6.28;
        offset *= 1.0 + sin(time * 0.15 + breathPhase) * 0.15;
        vec3 gPos = normalize(cluster4Center + offset);
        float gSize = (0.018 + hash(seed * 2.4) * 0.025) * (1.0 + cluster4Pulse);
        int gType = int(hash(seed * 3.4) * 5.0);
        float localTime = time * cluster4TimeScale + i * 2.0;  // Slight phase offset per galaxy
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 157.0, localTime, gType);
        color += g.rgb * 0.6;
    }
    
    // Cluster 5 - Rich cluster far right (optimized: 6 galaxies)
    vec3 cluster5Center = normalize(vec3(0.8, -0.2, -0.4));
    float cluster5TimeScale = -0.8;
    float cluster5TimeOffset = 30.0;
    for(float i = 0.0; i < 6.0; i++)
    {
        float seed = sessionSeed * 5.0 + i * 83.0 + 5000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.24;
        // Counter-rotating orbital motion
        float orbitSpeed = 0.025 + hash(seed * 1.5) * 0.025;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.yz += vec2(cos(-time * orbitSpeed + orbitPhase), sin(-time * orbitSpeed + orbitPhase)) * 0.03;
        vec3 gPos = normalize(cluster5Center + offset);
        float gSize = 0.013 + hash(seed * 2.5) * 0.032;
        int gType = int(hash(seed * 3.5) * 5.0);
        float localTime = time * cluster5TimeScale + cluster5TimeOffset + hash(seed) * 12.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 163.0, abs(localTime), gType);
        color += g.rgb * 0.55;
    }
    
    // Cluster 6 - Distant dense cluster behind (optimized: 7 galaxies)
    vec3 cluster6Center = normalize(vec3(0.25, 0.4, -0.85));
    float cluster6TimeScale = 0.4;
    float cluster6TimeOffset = 50.0;
    for(float i = 0.0; i < 7.0; i++)
    {
        float seed = sessionSeed * 5.5 + i * 71.0 + 6000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.28;
        // Very subtle drift
        float driftSpeed = 0.005 + hash(seed * 1.5) * 0.01;
        float driftPhase = hash(seed * 1.7) * 6.28;
        offset += vec3(sin(time * driftSpeed + driftPhase), cos(time * driftSpeed * 0.8), sin(time * driftSpeed * 1.2)) * 0.015;
        vec3 gPos = normalize(cluster6Center + offset);
        float gSize = 0.008 + hash(seed * 2.6) * 0.025;  // Smaller - more distant
        int gType = int(hash(seed * 3.6) * 5.0);
        float localTime = time * cluster6TimeScale + cluster6TimeOffset + hash(seed) * 15.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 167.0, localTime, gType);
        color += g.rgb * 0.45;
    }
    
    // === SCATTERED FIELD GALAXIES (increased: 20) ===
    for(float i = 0.0; i < 20.0; i++)
    {
        float seed = sessionSeed * 2.0 + i * 337.0;
        
        // Spread evenly around the sky
        float angH = i * 0.15 + hash(seed) * 0.5;
        float angV = (hash(seed * 1.5) - 0.5) * 2.8;
        vec3 gPos = normalize(vec3(cos(angH) * cos(angV), sin(angV), sin(angH) * cos(angV)));
        
        // Add subtle wobble/drift to position
        float wobbleSpeed = 0.01 + hash(seed * 1.8) * 0.02;
        float wobblePhase = hash(seed * 1.9) * 6.28;
        gPos = normalize(gPos + vec3(
            sin(time * wobbleSpeed + wobblePhase) * 0.01,
            cos(time * wobbleSpeed * 0.8 + wobblePhase) * 0.01,
            sin(time * wobbleSpeed * 1.2 + wobblePhase * 2.0) * 0.01
        ));
        
        // Small to medium sizes
        float gSize = 0.015 + hash(seed * 2.2) * 0.04;
        
        // Random type
        int gType = int(hash(seed * 3.3) * 5.0);
        
        // UNIQUE animation timing for each field galaxy
        float localTimeScale = 0.6 + hash(seed * 4.4) * 1.2;  // 0.6x to 1.8x speed
        float localTimeOffset = hash(seed * 5.5) * 50.0;  // Random phase offset
        float localTime = time * localTimeScale + localTimeOffset;
        
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 137.0, localTime, gType);
        color += g.rgb * 0.45;
    }
    
    // === ADDITIONAL GALAXY CLUSTERS (6 more) ===
    
    // Cluster 7 - Upper right region
    vec3 cluster7Center = normalize(vec3(0.7, 0.55, 0.35));
    float cluster7TimeScale = 1.2;
    for(float i = 0.0; i < 10.0; i++)
    {
        float seed = sessionSeed * 6.0 + i * 79.0 + 7000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.26;
        float orbitSpeed = 0.02 + hash(seed * 1.5) * 0.03;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.xz += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.025;
        vec3 gPos = normalize(cluster7Center + offset);
        float gSize = 0.012 + hash(seed * 2.1) * 0.03;
        int gType = int(hash(seed * 3.1) * 5.0);
        float localTime = time * cluster7TimeScale + hash(seed) * 12.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 173.0, localTime, gType);
        color += g.rgb * 0.5;
    }
    
    // Cluster 8 - Lower left region
    vec3 cluster8Center = normalize(vec3(-0.65, -0.5, 0.45));
    float cluster8TimeScale = 0.7;
    for(float i = 0.0; i < 8.0; i++)
    {
        float seed = sessionSeed * 6.5 + i * 91.0 + 8000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.22;
        float orbitSpeed = 0.015 + hash(seed * 1.5) * 0.025;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.yz += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.02;
        vec3 gPos = normalize(cluster8Center + offset);
        float gSize = 0.01 + hash(seed * 2.2) * 0.028;
        int gType = int(hash(seed * 3.2) * 5.0);
        float localTime = time * cluster8TimeScale + hash(seed) * 10.0 + 20.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 179.0, localTime, gType);
        color += g.rgb * 0.5;
    }
    
    // Cluster 9 - Front center-left
    vec3 cluster9Center = normalize(vec3(-0.3, 0.1, 0.9));
    float cluster9TimeScale = 0.9;
    for(float i = 0.0; i < 9.0; i++)
    {
        float seed = sessionSeed * 7.0 + i * 103.0 + 9000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.24;
        float orbitSpeed = 0.018 + hash(seed * 1.5) * 0.022;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.xy += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.022;
        vec3 gPos = normalize(cluster9Center + offset);
        float gSize = 0.013 + hash(seed * 2.3) * 0.032;
        int gType = int(hash(seed * 3.3) * 5.0);
        float localTime = time * cluster9TimeScale + hash(seed) * 14.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 181.0, localTime, gType);
        color += g.rgb * 0.55;
    }
    
    // Cluster 10 - Deep background top
    vec3 cluster10Center = normalize(vec3(0.15, 0.85, -0.4));
    float cluster10TimeScale = 0.5;
    for(float i = 0.0; i < 7.0; i++)
    {
        float seed = sessionSeed * 7.5 + i * 107.0 + 10000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.2;
        float driftSpeed = 0.008 + hash(seed * 1.5) * 0.012;
        float driftPhase = hash(seed * 1.7) * 6.28;
        offset += vec3(sin(time * driftSpeed + driftPhase), cos(time * driftSpeed), sin(time * driftSpeed * 0.9)) * 0.012;
        vec3 gPos = normalize(cluster10Center + offset);
        float gSize = 0.008 + hash(seed * 2.4) * 0.022;
        int gType = int(hash(seed * 3.4) * 5.0);
        float localTime = time * cluster10TimeScale + hash(seed) * 18.0 + 40.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 191.0, localTime, gType);
        color += g.rgb * 0.4;
    }
    
    // Cluster 11 - Side right-back
    vec3 cluster11Center = normalize(vec3(0.85, 0.0, -0.35));
    float cluster11TimeScale = 1.0;
    for(float i = 0.0; i < 8.0; i++)
    {
        float seed = sessionSeed * 8.0 + i * 113.0 + 11000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.23;
        float orbitSpeed = 0.02 + hash(seed * 1.5) * 0.02;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.xz += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.025;
        vec3 gPos = normalize(cluster11Center + offset);
        float gSize = 0.011 + hash(seed * 2.5) * 0.028;
        int gType = int(hash(seed * 3.5) * 5.0);
        float localTime = time * cluster11TimeScale + hash(seed) * 11.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 193.0, localTime, gType);
        color += g.rgb * 0.5;
    }
    
    // Cluster 12 - Bottom back
    vec3 cluster12Center = normalize(vec3(-0.4, -0.6, -0.6));
    float cluster12TimeScale = 0.65;
    for(float i = 0.0; i < 9.0; i++)
    {
        float seed = sessionSeed * 8.5 + i * 119.0 + 12000.0;
        vec3 offset = (hash3(vec3(seed)) - 0.5) * 0.25;
        float orbitSpeed = 0.012 + hash(seed * 1.5) * 0.02;
        float orbitPhase = hash(seed * 1.7) * 6.28;
        offset.yz += vec2(cos(time * orbitSpeed + orbitPhase), sin(time * orbitSpeed + orbitPhase)) * 0.02;
        vec3 gPos = normalize(cluster12Center + offset);
        float gSize = 0.01 + hash(seed * 2.6) * 0.026;
        int gType = int(hash(seed * 3.6) * 5.0);
        float localTime = time * cluster12TimeScale + hash(seed) * 16.0 + 35.0;
        vec4 g = renderGalaxy(rd, gPos, gSize, seed * 197.0, localTime, gType);
        color += g.rgb * 0.45;
    }
    
    // === BRIGHT FOREGROUND STARS (optimized: 8) ===
    for(float s = 0.0; s < 8.0; s++)
    {
        float sSeed = sessionSeed + s * 97.0 + 500.0;
        vec3 starPos = normalize(hash3(vec3(sSeed)) * 2.0 - 1.0);
        float starDist = length(rd - starPos);
        
        // Sharp bright star core
        float star = exp(-starDist * starDist / 0.00004);
        
        // Diffraction spikes (6-pointed like HST)
        vec3 toStar = rd - starPos;
        float spike1 = exp(-abs(toStar.x) / 0.0008 - starDist * 35.0);
        float spike2 = exp(-abs(toStar.y) / 0.0008 - starDist * 35.0);
        float spike3 = exp(-abs(toStar.x + toStar.y) / 0.0012 - starDist * 35.0);
        float spike4 = exp(-abs(toStar.x - toStar.y) / 0.0012 - starDist * 35.0);
        star += (spike1 + spike2 + spike3 + spike4) * 0.15;
        
        // Star color - MORE red and white variety
        float starTemp = hash(sSeed + 1.0);
        vec3 starCol;
        if(starTemp < 0.25) starCol = vec3(1.0, 0.5, 0.3);        // Red/orange
        else if(starTemp < 0.4) starCol = vec3(1.0, 0.7, 0.5);   // Warm orange
        else if(starTemp < 0.7) starCol = vec3(1.0, 0.98, 0.95); // White
        else if(starTemp < 0.85) starCol = vec3(0.9, 0.95, 1.0); // Blue-white
        else starCol = vec3(1.0, 0.4, 0.35);                      // Deep red
        
        // Add flickering
        float flicker = 0.85 + 0.15 * sin(time * (8.0 + hash(sSeed) * 12.0) + sSeed * 10.0);
        
        color += starCol * star * 1.3 * flicker;
    }
    
    // === FLICKERING BACKGROUND DOTS (optimized: 15) ===
    for(float s = 0.0; s < 15.0; s++)
    {
        float sSeed = sessionSeed + s * 53.0 + 800.0;
        vec3 starPos = normalize(hash3(vec3(sSeed)) * 2.0 - 1.0);
        float starDist = length(rd - starPos);
        
        // Tiny crisp dot - 2x smaller again
        float star = exp(-starDist * starDist / 0.000017);
        
        // Color - biased toward red and white
        float starTemp = hash(sSeed + 2.0);
        vec3 starCol;
        if(starTemp < 0.35) starCol = vec3(1.0, 0.45, 0.35);      // Red
        else if(starTemp < 0.55) starCol = vec3(1.0, 0.6, 0.45);  // Orange-red
        else if(starTemp < 0.8) starCol = vec3(1.0, 0.97, 0.93);  // White
        else starCol = vec3(0.95, 0.95, 1.0);                      // Cool white
        
        // Flickering - different speeds
        float flickerSpeed = 5.0 + hash(sSeed + 3.0) * 20.0;
        float flicker = 0.7 + 0.3 * sin(time * flickerSpeed + sSeed * 7.0);
        
        color += starCol * star * 1.4 * flicker;
    }
    
    // Faint background star field
    float bgStars = stars(rd.xy * 3.0 + rd.z, sessionSeed);
    color += vec3(0.85, 0.85, 0.9) * bgStars * 0.12;
    
    return clamp(color, 0.0, 1.0);
}

void main()
{
    vec2 fragCoord = vUv * iResolution;
    
    // ========== CONSOLE MODE - Replace entire scene with terminal ==========
    if(iConsoleMode > 0.5)
    {
        vec2 screenUV = fragCoord / iResolution.xy;
        vec3 color = renderConsole(screenUV, iTime);
        gl_FragColor = vec4(color, 1.0);
        return;
    }
    
    // Initialize session seed from JavaScript random value - truly random per page load
    sessionSeed = iRandomSeed;
    
    // ========== FLY-THROUGH CAMERA ==========
    // Camera orbits around black hole at center, periodically pulls back for full view
    // Cycle: inside (orbiting black hole) -> pull out -> full scene view -> back in
    
    float cycleTime = iTime * 0.1;  // Full cycle speed
    float cyclePhase = mod(cycleTime, 6.283185);  // 0 to 2*PI cycle
    
    // Smooth transition factor: 0 = inside near black hole, 1 = outside viewing whole scene
    // Spends more time inside, quick pull-out and return
    float insideOutside = smoothstep(4.5, 5.5, cyclePhase) * (1.0 - smoothstep(5.8, 6.283185, cyclePhase));
    
    // Inside orbit parameters - stay within central void of Menger sponge
    // The central cavity is ~0.67 units (1/3 of size 2 cube), so keep radius < 0.3
    float orbitSpeed = iTime * 0.3;
    float insideRadius = 0.25;  // Safe orbit within central void
    vec3 insidePos = vec3(
        sin(orbitSpeed) * insideRadius,
        sin(orbitSpeed * 0.7 + 1.0) * insideRadius * 0.3,  // Minimal vertical bob
        cos(orbitSpeed) * insideRadius
    );
    
    // Outside position - pull back to see whole scene
    float outsideRadius = 6.0;
    vec3 outsidePos = vec3(
        sin(orbitSpeed * 0.3) * outsideRadius,
        cos(orbitSpeed * 0.2) * outsideRadius * 0.5 + 2.0,  // Slightly above
        cos(orbitSpeed * 0.3) * outsideRadius
    );
    
    // Blend between inside and outside positions
    vec3 cam_pos = mix(insidePos, outsidePos, insideOutside);
    
    // Check if inside cube bounds (cube is size 2.0, so bounds are -2 to 2)
    bool insideCubeBounds = abs(cam_pos.x) < 2.0 && abs(cam_pos.y) < 2.0 && abs(cam_pos.z) < 2.0;
    
    // Set global flag for map() function to use constant iterations when inside
    gCameraInsideCube = insideCubeBounds;
    
    // Always look at the black hole (center of the cube)
    vec3 target = vec3(0.0);
    
    // When outside, add slight offset to see more of the scene
    if (insideOutside > 0.5) {
        target = vec3(sin(iTime * 0.1) * 0.3, 0.0, cos(iTime * 0.1) * 0.3);
    }
    
    vec3 cam_dir = normalize(target - cam_pos);
    
    // Camera basis vectors
    vec3 cam_up = vec3(0.0, 1.0, 0.0);
    // Add gentle roll based on orbit
    float roll = sin(orbitSpeed * 0.3) * 0.15;
    cam_up = vec3(sin(roll), cos(roll), 0.0);
    
    vec3 cam_x = normalize(cross(cam_dir, cam_up));
    vec3 cam_y = cross(cam_x, cam_dir);
    
    // UV coordinates with aspect ratio correction
    vec2 uv = -1.0 + 2.0 * fragCoord / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    
    // Wider FOV when inside cube for more immersive feel
    float fov = insideCubeBounds ? 1.4 : 1.0;
    vec3 ray_dir = normalize(cam_dir * fov + uv.x * cam_x + uv.y * cam_y);
    
    // Ray march the cube with STRAIGHT rays (no lensing on cube)
    vec3 c = intersect(cam_pos, ray_dir);
    
    vec3 color = vec3(0.0);
    
    if(c.x > 0.0) {
        // HIT THE CUBE - render normally without any black hole effects
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
        
        // Base color - steel blue/white to red/black palette
        // Smoothly transition between the two color schemes based on position
        float colorMix = sin(length(hitPos) * 2.0 + iTime * 0.15) * 0.5 + 0.5;
        
        // Steel blue / white palette
        vec3 steelBlue = vec3(0.4, 0.5, 0.6);      // Steel blue
        vec3 lightSteel = vec3(0.7, 0.8, 0.9);     // Light steel / white-ish
        vec3 white = vec3(0.95, 0.95, 1.0);        // Cold white
        
        // Red / black palette
        vec3 deepRed = vec3(0.6, 0.1, 0.1);        // Deep red
        vec3 darkRed = vec3(0.3, 0.05, 0.05);      // Dark red
        vec3 black = vec3(0.02, 0.02, 0.02);       // Near black
        
        // Position-based variation within each palette
        float posVar = fract(dot(hitPos, vec3(1.7, 2.3, 1.9)) * 0.5);
        
        // Steel blue palette color
        vec3 steelColor = mix(steelBlue, lightSteel, posVar);
        steelColor = mix(steelColor, white, pow(posVar, 2.0) * 0.5);
        
        // Red/black palette color  
        vec3 redColor = mix(darkRed, deepRed, posVar);
        redColor = mix(redColor, black, (1.0 - posVar) * 0.6);
        
        // Blend between the two palettes
        vec3 baseColor = mix(steelColor, redColor, colorMix);
        
        // Combine lighting
        vec3 ambient = vec3(0.05, 0.05, 0.08) * ao;
        vec3 diffuse = baseColor * (diff1 * lightCol1 * shadow1 + diff2 * lightCol2 * shadow2);
        vec3 specular = (spec1 * lightCol1 * shadow1 + spec2 * lightCol2 * shadow2) * 0.5;
        
        // Rim glow - subtle steel blue or red tint
        vec3 rimColor = mix(vec3(0.5, 0.6, 0.8), vec3(0.8, 0.2, 0.1), colorMix);
        vec3 rim = fresnel * rimColor * 0.6;
        
        // Inner glow when close to surface
        float innerGlow = exp(-c.x * 2.0) * 0.3;
        vec3 glowColor = mix(vec3(0.4, 0.5, 0.7), vec3(0.5, 0.1, 0.1), colorMix);
        
        color = ambient + diffuse + specular + rim + glowColor * innerGlow;
        
        // Depth fog with colored atmosphere
        float fog = 1.0 - exp(-c.x * 0.2);
        vec3 fogColor = vec3(0.02, 0.01, 0.05); // Deep purple-black
        color = mix(color, fogColor, fog);
        
        // Tone mapping
        color = color / (color + vec3(1.0));
        
        // Subtle vignette glow
        color += innerGlow * glowColor * 0.2;
        
    } else {
        // BACKGROUND - Apply gravitational lensing ONLY here
        // Compute lensed ray direction for background
        vec3 lensedBgDir = gravitationalLensing(cam_pos, ray_dir, BLACK_HOLE_MASS * 2.0);
        
        // Additional bending for rays close to black hole
        vec3 bentPos = cam_pos;
        for(int i = 0; i < 4; i++)
        {
            float distToHole = length(bentPos - BLACK_HOLE_POS);
            if(distToHole < 2.0) {
                float bendStrength = BLACK_HOLE_MASS * (2.0 - distToHole) * 0.5;
                lensedBgDir = gravitationalLensing(bentPos, lensedBgDir, bendStrength);
            }
            bentPos = bentPos + lensedBgDir * 0.3;
            if(length(bentPos - BLACK_HOLE_POS) < EVENT_HORIZON) break;
        }
        
        // Check if ORIGINAL ray hits black hole sphere - always render as solid black
        // This ensures black hole always appears as a black sphere
        if(hitsEventHorizon(cam_pos, ray_dir))
        {
            // Solid black sphere
            color = vec3(0.0);
        }
        // Also check if the lensed ray gets swallowed
        else if(hitsEventHorizon(cam_pos, lensedBgDir))
        {
            // Black hole silhouette against background
            color = vec3(0.0);
        }
        else
        {
            // Render cosmic background with lensed ray
            color = cosmicWebBackground(lensedBgDir, iTime);
        }
        
        // Add photon sphere glow and accretion disk on top (but not on black hole itself)
        if(!hitsEventHorizon(cam_pos, ray_dir))
        {
            color += renderPhotonSphere(cam_pos, ray_dir);
            color += renderAccretionDisk(cam_pos, ray_dir, iTime);
        }
    }
    
    // Gamma correction
    color = pow(color, vec3(0.8));
    
    gl_FragColor = vec4(color, 1.0);
}
