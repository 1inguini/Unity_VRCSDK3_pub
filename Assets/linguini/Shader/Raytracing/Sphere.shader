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
            
            #define IDMAT4 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
            
            float square(float x) {
                return x*x;
            }
            float square(float3 v) {
                return dot(v,v);
            }

            float solveQuadratic(float a, float b, float c) {
                float d = square(b) - 4*a*c;
                return d < 0? -1: (-b - sqrt(d))/(2*a);
            }

            float solveQuadraticHalf(float a, float halfB, float c) {
                float quartD = square(halfB) - a * c;
                return quartD < 0? -1: (-halfB - sqrt(quartD))/a;
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

            float4x4 rodriguesMatrix(float3 n, float theta) {
                float sinT = sin(theta);
                float cosT = cos(theta);
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
            
            intersection foreground(intersection b0, intersection b1) {
                // return b0 if b0 is foreground, b1 if else.
                bool isB0 = (0 < b0.dist && 0 < b1.dist)? (b0.dist < b1.dist): (b1.dist < b0.dist);
                b0.dist = isB0? b0.dist: b1.dist;
                b0.normal = isB0? b0.normal: b1.normal;
                return b0;
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

            #define INTERSECTION_FUNC(_bodyName) intersection _bodyName##(float4x4 mat, rayDef ray) { \
                intersection o; \
                movedRay mray = matrixApply(mat, ray); \
                o.dist = _bodyName##Dist(mray.ray); \
                float3 pos = o.dist*mray.ray.dir + mray.ray.pos; \
                o.dist /= mray.correction; \
                o.normal = (o.dist <= 0)? 0: \
                mul( \
                transpose(mat), \
                float4(_bodyName##Normal(pos),1)).xyz; \
                return o; \
            }

            float planeDef(float3 normal, float3 pos) {
                return dot(normal, pos);
            }

            inline float planeFromNormalDist(float3 normal, rayDef ray) {
                float DdotN = dot(ray.dir, normal);
                return -dot(ray.pos, normal)/(DdotN? DdotN: 1);
            }

            intersection plane(float4x4 mat, rayDef ray) {
                intersection o;
                movedRay mray = matrixApply(mat, ray);
                o.normal = float3(0,sign(mray.ray.pos.y),0);
                o.dist = o.normal.y? planeFromNormalDist(o.normal, mray.ray): -1;
                o.normal = (o.dist <= 0)? 0: mul(transpose(mat), float4(o.normal,1)).xyz;
                return o;
            }

            float sphereDef(float3 pos) {
                // return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
                return length(pos) - 0.5;
            }
            
            float3 sphereNormal(float3 pos){
                return pos - 0;
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

            float torusDef(float3 pos) {
                return distance((length(pos.xy) - 0.1), pos.z) - 0.25;
                // return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
            }
            
            NORMAL_FUNC(torus)
            

            intersection scene(rayDef ray) {
                
                intersection plane0,
                sphere0, sphere1;
                float4x4 matPlane0 = IDMAT4,
                matSphere0 = IDMAT4, matSphere1 = IDMAT4;
                
                matPlane0 -= shiftMatrix(float3(0,0,0));
                matPlane0 = mul(matPlane0, rodriguesMatrix(normalize(float3(0,0,1)), UNITY_HALF_PI*0.5));
                plane0 = plane(matPlane0, ray);

                matSphere0 = mul(matSphere0, scaleMatrix(float3(2,2,2)));
                // matSphere0 += shiftMatrix(float3(0.3,0,0));
                sphere0 = sphere(matSphere0, ray);
                // posS0 = s0*sphere0.ray.dir + sphere0.ray.pos;
                
                matSphere1 -= shiftMatrix(float3(0,-0.5,0));
                matSphere1 = mul(matSphere1, scaleMatrix(float3(2,2,1)));
                sphere1 = sphere(matSphere1, ray);
                // posS1 = s1*sphere1.ray.dir + sphere1.ray.pos;

                return foreground(plane0, foreground(sphere0,sphere1));
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