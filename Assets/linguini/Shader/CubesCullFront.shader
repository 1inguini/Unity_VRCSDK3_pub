Shader "linguini/RayMarching/CubesCullFront"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _BackGround ("BackGround", Color) = (0,0,0)
        _Size ("Size", Range(0,1)) = 0.5
        _Anim ("Animation", Range(0,1)) = 0
        _MaxDistance ("MaxDistance", Range(0,1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque"  "LightMode" = "ForwardBase" }
        LOD 100
        Cull Front

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
            
            struct fragout
            {
                fixed4 color : SV_Target;
                float depth : SV_Depth;
            };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;

            fixed4 _Color;
            fixed4 _BackGround;
            float _Size;
            float _Anim;
            float _MaxDistance;

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
                float3 q = abs(pos) - _Size/2;
                return length(max(q, 0)) //+ min(max(q.x, max(q.y, q.z)), 0)
                ;
            }

            float pillarZDist(float3 pos) {
                float3 q = float3(abs(pos.xy) - _Size/2, -abs(pos.z));
                return length(max(q,0));
            }

            float3 repeat(float3 pos){
                return abs(fmod(pos, _Size * 4)) - _Size * 2;
            }

            float2 rotate(float2 pos, float r) {
                float2x2 m = float2x2(cos(r), sin(r), -sin(r), cos(r));
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

            fragout frag (v2f i) : SV_Target
            {
                // float3 pos = mul(unity_WorldToObject, _WorldSpaceCameraPos);
                float3 pos = _WorldSpaceCameraPos;
                // レイの進行方向
                float3 rayDir = normalize(i.pos.xyz - pos);
                
                float maxDistance = 1000 * _MaxDistance * _Size;
                float minDistance = _Size * 0.0001;
                float marchingDist = sceneDist(pos); 
                
                fragout fout;
                float3 normal;
                float3 lightDir;
                float NdotL;
                float4 projectionPos;
                // [unroll]
                //  for (int i = 0; i < 60; i++) {
                    while (length(pos) < maxDistance) {
                        marchingDist = sceneDist(pos);
                        if (marchingDist < minDistance) {
                            // 法線
                            normal = getSceneNormal(pos);
                            // lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0);
                            lightDir = _WorldSpaceLightPos0;
                            //ランバート反射を計算
                            NdotL = max(0, dot(normal, lightDir));
                            fout.color = fixed4(_Color.xyz * NdotL + fixed3(0.1,0.1,0.1), _Color.a);

                            projectionPos = UnityObjectToClipPos(float4(pos, 1.0));
                            fout.depth = projectionPos.z / projectionPos.w;
                            return fout;
                        }
                        pos.xyz += marchingDist * rayDir.xyz;
                    }
                    fout.color = _BackGround;
                    return fout;
                }
                ENDCG
            }
        }
    }
