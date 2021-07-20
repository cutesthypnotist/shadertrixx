Shader "Unlit/RandomFractal"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Creal("Creal",Range(-5,5)) = 0
		_Cimag("Cimg",Range(-5,5)) = 0
		_Zoom("Zoom", Float) = 1

	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog

				#include "UnityCG.cginc"

				uniform float _Creal,_Cimag,_Zoom;

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
			
			fixed4 frag (v2f i) : SV_Target
			{

				float2 uv = (i.uv-.5) - float2(_MainTex_ST.z,_MainTex_ST.w) * float2(_MainTex_ST.x,_MainTex_ST.y) * _Zoom;

				float real = uv.x - .5;
				float imag = uv.y - .5;

				float4 color = 0;

				for (float i = 0; i < 200; i++) {
					float realtemp = real;
					real = real * real - imag * imag + _Creal;
					imag = 2 * realtemp * imag * _Cimag;
					if (sqrt(real * real + imag * imag) > 4) {
						color = i/40;
					}
				}


					return color;

				}

			ENDCG
		}
	}
}
