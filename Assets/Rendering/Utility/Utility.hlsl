#ifndef UTILITY_INCLUDED_HANDER
#define UTILITY_INCLUDED_HANDER

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


inline float3 GetObjectWorldPosition()
{
    return UNITY_MATRIX_M._14_24_34;
}

inline float3 GetObjectWorldScale()
{
    return float3(length(UNITY_MATRIX_M._11_21_31), length(UNITY_MATRIX_M._12_22_32), length(UNITY_MATRIX_M._13_23_33));
}

inline float2 ScreenUV(float4 positionHCS)
{
	return positionHCS.xy / _ScaledScreenParams.xy;
}

//reconstruct world space position using view direction and depth
inline float WorldSurfaceDistance(float4 positionHCS, float3 normalized_view_dir_VS)
{
    float2 uv = positionHCS.xy / _ScaledScreenParams.xy;
    float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    #if defined(UNITY_REVERSE_Z)
			depth = 1.0 - depth;
    #endif

    return depth / normalized_view_dir_VS.z;
}

//return near and far intersection distance
inline float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float sphereRadius)
{
    float b = 2.0 * dot(rayDir, rayOrigin);
    float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
    float d = (b * b) - 4.0 * c;
    if (d < 0)
    {
        return float2(1e5, -1e5);
    }
    return float2(
        max((-b - sqrt(d)) / 2.0, 0.0),
        (-b + sqrt(d)) / 2.0
    );
}


#endif
