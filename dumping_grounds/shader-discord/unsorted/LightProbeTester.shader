Shader "Unlit/LightProbeTester"
{
	Properties
	{
		//_MainTex ("Texture", 2D) = "white" {}
		[Toggle(_)]_NonLinearSH("Non-Linear SH", Int) = 0
		[Toggle(_)]_OnlyClampSH("Clamp SH", Int) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode"="ForwardBase"}
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase_fullshadows
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 worldNormal : TEXCOORD2;
			};

			int _NonLinearSH;
			int _OnlyClampSH;
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			float shEvaluateDiffuseL1Geomerics(float L0, float3 L1, float3 n)
			{
				// average energy
				float R0 = L0;

				// avg direction of incoming light
				float3 R1 = 0.5f * L1;

				// directional brightness
				float lenR1 = length(R1);

				// linear angle between normal and direction 0-1
				//float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
				//float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
				float q = dot(normalize(R1), n) * 0.5 + 0.5;

				// power for q
				// lerps from 1 (linear) to 3 (cubic) based on directionality
				float p = 1.0f + 2.0f * lenR1 / R0;

				// dynamic range constant
				// should vary between 4 (highly directional) and 0 (ambient)
				float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

				return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
			}

			fixed4 frag (v2f i) : SV_Target
			{		
				float3 indirect;
				if(_NonLinearSH == 1)
				{
					if(_OnlyClampSH)
					{
						indirect = max(0, ShadeSH9(float4(i.worldNormal, 1)));
					}
					else
					{
						float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
						indirect.r = shEvaluateDiffuseL1Geomerics(L0.r, unity_SHAr.xyz, i.worldNormal);
						indirect.g = shEvaluateDiffuseL1Geomerics(L0.g, unity_SHAg.xyz, i.worldNormal);
						indirect.b = shEvaluateDiffuseL1Geomerics(L0.b, unity_SHAb.xyz, i.worldNormal);
					}
				}
				else
				{
					indirect = ShadeSH9(float4(i.worldNormal, 1));
				}

				return indirect.xyzz;
			}
			ENDCG
		}
	}
}
