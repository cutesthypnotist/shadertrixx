Shader "Custom/SimpleLazyTriplanar" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[Normal]_BumpMap ("Normal Map", 2D) = "bump" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		 _tiles0x ("tile0X", float) = 0.03
		 _tiles0y ("tile0Y", float) = 0.03
		 _tiles0z ("tile0Z", float) = 0.03
		 _offset0x ("offset0X", float) = 0
		 _offset0y ("offset0Y", float) = 0
		 _offset0z ("offset0Z", float) = 0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex; float4 _MainTex_ST;
		sampler2D _BumpMap; float4 _BumpMap_ST;

		struct Input {
			float2 uv_MainTex;
            float3 worldNormal; INTERNAL_DATA
            float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

float _tiles0x;
float _tiles0y;
float _tiles0z;

float _offset0x;
float _offset0y;
float _offset0z;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		//GeometricSpecularAA (Valve Method)
		float GeometricAASpecular(float3 normal, float smoothness){
		    float3 vNormalWsDdx = ddx(normal);
		    float3 vNormalWsDdy = ddy(normal);
		    float flGeometricRoughnessFactor = pow(saturate(max(dot(vNormalWsDdx, vNormalWsDdx), dot(vNormalWsDdy, vNormalWsDdy))), 0.333);
		    return min(smoothness, 1.0 - flGeometricRoughnessFactor);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {


            float3 normal = WorldNormalVector ( IN, float3( 0, 0, 1 ) );

			float3 tighten = 0.576;
			float3 absVertexNormal = abs(normalize(normal));
			float3 weights = absVertexNormal - tighten;

			weights *= 3;

			float2 y0 = IN.worldPos.zy * _tiles0x + _offset0x;
			float2 x0 = IN.worldPos.xz * _tiles0z + _offset0z;
			float2 z0 = IN.worldPos.xy * _tiles0y + _offset0y;
		
			float4 mixedDiffuse = 0;
			if(weights.x > 0) mixedDiffuse += weights.x * tex2D(_MainTex, y0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
			if(weights.y > 0) mixedDiffuse += weights.y * tex2D(_MainTex, x0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
			if(weights.z > 0) mixedDiffuse += weights.z * tex2D(_MainTex, z0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;

			fixed3 nrm = 0.0f;
			if(weights.x > 0) nrm += weights.x * UnpackNormal(tex2D(_BumpMap, y0 * _BumpMap_ST.xy + _BumpMap_ST.zw));
			if(weights.y > 0) nrm += weights.y * UnpackNormal(tex2D(_BumpMap, x0 * _BumpMap_ST.xy + _BumpMap_ST.zw));
			if(weights.z > 0) nrm += weights.z * UnpackNormal(tex2D(_BumpMap, z0 * _BumpMap_ST.xy + _BumpMap_ST.zw));

			// Albedo comes from a texture tinted by color
			o.Albedo = mixedDiffuse.xyz;
			o.Normal = normalize(nrm);
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = mixedDiffuse.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
