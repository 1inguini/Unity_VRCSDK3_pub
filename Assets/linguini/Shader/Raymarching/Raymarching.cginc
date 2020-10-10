#ifndef RAYMARCHING_INCLUDED
    #define RAYMARCHING_INCLUDED

    fixed4 _Color;
    fixed4 _BackGround;
    float _MaxDistance;
    float _Resolution;

    float sceneDist(float clarity, float3 pos);

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

    inline float min3(float x, float y, float z){
        return min(x, min(y, z));
    }

    inline float square(float x) {
        return x*x;
    }
    inline float square(float3 v) {
        return dot(v, v);
    }

    inline float blurstep(float x) {
        return sin(UNITY_HALF_PI*x);
    }

    float3 fold(float3 normal, float3 pos) {
        return pos - 2*min(0, dot(pos, normal))*normal;
    }
    
    float3 sphereFold (float radius, float3 pos) {
        float R2 = square(radius);
        float r2 = square(pos);
        return (r2 < R2? R2/r2: 1)*pos;
    }
    
    float3 repeat(float3 pos){
        float size = 4;
        pos -= round(pos/size);
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
    float4x4 rotationMatrixCos(float cosx, float cosy, float cosz) {
        float c, s;
        c = cosx;
        s = sqrt(1 - square(cosx));
        float4x4 o = float4x4(1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1);
        c = cosy;
        s = sqrt(1 - square(cosy));
        o = mul(o, float4x4(c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1));
        c = cosz;
        s = sqrt(1 - square(cosz));
        o = mul(o, float4x4(c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1));
        return o;     
    }
    float4x4 rotationMatrixCos(float3 coss) {
        return rotationMatrixCos(coss.x, coss.y, coss.z);                
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
    
    #define EPS 0.00001

    float3 getSceneNormal(float3 pos){
        float def = sceneDist(1, pos);
        float3 delta = float3(EPS, 0, 0);
        return normalize(float3(
        sceneDist(1, pos + delta.xyz) - def,
        sceneDist(1, pos + delta.yzx) - def,
        sceneDist(1, pos + delta.zxy) - def
        ));
    }


    // https://qiita.com/RamType0/items/baf2b9d5ce0f9fc458be {
        float3 ScaleOf(in float3x3 mat){
            return float3(length(mat._m00_m10_m20),length(mat._m01_m11_m21),length(mat._m02_m12_m22));
        }
        float3 ScaleOf(in float4x4 mat){
            return ScaleOf((float3x3)mat);
        }
        float3 PositionOf(in float4x4 mat){
            return mat._m03_m13_m23;
        }
        float3x3 RotationOf(float3x3 mat,float3 scale){
            mat._m00_m10_m20 /= scale.x;
            mat._m01_m11_m21 /= scale.y;
            mat._m02_m12_m22 /= scale.z;
            return mat;

        }
        float3x3 RotationOf(float4x4 mat,float3 scale){
            return RotationOf((float3x3)mat,scale);
        }


        float4x4 BuildMatrix(in float3x3 mat,in float3 offset)
        {
            return float4x4(
            float4(mat[0],offset.x),
            float4(mat[1],offset.y),
            float4(mat[2],offset.z),
            float4(0,0,0,1)
            );
        }
        float3x3 Columns(float3 column0,float3 column1,float3 column2){
            float3x3 ret;
            ret._m00_m10_m20 = column0;
            ret._m01_m11_m21 = column1;
            ret._m02_m12_m22 = column2;
            return ret;
        }
        //ベクトルを線形球面補間しますが、入力ベクトルは正規化されている必要があり、戻り値のベクトルは正規化されていません。
        //Abnormal・・・？
        float3 SlerpAbnormal(float3 normalizedA,float3 normalizedB,float t){
            float angle = acos(dot(normalizedA,normalizedB));//acosクッソ重い
            //float _sin = sin(angle);
            float aP = sin(mad(-angle,t,angle));
            float bP = sin(angle * t);
            return angle ? (aP * normalizedA + bP * normalizedB) : normalizedA;
        }
        //ベクトルを球面線形補間します。
        float3 Slerp(float3 a,float3 b,float t){
            return normalize(SlerpAbnormal(normalize(a),normalize(b),t));
        }
        //回転行列を球面線形補間します。
        float3x3 Slerp(in float3x3 a ,in float3x3 b,in float t){
            //OpenGLは列優先メモリレイアウトなのでこのままでOK
            #if SHADER_TARGET_GLSL
                float3 iy = SlerpAbnormal(a._m01_m11_m21,b._m01_m11_m21,t);//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = SlerpAbnormal(a._m02_m12_m22,b._m02_m12_m22,t);//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);//直交する正規化ベクトル同士のクロス積も正規化されている
                return Columns(ix,iy,iz);
            #else
                //DirectXは行優先のメモリレイアウトなので、できれば行ベースで計算したい・・・
                //ところで回転行列って直交行列ですね？
                //回転行列の0,1,2列=この行列で回転をした後のX,Y,Z軸ベクトル
                //回転行列の0,1,2行=回転行列の転置行列の0,1,2列
                //                =回転行列の逆行列の0,1,2列
                //                =逆回転の回転行列の0,1,2列
                //                =この行列の逆回転の行列で回転をしたあとのX,Y,Z軸ベクトル
                //ということで、この関数の中では終始逆回転、かつ転置した状態として取り扱ってるのでこの計算の結果は正しいです。
                float3 iy = SlerpAbnormal(a[1],b[1],t);//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = SlerpAbnormal(a[2],b[2],t);//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);//直交する正規化ベクトル同士のクロス積も正規化されている
                return float3x3(ix,iy,iz);
            #endif
        }

        //移動、回転行列の回転をSlerp、移動をLerpします。
        float4x4 InterpolateTRMatrix(in float4x4 a,in float4x4 b,in float t){
            return BuildMatrix(Slerp((float3x3)a,(float3x3)b,t), lerp(PositionOf(a),PositionOf(b),t));
        }
        //回転行列の平均を求めます。Slerp(a,b,0.5)より遥かに高速です。
        float3x3 RMatrixAverage(in float3x3 a,in float3x3 b){
            //OpenGLは列優先メモリレイアウトなのでこのままでOK
            #if SHADER_TARGET_GLSL

                float3 iy = (a._m01_m11_m21 + b._m01_m11_m21)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = (a._m02_m12_m22 + b._m02_m12_m22)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);//直交する正規化ベクトル同士のクロス積も正規化されている
                return Columns(ix,iy,iz);
            #else
                //DirectXは行優先のメモリレイアウトなので、できれば行ベースで計算したい・・・
                //ところで回転行列って直交行列ですね？
                //回転行列の0,1,2列=この行列で回転をした後のX,Y,Z軸ベクトル
                //回転行列の0,1,2行=回転行列の転置行列の0,1,2列
                //                =回転行列の逆行列の0,1,2列
                //                =逆回転の回転行列の0,1,2列
                //                =この行列の逆回転の行列で回転をしたあとのX,Y,Z軸ベクトル
                //ということで、この関数の中では終始逆回転、かつ転置した状態として取り扱ってるのでこの計算の結果は正しいです。
                float3 iy = (a[1] + b[1])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = (a[2] + b[2])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);  //直交する正規化ベクトル同士のクロス積も正規化されている
                return float3x3(ix,iy,iz);
            #endif

        }
        //移動、回転行列の平均を求めます。InterpolateTRMatrix(a,b,0.5)より遥かに高速です。
        float4x4 TRMatrixAverage(in float4x4 a,in float4x4 b){
            return BuildMatrix(RMatrixAverage((float3x3)a,(float3x3)b),(PositionOf(a)+PositionOf(b))*0.5);
        }
        #if defined(USING_STEREO_MATRICES)
            #define StereoWorldSpaceEyeRotation (float3x3)unity_StereoCameraToWorld
            #define FaceToWorld TRMatrixAverage(unity_StereoCameraToWorld[0],unity_StereoCameraToWorld[1])
            #define WorldSpaceFaceRotation RMatrixAverage(StereoWorldSpaceEyeRotation[0],StereoWorldSpaceEyeRotation[1])

            float3 FaceToWorldPos(float3 pos) {return mul(FaceToWorld,float4(pos,1)).xyz;}

            float3 ObjectToFaceAlignedWorldPosUnscaled(in float3 pos)
            {
                float3 ret = mul(WorldSpaceFaceRotation,pos);//ワールド空間でのカメラの向きに回転
                ret += PositionOf(unity_ObjectToWorld);//オブジェクトのワールド座標を加算
                return ret;
            }
            float3 ObjectToFaceAlignedWorldPos(float3 pos)
            {
                pos *= ScaleOf(unity_ObjectToWorld);//unity_ObjectToWorldからのスケールの抽出、適応
                return ObjectToFaceAlignedWorldPosUnscaled(pos);
            }
        #endif
    // }

    struct marchResult {
        float totalDist;
        bool intersect;
        float3 pos;
        float iter;
    };
    
    marchResult raymarch (float clarity, float3 pos, float3 rayDir) {
        marchResult o;

        float maxDist = 1000 * _MaxDistance;
        float minDist = (EPS + 1 - blurstep(blurstep(clarity)));
        o.pos = pos;
        o.totalDist = 0;
        o.iter = 0;
        float marchingDist;
        do {
            marchingDist = sceneDist(clarity, o.pos);
            o.totalDist += marchingDist;
            o.pos += marchingDist*rayDir;
            o.iter++;
        } while (minDist <= marchingDist && o.totalDist < maxDist && marchingDist < 0.5*maxDist);
        o.intersect = marchingDist < minDist;
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

    fixed4 lighting(float3 pos, float3 normal, fixed shadow, fixed4 col) {

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

    bool nearlyEq(float x, float y) {
        return x - EPS <= y && y <= x + EPS;
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
        marchResult result = raymarch(
        #if defined(UNITY_SINGLE_PASS_STEREO)
            abs(dot(rayDir, normalize(mul(unity_WorldToObject, mul(FaceToWorld, float3(0,0,1)))))),
        #else
            abs(dot(rayDir, normalize(mul(unity_WorldToObject, mul((float3x3)unity_CameraToWorld, float3(0,0,1)))))),
            // blurstep(blurstep(1-1.25*distance(float2(0.5, 0.45), screenPos.xy/_ScreenParams.x))),
        #endif
        pos,
        rayDir
        );
        
        // if (pos.x == 0, pos.y == 0, pos.z == 0) discard;
        if(!result.intersect) discard;
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

        o.color.a = _Color.a;
        o.color.rgb = rgb2hsv(_Color.rgb);
        o.color.r = frac(o.color.r + result.iter*abs(_CosTime.w)/90.0);
        o.color.rgb = (hsv2rgb(o.color.rgb));
        
        float3 normal = getSceneNormal(pos - 10*EPS*rayDir);

        #ifdef _SHADOW_ON
            rayDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
            o.color = lighting(
            pos, 
            normal,
            shadowmarch(pos + rayDir * 10 * EPS, rayDir),
            o.color
            );
        #else // #elif _SHADOW_OFF
            o.color = lighting(pos, normal, 1, o.color);
        #endif
        #if defined(_DEBUG_ON)
            #if defined(UNITY_SINGLE_PASS_STEREO)
                o.color.rgb = 1 - abs(dot(rayDir, normalize(mul(unity_WorldToObject, mul(FaceToWorld, float3(0,0,1))))));
            #else
                // o.color.rgb = blurstep(blurstep(1-1.25*distance(float2(0.5, 0.45), screenPos.xy/_ScreenParams.xy)));
                o.color.rgb = 1 - abs(dot(rayDir, normalize(mul(unity_WorldToObject, mul((float3x3)unity_CameraToWorld, float3(0,0,1))))));
            #endif
            o.depth=1;
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