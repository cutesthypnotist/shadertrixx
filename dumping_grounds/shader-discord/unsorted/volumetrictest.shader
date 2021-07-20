Shader "VolumetricSphereDensity"
{
	Subshader
	{
		Tags { "Queue"="Transparent+4" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
		Cull Front
		Blend One One
		ZTest Always
		Lighting Off
		SeparateSpecular Off
		Fog { Mode Off }
		Pass
		{
			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma fragment pixel_shader
			#pragma target 5.0
			#pragma fragmentoption ARB_precision_hint_fastest

			#include "UnityCG.cginc"

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			float sphDensity( float3  ro, float3  rd, float3  sc, float sr, float dbuffer )
			{
				// normalize the problem to the canonical sphere
				float ndbuffer = dbuffer / sr;
				float3  rc = (ro - sc)/sr;
				
				// find intersection with sphere
				float b = dot(rd,rc);
				float c = dot(rc,rc) - 1.0;
				float h = b*b - c;

				// not intersecting
				if( h<0.0 ) return 0.0;
				
				h = sqrt( h );

				float t1 = -b - h;
				float t2 = -b + h;

				// not visible (behind camera or behind ndbuffer)
				if( t2<0.0 || t1>ndbuffer ) return 0.0;

				// clip integration segment from camera to ndbuffer
				t1 = max( t1, 0.0 );
				t2 = min( t2, ndbuffer );

				// analytical integration of an inverse squared density
				float i1 = -(c*t1 + b*t1*t1 + t1*t1*t1/3.0);
				float i2 = -(c*t2 + b*t2*t2 + t2*t2*t2/3.0);
				return (i2-i1)*(3.0/4.0);
			}

			fixed4 render(fixed3 baseWorldPos, fixed3 rd, in out float3 depthPosition) {
				const float zDepth = length(_WorldSpaceCameraPos-depthPosition);
				const float scale = length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x));
				float sum = sphDensity(_WorldSpaceCameraPos, rd, baseWorldPos, 0.5 * scale, zDepth);
				return sum;
			}

			struct custom_type
			{
				fixed4 screen_vertex : SV_POSITION;
				fixed3 world_vertex : TEXCOORD0;
				float4 scrPos : TEXCOORD1;
				float4 projPos : TEXCOORD2;
				float3 ray : TEXCOORD3;
			};

			custom_type vertex_shader (fixed4 vertex : POSITION)
			{
				custom_type vs;
				vs.screen_vertex = UnityObjectToClipPos(vertex);
				vs.world_vertex = mul(unity_ObjectToWorld, vertex);
				vs.scrPos = ComputeScreenPos(vs.screen_vertex);
				vs.ray = vs.world_vertex.xyz - _WorldSpaceCameraPos;
				float4 wvertex = mul(UNITY_MATRIX_VP, float4(vs.world_vertex, 1.0));
				vs.projPos = ComputeScreenPos (wvertex);
				vs.projPos.z = -mul(UNITY_MATRIX_V, float4(vs.world_vertex, 1.0)).z;
				return vs;
			}

			fixed4 pixel_shader(custom_type ps ) : SV_TARGET
			{
                fixed3 viewDirection = normalize(ps.world_vertex-_WorldSpaceCameraPos.xyz);

				fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;

				float sceneDepth = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(ps.projPos)));
				float3 depthPosition = sceneDepth * ps.ray / ps.projPos.z + _WorldSpaceCameraPos;

				fixed3 finalColor = saturate(render(baseWorldPos, viewDirection, depthPosition).xyz);
				return fixed4(finalColor, 1.0);
			}
			ENDCG
		}
	}
}