// =============================================================================
// Kweave Compute Source -- Utility functions for Kweave-generated PCG GPU nodes.
// KWEAVE_CS_VERSION 3
//
// Managed by Kweave -- do not edit manually if using the Kweave Bridge.
// These functions are prefixed with "Kweave" to avoid name collisions.
// =============================================================================

// --- Chebyshev (L∞) distance ---
// Maximum absolute per-component difference.
float KweaveChebyshevDistance(float A, float B)
{
    return abs(A - B);
}

float KweaveChebyshevDistance(float2 A, float2 B)
{
    float2 D = abs(A - B);
    return max(D.x, D.y);
}

float KweaveChebyshevDistance(float3 A, float3 B)
{
    float3 D = abs(A - B);
    return max(D.x, max(D.y, D.z));
}

float KweaveChebyshevDistance(float4 A, float4 B)
{
    float4 D = abs(A - B);
    return max(max(D.x, D.y), max(D.z, D.w));
}

// --- Quaternion Slerp ---
// Spherical linear interpolation between two unit quaternions.
half4 KweaveSlerp(half4 A, half4 B, half Alpha)
{
    half CosTheta = dot(A, B);

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

    half Theta = acos(CosTheta);
    half SinTheta = sin(Theta);
    half WA = sin((1.0 - Alpha) * Theta) / SinTheta;
    half WB = sin(Alpha * Theta) / SinTheta;
    return WA * A + WB * B;
}

// --- Quaternion to 4x4 rotation matrix ---
float4x4 KweaveQuatToMatrix(half4 Q)
{
    half X2 = Q.x + Q.x;
    half Y2 = Q.y + Q.y;
    half Z2 = Q.z + Q.z;
    half XX = Q.x * X2;
    half XY = Q.x * Y2;
    half XZ = Q.x * Z2;
    half YY = Q.y * Y2;
    half YZ = Q.y * Z2;
    half ZZ = Q.z * Z2;
    half WX = Q.w * X2;
    half WY = Q.w * Y2;
    half WZ = Q.w * Z2;

    return float4x4(
        1.0 - (YY + ZZ), XY - WZ,         XZ + WY,         0.0,
        XY + WZ,         1.0 - (XX + ZZ),  YZ - WX,         0.0,
        XZ - WY,         YZ + WX,          1.0 - (XX + YY),  0.0,
        0.0,             0.0,              0.0,              1.0
    );
}

// --- Quaternion from Euler angles (pitch, yaw, roll in degrees) ---
half4 KweaveQuatFromRotator(half3 PitchYawRollDeg)
{
    half3 Rad = radians(PitchYawRollDeg) * 0.5;
    half3 C = cos(Rad);
    half3 S = sin(Rad);

    return half4(
        C.y * S.x * C.z + S.y * C.x * S.z,   // X
        S.y * C.x * C.z - C.y * S.x * S.z,   // Y
        C.y * C.x * S.z - S.y * S.x * C.z,   // Z
        C.y * C.x * C.z + S.y * S.x * S.z    // W
    );
}

// --- Quaternion inverse (conjugate / squared length) ---
// For unit quaternions this is just the conjugate, but this version
// handles non-unit quaternions safely.
half4 KweaveQuatInverse(half4 Q)
{
    half LenSq = dot(Q, Q);
    return half4(-Q.xyz, Q.w) / max(LenSq, 0.0001);
}

// --- Quaternion to Euler angles (pitch, yaw, roll in degrees) ---
half3 KweaveQuatToRotator(half4 Q)
{
    // Pitch (X rotation)
    half SinP = 2.0 * (Q.w * Q.x - Q.y * Q.z);
    half Pitch = (abs(SinP) >= 1.0) ? sign(SinP) * 90.0 : degrees(asin(SinP));

    // Yaw (Y rotation)
    half SinY = 2.0 * (Q.w * Q.y + Q.x * Q.z);
    half CosY = 1.0 - 2.0 * (Q.x * Q.x + Q.y * Q.y);
    half Yaw = degrees(atan2(SinY, CosY));

    // Roll (Z rotation)
    half SinR = 2.0 * (Q.w * Q.z + Q.x * Q.y);
    half CosR = 1.0 - 2.0 * (Q.x * Q.x + Q.z * Q.z);
    half Roll = degrees(atan2(SinR, CosR));

    return half3(Pitch, Yaw, Roll);
}

// --- Combine two rotators (Euler angles in degrees) via quaternion multiply ---
half3 KweaveCombineRotator(half3 A, half3 B)
{
    half4 QA = KweaveQuatFromRotator(A);
    half4 QB = KweaveQuatFromRotator(B);

    // Quaternion multiply: QA * QB
    half4 R;
    R.x = QA.w * QB.x + QA.x * QB.w + QA.y * QB.z - QA.z * QB.y;
    R.y = QA.w * QB.y - QA.x * QB.z + QA.y * QB.w + QA.z * QB.x;
    R.z = QA.w * QB.z + QA.x * QB.y - QA.y * QB.x + QA.z * QB.w;
    R.w = QA.w * QB.w - QA.x * QB.x - QA.y * QB.y - QA.z * QB.z;

    return KweaveQuatToRotator(R);
}

// --- Rotate a quaternion in its own local frame ---
// Right-multiply: Q * QuatFromAxisAngle(Axis, AngleRad)
half4 KweaveQuatRotateLocal(half4 Q, half3 Axis, half AngleRad)
{
    half HalfAngle = AngleRad * 0.5;
    half S = sin(HalfAngle);
    half4 Delta = half4(Axis * S, cos(HalfAngle));

    // Q * Delta
    half4 R;
    R.x = Q.w * Delta.x + Q.x * Delta.w + Q.y * Delta.z - Q.z * Delta.y;
    R.y = Q.w * Delta.y - Q.x * Delta.z + Q.y * Delta.w + Q.z * Delta.x;
    R.z = Q.w * Delta.z + Q.x * Delta.y - Q.y * Delta.x + Q.z * Delta.w;
    R.w = Q.w * Delta.w - Q.x * Delta.x - Q.y * Delta.y - Q.z * Delta.z;
    return R;
}

// --- Extract forward (X) axis from quaternion ---
half3 KweaveQuatForward(half4 Q)
{
    return half3(
        1.0 - 2.0 * (Q.y * Q.y + Q.z * Q.z),
        2.0 * (Q.x * Q.y + Q.w * Q.z),
        2.0 * (Q.x * Q.z - Q.w * Q.y)
    );
}

// --- Extract right (Y) axis from quaternion ---
half3 KweaveQuatRight(half4 Q)
{
    return half3(
        2.0 * (Q.x * Q.y - Q.w * Q.z),
        1.0 - 2.0 * (Q.x * Q.x + Q.z * Q.z),
        2.0 * (Q.y * Q.z + Q.w * Q.x)
    );
}

// --- Extract up (Z) axis from quaternion ---
half3 KweaveQuatUp(half4 Q)
{
    return half3(
        2.0 * (Q.x * Q.z + Q.w * Q.y),
        2.0 * (Q.y * Q.z - Q.w * Q.x),
        1.0 - 2.0 * (Q.x * Q.x + Q.y * Q.y)
    );
}

// --- Internal: build quaternion from a 3x3 rotation matrix (column vectors) ---
half4 KweaveQuatFromMatrix3(half3 X, half3 Y, half3 Z)
{
    half Trace = X.x + Y.y + Z.z;
    half4 Q;

    if (Trace > 0.0)
    {
        half S = sqrt(Trace + 1.0) * 2.0;
        Q = half4(
            (Y.z - Z.y) / S,
            (Z.x - X.z) / S,
            (X.y - Y.x) / S,
            0.25 * S
        );
    }
    else if (X.x > Y.y && X.x > Z.z)
    {
        half S = sqrt(1.0 + X.x - Y.y - Z.z) * 2.0;
        Q = half4(
            0.25 * S,
            (X.y + Y.x) / S,
            (Z.x + X.z) / S,
            (Y.z - Z.y) / S
        );
    }
    else if (Y.y > Z.z)
    {
        half S = sqrt(1.0 + Y.y - X.x - Z.z) * 2.0;
        Q = half4(
            (X.y + Y.x) / S,
            0.25 * S,
            (Y.z + Z.y) / S,
            (Z.x - X.z) / S
        );
    }
    else
    {
        half S = sqrt(1.0 + Z.z - X.x - Y.y) * 2.0;
        Q = half4(
            (Z.x + X.z) / S,
            (Y.z + Z.y) / S,
            0.25 * S,
            (X.y - Y.x) / S
        );
    }

    return normalize(Q);
}

// --- Build quaternion from a single direction vector (axis = 0:X, 1:Y, 2:Z) ---
// The given direction becomes the specified axis; the other two are derived.
half4 KweaveQuatFromAxis(half3 Dir, int Axis)
{
    half3 D = normalize(Dir);

    // Pick a reference vector not parallel to D
    half3 Ref = (abs(D.z) < 0.999) ? half3(0, 0, 1) : half3(1, 0, 0);

    half3 A2 = normalize(cross(D, Ref));
    half3 A3 = cross(D, A2);

    // Assign to X/Y/Z columns based on which axis D represents
    half3 X, Y, Z;
    if (Axis == 0) { X = D; Y = A2; Z = A3; }
    else if (Axis == 1) { Y = D; Z = A2; X = A3; }
    else { Z = D; X = A2; Y = A3; }

    return KweaveQuatFromMatrix3(X, Y, Z);
}

// --- Build quaternion from two direction vectors ---
// Primary direction becomes PrimaryAxis, secondary is orthogonalized to become SecondaryAxis.
half4 KweaveQuatFromAxes(half3 PrimaryDir, half3 SecondaryDir, int PrimaryAxis, int SecondaryAxis)
{
    half3 P = normalize(PrimaryDir);
    // Gram-Schmidt: remove the component of SecondaryDir along P
    half3 S = normalize(SecondaryDir - P * dot(SecondaryDir, P));
    // Third axis via cross product (right-hand rule, may need sign flip)
    half3 T = cross(P, S);

    // Assign to X/Y/Z based on axis indices
    // PrimaryAxis and SecondaryAxis are different (0=X, 1=Y, 2=Z)
    int ThirdAxis = 3 - PrimaryAxis - SecondaryAxis;

    half3 Axes[3];
    Axes[PrimaryAxis] = P;
    Axes[SecondaryAxis] = S;
    Axes[ThirdAxis] = T;

    // Ensure right-handed: if cross(X,Y) disagrees with Z, flip the third axis
    half3 Check = cross(Axes[0], Axes[1]);
    if (dot(Check, Axes[2]) < 0.0) Axes[ThirdAxis] = -T;

    return KweaveQuatFromMatrix3(Axes[0], Axes[1], Axes[2]);
}
