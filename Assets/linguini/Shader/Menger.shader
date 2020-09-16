Shader "linguini/RayMarching/Menger"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _BackGround ("BackGround", Color) = (0,0,0)
        _Size ("Size", Range(0,1)) = 1
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
    }
    SubShader
    {
        Tags { "LightMode" = "ForwardBase" }
        LOD 100
        Cull Front
        ZWrite On

        Pass
        {
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
                return abs(fmod(pos, _Size * 4)) - _Size * 2;
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

            float fillDist(float3 pos) {
                return 0;
            }
            
            float mengerRec(float3 pos, uint level, uint maxLevel) {
                float size = _Size/pow(3,level);
                float offset = _Size/pow(3, level - 1);
                
                pos.yz = abs(pos.yz);

                pos.yz -= offset/2;
                pos.yz = abs(pos.yz);
                pos.yz += offset/2;

                pos.yz -= offset;

                float x = pillarXDist(pos*size)/size;
                return level < maxLevel ?
                min(
                x,
                mengerRec(pos, level + 1, maxLevel)
                ):
                x
                ;
            }

            float mengerTail(float3 pos, uint level, uint maxLevel, float accm) {
                float size = _Size/pow(3,level);
                float offset = _Size/pow(3, level - 1);

                pos.yz = abs(pos.yz);

                pos.yz -= offset/2;
                pos.yz = abs(pos.yz);
                pos.yz += offset/2;

                pos.yz -= offset;
                
                float dist = min(accm, pillarXDist(pos));

                return level < maxLevel ?
                mengerTail(pos, level++, maxLevel, dist):
                dist;
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


            float mengerDist(float3 pos) {
                float cube = cubeDist(pos);
                uint size = 3;
                float offset = _Size;
                float dist = pillarZDist(pos*size)/size;
                float3 posX = pos, posY = pos, posZ = pos;

                for (uint level = 0; level < 3; level++){
                    size *= 3;
                    offset /= 3;
                    posX = mengerizeXPos(posX, offset);
                    posY = mengerizeYPos(posY, offset);
                    posZ = mengerizeZPos(posZ, offset);
                    dist = min(dist, min3(
                    pillarXDist(posX*size)/size,
                    pillarYDist(posY*size)/size,
                    pillarZDist(posZ*size)/size
                    ));
                }
                //return dist;
                return max(cube, -dist);
                // return max(cube, -pillarXDist(pos)/9);
            }
            
            // int fib (int num) {
                //         return num <= 0 ?
                //         0 :(
                //             num == 1?
                //             1:
                //             fib(num-2) + fib(num-1);
                //         );
            // }

            // int fibTail (int num, int accm0 = 0, int accm1 = 1) {
                //     return num <= 0 ?
                //     accm0 :(
                //     num == 1? 
                //     accm1:
                //     fibTail(num--, accm1, accm0 + accm1)
                //     );
            // }

            
            // float mengerDist(float3 pos){
                //     float offset;
                //     float3 pos0,pos1,pos2;
                //     float x0,x1,x2;
                //     float x;
                //     for(;;){
                    //         offset = _Size / pow(3, level - 1);
                    //         pos2 = abs(pos);
                    //         pos0 = pos2 - float3(0,offset,0);
                    //         x0 = pillarXDist(pos0);
                    //         pos1 = pos2 - float3(0,0,offset);
                    //         x1 = pillarXDist(pos1);
                    //         pos2 = pos2 - float3(0,offset,offset);
                    //         x2 = pillarXDist(pos2);
                    //         x = min3(x0, x1, x2);
                    //         if (maxLevel < level){
                        //             return x;
                    //         }
                    //         pos = 
                //     }
                //     return 0;
            // }

            // float mengerDist(float3 pos){
                //     float cube = cubeDist(pos);
                //     float ret;
                //     float p0 = pillarXDist(pos * pow(3,1)) / pow(3,1);
                //     float3 posy = pos;
                //     float3 posz = pos;
                //     float offset = _Size;
                //     int level = 3;
                //     for (int i = 0; i < 4; i++){
                    //             level *= 3;
                    //             offset /= 3;
                    //             posy = pos;
                    //             posz = pos;
                    //             posy -= float3(0,offset,0);
                    //             posz -= float3(0,0,offset);
                    //             pos = posy;
                    //             p0 = min(
                    //                 //min(
                    //                     p0,
                    //                 //    pillarXDist(posx*level)/level
                    //                 //    ),
                    //                 min(
                    //                     pillarXDist(posy*level)/level,
                    //                     pillarXDist(posz*level)/level
                    //                     )
                    //                 );
                //     }
                //     // return p0;
                //     return max(cube,-p0);
            // }            


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
                float maxDistance = 100 * _Size * _MaxDistance;
                float minDistance = _Size * 0.001;
                float marchingDist = sceneDist(pos); 
                
                fragout fout;
                
                float3 normal;
                float3 lightDir;
                float NdotL;
                float4 projectionPos;
                // [unroll]
                // for (int i = 0; i < 30; i++) {
                    while (length(pos) < maxDistance) {
                        marchingDist = sceneDist(pos);
                        if (marchingDist < minDistance && -minDistance < marchingDist) {
                            // 法線
                            normal = getSceneNormal(pos);
                            lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0);
                            // lightDir = _WorldSpaceLightPos0;
                            //ランバート反射を計算
                            NdotL = dot(normal, lightDir);
                            fout.color = fixed4(_Color.xyz * NdotL, _Color.a);
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
    }
}
