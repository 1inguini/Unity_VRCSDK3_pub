Shader "linguini/Raytracing/Sphere"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1)
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
            
            #define WORLD

            fixed4 _Color;
            
            #define EPS 0.0001
            #define INF 3.402823466e+38
            
            float4x4 IDMAT4 = {
                {1,0,0,0}, 
                {0,1,0,0},
                {0,0,1,0},
                {0,0,0,1}
            };
            
            float inf2neg(float x) {
                return INF <= x? -1: x;
            }

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

            float solveQuadratic(float a, float b, float c) {
                float d = square(b) - 4*a*c;
                return d < 0? -INF: (-b - sqrt(d))/(2*a);
            }

            float solveQuadraticHalf(float a, float halfB, float c) {
                float quartD = square(halfB) - a * c;
                return quartD < 0? -INF: (-halfB - sqrt(quartD))/a;
            }
            
            // // http://answers.unity.com/answers/641391/view.html
            // float4x4 inverse(float4x4 input)
            // {
                //     #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
                //     //determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))
                
                //     float4x4 cofactors = float4x4(
                //     minor(_22_23_24, _32_33_34, _42_43_44), 
                //     -minor(_21_23_24, _31_33_34, _41_43_44),
                //     minor(_21_22_24, _31_32_34, _41_42_44),
                //     -minor(_21_22_23, _31_32_33, _41_42_43),
                
                //     -minor(_12_13_14, _32_33_34, _42_43_44),
                //     minor(_11_13_14, _31_33_34, _41_43_44),
                //     -minor(_11_12_14, _31_32_34, _41_42_44),
                //     minor(_11_12_13, _31_32_33, _41_42_43),
                
                //     minor(_12_13_14, _22_23_24, _42_43_44),
                //     -minor(_11_13_14, _21_23_24, _41_43_44),
                //     minor(_11_12_14, _21_22_24, _41_42_44),
                //     -minor(_11_12_13, _21_22_23, _41_42_43),
                
                //     -minor(_12_13_14, _22_23_24, _32_33_34),
                //     minor(_11_13_14, _21_23_24, _31_33_34),
                //     -minor(_11_12_14, _21_22_24, _31_32_34),
                //     minor(_11_12_13, _21_22_23, _31_32_33)
                //     );
                //     #undef minor
                //     return transpose(cofactors) / determinant(input);
            // }

            float4x4 rodriguesMatrixCosSin(float3 n, float cosT, float sinT) {
                float3 sq = float3(n.x*n.x, n.y*n.y, n.z*n.z);
                float3 adj = float3(n.x*n.y, n.y*n.z, n.z*n.x);
                float r = 1 - cosT;
                return float4x4(
                cosT + sq.x*r, adj.x*r - n.z*sinT, adj.z*r + n.y*sinT, 0,
                adj.x*r + n.z*sinT, cosT + sq.y*r, adj.y*r - n.x*sinT, 0,
                adj.z*r - n.y*sinT, adj.y*r + n.x*sinT, cosT + sq.z*r, 0,
                0, 0, 0, 1
                );
            }

            float4x4 rodriguesMatrix(float3 n, float theta) {
                float sinT = sin(theta);
                float cosT = cos(theta);
                return rodriguesMatrixCosSin(n,cosT,sinT);
            }

            float4x4 rodriguesMatrixCos(float3 n, float cosT) {
                float sinT = sqrt(1-square(cosT));
                return rodriguesMatrixCosSin(n,cosT,sinT);
            }


            float4x4 rotationMatrix(float x, float y, float z) {
                float s, c;
                s = sin(x);
                c = cos(x);
                float4x4 o = float4x4(1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1);
                s = sin(y);
                c = cos(y);
                o = mul(o, float4x4(c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1));
                s = sin(z);
                c = cos(z);
                o = mul(o, float4x4(c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1));
                return o;                
            }
            float4x4 rotationMatrix(float3 thetas) {
                return rotationMatrix(thetas.x, thetas.y, thetas.z);                
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
                fixed4 color : SV_Target;
                float depth : SV_Depth;
            };
            
            struct rayDef {
                float3 pos;
                float3 dir;
            };

            // struct movedRay{
                //     rayDef ray;
                //     float correction;
            // };            
            
            // movedRay matrixApply(float4x4 mat, rayDef ray) {
                //     movedRay o;
                //     // mat = inverse(mat);
                //     o.ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                //     o.ray.dir = mul(mat, ray.dir).xyz;
                //     o.correction = length(o.ray.dir);
                //     o.ray.dir /= o.correction;
                //     return o;
            // }
            
            rayDef matrixApply(float4x4 mat, rayDef ray) {
                // mat = inverse(mat);
                ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                ray.dir = mul(mat, ray.dir).xyz;
                return ray;
            }

            struct intersection {
                float t;
                float3 normal;
            };
            
            struct bodyDef {
                uint base; // 0:plane 1:sphere 2:cube
                float4x4 mat;
                rayDef ray;
                float3 pos;
                float3 normal;
            };

            #define PLANE 0
            #define SPHERE 1
            #define CUBE 2


            #define PROTOTYPE_BODY(_body) intersection _body##(rayDef ray);
            PROTOTYPE_BODY(plane)
            PROTOTYPE_BODY(sphere)
            PROTOTYPE_BODY(cube)

            bodyDef runBody(bodyDef body) {
                rayDef ray = matrixApply(body.mat, body.ray);
                intersection i;
                [call] switch(body.base){
                    case 0: {i = plane(ray); break;}
                    case 1: {i = sphere(ray); break;}
                    case 2: {i = cube(ray); break;}
                }
                body.pos = i.t*body.ray.dir + body.ray.pos;
                body.normal = mul(transpose(body.mat), float4(i.normal, 1)).xyz;
                return body;
            };
            
            bodyDef initBody(uint base, float4x4 mat, rayDef ray) {
                bodyDef o;
                o.base = base;
                o.mat = mat;
                o.ray = ray;
                o.pos = ray.pos;
                o.normal = 0;
                o = runBody(o);
                return o;
            }

            float getDist(bodyDef b){
                return sign(dot(b.pos - b.ray.pos, b.ray.dir))*distance(b.pos, b.ray.pos);
                // return
                // (b.ray.dir.x?
                // (b.i.pos.x - b.ray.pos.x)/b.ray.dir.x:
                // (b.ray.dir.y?
                // (b.i.pos.y - b.ray.pos.y)/b.ray.dir.y:
                // ((b.i.pos.z - b.ray.pos.z)/b.ray.dir.z)));
            }

            bodyDef not(bodyDef b) {
                // b.i.dist *= -1;
                b.pos -= 2*(b.pos - b.ray.pos);
                b.normal *= -1;
                return b;
            }

            bodyDef or(bodyDef b[2]) {
                // return b0 if b0 is foreground, b1 if else.
                float dist[2] = { getDist(b[0]), getDist(b[1]) };
                bool isB0 = (0 < dist[0] && 0 < dist[1])? (dist[0] < dist[1]): (dist[1] < dist[0]);
                return b[!isB0];
            }
            bodyDef or(bodyDef b0, bodyDef b1) {
                bodyDef b[2] = {b0, b1};
                return or(b);
            }

            // bodyDef and(bodyDef b[2]) {
                //     // return b0 if b0 is foreground, b1 if else.
                //     float dist[2] = { getDist(b[0]), getDist(b[1]) };
                //     bool isB[2];
                //     isB[0] = (0 < dist[0] && dist[0] < dist[1]);
                //     isB[1] = (0 < dist[1] && dist[1] < dist[0]);
                //     b0.pos = isB[0]? b[0].pos:(isB[1]? b[1].pos: -1);
                //     b0.normal = isB[0]? b0.normal: b1.normal;
                //     return b0;
            // }

            // intersection not(intersection b) {
                //     b.dist *= -1;
                //     b.normal *= -1;
                //     return b;
            // }

            // intersection or(intersection b0, intersection b1) {
                //     // return b0 if b0 is foreground, b1 if else.
                //     bool isB0 = (0 < b0.dist && 0 < b1.dist)? (b0.dist < b1.dist): (b1.dist < b0.dist);
                //     b0.dist = isB0? b0.dist: b1.dist;
                //     b0.normal = isB0? b0.normal: b1.normal;
                //     return b0;
            // }
            
            // intersection and(intersection b0, intersection b1) {
                //     // return b0 if b0 is foreground, b1 if else.
                //     bool2 isB;
                //     isB[0] = (0 < b0.dist && b0.dist < b1.dist);
                //     isB[1] = (0 < b1.dist && b1.dist < b0.dist);
                //     b0.dist = isB[0]? b0.dist:(isB[1]? b1.dist: -1);
                //     b0.normal = isB[0]? b0.normal: b1.normal;
                //     return b0;
            // }

            // intersection max(intersection b0, intersection b1) {
                //     // return b0 if b0 is foreground, b1 if else.
                //     bool isB0 = (0 < b0.dist && 0 < b1.dist)? (b0.dist < b1.dist): (b1.dist < b0.dist);
                //     b0.dist = isB0? b0.dist: b1.dist;
                //     b0.normal = isB0? b0.normal: b1.normal;
                //     return b0;
            // }


            #define NORMAL_FUNC(_bodyName) float3 _bodyName##Normal(float3 pos) { \
                float def = _bodyName##Def(pos); \
                return normalize(float3( \
                _bodyName##Def(pos + float3(EPS,0,0)) - def, \
                _bodyName##Def(pos + float3(0,EPS,0)) - def, \
                _bodyName##Def(pos + float3(0,0,EPS)) - def \
                ) \
                ); \
            }

            #define INTERSECTION_FUNC(_bodyName) intersection _bodyName##(rayDef ray) { \
                intersection o; \
                o.t = _bodyName##Dist(ray); \
                o.normal = _bodyName##Normal(o.t*ray.dir + ray.pos); \
                return o; \
            }

            // float planeDef(float3 normal, float3 pos) {
                //     return dot(normal, pos);
            // }

            inline float planeFromNormalDist(float3 normal, rayDef ray) {
                float DdotN = dot(ray.dir, normal);
                return -dot(ray.pos, normal)/(DdotN? DdotN: 1);
            }

            intersection plane(rayDef ray) {
                intersection o;
                o.normal = float3(0,sign(ray.pos.y),0);
                o.t = planeFromNormalDist(o.normal, ray);
                return o;
            }

            // float sphereDef(float3 pos) {
                //     // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                //     return length(pos) - 0.5;
            // }
            
            float3 sphereNormal(float3 pos){
                return normalize(pos - 0);
            }

            float sphereDist(rayDef ray) {
                return solveQuadraticHalf(
                square(ray.dir),
                dot(ray.dir, ray.pos),
                square(ray.pos) - 0.25
                );
            }

            INTERSECTION_FUNC(sphere)
            // intersection sphere(float4x4 mat, rayDef ray) {
                //     INTERSECTION(sphereDist, sphereNormal, mat, ray)
                //     // intersection o;
                //     // movedRay mray = matrixApply(mat, ray);
                //     // o.dist = sphereDist(mray.ray);
                //     // float3 pos = o.dist*mray.ray.dir + mray.ray.pos;
                //     // o.dist /= mray.correction; 
                //     // o.normal = (o.dist <= 0)? 0:
                //     // mul(
                //     // transpose(mat),
                //     // float4(sphereNormal(pos),1)).xyz;
                //     // return o;
            // }

            float cubeDef(float3 pos) {
                return max3(abs(pos)) - 0.5;
            }

            // NORMAL_FUNC(cube)

            float3 cubeNormal(float3 pos) {
                return normalize(step(pos, 0.5-EPS));
            }

            float cubeDist(rayDef ray) {
                float2 buf;
                float3 tmin, tmax;
                #define SOLVE(i) \
                buf[0] = (0.5 - ray.pos.i)/ray.dir.i; \
                buf[1] = -(0.5 + ray.pos.i)/ray.dir.i; \
                tmin.i = max(0, min(buf[0],buf[1])); \
                tmax.i = max(buf[0],buf[1]);
                SOLVE(x)
                SOLVE(y)
                SOLVE(z)
                #undef SOLVE
                float2 tbound = float2(max3(tmin), min3(tmax));
                return tbound[1] < tbound[0]? -1: tbound[0];
            }

            INTERSECTION_FUNC(cube)

            float torusDef(float3 pos) {
                return distance((length(pos.xy) - 0.1), pos.z) - 0.25;
                // return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
            }
            NORMAL_FUNC(torus)
            
            bodyDef scene(rayDef ray) {
                
                bodyDef plane0, cube0, sphere0, sphere1;
                float4x4 mat = IDMAT4;
                
                mat -= shiftMatrix(float3(0,-0.5,0));
                mat = mul(mat, rodriguesMatrix(normalize(float3(0,0,1)), UNITY_HALF_PI*0.5));
                // plane0 = plane(mat, ray);
                plane0 = initBody(PLANE, mat, ray);
                mat = IDMAT4;

                // mat -= shiftMatrix(0.3,0,0);
                // mat = mul(mat, scaleMatrix(2,2,2));
                cube0 = initBody(CUBE, mat, ray);
                mat = IDMAT4;
                
                mat = mul(mat, scaleMatrix(float3(1,2,2)));
                // mat += shiftMatrix(float3(0.3,0,0));
                // sphere0 = sphere(mat, ray);
                sphere0 = initBody(SPHERE, mat, ray);
                mat = IDMAT4;

                mat -= shiftMatrix(float3(0,0.3,0));
                mat = mul(mat, scaleMatrix(float3(2,2,1)));
                // sphere1 = sphere(mat, ray);
                sphere1 = initBody(SPHERE, mat, ray);

                // return or(sphere0, sphere1);
                return cube0;
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

                // float4x4 rayCoord = addShift(dir2zAxis(rayDirV), -pos);
                bodyDef p = scene(ray);

                clip(getDist(p));
                
                // float4 pos = float4(p.dist*ray.dir + ray.pos, 1); 
                float4 pos = float4(p.pos, 1); 
                float4 projectionPos;
                #if defined(WORLD)
                    projectionPos = UnityWorldToClipPos(pos);
                #elif defined(OBJECT)
                    projectionPos = UnityObjectToClipPos(pos);
                #else
                    projectionPos = 1;
                #endif
                o.depth = projectionPos.z / projectionPos.w;
                // o.color = fixed4(1/p.dist,0,0,1);
                o.color = lighting(pos, p.normal, 1, _Color);
                return o;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        // UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}