Shader "GeomOutlines"
{
	Properties 
	{
		_Color("Color", Color) = (1,0,0,1)
		_OutlineColor("OColor", Color) = (1,0,0,1)
		_Outline("Thickness", Range(0,10)) = 2
		_AngleAdjust("Hard Edge Angle Adjustment", Range (0.0, 180.0)) = 89.0
	}
	
	SubShader 
	{
		Name "Outline"
        Tags { "LightMode" = "ForwardBase"  "IgnoreProjectors" = "True"}
		
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off
		//ZTest always //un-comment to render outline through walls
		Pass
		{
		
			Stencil
			{
				Ref 128
				Comp always
				Pass replace
			}
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			
			half4 _Color;

			struct v2g_small
			{
			  float4  pos : SV_POSITION;
			  float2 uv : TEXCOORD0;
			};
			
			struct g2f_small
			{
			  float4  pos : SV_POSITION;
			  float2 uv : TEXCOORD0;
			};

			v2g_small vert(appdata_base v)
			{
			  v2g_small OUT;
			  OUT.pos = UnityObjectToClipPos(v.vertex);
			  return OUT;
			}
			
			half4 frag(g2f_small IN) : COLOR
			{
				return float4(_Color.rgb,1);
			}
			
			ENDCG
			
	}
	
		Pass 
		{
		
			Cull  Off
			
			Stencil
			{
				Ref 128
				Comp NotEqual
			}		
			
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma target 4.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fog
			
			#include "Lighting.cginc"
			
			
			half4 _OutlineColor;
			float _Outline, _AngleAdjust;

			struct v2g 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewTan : TANGENT;
				float3 normals : NORMAL;
			};
			
			struct g2f 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS( 2 )
				float3 viewTan : TANGENT;
				float3 normals : NORMAL;
			};

			v2g vert(appdata_base v)
			{
				v2g OUT;
				float3 scaleDir = normalize(v.vertex.xyz - float4(0,0,0,1));
				OUT.pos = UnityObjectToClipPos(v.vertex);
				OUT.uv = v.texcoord;
				UNITY_BRANCH
				if (degrees(acos(dot(scaleDir.xyz, v.normal.xyz))) > _AngleAdjust)
				{
					OUT.normals = mul((float3x3) UNITY_MATRIX_VP, mul((float3x3) UNITY_MATRIX_M, v.normal));
				}else
				{
					OUT.normals = mul((float3x3) UNITY_MATRIX_VP, mul((float3x3) UNITY_MATRIX_M, v.vertex));
				}
				OUT.viewTan = ObjSpaceViewDir(v.vertex);
				//#if defined(UNITY_REVERSED_Z)
				//OUT.pos.z -= 0.00015;
				//#else
				//OUT.pos.z += 0.00015;
				//#endif
			 
				return OUT;
			}
			
			void geom2(v2g start, v2g end, inout TriangleStream<g2f> triStream)
			{
				float thisWidth = normalize(start.normals.xy) / _ScreenParams.xy * _Outline * min(3,start.pos.w) * 2;
				float4 para = start.pos-end.pos;
				normalize(para);
				para *= thisWidth;
				
				float4 perp = float4(para.y,-para.x, 0, 0);
				perp = normalize(perp) * thisWidth;
				float4 v1 = start.pos-para;
				float4 v2 = end.pos+para;
				g2f OUT;
				OUT.pos = v1-perp;
				OUT.uv = start.uv;
				OUT.viewTan = start.viewTan;
				OUT.normals = start.normals;
				triStream.Append(OUT);
				
				OUT.pos = v1+perp;
				triStream.Append(OUT);
				
				OUT.pos = v2-perp;
				OUT.uv = end.uv;
				OUT.viewTan = end.viewTan;
				OUT.normals = end.normals;
				triStream.Append(OUT);
				
				OUT.pos = v2+perp;
				OUT.uv = end.uv;
				OUT.viewTan = end.viewTan;
				OUT.normals = end.normals;
				triStream.Append(OUT);
			}
			
			[maxvertexcount(12)]
			void geom(triangleadj  v2g IN[6], inout TriangleStream<g2f> triStream)
			{
				geom2(IN[0],IN[1],triStream);
				geom2(IN[1],IN[2],triStream);
				geom2(IN[2],IN[0],triStream);
			}
			
			half4 frag(g2f IN) : COLOR
			{
				float3 brightness = ShadeSH9(float4(0,0,0,1)) + _LightColor0;
				float worldBrightness = saturate((brightness.r + brightness.g + brightness.b)/3);
				_OutlineColor.rgb *= max(0, worldBrightness * 100);
				UNITY_APPLY_FOG( i.fogCoord, i.color );
				return _OutlineColor;
			}
			
			ENDCG

		}
	}
}