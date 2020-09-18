Shader "linguini/RayMarching/Menger"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _BackGround ("BackGround", Color) = (0,0,0)
        _Size ("Size", Range(0,1)) = 1
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
        _MengerLevel ("MengerLevel", Range(0,1)) = 0.3
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

            fixed4 _Color;
            fixed4 _BackGround;
            float _Size;
            float _MaxDistance;
            float _MengerLevel;

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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                // //メッシュのワールド座標を代入
                // o.pos = mul(unity_ObjectToWorld, v.vertex);
                //メッシュのローカル座標を代入
                o.pos = v.vertex;
                o.uv = v.uv;
                return o;
            }

            float min3(float x, float y, float z){
                return min(x, min(y, z));
            }

            
            float3 repeat(float3 pos){
                float size = _Size * 4;
                pos -= round(pos/ size) * _Size;
                return pos;
            }

            float2 rotate(float2 pos, float r) {
                float2x2 m = float2x2(cos(r), sin(r), -sin(r), cos(r));
                return mul(pos,m);
            }

            float2 rotate90(float2 pos){
                float2x2 m = float2x2(0,1,-1,0);
                return mul(m, pos);
            }

            float2 rotate45(float2 pos){
                float x = pow(2, 1/2) / 2;
                float2x2 m = float2x2(x,x,-x,x);
                return mul(m, pos);
            }

            
            float sphereDist(float3 pos){
                return length(pos) - _Size/2;
            }

            float cubeDist(float3 pos){
                float3 q = abs(pos) - _Size/2;
                return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0);
            }
            
            float pillarXDist(float3 pos) {
                pos = abs(pos);
                return max(pos.y, pos.z) - _Size/2;
            }
            float pillarYDist(float3 pos) {
                pos = abs(pos);
                return max(pos.z, pos.x) - _Size/2;
            }
            float pillarZDist(float3 pos) {
                pos = abs(pos);
                return max(pos.x, pos.y) - _Size/2;
            }

            float pillarXYZDist(float3 pos){
                return min3(
                pillarXDist(pos),
                pillarYDist(pos),
                pillarZDist(pos)
                );
            }
            
            float3 mengerizeXPos(float3 pos, float offset) {
                pos.yz = abs(pos.yz);

                pos.yz -= offset/2;
                pos.yz = abs(pos.yz);
                pos.yz += offset/2;

                pos.yz -= offset;
                return pos;
            }
            float3 mengerizeYPos(float3 pos, float offset) {
                pos.zx = abs(pos.zx);

                pos.zx -= offset/2;
                pos.zx = abs(pos.zx);
                pos.zx += offset/2;

                pos.zx -= offset;
                return pos;
            }
            float3 mengerizeZPos(float3 pos, float offset) {
                pos.xy = abs(pos.xy);

                pos.xy -= offset/2;
                pos.xy = abs(pos.xy);
                pos.xy += offset/2;

                pos.xy -= offset;
                return pos;
            }
            float3 mengerizePos(float3 pos, float offset) {
                pos = abs(pos);

                pos -= offset/2;
                pos = abs(pos);
                pos += offset/2;

                pos -= offset;
                return pos;
            }

            float mengerDist(float3 pos) {
                float cube = cubeDist(pos);
                uint maxLevel = _MengerLevel * 10;
                uint size = 3;
                float offset = _Size;
                float dist = pillarXYZDist(pos*size)/size;
                float3 posX = pos, posY = pos, posZ = pos;

                for (uint level = 0; level < maxLevel; level++){
                    size *= 3;
                    offset /= 3;
                    // posX = mengerizeXPos(posX, offset);
                    // posY = mengerizeYPos(posY, offset);
                    // posZ = mengerizeZPos(posZ, offset);
                    // dist = min(dist, min3(
                    // pillarXDist(posX*size)/size,
                    // pillarYDist(posY*size)/size,
                    // pillarZDist(posZ*size)/size
                    // ));
                    pos = mengerizePos(pos, offset);
                    dist = min(dist, pillarXYZDist(pos*size)/size);
                }
                // return dist;
                return max(cube, -dist);
                // return max(cube, -pillarXDist(pos)/9);
            }
            
            float sceneDist(float3 pos){
                return mengerDist(pos);
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

            fragout raymarch(float3 pos, float3 rayDir) {
                float maxDistance = 1000 * _Size * _MaxDistance;
                float minDistance = 0.0001;
                float marchingDist = sceneDist(pos); 
                
                fragout fout;
                
                float3 normal;
                float3 lightDir;
                float NdotL;
                fixed3 lightColor, lightProbe, lighting, ambient;
                float4 projectionPos;
                // [unroll]
                // for (int i = 0; i < 30; i++) {
                    while (length(pos) < maxDistance) {
                        marchingDist = sceneDist(pos);
                        if (marchingDist < minDistance && -minDistance < marchingDist) {
                            //ランバート反射を計算
                            // 法線
                            normal = getSceneNormal(pos);
                            //ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
                            lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;

                            // lightDir = normalize(mul(unity_WorldToObject,_WorldSpaceLightPos0)).xyz;
                            NdotL = saturate(dot(normal, lightDir));

                            lightProbe = ShadeSH9(fixed4(UnityObjectToWorldNormal(normal), 1));

                            lighting = lerp(lightProbe, _LightColor0, NdotL);
                            
                            ambient = Shade4PointLights(
                            unity_4LightPosX0, 
                            unity_4LightPosY0, 
                            unity_4LightPosZ0,
                            unity_LightColor[0].rgb, 
                            unity_LightColor[1].rgb, 
                            unity_LightColor[2].rgb, 
                            unity_LightColor[3].rgb,
                            unity_4LightAtten0, 
                            pos, 
                            normal);
                            
                            fout.color = fixed4(lighting * _Color.rgb + (ambient? ambient: 0.1), _Color.a);
                            //fout.color = _Color;

                            projectionPos = UnityObjectToClipPos(float4(pos, 1.0));
                            fout.depth = projectionPos.z / projectionPos.w;
                            return fout;
                        }
                        pos.xyz += marchingDist * rayDir.xyz;                                
                    }
                    
                // }
                discard;
                fout.color = _BackGround;
                return fout;
            }

            fragout frag (v2f i)
            {
                // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
                float3 pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                //float3 pos = _WorldSpaceCameraPos;
                // レイの進行方向
                float3 rayDir = normalize(i.pos.xyz - pos);
                return raymarch(pos, rayDir);
            }
            ENDCG
        }
        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/SHADOWCASTER"
    }
}

