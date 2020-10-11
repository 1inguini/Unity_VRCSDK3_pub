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
    }
    SubShader
    {

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            LOD 100
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

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #include "Raymarching.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Decol;
            float _Red;
            float _Green;
            float _Blue;
            float _Cycle;
            float _Scale;
            float _RGBIntensity;
            float _TexIntensity;
            float _FreqR;
            float _FreqG;
            float _FreqB;
            float _Cutoff;

            fixed4 gaming (v2f i)
            {   
                float xy = (i.uv.x + i.uv.y) * _Scale;
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

            inline float4 colorize (v2f i, marchResult m, float4 color) {
                return gaming(i);
            }
            
            float sceneDist(float clarity, float3 pos){
                float time = 2*_Time.x;
                pos.yz = rotate(pos.yz, time);
                pos.zx = rotate(pos.zx, time);
                pos.xy = rotate(pos.xy, time);
                pos = repeat(2, pos);
                pos.yz = rotate(pos.yz, _Time.y);
                pos.zx = rotate(pos.zx, _Time.y);
                pos.xy = rotate(pos.xy, _Time.y);
                return cubeDist(pos/_Size)*_Size;
            }
            
            ENDCG
        }
        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}