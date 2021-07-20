Shader "Unlit/CheapTriplanar"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Pow("Pow", float) = 160
		_Contrast("_Contrast", float) = 512
		_UvMult("_UvMult", float) = 64
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 objPos : TEXCOORD1;
				float3 tangentForward : TEXCOORD3;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Pow;
			float _Contrast;
			float _UvMult;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.objPos = v.vertex;

				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				fixed3 worldBinormal = cross(worldNormal, worldTangent);

				float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
					worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
					worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
					0.0, 0.0, 0.0, 1.0);

				o.tangentForward = mul(tangentToWorld,float4(0, 0, 1, 0)).xyz;
				o.tangentForward = mul(unity_WorldToObject, o.tangentForward);
				return o;
			}

			float3 CheapContrast_RGB(float3 color, float contrast)
			{
				return saturate(lerp(-contrast, contrast + 1, color));
			}


			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 pos = i.objPos / 1024;

				float3 dir = pow(abs(i.tangentForward), _Pow);
				dir /= dot(dir, 1);
				dir = CheapContrast_RGB(dir, _Contrast).rgb;

				float2 uvs = pos.rg * dir.z + pos.gb * dir.x + pos.rb * dir.y;
				fixed4 col = tex2D(_MainTex, uvs*4*_UvMult);
				return col;
			}
			ENDCG
		}
	}
}
