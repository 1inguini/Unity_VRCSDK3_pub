#ifndef RAYMARCHING_INCLUDED
    #define RAYMARCHING_INCLUDED

    #ifndef CAMERA_SPACING
        #define CAMERA_SPACING 0
    #endif

    #ifdef WORLD
        half _Size;
    #endif
    
    #ifdef BACKGROUND
        fixed4 _BackGround;
    #endif

    fixed4 _Color;
    half _MaxDistance;
    half _Resolution;

    // // max size of float
    //#define INF 3.402823466e+38
    // max size of half
    #define INF 60000
    #define EPS 10e-7

    #include "Lighting.cginc"
    #include "Misc.cginc"
    #include "SDF.cginc"

    #ifdef COLORDIST
        half4 coloredSceneDist(half4 color, distIn i);

        inline half sceneDist(distIn i) {
            return coloredSceneDist(0, i).w;
        }
    #else
        half sceneDist(distIn i);
    #endif

    struct appdata
    {
        half4 vertex : POSITION;
        half2 uv : TEXCOORD0;
    };

    struct v2f
    {
        half2 uv : TEXCOORD0;
        // UNITY_FOG_COORDS(1)
        half4 pos : POSITION1;
        half4 vertex : SV_POSITION;
    };

    struct fragout
    {
        fixed4 color : SV_Target;
        #if !defined(NODEPTH)
            half depth : SV_Depth;
        #endif
    };

    // sampler2D _MainTex;
    // half4 _MainTex_ST;

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
        o.uv = v.uv;
        return o;
    }

    // inline half3 getSceneNormal(distIn din){
        //         half def = sceneDist(din);
        //         half2 delta = half2(EPS, 0);
        //         return normalize(half3(
        //         saturate(sceneDist(addToPos(din, delta.xyy))) - def,
        //         saturate(sceneDist(addToPos(din, delta.yxy))) - def,
        //         saturate(sceneDist(addToPos(din, delta.yyx))) - def
        //         ));
    // }
    inline half3 getSceneNormal(distIn din){
        // half def = sceneDist(clarity, pos);
        half2 delta = half2(EPS, -EPS); 
        half2 plusminus = half2(INF, -INF)*0.5;
        half3 normal = half3(
        plusminus.xyy*(sceneDist(addToPos(din, delta.xyy))) +
        plusminus.yyx*(sceneDist(addToPos(din, delta.yyx))) +
        plusminus.yxy*(sceneDist(addToPos(din, delta.yxy))) +
        plusminus.xxx*(sceneDist(addToPos(din, delta.xxx)))
        );
        half normalLength = length(normal);
        return normalLength? normal/normalLength: float3(1,0,0);
    }

    struct marchResult {
        half3 pos;
        half totalDist;
        half totalDistRatio;
        bool intersect;
        half nearestDist;
        half iter;
        half clarity;
        #ifdef COLORDIST
            half4 color;
        #endif
    };
    
    #ifdef COLORDIST
        marchResult raymarch (half4 color, distIn din, half3 rayDir)
    #else
        marchResult raymarch (distIn din, half3 rayDir)
    #endif
    {
        marchResult o;

        half maxDist = 500 * (EPS + _MaxDistance * din.clarity);
        uint maxIter = 500 * din.clarity;
        half minDist = din.pixSize;
        half pixRatio = din.pixSize;
        o.pos = din.pos;
        o.totalDist = 0;
        o.nearestDist = maxDist;
        o.intersect = false;
        o.iter = 0;
        o.clarity = din.clarity;
        #ifdef COLORDIST
            half4 cMarchingDist;
        #endif
        half marchingDist;
        while (
        (!o.intersect) &&
        o.totalDist < maxDist &&
        marchingDist < 0.5*maxDist &&
        o.iter < maxIter
        ) {
            #ifdef COLORDIST
                cMarchingDist = coloredSceneDist(color, din);
                marchingDist = cMarchingDist.w;
            #else
                marchingDist = sceneDist(din);
            #endif
            o.totalDist += abs(marchingDist);
            din.pos = o.pos + o.totalDist*rayDir;
            minDist = din.pixSize*o.totalDist;
            // o.clarity = clarity*(maxDist-o.totalDist)/maxDist;
            din.clarity = o.clarity - square(o.totalDist/maxDist);
            o.nearestDist = min(o.nearestDist, marchingDist);
            o.iter++; 
            o.intersect = marchingDist < minDist;
        }
        o.pos = din.pos;
        o.clarity = din.clarity;
        o.totalDistRatio = o.totalDist / maxDist;
        #ifdef COLORDIST
            o.color = half4(cMarchingDist.rgb, 1);
        #endif
        return o;
    }

    #define K 16
    fixed shadowmarch (distIn din, half3 rayDir) {
        // half maxDistance = 1; // 10 * _MaxDistance;
        // half3 initPos = pos;
        half result = 1;
        half marchingDist;
        half totalDist = 0;
        [unroll(35)] for (uint i = 0; i < 35; i++)
        {
            marchingDist = abs(sceneDist(din));
            if (marchingDist < din.pixSize*totalDist) return 0;

            totalDist += marchingDist;
            din.pos += marchingDist * rayDir;
            result = min(result, K * marchingDist / totalDist);
        }
        return result;
    }

    half4 lighting(half3 wpos, half3 wnormal, fixed shadow, fixed4 col) {

        half3 lightDir;
        // #ifdef WORLD
        lightDir = _WorldSpaceLightPos0.xyz;
        lightDir -= _WorldSpaceLightPos0.w? wpos: 0;
        // #elif OBJECT
        //     //ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
        //     lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
        //     lightDir -= _WorldSpaceLightPos0.w? 0: mul(unity_WorldToObject, half4(pos, 1)).xyz;
        // #else
        //     lightDir = half3(1,-1,0);
        // #endif
        lightDir = normalize(lightDir);
        // #ifdef WORLD
        half3 lightProbe = ShadeSH9(fixed4(wnormal, 1));
        // #else // #elif OBJECT
        //     half3 lightProbe = ShadeSH9(fixed4(UnityObjectToWorldNormal(normal), 1));
        // #endif
        // half lightStrength = pow(0.5*(1 + (dot(normal, lightDir))), 3); // ディレクショナルライトがないと黒くなる
        half lightStrength = saturate(dot(wnormal, lightDir)); // ディレクショナルライトがないとき0になるべき
        half3 lighting = lerp(lightProbe, _LightColor0, lightStrength);
        
        half3 ambient = Shade4PointLights(
        unity_4LightPosX0, 
        unity_4LightPosY0, 
        unity_4LightPosZ0,
        unity_LightColor[0].rgb, 
        unity_LightColor[1].rgb, 
        unity_LightColor[2].rgb, 
        unity_LightColor[3].rgb,
        unity_4LightAtten0, 
        wpos, 
        wnormal
        );

        // return half4(lerp(col.rgb*0.01, col.rgb, shadow) * lighting + (ambient? ambient: 0.1), col.a);
        return half4(
        lerp(col.rgb*(ambient? ambient: 0.1), col.rgb, shadow * lighting),
        col.a
        );
    }

    bool nearlyEq(half x, half y) {
        return x - EPS <= y && y <= x + EPS;
    }

    half4 colorize(v2f i, marchResult m, half4 color);
    
    half4 distColor(half slip, marchResult m, half4 color) {
        half4 o;
        o = color;
        o.rgb = rgb2hsv(color.rgb);
        o.r = frac(o.r + slip + m.iter/90.0);
        o.rgb = hsv2rgb(o.rgb);
        return o;
    }
    
    fragout frag (v2f i)
    {
        fragout o;

        distIn din;

        #ifdef WORLD
            din.pos = _WorldSpaceCameraPos;
        #elif OBJECT
            // half3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
            din.pos = mul(unity_WorldToObject, half4(_WorldSpaceCameraPos, 1)).xyz;
        #else
            din.pos = _WorldSpaceCameraPos;
        #endif

        // レイの進行方向
        half3 rayDir = normalize(i.pos.xyz - din.pos);
        
        #ifdef WORLD
            din.pos += CAMERA_SPACING*rayDir;
            din.clarity = dot(rayDir, normalize(mul(FaceToWorld, half3(0,0,1))));
        #else // #ifdef OBJECT
            din.pos += mul((half3x3)unity_WorldToObject, CAMERA_SPACING*normalize(mul((half3x3)unity_ObjectToWorld, rayDir)));
            din.clarity = dot(rayDir, normalize(mul(unity_WorldToObject, mul(FaceToWorld, half3(0,0,1)))));
            // blurstep(blurstep(1-1.25*distance(half2(0.5, 0.45), screenPos.xy/_ScreenParams.x))),
        #endif

        // din.pixSize = length(ddx(i.pos) + ddy(i.pos))/length(i.pos.xyz - din.pos);
        // din.pixSize = rcp(_ScreenParams.y*UNITY_NEAR_CLIP_VALUE);
        din.pixSize = abs(ddx(rayDir.x))/length(rayDir);

        clip(din.clarity - 0.6);
        // clarity = enhanceVisibility((clarity - 0.8)/(1-0.8));
        // din.clarity = saturate(0.5 + (din.clarity - 0.7)/(1-0.7));
        // din.clarity = (din.clarity - 0.6)/(1-0.6);
        // din.clarity = (din.clarity - 0.6)*2.5;
        // // 0.6 <= din.clarity <= 1
        din.clarity = saturate(0.1 + step(0.65, din.clarity));
        #define REFRESH_RATE 90
        din.clarity *= saturate(unity_DeltaTime.w/REFRESH_RATE);

        #ifdef COLORDIST
            marchResult result = raymarch(_Color, din, rayDir);
        #else
            marchResult result = raymarch(din, rayDir);
        #endif
        
        #if !(defined(BACKGROUND) || defined(_DEBUG_ON))
            // if (pos.x == 0, pos.y == 0, pos.z == 0) discard;
            if(!result.intersect) discard;
        #endif

        half4 projectionPos;
        #ifdef WORLD
            projectionPos = UnityWorldToClipPos(half4(result.pos, 1.0));
        #elif OBJECT
            projectionPos = UnityObjectToClipPos(half4(result.pos, 1.0));
        #else
            projectionPos = UnityWorldToClipPos(half4(result.pos, 1.0));
        #endif

        #ifdef COLORDIST
            o.color = result.color;
        #else
            o.color = _Color;
        #endif

        o.color = colorize(i, result, o.color);
        
        #if !defined(NODEPTH)
            #if defined(BACKGROUND) && defined(PARTIAL_DEPTH)
                // o.depth = result.intersect? projectionPos.z / projectionPos.w: 0;
                half4 p = UnityWorldToClipPos(i.pos);
                o.depth = result.totalDist < length(i.pos.xyz - din.pos) && result.intersect?
                projectionPos.z/projectionPos.w:
                p.z/p.w;
            #elif defined(BACKGROUND)
                o.depth = result.intersect? projectionPos.z / projectionPos.w: 0;
            #else
                o.depth = projectionPos.z / projectionPos.w;
            #endif
        #endif

        din.pos = result.pos;
        din.clarity = result.clarity;

        half3 normal = getSceneNormal(addToPos(din, -EPS*rayDir));

        #if !defined(_SHADE_OFF)
            #ifdef _SHADOW_ON
                #ifdef OBJECT
                    rayDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
                    half shadow = shadowmarch(addToPos(din, 0.001*rayDir), rayDir);
                    normal = UnityObjectToWorldNormal(normal);
                    din.pos = mul(unity_ObjectToWorld, half4(din.pos, 1)).xyz;
                #else // #elif WORLD
                    rayDir = _WorldSpaceLightPos0;
                    half shadow = shadowmarch(addToPos(din, 0.001*rayDir), rayDir);
                #endif

                o.color = !result.intersect? o.color: lighting(
                din.pos, 
                normal,
                shadow,
                o.color
                );
            #else // #elif _SHADOW_OFF
                o.color = !result.intersect? o.color: lighting(din.pos, normal, 1, o.color);
            #endif
        #endif

        #ifdef BACKGROUND
            #ifdef GLOW
                o.color = result.intersect? o.color: _BackGround*result.totalDistRatio+pow(result.nearestDist+1, -K)*o.color;
            #else
                o.color = lerp(result.intersect? o.color: _BackGround, _BackGround, result.totalDistRatio);
            #endif
        #endif
        #if defined(_DEBUG_ON)            
            // o.color.rgb = 1 - 2*din.clarity;
            // o.color.rgb = dot(rayDir, normalize(mul(unity_WorldToObject, mul(FaceToWorld, half3(0,0,1)))));
            // o.color.rgb = 100*din.pixSize;
            o.color.rgb = 0.01*unity_DeltaTime.y;
        #endif
        return o;
    }
#endif