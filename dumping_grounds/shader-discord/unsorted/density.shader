Shader "Unlit/density"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Density("Density", float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="AlphaTest"}
		
		Pass
		{
		    Cull Front
		    ZWrite Off
		    ColorMask A
		    
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float depth : TEXCOORD1;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z *_ProjectionParams.w;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return i.depth;
			}
			ENDCG
		}
		
		GrabPass{"_DepthCapture"}
		
		Pass
		{
		    Cull Back
		    Blend One OneMinusSrcAlpha
		    ZWrite Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 screenPos : TEXCOORD1;
				float depth : TEXCOORD2;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _DepthCapture;
			sampler2D _CameraDepthTexture;
			float _Density;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.screenPos = ComputeGrabScreenPos(o.vertex);
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z *_ProjectionParams.w;
				return o;
			}
			
			float erf( float z )
            {
                float z2 = z*z;
                return 1.1283791670955125738961589031215 * z * (1.0 + z2 * ((-1.0/3.0) + z2 * ((1.0/10.0) + z2 * ((-1.0/42.0) + z2 * (1.0/216.0)))));
            }
			
			fixed4 frag (v2f i) : SV_Target
			{
			    float2 screenUv = i.screenPos.xy / i.screenPos.w;
				float capturedDepth = tex2D(_DepthCapture, screenUv).w;
				float sceneDepth = Linear01Depth(tex2D(_CameraDepthTexture, screenUv).r);
				float linearDepth = min(sceneDepth, capturedDepth);
				float dist = abs(linearDepth - i.depth) * _ProjectionParams.z;
				
				float density = saturate(erf(dist*_Density));
				
				float3 col = 0;
				col = lerp( col, float3(0.2,0.5,1.0), density );
                col = lerp( col, 1.15*float3(1.0,0.9,0.6), density*density*density );
				return float4(col, density);
			}
			ENDCG
		}
	}
}
