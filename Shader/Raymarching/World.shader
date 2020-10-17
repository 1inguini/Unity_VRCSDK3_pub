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
        LOD 1000
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            Cull Front
            ZWrite On

            //アルファ値が機能するために必要
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
            #pragma exclude_renderers gles
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma shader_feature _ _DEBUG_ON
            #pragma multi_compile WORLD
            #pragma multi_compile COLORDIST
            // #pragma multi_compile OBJECT
            #pragma shader_feature _SHADOW_OFF _SHADOW_ON
            #pragma shader_feature _BOX_SIERPINSKI _BOX_MENGER _BOX_MANDELBOX _BOX_LERP
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #define CAMERA_SPACING 0.1
            #include "Raymarching.cginc"
            
            
            // half4 colorize(v2f i, marchResult m, half4 color) {
                //     half4 o;
                //     o = color;
                //     o.rgb = rgb2hsv(color.rgb);
                //     o.r = frac(o.r + m.iter*abs(_CosTime.w)/90.0);
                //     o.rgb = (hsv2rgb(o.rgb));
                //     return o;                
            // }                        
            half4 colorize(v2f i, marchResult m, half4 color) {
                return color;
            }

            #if defined(_BOX_SIERPINSKI) || defined(_BOX_LERP)

                // inline half3 fold(half3 normal, half3 pos) {
                    //     return pos - 2*min(0, dot(pos, normal))*normal;
                // }
                
                half2x3 coloredTetrahedronFold(half2x3 colPos) {
                    half3 normal = normalize(half3(1, 1, 0));
                    colPos[0].r -= (dot(colPos[1], normal.xyz) < 0)*(0.5 - colPos[0].r);
                    colPos[0].g -= (dot(colPos[1], normal.yzx) < 0)*(0.5 - colPos[0].g);
                    colPos[0].b -= (dot(colPos[1], normal.zxy) < 0)*(0.5 - colPos[0].b);

                    colPos[1] = fold(normal.xyz, colPos[1]);
                    colPos[1] = fold(normal.yzx, colPos[1]);
                    colPos[1] = fold(normal.zxy, colPos[1]);
                    return colPos;
                }

                half3 tetrahedronFold(half3 pos) {
                    half3 normal = normalize(half3(1, 1, 0));
                    pos = fold(normal.xyz, pos);
                    pos = fold(normal.yzx, pos);
                    pos = fold(normal.zxy, pos);
                    return pos;
                }

                half4 sierpinskiDist(half4 color, distIn din)
                {
                    half r;
                    half scale = 2;
                    half3 offset = 0.5;
                    half i; 
                    half3 hsv = rgb2hsv(color.rgb);
                    for (i = 0; i < 10 * din.clarity * _Resolution; i++) {                      
                        din.pos = mul(rotationMatrixCos(_CosTime.x), din.pos);
                        din.pos = tetrahedronFold(din.pos);
                        din.pos = din.pos*scale - offset*(scale - 1);                        
                        hsv.x -= 0.1*frac(din.pos.x + din.pos.y + din.pos.z);
                    }
                    return half4(hsv2rgb(hsv), tetrahedronDist(din.pos) * pow(scale, -i));
                }
            #endif

            #if defined(_BOX_MENGER) || defined(_BOX_LERP)
                half4 mengerDist(half4 color, distIn din)
                {
                    half r;
                    half scale = 3;
                    half3 offset = 0.5;
                    half3 normal = normalize(half3(1, -1, 0));
                    half3 pos = din.pos;

                    half i;
                    half3 hsv = rgb2hsv(color.rgb);
                    for (i = 0; i <  10 * din.clarity * _Resolution; i++) {                      
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
                        hsv.x -= 0.1*frac(pos.x + pos.y + pos.z);
                    } 
                    return half4(hsv2rgb(hsv), cubeDist(pos) * pow(scale, -i));
                }
            #endif

            #if defined(_BOX_MANDELBOX) || defined(_BOX_LERP)
                struct posDRisFolded {
                    half4 posDR;
                    bool folded;
                };
                posDRisFolded boxFoldDR(half size, half4 posDR) {
                    posDRisFolded o;
                    o.folded = any(step(posDR, -size) * step(size, posDR));
                    o.posDR = half4(clamp(posDR.xyz, -size, size) * 2 - posDR.xyz, posDR.w);
                    return o;
                }

                posDRisFolded sphereFoldDR (half radius, half innerRadius, half4 posDR) {
                    half R2 = square(radius);
                    posDRisFolded o;
                    half r2 = square(posDR.xyz);
                    half iR2 = square(innerRadius);
                    o.folded = iR2 < r2 && r2 < R2;
                    o.posDR = (r2 < iR2? R2/iR2: r2 < R2? R2/r2: 1) * posDR;
                    return o;
                }
                
                half4 mandelBoxDist(half4 color, distIn din) {
                    // uint maxLevel = _Resolution * 100;
                    half scale = -2.8;// - 0.5*_CosTime.z;
                    half absScale = abs(scale);
                    posDRisFolded p;
                    p.posDR = half4(din.pos, 1);
                    half3 hsv = rgb2hsv(color.rgb);
                    half h[3] = {hsv.x, hsv.x-0.5, hsv.x+0.3};
                    uint i = 0;
                    for(uint j = 0; j < 10 * din.clarity * _Resolution; j++){
                        p = boxFoldDR(0.25, p.posDR);
                        i += p.folded;

                        p = sphereFoldDR(0.25, 0.1, p.posDR);
                        i += p.folded;
                        
                        p.posDR.xyz = scale*p.posDR.xyz + din.pos;
                        p.posDR.w = absScale*p.posDR.w + 1;                        
                    }
                    hsv.x = h[i];
                    return half4(hsv2rgb(hsv), cubeDist(p.posDR.xyz)/p.posDR.w);
                }

                #undef minRadius2
                #undef fixedRadius2
            #endif

            half4 coloredSceneDist(half4 color, distIn din) {
                #ifdef _BOX_SIERPINSKI
                    return sierpinskiDist(color, din);
                    // return tetrahedronDist(clarity, (pos));
                #elif _BOX_MENGER
                    return mengerDist(color, din);
                #elif _BOX_MANDELBOX
                    return mandelBoxDist(color, din);
                #elif _BOX_LERP
                    return lerp(
                    mengerDist(color, din),
                    mandelBoxDist(color, din),
                    0.5*(1 - _CosTime.y)
                    );       
                #endif
            }

            ENDCG
        }
        UsePass "Standard/ShadowCaster"
    }
}