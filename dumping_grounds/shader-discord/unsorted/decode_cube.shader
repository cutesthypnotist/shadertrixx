Shader "Unlit/decode cube"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags{ "RenderType" = "Opaque" "Queue" = "Transparent+2" }

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
				float4 vertex : SV_POSITION;
			};

			sampler2D _AfterEncode;
			
			v2f vert (appdata v)
			{
				v2f o;
				float2 pixelSize = 1.0 / _ScreenParams.xy;
				float halfSize = (pixelSize.x / 2.0);
				float2 uv = float2(0,1);
				float4 worldPosX = tex2Dlod(_AfterEncode, float4(uv,0,0));
				uv = float2(pixelSize.x + halfSize, 1);
				float4 worldPosY = tex2Dlod(_AfterEncode, float4(uv, 0, 0));
				uv = float2(2*pixelSize.x + halfSize, 1);
				float4 worldPosZ = tex2Dlod(_AfterEncode, float4(uv, 0, 0));
				float3 worldPos = float3(RGBA8ToFloat32(worldPosX), RGBA8ToFloat32(worldPosY), RGBA8ToFloat32(worldPosZ));
				worldPos *= 4.02;//I don't know why this has to be here, but it does work tho
				o.vertex = UnityObjectToClipPos(v.vertex + mul(unity_WorldToObject, worldPos));
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = float4(1,0,0,1);
				return col;
			}
			ENDCG
		}
	}
}
