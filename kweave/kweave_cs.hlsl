// =============================================================================
// Kweave Compute Source — Utility functions for Kweave-generated PCG GPU nodes.
// KWEAVE_CS_VERSION 1
//
// Managed by Kweave — do not edit manually if using the Kweave Bridge.
// These functions are prefixed with "Kweave" to avoid name collisions.
// =============================================================================

// --- Quaternion Slerp ---
// Spherical linear interpolation between two unit quaternions.
float4 KweaveSlerp(float4 A, float4 B, float Alpha)
{
    float CosTheta = dot(A, B);

    // Take the shorter arc
    if (CosTheta < 0.0)
    {
        B = -B;
        CosTheta = -CosTheta;
    }

    // Fall back to lerp for nearly-parallel quaternions
    if (CosTheta > 0.9995)
    {
        return normalize(lerp(A, B, Alpha));
    }

    float Theta = acos(CosTheta);
    float SinTheta = sin(Theta);
    float WA = sin((1.0 - Alpha) * Theta) / SinTheta;
    float WB = sin(Alpha * Theta) / SinTheta;
    return WA * A + WB * B;
}

// --- Quaternion to 4x4 rotation matrix ---
float4x4 KweaveQuatToMatrix(float4 Q)
{
    float X2 = Q.x + Q.x;
    float Y2 = Q.y + Q.y;
    float Z2 = Q.z + Q.z;
    float XX = Q.x * X2;
    float XY = Q.x * Y2;
    float XZ = Q.x * Z2;
    float YY = Q.y * Y2;
    float YZ = Q.y * Z2;
    float ZZ = Q.z * Z2;
    float WX = Q.w * X2;
    float WY = Q.w * Y2;
    float WZ = Q.w * Z2;

    return float4x4(
        1.0 - (YY + ZZ), XY - WZ,         XZ + WY,         0.0,
        XY + WZ,         1.0 - (XX + ZZ),  YZ - WX,         0.0,
        XZ - WY,         YZ + WX,          1.0 - (XX + YY),  0.0,
        0.0,             0.0,              0.0,              1.0
    );
}

// --- Quaternion from Euler angles (pitch, yaw, roll in degrees) ---
float4 KweaveQuatFromRotator(float3 PitchYawRollDeg)
{
    float3 Rad = radians(PitchYawRollDeg) * 0.5;
    float3 C = cos(Rad);
    float3 S = sin(Rad);

    return float4(
        C.y * S.x * C.z + S.y * C.x * S.z,   // X
        S.y * C.x * C.z - C.y * S.x * S.z,   // Y
        C.y * C.x * S.z - S.y * S.x * C.z,   // Z
        C.y * C.x * C.z + S.y * S.x * S.z    // W
    );
}

// --- Quaternion inverse (conjugate / squared length) ---
// For unit quaternions this is just the conjugate, but this version
// handles non-unit quaternions safely.
float4 KweaveQuatInverse(float4 Q)
{
    float LenSq = dot(Q, Q);
    return float4(-Q.xyz, Q.w) / max(LenSq, 0.0001);
}
