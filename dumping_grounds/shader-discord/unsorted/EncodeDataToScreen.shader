Shader "d4rkpl4y3r/Debug/Encode Data To Screen"
{
	Properties
	{
		[Enum(Off,0,Front,1,Back,2)] _Culling ("Culling Mode", Int) = 2
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
		}
		Cull [_Culling]

		CGINCLUDE
		#pragma vertex vert
		#pragma geometry geom
		#pragma fragment frag

		#pragma target 5.0

		#include "UnityCG.cginc"

		struct g2f
		{
			float4 pos : SV_POSITION;
		};

		void vert() { }

		[maxvertexcount(4)]
		void geom(triangle g2f IN[3], inout TriangleStream<g2f> tristream, uint id : SV_PrimitiveID)
		{
			if (id > 0)
				return;
			g2f o;
			o.pos = float4(-1, -1, 1, 1);
			tristream.Append(o);
			o.pos = float4(1, -1, 1, 1);
			tristream.Append(o);
			o.pos = float4(-1, 1, 1, 1);
			tristream.Append(o);
			o.pos = float4(1, 1, 1, 1);
			tristream.Append(o);
		}

		uint2 f30touint15_2(float input)
		{
			return uint2((asuint(input) >> 2) & 0x7fff, asuint(input) >> 17);
		}

		float uint15_2tof30(uint2 input)
		{
			return asfloat(((input.x & 0x7fff) << 2) | (input.y << 17));
		}

		float4 uint15tof32(uint4 input)
		{
			return f16tof32(((input & 0x4000) << 1) | input & 0x3fff);
		}

		uint4 f32touint15(float4 input)
		{
			return ((f32tof16(input) >> 1) & 0x4000) | (f32tof16(input) & 0x3fff);
		}

		float4 uint8tof32(uint4 input)
		{
			float4 split = input / 255.0;
			split.r = GammaToLinearSpaceExact(split.r);
			split.g = GammaToLinearSpaceExact(split.g);
			split.b = GammaToLinearSpaceExact(split.b);
			return split;
		}

		uint4 f32touint8(float4 input)
		{
			input.r = LinearToGammaSpaceExact(input.r);
			input.g = LinearToGammaSpaceExact(input.g);
			input.b = LinearToGammaSpaceExact(input.b);
			return round(input * 255);
		}

		float4 encodeFloatToARGB8(float f)
		{
			uint u = asuint(f);
			return uint8tof32(uint4(u, u >> 8, u >> 16, u >> 24) & 255);
		}

		float decodeFloatFromARGB8(float4 rgba)
		{
			uint4 u = f32touint8(rgba);
			return asfloat(u.x + (u.y << 8) + (u.z << 16) + (u.w << 24));
		}

		float4 f16tof32full(uint4 input)
		{
			uint4 exponent = (input >> 10) & 0x1f;
			uint4 mantissa = input & 0x3ff;
			uint4 nanFix = ((input << 16) & 0x80000000) | 0x7f800000 | (mantissa << 13);
			return ((exponent == 0x1f) && (mantissa != 0)) ? asfloat(nanFix) : f16tof32(input);
		}

		uint4 f32tof16full(float4 finput)
		{
			uint4 input = asuint(finput);
			uint4 exponent = (input >> 23) & 0xff;
			uint4 mantissa = input & 0x7fffff;
			uint4 nanFix = ((input & 0x80000000) >> 16) | 0x7c00 | (mantissa >> 13);
			return ((exponent == 0xff) && (mantissa != 0)) ? nanFix : f32tof16(finput);
		}
		ENDCG

		Pass
		{
			CGPROGRAM
			float4 frag(g2f i) : SV_Target
			{
				int2 pos = i.pos.xy;
				if (all(pos.xy < 256))
				{
					uint h = pos.x | pos.y << 8;
					return f16tof32full(h);
				}
				pos.y -= 260;
				if (pos.x < 256 && pos.y < 128 && pos.y >= 0)
				{
					uint h = pos.x | pos.y << 8;
					return uint15tof32(h);
				}
				pos.y -= 132;
				if (pos.x < 256 && pos.y < 256 && pos.y >= 0)
				{
					return uint8tof32(pos.yyyx);
				}
				pos.y -= 260;
				if (pos.x < 4 && pos.y < 4 && pos.y >= 0)
				{
					return encodeFloatToARGB8(UNITY_MATRIX_I_V[pos.y][pos.x]);
				}
				pos.y -= 8;
				if (pos.x < 4 && pos.y < 4 && pos.y >= 0)
				{
					float v = asfloat(~3u & asuint(UNITY_MATRIX_I_V[pos.y][pos.x]));
					return uint15tof32(f30touint15_2(v).xyxy);
				}
				clip(-1);
				return 0;
			}
			ENDCG
		}

		GrabPass
		{
			"_EncodedScreen"
		}

		Pass
		{
			CGPROGRAM
			#pragma multi_compile _ UNITY_HDR_ON
			Texture2D _EncodedScreen;

			float4 frag(g2f i) : SV_Target
			{
				int2 pos = i.pos.xy;
				pos.x -= 260;
				float4 screenValue = _EncodedScreen.Load(int3(pos, 0));
				if (all(pos < 256) && all(pos >= 0))
				{
					uint h = pos.x | pos.y << 8;
					return (h == f32tof16full(screenValue.r)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.x -= 260;
				if (all(pos < 256) && all(pos >= 0))
				{
					uint h = pos.x | pos.y << 8;
					return (h == f32tof16full(f16tof32full(h))) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.x += 260;
				pos.y -= 260;
				if (pos.x < 256 && pos.y < 128 && all(pos >= 0))
				{
					uint h = pos.x | pos.y << 8;
					return (h == f32touint15(screenValue.r)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.y -= 132;
				if (all(pos < 256) && all(pos >= 0))
				{
					return all(pos.yyyx == f32touint8(screenValue)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.y -= 260;
				if (all(pos < 4) && all(pos >= 0))
				{
					return all(UNITY_MATRIX_I_V[pos.y][pos.x] == decodeFloatFromARGB8(screenValue)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.y -= 8;
				if (all(pos < 4) && all(pos >= 0))
				{
					float v = asfloat(~3u & asuint(UNITY_MATRIX_I_V[pos.y][pos.x]));
					return (v == uint15_2tof30(f32touint15(screenValue).zw)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.x -= 8;
				if (all(pos < 4) && all(pos >= 0))
				{
					float v = UNITY_MATRIX_I_V[pos.y][pos.x];
					return (v == uint15_2tof30(f32touint15(screenValue).zw)) ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}
				pos.x += 8;
				pos.y -= 8;
				if (all(pos < 32) && all(pos >= 0))
				{
					bool b = false;
#ifdef UNITY_HDR_ON
					b = true;
#endif
					return b ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1);
				}

				clip(-1);
				return 0;
			}
			ENDCG
		}
	}
}
