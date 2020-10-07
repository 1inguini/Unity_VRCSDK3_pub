Shader "linguini/RayMarching/Box"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1)
        
        _BackGround ("BackGround", Color) = (0,0,0)
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
        _Resolution ("Resolution", Range(0,1)) = 0.3

        [KeywordEnum(OFF, ON)]
        _SHADOW ("Shadow", Float) = 0
        
        [KeywordEnum(MENGER, MANDELBOX, LERP)]
        _BOX ("BoxType", Float) = 0
        
        [KeywordEnum(OFF, ON)]
        _DEBUG ("DEBUG", Float) = 0
        
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            LOD 100
            Cull Front
            ZWrite On

            //アルファ値が機能するために必要
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma shader_feature _ _DEBUG_ON
            // #pragma multi_compile WORLD
            #pragma multi_compile OBJECT
            #pragma shader_feature _SHADOW_OFF _SHADOW_ON
            #pragma shader_feature _BOX_MENGER _BOX_MANDELBOX _BOX_LERP
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            float sceneDist(float clarity, float3 pos);
            #include "Raymarching.cginc"

            #if defined(_BOX_MENGER) || defined(_BOX_LERP)
                float3 mengerizePos(float3 pos, float offset) {
                    pos = abs(pos);

                    pos -= offset/2;
                    pos = abs(pos);
                    pos += offset/2;

                    pos -= offset;
                    return pos;
                }

                float mengerDist(float clarity, float3 pos) {
                    float cube = cubeDist(pos);
                    uint maxLevel = clarity * _Resolution * 10;
                    uint size = 3;
                    float offset = 1;
                    float dist = pillarXYZDist(pos*size)/size;
                    float3 posX = pos, posY = pos, posZ = pos;

                    for (uint level = 0; level < maxLevel; level++){
                        size *= 3;
                        offset /= 3;
                        // posX = mengerizeXPos(posX, offset);
                        // posY = mengerizeYPos(posY, offset);
                        // posZ = mengerizeZPos(posZ, offset);
                        // dist = min(dist, min3(
                        // pillarXDist(posX*size)/size,
                        // pillarYDist(posY*size)/size,
                        // pillarZDist(posZ*size)/size
                        // ));
                        pos = mengerizePos(pos, offset);
                        dist = min(dist, pillarXYZDist(pos*size)/size);
                    }
                    // return cube;
                    // return dist;
                    return max(cube, -dist);
                    // return max(cube, -pillarXDist(pos)/9);
                }
            #endif

            #if defined(_BOX_MANDELBOX) || defined(_BOX_LERP)
                #define minRadius2 0.25
                #define fixedRadius2 1.9
                float3 boxFold (float3 pos) {
                    return clamp(pos, -1, 1) * 2 - pos;
                }

                float dot2 (float3 x) {
                    return dot(x,x);
                }

                float sphereFold (float3 pos) {
                    float r2 = dot(pos, pos);
                    return // r2 < minRadius2? fixedRadius2/minRadius2: // linear inner scaling
                    // (r2 < fixedRadius2 ?
                    max(1, fixedRadius2/max(r2,minRadius2))//: // this is the actual sphere inversion
                    // 1)
                    ;
                }

                float mandelBoxDist(float clarity, float3 pos) {
                    float3 initPos = pos;
                    uint maxLevel = 5 + _Resolution * 10 * clarity;
                    float scale = -2.5;//_SinTime.y;
                    float offset = 1;
                    float coef = 1;
                    float r;
                    for (uint i = 0; i < maxLevel; i++) {
                        pos = boxFold(pos);
                        coef = sphereFold(pos);
                        pos *= coef;
                        offset *= coef;
                        pos = scale * pos + initPos;
                        offset = offset * abs(scale) + 1;
                    }
                    return (length(pos)/abs(offset));
                }
                #undef minRadius2
                #undef fixedRadius2
            #endif

            float sceneDist(float clarity, float3 pos) {
                #ifdef _BOX_MENGER
                    return mengerDist(clarity, pos);
                #elif _BOX_MANDELBOX
                    return mandelBoxDist(clarity, pos*4)/4;
                #elif _BOX_LERP
                    return lerp(
                    mengerDist(clarity, pos),
                    mandelBoxDist(clarity, pos*4)/4,
                    (_SinTime.y+1)/2
                    );
                #endif
            }

            ENDCG
        }
        UsePass "Standard/ShadowCaster"
    }
}