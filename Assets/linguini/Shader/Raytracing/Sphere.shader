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
            
            float square(float x) {
                return x*x;
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
                float theta; // the angle from z to x in radian
                float phi; // the angle from z to y in radian
            };

            struct polarCoord {
                float radius; // same as distance from the origin
                direction dir;
            };

            float3 polar2cartesian(polarCoord pos) {
                float3 unit = float3(0,0,1);
                unit.zx = rotate(unit.zx, pos.dir.theta);
                unit.zy = rotate(unit.zy, pos.dir.phi);
                return pos.radius * unit;
            }

            polarCoord catresian2polar(float3 pos) {
                polarCoord o;
                o.radius = length(pos);
                o.dir.theta = sign(pos.x) * acos(length(pos.zx)/pos.y);
                o.dir.phi = sign(pos.y) * acos(length(pos.zy)/pos.x);
                return o;
            }
            
            struct cylinderCoord {
                float 
            }

            struct rayDef {
                float3 pos;
                direction dir;
            };

            float plane(float3 pos) {
                return pos.x + pos.y + pos.z;
            }

            // float decodePlane(float result) {
                //     return -result;
            // }

            float sphere(float3 pos) {
                return square(pos.x) + square(pos.y) + square(pos.z) - 0.25;
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

            float torus(float3 pos) {
                return square(sqrt(square(pos.x) + square(pos.y)) - 0.1) + square(pos.z) - 0.25;
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

            float scene(rayDef ray) {
                
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

                #if defined(WORLD)
                    ray.pos = _WorldSpaceCameraPos;
                #elif defined(OBJECT)
                    // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
                    ray.pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                #else
                    ray.pos = 0;
                #endif
                

                // レイの進行方向
                float3 rayDir = i.pos.xyz - ray.pos;
                ray.dir.theta = sign(rayDir.x) * acos(length(rayDir.zx)/rayDir.y);
                ray.dir.phi = sign(rayDir.y) * length(rayDir.zy)/rayDir.x;

                clip(-1*scene(ray));
                
                return _Color;
            }

            ENDCG
        }

        // pull in shadow caster from linguini/ShaderUtility shader
        UsePass "linguini/ShaderUtility/ShadowCaster"
    }
}