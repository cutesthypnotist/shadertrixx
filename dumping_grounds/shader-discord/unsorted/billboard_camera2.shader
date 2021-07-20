// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Billboard/Face Camera rot xy"
{
    Properties
    {
        _NTex ("North (RGB)", 2D) = "white" {} // Sprite is facing N
		_xtiles ("X Tiles", Int) = 1
		_ytiles ("Y Tiles", Int) = 1
		_threshold ("Clip Alpha Threshold", range(0, 1.1)) = 0.05 
		_framerate ("Frames Per Second", Int) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        LOD 100
        
        Cull off
        Zwrite On
        
        //Ztest Always
        
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass {
			Stencil {
					Ref 13
					Comp NotEqual
					Pass Keep
			}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 ang : TEXCOORD1;
                float4 pos : SV_POSITION;
				//float ang : ANGLE;
            };
            half4 _DetailTex_ST;
			sampler2D _NTex;
          
			half4 _NTex_ST;
			
            half _alpha;
			half _range;
			uint _framerate;
			uint _xtiles;
			uint _ytiles;
			half _threshold;
            v2f vert(float4 pos : POSITION, float2 uv : TEXCOORD0, float2 ang : TEXCOORD1)
            {
                v2f o;
				//Check if we're in VR, if we are set the camera's position to between
				//the two eyes. This avoids bad stereo effects where the sprite is aiming
				//at each eye at the same time. Otherwise just use the normal camera pos.
				#if UNITY_SINGLE_PASS_STEREO
					float4 cameraPos = float4((unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1])*0.5, 1);
				#else
					float4 cameraPos = float4(_WorldSpaceCameraPos,1);
				#endif
				
				cameraPos =  mul(unity_WorldToObject, cameraPos);
				float len = distance(float2(0, 0), float2(cameraPos[0], cameraPos[2]));
				
				//Length of the hypotenuse of the triangle formed by the camera's
				//objectspace pos, the origin, and the projection of the camera on
				//to the xz plane
				float hyp = distance(float3(0, 0, 0 ), float3(cameraPos[0],cameraPos[1],cameraPos[2]));
				
				// rotate the vertices along the X-axis to face the Camera
				float cosa = len/hyp;
				float sina = (-cameraPos[1])/hyp;
				float4x4 R = float4x4(
					1,	0,		0,		0,
					0,  cosa,	-sina,	0,
					0,	sina,	cosa,	0,
					0,		0,	0,		1);
				pos = mul(R, pos);
				
				//Rotate the vertices around the y-axis
				cosa = (cameraPos[2])/len;
				sina = (cameraPos[0])/len;
				R = float4x4(
					cosa,	0,	sina,	0,
					0,		1,	0,		0,
					-sina,	0,	cosa,	0,
					0,		0,	0,		1);
				pos = mul(R, pos);
				
				//o.ang[0] = atan2(cameraPos[0], cameraPos[2]);
				
				int2 frame = int2(floor(fmod(_Time[1]*_framerate, _xtiles)), floor(fmod((_Time[1]/float(_xtiles))*_framerate, _ytiles)));
					
				
				uv = float2((uv[0] + frame[0])/_xtiles, ((uv[1] + frame[1])/_ytiles) + (_ytiles - 1)/_ytiles);
				o.uv = TRANSFORM_TEX(uv, _NTex);
				
				
				//o.pos = UnityObjectToClipPos(pos);
				o.pos = UnityObjectToClipPos(pos);
				//o.pos = o.pos - o.pos*step(_range, dist);
				
				
				// Multiply the x coordinate by the aspect ratio of the screen so square textures
				// aren't stretched across the entire screen. Also centers the image on the screen.
				// This distorts the textures to 1:1 aspect ratio on desktop, but for some reason
				// it distorts them to 2:1 in VR
                //o.refl = ComputeScreenPos (o.pos*float4((_ScreenParams[0]/_ScreenParams[1]),1,1,1));
                return o;
            }

           
			
            fixed4 frag(v2f i) : SV_Target
            {                
				
				fixed4 uv;
				//#if UNITY_SINGLE_PASS_STEREO // use stereo image if in VR, otherwise use single image 
                //uv = tex2Dproj(_DetailTex, i.refl);
				//#else
				//uv = tex2Dproj(_DetailTex2, i.refl);
				//#endif
				uv = tex2D(_NTex, i.uv);
				clip(uv.a-_threshold);
				return uv;
				
            }
            ENDCG
        }
    }
}