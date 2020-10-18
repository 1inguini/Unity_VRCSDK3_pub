Shader "linguini/RayMarching/GamingCubes"
{
    Properties
    {
        _Size ("Size", Range(0,1)) = 0.5
        _MaxDistance ("MaxDistance", Range(0,1)) = 1.0
        _BackGround ("BackGround", Color) = (0,0,0)

        _MainTex ("Texture", 2D) = "white" {}
        [MaterialToggle] _Decol ("Decolor", Float ) = 1
        _Red ("Red", Range(0, 1)) = 1
        _Green ("Green", Range(0, 1)) = 1
        _Blue ("Blue", Range(0, 1)) = 1
        _Cycle ("Cycle", Range(0.03, 0.5)) = 0.1
        _Scale ("Scale", Range(0.5, 3)) = 1
        _RGBIntensity ("RGB_Intensity", Range(0, 1)) = 1
        _TexIntensity ("Texture_Intensity", Range(0, 1)) = 1
        _FreqR ("Freq_R", Range(0.3, 3)) = 1
        _FreqG ("Freq_G", Range(0.3, 3)) = 1
        _FreqB ("Freq_B", Range(0.3, 3)) = 1
        _Cutoff("Cutoff", Range(0, 1)) = 0.5
        
        [KeywordEnum(OFF, ON)]
        _DEBUG ("DEBUG", Float) = 0
    }
    SubShader
    {

        LOD 1000
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            Cull Off

            //アルファ値が機能するために必要
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog
            
            #pragma multi_compile WORLD
            // #pragma multi_compile OBJECT
            #pragma multi_compile BACKGROUND
            #pragma multi_compile NODEPTH
            #pragma multi_compile _SHADOW_OFF

            #pragma shader_feature _ _DEBUG_ON

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #include "Raymarching.cginc"

            sampler2D _MainTex;
            half4 _MainTex_ST;
            half _Decol;
            half _Red;
            half _Green;
            half _Blue;
            half _Cycle;
            half _Scale;
            half _RGBIntensity;
            half _TexIntensity;
            half _FreqR;
            half _FreqG;
            half _FreqB;
            half _Cutoff;

            fixed4 gaming (v2f i)
            {   
                half xy = (i.uv.x + i.uv.y) * _Scale;
                fixed3 gaming_col = fixed3(
                _Red * (sin(_FreqR * (_Time.y + xy) / _Cycle) + 1) / 2,
                _Green * (sin(_FreqG * (_Time.y + xy) / _Cycle + UNITY_PI * 2 / 3) + 1) / 2,
                _Blue * (sin(_FreqB * (_Time.y + xy) / _Cycle + UNITY_PI * 4 / 3) + 1) / 2
                );
                
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed ave = (col.x + col.y + col.z) / 3.0;
                fixed4 o = clamp(
                fixed4(
                col.x * (1 - _Decol) + ave * _Decol,
                col.y * (1 - _Decol) + ave * _Decol,
                col.z * (1 - _Decol) + ave * _Decol,
                1) * _TexIntensity +
                (fixed4(gaming_col * _RGBIntensity, 1)),
                0, 1);
                clip(col.a - _Cutoff);
                return o;
            }

            inline half4 colorize (v2f i, marchResult m, half4 color) {
                return gaming(i);
            }
            
            half sceneDist(distIn din){
                half atField = -sphereDist((din.pos - mul(unity_ObjectToWorld, half4(0,0,0,1)).xyz)*0.1)*10;
                half interval = 3*_Size;
                half m = 10;
                uint i = ceil(_Time.y);
                din.pos.z -= ceil(_Time.y) + easing(m, frac(_Time.y));
                // din.pos = mul(rotationMatrix(-2*_Time.x), din.pos);
                din.pos = repeat(interval, din.pos);
                half2 rot = half2(UNITY_HALF_PI*(easing(m, frac(_Time.y))), 0);
                din.pos = mul(rotationMatrix(-rot[i%2], rot[(i+1)%2], 0), din.pos);
                
                half beat = _Size*(1+0.5*exp(-m*0.25*(1 + cos(UNITY_TWO_PI*_Time.w))));
                return max(atField, cubeDist(din.pos/beat)*beat);
            }
            
            ENDCG
        }
        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}