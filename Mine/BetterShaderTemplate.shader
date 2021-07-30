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
			sampler2D _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;
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
        //Tags { "RenderType"="Opaque" "Queue"="AlphaTest"}
        Tags{ "Queue" = "Transparent" "RenderType" = "Opaque" }





        Pass
        {
            AlphaToMask On
            ZWrite [_ZWrite]
            Cull [_Cull]
            Blend [_SourceBlend] [_DestinationBlend]
            ZTest [_ZTest]
            CGPROGRAM
            #pragma target 5.0
            
			#pragma hull hul
			#pragma domain dom
			#pragma geometry geo   

            #pragma fragment frag
            #pragma multi_compile_instancing

            //https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityInstancing.cginc
            // Geometry Shader [TESS * TESS * GS_INSTANCE]
            // input mesh topology : point
            #define TESS 65
            #define GS_INSTANCE 32

			struct cho //CONSTANT_HS_OUT
			{
				float e[4] : SV_TessFactor;
				float i[2] : SV_InsideTessFactor;
			};

            struct ho { //HS_OUT
                #if defined(UNITY_INSTANCING_ENABLED)
                uint  instanceID : SV_InstanceID;
                #endif
            };

            struct dso { //DS_OUT
                uint pid : PID;
            };

            struct go { //GS_OUT
                float4 vertex : SV_POSITION;
            };

            cho chs() {
                cho o;
                o.e[0] = o.e[1] = o.e[2] = o.e[3] = o.i[0] = o.i[1] = TESS -1;
                return o;
            }

			[domain("quad")]
			[partitioning("integer")]
			[outputtopology("point")]
			[outputcontrolpoints(1)]
			[patchconstantfunc("chs")]
            ho hul(InputPatch<vo, 4> i) {
                #if defined(UNITY_INSTANCING_ENABLED)
                ho o;
                o.instanceID = i[0].instanceID;
                return o;
                #endif
            }

            [domain("quad")]
            dso dom(cho i, const OutputPatch<ho, 4> patch, float2 uv : SV_DomainLocation) 
            {
                dso o;
                o.pid = (uint)(round(uv.x * (TESS-1))) + ((uint)(round(uv.y*(TESS-1))) * TESS);
                return o;
            }

            // #define ADD_VERT(v,n) \
            //     o.vertex = UnityObjectToClipPos(v); \
            //     o.normal = UnityObjectToWorldNormal(n); \
            //     TriStream.Append(o);
            
            // #define ADD_TRI(p0,p1,p2,n) \
            //     ADD_VERT(p0, n) \
            //     ADD_VERT (p1, n) \
            //     ADD_VERT(p2, n)
            
            #define ADD_VERT(v) \
                o.vertex = v; \
                ts.Append(o);
            
            #define ADD_QUAD(p0,p1,p2,p3) \
                ADD_VERT(p0); \
                ADD_VERT(p1); \
                ADD_VERT(p2); \
                ADD_VERT(p3); \
                ts.RestartStrip();


            [instance(GS_INSTANCE)]
            [maxvertexcount(24)]
            void geo(point dso i[1], inout TriangleStream<go> ts, uint gsid : SV_GSInstanceID) {
                go o;

				// id : [0] - [TESS * TESS * GS_INSTANCE - 1]
				uint id = gsid + GS_INSTANCE * i[0].pid;

				// test : draw 135,200 cube, 1,622,400 polygon
				uint xid = id % 368;
				uint zid = id / 368;
				float xd = -100 * 0.5f + 100 * 0.5f / 368 + 100 * xid / 368;
				float zd = -100 * 0.5f + 100 * 0.5f / 368 + 100 * zid / 368;

				float4 p0 = UnityObjectToClipPos(float4(float3(-1, +1, +1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p1 = UnityObjectToClipPos(float4(float3(+1, +1, +1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p2 = UnityObjectToClipPos(float4(float3(-1, +1, -1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p3 = UnityObjectToClipPos(float4(float3(+1, +1, -1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p4 = UnityObjectToClipPos(float4(float3(-1, -1, +1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p5 = UnityObjectToClipPos(float4(float3(+1, -1, +1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p6 = UnityObjectToClipPos(float4(float3(-1, -1, -1) * 0.1f + float3(xd, 0, zd), 1));
				float4 p7 = UnityObjectToClipPos(float4(float3(+1, -1, -1) * 0.1f + float3(xd, 0, zd), 1));    

                //cube
                ADD_QUAD(p0,p1,p2,p3);
                ADD_QUAD(p4,p6,p5,p7);
                ADD_QUAD(p0,p2,p4,p6);
                ADD_QUAD(p3,p1,p7,p5);
                ADD_QUAD(p1,p0,p5,p4);
                ADD_QUAD(p2,p3,p6,p7);
                

            }

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
