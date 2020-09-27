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
            
            #define IDMAT4 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
            
            float square(float x) {
                return x*x;
            }
            float square(float3 v) {
                return dot(v,v);
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

            struct movedRay{
                rayDef ray;
                float correction;
            };            
            
            movedRay matrixApply(float4x4 mat, rayDef ray) {
                movedRay o;
                // mat = inverse(mat);
                o.ray.pos = mul(mat, float4(ray.pos, 1)).xyz;
                o.ray.dir = mul(mat, ray.dir).xyz;
                o.correction = length(o.ray.dir);
                o.ray.dir /= o.correction;
                return o;
            }

            struct intersection {
                float dist;
                float3 normal;
            };

            #define NORMAL(_funcName, _pos)  float EPS = 0.0001; \
            float def = _funcName##(pos); \
            return normalize(float3( \
            _funcName##(pos + float3(EPS,0,0)) - def, \
            _funcName##(pos + float3(0,EPS,0)) - def, \
            _funcName##(pos + float3(0,0,EPS)) - def \
            ) \
            );

            #define INTERSECTION(_distFunc, _normalFunc, _mat, _ray) intersection _distFunc##_normalFunc; \
            movedRay _mat##_ray = matrixApply(_mat, _ray); \
            _distFunc##_normalFunc.dist = _distFunc##(_mat##_ray.ray); \
            float3 _distFunc##_normalFunc##_mat##_ray##_pos = _distFunc##_normalFunc.dist*_mat##_ray.ray.dir + _mat##_ray.ray.pos; \
            _distFunc##_normalFunc.dist /= _mat##_ray.correction; \
            _distFunc##_normalFunc.normal = (_distFunc##_normalFunc.dist <= 0)? 0: \
            mul( \
            transpose(_mat), \
            float4(_normalFunc##(_distFunc##_normalFunc##_mat##_ray##_pos),1)).xyz; \
            return _distFunc##_normalFunc;

            float planeDef(float3 pos) {
                float3 n = float3(0,0,1);
                return dot(n, pos);
            }

            float3 planeNormal(float3 pos){
                NORMAL(planeDef, pos)
            }

            float planeDist(rayDef ray) {
                float3 normal = float3(0,1,0);
                float DdotN = dot(ray.dir, normal);
                return (DdotN? -dot(ray.pos, normal)/DdotN: 0);
            }

            intersection plane(float4x4 mat, rayDef ray) {
                INTERSECTION(planeDist, planeNormal, mat, ray)
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

            float sphereDef(float3 pos) {
                // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                return length(pos) - 0.5;
            }
            
            float3 sphereNormal(float3 pos){
                NORMAL(sphereDef, pos)
            }

            float sphereDist(rayDef ray) {
                return solveQuadraticHalf(
                square(ray.dir),
                dot(ray.dir, ray.pos),
                square(ray.pos) - 0.25
                );
            }

            intersection sphere(float4x4 mat, rayDef ray) {
                INTERSECTION(sphereDist, sphereNormal, mat, ray)
                // intersection o;
                // movedRay mray = matrixApply(mat, ray);
                // o.dist = sphereDist(mray.ray);
                // float3 pos = o.dist*mray.ray.dir + mray.ray.pos;
                // o.dist /= mray.correction; 
                // o.normal = (o.dist <= 0)? 0:
                // mul(
                // transpose(mat),
                // float4(sphereNormal(pos),1)).xyz;
                // return o;
            }

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

            // bool foreground(float dist0, float dist1) {
                //     // return true if dist0 is foreground, false if else.
                //     return (0 < dist0 && 0 < dist1)? (dist0 < dist1): (dist1 < dist0);
                //     // return 0 < dist0 && dist0 < dist1;
            // }
            intersection foreground(intersection b0, intersection b1) {
                // return true if dist0 is foreground, false if else.
                intersection o;
                bool isB0 = (0 < b0.dist && 0 < b1.dist)? (b0.dist < b1.dist): (b1.dist < b0.dist);
                o.dist = isB0? b0.dist: b1.dist;
                o.normal = isB0? b0.normal: b1.normal;
                return o;
                // return 0 < dist0 && dist0 < dist1;
            }

            intersection scene(rayDef ray) {
                
                intersection plane0,
                sphere0, sphere1;
                float4x4 matPlane0 = IDMAT4,
                matSphere0 = IDMAT4, matSphere1 = IDMAT4;
                
                matPlane0 -= shiftMatrix(float3(0,0,0));
                plane0 = plane(matPlane0, ray);

                matSphere0 = mul(matSphere0, scaleMatrix(float3(2,2,2)));
                // matSphere0 += shiftMatrix(float3(0.3,0,0));
                sphere0 = sphere(matSphere0, ray);
                // posS0 = s0*sphere0.ray.dir + sphere0.ray.pos;
                
                matSphere1 -= shiftMatrix(float3(0,-0.5,0));
                matSphere1 = mul(matSphere1, scaleMatrix(float3(2,2,1)));
                sphere1 = sphere(matSphere1, ray);
                // posS1 = s1*sphere1.ray.dir + sphere1.ray.pos;

                intersection s;
                
                // bool isS0 = foreground(sphere0.dist,sphere1.dist);
                // // if(isS0) {s = sphere0;} else {s = sphere1;}
                // s = isS0? sphere0: sphere1;
                s = foreground(plane0,
                foreground(sphere0,sphere1)
                )
                ;
                // s.dist = s1;
                // float3 pos = isS0? posS0: posS1;
                // float4x4 matScene = isS0? matSphere0: matSphere1;
                // // float3 pos = posS1;
                // s.normal = (0 < s.dist)?
                // mul(
                // transpose(matScene),
                // float4(sphereNormal(pos),1)).xyz:
                // 0;
                return s;
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