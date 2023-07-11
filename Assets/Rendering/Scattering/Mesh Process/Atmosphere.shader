Shader "RayMarching/Atmosphere"
{
    Properties
    {
        //_debug("debug", Range(0, 1)) = 0
        _planet_radius("planet radius", Float) = 0
        _atmo_radius("atmo radius", Float) = 0.5
        _steps_i("steps_i", Int) = 32
        _steps_l("steps_l", Int) = 8
        _g("g", Range(0, 1)) = 0.7
        _ray_scale("ray scale", Float) = 1
        _height_ray("height ray", Float) = 0
        _height_mie("height mie", Float) = 0
        _height_absorption("height absorption", Float) = 0
        _absorption_falloff("absorption falloff", Float) = 0
        [HDR]_light_intensity("light intensity", Color) = (0, 0, 0, 0)
        [HDR]_beta_ray("Ray Beta", Color) = (0, 0, 0, 0)
        [HDR]_beta_mie("Mie Beta", Color) = (0, 0, 0, 0)
        [HDR]_beta_absorption("Absorption Beta", Color) = (0, 0, 0, 0)
        [HDR]_beta_ambient("Ambient Beta", Color) = (0, 0, 0, 0)
        _DitherTex("Dither Texture", 2D) = "white" {}
        _ditherStrength("Dither Strength", Range(0, 10)) = 0.5
        [Toggle(_True)]_point_light("point light", Int) = 0
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
            float _g;
            float _height_ray;
            float _height_mie;
            float _height_absorption;
            float _absorption_falloff;
            int _steps_i;
            int _steps_l;
            float _ray_scale;
            float3 _light_intensity;
            float3 _beta_ray;
            float3 _beta_mie;
            float3 _beta_absorption;
            float3 _beta_ambient;
            float _ditherStrength;
            bool _point_light;
            CBUFFER_END

            TEXTURE2D(_DitherTex);
            SAMPLER(sampler_DitherTex);

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

            struct frag_out
            {
                half4 color : COLOR0;
                half4 alpha : COLOR1;
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

            frag_out frag(v2f i) : SV_Target
            {
                frag_out o;
                o.alpha = half4(1, 1, 1, 0);
                o.color = half4(0, 0, 0, 0);

                //world space view direction
                i.view_dir_WS = normalize(i.view_dir_WS);
                i.view_dir_VS = normalize(i.view_dir_VS);
                float2 screenUV = i.positionHCS.xy / _ScaledScreenParams.xy;


                //reconstruct world space position using view direction and depth
                float distance = WorldSurfaceDistance(i.positionHCS, i.view_dir_VS);


                // return PlanetScattering(
                // 	GetCameraPositionWS(), 
                // 	i.view_dir_WS, 
                // 	distance, 
                // 	light_dir, 
                // 	_light_intensity,
                // 	GetObjectWorldPosition(),
                // 	_planet_radius, 
                // 	_atmo_radius, 
                // 	_beta_ray, 
                // 	_beta_mie, 
                // 	_beta_absorption, 
                // 	_beta_ambient, 
                // 	_g, 
                // 	_height_ray, 
                // 	_height_mie, 
                // 	_height_absorption, 
                // 	_absorption_falloff, 
                // 	_steps_i, 
                // 	_steps_l
                // 	);

                float3 planet_position_WS = GetObjectWorldPosition();
                float3 origin = GetCameraPositionWS() - planet_position_WS;
                //main light direction
                float3 light_dir;
                if (_point_light)
                {
                    light_dir = normalize(_MainLightPosition.xyz - planet_position_WS);
                }
                else
                {
                    Light light = GetMainLight();
                    light_dir = light.direction;
                }

                float3 dir = -i.view_dir_WS;

                // calculate the ray length
                float2 ray_length = RaySphereIntersection(origin, dir, _atmo_radius);
                ray_length.y = min(ray_length.y, distance);

                // if the ray did not hit the atmosphere, return a back color
                if (ray_length.x > ray_length.y)
                    return o;

                // return (ray_length.y - ray_length.x)/_atmo_radius;


                // get the step size of the ray
                float step_size_i = (ray_length.y - ray_length.x) / float(_steps_i);

                // next, set how far we are along the ray, so we can calculate the position of the sample
                // if the camera is outside the atmosphere, the ray should origin at the edge of the atmosphere
                // if it's inside, it should origin at the position of the camera
                // the min statement makes sure of that
                float dither = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, screenUV).r * _ditherStrength;
                // float ray_pos_i = ray_length.x + step_size_i * 0.5 + dither * step_size_i;
                float dither_i = dither * step_size_i;
                float ray_pos_i = ray_length.x + dither_i;

                // these are the values we use to gather all the scattered light
                float3 total_ray = float3(0, 0, 0); // for rayleigh
                float3 total_mie = float3(0, 0, 0); // for mie

                // initialize the optical depth. This is used to calculate how much air was in the ray
                float3 opt_i = float3(0, 0, 0);

                // also init the scale height, avoids some float2's later on
                float2 scale_height = float2(_height_ray, _height_mie);

                float phase_ray;
                float phase_mie;
                // prevent the mie glow from appearing if there's an object in front of the camera
                bool allow_mie = distance > ray_length.y;
                phase_rayleigh_mie(light_dir, dir, _g, true, phase_ray, phase_mie);

                // now we need to sample the 'primary' ray. this ray gathers the light that gets scattered onto it
                for (int i = 0; i < _steps_i; ++i)
                {
                    // calculate where we are along this ray
                    float3 pos_i = origin + dir * ray_pos_i;

                    // and how high we are above the surface
                    float height_i = length(pos_i) - _planet_radius;

                    // now calculate the density of the particles (both for rayleigh and mie)
                    float3 density = float3(exp(-height_i / scale_height), 0.0);

                    // and the absorption density. this is for ozone, which scales together with the rayleigh, 
                    // but absorbs the most at a specific height, so use the sech function for a nice curve falloff for this height
                    // clamp it to avoid it going out of bounds. This prevents weird black spheres on the night side
                    float denom = (_height_absorption - height_i) / _absorption_falloff;
                    density.z = (1.0 / (denom * denom + 1.0)) * density.x;

                    // multiply it by the step size here
                    // we are going to use the density later on as well
                    density *= step_size_i;

                    // Add these densities to the optical depth, so that we know how many particles are on this ray.
                    opt_i += density;

                    // Calculate the step size of the light ray.
                    // again with a ray sphere intersect
                    float a = dot(light_dir, light_dir);
                    float b = 2.0 * dot(light_dir, pos_i);
                    float c = dot(pos_i, pos_i) - (_atmo_radius * _atmo_radius);
                    float d = (b * b) - 4.0 * a * c;

                    // no early stopping, this one should always be inside the atmosphere
                    // calculate the ray length
                    float step_size_l = (-b + sqrt(d)) / (2.0 * a * float(_steps_l));

                    // and the position along this ray
                    // this time we are sure the ray is in the atmosphere, so set it to 0
                    // dither = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, screenUV).r;
                    float ray_pos_l = step_size_l * 0.5 + dither * step_size_l;

                    // and the optical depth of this ray
                    float3 opt_l = float3(0, 0, 0);

                    // now sample the light ray
                    // this is similar to what we did before
                    for (int l = 0; l < _steps_l; ++l)
                    {
                        // calculate where we are along this ray
                        float3 pos_l = pos_i + light_dir * ray_pos_l;

                        // the heigth of the position
                        float height_l = length(pos_l) - _planet_radius;

                        // calculate the particle density, and add it
                        // this is a bit verbose
                        // first, set the density for ray and mie
                        float3 density_l = float3(exp(-height_l / scale_height), 0.0);

                        // then, the absorption
                        float denom = (_height_absorption - height_l) / _absorption_falloff;
                        density_l.z = (1.0 / (denom * denom + 1.0)) * density_l.x;

                        // multiply the density by the step size
                        density_l *= step_size_l;

                        // and add it to the total optical depth
                        opt_l += density_l;

                        // and increment where we are along the light ray.
                        ray_pos_l += step_size_l;
                    }

                    // Now we need to calculate the attenuation
                    // this is essentially how much light reaches the current sample point due to scattering
                    float3 attn = exp(
                        - _beta_ray * (opt_i.x + opt_l.x)
                        - _beta_mie * (opt_i.y + opt_l.y)
                        - _beta_absorption * (opt_i.z + opt_l.z)
                    ) * GetShadow(pos_i + planet_position_WS);
                    // accumulate the scattered light (how much will be scattered towards the camera)
                    total_ray += density.x * attn;
                    total_mie += density.y * attn;

                    // and increment the position on this ray
                    ray_pos_i += step_size_i;
                }

                // calculate how much light can pass through the atmosphere
                float3 opacity = exp(-(
                    _beta_ray * opt_i.x +
                    _beta_mie * opt_i.y +
                    _beta_absorption * opt_i.z
                ));
                // calculate and return the final color
                float3 col = (
                    phase_ray * _beta_ray * total_ray + // rayleigh color
                    phase_mie * _beta_mie * total_mie + // mie
                    opt_i.x * _beta_ambient // and ambient
                ) * _light_intensity;

                o.color = half4(col, 1);
                o.alpha = half4(opacity, 1);
                return o;
            }
            ENDHLSL
        }

    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}