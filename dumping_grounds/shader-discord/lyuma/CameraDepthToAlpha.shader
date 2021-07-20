Shader "LyumaShader/CameraDepthToAlpha" 
{
	Properties
	{
        // Shader properties
		_Color ("Main Color", Color) = (1,1,1,1)
	}
	SubShader
	{
        Tags { "Queue"="Overlay" "RenderType"="Opaque" "IgnoreProjector"="True"}
        // Shader code
        Cull Off
        ZWrite Off
        ZTest Always
        ColorMask A
        Blend One Zero, One Zero
		Pass
        {
            CGPROGRAM
            #pragma fragment frag
            #pragma vertex vert
            #include "UnityCG.cginc"

            sampler2D _CameraDepthTexture;

            struct v2f {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float4 worldPos : TEXCOORD1;
            };

#ifdef USING_STEREO_MATRICES
static bool isInMirror = 0;
#else
static bool isInMirror = (unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f);
#endif
            v2f vert(in float3 pos : POSITION) {
                v2f o;
                o.worldPos = mul(unity_CameraToWorld, float4(pos.xy * 100, 10, 1));
                o.screenPos = UnityWorldToClipPos(o.worldPos);
                o.pos = o.screenPos;
                if (!isInMirror) {
                    o.pos = float4(1,1,1,1);
                }
                return o;
            }

            static float4x4 projMat = UNITY_MATRIX_P;
            // Inspired by Internal_ScreenSpaceeShadow implementation.
            float3 computeCameraSpacePosFromDepthAndInvProjMat(float zdepth, float2 screenUV) {
                #if defined(UNITY_REVERSED_Z)
                    zdepth = 1 - zdepth;
                #endif
                float4 clipPos = float4(screenUV.xy, zdepth, 1.0);
                clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
                float4 camPos = mul(unity_CameraInvProjection, clipPos);
                camPos.xyz /= camPos.w;
                camPos.z *= -1;
                return camPos.xyz;
            }

            float4 frag(in v2f o) : SV_Target {

                float2 screenUV = (o.screenPos.xy / o.screenPos.w) * 0.5f + 0.5f;
                #ifdef UNITY_UV_STARTS_AT_TOP
                    screenUV.y = 1 - screenUV.y;
                #endif
                screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
                // Read depth, linearizing into worldspace units.    
                float sampledDepth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV));
                float3 viewSpacePosition = computeCameraSpacePosFromDepthAndInvProjMat(sampledDepth, screenUV);
                return float4(viewSpacePosition.xyy, viewSpacePosition.z);
            }
            ENDCG
		}
	} 
}
