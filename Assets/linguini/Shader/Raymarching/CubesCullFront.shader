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
        Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        Cull Front
        LOD 100

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
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define CAMERA_SPACING 0.1

            #include "Raymarching.cginc"
            
            inline half4 colorize(v2f i, marchResult m, half4 color) {
                return color;
            }

            half sceneDist(distIn din){
                half3 pos = din.pos;
                // half atField = sphereDist((pos-_WorldSpaceCameraPos)/5)*5;
                half time = 2*_Time.x;
                pos.yz = rotate(pos.yz, time);
                pos.zx = rotate(pos.zx, time);
                pos.xy = rotate(pos.xy, time);
                pos = repeat(10*_MaxDistance, pos);
                pos.yz = rotate(pos.yz, _Time.y);
                pos.zx = rotate(pos.zx, _Time.y);
                pos.xy = rotate(pos.xy, _Time.y);
                // return sphereDist(pos/_Size)*_Size;
                // return torusDist(0.05, pos);
                return cubeDist(pos/_Size)*_Size;
                // return max(-atField, cubeDist(pos/_Size)*_Size);
            }
            ENDCG
        }
    }
}