# shadertrixx

~~CNLohr's repo for his Unity assets and other shader notes surrounding VRChat.  This largely contains stuff made by other people but I have kind of collected.~~

Needed a repo to write down notes so I forked CNLohr's repo as a starting point since it's well organized otherwise I will probably just find myself asking the same questions over and over again.


Look at: https://gist.github.com/mattatz
https://scrapbox.io/api/code/sayachang/Easing.hlsl/Easing.HLSL
https://scrapbox.io/api/code/sayachang/Easing.GLSL/Easing.GLSL
https://scrapbox.io/api/code/sayachang/Kmath.Easing.cs/Easing.cs
https://github.com/setchi/EasingCore
https://github.com/setchi/Unity-ShaderSketches
https://neort.io/vAMwJKARLdhDZyEjEYWJlgYfnGZ2
https://neort.io/popular
https://noriben.booth.pm/items/3143798
https://noriben.booth.pm/items/2802412


## Default values available for texture properties

Can also be edited without scripts but with "Debug-internal" inspector, activated by typing internal onto unitys "about" window
```Default values available for texture properties:
red
gray
grey
linearGray
linearGrey
grayscaleRamp
greyscaleRamp
bump
blackCube
lightmap
unity_Lightmap
unity_LightmapInd
unity_ShadowMask
unity_DynamicLightmap
unity_DynamicDirectionality
unity_DynamicNormal
unity_DitherMask
_DitherMaskLOD
_DitherMaskLOD2D
unity_RandomRotation16
unity_NHxRoughness
unity_SpecCube0
unity_SpecCube1```

IE _MainTex ("Texture", 2D) = "unity_DynamicLightmap" {}


## Avoid division by zero (Lyuma)
I rarely have this problem but here.
```sign(X) * max(0.001, abs(X))```

## TODO List:

## Don't go without this shadowcaster code (you will probably need it)
```hlsl        
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
```



## Audiolink
Look at github repo's examples and look at some of CNLohr's example code. 

## Instancing hacks
Basics are at: https://github.com/pema99/shader-knowledge/blob/main/gpu-instancing.md

Following up on this, you can try two-pass method:
The first pass: a GPU-instance enabled material on each joint
The second pass: a GPU-instance disabled material on the body renderer
The second pass doesn't have instancing so when you query the instancing data it's from the first pass
You can force the two passes sticking together by specifying their render queue.
Okay apparently this doesn't work and it's better to juse use the sorting order trick.

## Diffuse Box Raytracing
Sampling using grid points and not using monte carlo? Ask Lox to clarify because I do not understand.

## Projector Abuse?
Wireframe avatar in avatar testing
Lox's photo booth
https://vrchat.com/home/launch?worldId=wrld_6888716f-815b-4bcf-ab52-dc06e4c91033&instanceId=41732~region(us)

Lyuma's "mirror" shader - triplanar mapped material onto a reflection of the players' avatars
https://booth.pm/en/items/3136007
Just using a camera and rendertextures with the whole cam.SetTargetBuffers(colorRT.colorBuffer, depthRT.depthBuffer) and a projector set up with a material.


## SDF Collision
From Pema 07172021 #raymarching
I explained it a while back. For spheres, it's pretty simple. If you calculate the gradient of the distance field (the method you usually use for calculating normals) at the spheres position, you can march in the opposite direction, and if the distance from that is less than the spheres radius, you have a collision.

To resolve the collision, you can translate the sphere along the gradient by an amount given by radius - distance_to_sdf. Works well enough to do collision for many distance estimators but gets worse the more inaccurate your estimate is & if you bend space too much.
I made this a while back which kind of illustrates it in 2D, except that I am just evaluating the distance function once instead of actually marching (line 60). Didn't need to march since the sdf was sufficiently simple, but that isn't always the case. https://www.shadertoy.com/view/NlB3Dy

## Unity Cgincs
Go through all of them meticulously.


## Multiple CRTs
Revisit multiple CRT example.

## FakeSSS and SSR
See relevant includes..

## Geometry Shaders + Cameras
TODO: Simple pins type geometry shader.

## Raymarching
Bidirectional raymarching with spherecast inside and linear outside. Decent gains (made bee burger somewhat more tolerable, log fps)
1. https://blog.uhawkvr.com/rendering/rendering-volumetric-clouds-using-signed-distance-fields/
other approaches for fixed step size volumetric stuff is to increase the step size the further away you get

### Jump Flooding Algorithm 
Read these:

1. https://www.comp.nus.edu.sg/~tants/jfa/i3d06.pdf
2. https://blog.demofox.org/2016/02/29/fast-voronoi-diagrams-and-distance-dield-textures-on-the-gpu-with-the-jump-flooding-algorithm/
3. https://blog.demofox.org/2016/03/02/actually-making-signed-distance-field-textures-with-jfa/
As a start, you could try just doing stupid simple flood fill. Every pixel just reads from its neighbors at each iteration

Examples:

1. SCRN example: https://github.com/SCRN-VRC/Raymarched-GPU-Particles-with-Screenspace-Physics/

## CNLohr's ballpit mushrooms

~~1. d4rkplayer's UNITY_BRDF macro instead of SurfaceOutput standard (check ballpit code for example)~~
2. d4rkplayer's SV_Coverage for metallic shader
~~3. d4rkplayer's better depth normals~~
~~4. d4rkplayer's no forward add ~~
5. Finish kernel coefficient generator
6. Shrooms act as dispersors

## d4rkplayer's encode data to screen
See encodedatatoscreen.shader

## VRC Shader Discord
Test unsorted shader/examples and keep only what's useful

## liliToon
Helpful library functions

## Implement Lox 1-bounce Diffuse Box
for 1-bounce, the irradiance of each point on the box is a surface integral of bounce points on the box
i just approximate this integral by evaluating at quad corner points and mid points and taking weighted sum

## I don't know
UNITY_MATRIX_P._13 < 0 is true for left eye and false for the right
what’s the code of telling which eye
I think it was the sign of _23, let me check again
nope was _13

## The most important trick

```glsl
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
```

This makes a well behaved `mod` function that rounds down even when negative.

Thanks, @d4rkpl4y3r - this originally actually comes from an epic bgolus forum post: https://forum.unity.com/threads/translating-a-glsl-shader-noise-algorithm-to-hlsl-cg.485750/

## Struggling with shader type mismatches?

You can put this at the top of your shader to alert you to when you forgot a `float3` and wrote `float` by accident.

```glsl
#pragma warning (default : 3206) // implicit truncation
```

## General 2019 Beta Info:

1. React to this post: https://discord.com/channels/189511567539306508/449348023147823124/500437451085578262
2. Read this https://discord.com/channels/189511567539306508/503009489486872583/865421330698731541
4. Download this: https://files.vrchat.cloud/sdk/U2019-VRCSDK3-WORLD-2021.07.15.13.46_Public.unitypackage
5. Download & Install Unity Hub: https://unity3d.com/get-unity/download
7. Install Unity 2019.4.28f1.
8. Backup your project.
9. Follow this guide: https://docs.vrchat.com/v2021.3.2/docs/migrating-from-2018-lts-to-2019-lts
Basically:
1. Open the project to an empty scene.
2. Import the BETA SDK - if you ever import the not beta SDK you will likely have to start over.
3. Import Udon sharp aftert the beta SDK.
4. Import CyanEmu.

Import anything else you need.

Then open your scene.


NOTE: If you are going from a fresh git tree of a project, you should open a blank scene, import the new beta SDK and all your modules then close unity and reopen your scene.

## Additional tricks

From @Lyuma
 * [flatten] (UNITY_FLATTEN macro) to force both cases of an if statement or
 * force a branch with [branch] (UNITY_BRANCH macro);
 * force loop to unroll with [unroll] (UNITY_UNROLL) or
 * force a loop with [loop] (UNITY_LOOP)
 * there's also [call] for if or switch statements I think, not sure exactly how it works.

From @Orels
 * Here's a pretty quick reference for HLSL: https://developer.download.nvidia.com/cg/index_stdlib.html

From @lox9973
 * This flowchart of how mono behaviors are executed and in what order: https://docs.unity3d.com/uploads/Main/monobehaviour_flowchart.svg

## tanoise

Very efficient noise based on Toocanzs noise. https://github.com/cnlohr/shadertrixx/blob/main/Assets/tanoise/README.md

## scrn_aurora

tanoise-modified aurora, originally written by nimitz, modified further by scrn.  https://github.com/cnlohr/shadertrixx/tree/main/Assets/scrn_aurora

## Defining Avatar Scale

The "magic ratio" is `view_y = head_to_wrist / 0.4537` (in t-pose) all unitless.

"It's mentioned many places that armspan is the defining scale, but that comment is more specific (armspan is 2 * head_to_wrist, and the ratio to height)" - Ben

## Using depth cameras on avatars.

If an avatar has a grab pass, and you're using a depth camera, you may fill people's logs with this:

```
Warning    -  RenderTexture.Create: Depth|ShadowMap RenderTexture requested without a depth buffer. Changing to a 16 bit depth buffer.
```

A way around this is to create a junk R8 texture with no depth buffer `rtDepthThrowawayColor`, and your normal depth buffer, `rtBotDepth` and frankenbuffer it into a camera.  NOTE: This will break camrea depth, so be sure to call `SetTargetBuffers()` in the order you want the camreas to evaluate.

```cs
	CamDepthBottom.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtBotDepth.depthBuffer );
```



## Grabpasses

You can add a grabpass tag outside of any pass (this happens in the SubShader tag).  You should only use `_GrabTexture` on the transparent queue as to not mess with other shaders that use the `_GrabTexture`

```
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        GrabPass
        {
            "_GrabTexture"
        }

```

You should use the `_GrabTexture` name so that it only has to get executed once instead of once for every material.

You can then index into it as a sampler2D.


```glsl
            sampler2D _GrabTexture;
```

```glsl
float2 grabuv = i.uv;
#if !UNITY_UV_STARTS_AT_TOP
grabuv.y = 1 - grabuv.y;
#endif
fixed4 col = tex2D(_GrabTexture, grabuv);
```

Or, if you want to grab into it from its place on the screen, like to do a screen-space effect, you can do this:

in Vertex shader:
```glsl
	o.grabposs = ComputeGrabScreenPos( o.vertex );
```
in Fragment shader:
```glsl
	col = tex2Dproj(_GrabTexture, i.grabposs );
```

editor's note: I spent a long time trying to find a good way to do this exclusively from the fragment shader, and I did not find one.

## Depth Textures

If you define a sampler2D the following way, you can read the per-pixel depth.
```glsl
sampler2D _CameraDepthTexture;
```

```glsl
// Compute projective scaling factor...
float perspectiveDivide = 1.0f / i.screenPosition.w;

// Scale our view ray to unit depth.
float3 direction = i.worldDirection * perspectiveDivide;

// Calculate our UV within the screen (for reading depth buffer)
float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;

// No idea
screenUV.y = 1 - screenUV.y; 

// VR stereo support
screenUV = UnityStereoTransformScreenSpaceTex(screenUV);

// Read depth, linearizing into worldspace units.    
float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

float3 worldspace = direction * depth + _WorldSpaceCameraPos;
```

## VRC Layers

http://vrchat.wikidot.com/worlds:layers

Want to do a camera compute loop?  Shove everything on the "Compute" layer and put it somewhere a long way away.

## Need to iterate on Udon Sharp faster?

Edit -> Preferences -> General -> Auto Refresh, uncheck.

Whenever you do need Unity to reload, ctrl+r

## MRT

This demo is not in this project, but, I wanted to include notes on how to do multiple rendertextures.

1) Set up cameras pointed at whatever you want to compute.
2) Put the things on a layer which is not heavily used by anything else.
3) Make sure to cull that layer on all lights.
4) Use `SetReplacementShader` - this will prevent a mountain of `OnRenderObject()` callbacks.
5) Cull in camrea based on that layer.
6) Put camera on default layer.
7) Don't care about depth because when using MRTs, you want to avoid letting unity figure out the render order, unless you really don't care.
8) I find putting camera calcs on `UiMenu` to work best.

OPTION 1: Cameras ignore their depth and render order when you do this.  Instead they will execute in the order you call SetTargetBuffers on them.

NOTE: OPTION 2: TEST IT WITHOUT EXPLICIT ORDERING (manually executing .Render) FIRST AS THIS WILL SLOW THINGS DOWN  You will need to explicitly execute the order you want for all the cameras.   You can only do this in `Update` or `LateUpdate`, i.e.

```cs
		CamCalcA.enabled = false;
		CamCalcA.SetReplacementShader( <shader>, "" );
		RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };
		CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);
..

		CamCalcA.Render()
		CamCalcB.Render()
```


## Making camera computation loops performant

 * Put the camera, the culling mask and the object you're looking at on a unique layer from your scene in general.  Find all lights, and cull off that layer.  If a camera is on a layer that is lit by a light, things get slow.
 * Make sure your bounding box for your geometry you are computing on doesn't leak into other cameras.
 * Use the following script on your camera: `<camera>.SetReplacementShader( <shader>, "");` where `<camera>` is your camera and `<shader>` is the shader you are using on the object you care about.  As a warning, using a tag here will slow things back down.  This prevents a ton of callbacks like `OnRenderObject()` in complicated scenes.
 * Doing these things should make your camera passes take sub-200us in most situations.



## Additional Links

These are links other people have given me, these links are surrounding U#.

 * https://github.com/jetdog8808/Jetdogs-Prefabs-Udon
 * https://github.com/Xytabich/UNet
 * https://github.com/FurryMLan/VRChatUdonSharp
 * https://github.com/Guribo/BetterAudio
 * https://github.com/squiddingme/UdonTether
 * https://github.com/cherryleafroad/VRChat_Keypad
 * https://github.com/aiya000/VRChat-Flya
 * https://github.com/MerlinVR/USharpVideo
 * https://github.com/Reimajo/EstrelElevatorEmulator/tree/master/ConvertedForUdon

Lit vertex shader
 * https://github.com/Xiexe/Unity-Lit-Shader-Templates

Interesting looking mesh tool (Still need to use)
 * https://github.com/lyuma/LyumaShader/blob/master/LyumaShader/Editor/LyumaMeshTools.cs
 
Basic global profiling scripts for Udon:
 * https://gist.github.com/MerlinVR/2da80b29361588ddb556fd8d3f3f47b5

This explaination of how the fallback system works (Linked by GenesisAria)
 * https://pastebin.com/92gwQqCM

Making procedural things like grids that behave correctly for going off in the distance.
 * https://www.iquilezles.org/www/articles/filterableprocedurals/filterableprocedurals.htm
 * https://www.iquilezles.org/www/articles/bandlimiting/bandlimiting.htm

 Convert detp function:
 ```c
     //Convert to Corrected LinearEyeDepth by DJ Lukis
     float depth = CorrectedLinearEyeDepth(sceneZ, direction.w);

     //Convert from Corrected Linear Eye Depth to Raw Depth 
     //Credit: https://www.cyanilux.com/tutorials/depth/#eye-depth

     depth = (1.0 - (depth * _ZBufferParams.w)) / (depth * _ZBufferParams.z);
     //Convert to Linear01Depth
     depth = Linear01Depth(depth);
```


This SLERP function, found by ACiiL,
```c
        ////============================================================
        //// blend between two directions by %
        //// https://www.shadertoy.com/view/4sV3zt
        //// https://keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/
        float3 slerp(float3 start, float3 end, float percent)
        {
            float d     = dot(start, end);
            d           = clamp(d, -1.0, 1.0);
            float theta = acos(d)*percent;
            float3 RelativeVec  = normalize(end - start*d);
            return      ((start*cos(theta)) + (RelativeVec*sin(theta)));
        }
```

Thanks, error.mdl for telling me how to disable batching.  This fixes issues where shaders need to get access to their local coordinates.
```
            Tags {  "DisableBatching"="true"}
```

## HALP The Unity compiler is emitting really bizarre assembly code.

Eh, just try using a different shader model, add a 
```glsl
#pragma  target 5.0
```
in your code or something.  Heck 5.0's been supported since the GeForce 400 in 2010.

## Udon events.

Re: `FixedUpdate`, `Update`, `LateUpdate`

From Merlin: https://docs.unity3d.com/ScriptReference/MonoBehaviour.html most of the events under Messages, with some exceptions like awake and things that don't make sense like the Unity networking related ones
you can look at what events UdonBehaviour.cs registers to see if they are actually there on Udon's side

## Getting big buffers

From @lox9973

BIG WARNING: After a lot of testing, we've found that this is slower than reading from a texture if doing intensive reads.  If you need to read from like 100 of these in a shader, probably best to move it into a texture first.

```c
cbuffer SampleBuffer {
    float _Samples[1023*4] : packoffset(c0);  
    float _Samples0[1023] : packoffset(c0);
    float _Samples1[1023] : packoffset(c1023);
    float _Samples2[1023] : packoffset(c2046);
    float _Samples3[1023] : packoffset(c3069);
};
float frag(float2 texcoord : TEXCOORD0) : SV_Target {
    uint k = floor(texcoord.x * _CustomRenderTextureInfo.x);
    float sum = 0;
    for(uint i=k; i<4092; i++)
        sum += _Samples[i] * _Samples[i-k];
    if(texcoord.x < 0)
        sum = _Samples0[0] + _Samples1[0] + _Samples2[0] + _Samples3[0]; // slick
    return sum;
}
```
and
```c
void Update() {
    source.GetOutputData(samples, 0);
    System.Array.Copy(samples, 4096-1023*4, samples0, 0, 1023);
    System.Array.Copy(samples, 4096-1023*3, samples1, 0, 1023);
    System.Array.Copy(samples, 4096-1023*2, samples2, 0, 1023);
    System.Array.Copy(samples, 4096-1023*1, samples3, 0, 1023);
    target.SetFloatArray("_Samples0", samples0);
    target.SetFloatArray("_Samples1", samples1);
    target.SetFloatArray("_Samples2", samples2);
    target.SetFloatArray("_Samples3", samples3);
}
```
https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-constants

CBuffers:
```
Properties {
...

    _Spread00 ("Spine",     Vector) = (40, 40, 40, 1)
    _Spread01 ("Head",        Vector) = (40, 40, 80, 1)
    ...
    _Spread50 ("IndexProximal",    Vector) = (45, 20,  9, 1)
    _Spread51 ("IndexDistal",    Vector) = (45,  9,  9, 1)

    _Finger00 ("LeftThumb",        Vector) = (0, 0, 0, 0)
    _Finger01 ("RightThumb",    Vector) = (0, 0, 0, 0)
    ...
    _Finger40 ("LeftLittle",    Vector) = (0, 0, 0, 0)
    _Finger41 ("RightLittle",    Vector) = (0, 0, 0, 0)
}

CGPROGRAM
...
cbuffer SpreadBuffer {
    float4 _Spread[6][2] : packoffset(c0);  
    float4 _Spread00 : packoffset(c0);
    float4 _Spread01 : packoffset(c1);
    ...
    float4 _Spread50 : packoffset(c10);
    float4 _Spread51 : packoffset(c11);
};
cbuffer FingerBuffer {
    float4 _Finger[10] : packoffset(c0);  
    float4 _Finger00 : packoffset(c0);
    ...
    float4 _Finger40 : packoffset(c8);
    float4 _Finger41 : packoffset(c9);
}
ENDCG
```

## Keywords.

(1) DO NOT INCLUDE `[Toggle]`!!
INSTEAD, use `[ToggleUI]`

(2) If you do want to use keywords, you can from this list: https://pastebin.com/83fQvZ3n

## VRChat "Build & Test" Overrides

You can insert additional parameters into VRC for "Build & Test" with the following (compiled TCC build of code included.) For instance, this one adds the `--fps=0` command-line parameter.
```c
#include <stdio.h>
#include <stdlib.h>

int main( int argc, char ** argv )
{
    char cts[8192];
    char * ctsp = cts;
    int i;
    ctsp += sprintf( ctsp, "vrchat.exe --fps=0" );
    for( i = 1; i < argc; i++ )
    {
        ctsp += sprintf( ctsp, " \"%s\"", argv[i] );
    }
    printf( "Launching: %s\n", cts );
    system( cts );
}
```
Command-line to compile application:
```
c:\tcc\tcc.exe vrc-uncapped.c
```

Then, in VRC SDK Settings, set the path to the VRC Exe to be vrc-uncapped.exe



## Making audio play

Thanks, @lox9973 for informing me of this: https://gitlab.com/-/snippets/2115172


## CRT Perf Testing (Unity 2018)
Test number results were performed on a laptop RTX2070.

**BIG NOTE**: CNLohr has observed lots of oddities and breaking things when you use the "period" functionality in CRTs.  I strongly recommend setting "period" to 0.

NSIGHT Tests were not performed in VR.

SINGLE CRT TESTS

Swapping buffers between passes:

 * SAME CRT: 1024x1024 RGBAF Running a CRT with with 25x .2x.2 update zones, double buffering every time yields a total run time of 
   * 2.25ms in-editor. 2.5ms in-game.
   * Each pass executed over a 10us window.
   * There was 100us between executions.
 * Same as above, except for 128x128.
   * 330us in-editor. 250us in-game.
   * Each pass executed over a 6us window.
   * There was 6us between executions.
 * Same as above, except for 20x20.
   * 340us in-editor. 270us in-game.
   * Each pass executed over a 6us window.
   * There was 6us between executions.
   
Not swapping buffers between passes:

 * SAME CRT: 1024x1024 RGBAF Running a CRT with with 25x .2x.2 update zones, double buffering only on last pass yields a total run time of 
   * 230-280us in-editor. 185us in-game.
   * Each pass executed over a 3.5us window.
   * There is no time between executions.
   * There was a 100us lag on the very last update.
 * Same as above, except for 128x128.
   * 63us in-editor. 22us (+/- a fair bit) in-game.
   * Each pass executed over a between 400ns and 1us window.
   * There are random lags surrounding this in game, but the lags are all tiny.
   
   
With chained CRTs, **but** using the same shader.  The mateials were set up so that each passing CRT.  All tests run 25 separate CRTs, using the last one.
 * 1024x1024 RGBAF running a CRT, but only .2x.2 of the update zone. (So it's a fair test).
   * ~80us in-editor, 140us in-game.
   * ~6.5us between passes.
   * First material uses a fixed material.
   * OBSERVATION: This looks cheaty, as it's all the same rendertarget.
 * Same, except forces the chain to be circular.
   * Same in-game perf.
 * Same, except verifying that each step is not stepped upon.
   * Unity a little slower (110us), 160us in-game.

 * Forced different rendertarget sizes, pinging between 1024x1024 and 512x512.
   * ~85us in-editor.
   * 120us in-game.

 * Forcefully inserting one double-buffered frame, to allow data tobe fed back in on itself
    * 190us in-editor
	* 250us in-game.
	* The frame with the double buffer incurs a huge pipeline hit of ~110us.

### Cameras
 * Created 25 cameras, pointed at 25 quads, each on an invisible layer.
 * No depth buffer, no clear.
 * Quad was only .2x.2
 * Basically same shader as chain CRT.
 * 1024x1024 RGBA32F
 
 * In-Editor 234us per camera. 5.8ms total.
 * In-Game 300us per camera. 7.8ms total.

Trying 128x128
 * In-Editor: 35us per camera. around 600us total.
 * In-game: ~30us per camera.  But, weird timing. Has stalls. Takes ~2.1ms total.

### Conclusions:
 * You can work with large CRTs that chain with virtually no overhead.
 * Small (say 128x128) buffers can double buffer almost instantly.
 * Larger buffers, for instance 1024x1024 RGBA32F take ~110us to double-buffer.
 * No penalty is paid by chaining CRTs target different texture sizes.
 * Note that all tests were performed with the same shader for all CRTs.
 * Cameras work surprisingly well for smaller textures and really poorly for big textures.
