Shader "Test/BlitBlend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurSize("Blur Size", Range(0.0, 1.0)) = 0.01
        _BilaterFilterFactor("Bilater Filter Factor", Range(0.0, 1.0)) = 0.5
        _blurInt("Blur Int", Range(0, 10)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _BilaterFilterFactor;
        int _blurInt;
        float _BlurSize;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_ColorFinalTex);
        SAMPLER(sampler_ColorFinalTex);

        TEXTURE2D(_AlphaFinalTex);
        SAMPLER(sampler_AlphaFinalTex);

        TEXTURE2D(_ColorTex);
        SAMPLER(sampler_ColorTex);

        TEXTURE2D(_AlphaTex);
        SAMPLER(sampler_AlphaTex);


        struct appdata
        {
            float4 vertex : POSITION;
        };

        struct v2f
        {
            float4 positionHCS : SV_POSITION;
            half2 screenUV: TEXCOORD0;
        };


        v2f vert(appdata v)
        {
            v2f o;
            o.positionHCS = TransformObjectToHClip(v.vertex);
            float4 uv = ComputeScreenPos(o.positionHCS);
            o.screenUV = uv.xy / uv.w;
            // o.screenUV *=0.5;
            // o.screenUV = float2(o.screenUV.x, o.screenUV.y * _ProjectionParams.x) + o.positionHCS.w;
            // o.screenUV /= o.positionHCS.z;
            // o.zw = positionCS.zw;
            // ComputeScreenPos(o.positionHCS)
            return o;
        }
        
        ENDHLSL


        Pass
        {
            Name "BlitToColor"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend One Zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            half4 frag(v2f i) : SV_Target
            {
                // sample the texture
                const float2 uv = i.screenUV;
                //blur

                half4 color = SAMPLE_TEXTURE2D(_ColorTex, sampler_ColorTex, uv);
                half4 alpha = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, uv);
                half4 color_final = SAMPLE_TEXTURE2D(_ColorFinalTex, sampler_ColorTex, uv);
                half4 alpha_final = SAMPLE_TEXTURE2D(_AlphaFinalTex, sampler_AlphaTex, uv);

                return color + color_final * alpha;
            }
            ENDHLSL
        }

        Pass
        {
            Name "BlitToAlpha"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend DstColor Zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            half4 frag(v2f i) : SV_Target
            {
                // sample the texture
                const float2 uv = i.screenUV;
                half4 color = SAMPLE_TEXTURE2D(_ColorTex, sampler_ColorTex, uv);
                half4 alpha = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, uv);
                half4 color_final = SAMPLE_TEXTURE2D(_ColorFinalTex, sampler_ColorTex, uv);
                half4 alpha_final = SAMPLE_TEXTURE2D(_AlphaFinalTex, sampler_AlphaTex, uv);

                // return alpha_final * alpha;
                return alpha;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Blend"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend One Zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            half4 frag(v2f i) : SV_Target
            {
                const float2 uv = i.screenUV;
                half4 base_color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                half4 color = SAMPLE_TEXTURE2D(_ColorFinalTex, sampler_ColorFinalTex, uv);
                half4 alpha = SAMPLE_TEXTURE2D(_AlphaFinalTex, sampler_AlphaFinalTex, uv);

                // return half4(i.screenUV, 0, 1);
                return color + base_color * alpha;
            }
            ENDHLSL
        }
    }
}