Shader "RayMarching/Intersect"
{
    Properties
    {
        //_debug("debug", Range(0, 1)) = 0
        _planet_radius("planet radius", Float) = 0
        _atmo_radius("atmo radius", Float) = 0.5
        [HideInInspector]_QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector]_QueueControl("_QueueControl", Float) = -1
        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            // "RenderType"="Opaque"
            // "Queue"="Geometry"
            "UniversalMaterialType" = "Unlit"
            "DisableBatching" = "False"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            // Render State
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always

            // Cull Back
            // Blend One Zero
            // ZTest LEqual
            // ZWrite On

            HLSLPROGRAM
            #pragma shader_feature _AdditionalLights
            // 接收阴影所需关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT


            #pragma vertex vert
            #pragma fragment frag

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
            #include "Assets/Rendering//Utility/Utility.hlsl"
            #include "Assets/Rendering/Utility/Scattering.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _atmo_radius;
            float _planet_radius;
            CBUFFER_END
            

            inline void phase_rayleigh_mie(
                float3 light_dir,
                float3 ray_dir,
                float g,
                bool allow_mie,
                out float phase_ray,
                out float phase_mie)
            {
                float mu = dot(ray_dir, light_dir);
                float mumu = mu * mu;
                float gg = g * g;
                phase_ray = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
                phase_mie = allow_mie
                                ? 3.0 / (25.1327412287 /* (8 * pi) */)
                                * ((1.0 - gg)
                                    * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg))
                                : 0.0;
                // phase_mie =
                // 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) 
                // * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
            }

            inline half GetShadow(float3 positionWS)
            {
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                //sample shadow near by
                half shadow = MainLightRealtimeShadow(shadowCoord);
                // Light light = GetMainLight(shadowCoord);
                // half shadow = light.shadowAttenuation;
                // float3 light_dir = normalize(_MainLightPosition.xyz - GetObjectWorldPosition());
                // shadow =shadow
                return shadow;
            }


            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
                float3 view_dir_WS : TEXCOORD0;
                float3 view_dir_VS : TEXCOORD1;
            };
            


            v2f vert(appdata v)
            {
                v2f o;
                //world
                o.positionHCS.xyz = TransformObjectToWorld(v.vertex.xyz);
                o.view_dir_WS = GetWorldSpaceViewDir(o.positionHCS.xyz);
                //view
                o.view_dir_VS = TransformWorldToViewDir(o.view_dir_WS);
                //clip
                o.positionHCS = TransformWorldToHClip(o.positionHCS.xyz);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {

                //world space view direction
                i.view_dir_WS = normalize(i.view_dir_WS);
                i.view_dir_VS = normalize(i.view_dir_VS);
                float2 screenUV = i.positionHCS.xy / _ScaledScreenParams.xy;
                
                float distance = WorldSurfaceDistance(i.positionHCS, i.view_dir_VS);

                float3 planet_position_WS = GetObjectWorldPosition();
                float3 origin = GetCameraPositionWS() - planet_position_WS;
                //main light direction
                float3 light_dir;
                {
                    Light light = GetMainLight();
                    light_dir = light.direction;
                }

                float3 dir = -i.view_dir_WS;

                // calculate the ray length
                float2 near_far = RaySphereIntersection(origin, dir, _atmo_radius);
                near_far.y = min(near_far.y, distance);

                // if the ray did not hit the atmosphere, return a back color
                if (near_far.x > near_far.y)
                    return 0;

                float2 inter_near_far = RaySphereIntersection(origin, dir, _planet_radius);

                if (inter_near_far.x > inter_near_far.y)
                    return 0;

                half4 res = abs(near_far.y - inter_near_far.x)/4;
                res.a = 1;
                return res;
            }
            ENDHLSL
        }

    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}