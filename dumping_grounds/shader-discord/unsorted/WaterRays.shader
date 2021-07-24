// Copyright (C) 2019 Lyuma (Lyuma#0781) (xn.lyuma@gmail.com)
// MIT License
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
Shader "Selphina/WaterGodRays"
{
    Properties
    {
		[Header(PBR Settings)] _Color ("Color", Color) = (.8,.8,.8,1)
		_Gradient ("Gradient", 2D) = "white" {}
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.75
		_Metallic ("Metallic", Range(0,1)) = 0.75
		// [Header(Glitter in background)] _GlitterDist ("Glitter layer distances", Vector) = (0.03,0.09,0.23,0.3)
		// _GlitterEffect ("Glitter layer strength", Vector) = (0.2, 0.29, 0.37, 0.3)
		// _GlitterSize ("Glitter size", Vector) = (0.0833, 0.0733, 0.0633, 0.32)
		// _GlitterAngle ("Glitter view angle", Range(0,1)) = 0.4
		[Header(Water waves on surface)] _WaterHeight ("Distance to water surface", Float) = 26.58
		_WaterDensity ("Density of water waves", Float) = 0.49
		_WaterBrightness ("Brightness of water effect (0 disable)", Float) = 16.89
		_WaterSpeed ("Water speed", Float) = 0.25
        [HDR] _WaterColor ("Water color", Color) = (0.02,0.186,0.34,1)
        [HDR] _WaterBackgroundColor ("Water background color", Color) = (0.0,0.085,0.077,1)
        [HDR] _WaterGodrayColor ("Water color", Color) = (0.887,0.590,0.26,1)
        _SunPosition ("Sun position for godray", Vector) = (0, 1.26, -0.57, 0.0)
        _GodrayMultiplier ("Multiplier for godrays", Float) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry+1" "DisableBatching"="True" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertexNormX : TEXCOORD1;
                float4 texcoordNormYZ : TEXCOORD2;
                UNITY_FOG_COORDS(3)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.vertexNormX = float4(v.vertex.xyz, v.normal.x);
                o.texcoordNormYZ = float4(v.uv.xy, v.normal.yz);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }


    		static float3 objSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
            ////////// TRIANGULATION ///////////
            float getTriangleCustom(float2 uv, out float2 triangleId, out float2 triangleUV, float columnSpacing, float triDims) {
                //uv += float2(1,1);
                float2 tmpUV = uv - float2(0.5 + columnSpacing/triDims,0.5);
                float row = fmod(2 + fmod(0 + tmpUV.y * triDims, 2),2); // 0 + -> zero row offset, flips when negative
                tmpUV.x = (tmpUV.x - columnSpacing * (row - 1) / triDims) / (2 * columnSpacing);

                float2 realcoord = (float2(tmpUV.xy * float2(1,0.5)) * triDims);
                float2 fraccoord = fmod(1 + fmod(realcoord,1), 1 );
                float2 subCoord = ((float2(fraccoord.y + .5 * fraccoord.x, fraccoord.y)) * 2);
            
                triangleId = (floor(realcoord) * 2 + floor(subCoord));
                float2 fracTriangle = frac(subCoord);
                if (fracTriangle.y < fracTriangle.x) {
                    fracTriangle = frac(-subCoord);
                }
                triangleUV = fracTriangle;
                float equiCoord = 1 - 3 * min(1 - triangleUV.y, min(triangleUV.x, triangleUV.y - triangleUV.x));
                return equiCoord;
            }


            ////////// NOISE FUNCTIONS ///////////
            #define function(t) 			fmod(t,4.0)
            #define multiply_by_F1(t)	(fmod(t,8.0)  >= 4.0)
            #define inverse(t)				(fmod(t,16.0) >= 8.0)
            #define distance_type(t)	fmod(t/16.0,4.0)

            // Voronoi noise:
            float voronoi( in float2 x, float t ){
                float2 n = floor( x );
                float2 f = frac( x );
                
                float F1 = 8.0;
                float F2 = 8.0;
                
                for( int j=-1; j<=1; j++ )
                    for( int i=-1; i<=1; i++ ){
                        float2 g = float2(i,j);
                        float2 p = n + g;
                        p = ( dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3))).xx;
                        float2 o = frac(sin(p)*43758.5453);
                        //float2 o = hash( n + g );

                        o = 0.5 + 0.41*sin( t + 6.2831*o );	
                        float2 r = g - f + o;

                    float d = 	distance_type(t) < 1.0 ? dot(r,r)  :				// euclidean^2
                                    distance_type(t) < 2.0 ? sqrt(dot(r,r)) :			// euclidean
                                distance_type(t) < 3.0 ? abs(r.x) + abs(r.y) :		// manhattan
                                distance_type(t) < 4.0 ? max(abs(r.x), abs(r.y)) :	// chebyshev
                                0.0;

                    if( d<F1 ) { 
                        F2 = F1; 
                        F1 = d; 
                    } else if( d<F2 ) {
                        F2 = d;
                    }
                    }
                
                float c = function(t) < 1.0 ? F1 : 
                            function(t) < 2.0 ? F2 : 
                            function(t) < 3.0 ? F2-F1 :
                            function(t) < 4.0 ? (F1+F2)/2.0 : 
                            0.0;
                    
                if( multiply_by_F1(t) )	c *= F1;
                if( inverse(t) )			c = 1.0 - c;
                
                    return c;
            }

            // Simplex noise:
            float snoise(float2 v){
                const float4 C = float4(0.211324865405187, 0.366025403784439,
                                -0.577350269189626, 0.024390243902439);
                float2 i  = floor(v + dot(v, C.yy) );
                float2 x0 = v -   i + dot(i, C.xx);
                float2 i1;
                i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                float4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = fmod(i, 289.0);
                float3 permuteIn1 = i.y + float3(0.0, i1.y, 1.0 );
                float3 permuteIn2 = fmod(((permuteIn1*34.0)+1.0)*permuteIn1, 289.0) + i.x + float3(0.0, i1.x, 1.0 );
                float3 p = fmod(((permuteIn2*34.0)+1.0)*permuteIn2, 289.0);
                float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy),
                    dot(x12.zw,x12.zw)), 0.0);
                m = m*m ;
                m = m*m ;
                float3 x = 2.0 * frac(p * C.www) - 1.0;
                float3 h = abs(x) - 0.5;
                float3 ox = floor(x + 0.5);
                float3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
                float3 g;
                g.x  = a0.x  * x0.x  + h.x  * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            ////////// WATER EFFECT ///////////
            uniform float _WaterHeight;
            uniform float _WaterDensity;
            uniform float _WaterBrightness;
            uniform float _WaterSpeed;
            uniform float4 _WaterGodrayColor;
            uniform float4 _WaterBackgroundColor;
            uniform float4 _WaterColor;
            uniform float4 _SunPosition;
            uniform float _GodrayMultiplier;

            struct Cone
            {
                float cosa;	// half cone angle
                float h;	// height
                float3 c;		// tip position
                float3 v;		// axis
            };

            struct Ray
            {
                float3 o;		// origin
                float3 d;		// direction
            };

            struct Hit
            {
                float t;	// solution to p=o+t*d
                float3 n;		// normal
            };

            // returns float4(normal, solution to p=o+t*d)
            float4 intersectCone(Cone s, Ray r)
            {
                float3 co = r.o - s.c;

                float a = dot(r.d,s.v)*dot(r.d,s.v) - s.cosa*s.cosa;
                float b = 2. * (dot(r.d,s.v)*dot(co,s.v) - dot(r.d,co)*s.cosa*s.cosa);
                float c = dot(co,s.v)*dot(co,s.v) - dot(co,co)*s.cosa*s.cosa;

                float det = b*b - 4.*a*c;
                if (det < 0.) return float4(0,0,0,0);

                det = sqrt(det);
                float t1 = (-b - det) / (2. * a);
                float t2 = (-b + det) / (2. * a);

                // This is a bit messy; there ought to be a more elegant solution.
                float t = t1;
                if (t < 0. || t2 > 0. && t2 < t) t = t2;
                if (t < 0.) return float4(0,0,0,0);

                float3 cp = r.o + t*r.d - s.c;
                float h = dot(cp, s.v);
                if (h < 0. || h > s.h) return float4(0,0,0,0);

                float3 n = normalize(cp * dot(s.v, cp) / dot(cp, cp) - s.v);

                return float4(n, t);
            }


            ////// For waves on surface:
            #define MOD3 float3(443.8975,397.2973, 491.1871)
            float3 hash33(float3 p3)
            {
                p3 = frac(p3 * MOD3);
                p3 += dot(p3, p3.yxz+19.19);
                return -1.0 + 2.0 * frac(float3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
            }

            float perlin_noise(float3 p)
            {
                float3 pi = floor(p);
                float3 pf = p - pi;
                
                float3 w = pf * pf * (3.0 - 2.0 * pf);
                
                return  lerp(
                            lerp(
                                lerp(dot(pf - float3(0, 0, 0), hash33(pi + float3(0, 0, 0))), 
                                    dot(pf - float3(1, 0, 0), hash33(pi + float3(1, 0, 0))),
                                    w.x),
                                lerp(dot(pf - float3(0, 0, 1), hash33(pi + float3(0, 0, 1))), 
                                    dot(pf - float3(1, 0, 1), hash33(pi + float3(1, 0, 1))),
                                    w.x),
                                w.z),
                            lerp(
                                lerp(dot(pf - float3(0, 1, 0), hash33(pi + float3(0, 1, 0))), 
                                    dot(pf - float3(1, 1, 0), hash33(pi + float3(1, 1, 0))),
                                    w.x),
                                lerp(dot(pf - float3(0, 1, 1), hash33(pi + float3(0, 1, 1))), 
                                    dot(pf - float3(1, 1, 1), hash33(pi + float3(1, 1, 1))),
                                    w.x),
                                w.z),
                            w.y);
            }

            float simplex_noise(float3 p)
            {
                const float K1 = 0.333333333;
                const float K2 = 0.166666667;
                
                float3 i = floor(p + (p.x + p.y + p.z) * K1);
                float3 d0 = p - (i - (i.x + i.y + i.z) * K2);
                
                // thx nikita: https://www.shadertoy.com/view/XsX3zB
                float3 e = step(float3(0,0,0), d0 - d0.yzx);
                float3 i1 = e * (1.0 - e.zxy);
                float3 i2 = 1.0 - e.zxy * (1.0 - e);
                
                float3 d1 = d0 - (i1 - 1.0 * K2);
                float3 d2 = d0 - (i2 - 2.0 * K2);
                float3 d3 = d0 - (1.0 - 3.0 * K2);
                
                float4 h = max(0.6 - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
                float4 n = h * h * h * h * float4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));
                
                return dot(float4(31.316,31.316,31.316,31.316), n);
            }

            float water(float3 ro, float3 ray)
            {
                return (_WaterHeight - ro.y) / ray.y;
            }
            float bottom(float3 ro, float3 ray)
            {
                return (.95 + 0.05 * sin(_WaterSpeed * 4 * _Time.y)) * (_WaterHeight - ro.y)/ ((ray.y));
            }

            float2 scene(float3 ro, float3 ray)
            {
                return (-_WaterHeight - (ro.y))/ ( (ray.y));
            }

            float3 waterNormal(float3 p, float e) {
                float3 ee = float3(e, 0., 0.);
                float3 pp = p * 1.0;
                float h1 = perlin_noise(p + ee.xyy);
                float h2 = perlin_noise(p - ee.xyy);
                float h3 = perlin_noise(p + ee.yyx);
                float h4 = perlin_noise(p - ee.yyx);
                float3 du = float3(1., 0., h2 - h1);
                float3 dv = float3(0., 1., h4 - h3);
                return normalize(cross(du, dv)) * 0.5 + 0.5;
                //return float3(h1, h2, h3);
            }

            static float3 caustics_lp = float3(10.0, 10.0, 10.0);

            float caustics(float3 p, float3 lp) {
                float3 ray = normalize(p - lp);

                float2 shadow = water(lp, ray);
                float l = distance(lp + ray * shadow.x, p);
                // if (l > 0.01) {
                //     return 0.0;
                // }

                float dist = water(lp, ray);
                float3 waterSurface = lp + ray * dist;

                float3 refractRay = refract(ray, float3(0., 1., 0.), 1.0/1.333);
                float beforeHit = bottom(waterSurface, refractRay);
                float3 beforePos = waterSurface + refractRay * beforeHit;

                float3 noisePos = waterSurface + float3(0.,fmod(_Time.y * _WaterSpeed, 3600.) * 2.0,0.);
                float height = simplex_noise(noisePos);
                float3 deformedWaterSurface = waterSurface + float3(0., height, 0.);

                // refractRay = refract(ray, waterNormal(noisePos, 0.5), 1.0/1.333);
                refractRay = refract(ray, normalize(float3(height * float3((sign(sin(waterSurface.xz + height * float2(.3,.7))) * 2 + 1), 0).xzy + float3(0,1,0))), 1.0/1.333);
                float afterHit = bottom(deformedWaterSurface, refractRay);
                float3 afterPos = deformedWaterSurface + refractRay * afterHit;

                float beforeArea = length(ddx(beforePos)) * length(ddy(beforePos));
                float afterArea = length(ddx(afterPos)) * length(ddy(afterPos));
                return 3*max(beforeArea / afterArea, .001);
            }
            float simplifiedCaustics(float3 p, float3 lp) {
                p.xz *= 3.0;
                float3 ray = normalize(p - lp);

                float2 shadow = water(lp, ray);
                float l = distance(lp + ray * shadow.x, p);
                // if (l > 0.01) {
                //     return 0.0;
                // }

                float dist = water(lp, ray);
                float3 waterSurface = lp + ray * dist;
                float3 noisePos = waterSurface + float3(0.,fmod(_Time.y * _WaterSpeed, 3600.) * 2.0,0.);
                float height = simplex_noise(noisePos);

                // float3 refractRay = refract(ray, float3(0., 1., 0.), 1.0/1.333);
                float3 refractRay = refract(ray, normalize(float3(height * float3((sign(sin(waterSurface.xz + height * float2(.3,.7))) * 2 + 1), 0).xzy + float3(0,1,0))), 1.0/1.333);
                float beforeHit = bottom(waterSurface, refractRay);
                float3 beforePos = waterSurface + refractRay * beforeHit;

                // float3 noisePos = waterSurface + float3(0.,fmod(_Time.y * _WaterSpeed, 3600.) * 2.0,0.);
                // float height = simplex_noise(noisePos);
                return 3 * max(height, .001);
            }

            float3 waterEffect( in float3 ro, in float3 ray, float resX ) {
                float3 p = ro + ray * resX;
                float3 n = float3(0,1,0);
                float3 l = caustics_lp;
                float3 v = normalize(p - l);

                p *= float3(_WaterDensity,1,_WaterDensity);

                float c = caustics(p, l) * 0.6;
                float3 co = float3(c,c,c) *  + _WaterColor.rgb;
                float li = max(dot(v, n), 0.0);
                float3 col = max(0, co * li) + _WaterColor.rgb;
                col = pow(col, 1.0/2.2 * float3(1,1,1));
                return lerp(col, _WaterBackgroundColor.rgb, saturate(resX / 100.0));
            }

            float3 underwaterSunlight(float3 dir, float2 uv) {
                float3 axis = float3(0,1,0);
                Ray ray = {objSpaceCameraPos - dir * 100.0, dir};
                Cone cone = {.9, 4. * _WaterHeight, _WaterHeight * _SunPosition.xyz, -axis};
                float4 hitNormSol = intersectCone(cone, ray);
                float3 coneHitPt = (ray.o + dir * hitNormSol.w);
                float3 conecol = 0;
                float totalCaustics = 0;
                float stepdist = length(coneHitPt.xz - cone.c.xz) * 0.4 * 4.5;
                { //\for (uint i = 4; i < 6; i++) {
                    float3 coneHitPt2 = (ray.o + float3(dir.xzy * (stepdist)).xzy + dir * hitNormSol.w);
                    float3 godraycol = _WaterGodrayColor.rgb; //float3(0.02,0.15,0.27);
                    float mult = 1.0 - smoothstep(0.9 * _WaterHeight, 1.2 * _WaterHeight, coneHitPt2.y);
                    float3 coneIntersectWater = normalize(float3(((coneHitPt2.xz - cone.c.xz) * (1 + cone.c.y - _WaterHeight) / (coneHitPt2.y - cone.c.y)) + cone.c.xz, _WaterHeight).xzy);
                    float coneCaustics = simplifiedCaustics(float3(10,1,10)*float3(_WaterDensity,1,_WaterDensity) * coneIntersectWater, caustics_lp);
                    totalCaustics += abs(coneCaustics);
                    conecol += mult * saturate(dot(dir.xz, normalize(coneHitPt2.xz - cone.c.xz))) * pow((float3(coneCaustics,coneCaustics,coneCaustics) *  + godraycol) * (max(dot(-normalize(coneIntersectWater - caustics_lp), float3(0,1,0)), 0.0)) + godraycol, 1.0/2.2 * float3(1,1,1));
                }

                float waterSunRayBrightness = abs(totalCaustics) + 0.01;
                float underwaterDist = _WaterHeight - objSpaceCameraPos.y;
                float distAlongDir = (underwaterDist/(0.001+abs(dir.y)))    ;
                float3 surfaceHit = objSpaceCameraPos + dir * distAlongDir;
                /* * (dir.y * 2) * (dir.y + 0.5) */
                // float3 waterColor = hitNormSol.y * waterSunRayBrightness * hitNormSol.y * conecol * hitNormSol.y * saturate(.11 * _WaterHeight + .3 * -(cone.c.y - coneHitPt.y));
                float3 waterColor = hitNormSol.w * waterSunRayBrightness * conecol * _GodrayMultiplier * pow(saturate(_WaterHeight * 0.5 / (cone.c.y - coneHitPt.y)), 10.0) * saturate((cone.c.y - coneHitPt.y) / _WaterHeight - 0.5);// * saturate(.11 * _WaterHeight + .3 * -(cone.c.y - coneHitPt.y) / _WaterHeight);
                if (1) {
                    // uv.y * 
                    // distance(objSpaceCameraPos + dir * distAlongDir, cone.c)
                    waterColor += 1.0 / distance(surfaceHit, cone.c) * waterEffect(objSpaceCameraPos, dir, distAlongDir); //1.0 / distance(surfaceHit, cone.c) * saturate(waterEffect(float3(-1,-1,1) * objSpaceCameraPos, float3(-1,-1,1) * dir, distAlongDir));
                }

                // float underwaterDist = _WaterHeight - objSpaceCameraPos.y;
                // float distAlongDir = (underwaterDist/(0.001+abs(dir.y)))    ;
                // float3 waterColor = waterEffect(objSpaceCameraPos, dir, distAlongDir);

                //  * uv.y
                //waterColor *= saturate(1.6 / distance(surfaceHit, cone.c)); // 1.6 in the saturate
                return waterColor;
            }
            ////////////// END OF WATER EFFECT ///////////////



            ////////// COLOR FUNCTIONS ///////////
            float3 HSVToRGB( float3 c )
            {
                float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
                float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
                return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
            }

            float3 RGBToHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
                float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
                float d = q.x - min( q.w, q.y );
                float e = 1.0e-10;
                return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }


            fixed4 frag (v2f i) : SV_Target
            {
                // // sample the texture
                // fixed4 col = tex2D(_MainTex, i.uv);

                float3 viewVector = (i.vertexNormX.xyz - objSpaceCameraPos).xyz;
                float3 dir = (normalize(viewVector));
                float2 parallax = dir.xy / (.001+saturate(dir.z));
                // float2 gradientuv = saturate(0.5 + (1.0 - _GlitterSize.w) * (i.texcoordNormYZ.xy - 0.5));
                // float2 gradientl0 = gradientuv + parallax * _GlitterDist.w;
                // float2 gradientl1 = gradientuv + parallax * _GlitterDist.x;
                // float2 gradientl2 = gradientuv + parallax * _GlitterDist.y;
                // float2 gradientl3 = gradientuv + parallax * _GlitterDist.z;
                float2 uv = i.texcoordNormYZ.xy; //(0.5 + 1.05 * (IN.texcoord.xy - 0.5));

                // float3 normal = float3(IN.vertexNormX.w, IN.texcoordNormYZ.zw);
                // float2 triangleId;
                // float2 triangleUV;
                // float equiCoord = getTriangle(uv, triangleId, triangleUV);
                // fixed4 c = tex2D (_MainTex, TRANSFORM_TEX(uv, _MainTex));

                // clip (1 - length(2 * uv - 1));

                // water begin
                float3 waterEmission = _WaterBrightness * (2 * underwaterSunlight(dir, uv)); // clamp(2 * underwaterSunlight(dir, uv), 0, 0.8);
                waterEmission = lerp(_WaterBackgroundColor, waterEmission, smoothstep(-0.1, 0.7, dir.y));

                // c = saturate(16 * ((min(c.r, min(c.g, c.b)) * c.a) - 0.6)) * _Color;

                // float surfaceDistance = abs(viewVector).x;

                // float2 glitterTriangleId;
                // float2 glitterTriangleUV;
                // float equiGlitter;
                // float2 gradientMod;
                // float glitterAngle = 1. / (_GlitterAngle * _GlitterAngle);
                // float angleEffect = 1. / (_GlitterEffect.w + glitterAngle * surfaceDistance * surfaceDistance);
                // equiGlitter = getTriangleCustom(gradientl3.xy + float2(-7.61,9.38), glitterTriangleId, glitterTriangleUV, 0.5, 1/(.001 + _GlitterSize.z * _GlitterSize.z - 0.000901823));
                // gradientMod = (equiCoord > _InnerTriangle ? 1 : 0) * 0.1 * _GlitterEffect.z * angleEffect * snoise(float2(9.41 * floor(glitterTriangleId / float2(3,2))));
                // equiGlitter = getTriangleCustom(gradientl2.xy + float2(13.17,-23.11), glitterTriangleId, glitterTriangleUV, 0.5, 1/(.001 + _GlitterSize.y * _GlitterSize.y - 0.0005584));
                // gradientMod = max(gradientMod, (equiCoord > _InnerTriangle ? 1 : 0) * 0.1 * _GlitterEffect.y * angleEffect * snoise(float2(13.778 * floor(glitterTriangleId / float2(3,2)))));
                // equiGlitter = getTriangleCustom(gradientl1.xy + float2(2.48,5.113), glitterTriangleId, glitterTriangleUV, 0.5, 1/(.001 + _GlitterSize.x * _GlitterSize.x - 0.00069266));
                // gradientMod = max(gradientMod, (equiCoord > _InnerTriangle ? 1 : 0) * 0.1 * _GlitterEffect.x * angleEffect * snoise(float2(11.723 * floor(glitterTriangleId / float2(3,2)))));
                // float vdotn = 2 * max(
                // 	abs(dot(normalize(viewVector), normalize(float3(gradientMod, 0.005)))),
                // 	abs(dot(normalize(viewVector), normalize(float3(-gradientMod.x, gradientMod.y, 0.005)))));
                // //gradientMod /= abs(vdotn);
                // gradientl0 += gradientMod;
                // float glitterSparkle = 0.75 * pow(abs((1.77 - fmod(0.46 * dot(floor(141 - 141 * vdotn) + float2(_Time.y * 0.001183, sin(_Time.y * 0.000531)) + floor(glitterTriangleId / float2(3,2)), float2(137.8, 663.1)), 1.77)) * saturate( abs(gradientMod.y) * 10) * vdotn),5);
                // fixed4 gradient = tex2D (_Gradient, TRANSFORM_TEX(gradientl0, _Gradient)) * _Color * (0.95 + glitterSparkle);

                // float brt1_now = saturate(snoise(float2(triangleId) + 0.01 * float2(_Time.y*7 * 0.1 * 1.713, _Time.y * 0.1 * 1.991 + 12.3)));
                // float brt1_delay1 = saturate(snoise(float2(triangleId) + 0.01 * float2((0.25 + _Time.y)*7 * 0.1 * 1.713, (0.25 + _Time.y) * 0.1 * 1.991 + 12.3)));
                // float brt1_delay2 = saturate(snoise(float2(triangleId) + 0.01 * float2((0.5 + _Time.y)*7 * 0.1 * 1.713, (0.5 + _Time.y) * 0.1 * 1.991 + 12.3)));
                // float brt1 = max(min(brt1_delay1,brt1_delay2), min(max(brt1_delay1,brt1_delay2),brt1_now));
                // float brt2 = clamp(1.2*.5 * sqrt(2 * voronoi(float2(triangleId) + float2(cos(brt1_now), sin(brt1_now)), brt1_now) * 2),0.,1.);
                // float triangleBrighten = saturate((brt1 + .15*saturate(.3 * abs(triangleId.y) - .9) - 0.5) * 3.33) * lerp(0, brt1, clamp(40. * (0. + clamp(3.0 * (brt1 - 0.75), 0.,1.)), 0., 1.));
                // float triangleBrightness = max((2 * 0.333 * brt2) + 0.1666, triangleBrighten);

                // float3 gradhsv = RGBToHSV(gradient.rgb);
                // gradhsv.x += sign(float(triangleId.y)) * 0.001 / (0.02 + abs(gradhsv.x - 0.7));
                // float3 brightgrad = saturate(HSVToRGB(gradhsv));
                
                // float3 trianglePattern = equiCoord > _InnerTriangle ? gradient.rgb : lerp(gradient.rgb * triangleBrightness * 1.5, brightgrad, triangleBrighten);
                float4 c = float4(1,1,1,1);
			    float3 outputColor = waterEmission; // + lerp(0.3 * c.rgb, lerp(0.3 * trianglePattern, 0.8 * trianglePattern, (equiCoord <= _InnerTriangle ? triangleBrighten : 0)), 1 - c.a);
                float4 col = float4(outputColor, 1.0);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
