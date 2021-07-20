Shader "!M.O.O.N/ShaderToy/PSThingie"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}


			const float speed = 0.4;
			const float widthFactor = 1.0;

			float3 calcSine(float2 uv,
				float frequency, float amplitude, float shift, float offset,
				float3 color, float width, float exponent, bool dir)
			{
				float angle = _Time.y * speed * frequency + (shift + uv.x) * 0.75;

				float y = sin(angle) * amplitude + offset;
				float clampY = clamp(0.0, y, y);
				float diffY = y - uv.y;

				float dsqr = distance(y, uv.y);
				float scale = 1.0;

				if (dir && diffY > 0.0)
				{
					dsqr = dsqr * 4.0;
				}
				else if (!dir && diffY < 0.0)
				{
					dsqr = dsqr * 4.0;
				}

				scale = pow(smoothstep(width * widthFactor, 0.0, dsqr), exponent);

				return min(color * scale, color);
			}


			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float3 color = 0;

				float t1 = (sin(_Time.y / 20.0) / 3.14) + 0.2;
				float t2 = (sin(_Time.y / 10.0) / 3.14) + 0.2;

				color += calcSine(uv, 0.20, 0.2, 0.0, 0.5, float3(0.5, 0.5, 0.5), 0.1, 15.0, false);
				color += calcSine(uv, 0.40, 0.15, 0.0, 0.5, float3(0.5, 0.5, 0.5), 0.1, 17.0, false);
				color += calcSine(uv, 0.60, 0.15, 0.0, 0.5, float3(0.5, 0.5, 0.5), 0.05, 23.0, false);

				color += calcSine(uv, 0.26, 0.07, 0.0, 0.3, float3(0.5, 0.5, 0.5), 0.1, 17.0, true);
				color += calcSine(uv, 0.46, 0.07, 0.0, 0.3, float3(0.5, 0.5, 0.5), 0.05, 23.0, true);
				color += calcSine(uv, 0.58, 0.05, 0.0, 0.3, float3(0.5, 0.5, 0.5), 0.2, 15.0, true);

				color.x += t1 * (1.0 - uv.y);
				color.y += t2 * (1.0 - uv.y);

				return float4(color, 1.0);
			}
			ENDCG
		}
	}
}
