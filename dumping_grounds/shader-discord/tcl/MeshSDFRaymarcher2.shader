Shader "TCL/Raymarching/SDFVisualizer2"
{
    Properties
    {
        _MeshSDFTexture("Mesh SDF Texture", 3D) = "black" {}
        _SDFSize("SDF Size", Vector) = (0, 0, 0, 0)
        _SDFCenter("SDF Center", Vector) = (0, 0, 0, 0)
        [Toggle(OBJECT_SPACE)] _ObjectSpace("Object Space", Float) = 0
        _MaxSteps("Max Steps", int) = 48
    }
        SubShader
        {
            Tags { "RenderType" = "AlphaTest" "Queue" = "Transparent-1" }
            LOD 100
            Cull Front

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile __ OBJECT_SPACE

                #include "UnityCG.cginc"
                #include "Lighting.cginc"

                #define EPSILON 0.001

                struct appdata
                {
                    float4 vertex : POSITION;
                };

                struct v2f
                {
                    float4 vertex : SV_POSITION;
                    float3 wpos : TEXCOORD0;
                };

                struct fragOutput
                {
                    float4 color : SV_TARGET;
                    float depth : SV_DEPTH;
                };

                sampler3D _MeshSDFTexture;
                float4 _SDFCenter;
                float4 _SDFSize;
                int _MaxSteps;

                float sdBox(float3 pos, float3 size, float3 center)
                {
                  float3 d = abs(pos - center) - size/2;
                  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
                }

                float sdPlane( float3 pos, float4 normal )
                {
                  // normal must be normalized
                  return dot(pos, normal.xyz) + normal.w;
                }

                float sdMeshSDFTexture(float3 pos, float3 size, float3 center)
                {

                    float3 sdfUV = ((pos - center)/ size.xyz) + float3(0.5, 0.5, 0.5);
                    return tex3Dlod(_MeshSDFTexture, float4(sdfUV, 0));
                }

                float4 simpleLambert (float3 normal) {
                    fixed3 lightDir = fixed3(0.5,0.5, 0); // Light direction
                    fixed3 lightCol = fixed3(1,1,1); // Light color

                    fixed NdotL = max(dot(normal, lightDir),0);
                    fixed4 c;
                    c.rgb = float4(1,1,1,1) * lightCol * NdotL;
                    c.a = 1;
                    return c;
                }

                //Oh hello there, I see you're interested in how we get our distance estimation to all these spheres...
                //well let me tell you
                float distanceEstimator(float3 pos)
                {
                    #if defined(OBJECT_SPACE)
                        float3 center = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));
                    #else
                        float3 center = _SDFCenter.xyz;
                    #endif

                    //now just feed in all the variables into the distance estimation function of a sphere, it needs the current ray position after we
                    //adjusted it with our modulo and offset stuff, its radius and the center, we got all that, so feed it in!
                    float dist = sdBox(pos, _SDFSize, center);

                    if (dist <= EPSILON)
                    {
                        dist = sdMeshSDFTexture(pos, _SDFSize.xyz, center);
                    }

                    //that's it, return the distance, and wow, it works, we're amazing! Also, if you want to add multiple objects, just calculate the distance
                    //to another one and return min(distObjectA, distObjectB), you can chain as many as you want with the min function! And if you want to be
                    //super crazy, instead of min(a, b) you can also use one of those rounding functions on that one link i gave you to make like a smoother
                    //intersection where both those objects meet
                    return dist;
                }

                float3 estimateNormal(float3 p) {
                    return normalize(float3(
                        distanceEstimator(float3(p.x + EPSILON, p.y, p.z)) - distanceEstimator(float3(p.x - EPSILON, p.y, p.z)),
                        distanceEstimator(float3(p.x, p.y + EPSILON, p.z)) - distanceEstimator(float3(p.x, p.y - EPSILON, p.z)),
                        distanceEstimator(float3(p.x, p.y, p.z  + EPSILON)) - distanceEstimator(float3(p.x, p.y, p.z - EPSILON))
                    ));
                }


                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                    return o;
                }

                fragOutput frag(v2f i)
                {
                    fragOutput output = (fragOutput)0;

                    float3 rayDir = normalize(i.wpos - _WorldSpaceCameraPos.xyz);
                    float3 rayPos = _WorldSpaceCameraPos.xyz;

                    for (int stp = 0; stp < _MaxSteps; stp++) {
                        float distance = distanceEstimator(rayPos);

                        if (abs(distance) <= EPSILON) {
                            //output.color = float4(stp, stp, stp, stp) / _MaxSteps;
                            output.color = simpleLambert(estimateNormal(rayPos));
                            //output.color = float4(estimateNormal(rayPos), 1.0);

                            float4 csPos = UnityWorldToClipPos(rayPos);
                            output.depth = csPos.z/csPos.w;

                            return output;
                        }

                        rayPos += rayDir * distance;
                    }

                    discard;
                    return output;
                }
                ENDCG
            }
        }
}
