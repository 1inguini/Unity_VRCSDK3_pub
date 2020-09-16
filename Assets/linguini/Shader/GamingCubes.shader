Shader "linguini/RayMarching/GamingCubes"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
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
        Tags { "RenderType" = "Opaque"  "LightMode" = "ForwardBase" }
        LOD 100
        Cull Off

        Pass
        {
            //アルファ値が機能するために必要
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                // UNITY_FOG_COORDS(1)
                float4 pos : POSITION1;
                float4 vertex : SV_POSITION;
            };
            
            // struct fragout
            // {
                //     fixed4 color : SV_Target;
                //     float depth : SV_Depth;
            // };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;

            fixed4 _BackGround;
            float _Size;
            float _MaxDistance;

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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                // //メッシュのワールド座標を代入
                o.pos = mul(unity_ObjectToWorld, v.vertex);
                //メッシュのローカル座標を代入
                // o.pos = v.vertex;
                o.uv = v.uv;
                return o;
            }

            float sphereDist(float3 pos){
                return length(pos) - _Size/2;
            }

            float cubeDist(float3 pos){
                return length(max(abs(pos) - _Size/2, 0));
            }

            float3 repeat(float3 pos){
                float size = _Size * 4;
                pos -= round(pos/ size) * _Size;
                return pos;
            }

            float2 rotate(float2 pos, float r) {
                float2x2 m = float2x2(cos(r),sin(r),-sin(r),cos(r)) ;
                return mul(pos,m);
            }

            float sceneDist(float3 pos){
                pos.yz = rotate(pos.yz, _Time.y/10);
                pos.zx = rotate(pos.zx, _Time.y/10);
                pos.xy = rotate(pos.xy, _Time.y/10);
                pos = repeat(pos);
                pos.yz = rotate(pos.yz, _Time.y);
                pos.zx = rotate(pos.zx, _Time.y);
                pos.xy = rotate(pos.xy, _Time.y);
                return cubeDist(pos);
            }

            float3 getSceneNormal(float3 pos){
                float EPS = 0.0001;
                return normalize(float3(
                sceneDist(pos + float3(EPS,0,0)) - sceneDist(pos + float3(-EPS,0,0)),
                sceneDist(pos + float3(0,EPS,0)) - sceneDist(pos + float3(0,-EPS,0)),
                sceneDist(pos + float3(0,0,EPS)) - sceneDist(pos + float3(0,0,-EPS))
                )
                );
            }
            
            fixed4 gaming (v2f i)
            {   
                float PI = 3.14159265;
                float xy = (i.uv.x + i.uv.y) * _Scale;
                fixed3 gaming_col = fixed3(
                _Red * (sin(_FreqR * (_Time.y + xy) / _Cycle) + 1) / 2,
                _Green * (sin(_FreqG * (_Time.y + xy) / _Cycle + PI * 2 / 3) + 1) / 2,
                _Blue * (sin(_FreqB * (_Time.y + xy) / _Cycle + PI * 4 / 3) + 1) / 2
                );
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed ave = (col.x + col.y + col.z) / 3;
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


            fixed4 raymarch(float3 pos, float3 rayDir, fixed4 col) {
                float3 normal;
                float3 lightDir;
                float NdotL;
                float4 projectionPos;
                float maxDistance = 1000 * _MaxDistance * _Size;
                float minDistance = _Size * 0.001;
                float marchingDist; 
                while (length(pos) < maxDistance) {
                    marchingDist = sceneDist(pos);
                    if (marchingDist < minDistance && -minDistance < marchingDist) {
                        // 法線
                        normal = getSceneNormal(pos);
                        //ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
                        lightDir = normalize(mul(unity_WorldToObject,_WorldSpaceLightPos0)).xyz;
                        //ランバート反射を計算
                        NdotL = max(0, dot(normal, lightDir));
                        return fixed4(col.xyz * NdotL + fixed3(0.1,0.1,0.1), col.a);
                    }
                    pos.xyz += marchingDist * rayDir.xyz;
                }
                return _BackGround;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //     // sample the texture
                //     fixed4 col = tex2D(_MainTex, i.uv);
                //     // apply fog
                //     UNITY_APPLY_FOG(i.fogCoord, col);
                //     return col;
                
                // レイの初期位置(ピクセルのローカル座標)
                // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
                float3 pos = _WorldSpaceCameraPos;
                // レイの進行方向
                
                float3 rayDir = normalize(i.pos.xyz - pos);
                fixed4 col = gaming(i);
                // = sceneDist(pos);

                return raymarch(pos, rayDir, col);
            }
            ENDCG
        }
    }
}
