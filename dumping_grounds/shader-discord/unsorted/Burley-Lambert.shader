Shader "Unlit/Burley-Lambert"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		[Toggle]_Lambert("Lambert Toggle", Int) = 0
	}
	SubShader
	{

		Pass
		{
			Tags { "RenderType"="Opaque" "LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "UnityPBSLighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 worldNormal : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			int _Lambert;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			float OrenNayar( in float3 l, in float3 n, in float3 v, float r )
			{
				
				float r2 = r*r;
				float a = 1.0 - 0.5*(r2/(r2+0.57));
				float b = 0.45*(r2/(r2+0.09));

				float nl = dot(n, l);
				float nv = dot(n, v);

				float ga = dot(v-n*nv,n-n*nl);

				return max(0.0,nl) * (a + b*max(0.0,ga) * sqrt((1.0-nv*nv)*(1.0-nl*nl)) / max(nl, nv));
			}

			// float3 F_Schlick(const float3 f0, float VoH) {
			// 	// Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
			// 	return f0 + (float3(1.0) - f0) * pow5(1.0 - VoH);
			// }

			float Burley(float3 V, float3 L, float3 N, float r) {
				r *= r;
				
				float3 H = normalize(V + L);
				
				float NdotL = clamp(dot(N, L),0.,1.);
				float LdotH = clamp(dot(L, H),0.,1.);
				float NdotV = clamp(dot(N, V),0.,1.);

				float energyFactor = -r * .337748344 + 1.;
				float f90 = 2. * r * (LdotH*LdotH + .25) - 1.;

				float lightScatter = f90 * pow(1.-NdotL,5.) + 1.;
				float viewScatter  = f90 * pow(1.-NdotV,5.) + 1.;
				
				return NdotL * energyFactor * lightScatter * viewScatter;

			}

			float Lambert( in float3 l, in float3 n)
			{
				return saturate(dot(l,n));
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos); 
				float3 halfvec = normalize(_WorldSpaceLightPos0 + viewDir);

				float3 diffuseLight = Burley(viewDir, _WorldSpaceLightPos0, i.worldNormal, 0) * _LightColor0;
				float3 indirect = ShadeSH9(float4(normalize(i.worldNormal.xyz), 1));
				float3 lambert = Lambert(_WorldSpaceLightPos0, normalize(i.worldNormal)) * _LightColor0;

				if(_Lambert != 1)
					return col * (diffuseLight.xyzz + indirect.xyzz);
				else
					return col * (lambert.xyzz + indirect.xyzz);
			}
			ENDCG
		}
	}
}
