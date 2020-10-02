Shader "linguini/RayMarching/Menger"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        [MaterialToggle] _ShadowOn ("ShadowOn", Float) = 0 
        _BackGround ("BackGround", Color) = (0,0,0)
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
        _Resolution ("Resolution", Range(0,1)) = 0.3
        _CubeType ("CubeType", Int) = 0
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
            
            #pragma shader_feature OBJECT

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            float sceneDist(float3 pos);
            #include "Raymarching.cginc"

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
                uint maxLevel = _Resolution * 10;
                uint size = 3;
                float offset = 1;
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
                // return cube;
                // return dist;
                return max(cube, -dist);
                // return max(cube, -pillarXDist(pos)/9);
            }            

            float3 boxFold (float3 pos) {
                return clamp(pos, -1, 1) * 2 - pos;
            }

            float dot2 (float3 x) {
                return dot(x,x);
            }

            #define minRadius2 0.25
            #define fixedRadius2 1.9

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

            float sceneDist(float3 pos){
                return mengerDist(pos);
            }

            ENDCG
        }

        // Pass{
            //     Name "ShadowCaster"
            //     Tags { "LightMode" = "ShadowCaster" }
            //     Cull Back
            //     CGPROGRAM
            //     #pragma vertex vert
            //     #pragma fragment frag

            //     #pragma multi_compile_shadowcaster
            
            //     #include "UnityCG.cginc"


            //     fixed4 _Color;
            //     fixed4 _BackGround;
            //     float _Size;
            //     float _MaxDistance;
            //     float _MengerLevel;

            //     float min3(float x, float y, float z){
                //         return min(x, min(y, z));
            //     }

            //     struct v2f
            //     {
                //         // V2F_SHADOW_CASTER;
                //         float4 vertex : SV_POSITION;
                //         float4 pos : POSITION1;
            //     };

            //     v2f vert (appdata_base v)
            //     {
                //         v2f o;
                //         // TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                //         o.vertex = UnityClipSpaceShadowCasterPos(v.vertex, v.normal);
                //         // o.vertex = UnityObjectToClipPos(v.vertex);
                //         o.pos = v.vertex;
                //         // o.pos = mul(unity_ObjectToWorld, v.vertex);
                //         return o;
            //     }

            
            //     float cubeDist(float3 pos){
                //         float3 q = abs(pos) - _Size/2;
                //         return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0);
            //     }
            
            //     float pillarXDist(float3 pos) {
                //         pos = abs(pos);
                //         return max(pos.y, pos.z) - _Size/2;
            //     }
            //     float pillarYDist(float3 pos) {
                //         pos = abs(pos);
                //         return max(pos.z, pos.x) - _Size/2;
            //     }
            //     float pillarZDist(float3 pos) {
                //         pos = abs(pos);
                //         return max(pos.x, pos.y) - _Size/2;
            //     }

            //     float pillarXYZDist(float3 pos){
                //         return min3(
                //         pillarXDist(pos),
                //         pillarYDist(pos),
                //         pillarZDist(pos)
                //         );
            //     }
            
            //     float3 mengerizePos(float3 pos, float offset) {
                //         pos = abs(pos);

                //         pos -= offset/2;
                //         pos = abs(pos);
                //         pos += offset/2;

                //         pos -= offset;
                //         return pos;
            //     }

            //     float mengerDist(float3 pos) {
                //         float cube = cubeDist(pos);
                //         uint maxLevel = _MengerLevel * 10;
                //         uint size = 3;
                //         float offset = _Size;
                //         float dist = pillarXYZDist(pos*size)/size;
                //         float3 posX = pos, posY = pos, posZ = pos;

                //         for (uint level = 0; level < maxLevel; level++){
                    //             size *= 3;
                    //             offset /= 3;
                    //             pos = mengerizePos(pos, offset);
                    //             dist = min(dist, pillarXYZDist(pos*size)/size);
                //         }
                //         // return dist;
                //         return max(cube, -dist);
                //         // return max(cube, -pillarXDist(pos)/9);
            //     }

            //     float sceneDist(float3 pos) {
                //         //return cubeDist(pos);
                //         return mengerDist(pos);
                //         return (length(pos*0.1) - _Size/2)/0.1;
            //     }

            
            //     float raymarch(float3 pos, float3 rayDir) {
                //         float maxDistance = 100 * _Size * _MaxDistance;
                //         float minDistance = 0.0001;
                //         float marchingDist = sceneDist(pos); 
                
                //         while (length(pos) < maxDistance) {
                    //             marchingDist = sceneDist(pos);
                    //             if (abs(marchingDist) < minDistance) {
                        //                 return 1;
                    //             }
                    //             pos.xyz += marchingDist * rayDir.xyz;                                
                //         }
                //         return 0;
            //     }

            //     float frag (v2f i) : SV_DEPTH
            //     {
                //         // レイの進行方向
                //         float3 DirRayDir = ObjSpaceLightDir(i.pos);

                //         float3 PointPos = mul(unity_WorldToObject, float4(_WorldSpaceLightPos0.xyz, 1)).xyz; 
                
                //         return _WorldSpaceLightPos0.w? 
                //         raymarch(10 * -DirRayDir - i.pos.xyz, DirRayDir):
                //         raymarch(PointPos, normalize(i.pos.xyz - PointPos));
            //     }
            //     ENDCG
        // }
        
        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}

