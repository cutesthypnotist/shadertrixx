// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Sphere Density Test"
{
	Properties
	{
		[HDR]_Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0) 
		_Radius ("Radius", Float) = 1.0
	}
	SubShader
	{
		LOD 100
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
    	Blend SrcAlpha One
    	ColorMask RGB
		Cull Off Lighting Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

            struct appdata_t {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 projPos : TEXCOORD2;
				float4 posWorld : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

			float4 _Color;
			float _Radius;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.projPos = ComputeScreenPos (o.vertex);
                COMPUTE_EYEDEPTH(o.projPos.z);
                o.color = v.color * _Color;
                o.texcoord = (v.texcoord);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

			float computeFog( float3  ro, float3  rd,   // ray origin, ray direction
			                  float3  sc, float sr,   // sphere center, sphere radius
			                  float dbuffer )
			{
			    // normalize the problem to the canonical sphere
			    float ndbuffer = dbuffer / sr;
			    float3  rc = (ro - sc)/sr;
				
			    // find intersection with sphere
			    float b = dot(rd,rc);
			    float c = dot(rc,rc) - 1.0f;
			    float h = b*b - c;

			    // not intersecting
			    if( h<0.0f ) return 0.0f;
				
			    h = sqrt( h );
			    float t1 = -b - h;
			    float t2 = -b + h;

			    // not visible (behind camera or behind ndbuffer)
			    if( t2<0.0f || t1>ndbuffer ) return 0.0f;

			    // clip integration segment from camera to ndbuffer
			    t1 = max( t1, 0.0f );
			    t2 = min( t2, ndbuffer );

			    // analytical integration of an inverse squared density
			    float i1 = -(c*t1 + b*t1*t1 + t1*t1*t1/3.0f);
			    float i2 = -(c*t2 + b*t2*t2 + t2*t2*t2/3.0f);
			    return (i2-i1)*(3.0f/4.0f);
			}

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldPos = mul(unity_ObjectToWorld, i.vertex);
				float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				float worldOrigin = mul(unity_ObjectToWorld, float4(0,0,0,1));
				//
				float sceneZ = Linear01Depth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				// ray origin, ray direction
				// sphere center, sphere radius
				// depth
				fixed4 col = computeFog(_WorldSpaceCameraPos, viewDirection,
				worldOrigin, _Radius,
				(sceneZ));
				// col *= i.color;
				// apply fog
                UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0,0,0,0)); // fog towards black due to our blend mode
				return sceneZ;
			}
			ENDCG
		}
	}
}
