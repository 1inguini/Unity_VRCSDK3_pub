Shader "linguini/RayMarching/Box"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1)
        
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
        LOD 1000
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
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

            #define CAMERA_SPACING 0.05
            #include "Raymarching.cginc"
            
            inline half4 colorize(v2f i, marchResult m, half4 color) {
                return distColor(m, color);
            }

            #if defined(_BOX_SIERPINSKI) || defined(_BOX_LERP)
                half sierpinskiDist(distIn din)
                {
                    half r;
                    half scale = 2; // 1.75 + 0.25*_CosTime.w;
                    half3 offset = 0.5;
                    half3 normal = normalize(half3(1, 1, 0));
                    
                    half i;
                    for (i = 0; i < 10 * din.clarity * _Resolution; i++) {                      
                        din.pos = mul(rotationMatrix(_Time.y/5.0), din.pos);
                        din.pos = fold(normal.xyz, din.pos);
                        din.pos = fold(normal.yzx, din.pos);
                        din.pos = fold(normal.zxy, din.pos);

                        din.pos = din.pos*scale - offset*(scale - 1);	
                    } 
                    return tetrahedronDist(din.pos) * pow(scale, -i);
                }
            #endif

            #if defined(_BOX_MENGER) || defined(_BOX_LERP)
                half mengerDist(distIn din)
                {
                    half r;
                    half scale = 3;
                    half3 offset = 0.5;
                    half3 normal = normalize(half3(1, -1, 0));

                    half finalscale = 1;
                    half i;
                    for (
                    i = 0;
                    i <  10 * din.clarity * _Resolution &&
                    din.pixSize < finalscale;
                    i++)
                    {                      
                        // pos = mul(rotationMatrixCos(_CosTime.x), pos);
                        din.pos = abs(din.pos);
                        din.pos = fold(normal.xyz, din.pos);
                        din.pos = fold(normal.xzy, din.pos);
                        din.pos = fold(normal.zxy, din.pos);
                        din.pos.xy = din.pos.xy*scale - offset.xy*(scale - 1);	
                        
                        din.pos.z -= 0.5*offset.z*(scale-1)/scale;
                        din.pos.z = -abs(din.pos.z);
                        din.pos.z += 0.5*offset.z*(scale-1)/scale;
                        din.pos.z = scale*din.pos.z;
                        finalscale /= scale;
                    } 
                    return cubeDist(din.pos) * finalscale;
                }
            #endif

            #if defined(_BOX_MANDELBOX) || defined(_BOX_LERP)               
                half4 boxFoldDR(half size, half4 posDR) {
                    return half4(clamp(posDR.xyz, -size, size) * 2 - posDR.xyz, posDR.w);
                }

                half4 sphereFoldDR (half radius, half innerRadius, half4 posDR) {
                    half R2 = square(radius);
                    half r2 = square(posDR.xyz);
                    half iR2 = square(innerRadius);
                    return (r2 < iR2? R2/iR2: r2 < R2? R2/r2: 1) * posDR;
                }
                
                half mandelBoxDist(distIn din) {
                    // uint maxLevel = _Resolution * 100;
                    half scale = -2.5 + 0.5*_CosTime.w;
                    half absScale = abs(scale);
                    half4 offset = half4(din.pos, 1);
                    half4 posDR = half4(din.pos, 1);
                    half rcpPixSize = 1/din.pixSize;
                    for(uint j = 0; j < 10 * din.clarity * _Resolution && posDR.w < rcpPixSize; j++){
                        posDR = sphereFoldDR(0.25, 0.125, boxFoldDR(0.25, posDR));
                        posDR.xyz = scale*posDR.xyz + offset.xyz;
                        posDR.w = absScale*posDR.w + offset.w;
                    }
                    return cubeDist(posDR.xyz)/posDR.w;
                }

            #endif

            half sceneDist(distIn din) {
                // half viewField = -sphereDist((pos-mul(unity_WorldToObject, half4(_WorldSpaceCameraPos, 1)).xyz)*10)/10;
                // return torusDist(0.3, pos);
                #ifdef _BOX_SIERPINSKI
                    return sierpinskiDist(din);
                #elif _BOX_MENGER
                    return mengerDist(din);
                #elif _BOX_MANDELBOX
                    return mandelBoxDist(din);
                #elif _BOX_LERP
                    return lerp(
                    mengerDist(din),
                    mandelBoxDist(din),
                    0.5*(1 - _CosTime.y)
                    );       
                #endif
            }

            ENDCG
        }
        // UsePass "Standard/ShadowCaster"
    }
}