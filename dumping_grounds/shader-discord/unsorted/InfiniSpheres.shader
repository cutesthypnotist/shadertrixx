Shader "Nave/Raymarching/InfiniSpheres"
{
	Properties
	{
		_AO ("Ambient Occlusion", Range(0, 5)) = 1.0
		_Size("Grid Size", Range(1, 10)) = 1.0
		_SRad("Sphere Radius", Range(0, 1)) = 0.15
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent-1" }
		LOD 100
		Cull Front
		ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 wpos : TEXCOORD0;
			};
			
			sampler2D_float _CameraDepthTexture;
			float _AO, _SRad, _Size;
			
			//Nothing to see here, this is just a copy&pasted distance estimation function for a sphere
			float fSphere(float3 p, float r, float3 c) 
			{
				return length(p - c) - r;
			}
			
			//Oh hello there, I see you're interested in how we get our distance estimation to all these spheres...
			//well let me tell you
			float DE(float3 p)
			{
				//Now this first line is the magic line that changes 1 sphere into an infinite amount of spheres, it does a couple of things
				//First of, p is the current worldposition of where our ray is right this very moment
				//Now i do something weird here and I'll tell you why in a second, but I offset the position by 500 on every axis
				//Why do I do this you ask? Well simple, unfortunately our magic modulo fucks up with negative values, so by offsetting
				//the ray position to somewhere ridiculous we make sure it never reaches any negative value to fuck up... you can
				//remove this and see how it doesn't render anything at the origin of your scene before 0
				//you can also change one of those 500's to 500 + _Time.x or whatever to have the scene moving on that axis
				//Well anyways, then we use our amazing fmod function and all it does is it takes our offset'ed rayposition modulo our gridsize
				//(yes you have a slider for that one). if our _Size is 1, then we basically reset the the ray position to a range between 0 and 1
				//so if the ray is at, idk, x=50.123 somewhere in the scene it'll act as if it was at 0.123... that means if we have a single object
				//at the origin, it'll probably hit that very same object every unit on all axises no matter where it is
				//that's how we get the infinite space, just imagine a cube that goes from 0 to _Size on all axises and repeat that infinitely long
				//all we need to do now is fill that single cube with an object and it'll appear in every single one
				//by the way, if you're wondering why i'm using fmod(a, b) instead of a % b, that's because fmod stands for fast-modulo and we want
				//fast things, right? (It probably is exactly the same, i have no idea, change it if you want)
				p = fmod(p + float3(500, 500, 500), _Size);
				
				//Alrighty, that was a lot of text, let's fill our single grid cell at the origin with a sphere, to do this we use the amazing
				//distance estimation function of a sphere, you can google it for any other primitive, or use that one link i sent you
				//the center of the sphere shouldn't be at 0, 0, 0 tho, remember that our grid cell goes from 0 to _Size on every axis, so we should
				//place it in the middle of that cell, so at _Size/2 it is!
				float3 center = float3(_Size/2, _Size/2, _Size/2);
				
				//now just feed in all the variables into the distance estimation function of a sphere, it needs the current ray position after we
				//adjusted it with our modulo and offset stuff, its radius and the center, we got all that, so feed it in!
				float distObj = fSphere(p, _SRad, center);
				
				//that's it, return the distance, and wow, it works, we're amazing! Also, if you want to add multiple objects, just calculate the distance
				//to another one and return min(distObjectA, distObjectB), you can chain as many as you want with the min function! And if you want to be
				//super crazy, instead of min(a, b) you can also use one of those rounding functions on that one link i gave you to make like a smoother
				//intersection where both those objects meet
				return distObj;
			}
			
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//Heyy Neen, I'm taking the time to comment this for you :)
				
				//Alright so this just defines the maximum amount of steps we'll use, I probably don't
				//have to explain something as simple as this but whatever :D
				float maxStep = 48;
				
				//alright, let's get straight into raycasting, getting the direction and origin of the
				//ray is super easy, for the direction you just take the vector between the camera position
				//and the world position of the current pixel that's processed and tada, you got the direction
				//normalize this shit and you're good to go
				float3 raydir = normalize(i.wpos - _WorldSpaceCameraPos.xyz);
				//the position the ray starts is just as easy, it's our camera position, who would have guessed that
				float3 raypos = _WorldSpaceCameraPos.xyz;
				
				//alright, time to raytrace, simple for-loop with maxStep iterations
				for (int stp = 0; stp < maxStep; stp++) {
					//alright, here we simply get the distance to the nearest object calculated by our amazing DE
					//or "Distance Estimation" function, genius, you can look into the comments on that one further above
					float d = DE(raypos);
					
					//now if the distance is super small, that means we hit something, I tried checking against <= 0.0 but
					//that made everything noisy and stuff so we'll just use something super tiny here
					if (d <= 0.0001) {
						//Now if we did hit something, we just return white times my magic ambient occlusion formular... Ohhhh :O
						//it's super simple tho, the main core is (stp / maxStep) which basically gives us the ratio of how many
						//steps it took to get here, if we hit something on the first step, then stp/maxStep is gonna be super small
						//but if it was the last step of the for loop then stp/maxStep is basically almost 1...
						//so if we hit something early it's gonna be close to 0 and if it's super far away or we needed a lot of steps
						//it's gonna be close to 1... then we just invert that with a "1 - bla" so, far is 1 and near is 0 and then
						//we take all of that and take that to a power of something which has a slider so you can kinda play around with
						//the "intensity" a little bit... Oh yes, also, if a ray takes multiple steps to get somewhere, not only does that
						//mean it may be far away, but it could also mean the surface it hit was more complex to get to, that's why you
						//see the spheres having some small gradient torwards the edges, which looks cool!
						return float4(1, 1, 1, 1) * saturate(pow(1 - stp / maxStep, _AO));
					}
					//oh yes, also, if we didn't hit something we just add the direction times our minimum distance to the nearest
					//object to the current ray pos and take the next step
					raypos += raydir * d;
				}
				
				//also look, if it went through all steps and didn't hit anything then just return pure black... it must have either
				//went on for infinity or found itself in a super complex crack of some fractal surface or whatever
				return float4(0, 0, 0, 1);
			}
			ENDCG
		}
	}
}
