// KWEAVE_NOISE_VERSION 2

// ====== Noise Math (Shared Utilities) ======

static const float KWEAVE_PI = 3.14159265358979;

// ===== Hash Functions =====

// xxHash-inspired 32-bit hash
uint KweaveHash32(int x, int y, int z)
{
    uint h = (uint)x * 374761393u;
    h += (uint)y * 668265263u;
    h += (uint)z * 1274126177u;
    h ^= h >> 13;
    h *= 1274126177u;
    h ^= h >> 16;
    return h;
}

// Hash to [0,1)
// Bit-level mantissa trick: stuff the top 23 bits of h directly into the
// mantissa of a float in [1.0, 2.0), then subtract 1.0. Uniform across the
// full uint range -- avoids the precision collapse of float(h)/UINT_MAX,
// where high uints quantize to 256-step floats.
float KweaveHash32ToFloat01(uint h)
{
    return asfloat(0x3F800000u | (h >> 9)) - 1.0;
}

// Convenience: position to [0,1]
float KweaveHash01(int x, int y, int z)
{
    return KweaveHash32ToFloat01(KweaveHash32(x, y, z));
}

// Hash to [-1,1]
float KweaveHash11(int x, int y, int z)
{
    return KweaveHash01(x, y, z) * 2.0 - 1.0;
}

// Permutation-style hash (replaces table lookup)
int KweavePermHash(int x)
{
    // Bit mixing for permutation-like behavior
    uint h = (uint)x;
    h ^= h >> 16;
    h *= 0x45d9f3bu;
    h ^= h >> 16;
    return (int)(h & 255u);
}

int KweaveHash3D(int x, int y, int z)
{
    return KweavePermHash(KweavePermHash(KweavePermHash(x) + y) + z);
}

int KweaveHash3DSeed(int x, int y, int z, int seed)
{
    return KweaveHash3D(x + seed, y, z);
}

// ===== Gradient Functions =====

// 3D gradient from hash (16 directions on cube edges)
float3 KweaveGrad3(int hash)
{
    int h = hash & 15;
    // Encode the 16 gradient directions using bit manipulation
    float u = (h < 8) ? ((h & 1) ? -1.0 : 1.0) : 0.0;
    float v = (h < 4) ? 0.0 : ((h == 12 || h == 14) ? ((h & 1) ? -1.0 : 1.0) : (((h >> 1) & 1) ? -1.0 : 1.0));
    float w = (h < 8) ? (((h >> 1) & 1) ? -1.0 : 1.0) : 0.0;

    // Remap to standard gradient table
    // Simpler approach: use the standard 16-gradient table encoded as conditions
    switch(h)
    {
        case 0:  return float3( 1, 1, 0);
        case 1:  return float3(-1, 1, 0);
        case 2:  return float3( 1,-1, 0);
        case 3:  return float3(-1,-1, 0);
        case 4:  return float3( 1, 0, 1);
        case 5:  return float3(-1, 0, 1);
        case 6:  return float3( 1, 0,-1);
        case 7:  return float3(-1, 0,-1);
        case 8:  return float3( 0, 1, 1);
        case 9:  return float3( 0,-1, 1);
        case 10: return float3( 0, 1,-1);
        case 11: return float3( 0,-1,-1);
        case 12: return float3( 1, 1, 0);
        case 13: return float3(-1, 1, 0);
        case 14: return float3( 0,-1, 1);
        case 15: return float3( 0,-1,-1);
        default: return float3( 1, 1, 0);
    }
}

// Gradient dot product
float KweaveGradDot3(int hash, float x, float y, float z)
{
    float3 g = KweaveGrad3(hash);
    return g.x * x + g.y * y + g.z * z;
}

// ===== Interpolation =====

// Quintic smoothstep (C2 continuous): 6t^5 - 15t^4 + 10t^3
float KweaveQuintic(float t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Quintic smoothstep derivative: 30t^4 - 60t^3 + 30t^2
float KweaveQuinticDeriv(float t)
{
    return 30.0 * t * t * (t * (t - 2.0) + 1.0);
}

// ===== Distance Functions =====

float KweaveDistEuclidean(float3 a, float3 b)
{
    return length(a - b);
}

float KweaveDistEuclideanSq(float3 a, float3 b)
{
    float3 d = a - b;
    return dot(d, d);
}

float KweaveDistManhattan(float3 a, float3 b)
{
    float3 d = abs(a - b);
    return d.x + d.y + d.z;
}

float KweaveDistChebyshev(float3 a, float3 b)
{
    float3 d = abs(a - b);
    return max(d.x, max(d.y, d.z));
}

// ===== Utility =====

// Fractal bounding: 1 / sum(persistence^i) for i in [0, octaves)
float KweaveFractalBounding(int octaves, float persistence)
{
    float amp = 1.0;
    float sum = 0.0;
    for (int i = 0; i < octaves; i++)
    {
        sum += amp;
        amp *= persistence;
    }
    return 1.0 / sum;
}

// Positive modulo (for tiling)
int KweaveMod(int x, int period)
{
    int r = x % period;
    return r < 0 ? r + period : r;
}

// ====== Perlin Noise ======

// Internal: single-octave Perlin noise (used by other noises)
float KweavePerlinRaw(float3 pos, int seed)
{
    int x0 = (int)floor(pos.x);
    int y0 = (int)floor(pos.y);
    int z0 = (int)floor(pos.z);

    float xf = pos.x - x0;
    float yf = pos.y - y0;
    float zf = pos.z - z0;

    float u = KweaveQuintic(xf);
    float v = KweaveQuintic(yf);
    float w = KweaveQuintic(zf);

    int x0s = x0 + seed;

    int aaa = KweaveHash3D(x0s,   y0,   z0);
    int aba = KweaveHash3D(x0s,   y0+1, z0);
    int aab = KweaveHash3D(x0s,   y0,   z0+1);
    int abb = KweaveHash3D(x0s,   y0+1, z0+1);
    int baa = KweaveHash3D(x0s+1, y0,   z0);
    int bba = KweaveHash3D(x0s+1, y0+1, z0);
    int bab = KweaveHash3D(x0s+1, y0,   z0+1);
    int bbb = KweaveHash3D(x0s+1, y0+1, z0+1);

    float g_aaa = KweaveGradDot3(aaa, xf,     yf,     zf);
    float g_baa = KweaveGradDot3(baa, xf-1.0, yf,     zf);
    float g_aba = KweaveGradDot3(aba, xf,     yf-1.0, zf);
    float g_bba = KweaveGradDot3(bba, xf-1.0, yf-1.0, zf);
    float g_aab = KweaveGradDot3(aab, xf,     yf,     zf-1.0);
    float g_bab = KweaveGradDot3(bab, xf-1.0, yf,     zf-1.0);
    float g_abb = KweaveGradDot3(abb, xf,     yf-1.0, zf-1.0);
    float g_bbb = KweaveGradDot3(bbb, xf-1.0, yf-1.0, zf-1.0);

    float x00 = lerp(g_aaa, g_baa, u);
    float x10 = lerp(g_aba, g_bba, u);
    float x01 = lerp(g_aab, g_bab, u);
    float x11 = lerp(g_abb, g_bbb, u);

    float xy0 = lerp(x00, x10, v);
    float xy1 = lerp(x01, x11, v);

    return lerp(xy0, xy1, w);
}

// 3D Perlin noise [0,1]
float KweaveNoisePerlin(float3 Position, float Frequency, int Seed)
{
    return KweavePerlinRaw(Position * Frequency, Seed) * 0.5 + 0.5;
}

float2 KweaveNoisePerlin2(float3 Position, float Frequency, int Seed)
{
    return float2(
        KweaveNoisePerlin(Position, Frequency, Seed),
        KweaveNoisePerlin(Position, Frequency, Seed + 1000)
    );
}

float3 KweaveNoisePerlin3(float3 Position, float Frequency, int Seed)
{
    return float3(
        KweaveNoisePerlin(Position, Frequency, Seed),
        KweaveNoisePerlin(Position, Frequency, Seed + 1000),
        KweaveNoisePerlin(Position, Frequency, Seed + 2000)
    );
}

// ====== Simplex Noise ======

float KweaveSimplexContrib(int hash, float x, float y, float z)
{
    float attn = 0.6 - x*x - y*y - z*z;
    if (attn <= 0.0) return 0.0;
    attn *= attn;
    return attn * attn * KweaveGradDot3(hash, x, y, z);
}

float KweaveNoiseSimplexRaw(float3 pos, int seed)
{
    // constants
    float F3 = 0.33333333;
    float G3 = 0.16666667;

    float s = (pos.x + pos.y + pos.z) * F3;
    int i = (int)floor(pos.x + s);
    int j = (int)floor(pos.y + s);
    int k = (int)floor(pos.z + s);

    float t = (i + j + k) * G3;
    float x0 = pos.x - (i - t);
    float y0 = pos.y - (j - t);
    float z0 = pos.z - (k - t);

    int i1, j1, k1, i2, j2, k2;
    if (x0 >= y0) {
        if (y0 >= z0) { i1=1;j1=0;k1=0; i2=1;j2=1;k2=0; }
        else if (x0 >= z0) { i1=1;j1=0;k1=0; i2=1;j2=0;k2=1; }
        else { i1=0;j1=0;k1=1; i2=1;j2=0;k2=1; }
    } else {
        if (y0 < z0) { i1=0;j1=0;k1=1; i2=0;j2=1;k2=1; }
        else if (x0 < z0) { i1=0;j1=1;k1=0; i2=0;j2=1;k2=1; }
        else { i1=0;j1=1;k1=0; i2=1;j2=1;k2=0; }
    }

    float x1 = x0 - i1 + G3;
    float y1 = y0 - j1 + G3;
    float z1 = z0 - k1 + G3;
    float x2 = x0 - i2 + 2.0*G3;
    float y2 = y0 - j2 + 2.0*G3;
    float z2 = z0 - k2 + 2.0*G3;
    float x3 = x0 - 1.0 + 3.0*G3;
    float y3 = y0 - 1.0 + 3.0*G3;
    float z3 = z0 - 1.0 + 3.0*G3;

    int ii = i + seed;
    int jj = j;
    int kk = k;

    int gi0 = KweaveHash3D(ii, jj, kk);
    int gi1 = KweaveHash3D(ii+i1, jj+j1, kk+k1);
    int gi2 = KweaveHash3D(ii+i2, jj+j2, kk+k2);
    int gi3 = KweaveHash3D(ii+1, jj+1, kk+1);

    float n0 = KweaveSimplexContrib(gi0, x0, y0, z0);
    float n1 = KweaveSimplexContrib(gi1, x1, y1, z1);
    float n2 = KweaveSimplexContrib(gi2, x2, y2, z2);
    float n3 = KweaveSimplexContrib(gi3, x3, y3, z3);

    return 32.0 * (n0 + n1 + n2 + n3);
}

float KweaveNoiseSimplex(float3 Position, float Frequency, int Seed)
{
    return KweaveNoiseSimplexRaw(Position * Frequency, Seed) * 0.5 + 0.5;
}

float2 KweaveNoiseSimplex2(float3 Position, float Frequency, int Seed)
{
    return float2(
        KweaveNoiseSimplex(Position, Frequency, Seed),
        KweaveNoiseSimplex(Position, Frequency, Seed + 1000)
    );
}

float3 KweaveNoiseSimplex3(float3 Position, float Frequency, int Seed)
{
    return float3(
        KweaveNoiseSimplex(Position, Frequency, Seed),
        KweaveNoiseSimplex(Position, Frequency, Seed + 1000),
        KweaveNoiseSimplex(Position, Frequency, Seed + 2000)
    );
}

// ====== Value Noise ======

float KweaveNoiseValueCore(float3 Position, float Frequency, int Seed)
{
    float3 pos = Position * Frequency;
    int x0 = (int)floor(pos.x);
    int y0 = (int)floor(pos.y);
    int z0 = (int)floor(pos.z);

    float xf = pos.x - x0;
    float yf = pos.y - y0;
    float zf = pos.z - z0;

    float u = KweaveQuintic(xf);
    float v = KweaveQuintic(yf);
    float w = KweaveQuintic(zf);

    int x0s = x0 + Seed;

    float v000 = KweaveHash01(x0s,   y0,   z0);
    float v100 = KweaveHash01(x0s+1, y0,   z0);
    float v010 = KweaveHash01(x0s,   y0+1, z0);
    float v110 = KweaveHash01(x0s+1, y0+1, z0);
    float v001 = KweaveHash01(x0s,   y0,   z0+1);
    float v101 = KweaveHash01(x0s+1, y0,   z0+1);
    float v011 = KweaveHash01(x0s,   y0+1, z0+1);
    float v111 = KweaveHash01(x0s+1, y0+1, z0+1);

    float x00 = lerp(v000, v100, u);
    float x10 = lerp(v010, v110, u);
    float x01 = lerp(v001, v101, u);
    float x11 = lerp(v011, v111, u);

    float xy0 = lerp(x00, x10, v);
    float xy1 = lerp(x01, x11, v);

    return lerp(xy0, xy1, w);
}

float KweaveNoiseValue(float3 Position, float Frequency, int Seed)
{
    return KweaveNoiseValueCore(Position, Frequency, Seed);
}

float2 KweaveNoiseValue2(float3 Position, float Frequency, int Seed)
{
    return float2(
        KweaveNoiseValue(Position, Frequency, Seed),
        KweaveNoiseValue(Position, Frequency, Seed + 1000)
    );
}

float3 KweaveNoiseValue3(float3 Position, float Frequency, int Seed)
{
    return float3(
        KweaveNoiseValue(Position, Frequency, Seed),
        KweaveNoiseValue(Position, Frequency, Seed + 1000),
        KweaveNoiseValue(Position, Frequency, Seed + 2000)
    );
}

// ====== OpenSimplex2 Noise ======

static const float KWEAVE_OS2_SQUISH = 0.33333333;
static const float KWEAVE_OS2_STRETCH = -0.16666667;
static const float KWEAVE_OS2_NORM = 103.0;

float KweaveOS2Contrib(int xsv, int ysv, int zsv, float dx, float dy, float dz, int seed)
{
    float attn = 0.66666667 - dx*dx - dy*dy - dz*dz;
    if (attn <= 0.0) return 0.0;
    int gi = KweaveHash3DSeed(xsv, ysv, zsv, seed);
    attn *= attn;
    return attn * attn * KweaveGradDot3(gi, dx, dy, dz);
}

float KweaveNoiseOpenSimplex2Core(float3 Position, float Frequency, int Seed)
{
    float3 pos = Position * Frequency;
    float s = (pos.x + pos.y + pos.z) * KWEAVE_OS2_SQUISH;
    float xs = pos.x + s;
    float ys = pos.y + s;
    float zs = pos.z + s;

    int xsb = (int)floor(xs);
    int ysb = (int)floor(ys);
    int zsb = (int)floor(zs);

    float xsi = xs - xsb;
    float ysi = ys - ysb;
    float zsi = zs - zsb;

    float sq = (xsi + ysi + zsi) * KWEAVE_OS2_STRETCH;
    float dx0 = xsi + sq;
    float dy0 = ysi + sq;
    float dz0 = zsi + sq;

    float value = 0.0;

    value += KweaveOS2Contrib(xsb, ysb, zsb, dx0, dy0, dz0, Seed);
    value += KweaveOS2Contrib(xsb+1, ysb, zsb, dx0-1.0-KWEAVE_OS2_STRETCH, dy0-KWEAVE_OS2_STRETCH, dz0-KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb, ysb+1, zsb, dx0-KWEAVE_OS2_STRETCH, dy0-1.0-KWEAVE_OS2_STRETCH, dz0-KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb, ysb, zsb+1, dx0-KWEAVE_OS2_STRETCH, dy0-KWEAVE_OS2_STRETCH, dz0-1.0-KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb+1, ysb+1, zsb, dx0-1.0-2.0*KWEAVE_OS2_STRETCH, dy0-1.0-2.0*KWEAVE_OS2_STRETCH, dz0-2.0*KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb+1, ysb, zsb+1, dx0-1.0-2.0*KWEAVE_OS2_STRETCH, dy0-2.0*KWEAVE_OS2_STRETCH, dz0-1.0-2.0*KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb, ysb+1, zsb+1, dx0-2.0*KWEAVE_OS2_STRETCH, dy0-1.0-2.0*KWEAVE_OS2_STRETCH, dz0-1.0-2.0*KWEAVE_OS2_STRETCH, Seed);
    value += KweaveOS2Contrib(xsb+1, ysb+1, zsb+1, dx0-1.0-3.0*KWEAVE_OS2_STRETCH, dy0-1.0-3.0*KWEAVE_OS2_STRETCH, dz0-1.0-3.0*KWEAVE_OS2_STRETCH, Seed);

    return value / KWEAVE_OS2_NORM * 0.5 + 0.5;
}

float KweaveNoiseOpenSimplex2(float3 Position, float Frequency, int Seed)
{
    return KweaveNoiseOpenSimplex2Core(Position, Frequency, Seed);
}

float2 KweaveNoiseOpenSimplex22(float3 Position, float Frequency, int Seed)
{
    return float2(
        KweaveNoiseOpenSimplex2(Position, Frequency, Seed),
        KweaveNoiseOpenSimplex2(Position, Frequency, Seed + 1000)
    );
}

float3 KweaveNoiseOpenSimplex23(float3 Position, float Frequency, int Seed)
{
    return float3(
        KweaveNoiseOpenSimplex2(Position, Frequency, Seed),
        KweaveNoiseOpenSimplex2(Position, Frequency, Seed + 1000),
        KweaveNoiseOpenSimplex2(Position, Frequency, Seed + 2000)
    );
}

// ====== White Noise ======

float KweaveNoiseWhiteCore(float3 Position, float Frequency, int Seed)
{
    float3 pos = Position * Frequency;
    int x = (int)floor(pos.x);
    int y = (int)floor(pos.y);
    int z = (int)floor(pos.z);
    return KweaveHash32ToFloat01(KweaveHash32(x + Seed, y, z));
}

float KweaveNoiseWhite(float3 Position, float Frequency, int Seed)
{
    return KweaveNoiseWhiteCore(Position, Frequency, Seed);
}

float2 KweaveNoiseWhite2(float3 Position, float Frequency, int Seed)
{
    return float2(
        KweaveNoiseWhite(Position, Frequency, Seed),
        KweaveNoiseWhite(Position, Frequency, Seed + 1000)
    );
}

float3 KweaveNoiseWhite3(float3 Position, float Frequency, int Seed)
{
    return float3(
        KweaveNoiseWhite(Position, Frequency, Seed),
        KweaveNoiseWhite(Position, Frequency, Seed + 1000),
        KweaveNoiseWhite(Position, Frequency, Seed + 2000)
    );
}

// ====== Worley Noise ======

float KweaveNoiseWorleyCore(float3 Position, float Frequency, int Seed, float Jitter)
{
    float3 pos = Position * Frequency;
    int xi = (int)floor(pos.x);
    int yi = (int)floor(pos.y);
    int zi = (int)floor(pos.z);

    float minDist = 1e10;

    for (int dz = -1; dz <= 1; dz++)
    for (int dy = -1; dy <= 1; dy++)
    for (int dx = -1; dx <= 1; dx++)
    {
        int cx = xi + dx;
        int cy = yi + dy;
        int cz = zi + dz;

        // Random point within cell
        float px = (float)cx + KweaveHash01(cx + Seed, cy, cz) * Jitter + (1.0 - Jitter) * 0.5;
        float py = (float)cy + KweaveHash01(cx, cy + Seed, cz) * Jitter + (1.0 - Jitter) * 0.5;
        float pz = (float)cz + KweaveHash01(cx, cy, cz + Seed) * Jitter + (1.0 - Jitter) * 0.5;

        float3 diff = pos - float3(px, py, pz);
        float dist = dot(diff, diff);
        minDist = min(minDist, dist);
    }

    return saturate(sqrt(minDist));
}

float KweaveNoiseWorley(float3 Position, float Frequency, int Seed, float Jitter)
{
    return KweaveNoiseWorleyCore(Position, Frequency, Seed, Jitter);
}

float2 KweaveNoiseWorley2(float3 Position, float Frequency, int Seed, float Jitter)
{
    return float2(
        KweaveNoiseWorley(Position, Frequency, Seed, Jitter),
        KweaveNoiseWorley(Position, Frequency, Seed + 1000, Jitter)
    );
}

float3 KweaveNoiseWorley3(float3 Position, float Frequency, int Seed, float Jitter)
{
    return float3(
        KweaveNoiseWorley(Position, Frequency, Seed, Jitter),
        KweaveNoiseWorley(Position, Frequency, Seed + 1000, Jitter),
        KweaveNoiseWorley(Position, Frequency, Seed + 2000, Jitter)
    );
}

// ====== Voronoi Noise ======

// Smooth minimum for cell blending
float KweaveSmoothMin(float a, float b, float k)
{
    if (k <= 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float KweaveNoiseVoronoiCore(float3 Position, float Frequency, int Seed, float Jitter, float Smoothness)
{
    float3 pos = Position * Frequency;
    int xi = (int)floor(pos.x);
    int yi = (int)floor(pos.y);
    int zi = (int)floor(pos.z);

    float minDist = 1e10;
    float cellValue = 0.0;

    for (int dz = -1; dz <= 1; dz++)
    for (int dy = -1; dy <= 1; dy++)
    for (int dx = -1; dx <= 1; dx++)
    {
        int cx = xi + dx;
        int cy = yi + dy;
        int cz = zi + dz;

        float px = (float)cx + KweaveHash01(cx + Seed, cy, cz) * Jitter + (1.0 - Jitter) * 0.5;
        float py = (float)cy + KweaveHash01(cx, cy + Seed, cz) * Jitter + (1.0 - Jitter) * 0.5;
        float pz = (float)cz + KweaveHash01(cx, cy, cz + Seed) * Jitter + (1.0 - Jitter) * 0.5;

        float3 diff = pos - float3(px, py, pz);
        float dist = dot(diff, diff);

        if (Smoothness > 0.0)
        {
            float newMin = KweaveSmoothMin(minDist, dist, Smoothness);
            if (newMin < minDist)
            {
                cellValue = KweaveHash01(cx, cy, cz);
                minDist = newMin;
            }
        }
        else if (dist < minDist)
        {
            minDist = dist;
            cellValue = KweaveHash01(cx, cy, cz);
        }
    }

    return cellValue;
}

float KweaveNoiseVoronoi(float3 Position, float Frequency, int Seed, float Jitter, float Smoothness)
{
    return KweaveNoiseVoronoiCore(Position, Frequency, Seed, Jitter, Smoothness);
}

float2 KweaveNoiseVoronoi2(float3 Position, float Frequency, int Seed, float Jitter, float Smoothness)
{
    return float2(
        KweaveNoiseVoronoi(Position, Frequency, Seed, Jitter, Smoothness),
        KweaveNoiseVoronoi(Position, Frequency, Seed + 1000, Jitter, Smoothness)
    );
}

float3 KweaveNoiseVoronoi3(float3 Position, float Frequency, int Seed, float Jitter, float Smoothness)
{
    return float3(
        KweaveNoiseVoronoi(Position, Frequency, Seed, Jitter, Smoothness),
        KweaveNoiseVoronoi(Position, Frequency, Seed + 1000, Jitter, Smoothness),
        KweaveNoiseVoronoi(Position, Frequency, Seed + 2000, Jitter, Smoothness)
    );
}

// ====== Spots Noise ======

float KweaveNoiseSpotsCore(float3 Position, float Frequency, int Seed, float SpotRadius, float Jitter)
{
    float3 pos = Position * Frequency;
    int xi = (int)floor(pos.x);
    int yi = (int)floor(pos.y);
    int zi = (int)floor(pos.z);

    float result = 0.0;

    for (int dz = -1; dz <= 1; dz++)
    for (int dy = -1; dy <= 1; dy++)
    for (int dx = -1; dx <= 1; dx++)
    {
        int cx = xi + dx;
        int cy = yi + dy;
        int cz = zi + dz;

        // Spot center with jitter
        float px = (float)cx + 0.5 + (KweaveHash01(cx + Seed, cy, cz) - 0.5) * Jitter * 2.0;
        float py = (float)cy + 0.5 + (KweaveHash01(cx, cy + Seed, cz) - 0.5) * Jitter * 2.0;
        float pz = (float)cz + 0.5 + (KweaveHash01(cx, cy, cz + Seed) - 0.5) * Jitter * 2.0;

        float3 diff = pos - float3(px, py, pz);
        float dist = length(diff);

        // Per-spot radius variation (+-10%)
        float r = SpotRadius * (0.9 + 0.2 * KweaveHash01(cx + 7, cy + 13, cz + Seed));

        // Soft circular falloff
        float spotVal = saturate(1.0 - dist / max(r, 0.001));
        result = max(result, spotVal);
    }

    return result;
}

float KweaveNoiseSpots(float3 Position, float Frequency, int Seed, float SpotRadius, float Jitter)
{
    return KweaveNoiseSpotsCore(Position, Frequency, Seed, SpotRadius, Jitter);
}

float2 KweaveNoiseSpots2(float3 Position, float Frequency, int Seed, float SpotRadius, float Jitter)
{
    return float2(
        KweaveNoiseSpots(Position, Frequency, Seed, SpotRadius, Jitter),
        KweaveNoiseSpots(Position, Frequency, Seed + 1000, SpotRadius, Jitter)
    );
}

float3 KweaveNoiseSpots3(float3 Position, float Frequency, int Seed, float SpotRadius, float Jitter)
{
    return float3(
        KweaveNoiseSpots(Position, Frequency, Seed, SpotRadius, Jitter),
        KweaveNoiseSpots(Position, Frequency, Seed + 1000, SpotRadius, Jitter),
        KweaveNoiseSpots(Position, Frequency, Seed + 2000, SpotRadius, Jitter)
    );
}

// ====== FBM Noise ======

float KweaveNoiseFBMCore(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence)
{
    float3 pos = Position * Frequency;
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float bound = KweaveFractalBounding(Octaves, Persistence);

    for (int i = 0; i < Octaves; i++)
    {
        sum += KweavePerlinRaw(pos * freq, Seed + i) * amp;
        amp *= Persistence;
        freq *= Lacunarity;
    }

    return sum * bound * 0.5 + 0.5;
}

float KweaveNoiseFBM(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence)
{
    return KweaveNoiseFBMCore(Position, Frequency, Seed, Octaves, Lacunarity, Persistence);
}

float2 KweaveNoiseFBM2(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence)
{
    return float2(
        KweaveNoiseFBM(Position, Frequency, Seed, Octaves, Lacunarity, Persistence),
        KweaveNoiseFBM(Position, Frequency, Seed + 1000, Octaves, Lacunarity, Persistence)
    );
}

float3 KweaveNoiseFBM3(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence)
{
    return float3(
        KweaveNoiseFBM(Position, Frequency, Seed, Octaves, Lacunarity, Persistence),
        KweaveNoiseFBM(Position, Frequency, Seed + 1000, Octaves, Lacunarity, Persistence),
        KweaveNoiseFBM(Position, Frequency, Seed + 2000, Octaves, Lacunarity, Persistence)
    );
}

// ====== Swiss Noise ======

// Perlin noise with analytical derivatives
float KweavePerlinWithDerivatives(float3 pos, int seed, out float3 deriv)
{
    int x0 = (int)floor(pos.x);
    int y0 = (int)floor(pos.y);
    int z0 = (int)floor(pos.z);

    float xf = pos.x - x0;
    float yf = pos.y - y0;
    float zf = pos.z - z0;

    float u = KweaveQuintic(xf);
    float v = KweaveQuintic(yf);
    float w = KweaveQuintic(zf);
    float du = KweaveQuinticDeriv(xf);
    float dv = KweaveQuinticDeriv(yf);
    float dw = KweaveQuinticDeriv(zf);

    int x0s = x0 + seed;

    float g_aaa = KweaveGradDot3(KweaveHash3D(x0s,   y0,   z0),   xf,     yf,     zf);
    float g_baa = KweaveGradDot3(KweaveHash3D(x0s+1, y0,   z0),   xf-1.0, yf,     zf);
    float g_aba = KweaveGradDot3(KweaveHash3D(x0s,   y0+1, z0),   xf,     yf-1.0, zf);
    float g_bba = KweaveGradDot3(KweaveHash3D(x0s+1, y0+1, z0),   xf-1.0, yf-1.0, zf);
    float g_aab = KweaveGradDot3(KweaveHash3D(x0s,   y0,   z0+1), xf,     yf,     zf-1.0);
    float g_bab = KweaveGradDot3(KweaveHash3D(x0s+1, y0,   z0+1), xf-1.0, yf,     zf-1.0);
    float g_abb = KweaveGradDot3(KweaveHash3D(x0s,   y0+1, z0+1), xf,     yf-1.0, zf-1.0);
    float g_bbb = KweaveGradDot3(KweaveHash3D(x0s+1, y0+1, z0+1), xf-1.0, yf-1.0, zf-1.0);

    float x00 = lerp(g_aaa, g_baa, u);
    float x10 = lerp(g_aba, g_bba, u);
    float x01 = lerp(g_aab, g_bab, u);
    float x11 = lerp(g_abb, g_bbb, u);

    float xy0 = lerp(x00, x10, v);
    float xy1 = lerp(x01, x11, v);

    float value = lerp(xy0, xy1, w);

    // Analytical derivatives
    float dx00 = g_baa - g_aaa;
    float dx10 = g_bba - g_aba;
    float dx01 = g_bab - g_aab;
    float dx11 = g_bbb - g_abb;

    deriv.x = du * lerp(lerp(dx00, dx10, v), lerp(dx01, dx11, v), w);
    deriv.y = dv * lerp(lerp(g_aba - g_aaa, g_bba - g_baa, u), lerp(g_abb - g_aab, g_bbb - g_bab, u), w);
    deriv.z = dw * (xy1 - xy0);

    return value;
}

float KweaveNoiseSwissCore(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence, float ErosionStrength, float WarpFactor)
{
    float3 pos = Position * Frequency;
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float3 derivSum = float3(0, 0, 0);
    float bound = KweaveFractalBounding(Octaves, Persistence);

    for (int i = 0; i < Octaves; i++)
    {
        float3 warpedPos = pos * freq + derivSum * WarpFactor;
        float3 deriv;
        float n = KweavePerlinWithDerivatives(warpedPos, Seed + i, deriv);

        // Erosion: reduce amplitude in steep areas
        float erosion = 1.0 / (1.0 + dot(derivSum, derivSum) * ErosionStrength);
        sum += n * amp * erosion;
        derivSum += deriv * amp;

        amp *= Persistence;
        freq *= Lacunarity;
    }

    return sum * bound * 0.5 + 0.5;
}

float KweaveNoiseSwiss(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence, float ErosionStrength, float WarpFactor)
{
    return KweaveNoiseSwissCore(Position, Frequency, Seed, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor);
}

float2 KweaveNoiseSwiss2(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence, float ErosionStrength, float WarpFactor)
{
    return float2(
        KweaveNoiseSwiss(Position, Frequency, Seed, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor),
        KweaveNoiseSwiss(Position, Frequency, Seed + 1000, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor)
    );
}

float3 KweaveNoiseSwiss3(float3 Position, float Frequency, int Seed, int Octaves, float Lacunarity, float Persistence, float ErosionStrength, float WarpFactor)
{
    return float3(
        KweaveNoiseSwiss(Position, Frequency, Seed, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor),
        KweaveNoiseSwiss(Position, Frequency, Seed + 1000, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor),
        KweaveNoiseSwiss(Position, Frequency, Seed + 2000, Octaves, Lacunarity, Persistence, ErosionStrength, WarpFactor)
    );
}

// ====== Tiling Noise ======

int KweaveHashPeriodic(int x, int y, int z, int px, int py, int pz, int seed)
{
    return KweaveHash3D(KweaveMod(x + seed, px), KweaveMod(y, py), KweaveMod(z, pz));
}

float KweaveNoiseTilingCore(float3 Position, float Frequency, int Seed, int PeriodX, int PeriodY, int PeriodZ)
{
    float3 pos = Position * Frequency;
    int x0 = (int)floor(pos.x);
    int y0 = (int)floor(pos.y);
    int z0 = (int)floor(pos.z);

    float xf = pos.x - x0;
    float yf = pos.y - y0;
    float zf = pos.z - z0;

    float u = KweaveQuintic(xf);
    float v = KweaveQuintic(yf);
    float w = KweaveQuintic(zf);

    // Periodic hashing
    int aaa = KweaveHashPeriodic(x0,   y0,   z0,   PeriodX, PeriodY, PeriodZ, Seed);
    int aba = KweaveHashPeriodic(x0,   y0+1, z0,   PeriodX, PeriodY, PeriodZ, Seed);
    int aab = KweaveHashPeriodic(x0,   y0,   z0+1, PeriodX, PeriodY, PeriodZ, Seed);
    int abb = KweaveHashPeriodic(x0,   y0+1, z0+1, PeriodX, PeriodY, PeriodZ, Seed);
    int baa = KweaveHashPeriodic(x0+1, y0,   z0,   PeriodX, PeriodY, PeriodZ, Seed);
    int bba = KweaveHashPeriodic(x0+1, y0+1, z0,   PeriodX, PeriodY, PeriodZ, Seed);
    int bab = KweaveHashPeriodic(x0+1, y0,   z0+1, PeriodX, PeriodY, PeriodZ, Seed);
    int bbb = KweaveHashPeriodic(x0+1, y0+1, z0+1, PeriodX, PeriodY, PeriodZ, Seed);

    float g_aaa = KweaveGradDot3(aaa, xf,     yf,     zf);
    float g_baa = KweaveGradDot3(baa, xf-1.0, yf,     zf);
    float g_aba = KweaveGradDot3(aba, xf,     yf-1.0, zf);
    float g_bba = KweaveGradDot3(bba, xf-1.0, yf-1.0, zf);
    float g_aab = KweaveGradDot3(aab, xf,     yf,     zf-1.0);
    float g_bab = KweaveGradDot3(bab, xf-1.0, yf,     zf-1.0);
    float g_abb = KweaveGradDot3(abb, xf,     yf-1.0, zf-1.0);
    float g_bbb = KweaveGradDot3(bbb, xf-1.0, yf-1.0, zf-1.0);

    float x00 = lerp(g_aaa, g_baa, u);
    float x10 = lerp(g_aba, g_bba, u);
    float x01 = lerp(g_aab, g_bab, u);
    float x11 = lerp(g_abb, g_bbb, u);

    float xy0 = lerp(x00, x10, v);
    float xy1 = lerp(x01, x11, v);

    return lerp(xy0, xy1, w) * 0.5 + 0.5;
}

float KweaveNoiseTiling(float3 Position, float Frequency, int Seed, int PeriodX, int PeriodY, int PeriodZ)
{
    return KweaveNoiseTilingCore(Position, Frequency, Seed, PeriodX, PeriodY, PeriodZ);
}

float2 KweaveNoiseTiling2(float3 Position, float Frequency, int Seed, int PeriodX, int PeriodY, int PeriodZ)
{
    return float2(
        KweaveNoiseTiling(Position, Frequency, Seed, PeriodX, PeriodY, PeriodZ),
        KweaveNoiseTiling(Position, Frequency, Seed + 1000, PeriodX, PeriodY, PeriodZ)
    );
}

float3 KweaveNoiseTiling3(float3 Position, float Frequency, int Seed, int PeriodX, int PeriodY, int PeriodZ)
{
    return float3(
        KweaveNoiseTiling(Position, Frequency, Seed, PeriodX, PeriodY, PeriodZ),
        KweaveNoiseTiling(Position, Frequency, Seed + 1000, PeriodX, PeriodY, PeriodZ),
        KweaveNoiseTiling(Position, Frequency, Seed + 2000, PeriodX, PeriodY, PeriodZ)
    );
}

// ====== Curl Noise ======

// Potential field: 3 independent noise channels
float3 KweaveCurlPotential(float3 pos, int seed)
{
    float fx = KweavePerlinRaw(pos, seed);
    float fy = KweavePerlinRaw(pos + float3(31.416, 47.853, 12.793), seed);
    float fz = KweavePerlinRaw(pos + float3(93.139, 25.186, 71.524), seed);
    return float3(fx, fy, fz);
}

float3 KweaveNoiseCurlCore(float3 Position, float Frequency, int Seed, float Epsilon)
{
    float3 pos = Position * Frequency;
    float e = Epsilon;
    float inv2e = 1.0 / (2.0 * e);

    // Sample potential field at 6 offset positions
    float3 pxp = KweaveCurlPotential(pos + float3(e, 0, 0), Seed);
    float3 pxn = KweaveCurlPotential(pos - float3(e, 0, 0), Seed);
    float3 pyp = KweaveCurlPotential(pos + float3(0, e, 0), Seed);
    float3 pyn = KweaveCurlPotential(pos - float3(0, e, 0), Seed);
    float3 pzp = KweaveCurlPotential(pos + float3(0, 0, e), Seed);
    float3 pzn = KweaveCurlPotential(pos - float3(0, 0, e), Seed);

    // Curl = nabla x F
    float3 curl;
    curl.x = (pyp.z - pyn.z - pzp.y + pzn.y) * inv2e;
    curl.y = (pzp.x - pzn.x - pxp.z + pxn.z) * inv2e;
    curl.z = (pxp.y - pxn.y - pyp.x + pyn.x) * inv2e;

    return curl;
}

float3 KweaveNoiseCurl(float3 Position, float Frequency, int Seed, float Epsilon)
{
    return KweaveNoiseCurlCore(Position, Frequency, Seed, Epsilon);
}

// ====== Flow Noise ======

float3 KweaveRotatedGrad(int hash, float time, float rotSpeed)
{
    float3 baseGrad = KweaveGrad3(hash);
    float rate = KweaveHash32ToFloat01((uint)hash * 2654435761u) * rotSpeed;
    float angle = time * rate * 2.0 * KWEAVE_PI;
    float ca = cos(angle);
    float sa = sin(angle);
    return float3(
        baseGrad.x * ca - baseGrad.y * sa,
        baseGrad.x * sa + baseGrad.y * ca,
        baseGrad.z
    );
}

float KweaveNoiseFlowCore(float3 Position, float Frequency, int Seed, float Time, float RotationSpeed)
{
    float3 pos = Position * Frequency;
    int x0 = (int)floor(pos.x);
    int y0 = (int)floor(pos.y);
    int z0 = (int)floor(pos.z);

    float xf = pos.x - x0;
    float yf = pos.y - y0;
    float zf = pos.z - z0;

    float u = KweaveQuintic(xf);
    float v = KweaveQuintic(yf);
    float w = KweaveQuintic(zf);

    int x0s = x0 + Seed;

    int h_aaa = KweaveHash3D(x0s,   y0,   z0);
    int h_baa = KweaveHash3D(x0s+1, y0,   z0);
    int h_aba = KweaveHash3D(x0s,   y0+1, z0);
    int h_bba = KweaveHash3D(x0s+1, y0+1, z0);
    int h_aab = KweaveHash3D(x0s,   y0,   z0+1);
    int h_bab = KweaveHash3D(x0s+1, y0,   z0+1);
    int h_abb = KweaveHash3D(x0s,   y0+1, z0+1);
    int h_bbb = KweaveHash3D(x0s+1, y0+1, z0+1);

    float3 g_aaa = KweaveRotatedGrad(h_aaa, Time, RotationSpeed);
    float3 g_baa = KweaveRotatedGrad(h_baa, Time, RotationSpeed);
    float3 g_aba = KweaveRotatedGrad(h_aba, Time, RotationSpeed);
    float3 g_bba = KweaveRotatedGrad(h_bba, Time, RotationSpeed);
    float3 g_aab = KweaveRotatedGrad(h_aab, Time, RotationSpeed);
    float3 g_bab = KweaveRotatedGrad(h_bab, Time, RotationSpeed);
    float3 g_abb = KweaveRotatedGrad(h_abb, Time, RotationSpeed);
    float3 g_bbb = KweaveRotatedGrad(h_bbb, Time, RotationSpeed);

    float d_aaa = dot(g_aaa, float3(xf,     yf,     zf));
    float d_baa = dot(g_baa, float3(xf-1.0, yf,     zf));
    float d_aba = dot(g_aba, float3(xf,     yf-1.0, zf));
    float d_bba = dot(g_bba, float3(xf-1.0, yf-1.0, zf));
    float d_aab = dot(g_aab, float3(xf,     yf,     zf-1.0));
    float d_bab = dot(g_bab, float3(xf-1.0, yf,     zf-1.0));
    float d_abb = dot(g_abb, float3(xf,     yf-1.0, zf-1.0));
    float d_bbb = dot(g_bbb, float3(xf-1.0, yf-1.0, zf-1.0));

    float x00 = lerp(d_aaa, d_baa, u);
    float x10 = lerp(d_aba, d_bba, u);
    float x01 = lerp(d_aab, d_bab, u);
    float x11 = lerp(d_abb, d_bbb, u);
    float xy0 = lerp(x00, x10, v);
    float xy1 = lerp(x01, x11, v);

    return lerp(xy0, xy1, w) * 0.5 + 0.5;
}

float KweaveNoiseFlow(float3 Position, float Frequency, int Seed, float Time, float RotationSpeed)
{
    return KweaveNoiseFlowCore(Position, Frequency, Seed, Time, RotationSpeed);
}

float2 KweaveNoiseFlow2(float3 Position, float Frequency, int Seed, float Time, float RotationSpeed)
{
    return float2(
        KweaveNoiseFlow(Position, Frequency, Seed, Time, RotationSpeed),
        KweaveNoiseFlow(Position, Frequency, Seed + 1000, Time, RotationSpeed)
    );
}

float3 KweaveNoiseFlow3(float3 Position, float Frequency, int Seed, float Time, float RotationSpeed)
{
    return float3(
        KweaveNoiseFlow(Position, Frequency, Seed, Time, RotationSpeed),
        KweaveNoiseFlow(Position, Frequency, Seed + 1000, Time, RotationSpeed),
        KweaveNoiseFlow(Position, Frequency, Seed + 2000, Time, RotationSpeed)
    );
}

// ====== Caustic Noise ======

float KweaveCausticWaveLayer(float3 pos, int layerIndex, int totalLayers, float time, float animSpeed)
{
    float angleOffset = (float)layerIndex * KWEAVE_PI * 2.0 / (float)totalLayers;
    float phaseOffset = (float)layerIndex * 1.7;
    float timeOffset = time * animSpeed + phaseOffset;

    float ca = cos(angleOffset);
    float sa = sin(angleOffset);

    float projXY = pos.x * ca + pos.y * sa;
    float projXZ = pos.x * sa + pos.z * ca;

    float wave1 = sin((projXY + timeOffset) * KWEAVE_PI * 2.0);
    float wave2 = sin((projXZ * 0.7 + timeOffset * 1.3) * KWEAVE_PI * 2.0);
    float wave3 = sin(((projXY + projXZ) * 0.5 + timeOffset * 0.8) * KWEAVE_PI * 2.0);

    return (wave1 + wave2 * 0.7 + wave3 * 0.5) / 2.2;
}

float KweaveNoiseCausticCore(float3 Position, float Frequency, int Seed, int WaveLayers, float Time, float AnimationSpeed)
{
    float3 pos = Position * Frequency;
    // Add seed-based offset
    pos += float3(
        KweaveHash11(Seed, 0, 0) * 100.0,
        KweaveHash11(0, Seed, 0) * 100.0,
        KweaveHash11(0, 0, Seed) * 100.0
    );

    float sum = 0.0;
    for (int i = 0; i < WaveLayers; i++)
    {
        sum += KweaveCausticWaveLayer(pos, i, WaveLayers, Time, AnimationSpeed);
    }
    sum /= (float)WaveLayers;

    // Remap to [0,1] and apply focus
    sum = sum * 0.5 + 0.5;
    sum = pow(saturate(sum), 2.0);

    return saturate(sum);
}

float KweaveNoiseCaustic(float3 Position, float Frequency, int Seed, int WaveLayers, float Time, float AnimationSpeed)
{
    return KweaveNoiseCausticCore(Position, Frequency, Seed, WaveLayers, Time, AnimationSpeed);
}

float2 KweaveNoiseCaustic2(float3 Position, float Frequency, int Seed, int WaveLayers, float Time, float AnimationSpeed)
{
    return float2(
        KweaveNoiseCaustic(Position, Frequency, Seed, WaveLayers, Time, AnimationSpeed),
        KweaveNoiseCaustic(Position, Frequency, Seed + 1000, WaveLayers, Time, AnimationSpeed)
    );
}

float3 KweaveNoiseCaustic3(float3 Position, float Frequency, int Seed, int WaveLayers, float Time, float AnimationSpeed)
{
    return float3(
        KweaveNoiseCaustic(Position, Frequency, Seed, WaveLayers, Time, AnimationSpeed),
        KweaveNoiseCaustic(Position, Frequency, Seed + 1000, WaveLayers, Time, AnimationSpeed),
        KweaveNoiseCaustic(Position, Frequency, Seed + 2000, WaveLayers, Time, AnimationSpeed)
    );
}

// ====== Gabor Noise ======

static const float KWEAVE_GABOR_RADIUS = 1.5;

float KweaveGaborKernel(float3 offset, float k, float a, float3 dir)
{
    float r2 = dot(offset, offset);
    if (r2 > KWEAVE_GABOR_RADIUS * KWEAVE_GABOR_RADIUS) return 0.0;
    float gaussian = exp(-KWEAVE_PI * a * a * r2);
    float phase = 2.0 * KWEAVE_PI * k * dot(dir, offset);
    return gaussian * cos(phase);
}

float KweaveNoiseGaborCore(float3 Position, float Frequency, int Seed, float3 Direction, float Bandwidth, int ImpulsesPerCell)
{
    float3 pos = Position * Frequency;
    int xi = (int)floor(pos.x);
    int yi = (int)floor(pos.y);
    int zi = (int)floor(pos.z);

    float k = Frequency * Bandwidth;
    float a = Bandwidth;
    float3 dir = normalize(Direction);

    float sum = 0.0;
    int count = 0;
    int searchRadius = (int)ceil(KWEAVE_GABOR_RADIUS);

    for (int dz = -searchRadius; dz <= searchRadius; dz++)
    for (int dy = -searchRadius; dy <= searchRadius; dy++)
    for (int dx = -searchRadius; dx <= searchRadius; dx++)
    {
        int nx = xi + dx;
        int ny = yi + dy;
        int nz = zi + dz;

        for (int i = 0; i < ImpulsesPerCell; i++)
        {
            // Random impulse position
            float ipx = (float)nx + KweaveHash01(nx + Seed, ny + i, nz);
            float ipy = (float)ny + KweaveHash01(nx + i, ny + Seed, nz);
            float ipz = (float)nz + KweaveHash01(nx, ny, nz + Seed + i);

            float3 delta = pos - float3(ipx, ipy, ipz);

            // Random weight [-1, 1]
            float weight = KweaveHash11(nx + i, ny + i, nz + Seed);

            sum += weight * KweaveGaborKernel(delta, k, a, dir);
            count++;
        }
    }

    // Normalize
    return sum * sqrt(1.0 / max((float)count, 1.0)) * 0.5 + 0.5;
}

float KweaveNoiseGabor(float3 Position, float Frequency, int Seed, float3 Direction, float Bandwidth, int ImpulsesPerCell)
{
    return KweaveNoiseGaborCore(Position, Frequency, Seed, Direction, Bandwidth, ImpulsesPerCell);
}

float2 KweaveNoiseGabor2(float3 Position, float Frequency, int Seed, float3 Direction, float Bandwidth, int ImpulsesPerCell)
{
    return float2(
        KweaveNoiseGabor(Position, Frequency, Seed, Direction, Bandwidth, ImpulsesPerCell),
        KweaveNoiseGabor(Position, Frequency, Seed + 1000, Direction, Bandwidth, ImpulsesPerCell)
    );
}

float3 KweaveNoiseGabor3(float3 Position, float Frequency, int Seed, float3 Direction, float Bandwidth, int ImpulsesPerCell)
{
    return float3(
        KweaveNoiseGabor(Position, Frequency, Seed, Direction, Bandwidth, ImpulsesPerCell),
        KweaveNoiseGabor(Position, Frequency, Seed + 1000, Direction, Bandwidth, ImpulsesPerCell),
        KweaveNoiseGabor(Position, Frequency, Seed + 2000, Direction, Bandwidth, ImpulsesPerCell)
    );
}

// ====== Marble Noise ======

float KweaveMarbleTurbulence(float3 pos, int seed, int octaves)
{
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float maxVal = 0.0;

    for (int i = 0; i < octaves; i++)
    {
        sum += abs(KweavePerlinRaw(pos * freq, seed + i)) * amp;
        maxVal += amp;
        amp *= 0.5;
        freq *= 2.0;
    }

    return sum / maxVal;
}

float KweaveNoiseMarbleCore(float3 Position, float Frequency, int Seed, float VeinFrequency, float TurbulenceStrength)
{
    float3 pos = Position * Frequency;

    // Use X coordinate as base (radial is accessible by passing length(Position) as 1D)
    float baseCoord = pos.x;

    // Turbulence distortion (4 octaves)
    float turbulence = KweaveMarbleTurbulence(pos, Seed, 4) * TurbulenceStrength;

    // Sine vein pattern
    float sineInput = (baseCoord * VeinFrequency + turbulence) * KWEAVE_PI;
    float result = sin(sineInput);

    return result * 0.5 + 0.5;
}

float KweaveNoiseMarble(float3 Position, float Frequency, int Seed, float VeinFrequency, float TurbulenceStrength)
{
    return KweaveNoiseMarbleCore(Position, Frequency, Seed, VeinFrequency, TurbulenceStrength);
}

float2 KweaveNoiseMarble2(float3 Position, float Frequency, int Seed, float VeinFrequency, float TurbulenceStrength)
{
    return float2(
        KweaveNoiseMarble(Position, Frequency, Seed, VeinFrequency, TurbulenceStrength),
        KweaveNoiseMarble(Position, Frequency, Seed + 1000, VeinFrequency, TurbulenceStrength)
    );
}

float3 KweaveNoiseMarble3(float3 Position, float Frequency, int Seed, float VeinFrequency, float TurbulenceStrength)
{
    return float3(
        KweaveNoiseMarble(Position, Frequency, Seed, VeinFrequency, TurbulenceStrength),
        KweaveNoiseMarble(Position, Frequency, Seed + 1000, VeinFrequency, TurbulenceStrength),
        KweaveNoiseMarble(Position, Frequency, Seed + 2000, VeinFrequency, TurbulenceStrength)
    );
}
