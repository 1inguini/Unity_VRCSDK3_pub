Shader "linguini/RayMarching/CubesCullFront"
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
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define CAMERA_SPACING 1

            #include "Raymarching.cginc"
            
            inline half4 colorize(v2f i, marchResult m, half4 color) {
                return color;
            }

            half sceneDist(distIn din){
                // half3 pos = din.pos;
                // // half atField = sphereDist((pos-_WorldSpaceCameraPos)/5)*5;
                // half time = 2*_Time.x;
                // pos.yz = rotate(pos.yz, time);
                // pos.zx = rotate(pos.zx, time);
                // pos.xy = rotate(pos.xy, time);
                // din.pos.x -= _Time.y;
                // din.pos = mul(rotationMatrix(-2*_Time.x), din.pos);
                half interval = 2;
                din.pos = repeat(interval, din.pos);
                half m = 10;
                half t = frac(_Time.y*0.5)*2;
                half x = t < 1? 1-exp(-m*t): exp(-m*(t-1));
                din.pos = mul(rotationMatrix(UNITY_HALF_PI*x), din.pos);
                // pos.yz = rotate(pos.yz, _Time.y);
                // pos.zx = rotate(pos.zx, _Time.y);
                // pos.xy = rotate(pos.xy, _Time.y);
                // return sphereDist(pos/_Size)*_Size;
                // return torusDist(0.05, pos);
                return cubeDist(din.pos/_Size)*_Size;
                // return max(-atField, cubeDist(pos/_Size)*_Size);
            }
            ENDCG
        }
    }
}