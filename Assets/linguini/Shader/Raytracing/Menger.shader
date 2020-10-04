//  Copyright (c) 2020 linguini. MIT license

Shader "linguini/Raytracing/Menger"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1)
        _MaxDistance ("MaxDistance", Range(0,1)) = 0.1
    }
    SubShader
    {
        Pass
        {
            Name "Raytrace"
            Tags { "LightMode" = "ForwardBase" }
            LOD 100
            Cull Front
            ZWrite On

            //アルファ値が機能するために必要
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
            #pragma exclude_renderers gles
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            // #define WORLD
            #define OBJECT

            fixed4 _Color;
            float _MaxDistance;
            
            #define EPS 0.0001
            #define INF 3.402823466e+38
            #define MAXDISTANCE 1000*_MaxDistance

            #define MENGER_ITER 4

            float4x4 IDMAT4 = {
                {1,0,0,0}, 
                {0,1,0,0},
                {0,0,1,0},
                {0,0,0,1}
            };
            
            float min3(float x, float y, float z){
                return min(x, min(y, z));
            }
            float min3(float3 xyz) {
                return min3(xyz.x, xyz.y, xyz.z);
            }

            float max3(float x, float y, float z){
                return max(x, max(y, z));
            }
            float max3(float3 xyz) {
                return max3(xyz.x, xyz.y, xyz.z);
            }
            
            float square(float x) {
                return x*x;
            }
            float square(float3 v) {
                return dot(v,v);
            }

            float4x4 shiftMatrix(float x, float y, float z) {
                float4x4 mat = 0;
                mat[0][3] = x;
                mat[1][3] = y;
                mat[2][3] = z;
                mat[3][3] = 1;
                // mat[3] = float4(pos,1);
                return mat; // + float4x4(0,0,0,pos.x, 0,0,0,pos.y, 0,0,0,pos.z, 0,0,0,0)
            }
            float4x4 shiftMatrix(float3 pos) {
                return shiftMatrix(pos.x, pos.y, pos.z);
            }

            float4x4 scaleMatrix(float x, float y, float z) {
                float4x4 mat = 0;
                mat[0][0] = x;
                mat[1][1] = y;
                mat[2][2] = z;
                mat[3][3] = 1;
                return mat;
            }
            float4x4 scaleMatrix(float3 scale) {
                return scaleMatrix(scale.x, scale.y, scale.z);
            }
            
            float4x4 scaleLocalMatrix(float4x4 mat, float x, float y, float z) {
                mat[0][0] *= x;
                mat[3][0] /= x;

                mat[1][1] *= y;
                mat[3][1] /= y;
                
                mat[2][2] *= z;
                mat[3][2] /= z;
                return mat;
            }
            float4x4 scaleLocalMatrix(float4x4 mat, float3 scale) {
                return scaleLocalMatrix(mat, scale.x, scale.y, scale.z);
            }

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : POSITION1;
                float4 vertex : SV_POSITION;
                // float2 cantorHoles[pow(2, MENGER_ITER)] : CANTOR;
            };

            struct fragout
            {
                float4 color : SV_Target;
                float depth : SV_Depth;
            };
            
            struct rayDef {
                float3 pos;
                float3 dir;
            };

            rayDef mkray(float3 pos, float3 dir) {
                rayDef o;
                o.pos = pos;
                o.dir = dir;
                return o;
            }

            struct movedRay{
                rayDef ray;
                float correction;
            };            
            
            movedRay matrixApply(float4x4 mat, rayDef ray) {
                movedRay o;
                // mat = inverse(mat);
                o.ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                o.ray.dir = mul(mat, ray.dir);
                o.correction = length(o.ray.dir);
                o.ray.dir /= o.correction;
                return o;
            }

            struct intersection {
                bool intersect;
                float t;
                float3 normal;
            };

            #define NORMAL_FUNC(_bodyName) float3 _bodyName##Normal(float3 pos) { \
                float def = _bodyName##Def(pos); \
                return normalize(float3( \
                _bodyName##Def(pos + float3(EPS,0,0)) - def, \
                _bodyName##Def(pos + float3(0,EPS,0)) - def, \
                _bodyName##Def(pos + float3(0,0,EPS)) - def \
                ) \
                ); \
            }
            
            float3 getPos(float t, rayDef ray) {
                return t*ray.dir + ray.pos;
            }

            float cubeDef(float3 pos) {
                return max3(abs(pos)) - 0.5;
            }
            NORMAL_FUNC(cube)

            // intersection cube(rayDef ray) {
                //     float2 buf;
                //     float2 range;
                //     float3 tmin, tmax;
                
                //     #define SOLVE(i) \
                //     buf = (range - ray.pos.i)/ray.dir.i; \
                //     tmin.i = min(buf[0], buf[1]); \
                //     tmax.i = max(buf[0], buf[1]);
                
                //     range = float2(-1,1) * 0.5;
                //     SOLVE(x)
                //     SOLVE(y)
                //     SOLVE(z)
                //     #undef SOLVE
                //     range = float2(max3(tmin), min3(tmax));
                //     intersection o;
                //     o.intersect = 0 <= range[0] && range[0] < range[1];
                //     o.t = !o.intersect? INF: range[0];
                //     o.normal = cubeNormal(getPos(o.t, ray));
                //     return o;
            // }
            
            bool inBound(float2 range, float x) {
                return range[0] <= x && x <= range[1];
            }
            
            bool inBound2(float2 range, float x0, float x1) {
                return inBound(range, x0) && inBound(range, x1);
            }
            bool inBound2(float2 range, float2 x) {
                return inBound2(range, x[0], x[1]);
            }
            bool inBound2(float range0, float range1, float2 x) {
                return inBound2(float2(range0, range1), x[0], x[1]);
            }

            bool inBound3(float2 range, float3 pos) {
                return 
                inBound(range, pos.x) &&
                inBound(range, pos.y) &&
                inBound(range, pos.z);
            }

            bool inBound2x2(float2 range, float2 xy0, float2 xy1) {
                return 
                inBound2(range, xy0.x, xy1.x) &&
                inBound2(range, xy0.y, xy1.y);
            }

            intersection yzinBoundWhenX(float2 range, rayDef ray, float x) {
                intersection o;
                
                float2 buf;
                buf[0] = ray.dir.x? 
                (ray.dir.y/ray.dir.x)*(x - ray.pos.x) + ray.pos.y: 
                ray.pos.y; 

                buf[1] = ray.dir.x?
                (ray.dir.z/ray.dir.x)*(x - ray.pos.x) + ray.pos.z:
                ray.pos.z;
                
                o.intersect = inBound2(range, buf);
                o.t = ray.dir.x?
                (x - ray.pos.x)/ray.dir.x:
                (ray.dir.y?
                (buf[0] - ray.pos.y)/ray.dir.y:
                (buf[1] - ray.pos.z)/ray.dir.z
                );
                o.normal = float3(sign(x),0,0);
                return o;
            }
            intersection zxinBoundWhenY(float2 range, rayDef ray, float y) {
                intersection o;
                ray.pos = ray.pos.yzx;
                ray.dir = ray.dir.yzx;
                o = yzinBoundWhenX(range, ray, y);
                o.normal.yzx = o.normal;
                return o;
            }
            intersection xyinBoundWhenZ(float2 range, rayDef ray, float z) {
                intersection o;
                ray.pos = ray.pos.zxy;
                ray.dir = ray.dir.zxy;
                o = yzinBoundWhenX(range, ray, z);
                o.normal.zxy = o.normal;
                return o;
            }

            intersection cube(rayDef ray) {
                intersection o[6];
                float2 range = float2(-1,1)*0.3;
                o[0] = yzinBoundWhenX(range, ray, range[0]);
                o[1] = yzinBoundWhenX(range, ray, range[1]);
                o[2] = zxinBoundWhenY(range, ray, range[0]); 
                o[3] = zxinBoundWhenY(range, ray, range[1]);
                o[4] = xyinBoundWhenZ(range, ray, range[0]);
                o[5] = xyinBoundWhenZ(range, ray, range[1]);
                [unroll] for (uint i = 1; i < 6; i++) {
                    o[0] = o[i*(!o[0].intersect || (o[i].intersect && o[i].t < o[0].t))];
                }
                return o[0];
            }


            float getT(rayDef ray, float3 pos) {
                return ray.dir.x?
                (pos.x - ray.pos.x)/ray.dir.x:
                (ray.dir.y?
                (pos.y - ray.pos.y)/ray.dir.y:
                (pos.z - ray.pos.z)/ray.dir.z
                );
            }
            float getTorINF(rayDef ray, float3 pos) {
                float t = getT(ray, pos);
                return t < 0? INF: t;
            }

            float3 posFromX(float x, rayDef ray) {
                float3 pos;
                pos.x = x;

                pos.y = ray.dir.x? 
                (ray.dir.y/ray.dir.x)*(x - ray.pos.x) + ray.pos.y: 
                ray.pos.y; 

                pos.z = ray.dir.x?
                (ray.dir.z/ray.dir.x)*(x - ray.pos.x) + ray.pos.z:
                ray.pos.z;
                return pos;
            }
            float3 posFromY(float y, rayDef ray) {
                float3 pos;
                ray.pos = ray.pos.yzx;
                ray.dir = ray.dir.yzx;
                pos.yzx = posFromX(y, ray);
                return pos;
            }
            float3 posFromZ(float z, rayDef ray) {
                float3 pos;
                ray.pos = ray.pos.zxy;
                ray.dir = ray.dir.zxy;
                pos.zxy = posFromX(z, ray);
                return pos;
            }
            float3 posFromXYZ(uint switchXYZ, float n, rayDef ray) {
                float3 pos;
                uint3 i;
                i.x = switchXYZ;
                i.y = (i.x + 1) % 3;
                i.z = (i.x + 2) % 3;
                
                pos[i.x] = n;
                
                pos[i.y] = ray.dir[i.x]? 
                (ray.dir[i.y]/ray.dir[i.x])*(pos[i.x] - ray.pos[i.x]) + ray.pos[i.y]: 
                ray.pos[i.y]; 

                pos[i.z] = ray.dir[i.x]?
                (ray.dir[i.z]/ray.dir[i.x])*(pos[i.x] - ray.pos[i.x]) + ray.pos[i.z]:
                ray.pos[i.z];
                return pos;
            }

            bool posInBound(float3x2 bound, float3 pos) {
                return
                inBound(bound[0], pos.x) &&
                inBound(bound[1], pos.y) &&
                inBound(bound[2], pos.z)
                ;
            }

            intersection planeYZ(float2 bound, float x, rayDef ray) {
                intersection o;
                float3 pos;
                pos = posFromX(x, ray);

                o.t = getT(ray, pos);
                o.intersect = 0 <= o.t && inBound2(bound, pos.yz);
                o.normal = normalize(float3(sign(x),0,0));
                return o;
            }
            intersection planeZX(float2 bound, float y, rayDef ray) {
                intersection o;
                ray.pos = ray.pos.yzx;
                ray.dir = ray.dir.yzx;
                o = planeYZ(bound, y, ray);
                o.normal.yzx = o.normal;
                return o;
            }
            intersection planeXY(float2 bound, float z, rayDef ray) {
                intersection o;
                ray.pos = ray.pos.zxy;
                ray.dir = ray.dir.zxy;
                o = planeYZ(bound, z, ray);
                o.normal.zxy = o.normal;
                return o;
            }


            intersection or(intersection i[2]) {
                return i[i[1].t < i[0].t];
            }
            intersection or(intersection i0, intersection i1) {
                intersection i[2] = { i0, i1 };
                return or(i);
            }

            float2x2 nextCantorHoles(float2 hole) {
                float range = (hole[1] - hole[0])/3.0;
                float2x2 o = {
                    { hole[0] - 2*range, hole[0] - range },
                    { hole[1] + range, hole[1] + 2*range }
                };
                return o;
            }

            struct cantorHolesWrapper {
                float2 cantorHoles[pow(2, MENGER_ITER)];
            };

            cantorHolesWrapper initCantorHoles() {
                cantorHolesWrapper noCantorHoles;
                [unroll] for (int i = 0; i < pow(2, MENGER_ITER); i++) {
                    noCantorHoles.cantorHoles[i] = 0;
                }
                noCantorHoles.cantorHoles[0] = float2(-1,1)*0.5/3.0;
                int origin = 1; 
                float2x2 nextHoles;
                [unroll] for (int level = 0; level < MENGER_ITER; level++) {
                    [unroll] for (int i = 0; i < pow(2, level); i++) {
                        nextHoles = nextCantorHoles(noCantorHoles.cantorHoles[origin-i]);
                        noCantorHoles.cantorHoles[origin + 2*i] = nextHoles[0];
                        noCantorHoles.cantorHoles[origin + 2*i + 1] = nextHoles[1];
                    }
                    origin += pow(2, level);
                }
                return noCantorHoles;
            }

            inline float tOrINF(intersection i) {
                return i.intersect? i.t: INF;
            }

            bool or3(bool3 b) {
                return b.x || b.y || b.z;
            }
            
            intersection menger(rayDef ray) {
                uint length = pow(2, MENGER_ITER);
                intersection o;
                float2 bound = float2(-1, 1)*0.5;
                float2 xy[2], yz[2], zx[2];

                o.intersect = false;
                o.t = INF;
                o.normal = float3(1,0,0);

                float2 holes[pow(2, MENGER_ITER)-1];
                holes[0] = bound/3.0;
                uint origin = 1; 
                float2x2 nextHoles;
                for (int level = 1; level < MENGER_ITER; level++) {
                    for (int i = 0; i < pow(2, level - 1); i++) {
                        nextHoles = nextCantorHoles(holes[origin-(i+1)]);
                        holes[origin + 2*i] = nextHoles[0];
                        holes[origin + 2*i + 1] = nextHoles[1];
                    }
                    origin += pow(2, level);
                }
                // holes[pow(2, MENGER_ITER)-1] = bound;
                
                float faceDir;
                float3 pos;
                intersection next;
                float3x2 bound3D;
                [unroll] for (int i = 0; i < 2; i++) {
                    [unroll] for (int xyz = 0; xyz < 3; xyz++) {
                        pos = posFromXYZ(xyz, bound[i], ray);
                        
                        next.t = getTorINF(ray, pos);
                        next.intersect = 
                        inBound(bound, pos[(xyz+1)%3]) &&
                        inBound(bound, pos[(xyz+2)%3]);

                        for (int hole0 = 0; hole0 < pow(2, MENGER_ITER)-1; hole0++){
                            for (int hole1 = 0; hole1 < pow(2, MENGER_ITER)-1; hole1++){
                                next.intersect = next.intersect &&
                                !(
                                inBound(holes[hole0], pos[(xyz+1)%3]) ||
                                inBound(holes[hole1], pos[(xyz+2)%3])
                                );
                            }
                        }
                        next.normal = 0;
                        next.normal[xyz] = 1; 
                        
                        // will next replace o?
                        next.intersect = next.intersect && next.t < o.t;

                        o.t = next.intersect? next.t: o.t;
                        o.normal = next.intersect? next.normal: o.normal;
                        o.intersect = next.intersect || o.intersect;
                    }
                }
                [unroll] for (int layer = 0; layer < pow(2, MENGER_ITER)-1; layer++) {
                    [unroll] for (int i = 0; i < 2; i++) {
                        [unroll] for (int xyz = 0; xyz < 3; xyz++) {
                            pos = posFromXYZ(xyz, holes[layer][i], ray);
                            
                            next.t = getTorINF(ray, pos);
                            next.intersect = 
                            inBound(bound, pos[(xyz+1)%3]) &&
                            inBound(bound, pos[(xyz+2)%3]);

                            for (int hole0 = 0; hole0 < pow(2, MENGER_ITER)-1; hole0++){
                                for (int hole1 = 0; hole1 < pow(2, MENGER_ITER)-1; hole1++){
                                    next.intersect = next.intersect &&
                                    !(
                                    inBound(holes[hole0], pos[(xyz+1)%3]) ||
                                    inBound(holes[hole1], pos[(xyz+2)%3])
                                    );
                                }
                            }
                            next.normal = 0;
                            next.normal[xyz] = -2*(i % 2) + 1; 
                            
                            // will next replace o?
                            next.intersect = next.intersect && next.t < o.t;

                            o.t = next.intersect? next.t: o.t;
                            o.normal = next.intersect? next.normal: o.normal;
                            o.intersect = next.intersect || o.intersect;
                        }
                    }
                }
                return o;
                // return planeXY(bound, bound[1], ray);

                // bool doReplace;
                // [unroll] for (uint i = 0; i < 3; i++) {
                    //     [unroll] for (uint j = 0; j < 4; j++) {
                        //         doReplace =
                        //         !(o[0][0].intersect && 0 <= o[0][0].t) ||
                        //         (o[i][j].intersect && 0 <= o[i][j].t && o[i][j].t < o[0][0].t);
                        
                        //         o[0][0] = o[i*doReplace][j*doReplace];
                    //     }
                // }
                // return o[0][0];
            }


            fixed4 lighting(float3 pos, float3 normal, fixed shadow, fixed4 col) {
                float3 lightDir;
                #ifdef WORLD
                    lightDir = _WorldSpaceLightPos0.xyz;
                #elif defined(OBJECT)
                    //ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
                    lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
                #else
                    lightDir = normalize(float3(1,-1,0));
                #endif

                // lightDir = normalize(mul(unity_WorldToObject,_WorldSpaceLightPos0)).xyz;
                float NdotL = saturate(dot(normal, lightDir));

                float3 lightProbe = ShadeSH9(fixed4(UnityObjectToWorldNormal(normal), 1));

                float3 lighting = lerp(lightProbe, _LightColor0, NdotL);
                
                float3 ambient = Shade4PointLights(
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

                return fixed4(shadow * lighting * col.rgb + (ambient? ambient: 0.1), col.a);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                #if defined(WORLD)
                    // メッシュのワールド座標を代入
                    o.pos = mul(unity_ObjectToWorld, v.vertex);
                #elif defined(OBJECT)
                    // メッシュのローカル座標を代入
                    o.pos = v.vertex;
                #else
                    o.pos = v.vertex;
                #endif
                // o.uv = v.uv;
                // cantorHolesWrapper c = initCantorHoles();
                // o.cantorHoles = c.cantorHoles;
                return o;
            }


            //fragout frag (v2f i)
            fragout frag (v2f i)
            {
                fragout o;
                
                rayDef ray;
                
                // float3 pos;
                #if defined(WORLD)
                    ray.pos = _WorldSpaceCameraPos;
                #elif defined(OBJECT)
                    // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
                    ray.pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                #else
                    ray.pos = 0;
                #endif
                

                // レイの進行方向
                ray.dir = normalize(i.pos.xyz - ray.pos);
                

                intersection p = menger(ray);

                if(!p.intersect) discard;
                
                float4 pos = float4(getPos(p.t, ray) , 1); 
                // float4 pos = float4(p.pos, 1); 
                float4 projectionPos;
                #if defined(WORLD)
                    projectionPos = UnityWorldToClipPos(pos);
                #elif defined(OBJECT)
                    projectionPos = UnityObjectToClipPos(pos);
                #else
                    projectionPos = 1;
                #endif

                o.depth = projectionPos.z / projectionPos.w;
                o.color = lighting(pos, p.normal, 1, _Color);
                return o;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        // UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}