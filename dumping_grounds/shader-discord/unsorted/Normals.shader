Shader "d4rkpl4y3r/Depth/Normals"
{
	Properties
	{
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling ("Culling Mode", Int) = 1
		[Enum(ddxy, 0, ddxy_fine, 1, 3tap, 2, 5tap, 3)] _NormalMethod("Normal Calculation Method", Int) = 0
		[Enum(Off, 0, On, 1)] _NegateHeadRotation("Negate Head Rotation", Int) = 0
	}
	SubShader
	{
		// yes, render queue 0 is correct. The _CameraDepthTexture gets rendered before that.
		// By rendering in 0 and writing depth a little greater than what we get from the depth 
		// texture we get to skip the pixel shader cost of most other shaders in the world.
		Tags { "Queue"="Transparent-3000" }
		Cull [_Culling]
		ZTest Off
		ZWrite On
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			//#pragma vertex vertFullScreen
			//#pragma geometry geomFullScreen
            #pragma fragment frag
			#pragma target 5.0
            #include "UnityCG.cginc"

			uniform int _NormalMethod;
			uniform int _NegateHeadRotation;
			uniform sampler2D _CameraDepthTexture;

            struct v2g
            {
                float4 pos : POSITION;
            };

			struct g2f
			{
				float4 pos : SV_POSITION;
				float4 grabPos : TEXCOORD0;
				float4 clipPos : CLIP_POS;
				nointerpolation float4x4 invProjection : MATRIX_I_P;
			};

            v2g vertFullScreen(appdata_base v) {
                return (v2g)0;
            }
			
			float4x4 inverse(float4x4 input)
			{
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
				//determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))
     
				float4x4 cofactors = float4x4(
					minor(_22_23_24, _32_33_34, _42_43_44), 
					-minor(_21_23_24, _31_33_34, _41_43_44),
					minor(_21_22_24, _31_32_34, _41_42_44),
					-minor(_21_22_23, _31_32_33, _41_42_43),
         
					-minor(_12_13_14, _32_33_34, _42_43_44),
					minor(_11_13_14, _31_33_34, _41_43_44),
					-minor(_11_12_14, _31_32_34, _41_42_44),
					minor(_11_12_13, _31_32_33, _41_42_43),
         
					minor(_12_13_14, _22_23_24, _42_43_44),
					-minor(_11_13_14, _21_23_24, _41_43_44),
					minor(_11_12_14, _21_22_24, _41_42_44),
					-minor(_11_12_13, _21_22_23, _41_42_43),
         
					-minor(_12_13_14, _22_23_24, _32_33_34),
					minor(_11_13_14, _21_23_24, _31_33_34),
					-minor(_11_12_14, _21_22_24, _31_32_34),
					minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

			float4x4 invP;

			g2f toFrag(float x, float y)
			{
				g2f o;
				o.pos = float4(x, y, 1, 1);
				o.clipPos = o.pos;
				o.grabPos = ComputeGrabScreenPos(o.pos);
				o.invProjection = invP;
				return o;
			}

			[maxvertexcount(4)]
			void geomFullScreen(triangle v2g IN[3], inout TriangleStream<g2f> tristream)
			{
				invP = inverse(UNITY_MATRIX_P);
				tristream.Append(toFrag(-1, -1));
				tristream.Append(toFrag(-1, 1));
				tristream.Append(toFrag(1, -1));
				tristream.Append(toFrag(1, 1));
			}

			g2f vert(appdata_base v)
			{
				g2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.clipPos = o.pos;
				o.grabPos = ComputeGrabScreenPos(o.pos);
				o.invProjection = inverse(UNITY_MATRIX_P);
				return o;
			}

			#define lengthSq(v) dot(v,v)

            half4 frag(g2f i, out float depth : SV_Depth) : SV_Target
            {
				float z = tex2Dproj(_CameraDepthTexture, i.grabPos).r;
				// I do write depth in this so it doesn't overwrite the mirror
				// also adding a small offset so MSAA doesn't overwrite the normals
				depth = saturate(z + z / 32);
				float4x4 IP = i.invProjection;
				float4 pos = i.clipPos / i.clipPos.w;
				float4 viewPos = mul(IP, float4(pos.xyw, z).xywz);
				viewPos /= viewPos.w;
				float3 viewNormal = 0;
				//_NormalMethod = (i.clipPos.x > 0) + 2 * (i.clipPos.y > 0);
				if(_NormalMethod == 0)
				{
					viewNormal = cross(ddx(viewPos.xyz), ddy(viewPos.xyz));
				}
				else if(_NormalMethod == 1)
				{
					viewNormal = cross(ddx_fine(viewPos.xyz), ddy_fine(viewPos.xyz));
				}
				else if (_NormalMethod == 2)
				{
					float zx = tex2Dproj(_CameraDepthTexture, i.grabPos + ddx(i.grabPos)).r;
					float4 vPosX = mul(IP, float4(pos.xyw + ddx(pos.xyw), zx).xywz);
					vPosX /= vPosX.w;
					float zy = tex2Dproj(_CameraDepthTexture, i.grabPos + ddy(i.grabPos)).r;
					float4 vPosY = mul(IP, float4(pos.xyw + ddy(pos.xyw), zy).xywz);
					vPosY /= vPosY.w;
					viewNormal = cross(vPosX.xyz - viewPos.xyz, vPosY.xyz - viewPos.xyz);
				}
				else if (_NormalMethod == 3)
				{
					float zx0 = tex2Dproj(_CameraDepthTexture, i.grabPos - ddx(i.grabPos)).r;
					float4 vPosX0 = mul(IP, float4(pos.xyw - ddx(pos.xyw), zx0).xywz);
					vPosX0 /= vPosX0.w;
					float zx1 = tex2Dproj(_CameraDepthTexture, i.grabPos + ddx(i.grabPos)).r;
					float4 vPosX1 = mul(IP, float4(pos.xyw + ddx(pos.xyw), zx1).xywz);
					vPosX1 /= vPosX1.w;
					float zy0 = tex2Dproj(_CameraDepthTexture, i.grabPos - ddy(i.grabPos)).r;
					float4 vPosY0 = mul(IP, float4(pos.xyw - ddy(pos.xyw), zy0).xywz);
					vPosY0 /= vPosY0.w;
					float zy1 = tex2Dproj(_CameraDepthTexture, i.grabPos + ddy(i.grabPos)).r;
					float4 vPosY1 = mul(IP, float4(pos.xyw + ddy(pos.xyw), zy1).xywz);
					vPosY1 /= vPosY1.w;
					float3 dx = vPosX1.xyz - viewPos.xyz;
					if(lengthSq(vPosX0.xyz - viewPos.xyz) < lengthSq(dx))
					{
						dx = -(vPosX0.xyz - viewPos.xyz);
					}
					float3 dy = vPosY1.xyz - viewPos.xyz;
					if(lengthSq(vPosY0.xyz - viewPos.xyz) < lengthSq(dy))
					{
						dy = -(vPosY0.xyz - viewPos.xyz);
					}
					viewNormal = cross(dx, dy);
				}
				if(_NegateHeadRotation == 1)
				{
					float3 centerEye = _WorldSpaceCameraPos;
					#ifdef USING_STEREO_MATRICES
					centerEye = .5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
					#endif
					float3 zaxis = -normalize(viewPos - mul(UNITY_MATRIX_V, float4(centerEye, 1)));
					float3 xaxis = normalize(cross(UNITY_MATRIX_I_V[1].xyz, zaxis));
					float3 yaxis = cross(zaxis, xaxis);
					viewNormal = mul(float3x3(xaxis, yaxis, zaxis), viewNormal);
				}
				viewNormal = normalize(viewNormal);
				return float4(pow(saturate(viewNormal.xyz), 2.2), 1);
            }
            ENDCG
		}
	}
}
