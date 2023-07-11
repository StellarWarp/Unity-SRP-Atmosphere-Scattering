Shader "Unlit/TestFeatureShader"
{
    Properties
    {
        [HDR]_Color ("Color", Color) = (1,1,1,1)
        [HDR]_Transmittance ("Transmittance", Color) = (1,1,1,1)
        _Debug ("Debug", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "UniversalMaterialType" = "Unlit"
            "DisableBatching" = "False"
        }
        LOD 100

        HLSLINCLUDE
                       #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
               
                       CBUFFER_START(UnityPerMaterial)
                       float _Debug;
                       float4 _Color;
                       float4 _Transmittance;
                       CBUFFER_END
               
                       // TEXTURE2D(_MainTex);
                       // SAMPLER(sampler_MainTex);
               
                       TEXTURE2D(_ColorFinalTex);
                       SAMPLER(sampler_ColorFinalTex);
               
                       TEXTURE2D(_AlphaFinalTex);
                       SAMPLER(sampler_AlphaFinalTex);
               
                       TEXTURE2D(_ColorTex);
                       SAMPLER(sampler_ColorTex);
               
                       TEXTURE2D(_AlphaTex);
                       SAMPLER(sampler_AlphaTex);
               
                       struct frag_out
                       {
                           half4 color : COLOR0;
                           half4 alpha : COLOR1;
                       };
                       ENDHLSL



        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #pragma shader_feature _AdditionalLights

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.positionHCS = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            frag_out frag(v2f i) : SV_Target
            {
                float2 uv = i.positionHCS.xy / _ScaledScreenParams.xy;

                frag_out o;
                o.color = _Color;
                o.alpha = _Transmittance;
                return o;
            }
            ENDHLSL
        }
    }
}