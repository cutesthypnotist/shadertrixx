// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Bender's Shaders/Geometry/Wire Outline"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Noise ("Noise", 2D) = "white" {}
		[HDR] _Color ("HDRColor", Color) = (1,1,1,1)
		_colorstr ("Color Strength", Range (0,1)) = 0
		_TriMin ("Scroll Speed", Range (0,1)) = 0
		_LineSize ("Mesh Scale", Range (0,1)) = 0
		_fullness ("Motion Speed", Range (0,1)) = 0
		_OffSet ("Wireframe Scale", Range (0,1)) = 0
		_speed ("Noise Scroll Speed", Range (0,1)) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" }
		ZTest Lequal
		Blend One One
		LOD 100
		cull off

		Pass
		{
			CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"


            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
				float2 noise : TEXCOORD1;
				float3 norm : NORMAL;
            };

            struct v2g
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
				float3 norm : NORMAL;
				float2 noise : TEXCOORD1;
            };

            struct g2f{
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex, _Noise;
            float4 _MainTex_ST, _Noise_ST;
			float4 _Color;
			uniform float _colorstr;
			uniform float _TriMin, _LineSize, _OffSet, _fullness, _speed;

            v2g vert (appdata v)
            {
                v2g o;
                o.pos = v.pos;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.noise = TRANSFORM_TEX(v.uv, _Noise);
				o.norm = v.norm;
                return o;
            }

            [maxvertexcount(4)]
            void geom(triangle v2g input[3], inout LineStream<g2f> tristream){
                g2f o;
				float4 b = ((input[0].pos + input[1].pos + input[2].pos + input[0].pos)/4);
				float noisetex = tex2Dlod(_Noise, float4( input[0].uv + ((_SinTime.x * _speed)), 0, 0).r);
				float noisemod = lerp(0, _fullness, noisetex);
				float pos = clamp(frac(_Time.x*(noisemod*4.0))*_OffSet - 0, 0,1);

				//FIRST VERTEX
                o.uv = input[0].uv;
                o.pos = UnityObjectToClipPos((b+(input[0].pos-b))*(_LineSize) + (input[0].norm*pos));

                tristream.Append(o);

                o.uv = input[1].uv;
                o.pos = UnityObjectToClipPos((b+(input[1].pos-b))*(_LineSize) + (input[1].norm*pos));

                tristream.Append(o);

                o.uv = input[2].uv;
                o.pos = UnityObjectToClipPos((b+(input[2].pos-b))*(_LineSize) + (input[2].norm*pos));

                tristream.Append(o);

                o.uv = input[0].uv;
                o.pos = UnityObjectToClipPos((b+(input[0].pos-b))*(_LineSize) + (input[0].norm*pos));

                tristream.Append(o);

				tristream.RestartStrip();

            }

            fixed4 frag (g2f i) : SV_Target
            {
			float2 scroll = i.uv + (_Time.x*_TriMin);
			float p = (i.pos.y * 1.0);
			float4 col = _Color * _colorstr;
			float4 tex = tex2D(_MainTex, scroll);
			float4 tex1 = tex * col;
                return tex1;
            }
ENDCG
		}
	}
}
