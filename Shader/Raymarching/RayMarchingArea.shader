Shader "linguini/RayMarching/RayMarchingArea"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _BackGround ("BackGround", Color) = (0,0,0)
        _Size ("Size", Range(0,1)) = 0.5
        _MaxDistance ("MaxDistance", Range(0,1)) = 1.0
        _Resolution ("Resolution", Range(0,1)) = 1
        
        [KeywordEnum(SIERPINSKI, MENGER, MANDELBOX, LERP, CUBE)]
        _BOX ("BoxType", Float) = 0
    }
    SubShader
    {
        LOD 1000
        Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        Cull Front

        Pass
        {
            //アルファ値が機能するために必要
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile WORLD
            // #pragma multi_compile OBJECT
            #pragma multi_compile _SHADOW_OFF
            #pragma multi_compile BACKGROUND
            // #pragma multi_compile NODEPTH
            #pragma multi_compile PARTIAL_DEPTH

            #pragma shader_feature _BOX_SIERPINSKI _BOX_MENGER _BOX_MANDELBOX _BOX_LERP _BOX_CUBE
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define CAMERA_SPACING 1

            #include "Raymarching.cginc"
            
            #ifdef _BOX_CUBE
                inline half4 colorize(v2f i, marchResult m, half4 color) {
                    return color;
                }
            #else
                inline half4 colorize(v2f i, marchResult m, half4 color) {
                    return distColor(-_Time.y, m, color);
                }
            #endif

            half sceneDist(distIn din){
                half m = 15;
                half interval = 3*_Size;
                half tick = 0.5*_Time.y;
                uint i = ceil(tick);
                // din.pos.x -= tick;
                // din.pos = mul(rotationMatrix(-2*_Time.x), din.pos);
                din.pos.z -= i + easing(m, frac(tick));
                // din.pos.z -= tick;
                din.pos = repeat(interval, din.pos);
                // half t = frac(tick*0.5)*2;
                //half x = t < 1? 1-exp(-m*t): exp(-m*(t-1));
                // din.pos = mul(rotationMatrix(UNITY_HALF_PI*x), din.pos);
                half2 rot = half2(UNITY_HALF_PI*(easing(m, frac(tick))), 0);
                din.pos = mul(rotationMatrix(-rot[i%2], ((i+1)%4? -1: 1)*rot[(i+1)%2], 0), din.pos);
                
                half beat = _Size*max(1, saturate(ceil(4*tick-1)%4)*(1+0.5*exp(-m*0.25*(1 + cos(UNITY_TWO_PI*4*tick)))));
                din.pos /= beat;
                half result;
                #ifdef _BOX_SIERPINSKI
                    result = sierpinskiDist(din);
                #elif _BOX_MENGER
                    result = mengerDist(din);
                #elif _BOX_MANDELBOX
                    result = mandelBoxDist(din);
                #elif _BOX_LERP
                    result = lerp(
                    mengerDist(din),
                    mandelBoxDist(din),
                    0.5*(1 - _CosTime.y)
                    );
                #elif _BOX_CUBE    
                    result = cubeDist(din.pos);
                #endif
                return result*beat;
            }
            ENDCG
        }
    }
}