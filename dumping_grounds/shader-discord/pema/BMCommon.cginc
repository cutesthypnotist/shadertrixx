static const uint particleTexSize = 512;
static const uint densityTexSize = 4096;
static const uint densityVolSize = 256;
static const float invDensityTexSize = 2.0 / densityTexSize; // 2 to match size of cube

float2x2 Rot(float a) {
    float s=sin(a), c=cos(a);
    return float2x2(c, -s, s, c);
}

uint Idx3to1(uint3 p, uint size) {
    return p.x + size*p.y + size*size*p.z;
}

uint3 Idx1to3(uint idx, uint size) {
    uint x = idx % size;
    uint y = (idx / size) % size;
    uint z = idx / (size * size);
    return uint3(x, y, z);
}

uint Idx2to1(uint2 p, uint size)
{
    return p.x + size * p.y;
}

uint2 Idx1to2(uint idx, uint size)
{
    uint x = idx % size;
    uint y = idx / size;
    return uint2(x, size-1-y); // textures are usually flipped w.r.t world coords on y axis
}

uint2 VolToTex(uint3 volCoord)
{
    uint volIdx = Idx3to1(volCoord, densityVolSize);
    uint2 texCoord = Idx1to2(volIdx, densityTexSize);
    return texCoord;
}

uint3 TexToVol(uint2 texCoord)
{
    uint texIdx = Idx2to1(texCoord, densityTexSize);
    uint3 volCoord = Idx1to3(texIdx, densityVolSize);
    return volCoord;
}

float rand(float co) { return frac(sin(co*(91.3458)) * 47453.5453); }
float rand(float2 co) { return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453); }
float rand(float3 co) { return rand(co.xy + rand(co.z)); }

float3 HueShift (in float3 Color, in float Shift)
{
    float3 P = float3(0.55735, 0.55735, 0.55735)*dot(float3(0.55735, 0.55735, 0.55735),Color);
    float3 U = Color-P;
    float3 V = cross(float3(0.55735, 0.55735, 0.55735),U);
    Color = U*cos(Shift*6.2832) + V*sin(Shift*6.2832) + P;
    return Color;
}

float3 SF(uint i, uint count) 
{
    const float golden_ratio = 1.61803398875; // (1 + sqrt(5)) / 2.0
    const float pi = 3.14159265359;
    
    float u_x = (i + 0.5) / count;
    float u_y = frac(i * golden_ratio);
    
    float phi = acos(1.0 - 2.0 * u_x);
    float theta = 2.0 * pi * u_y;
    float x = sin(phi) * cos(theta);
    float y = sin(phi) * sin(theta);
    float z = cos(phi);
    
    return float3(x, y, z);
}