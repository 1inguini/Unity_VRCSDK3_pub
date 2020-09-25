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

            // float4x4 rotationMatrix(direction dir, float theta) {
                //     float3 n = dir2unitVec(dir);
                //     float cost = cos(theta);
                //     float r = 1 - cost;
                //     float sint = sin(theta);
                //     float3 sq = float3(n.x*n.x, n.y*n.y, n.z*n.z);
                //     float3 adj = float3(n.x*n.y, n.y*n.z, n.z*n.x);
                //     return float4x4(
                //     sq.x*r + cost, adj.x*r - n.z*sint, adj.z*r + n.y*sint, 0,
                //     adj.x*r + n.z*sint, sq.y*r + cost, adj.y*r - n.x*sint, 0,
                //     adj.z*r - n.y*sint, adj.y*r + n.x*sint, sq.z*r + cost, 0,
                //     0, 0, 0, 1
                //     );
            // }
            // float4x4 rotationMatrix(float3 n, float theta) {
                //     float sint = sin(theta);
                //     float cost = cos(theta);
                //     float r = 1 - cost;
                //     float3 sq = float3(n.x*n.x, n.y*n.y, n.z*n.z);
                //     float3 adj = float3(n.x*n.y, n.y*n.z, n.z*n.x);
                //     return float4x4(
                //     sq.x*r + cost, adj.x*r - n.z*sint, adj.z*r + n.y*sint, 0,
                //     adj.x*r + n.z*sint, sq.y*r + cost, adj.y*r - n.x*sint, 0,
                //     adj.z*r - n.y*sint, adj.y*r + n.x*sint, sq.z*r + cost, 0,
                //     0, 0, 0, 1
                //     );
            // }

            // float4x4 rotationMatrixCos(direction dir, float cost) {
                //     float3 n = dir2unitVec(dir);
                //     float r = 1 - cost;
                //     float sint = sqrt(1-square(cost));
                //     float3 sq = float3(n.x*n.x, n.y*n.y, n.z*n.z);
                //     float3 adj = float3(n.x*n.y, n.y*n.z, n.z*n.x);
                //     return float4x4(
                //     sq.x*r + cost, adj.x*r - n.z*sint, adj.z*r + n.y*sint, 0,
                //     adj.x*r + n.z*sint, sq.y*r + cost, adj.y*r - n.x*sint, 0,
                //     adj.z*r - n.y*sint, adj.y*r + n.x*sint, sq.z*r + cost, 0,
                //     0, 0, 0, 1
                //     );
            // }
            // float4x4 rotationMatrixCos(float3 n, float cost) {
                //     float r = 1 - cost;
                //     float sint = sqrt(1-square(cost));
                //     float3 sq = float3(n.x*n.x, n.y*n.y, n.z*n.z);
                //     float3 adj = float3(n.x*n.y, n.y*n.z, n.z*n.x);
                //     return float4x4(
                //     sq.x*r + cost, adj.x*r - n.z*sint, adj.z*r + n.y*sint, 0,
                //     adj.x*r + n.z*sint, sq.y*r + cost, adj.y*r - n.x*sint, 0,
                //     adj.z*r - n.y*sint, adj.y*r + n.x*sint, sq.z*r + cost, 0,
                //     0, 0, 0, 1
                //     );
            // }

            float3x3 rotationMatrix(float3 thetas) {
                float s, c;
                s = sin(thetas.x);
                c = cos(thetas.x);
                float3x3 o = float3x3(1,0,0, 0,c,-s, 0,s,c);
                s = sin(thetas.y);
                c = cos(thetas.y);
                o *= float3x3(c,0,s, 0,1,0, -s,0,c);
                s = sin(thetas.z);
                c = cos(thetas.z);
                o *= float3x3(c,-s,0, s,c,0, 0,0,1);
                return o;                
            }

            float4x4 shiftMatrix(float3 pos) {
                float4x4 mat = IDMAT4;
                mat[0][3] += pos.x;
                mat[1][3] += pos.y;
                mat[2][3] += pos.z;
                return mat; // + float4x4(0,0,0,pos.x, 0,0,0,pos.y, 0,0,0,pos.z, 0,0,0,0)
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

            // float sphere(float3 pos) {
                //     // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                //     return length(pos) - 0.5;
            // }
            
            float solveQuadratic(float a, float b, float c) {
                float d = square(b) - 4*a*c;
                return d < 0? -1: (-b - sqrt(d))/(2*a);
            }

            float solveQuadraticHalf(float a, float halfB, float c) {
                float quartD = square(halfB) - a * c;
                return quartD < 0? -1: (-halfB - sqrt(quartD))/a;
            }

            float sphere(rayDef ray) {
                return solveQuadraticHalf(
                square(ray.dir),
                dot(ray.dir, ray.pos),
                square(ray.pos) - 0.25
                );
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

            // float torus(float3 pos) {
                //     return distance((length(pos.xy) - 0.1), pos.z) - 0.25;
                //     // return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
            // }

            // float torus(rayDef ray) {
                //     return;
            // }

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

            float scene(rayDef ray) {
                float3 spherePos = float3(0,0,1);
                float4x4 sphereMove = IDMAT4;
                // sphereMove *= rotationMatrixCos(float3(0,1,0), _CosTime.x);
                // sphereMove *= float4x4(_CosTime.x,0,_SinTime.x,0, 0,1,0,0, -_SinTime.x,0,_CosTime.x,0, 0,0,0,1);
                // sphereMove *= shiftMatrix(spherePos);
                // sphereMove *= float4x4(2,0,0,0, 0,2,0,0, 0,0,2,0, 0,0,0,1);
                // float3x3 rot = rotationMatrix(float3(0,0,_Time.y));
                //ray.pos += spherePos;
                //ray.pos = mul(ray.pos, rot);
                // ray.pos = mul(float4(ray.pos, 1), rot);
                //ray.dir = normalize(mul(ray.dir, rot));
                
                rayDef ray0, ray1;
                ray0 = ray;
                ray1 = ray;
                ray0.pos -= float3(0.3,0,0);
                ray0.pos *= 2;
                ray1.pos += float3(0.3,0,0);
                return max(sphere(ray0), sphere(ray1));
                return 0;
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
            fixed4 frag (v2f i) : SV_TARGET
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
                
                clip(scene(ray));
                
                return _Color;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}