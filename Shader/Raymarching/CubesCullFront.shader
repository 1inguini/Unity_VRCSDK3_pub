﻿Shader "linguini/RayMarching/CubesCullFront"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _BackGround ("BackGround", Color) = (0,0,0)
        _Size ("Size", Range(0,1)) = 0.5
        _MaxDistance ("MaxDistance", Range(0,1)) = 1.0
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
            #pragma multi_compile NODEPTH

            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define CAMERA_SPACING 1

            #include "Raymarching.cginc"
            
            inline half4 colorize(v2f i, marchResult m, half4 color) {
                return color;
            }

            half sceneDist(distIn din){
                half interval = 3*_Size;
                half m = 10;
                uint i = ceil(_Time.y);
                // din.pos.x -= _Time.y;
                // din.pos = mul(rotationMatrix(-2*_Time.x), din.pos);
                din.pos.z -= ceil(_Time.y) + easing(m, frac(_Time.y));
                // din.pos.z -= _Time.y;
                din.pos = repeat(interval, din.pos);
                // half t = frac(_Time.y*0.5)*2;
                //half x = t < 1? 1-exp(-m*t): exp(-m*(t-1));
                // din.pos = mul(rotationMatrix(UNITY_HALF_PI*x), din.pos);
                half2 rot1 = half2(UNITY_HALF_PI*(easing(m, frac(_Time.y))), 0);
                din.pos = mul(rotationMatrix(-rot1[i%2], rot1[(i+1)%2], 0), din.pos);
                
                half beat = _Size*(1+0.5*exp(-m*0.25*(1 + cos(UNITY_TWO_PI*_Time.w))));
                return cubeDist(din.pos/beat)*beat;
            }
            ENDCG
        }
    }
}