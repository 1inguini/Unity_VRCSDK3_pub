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

            // float4x4 scaleGloballyMatrix(float4x4 mat, float x, float y, float z) {
                //     mat[0][0] *= x;
                //     mat[3][0] *= x;

                //     mat[1][1] *= y;
                //     mat[3][1] *= y;
                
                //     mat[2][2] *= z;
                //     mat[3][2] *= z;
                //     return mat;
            // }
            // float4x4 scaleGloballyMatrix(float4x4 mat, float3 scale) {
                //     return scaleGloballyMatrix(mat, scale.x, scale.y, scale.z);
            // }
            
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
            
            bool inRange(float2 range, float x) {
                return range[0] <= x && x <= range[1];
            }
            
            bool inRange2(float2 range, float x0, float x1) {
                return inRange(range, x0) && inRange(range, x1);
            }
            bool inRange2(float2 range, float2 x) {
                return inRange2(range, x[0], x[1]);
            }
            
            bool inRange3(float2 range, float3 pos) {
                return 
                inRange(range, pos.x) &&
                inRange(range, pos.y) &&
                inRange(range, pos.z);
            }

            bool inRange2x2(float2 range, float2 xy0, float2 xy1) {
                return 
                inRange2(range, xy0.x, xy1.x) &&
                inRange2(range, xy0.y, xy1.y);
            }

            intersection yzinRangeWhenX(float2 range, rayDef ray, float x) {
                intersection o;
                
                float2 buf;
                buf[0] = ray.dir.x? 
                (ray.dir.y/ray.dir.x)*(x - ray.pos.x) + ray.pos.y: 
                ray.pos.y; 

                buf[1] = ray.dir.x?
                (ray.dir.z/ray.dir.x)*(x - ray.pos.x) + ray.pos.z:
                ray.pos.z;
                
                o.intersect = inRange2(range, buf);
                o.t = ray.dir.x?
                (x - ray.pos.x)/ray.dir.x:
                (ray.dir.y?
                (buf[0] - ray.pos.y)/ray.dir.y:
                (buf[1] - ray.pos.z)/ray.dir.z
                );
                o.normal = float3(sign(x),0,0);
                return o;
            }
            intersection zxinRangeWhenY(float2 range, rayDef ray, float y) {
                intersection o;
                ray.pos = ray.pos.yzx;
                ray.dir = ray.dir.yzx;
                o = yzinRangeWhenX(range, ray, y);
                o.normal.yzx = o.normal;
                return o;
            }
            intersection xyinRangeWhenZ(float2 range, rayDef ray, float z) {
                intersection o;
                ray.pos = ray.pos.zxy;
                ray.dir = ray.dir.zxy;
                o = yzinRangeWhenX(range, ray, z);
                o.normal.zxy = o.normal;
                return o;
            }

            intersection cube(rayDef ray) {
                intersection o[6];
                float2 range = float2(-1,1)*0.5;
                o[0] = yzinRangeWhenX(range, ray, range[0]);
                o[1] = yzinRangeWhenX(range, ray, range[1]);
                o[2] = zxinRangeWhenY(range, ray, range[0]); 
                o[3] = zxinRangeWhenY(range, ray, range[1]);
                o[4] = xyinRangeWhenZ(range, ray, range[0]);
                o[5] = xyinRangeWhenZ(range, ray, range[1]);
                [unroll] for (uint i = 1; i < 6; i++) {
                    o[0] = o[i*(!o[0].intersect || (o[i].intersect && o[i].t < o[0].t))];
                }
                return o[0];
            }

            intersection donutYZWhenX(rayDef ray, float4 rangeWithHole, float faceDir, float x) {
                intersection o;
                
                float2 buf;
                buf[0] = ray.dir.x? 
                (ray.dir.y/ray.dir.x)*(x - ray.pos.x) + ray.pos.y: 
                ray.pos.y; 

                buf[1] = ray.dir.x?
                (ray.dir.z/ray.dir.x)*(x - ray.pos.x) + ray.pos.z:
                ray.pos.z;
                
                o.intersect = 
                inRange2(float2(rangeWithHole[0], rangeWithHole[3]), buf) && 
                !inRange2(float2(rangeWithHole[1], rangeWithHole[2]), buf);
                o.t = ray.dir.x?
                (x - ray.pos.x)/ray.dir.x:
                (ray.dir.y?
                (buf[0] - ray.pos.y)/ray.dir.y:
                (buf[1] - ray.pos.z)/ray.dir.z
                );
                o.normal = float3(faceDir,0,0);
                return o;
            }
            intersection donutZXWhenY(rayDef ray, float4 rangeWithHole, float faceDir, float y) {
                intersection o;
                ray.pos = ray.pos.yzx;
                ray.dir = ray.dir.yzx;
                o = donutYZWhenX(ray, rangeWithHole, faceDir, y);
                o.normal.yzx = o.normal;
                return o;
            }
            intersection donutXYWhenZ(rayDef ray, float4 rangeWithHole, float faceDir, float z) {
                intersection o;
                ray.pos = ray.pos.zxy;
                ray.dir = ray.dir.zxy;
                o = donutYZWhenX(ray, rangeWithHole, faceDir, z);
                o.normal.zxy = o.normal;
                return o;
            }

            intersection menger(rayDef ray) {
                intersection o[3][4];
                float4 rangeWithHole = float4(-1, -1.0/3.0, 1.0/3.0, 1)*0.5;
                
                float faceDir;
                [unroll] for (uint i = 0; i < 4; i++) {
                    faceDir = fmod(i, 2)*2 - 1;
                    o[0][i] = donutYZWhenX(ray, rangeWithHole, faceDir, rangeWithHole[i]);
                    o[1][i] = donutZXWhenY(ray, rangeWithHole, faceDir, rangeWithHole[i]);
                    o[2][i] = donutXYWhenZ(ray, rangeWithHole, faceDir, rangeWithHole[i]);
                }

                bool doReplace;
                [unroll] for (uint i = 0; i < 3; i++) {
                    [unroll] for (uint j = 0; j < 4; j++) {
                        doReplace =
                        !(o[0][0].intersect && 0 <= o[0][0].t) ||
                        (o[i][j].intersect && 0 <= o[i][j].t && o[i][j].t < o[0][0].t);
                        
                        o[0][0] = o[i*doReplace][j*doReplace];
                    }
                }
                return o[0][0];
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