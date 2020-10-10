Shader "linguini/RayMarching/World"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1)
        
        _BackGround ("BackGround", Color) = (0,0,0)
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
        _Resolution ("Resolution", Range(0,1)) = 0.3

        [KeywordEnum(OFF, ON)]
        _SHADOW ("Shadow", Float) = 0
        
        [KeywordEnum(SIERPINSKI, MENGER, MANDELBOX, LERP)]
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
            #pragma shader_feature _BOX_SIERPINSKI _BOX_MENGER _BOX_MANDELBOX _BOX_LERP
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #include "Raymarching.cginc"
            
                        
            float4 colorize(v2f i, marchResult m, float4 color) {
                float4 o;
                o = color;
                o.rgb = rgb2hsv(color.rgb);
                o.r = frac(o.r + m.iter*abs(_CosTime.w)/90.0);
                o.rgb = (hsv2rgb(o.rgb));
                return o;                
            }

            #if defined(_BOX_SIERPINSKI) || defined(_BOX_LERP)
                float sierpinskiDist(float clarity, float3 pos)
                {
                    float r;
                    float scale = 2;
                    float3 offset = 0.5;
                    float3 normal = normalize(float3(1, 1, 0));
                    
                    float i;
                    for (i = 0; i < 10 * clarity * _Resolution; i++) {                      
                        // pos = mul(rotationMatrixCos(_CosTime.x), pos);

                        pos = fold(normal.xyz, pos);
                        pos = fold(normal.yzx, pos);
                        pos = fold(normal.zxy, pos);

                        pos = pos*scale - offset*(scale - 1);	
                    } 
                    return tetrahedronDist(pos) * pow(scale, -i);
                }
            #endif

            #if defined(_BOX_MENGER) || defined(_BOX_LERP)
                float mengerDist(float clarity, float3 pos)
                {
                    float r;
                    float scale = 3;
                    float3 offset = 0.5;
                    float3 normal = normalize(float3(1, -1, 0));
                    
                    float i;
                    for (i = 0; i <  10 * clarity * _Resolution; i++) {                      
                        // pos = mul(rotationMatrixCos(_CosTime.x), pos);
                        pos = abs(pos);
                        pos = fold(normal.xyz, pos);
                        pos = fold(normal.xzy, pos);
                        pos = fold(normal.zxy, pos);
                        pos.xy = pos.xy*scale - offset.xy*(scale - 1);	
                        
                        pos.z -= 0.5*offset.z*(scale-1)/scale;
                        pos.z = -abs(pos.z);
                        pos.z += 0.5*offset.z*(scale-1)/scale;
                        pos.z = scale*pos.z;
                        
                    } 
                    return cubeDist(pos) * pow(scale, -i);
                }
            #endif

            #if defined(_BOX_MANDELBOX) || defined(_BOX_LERP)               
                float4 boxFoldDR(float size, float4 posDR) {
                    return float4(clamp(posDR.xyz, -size, size) * 2 - posDR.xyz, posDR.w);
                }

                float4 sphereFoldDR (float radius, float innerRadius, float4 posDR) {
                    float R2 = square(radius);
                    float r2 = square(posDR.xyz);
                    float iR2 = square(innerRadius);
                    return (r2 < iR2? R2/iR2: r2 < R2? R2/r2: 1) * posDR;
                }
                
                float mandelBoxDist(float clarity, float3 pos) {
                    // uint maxLevel = _Resolution * 100;
                    float scale = -2.5 + 0.5*_CosTime.z;
                    float absScale = abs(scale);
                    float4 offset = float4(pos, 1);
                    float4 posDR = float4(pos, 1);
                    for(uint j = 0; j < 10 * clarity * _Resolution; j++){
                        posDR = sphereFoldDR(0.25, 0.1, boxFoldDR(0.25, posDR));
                        posDR.xyz = scale*posDR.xyz + offset.xyz;
                        posDR.w = absScale*posDR.w + offset.w;
                    }
                    return cubeDist(posDR.xyz)/posDR.w;
                }

                #undef minRadius2
                #undef fixedRadius2
            #endif

            float sceneDist(float clarity, float3 pos) {
                #ifdef _BOX_SIERPINSKI
                    return sierpinskiDist(clarity, pos);
                    // return tetrahedronDist(clarity, (pos));
                #elif _BOX_MENGER
                    return mengerDist(clarity, pos);
                #elif _BOX_MANDELBOX
                    return mandelBoxDist(clarity, pos);
                #elif _BOX_LERP
                    return lerp(
                    mengerDist(clarity, pos),
                    mandelBoxDist(clarity, pos),
                    0.5*(1 - _CosTime.y)
                    );       
                #endif
            }

            ENDCG
        }
        UsePass "Standard/ShadowCaster"
    }
}