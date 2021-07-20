Shader ".Psy/Widen"
{
    Properties
    {
        _Strength ("Thicken it up", Range(0, 1)) = 0
        
        [Toggle(_)]_DistanceFade ("Distance Fading", Int) = 0
        _MinDistance ("Min Distance", Float) = 5
        _DistanceFalloff ("Falloff", Float) = 2
    }
    
    SubShader
    {
        Tags { "RenderType" = "Overlay" "Queue" = "Overlay+28767" "IgnoreProjector" = "True" "ForceNoShadowCasting" = "True" }
        Cull Off
        ZTest Always
        ZWrite Off
        Lighting Off
        
        GrabPass
        {
            Tags { "LightMode" = "Always" }
            "_WidenGrab"
        }
        
        Pass
        {
            Tags { "LightMode" = "Always" }
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            
            #include "UnityCG.cginc"
            
            static const float2 OffsetFactor = float2(_ScreenParams.y / _ScreenParams.x, 1);
            
            struct appdata
            {
                float4 vertex: POSITION;
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 pos: SV_POSITION;
                float4 grabPos: TEXCOORD0;
                float4 clipPos: TEXCOORD1;
                float distFade: TEXCOORD2;
                
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            uniform Texture2D _WidenGrab; uniform SamplerState sampler_WidenGrab;
            
            uniform float _Strength;
            
            uniform int _DistanceFade;
            uniform float _MinDistance;
            uniform float _DistanceFalloff;
            
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                // Distance fade
                UNITY_BRANCH if (_DistanceFade)
                {
                    float3 worldCentrePos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                    float dist = abs(distance(_WorldSpaceCameraPos, worldCentrePos));
                    o.distFade = 1 - smoothstep(_MinDistance, _MinDistance + max(0.0001, _DistanceFalloff), dist);
                }
                else
                {
                    o.distFade = 1;
                }
                
                o.clipPos = UnityViewToClipPos(v.vertex.xyz);
                o.pos = o.clipPos;
                o.grabPos = ComputeGrabScreenPos(o.clipPos);
                
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {   
                float2 grabPos = i.grabPos.xy / i.grabPos.w;
                float2 clipPos = i.clipPos.xy / i.clipPos.w;
                
                float2 grabOffset = float2(_Strength * i.clipPos.x, 0);
                grabOffset *= -1 * i.distFade;
                grabPos += grabOffset.xy * OffsetFactor;
                
                return _WidenGrab.Sample(sampler_WidenGrab, grabPos);
            }
            ENDCG
            
        }
    }
}
