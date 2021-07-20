Shader "_Radial Blur Ball"
{
	Properties
	{
		[HDR]_Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0) 
		[Gamma]_Distortion("Distortion", Float) = 0.1
		[Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 0
	}
	Subshader
	{
		Tags { "Queue"="Transparent+4" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
		LOD 100
		Cull[_CullMode]
		GrabPass{ }
		Blend One One
		ZWrite Off ZTest Always
		Lighting Off
		SeparateSpecular Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma fragment pixel_shader
			#pragma target 5.0
            #pragma multi_compile_instancing
			#pragma multi_compile_fog    
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma instancing_options assumeuniformscaling 

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

			// @param Pos screen position from SV_Position which is pixel centered meaning +0.5
			// @param FrameIndexMod4 0..3 can be computed on CPU
			// @return 0 (included) .. 1 (excluded), 17 values/shades
			float Dither17(float2 Pos, float FrameIndexMod4)
			{
			    // 3 scalar float ALU (1 mul, 2 mad, 1 frac)
			    return frac(dot(float3(Pos.xy, FrameIndexMod4), uint3(2, 7, 23) / 17.0f));
			}

			float hash( const in float3 p ) {
                return frac(sin(dot(p,fixed3(127.1,311.7,758.5453123)))*43758.5453123);
            }

			float T(float z) {
			    return z >= 0.5 ? 2.-2.*z : 2.*z;
			}

			// R dither mask
			float intensity(float2 pixel) {
			    const float a1 = 0.75487766624669276;
			    const float a2 = 0.569840290998;
			    return frac(a1 * float(pixel.x) + a2 * float(pixel.y));
			}

			float rDither(float gray, float2 pos) {
				#define steps 8
				// pos is screen pixel position in 0-res range
			    // Calculated noised gray value
			    float noised = (2./steps) * T(intensity(float2(pos.xy))) + gray - (1./steps);
			    // Clamp to the number of gray levels we want
			    return floor(steps * noised) / (steps-1.);
			    #undef steps
			}

			fixed render(fixed3 baseWorldPos, fixed3 rd, in out float3 depthPosition) {
				const float zDepth = length(_WorldSpaceCameraPos-depthPosition);
				const float scale = length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x));
				float sum = sphDensity(_WorldSpaceCameraPos, rd, baseWorldPos, 0.5 * scale, zDepth);
				return sum;
			}

            struct appdata_t {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                float4 vertex : POSITION;
                fixed4 color : COLOR;
            };

			struct v2f
			{
                UNITY_VERTEX_INPUT_INSTANCE_ID 
				fixed4 screen_vertex : SV_POSITION;
				fixed3 world_vertex : TEXCOORD0;
				float4 grabPos : TEXCOORD1;
				float4 projPos : TEXCOORD2;
				float3 ray : TEXCOORD3;
                UNITY_FOG_COORDS(4)
                float4 uv_centre : TEXCOORD5;
                fixed4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
			};

			float4 _Color;
			float _Distortion;
			uniform sampler2D _GrabTexture;

			v2f vertex_shader (appdata_t v)
			{
				v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.screen_vertex = UnityObjectToClipPos(v.vertex);
				o.world_vertex = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.grabPos = ComputeGrabScreenPos(o.screen_vertex);
				o.ray = o.world_vertex.xyz - _WorldSpaceCameraPos;
				float4 wvertex = mul(UNITY_MATRIX_VP, float4(o.world_vertex, 1.0));
				o.projPos = ComputeScreenPos (wvertex);
				o.projPos.z = -mul(UNITY_MATRIX_V, float4(o.world_vertex, 1.0)).z;
				o.color = v.color * _Color;
				o.uv_centre = ComputeGrabScreenPos(UnityObjectToClipPos(float4(0, 0, 0, 1)));
                UNITY_TRANSFER_FOG(o,o.screen_vertex);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				return o;
			}

			fixed4 pixel_shader(v2f ps) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(ps);
				#define NUM_SAMPLES 8.0

				// Sphere radius 
                fixed3 viewDirection = normalize(ps.world_vertex-_WorldSpaceCameraPos.xyz);

				fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;

				float sceneDepth = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(ps.projPos)));
				float3 depthPosition = sceneDepth * ps.ray / ps.projPos.z + _WorldSpaceCameraPos;

				half radius = render(baseWorldPos, viewDirection, depthPosition);

				// Radial blur 
				float4 screenPos = float4( ps.grabPos.xyz , ps.grabPos.w + 0.00000000001 );

				float2 pointDist = screenPos-ps.uv_centre-0.5;

				float2 dither = float2(
					T(intensity(ps.screen_vertex.xy)), 
					T(intensity(ps.screen_vertex.xy+0.5)));

				pointDist *= 1.0 / float(NUM_SAMPLES) * _Distortion * dither;

				float3 finalColor = -tex2Dproj( _GrabTexture, UNITY_PROJ_COORD( screenPos ) ) * radius;

				for ( float i=1; i<NUM_SAMPLES+1; i++) {				
				screenPos.xy -= pointDist * 1.0 / NUM_SAMPLES;
				finalColor += tex2Dproj( _GrabTexture, UNITY_PROJ_COORD( ps.uv_centre+screenPos ) ) * radius;
				}
				finalColor *= 1.0/float(NUM_SAMPLES);

                UNITY_APPLY_FOG_COLOR(ps.fogCoord, finalColor, fixed4(0,0,0,0)); // fog towards black due to our blend mode
				return fixed4(finalColor, 1.0);
			}
			ENDCG
		}
	}
}