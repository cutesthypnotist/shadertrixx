// original shader by error.mdl
// modified by Neitri
// free of charge, free to redistribute

Shader "Unlit/Distance Field Depth Write Infinite Spheres"
{
	Properties
	{
	}
	SubShader
	{
		Pass 
		{
			Cull Back
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 posWorld : TEXCOORD0;
			};
			
			struct fragOut 
			{
				float4 color : SV_Target;
				float depth : SV_Depth;
			};
			
			float signedDistanceField (float3 pos)
			{
				pos += 100;
				#define SPHERE_RADIUS 0.3
				#define SPHERE_REPETITION 0.8
				pos = fmod(pos, SPHERE_REPETITION) - 0.5*SPHERE_REPETITION;
				return length(pos) - SPHERE_RADIUS;
			}			
			void raymarch (float3 rayStart, float3 rayDir, out float4 color, out float clipDepth)
			{
				color = float4(0,0,0,0);
				int maxSteps = 40;
				float minDistance = 0.001;
				float3 currentPos = rayStart;
				for (int i = 0; i < maxSteps; i++)
				{
					float distance = signedDistanceField(currentPos);
					currentPos += rayDir * distance;
					if (distance < minDistance)
					{
						color = float4((maxSteps-i)*0.025, (maxSteps-i)*0.025, (maxSteps-i)*0.025, 1);
						break;
					}
				}
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(currentPos, 1.0));
				clipDepth = clipPos.z / clipPos.w;
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}
			
			fragOut frag (v2f i)
			{
				float3 rayStart = i.posWorld.xyz;;
				float3 rayDir = normalize(rayStart - _WorldSpaceCameraPos);
				float4 rayColor;
				float clipDepth;
				raymarch(rayStart, rayDir, rayColor, clipDepth);

				fragOut f;
				f.depth = clipDepth;
				f.color = rayColor;
				return f;
			}
			ENDCG
		}
	}
}