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

            #define CAMERA_SPACING 0.075
            #include "Raymarching.cginc"
            
            inline half4 colorize(v2f i, marchResult m, half4 color) {
                return distColor(m, color);
            }

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