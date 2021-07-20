Shader "d4rkpl4y3r/PBS BRDF/No Forward Add"
{
	Properties
	{
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling ("Culling Mode", Int) = 2
		_Cutoff("Cutout", Range(0,1)) = .5
		_MainTex("Albedo", 2D) = "white" {}
		[NoScaleOffset] _OcclusionMap("Occlusion", 2D) = "white" {}
		[NoScaleOffset] _RoughnessMap("Roughness", 2D) = "black" {}
		[NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
		[hdr] _Color("Albedo Tint", Color) = (1,1,1,1)
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0
		_BumpScale("Normal Map Strength", Float) = 1
		_Smoothness("Smoothness", Range(0, 1)) = 0
		_DirectLightFactor("Directional Light Factor", Range(0, 1)) = 1
		_DirectLightAmbient("Directional Light Ambient", Range(0, 1)) = 0
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
			"Queue"="Geometry"
		}

		Cull [_Culling]

		CGINCLUDE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityPBSLighting.cginc"

			uniform float4 _Color;
			uniform float _Metallic;
			uniform float _Smoothness;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			sampler2D _OcclusionMap;
			sampler2D _RoughnessMap;
			sampler2D _NormalMap;
			uniform float _Cutoff;
			float _UVOcclusion;
			float _BumpScale;
			float _DirectLightFactor;
			float _DirectLightAmbient;

			struct v2f
			{
				#ifndef UNITY_PASS_SHADOWCASTER
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float3 wPos : TEXCOORD0;
				SHADOW_COORDS(3)
				#else
				V2F_SHADOW_CASTER;
				#endif
				float2 uv : TEXCOORD1;
			};

			v2f vert(appdata_full v)
			{
				v2f o;
				#ifdef UNITY_PASS_SHADOWCASTER
				TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
				#else
				o.wPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				o.pos = UnityWorldToClipPos(o.wPos);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.tangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
				o.tangent.w = v.tangent.w * unity_WorldTransformParams.w;
				TRANSFER_SHADOW(o);
				#endif
				o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
				return o;
			}

			half3 boxProjection(half3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
			{
				// Do we have a valid reflection probe?
				UNITY_BRANCH
				if (cubemapCenter.w > 0.0)
				{
					half3 nrdir = worldRefl;
					half3 rbmax = (boxMax.xyz - worldPos) / nrdir;
					half3 rbmin = (boxMin.xyz - worldPos) / nrdir;
					half3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;
					worldRefl = worldPos - cubemapCenter.xyz + nrdir * min(min(rbminmax.x, rbminmax.y), rbminmax.z);
				}
				return worldRefl;
			}

			float3 cubemapReflection(float smoothness, float3 worldReflDir, float3 worldPos)
			{
				Unity_GlossyEnvironmentData envData;
				envData.roughness = 1 - smoothness;
				envData.reflUVW = boxProjection(worldReflDir, worldPos,
					unity_SpecCube0_ProbePosition,
					unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
				float3 result = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0),
					unity_SpecCube0_HDR, envData);
				float spec0interpolationStrength = unity_SpecCube0_BoxMin.w;
				UNITY_BRANCH
				if(spec0interpolationStrength < 0.999)
				{
					envData.reflUVW = boxProjection(worldReflDir, worldPos,
						unity_SpecCube1_ProbePosition,
						unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
					result = lerp(Unity_GlossyEnvironment(
							UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
							unity_SpecCube1_HDR, envData),
						result, spec0interpolationStrength);
				}
				return result;
			}

			#ifndef UNITY_PASS_SHADOWCASTER
			float4 frag(v2f i) : SV_TARGET
			{
				float4 texCol = tex2D(_MainTex, i.uv) * _Color;
				clip(texCol.a - _Cutoff);

				float3 mapNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
				float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;

				float3 normal = normalize(
					mapNormal.x * i.tangent.xyz +
					mapNormal.y * binormal +
					mapNormal.z * i.normal
				);

				float2 uv = i.uv;

				UNITY_LIGHT_ATTENUATION(attenuation, i, i.wPos.xyz);

				float occlusion = tex2D(_OcclusionMap, i.uv).r;

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				smoothness *= 1 - tex2D(_RoughnessMap, i.uv).r;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, _Metallic, specularTint, oneMinusReflectivity
				);
				
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
				if(UNITY_MATRIX_P._43 == 0)
					viewDir = -UNITY_MATRIX_I_V._13_23_33;

				UnityLight light;
				light.color = (attenuation * _DirectLightFactor) * _LightColor0.rgb;
				light.dir = normalize(UnityWorldSpaceLightDir(i.wPos));
				UnityIndirect indirectLight;
				indirectLight.diffuse = max(0, ShadeSH9(float4(normal, 1)));
				indirectLight.diffuse += _LightColor0 * _DirectLightAmbient;
				indirectLight.diffuse *= occlusion;
				indirectLight.specular = cubemapReflection(smoothness, reflect(-viewDir, normal), i.wPos);
				indirectLight.specular *= occlusion;

				float3 col = UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, smoothness,
					normal, viewDir,
					light, indirectLight
				);

				#ifdef VERTEXLIGHT_ON

				indirectLight.diffuse = 0;
				indirectLight.specular = 0;

				for(int j = 0; j < 4 && any(unity_LightColor[j].rgb > 0); j++)
				{
					float3 lightPos = float3(unity_4LightPosX0[j], unity_4LightPosY0[j], unity_4LightPosZ0[j]);
					light.dir = lightPos - i.wPos;
					float lengthSq = dot(light.dir, light.dir);
					float atten2 = saturate(1 - ((lengthSq * unity_4LightAtten0[j]) / 25));

					if(atten2 > 0)
					{
						light.dir *= min(1e30, rsqrt(lengthSq));
						float atten = 1.0 / (1.0 + (lengthSq * unity_4LightAtten0[j]));
						atten = min(atten, atten2 * atten2);
						light.color = unity_LightColor[j] * atten;

						col += UNITY_BRDF_PBS(
							albedo, specularTint,
							oneMinusReflectivity, smoothness,
							normal, viewDir,
							light, indirectLight
						);
					}
				}

				#endif
				
				return float4(col, 1);
			}
			#else
			float4 frag(v2f i) : SV_Target
			{
				float alpha = _Color.a;
				if (_Cutoff > 0)
					alpha *= tex2D(_MainTex, i.uv).a;
				clip(alpha - _Cutoff);
				SHADOW_CASTER_FRAGMENT(i)
			}
			#endif
		ENDCG

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_fwdbase_fullshadows
			#pragma multi_compile _ VERTEXLIGHT_ON
			#pragma multi_compile UNITY_PASS_FORWARDBASE
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			ENDCG
		}
	}
}
