// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Position Mirror"
{
	Properties
	{
	}
	SubShader
	{
		Tags 
		{
			"Queue"="Transparent+10"
			"RenderType"="Transparent"
		}
		LOD 100

		Pass
		{
			Blend One Zero
            Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			// based on https://gamedev.stackexchange.com/a/132845/41980

			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldDirection : TEXCOORD0;
				float4 screenPosition : TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;
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

			v2f vert (appdata v)
			{
				v2f o;
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// Save the clip space position so we can use it later.
				// but here I'm aiming for the simplest version I can.
				// Optimized versions welcome in additional answers!)
				o.screenPosition = o.vertex;
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / i.screenPosition.w;
				// Scale our view ray to unit depth.
				float3 direction = i.worldDirection * perspectiveDivide;
				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;
				#ifdef UNITY_UV_STARTS_AT_TOP
					screenUV.y = 1 - screenUV.y; 
				#endif
				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));
                // Advance by depth along our view ray from the camera position.
				// This is the worldspace coordinate of the corresponding fragment
				// we retrieved from the depth buffer.
				float3 worldSpacePosition = direction * depth + _WorldSpaceCameraPos;
                float3 cameraSpacePosition = computeCameraSpacePosFromDepthAndInvProjMat(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)), screenUV);
                float3 YworldSpacePosition = mul(unity_CameraToWorld, float4(cameraSpacePosition, 1.0)).xyz;
				// Draw a worldspace tartan pattern over the scene to demonstrate.
				return float4(fmod(.1*YworldSpacePosition, 1.0f), 1.0f);
			}

			ENDCG
		}
	}
}
