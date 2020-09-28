Shader "linguini/Raytracing/Sphere"
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

            // struct distFuncOut {
                //     bool intersect;
                //     float2 range;
            // };

            // distFuncOut fail() {
                //     distFuncOut o;
                //     o.intersect = false;
                //     o.range = float2(-INF, INF);
                //     return o;
            // }
            
            // distFuncOut solveQuadratic(float a, float b, float c) {
                //     distFuncOut o;
                //     float d = square(b) - 4*a*c;
                //     o.intersect = 0 <= d;
                //     o.range = !o.intersect? float2(-INF, INF):
                //     float2((-b - sqrt(d))/(2*a), (-b + sqrt(d))/(2*a));
                //     return o;
            // }

            // distFuncOut solveQuadraticHalf(float a, float halfB, float c) {
                //     distFuncOut o;
                //     float quartD = square(halfB) - a*c;
                //     o.intersect = 0 <= quartD;
                //     o.range = !o.intersect? float2(-INF, INF):
                //     (-halfB + float2(-1, 1)*sqrt(quartD))/a;
                //     return o;
            // }
            
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
                fixed4 color : SV_Target;
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
            
            // rayDef matrixApply(float4x4 mat, rayDef ray) {
                //     // mat = inverse(mat);
                //     ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                //     ray.dir = mul(mat, ray.dir).xyz;
                //     return ray;
            // }

            struct intersection {
                bool intersect;
                bool surface; // index for "float2 range" that indicates surface.
                float2 range; // range.x < 0 < range.y when inside, 0 < range.x < range.y when outside 
                float3 normal;
            };

            float3 getPos(rayDef ray, float2 range) {
                return range[range[0] < 0]*ray.dir + ray.pos;
            }

            // intersection emptyIntersection(){
                //     intersection o;
                //     o.intersect = false;
                //     o.range = float2(-INF, INF);
                //     o.normal = 0;
                //     return o;
            // }
            
            struct bodyDef {
                intersection i;
                uint base; // 0:plane 1:sphere 2:cube
                float4x4 mat;
                rayDef ray;
            };

            float surface(bodyDef b) {
                // return b.i.range[b.i.range[0] < 0];
                return b.i.range[b.i.surface];
            }

            bodyDef stepBody(bodyDef body);
            float backside(bodyDef b) {
                // b.i.range[0] = b.i.range[!(b.i.range[0] < 0 || b.i.inside)];
                bodyDef next = stepBody(b);
                return b.i.surface? next.i.range[next.i.range[0] < 0]: b.i.range[1];
                // return b.i.range[0];
            }

            #define PLANE 0
            #define SPHERE 1
            #define CUBE 2


            #define PROTOTYPE_BODY(_body) intersection _body##(rayDef ray);
            PROTOTYPE_BODY(plane)
            PROTOTYPE_BODY(sphere)
            PROTOTYPE_BODY(cube)

            bodyDef runBody(bodyDef body) {
                movedRay mray = matrixApply(body.mat, body.ray);
                [call] switch(body.base){
                    case 0: {body.i = plane(mray.ray); break;}
                    case 1: {body.i = sphere(mray.ray); break;}
                    case 2: {body.i = cube(mray.ray); break;}
                }
                body.i.range /= mray.correction;
                body.i.normal = mul(transpose(body.mat), float4(body.i.normal, 1)).xyz;
                return body;
            };
            
            bodyDef stepBody(bodyDef body) {
                float t = body.i.range[body.i.range[0] < 0] + EPS;
                float3 pos = getPos(body.ray, t);
                movedRay mray = matrixApply(body.mat, mkray(pos, body.ray.dir));
                intersection i;
                [call] switch(body.base){
                    case 0: {body.i = plane(mray.ray); break;}
                    case 1: {body.i = sphere(mray.ray); break;}
                    case 2: {body.i = cube(mray.ray); break;}
                }
                // body.i.intersect = i.intersect;
                body.i.range = t + body.i.range/mray.correction;
                body.i.normal = mul(transpose(body.mat), float4(body.i.normal, 1)).xyz;
                return body;
            };
            
            bodyDef initBody(uint base, float4x4 mat, rayDef ray) {
                bodyDef o;
                o.i.intersect = false;
                o.i.surface = false;
                o.i.range = 0;
                o.i.normal = 0;
                o.base = base;
                o.mat = mat;
                o.ray = ray;
                o = runBody(o);
                return o;
            }

            bodyDef noBody() {
                bodyDef o;
                o.i.intersect = false;
                o.i.surface = false;
                o.i.range = float2(-INF, INF);
                o.i.normal = 0;
                o.base = 0;
                o.mat = 0;
                o.ray.dir = 0;
                o.ray.pos = 0;
                return o;
            }


            // float getDist(bodyDef b){
                //     return sign(dot(b.pos - b.ray.pos, b.ray.dir))*distance(b.pos, b.ray.pos);
                //     // return
                //     // (b.ray.dir.x?
                //     // (b.i.pos.x - b.ray.pos.x)/b.ray.dir.x:
                //     // (b.ray.dir.y?
                //     // (b.i.pos.y - b.ray.pos.y)/b.ray.dir.y:
                //     // ((b.i.pos.z - b.ray.pos.z)/b.ray.dir.z)));
            // }

            // float getDist(bodyDef b){
                //         return sign(dot(b.pos - b.ray.pos, b.ray.dir))*distance(b.pos, b.ray.pos);
            // }

            bodyDef not(bodyDef b) {
                b.i.surface = !b.i.surface;
                // b.i.intersect = !b.i.intersect;
                // b.i.t *= -1;
                b.i.normal *= -1;
                // b.ray.dir *= -1;
                return b;
            }

            // bodyDef or(bodyDef b[2]) {
                //     // return b0 if b0 is foreground, b1 if else.
                //     bool isB1 = (b[0].i.intersect && b[1].i.intersect)?
                //     (b[1].i.range.x < b[0].i.range.x):
                //     (b[1].i.intersect);
                //     return b[isB1];
            // }
            bodyDef or(bodyDef b[2]) {
                // // return b0 if b0 is foreground, b1 if else.
                // float surfaces[2] = { b[0].i.range[b[0].i.range[0] < 0], b[1].i.range[b[1].i.range[0] < 0] };
                // return b[
                // (b[0].i.intersect && b[1].i.intersect)?
                // (surfaces[1] < surfaces[0]):
                // (b[1].i.intersect)
                // ];
                return b[
                b[1].i.intersect &&
                surface(b[1]) < surface(b[0])
                ];
            }
            bodyDef or(bodyDef b0, bodyDef b1) {
                bodyDef b[2] = {b0, b1};
                return or(b);
            }
            bodyDef or3(bodyDef b[3]) {
                return or(b[0], or(b[1], b[2]));
            }

            bodyDef or3(bodyDef b0, bodyDef b1, bodyDef b2) {
                return or(b0, or(b1, b2));
            }

            bodyDef and(bodyDef b[2]) {
                bodyDef buf[2]= { noBody(), noBody() };// = { runBody(b[0]), runBody(b[1]) };
                float surf;
                bodyDef check[2] = { noBody(), b[0]};
                surf = surface(b[0]);
                buf[0] = check[
                b[1].i.intersect && (
                // (b[1].i.range[0] < surf && surf < b[1].i.range[1])
                surface(b[1]) < surface(b[0]) && surface(b[0]) < backside(b[1])
                )
                ];

                check[1] = b[1];
                surf = surface(b[1]);
                buf[1] = check[
                b[0].i.intersect && (
                // (b[0].i.range[0] < surf && surf < b[0].i.range[1])
                surface(b[0]) < surface(b[1]) && surface(b[1]) < backside(b[0])
                )
                ];

                return or(buf);
            }
            bodyDef and(bodyDef b0, bodyDef b1) {
                bodyDef b[2] = {b0, b1};
                return and(b);
            }
            bodyDef and3(bodyDef b0, bodyDef b1, bodyDef b2) {
                return and(b0, and(b1, b2));
            }

            #define NORMAL_FUNC(_bodyName) float3 _bodyName##Normal(float3 pos) { \
                float def = _bodyName##Def(pos); \
                return normalize(float3( \
                _bodyName##Def(pos + float3(EPS,0,0)) - def, \
                _bodyName##Def(pos + float3(0,EPS,0)) - def, \
                _bodyName##Def(pos + float3(0,0,EPS)) - def \
                ) \
                ); \
            }

            // #define INTERSECTION_FUNC(_bodyName) intersection _bodyName##(rayDef ray) { \
                //     intersection o; \
                //     distFuncOut dfo = _bodyName##Dist(ray); \
                //     o.intersect = dfo.intersect; \
                //     o.range = dfo.range; \
                //     o.normal = _bodyName##Normal(o.range[o.range[0] < 0]*ray.dir + ray.pos); \
                //     return o; \
            // }

            // float planeDef(float3 normal, float3 pos) {
                //     return dot(normal, pos);
            // }



            intersection planeFromNormal(float3 normal, rayDef ray) {
                intersection o;
                float DdotN = dot(ray.dir, normal);
                float PdotN = dot(ray.pos, normal);
                o.intersect = DdotN != 1;
                o.surface = 0 <= PdotN;
                float t = -PdotN/(DdotN? DdotN: 1);
                o.range[0] = o.surface? -INF: t;
                o.range[1] = o.surface? t: INF;
                o.normal = normal;
                return o;
            }

            intersection plane(rayDef ray) {
                // intersection o;
                // o.normal = float3(0,sign(ray.pos.y),0);
                // distFuncOut dfo = planeDistFromNormal(o.normal, ray);
                // o.intersect = 0 <= o.range;
                // return o;
                return planeFromNormal(float3(0,1,0), ray);
            }

            // float sphereDef(float3 pos) {
                //     // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                //     return length(pos) - 0.5;
            // }
            
            float3 sphereNormal(float3 pos){
                return normalize(pos - 0);
            }

            // distFuncOut sphereDist(rayDef ray) {
                //     float DdotP = dot(ray.dir, ray.pos);
                //     distFuncOut check[2] = {
                    //         fail(),
                    //         solveQuadraticHalf(
                    //         1, //square(ray.dir),
                    //         DdotP,
                    //         square(ray.pos) - 0.25
                    //         )
                //     };
                //     return check[DdotP < 0];
            // }
            intersection sphere(rayDef ray) {
                intersection o;
                float DdotP = dot(ray.dir, ray.pos);
                float quartD = square(DdotP) - (square(ray.pos) - 0.25);
                o.intersect = 0 <= quartD && DdotP < 0;
                o.range = !o.intersect? float2(-INF, INF):
                (-DdotP + float2(-1, 1)*sqrt(quartD));
                
                o.surface = o.range[0] < 0;
                o.normal = sphereNormal(getPos(ray, o.range));
                return o;
            }
            // INTERSECTION_FUNC(sphere)
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

            // distFuncOut cubeDist(rayDef ray) {
                //     float2 buf;
                //     float3 tmin, tmax;
                //     #define SOLVE(i) \
                //     buf[0] = (0.5 - ray.pos.i)/ray.dir.i; \
                //     buf[1] = -(0.5 + ray.pos.i)/ray.dir.i; \
                //     tmin.i = max(0, min(buf[0],buf[1])); \
                //     tmax.i = max(buf[0],buf[1]);
                //     SOLVE(x)
                //     SOLVE(y)
                //     SOLVE(z)
                //     #undef SOLVE
                //     float2 tbound = float2(max3(tmin), min3(tmax));
                //     distFuncOut o;
                //     o.intersect = tbound[0] < tbound[1];
                //     o.range = float2(tbound);
                //     o.range.xy = !o.intersect? float2(-INF, INF): o.range.xy;
                //     return o;
            // }
            // INTERSECTION_FUNC(cube)
            
            intersection cube(rayDef ray) {
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
                intersection o;
                o.intersect = tbound[0] < tbound[1];
                o.range = !o.intersect? float2(-INF, INF): tbound;
                o.surface = o.range[0] < 0;
                o.normal = cubeNormal(getPos(ray, o.range));
                return o;
            }


            float torusDef(float3 pos) {
                return distance((length(pos.xy) - 0.25), pos.z) - 0.01;
                // return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
            }
            NORMAL_FUNC(torus)
            
            bodyDef mengerFold(bodyDef body) {
                // body.mat = mul(body.mat, scaleMatrix(3));
                body.mat = scaleLocalMatrix(body.mat, 3);
                float div3 = 1.0/3.0;

                bodyDef corners[3][4], edges[2][4]; 
                [unroll] for (uint i = 0; i < 4; i++) {
                    corners[0][i] = body;
                    corners[1][i] = body;
                    corners[2][i] = body;
                    edges[0][i] = body;
                    edges[1][i] = body;
                    
                    corners[0][i].mat -= shiftMatrix(0, 1, 0);
                    corners[2][i].mat -= shiftMatrix(0, -1, 0);
                    edges[0][i].mat -= shiftMatrix(0, 1, 0);
                    edges[1][i].mat -= shiftMatrix(0, -1, 0);
                }
                [unroll] for (uint i = 0; i < 3; i++) {
                    corners[i][0].mat -= shiftMatrix(1, 0, 1);
                    corners[i][1].mat -= shiftMatrix(-1, 0, 1);
                    corners[i][2].mat -= shiftMatrix(1, 0, -1);
                    corners[i][3].mat -= shiftMatrix(-1, 0, -1);
                }
                [unroll] for (uint i = 0; i < 2; i++) {
                    edges[i][0].mat -= shiftMatrix(1, 0, 0);
                    edges[i][1].mat -= shiftMatrix(0, 0, 1);
                    edges[i][2].mat -= shiftMatrix(-1, 0, 0);
                    edges[i][3].mat -= shiftMatrix(0, 0, -1);
                }
                
                [unroll] for (uint i = 0; i < 4; i++) {
                    corners[0][i] = runBody(corners[0][i]);
                    corners[1][i] = runBody(corners[1][i]);
                    corners[2][i] = runBody(corners[2][i]);
                    edges[0][i] = runBody(edges[0][i]);
                    edges[1][i] = runBody(edges[1][i]);
                }
                
                [unroll] for (uint i = 0; i < 3; i++) {
                    corners[i][0] = or(
                    or(corners[i][0], corners[i][1]),
                    or(corners[i][2], corners[i][3])
                    );
                }
                [unroll] for (uint i = 0; i < 2; i++) {
                    edges[i][0] = or(
                    or(edges[i][0], edges[i][1]),
                    or(edges[i][2], edges[i][3])
                    );
                }
                return or(
                or3(corners[0][0], corners[1][0], corners[2][0]),
                or(edges[0][0], edges[1][0])
                );
            }

            // pass cube and make menger sponge // failing
            bodyDef menger(bodyDef body) {
                for (uint i = 0; i < 2; i++) {
                    body = mengerFold(body);
                }
                return body;
            } 

            bodyDef scene(rayDef ray) {
                
                bodyDef plane0, cube0, cube1, sphere0, sphere1;
                float4x4 mat = IDMAT4;
                
                mat -= shiftMatrix(float3(0,-0.5,0));
                mat = mul(mat, rodriguesMatrix(normalize(float3(0,0,1)), UNITY_HALF_PI*0.5));
                // plane0 = plane(mat, ray);
                plane0 = initBody(PLANE, mat, ray);
                mat = IDMAT4;

                // mat -= shiftMatrix(0.3,0,0);
                mat -= shiftMatrix(-0.2);
                mat = mul(mat, scaleMatrix(2,2,2));
                cube0 = initBody(CUBE, mat, ray);
                // cube0.mat -= shiftMatrix(float3(1,0,0));
                // cube0 = runBody(cube0);
                mat = IDMAT4;
                

                mat = mul(mat, scaleMatrix(1,1,1));
                mat -= shiftMatrix(0.3);
                cube1 = initBody(CUBE, mat, ray);
                // cube0 = runBody(cube0);
                mat = IDMAT4;
                
                mat = mul(mat, scaleMatrix(float3(2,2,1)));
                // mat += shiftMatrix(float3(0.3,0,0));
                // sphere0 = sphere(mat, ray);
                sphere0 = initBody(SPHERE, mat, ray);
                // sphere0.mat -= shiftMatrix(float3(0.3,0,0));
                // sphere0 = runBody(sphere0);
                mat = IDMAT4;

                mat -= shiftMatrix(float3(0,0.3,0));
                mat = mul(mat, scaleMatrix(float3(2,2,2)));
                // sphere1 = sphere(mat, ray);
                sphere1 = initBody(SPHERE, mat, ray);

                return and(cube0, not(cube1));
                // return and(sphere0, sphere1);
                // return sphere1;
                // return not(cube0);
                // return or(cube0, or(sphere0, sphere1));
                // return or(not(sphere0), sphere1);
                // return and(cube0, or(sphere0, sphere1));
                // return runBody(not(sphere0));
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

                if(!p.i.intersect) discard;
                
                float4 pos = float4((p.i.range.x < 0? p.i.range.y: p.i.range.x)*ray.dir + ray.pos, 1); 
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
                // o.color = fixed4(1/p.dist,0,0,1);
                o.color = lighting(pos, p.i.normal, 1, _Color);
                return o;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        // UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}