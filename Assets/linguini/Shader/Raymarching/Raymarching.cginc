#ifndef RAYMARCHING_INCLUDED
    #define RAYMARCHING_INCLUDED

    fixed4 _Color;
    fixed4 _BackGround;
    float _MaxDistance;
    float _Resolution;

    struct appdata
    {
        float4 vertex : POSITION;
        // float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        // float2 uv : TEXCOORD0;
        // UNITY_FOG_COORDS(1)
        float4 pos : POSITION1;
        float4 vertex : SV_POSITION;
    };

    struct fragout
    {
        fixed4 color : SV_Target;
        float depth : SV_Depth;
    };

    // sampler2D _MainTex;
    // float4 _MainTex_ST;

    v2f vert (appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        #ifdef WORLD
            // メッシュのワールド座標を代入
            o.pos = mul(unity_ObjectToWorld, v.vertex);
        #elif OBJECT
            // メッシュのローカル座標を代入
            o.pos = v.vertex;
        #else
            o.pos = mul(unity_ObjectToWorld, v.vertex);
        #endif
        // o.uv = v.uv;
        return o;
    }

    float min3(float x, float y, float z){
        return min(x, min(y, z));
    }

    float square(float x) {
        return x*x;
    }
    float square(float3 v) {
        return dot(v, v);
    }

    float3 repeat(float3 pos){
        float size = 4;
        pos -= round(pos/ size);
        return pos;
    }

    float2 rotate(float2 pos, float r) {
        float2x2 m = float2x2(cos(r), sin(r), -sin(r), cos(r));
        return mul(pos,m);
    }

    float2 rotate90(float2 pos){
        float2x2 m = float2x2(0,1,-1,0);
        return mul(m, pos);
    }

    float2 rotate45(float2 pos){
        float x = pow(2, 1/2) / 2;
        float2x2 m = float2x2(x,x,-x,x);
        return mul(m, pos);
    }


    float sphereDist(float3 pos){
        return length(pos) - 0.5;
    }

    float cubeDist(float3 pos){
        float3 q = abs(pos) - 0.5;
        return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0);
    }

    float pillarXDist(float3 pos) {
        pos = abs(pos);
        return max(pos.y, pos.z) - 0.5;
    }
    float pillarYDist(float3 pos) {
        pos = abs(pos);
        return max(pos.z, pos.x) - 0.5;
    }
    float pillarZDist(float3 pos) {
        pos = abs(pos);
        return max(pos.x, pos.y) - 0.5;
    }

    float pillarXYZDist(float3 pos){
        return min3(
        pillarXDist(pos),
        pillarYDist(pos),
        pillarZDist(pos)
        );
    }
    
    #define EPS 0.0001
    
    float3 getSceneNormal(float3 pos){
        // float def = sceneDist(pos);
        float3 delta = float3(EPS, 0, 0);
        return normalize(float3(
        sceneDist(1, pos + delta.xyz) - sceneDist(1, pos - delta.xyz),
        sceneDist(1, pos + delta.yzx) - sceneDist(1, pos - delta.xyz),
        sceneDist(1, pos + delta.zxy) - sceneDist(1, pos - delta.xyz)
        ));
    }

    struct marchResult {
        float totalDist;
        bool intersect;
        float3 pos;
        float iter;
    };

    marchResult raymarch (float3 pos, float3 rayDir) {
        marchResult o;

        #ifdef WORLD
            float clarity = dot(rayDir, -UNITY_MATRIX_V[2].xyz);
        #else // #elif OBJECT
            float clarity = dot(mul((float3x3)unity_ObjectToWorld, rayDir), -UNITY_MATRIX_V[2].xyz);
        #endif
        
        float maxDist = 100 * _MaxDistance;
        float minDist = pow(5*clarity, -5);

        // float minDist = EPS;
        o.pos = pos;
        o.totalDist = 0;
        o.iter = 0;
        float marchingDist;
        do {
            marchingDist = (sceneDist(clarity, o.pos));
            o.totalDist += marchingDist;
            o.pos += marchingDist*rayDir;
            o.iter++;
        } while (minDist <= marchingDist && o.totalDist < maxDist);
        o.intersect = minDist < marchingDist;
        return o;
    }
    
    // https://techblog.kayac.com/unity_advent_calendar_2018_15
    // RGB->HSV変換
    float3 rgb2hsv(float3 rgb)
    {
        float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        float4 p = rgb.g < rgb.b ? float4(rgb.bg, K.wz) : float4(rgb.gb, K.xy);
        float4 q = rgb.r < p.x ? float4(p.xyw, rgb.r) : float4(rgb.r, p.yzx);

        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }
    // HSV->RGB変換
    float3 hsv2rgb(float3 hsv)
    {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(frac(hsv.xxx + K.xyz) * 6.0 - K.www);
        return hsv.z * lerp(K.xxx, saturate(p - K.xxx), hsv.y);
    }
    
    #define K 16
    fixed shadowmarch (float3 pos, float3 rayDir) {
        // float maxDistance = 1; // 10 * _MaxDistance;
        // float3 initPos = pos;
        float result = 1;
        float marchingDist;
        float totalDist = 0;
        [unroll(35)] for (uint i = 0; i < 35; i++)
        {
            marchingDist = abs(sceneDist(1, pos));
            if (marchingDist < EPS){
                return 0;
            }

            totalDist += marchingDist;
            pos += marchingDist * rayDir;
            result = min(result, K * marchingDist / totalDist);
        }
        return result;
    }

    fixed4 lighting(float3 pos, fixed shadow, fixed4 col) {
        float3 normal = getSceneNormal(pos);

        float3 lightDir;
        #ifdef WORLD
            lightDir = _WorldSpaceLightPos0.xyz;
        #elif OBJECT
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

        // return fixed4(lerp(col.rgb*0.01, col.rgb, shadow) * lighting + (ambient? ambient: 0.1), col.a);
        return fixed4(lerp(col.rgb*(ambient? ambient: 0.1), col.rgb, shadow * lighting), col.a);
    }


    fragout frag (v2f i)
    {
        fragout o;
        
        float3 pos;
        #ifdef WORLD
            pos = _WorldSpaceCameraPos;
        #elif OBJECT
            // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
            pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
        #else
            pos = _WorldSpaceCameraPos;
        #endif
        
        // レイの進行方向
        float3 rayDir = normalize(i.pos.xyz - pos);
        marchResult result = raymarch(pos, rayDir);
        // if (pos.x == 0, pos.y == 0, pos.z == 0) discard;
        if(result.intersect) discard;
        pos = result.pos;

        float4 projectionPos;
        #ifdef WORLD
            projectionPos = UnityWorldToClipPos(float4(pos, 1.0));
        #elif OBJECT
            projectionPos = UnityObjectToClipPos(float4(pos, 1.0));
        #else
            projectionPos = UnityWorldToClipPos(float4(pos, 1.0));
        #endif
        o.depth = projectionPos.z / projectionPos.w;

        rayDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
        o.color.a = _Color.a;
        o.color.rgb = rgb2hsv(_Color.rgb);
        o.color.r = frac(o.color.r + result.iter*abs(_CosTime.w)/90.0);
        o.color.rgb = (hsv2rgb(o.color.rgb));
        #ifdef _SHADOW_ON
            o.color = lighting(
            pos, 
            shadowmarch(pos + rayDir * 10 * EPS, rayDir),
            o.color
            );
        #else // #elif _SHADOW_OFF
            o.color = lighting(pos, 1, o.color);
        #endif
        return o;
    }

    // fragout frag (v2f i)
    // {
        //     // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
        //     float3 pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
        //     //float3 pos = _WorldSpaceCameraPos;
        //     // レイの進行方向
        //     float3 rayDir = normalize(i.pos.xyz - pos);
        //     return raymarch(pos, rayDir);
    // }

#endif