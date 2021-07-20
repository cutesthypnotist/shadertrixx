// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Distance Fade Cube Volume"
{
	Properties
	{
		[HDR] _Color("Color", Color) = (0,0,0,1)
	}
		SubShader
	{
		Tags
		{
			"Queue" = "Transparent+1000"
			"RenderType" = "Transparent"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		Cull Back
		ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float4 _Color;

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 depthTextureUv : TEXCOORD1;
				float4 rayToCamera : TEXCOORD2;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			// Dj Lukis.LT's oblique view frustum correction (VRChat mirrors use such view frustum)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			#define UMP UNITY_MATRIX_P
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			#undef UMP

			v2f vert(appdata v)
			{
				float4 worldPosition = mul(UNITY_MATRIX_M, v.vertex);
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.depthTextureUv = ComputeGrabScreenPos(o.vertex);
				o.rayToCamera.xyz = worldPosition.xyz - _WorldSpaceCameraPos.xyz;
				o.rayToCamera.w = dot(o.vertex, ObliqueFrustumCorrection); // oblique frustrum correction factor
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float perspectiveDivide = 1.f / i.vertex.w;
				float4 rayToCamera = i.rayToCamera * perspectiveDivide;
				float2 depthTextureUv = i.depthTextureUv.xy * perspectiveDivide;

				float sceneZ = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, depthTextureUv);

				#if UNITY_REVERSED_Z
				if (sceneZ == 0.f) {
				#else
				if (sceneZ == 1.f) {
				#endif
					// this is skybox, depth texture has default value
					return float4(0.f, 0.f, 0.f, 1.f);
				}

				// linearize depth and use it to calculate background world position
				float sceneDepth = CorrectedLinearEyeDepth(sceneZ, rayToCamera.w);

				float3 worldPosition = rayToCamera.xyz * sceneDepth + _WorldSpaceCameraPos.xyz;
				float4 localPosition = mul(unity_WorldToObject, float4(worldPosition, 1));
				localPosition.xyz /= localPosition.w;

				float fade = abs(localPosition.z - 0.5);

				float4 color = _Color;
				color *= fade;
				return color;
			}

			ENDCG
		}
	}
	}