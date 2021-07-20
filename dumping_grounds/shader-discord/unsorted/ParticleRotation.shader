Shader "Cdrsan/Particle Rotator" {

	/*
	Vertex Streams needed for shader (in order):
	Position(POSITION.xyz), UV(TEXCOORD0.xy), Velocity(TEXCOORD0.zw|x), Center(TEXCOORD1.yzw)
	*/

	Properties {
		_MainTex ("Albedo", 2D) = "defaulttexture" {}
		_Color("Tint", Color) = (1, 1, 1, 1)
		_rtX ("Rotation X Axis", Range(-180,180)) = 0
		_rtY ("Rotation Y Axis", Range(-180,180)) = 0
		_rtZ ("Rotation Z Axis", Range(-180,180)) = 0
	}
	
	Subshader {
		Tags {"Queue" = "Transparent" "RenderType" = "Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		
		Pass {
		CGPROGRAM
			#pragma vertex vert 
			#pragma fragment frag 
			#include "UnityCG.cginc"
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			float _rtX, _rtY, _rtZ;
			
			struct input {
				float4 pos			: POSITION;
				float4 texcoord0	: TEXCOORD0;
				float4 texcoord1	: TEXCOORD1;
			};
			
			struct output {
				float4 pos	: SV_POSITION;
				float4 uv0	: TEXCOORD0;
				float4 uv1	: TEXCOORD1;
			};
			
			float3 getRotationOffset (float3 pos, float3 objPos, float3 objCenter, float3 rotation) {
				float3 rad = radians(rotation);
				float sinX = sin(rad.x);
				float sinY = sin(rad.y);
				float sinZ = sin(rad.z);
				float cosX = cos(rad.x);
				float cosY = cos(rad.y);
				float cosZ = cos(rad.z);
				float3 xAxis = float3(cosY * cosZ, cosX * sinZ + sinX * sinY * cosZ, sinX * sinZ - cosX * sinY * cosZ);
				float3 yAxis = float3(-cosY * sinZ, cosX * cosZ - sinX * sinY * sinZ, sinX * cosZ + cosX * sinY * sinZ);
				float3 zAxis = float3(sinY, -sinX * cosY, cosX * cosY);
				float3 tempPos = ((mul(unity_ObjectToWorld, pos).xyz - objCenter) - objPos);
				pos += float3(zAxis * tempPos.z + xAxis * tempPos.x + yAxis * tempPos.y) - tempPos;
				return pos;
			};
			
			output vert (input v) {
				output o;
				o.uv0 = v.texcoord0;
				o.uv1 = v.texcoord1;
				float3 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				float3 objCenter = float3(o.uv1.y,o.uv1.z,o.uv1.w);
				float3 velocity = normalize(float3(o.uv0.z, o.uv0.w, o.uv1.x));
				float3 dir0 = normalize(cross(float3(0,1,0), velocity));
				float3 dir1 = normalize(cross(dir0, velocity));
				v.pos.xyz = getRotationOffset(v.pos.xyz, objPos.xyz, objCenter, float3(0, 0, _rtZ));
				v.pos.xyz = getRotationOffset(v.pos.xyz, objPos.xyz, objCenter, float3(_rtX, 0, 0));
				v.pos.xyz = getRotationOffset(v.pos.xyz, objPos.xyz, objCenter, float3(0, _rtY, 0));
				float3 tempPos = ((mul(unity_ObjectToWorld, v.pos).xyz - objCenter) - objPos.xyz);
				v.pos.xyz += (((dir0 * tempPos.x) + (velocity * tempPos.y) + (dir1 * tempPos.z)) - tempPos);
				o.pos = UnityObjectToClipPos(v.pos);
				return o;
			};
			
			float4 frag (output i) : SV_TARGET {
				float4 color = tex2D(_MainTex, TRANSFORM_TEX(i.uv0, _MainTex));
				return saturate(color * _Color);
			};
		ENDCG
		}
	}
	Fallback "Diffuse"
}