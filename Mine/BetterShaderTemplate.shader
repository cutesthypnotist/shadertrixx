Shader "Unlit/BetterShaderTemplate"
{
// Script for setSortingOrder from https://github.com/pema99/shader-knowledge/blob/main/gpu-instancing.md
// using UnityEngine;

// [ExecuteInEditMode]
// public class SetSortingOrder : MonoBehaviour
// {
//     public int sortingOrder;
//     void OnEnable()
//     {
//         GetComponent<Renderer>().sortingOrder = sortingOrder;
//     }
// }

    Properties
    {
		[Header(Image)]
		_MainTex("Texture",2D) = "white"{}
		[Header(General settings)]
		_Tint("Tint (Alpha is transparency)", Color) = (1.0, 1.0, 1.0, 1.0)
        _ZBias ("ZBias", Float) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] _SourceBlend ("Source Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DestinationBlend ("Destination Blend", Float) = 10
        [Enum(UnityEngine.Rendering.BlendMode)] _SourceBlendA ("Source Blend A", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DestinationBlendA ("Destination Blend A", Float) = 10		
        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Int) = 1      		
        _Brightness("Brightness", Range(0, 2)) = 0.99
		_Gamma("Gamma", Range(0, 2)) = 1.0
		_GradualAlpha("Gradual alpha (0 to disable)", Range(0, 100)) = 0.0
    }
    CGINCLUDE
            #pragma target 5.0
            #pragma vertex vert
            #include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
            //#include "SDFMaster.cginc"
            #define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))

            struct vi
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vo
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            static vo qq;

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _Tint;
			float _Brightness;
			float _Gamma;
			float _GradualAlpha;    

            vo vert (vi v)
            {
                vo o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);  
				//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);              
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }                    
    ENDCG
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest"}

        Pass
        {
            AlphaToMask On
            ZWrite [_ZWrite]
            Cull [_Cull]
            Blend [_SourceBlend] [_DestinationBlend]
            ZTest [_ZTest]
            CGPROGRAM
            #pragma fragment frag
            #pragma multi_compile_instancing



            float4 frag (vo __vo) : SV_Target
            {
                qq = __vo;

                //TODO: Determine if this works with static vo qq
                // #if defined(UNITY_INSTANCING_ENABLED)

                // vo dummy;
                // float3 cube_positions[3];
                // for (int idx = 0; idx < 3; idx++) // get positions of 3 first renderers
                // {
                //     dummy.instanceID = idx; 
                //     UNITY_SETUP_INSTANCE_ID(dummy);

                //     float3 wpos = float3(unity_ObjectToWorld[0][3], unity_ObjectToWorld[1][3], unity_ObjectToWorld[2][3]);
                //     cube_positions[idx] = wpos;
                // }

                // UNITY_SETUP_INSTANCE_ID(qq);
                
                // return float4(cube_positions[floor(i.uv.x * 3)], 1);

                // #else
                // return 0;
                // #endif

                // If you don't want to jump through the hoops of using macros to access specific transform matrices, you can directly access the data like so:

                // unity_Builtins0Array[unity_BaseInstanceID + rendererID].unity_ObjectToWorldArray
                // Where rendererID is the instanceID of the renderer you want to access (the one assigned via Renderer.sortingOrder if you used that trick).                

                float4 col = tex2D(_MainTex, qq.uv);
				if (_GradualAlpha > 0.0) {
					_Tint.a = pow(min(col.r, min(col.g, col.b)), 1.0/(100.0-_GradualAlpha));
				}
                col = _Brightness * col;
				col = 0.5 * log(_Gamma+col);
				col = clamp(col, 0.0, 1.0);                
                return float4(col.xyz, _Tint.a);
            }
            ENDCG
        }
    }
}
