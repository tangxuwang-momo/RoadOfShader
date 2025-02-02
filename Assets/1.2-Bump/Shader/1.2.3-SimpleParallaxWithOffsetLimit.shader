﻿//https://www.jianshu.com/p/fea6c9fc610f

Shader "RoadOfShader/1.2-Bump/Simple Parallax With Offset Limit"
{
    Properties
    {
        [NoScaleOffset]_MainTex ("Main Tex", 2D) = "white" { }
        [NoScaleOffset]_NormalMap ("Normal Map", 2D) = "bump" { }
        [NoScaleOffset]_DepthMap ("Depth Map", 2D) = "bump" { }
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(32, 256)) = 64
        _HeightScale ("Height Scale", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }
        
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct Attributes
            {
                float4 positionOS: POSITION;
                float3 normalOS: NORMAL;
                float4 tangentOS: TANGENT;
                float2 uv: TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float2 uv: TEXCOORD0;
                float3 lightDirTS: TEXCOORD1;
                float3 viewDirTS: TEXCOORD2;
                float4 positionCS: SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            CBUFFER_START(UnityPerMaterial)
            float4 _SpecularColor;
            float _Gloss;
            float _HeightScale;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);   SAMPLER(sampler_NormalMap);
            TEXTURE2D(_DepthMap);   SAMPLER(sampler_DepthMap);

            float2 ParallaxMapping(float2 uv, float3 viewDir_tangent)
            {
                float3 viewDir = normalize(viewDir_tangent);
                float height = SAMPLE_TEXTURE2D(_DepthMap, sampler_DepthMap, uv).r;
                //因为viewDir是在切线空间的（xy与uv对齐），所以只用xy偏移就行了
                float2 p = viewDir.xy * (height * _HeightScale); //_HeightScale用来调整高度（深度）
                return uv - p;
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInputs.positionCS;
                
                Light mainLight = GetMainLight();
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                float3x3 tbn = float3x3(normalInputs.tangentWS, normalInputs.bitangentWS, normalInputs.normalWS);
                output.lightDirTS = mul(tbn, mainLight.direction);
                output.viewDirTS = mul(tbn, GetCameraPositionWS() - vertexInputs.positionWS);

                output.uv = input.uv;
                
                return output;
            }
            
            half4 frag(Varyings input): SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 lightDirTS = normalize(input.lightDirTS);
                float3 viewDirTS = normalize(input.viewDirTS);

                float2 uv = ParallaxMapping(input.uv, viewDirTS);
                if (uv.x > 1.0 || uv.y > 1.0 || uv.x < 0.0 || uv.y < 0.0) //去掉边上的一些古怪的失真，在平面上工作得挺好的
                discard;
                
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                half4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv);
                float3 normalTS = UnpackNormal(packedNormal);
                
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo.rgb;
                
                Light mainLight = GetMainLight();
                half3 diffuseColor = mainLight.color * albedo.rgb * saturate(dot(normalTS, lightDirTS));

                half3 halfDir = normalize(viewDirTS + lightDirTS);
                half3 specularColor = mainLight.color * _SpecularColor.rgb * pow(saturate(dot(normalTS,halfDir)),_Gloss);
                
                half3 finalColor = albedo.rgb + diffuseColor + specularColor;
                
                return half4(finalColor, 1.0);
            }
            ENDHLSL
            
        }
    }
}
