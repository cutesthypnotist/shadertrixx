/*BSD Licence - Khlorghaal 2019

jesus christ this fucking shader was an adventure
consisting of flailing around for more than an hour
in rapid tard helmet mode trying to extract
a fucking ramp
from the mathematical ether
im ashamed for the result
but proud of the process
*/

Shader "Khlor/Hull_Volume" {
	Properties {
		colorMax ("Color Max", Color) = (0,0,0,0)
		colorMin ("Color Min", Color) = (1,1,1,1)
		ramp("Ramp", float) = 1
	}
	SubShader {
		LOD 200

		Tags { "RenderType"="Transparent-69" }
		Cull Off
		ZWrite Off
		Blend One One

		//only needs one pass because additive commutativity and no depthwrite
		//no depthwrite works because transparents use the backbuffer regardless

		CGPROGRAM




#pragma surface surf Lambert
//plain emission isnt a surface function, dunno why


/*
my impulse was to use schlick fresnel, but thats a completely different phenomenon.
SDF to normal-plane, translated orthogonal to ray by depth
 | . ray
D|   .
 |     .
  _________ plane

tan(acos(N)) = sqrt(1-x*x)/x
basically a reciprocal, but f(0)=inf but want =1
this limit cannot be physically based in O(1)

FUCK

hit that cunt with a ramp
this bitch empirical
*airhorn noises*
so basically schlick fresnel but less aggressive
everything in graphics is ultimately fucking ramps
physically based is just a buzzword for lobe regression
yet i always worry that empirical things are inherently shit because religion or something

IGNORE MY TRIBULATION*/

float4 colorMin;
float4 colorMax;
float ramp;
struct Input {
	float3 viewDir;
	float3 worldNormal;
};
float hullDensity(float ramp, float3 V, float3 N){
	V= normalize(V);
	N= normalize(N);
	float d= abs(dot(V,N));
	d= 1-d;
	return pow(d,ramp);
}
void surf (Input IN, inout SurfaceOutput o) {
	float s= hullDensity(ramp, IN.viewDir, IN.worldNormal);
	o.Emission= .5 * lerp(colorMin, colorMax, s);
	//.5 because front and backface, assuming closed topology
}





		ENDCG
	}
	FallBack "Specular"
}
