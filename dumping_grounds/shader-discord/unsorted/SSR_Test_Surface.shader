Shader "SSR/SSR Example (Surface Shader)" {
	Properties {
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Metallic ("Metallic (R) Smoothness (A)", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}
		
		   [Header(Screen Space Reflection Settings)] 
		_SSRTex ("SSR mask", 2D) = "white" {}
		_NoiseTex("Noise Texture", 2D) = "black" {}
		[Toggle] _dith("Low Res", int) = 0
		_alpha("Reflection Strength", Range(0.0, 1.0)) = 1
		_rtint("Reflection Tint Strength", Range(0.0, 1.0)) = 0
		_blur("Blur (does ^2 texture samples!)", Float) = 8
		_MaxSteps ("Max Steps", Int) = 100
		_step("Ray step size", Float) = 0.09 
		_lrad("Large ray intersection radius", Float) = 0.2
		_srad("Small ray intersection radius", Float) = 0.02
		_edgeFade("Edge Fade", Range(0,1)) = 0.1
	}
	SubShader {
		Tags { "RenderType"="Opaque"  "Queue" = "Alphatest"}
		LOD 200
		
		GrabPass
		{
			"_GrabTextureSSR"
		}

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};

		sampler2D _Metallic;
		sampler2D _BumpMap;


		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			float4 metGloss = tex2D ( _Metallic,  IN.uv_MainTex);
			o.Metallic = metGloss.r;
			o.Normal = UnpackNormal (tex2D (_BumpMap, IN.uv_BumpMap));
			o.Smoothness = metGloss.a;
			o.Alpha = c.a;
		}
		ENDCG
		
	//----------------------------------------------------------------------------------------------	
	//
	//
	// SCREEN SPACE REFLECTIONS
	//
	//
	//----------------------------------------------------------------------------------------------
	
		
	
		
		Pass
		{
			
			//Blend One One
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
		
			#include "UnityCG.cginc"
			#include "SSR.cginc"
		
			struct VertIn
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
		
			struct VertOut
			{
				float4 vertex : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float2 uv1 : TEXCOORD2;
				float4 wPos : TEXCOORD4;
				half3 faceNormal : TEXCOORD5;
				half3 tspace0 : TEXCOORD6;
				half3 tspace1 : TEXCOORD7;
				half3 tspace2 : TEXCOORD8;
				
				//	 float2 uv3: TEXCOORD9;
			};
		
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D  _BumpMap;
			half4  _BumpMap_ST;
			sampler2D _Metallic;
					
			VertOut vert(VertIn v, float3 normal : NORMAL, float4 tangent : TANGENT)
			{
				VertOut o;
				
				/*
				* Collapse the mesh to a point if the camera rendering this is a mirror.
				* There's no point in rendering in VRC's mirrors as they don't have the
				* depth texture necessary to raymarch against, and rendering the effect
				* twice more (two extra cameras in the mirror) is extremely expensive
				*/
				
				UNITY_BRANCH if (!IsInMirror())
				{
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.uv = ComputeGrabScreenPos(o.vertex);
					o.wPos = mul(unity_ObjectToWorld, v.vertex);
					half3 wNormal = normalize(UnityObjectToWorldNormal(normal));
					
					// simple world space normal, unaffected by normal maps.
					o.faceNormal = wNormal;
					
					// Tangent info for calculating world-space normals from a normal map
					half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
					half tangentSign = tangent.w * unity_WorldTransformParams.w;
					half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
					
					o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
					o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
					o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
					
					
					o.uv0 = TRANSFORM_TEX(v.uv, _MainTex);
					o.uv1 = TRANSFORM_TEX(v.uv, _BumpMap);
					return o;
				
				} else {
					o.vertex = float4(0,0,0,0);
					o.uv = float4(0,0,0,0);
					o.uv0 = float2(0,0);
					o.wPos = float4(0,0,0,0);
					o.faceNormal = half3(0,0,0);
					o.tspace0 = half3(0,0,0);
					o.tspace1 = half3(0,0,0);
					o.tspace2 = half3(0,0,0);
					return o;
				}
			}
		
			sampler2D _SSRTex;
			sampler2D _NoiseTex;
			float4 _NoiseTex_TexelSize;
			int _dith;
			float _alpha;
			float _blur;
			
			float _edgeFade;
			half _rtint;
			half _lrad;
			half _srad;
			float _step;
			int _MaxSteps;
			
			sampler2D _GrabTextureSSR;
			float4 _GrabTextureSSR_TexelSize;
			
			
			
			float3 rgb2hsv(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
				float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
		
				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}
		
			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}
					
//--------------------------------------------------------------------------------------------------------------
		
			half4 frag(VertOut i) : SV_Target
			{
				/*
				 * We can't use unity's screen params variable as it is actually wrong
				 * in VR (for some reason the width is smaller by some amount than the
				 * true width. However, we're taking a grabpass and the dimensions of
				 * that texture are the true screen dimensions.
				 */
				#define scrnParams _GrabTextureSSR_TexelSize.zw
				
				half3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv1));
				float4 metallic = tex2D(_Metallic, i.uv0);
				float smoothness = metallic.a;
				float4 albedo = tex2D(_MainTex, i.uv0);
				
				// Mask for defining what areas can have SSR
				float mask = tex2D(_SSRTex, i.uv0).r;
				
				// Get the world-space normal direction from the normal map
				half3 wNormal;
				wNormal.x = dot(i.tspace0, tnormal);
				wNormal.y = dot(i.tspace1, tnormal);
				wNormal.z = dot(i.tspace2, tnormal);
				
				return getSSRColor(
									i.wPos,
									wNormal,
									i.faceNormal,
									_lrad,
									_srad,
									_step,
									_blur,
									_MaxSteps,
									_dith,
									smoothness,
									_edgeFade,
									_GrabTextureSSR_TexelSize.zw,
									_GrabTextureSSR,
									_NoiseTex,
									_NoiseTex_TexelSize.zw,
									albedo,
									metallic.r,
									_rtint,
									mask,
									_alpha
									);
				
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
