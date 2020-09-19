Shader "linguini/RayMarching/MandelBox"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _Shadow ("Shadow", Color) = (0,0,0)
        _BackGround ("BackGround", Color) = (0,0,0)
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
        _Resolution ("Resolution", Range(0,1)) = 0.3
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
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            float sceneDist(float3 pos);
            #include "Raymarching.cginc"

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

            float mandelBoxDist(float3 pos) {
                float3 initPos = pos;
                uint maxLevel = 5 + _Resolution * 10;
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

            float sceneDist(float3 pos) {
                return mandelBoxDist(pos*4)/4;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}

