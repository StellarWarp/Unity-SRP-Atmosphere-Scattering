Shader "Unlit/APITest"
{

    Properties
    {

    }

    SubShader
    {
        Tags 
        {
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
        }
        LOD 100


        Pass
        {
            Tags 
            {
                "LightMode" = "UniversalForward" 
            }
            
            HLSLPROGRAM
            //receive shadows
            #include  "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include  "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma  vertex vert
            #pragma  fragment frag

            #pragma  multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma  multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma  multi_compile _ _SHADOWS_SOFT

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                half shadow = MainLightRealtimeShadow(shadowCoord);
                return shadow;
            }
            
            ENDHLSL
        }
    }

}
