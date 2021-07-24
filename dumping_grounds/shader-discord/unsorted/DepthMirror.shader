Shader "LyumaShader/DepthMirror"
{
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
        _ParameterTex("ParameterTex", 2D) = "black"
		[HideInInspector] _ReflectionTex0("", 2D) = "white" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "white" {}
	}
	SubShader
	{
		Tags{ "RenderType" = "Opaque" "Queue" = "Geometry-1" }
		LOD 100

		Pass
		{
            AlphaToMask On 
            Cull Back
            ZWrite On
            ZTest Always
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityStandardCore.cginc"

			sampler2D _ReflectionTex0;
			sampler2D _ReflectionTex1;
            sampler2D _ParameterTex;

            sampler2D _CameraDepthTexture;
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 refl : TEXCOORD1;
                float4 params : TEXCOORD2;
                float4 worldPos : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float3 worldNormal : TEXCOORD5;
				float4 pos : SV_POSITION;
			};

			v2f vert(VertexInput v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
                o.screenPos = o.pos;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
				o.refl = ComputeNonStereoScreenPos(o.pos);
                o.params = tex2Dlod(_ParameterTex, float4(0, 0, 0, 0));
                o.worldNormal = UnityObjectToWorldNormal(float3(0,0,1));
				return o;
			}

            // Inverse of LinearEyeDepth()
            inline float LinearEyeDepthToOutDepth(float z)
            {
                return (1 - _ZBufferParams.w * z) / (_ZBufferParams.z * z);
            }
			float4 frag(v2f i, out float out_svdepth : SV_Depth) : SV_Target
			{
                float cameraDist = (i.worldPos - _WorldSpaceCameraPos);
                float3 reflectedCameraPos = i.worldPos + reflect(_WorldSpaceCameraPos - i.worldPos, i.worldNormal);
                float3 refCX = reflect(unity_CameraToWorld._11_21_31, i.worldNormal);
                float3 refCY = reflect(unity_CameraToWorld._12_22_32, i.worldNormal);
                float3 refCZ = reflect(unity_CameraToWorld._13_23_33, i.worldNormal);
                float4x4 reflectedCameraToWorld = float4x4(
                    refCX.x, refCY.x, refCZ.x, reflectedCameraPos.x,
                    refCX.y, refCY.y, refCZ.y, reflectedCameraPos.y,
                    refCX.z, refCY.z, refCZ.z, reflectedCameraPos.z,
                    0, 0, 0, 1);
                float _Opacity = saturate(i.params.r*1.2);
                float _DepthDisplay = i.params.g;
                float _DepthOutput = i.params.b;
				float4 tex = tex2D(_MainTex, i.uv);
				float4 refl = unity_StereoEyeIndex == 0 ? tex2Dproj(_ReflectionTex0, UNITY_PROJ_COORD(i.refl)) : tex2Dproj(_ReflectionTex1, UNITY_PROJ_COORD(i.refl));
                float depthWorldSpace = (0+refl.a);
                float2 screenUV = (i.screenPos.xy / i.screenPos.w) * 0.5f + 0.5f;
                #ifdef UNITY_UV_STARTS_AT_TOP
                    screenUV.y = 1 - screenUV.y; 
                #endif
                // VR stereo support
                screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
                float4 viewSpace = float4(
                    (i.screenPos.x / i.screenPos.w - unity_CameraProjection._13 * depthWorldSpace) / unity_CameraProjection._11,
                    (i.screenPos.y / i.screenPos.w - unity_CameraProjection._23 * depthWorldSpace) / unity_CameraProjection._22,
                    depthWorldSpace,
                    1.0);
                float4 worldSpacePosFinal = mul(reflectedCameraToWorld, viewSpace);
                float3 reflectedWorldSpacePos = i.worldPos.xyz + reflect(worldSpacePosFinal.xyz - i.worldPos.xyz, i.worldNormal.xyz);
                depthWorldSpace = mul(unity_WorldToCamera, float4(reflectedWorldSpacePos, 1.0)).z;
                out_svdepth = lerp(i.pos.z, LinearEyeDepthToOutDepth(depthWorldSpace), _DepthOutput);
                return float4(lerp((tex * refl).rgb, float3(saturate(depthWorldSpace.x*.1), frac(depthWorldSpace.x*.01), 0), _DepthDisplay), _Opacity);
			}
			ENDCG
		}
	}
}
