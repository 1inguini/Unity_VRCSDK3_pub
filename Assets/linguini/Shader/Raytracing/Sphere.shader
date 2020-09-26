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
            
            #define OBJECT

            fixed4 _Color;
            
            #define IDMAT4 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
            
            float square(float x) {
                return x*x;
            }
            float square(float3 v) {
                return dot(v,v);
            }
            
            // http://answers.unity.com/answers/641391/view.html
            float4x4 inverse(float4x4 input)
            {
                #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
                //determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))
                
                float4x4 cofactors = float4x4(
                minor(_22_23_24, _32_33_34, _42_43_44), 
                -minor(_21_23_24, _31_33_34, _41_43_44),
                minor(_21_22_24, _31_32_34, _41_42_44),
                -minor(_21_22_23, _31_32_33, _41_42_43),
                
                -minor(_12_13_14, _32_33_34, _42_43_44),
                minor(_11_13_14, _31_33_34, _41_43_44),
                -minor(_11_12_14, _31_32_34, _41_42_44),
                minor(_11_12_13, _31_32_33, _41_42_43),
                
                minor(_12_13_14, _22_23_24, _42_43_44),
                -minor(_11_13_14, _21_23_24, _41_43_44),
                minor(_11_12_14, _21_22_24, _41_42_44),
                -minor(_11_12_13, _21_22_23, _41_42_43),
                
                -minor(_12_13_14, _22_23_24, _32_33_34),
                minor(_11_13_14, _21_23_24, _31_33_34),
                -minor(_11_12_14, _21_22_24, _31_32_34),
                minor(_11_12_13, _21_22_23, _31_32_33)
                );
                #undef minor
                return transpose(cofactors) / determinant(input);
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
            
            float2 rotate(float2 pos, float r) {
                float2x2 m = float2x2(cos(r), sin(r), -sin(r), cos(r));
                return mul(pos,m);
            }

            float2 rotateCos(float2 pos, float cos) {
                float sin = sqrt(1 - square(cos));
                float2x2 m = float2x2(cos, sin, -sin, cos);
                return mul(pos,m);
            }

            struct direction {
                float zenith; // the angle from z to azimuth in radian
                float azimuth; // the angle from x to y in radian
            };

            direction mkdirection(float zenith, float azimuth) {
                direction o;
                o.zenith = zenith;
                o.azimuth = azimuth;
                return o;
            }
            
            float3 dir2unitVec(direction dir) {
                float3 o;
                float sinZ = sin(dir.zenith);
                o.x = sinZ * cos(dir.azimuth);
                o.y = sinZ * sin(dir.azimuth);
                o.z = cos(dir.zenith);
                return o;
            }

            direction vectDir(float3 vec) {
                direction o;
                o.zenith = acos(vec.z/length(vec));
                o.azimuth = sign(vec.y) * acos(vec.x/length(vec.xy));
                return o;
            }

            float4x4 internalRodrigues(float3 n, float cosT, float sinT) {
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

            float4x4 rodriguesMatrix(direction dir, float theta) {
                float3 n = dir2unitVec(dir);
                float cosT = cos(theta);
                float sinT = sin(theta);
                return internalRodrigues(n,cosT, sinT);
            }
            float4x4 rodriguesMatrix(float3 n, float theta) {
                float sinT = sin(theta);
                float cosT = cos(theta);
                return internalRodrigues(n,cosT,sinT);
            }

            float4x4 rodriguesMatrixCos(direction dir, float cosT) {
                float3 n = dir2unitVec(dir);
                float sinT = sqrt(1-square(cosT));
                return internalRodrigues(n,cosT,sinT);
            }
            float4x4 rodriguesMatrixCos(float3 n, float cosT) {
                float sinT = sqrt(1-square(cosT));
                return internalRodrigues(n,cosT,sinT);
            }

            float4x4 rotationMatrix(float3 thetas) {
                float s, c;
                s = sin(thetas.x);
                c = cos(thetas.x);
                float4x4 o = float4x4(1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1);
                s = sin(thetas.y);
                c = cos(thetas.y);
                o = mul(o, float4x4(c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1));
                s = sin(thetas.z);
                c = cos(thetas.z);
                o = mul(o, float4x4(c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1));
                return o;                
            }

            float4x4 shiftMatrix(float3 pos) {
                float4x4 mat = 0;
                mat[0][3] = pos.x;
                mat[1][3] = pos.y;
                mat[2][3] = pos.z;
                mat[3][3] = 1;
                // mat[3] = float4(pos,1);
                return mat; // + float4x4(0,0,0,pos.x, 0,0,0,pos.y, 0,0,0,pos.z, 0,0,0,0)
            }

            float4x4 scaleMatrix(float3 scale) {
                float4x4 mat = 0;
                mat[0][0] = scale.x;
                mat[1][1] = scale.y;
                mat[2][2] = scale.z;
                mat[3][3] = 1;
                return mat;
            }

            // float4x4 dir2zAxis(direction z) {
                //     float theta = z.zenith;
                //     float3 n = z.azimuth + UNITY_HALF_PI;
                //     return rotationMatrixCos(n, theta);
            // }
            // float4x4 dir2zAxis(float3 z) {
                //     float cosTheta = z.z/length(z);
                //     float3 n = normalize(cross(float3(0,0,1), z));
                //     return rotationMatrixCos(n, cosTheta);
            // }

            struct polarCoord {
                float radius; // same as distance from the origin
                direction dir;
            };

            float3 polar2cartesian(polarCoord pos) {
                return pos.radius * dir2unitVec(pos.dir);
            }

            polarCoord catresian2polar(float3 pos) {
                polarCoord o;
                o.radius = length(pos);
                o.dir.zenith = acos(pos.z/length(pos));
                o.dir.azimuth = sign(pos.y) * acos(pos.x/length(pos.zy));
                return o;
            }

            // struct rayDef {
                //     float3 pos;
                //     direction dir;
            // };
            
            struct rayDef {
                float3 pos;
                float3 dir;
            };

            // float plane(float3 pos) {
                //     float3 n = float3(0,0,1);
                //     return dot(n, pos);
            // }
            
            float plane(rayDef ray) {
                float normal = float3(1,0,0);
                return -dot(ray.pos, normal)/dot(ray.dir, normal);
            }

            // a*pos.x + b*pos.y + c*pos.y = 0
            // pos.x = -b/a * pos.y + -c/a * pos.z
            // pos.y = -c/b * pos.z + -a/b * pos.x
            // pos.z = -a/c * pos.x + -b/c * pos.y

            // // div zero is zero
            // float divZZ(float numerator, float denominator) { 
                //     return denominator? numerator/denominator: 0;
            // }

            // float4x4 planeMatrix{
                //     float3 n = float3(0,0,1); // normal
                //     return float4x4(
                //         0, divZZ(-n.y, n.x), divZZ(-n.z, n.x), 0,
                //         divZZ(-n.x, n.y), 0, divZZ(-n.z, n.y), 0,
                //         divZZ(-n.x, n.z), divZZ(-n.y, n.z), 0, 0,
                //         0, 0, 0, 1
                //     );
            // }
            
            // float4x4 planeYMatrix(){
                //     return float4x4(
                //         0, 0, 0, 0,
                //         0, 0, 0, 0,
                //         0, 0, 1, 0,
                //         0, 0, 0, 1
                //     );
            // }
            

            // float decodePlane(float result) {
                //     return -result;
            // }
            float solveQuadratic(float a, float b, float c) {
                float d = square(b) - 4*a*c;
                return d < 0? -1: (-b - sqrt(d))/(2*a);
            }

            float solveQuadraticHalf(float a, float halfB, float c) {
                float quartD = square(halfB) - a * c;
                return quartD < 0? -1: (-halfB - sqrt(quartD))/a;
            }
            
            // //mat = inverse(mat);
            // #define MATRIX_OPERATION_RAY(_varName, _funcName, _mat, _ray) rayDef _varName##_ray = ray; \
            // float4x4 _mat##_i = inverse(_mat); \
            // _varName##_ray.pos = mul(_mat##_i, float4(_varName##_ray.pos, 1)).xyz; \
            // float3 _varName##_dir = mul(_mat##_i, float4(_varName##_ray.dir, 1)).xyz; \
            // _varName##_ray.dir = normalize(_varName##_dir); \
            // _varName = _funcName##(_varName##_ray)/length(_varName##_dir);

            rayDef matrixApply(float4x4 mat, rayDef ray) {
                // mat = inverse(mat);
                ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                ray.dir = mul(mat, float4(ray.dir, 1)).xyz;
                return (ray, length(ray.dir));
            }

            float sphere(rayDef ray) {
                return solveQuadraticHalf(
                square(ray.dir),
                dot(ray.dir, ray.pos),
                square(ray.pos) - 0.25
                );
            }

            #define NORMAL(_funcName, _pos)  float EPS = 0.0001; \
            float def = _funcName##(pos); \
            return normalize(float3( \
            _funcName##(pos + float3(EPS,0,0)) - def, \
            _funcName##(pos + float3(0,EPS,0)) - def, \
            _funcName##(pos + float3(0,0,EPS)) - def \
            ) \
            );

            float sphereDef(float3 pos) {
                // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                return length(pos) - 0.5;
            }
            
            float3 sphereNormal(float3 pos){
                NORMAL(sphereDef, pos)
                // float EPS = 0.0001;
                // float def = sphereDef(mat, pos);
                // return normalize(float3(
                // sphereDef(mat, pos + float3(EPS,0,0)) - def,
                // sphereDef(mat, pos + float3(0,EPS,0)) - def,
                // sphereDef(mat, pos + float3(0,0,EPS)) - def
                // )
                // );
            }

            // float3 getSceneNormal(float3 pos){
                //     float EPS = 0.0001;
                //     float def = sceneDist(pos);
                //     return normalize(float3(
                //     sceneDef(pos + float3(EPS,0,0)) - def,
                //     sceneDef(pos + float3(0,EPS,0)) - def,
                //     sceneDef(pos + float3(0,0,EPS)) - def
                //     )
                //     );
            // }

            polarCoord polarSphere(direction dir) {
                polarCoord o;
                o.dir = dir;
                o.radius = 0.5;
                return o;
            }
            

            // float decodeSphere(float result) {
                //     return result < 0? sqrt(-result): -1;
            // }

            // float sphereZ(float2 xy) {
                //     float z2 = 0.25 - square(xy.x) - square(xy.y);
                //     return z2 < 0? -1: sqrt(z2);
            // }

            float torusDef(float3 pos) {
                return distance((length(pos.xy) - 0.1), pos.z) - 0.25;
                // return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
            }

            float3 torusNormal(float3 pos) {
                NORMAL(torusDef, pos)
            }

            // float torusZ(float2 xy) {
                //     return sqrt(1 - square(sqrt(square(xy.x) + square(xy.y)) - 0.5));
            // }

            // float scene(rayDef ray) {
                //     float3 posInScene = 0;

                //     float3 unitZ = float3(0,0,1);
                //     float3 cartPos = posInScene - ray.pos;
                //     polarCoord pos = catresian2polar(cartPos);
                
                //     float viewTheta = pos.dir.theta - ray.dir.theta;
                //     float viewPhi = pos.dir.phi - ray.dir.phi;
                //     float2 view = pos.radius * float2(sin(viewTheta), sin(viewPhi));
                //     float distance = sphereZ(view);
                //     return distance;
            // }

            struct intersection {
                float dist;
                float3 normal;
            };

            intersection scene(rayDef ray) {
                // sphere0 *= rotationMatrixCos(float3(0,1,0), _CosTime.x);
                // sphere0 *= float4x4(_CosTime.x,0,_SinTime.x,0, 0,1,0,0, -_SinTime.x,0,_CosTime.x,0, 0,0,0,1);
                
                float4x4 sphere0 = IDMAT4;
                //sphere0 = mul(sphere0, rotationMatrix(float3(0,_Time.y,0)));
                // sphere0 = mul(sphere0, rodriguesMatrix(normalize(float3(1,1,0)), _Time.y));
                // sphere0 = mul(sphere0,
                // // scaleMatrix(_SinTime.yzw)
                // scaleMatrix(float3(1,0.5,0.5))
                // );

                sphere0 += shiftMatrix(float3(0.3,0,0));
                sphere0 = mul(sphere0, scaleMatrix(float3(2,2,2)));
                //ray.pos += spherePos;
                //ray.pos = mul(ray.pos, rot);
                // ray.pos = mul(float4(ray.pos, 1), rot);
                //ray.dir = normalize(mul(ray.dir, rot));
                float4x4 sphere1 = IDMAT4+shiftMatrix(float3(-0.3,0,0));
                // sphere0 = mul(sphere0, rotationMatrix(float3(0,_Time.y,0));
                // sphere1 = mul(sphere0, rodriguesMatrix(normalize(float3(-1,1,1)), _Time.y));
                sphere1 = mul(sphere1, scaleMatrix(float3(0.5,0.5,0.5)));
                intersection s;
                float s0, s1;
                rayDef ray0 = matrixApply(sphere0, ray);
                float ray0Correct = length(ray.dir);
                ray0.dir = ray.dir/ray0Correct;
                s0 = sphere(ray0)/ray0Correct;
                // MATRIX_OPERATION_RAY(s0, sphere, sphere0, ray)
                // MATRIX_OPERATION_RAY(s1, sphere, sphere1, ray)
                s.dist = s0;
                s.normal = (mul(transpose(sphere0), sphereNormal(s.dist*ray0.dir + ray0.pos)));
                return s;
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

            float min3(float x, float y, float z){
                return min(x, min(y, z));
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
                intersection p = scene(ray);

                clip(p.dist);
                
                float4 pos = float4(p.dist*ray.dir + ray.pos, 1); 
                float4 projectionPos;
                #if defined(WORLD)
                    projectionPos = UnityWorldToClipPos(pos);
                #elif defined(OBJECT)
                    projectionPos = UnityObjectToClipPos(pos);
                #else
                    projectionPos = 1;
                #endif
                o.depth = projectionPos.z / projectionPos.w;

                float NdotL = dot(normalize(_WorldSpaceLightPos0.xyz), p.normal);                
                o.color = fixed4(NdotL*_Color.rgb, _Color.a);
                return o;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        // UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}