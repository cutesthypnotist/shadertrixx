Shader "Unlit/encode vert pos"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"= "Transparent+1"}
		ZWrite Off
		ZTest Always
		GrabPass{"_BeforeEncode"}//Grab unedited
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "packing.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 screenPos : TEXCOORD0;
				float3 centerPos : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = v.vertex * float4(2, 2, 1, 1);
				o.screenPos = ComputeGrabScreenPos(o.vertex);
				o.centerPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float4 col = 0;
				float2 uv = i.screenPos.xy / i.screenPos.w;

				int modX = floor(fmod(_ScreenParams.x*uv.x, 3));
				modX += 0;
				int xPixel = _ScreenParams.x*uv.x;
				int yPixel = _ScreenParams.y*(1-uv.y);//Flip to be at top of screen
				if (xPixel > 2 || yPixel > 0)
					discard;

				float3 encodedPos = i.centerPos.xyz;

				if (modX == 0)
				{
					col = float32ToRGBA8(encodedPos.x);
				}
				else if (modX == 1)
				{
					col = float32ToRGBA8(encodedPos.y);
				}
				else if (modX == 2)
				{
					col = float32ToRGBA8(encodedPos.z);
				}

				return col;
			}
			ENDCG
		}

		GrabPass{ "_AfterEncode"}//Grab encoded data
	}
}
