#ifndef MISC_INCLUDED
    #define MISC_INCLUDED

    inline half min3(half x, half y, half z){
        return min(x, min(y, z));
    }

    inline half square(half x) {
        return x*x;
    }
    inline half square(half3 v) {
        return dot(v, v);
    }

    // inline half eVstep(half x) {
        //     return sin(UNITY_HALF_PI*x);
    // }
    inline half enhanceVisibility(half x) {
        // return (eVstep(x));
        x = 1 - x;
        return 1 - x*x;
    }

    // 0 <= x <= 1
    inline half easing(half m, half x) {
        return 1-exp(-m*x);
    }
    
    inline half3 random3 (half3 pos) { 
        return frac(sin(dot(pos.xyz, float3(12.9898, 78.233, 56.787))) * 43758.5453);
    }

    inline half2 rotate(half2 pos, half r) {
        half2x2 m = half2x2(cos(r), sin(r), -sin(r), cos(r));
        return mul(pos,m);
    }

    inline half2 rotate90(half2 pos){
        half2x2 m = half2x2(0,1,-1,0);
        return mul(m, pos);
    }

    inline half2 rotate45(half2 pos){
        half x = pow(2, 1/2) / 2;
        half2x2 m = half2x2(x,x,-x,x);
        return mul(m, pos);
    }
    
    half4x4 rodriguesMatrixCosSin(half3 n, half cosT, half sinT) {
        half3 sq = half3(n.x*n.x, n.y*n.y, n.z*n.z);
        half3 adj = half3(n.x*n.y, n.y*n.z, n.z*n.x);
        half r = 1 - cosT;
        return half4x4(
        cosT + sq.x*r, adj.x*r - n.z*sinT, adj.z*r + n.y*sinT, 0,
        adj.x*r + n.z*sinT, cosT + sq.y*r, adj.y*r - n.x*sinT, 0,
        adj.z*r - n.y*sinT, adj.y*r + n.x*sinT, cosT + sq.z*r, 0,
        0, 0, 0, 1
        );
    }
    inline half4x4 rodriguesMatrix(half3 n, half theta) {
        half sinT = sin(theta);
        half cosT = cos(theta);
        return rodriguesMatrixCosSin(n,cosT,sinT);
    }
    inline half4x4 rodriguesMatrixCos(half3 n, half cosT) {
        half sinT = sqrt(1-square(cosT));
        return rodriguesMatrixCosSin(n,cosT,sinT);
    }

    half4x4 rotationMatrix(half x, half y, half z) {
        half s, c;
        s = sin(x);
        c = cos(x);
        half4x4 o = half4x4(1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1);
        s = sin(y);
        c = cos(y);
        o = mul(o, half4x4(c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1));
        s = sin(z);
        c = cos(z);
        o = mul(o, half4x4(c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1));
        return o;                
    }
    inline half4x4 rotationMatrix(half3 thetas) {
        return rotationMatrix(thetas.x, thetas.y, thetas.z);                
    }
    half4x4 rotationMatrixCos(half cosx, half cosy, half cosz) {
        half c, s;
        c = cosx;
        s = sqrt(1 - square(cosx));
        half4x4 o = half4x4(1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1);
        c = cosy;
        s = sqrt(1 - square(cosy));
        o = mul(o, half4x4(c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1));
        c = cosz;
        s = sqrt(1 - square(cosz));
        o = mul(o, half4x4(c,-s,0,0, s,c,0,0, 0,0,1,0, 0,0,0,1));
        return o;     
    }
    inline half4x4 rotationMatrixCos(half3 coss) {
        return rotationMatrixCos(coss.x, coss.y, coss.z);                
    }

    half4x4 shiftMatrix(half x, half y, half z) {
        half4x4 mat = 0;
        mat[0][3] = x;
        mat[1][3] = y;
        mat[2][3] = z;
        mat[3][3] = 1;
        // mat[3] = half4(pos,1);
        return mat; // + half4x4(0,0,0,pos.x, 0,0,0,pos.y, 0,0,0,pos.z, 0,0,0,0)
    }
    inline half4x4 shiftMatrix(half3 pos) {
        return shiftMatrix(pos.x, pos.y, pos.z);
    }

    half4x4 scaleMatrix(half x, half y, half z) {
        half4x4 mat = 0;
        mat[0][0] = x;
        mat[1][1] = y;
        mat[2][2] = z;
        mat[3][3] = 1;
        return mat;
    }
    inline half4x4 scaleMatrix(half3 scale) {
        return scaleMatrix(scale.x, scale.y, scale.z);
    }

    // https://qiita.com/RamType0/items/baf2b9d5ce0f9fc458be {
        half3 ScaleOf(in half3x3 mat){
            return half3(length(mat._m00_m10_m20),length(mat._m01_m11_m21),length(mat._m02_m12_m22));
        }
        half3 ScaleOf(in half4x4 mat){
            return ScaleOf((half3x3)mat);
        }
        half3 PositionOf(in half4x4 mat){
            return mat._m03_m13_m23;
        }
        half3x3 RotationOf(half3x3 mat,half3 scale){
            mat._m00_m10_m20 /= scale.x;
            mat._m01_m11_m21 /= scale.y;
            mat._m02_m12_m22 /= scale.z;
            return mat;

        }
        half3x3 RotationOf(half4x4 mat,half3 scale){
            return RotationOf((half3x3)mat,scale);
        }


        half4x4 BuildMatrix(in half3x3 mat,in half3 offset)
        {
            return half4x4(
            half4(mat[0],offset.x),
            half4(mat[1],offset.y),
            half4(mat[2],offset.z),
            half4(0,0,0,1)
            );
        }
        half3x3 Columns(half3 column0,half3 column1,half3 column2){
            half3x3 ret;
            ret._m00_m10_m20 = column0;
            ret._m01_m11_m21 = column1;
            ret._m02_m12_m22 = column2;
            return ret;
        }
        //ベクトルを線形球面補間しますが、入力ベクトルは正規化されている必要があり、戻り値のベクトルは正規化されていません。
        //Abnormal・・・？
        half3 SlerpAbnormal(half3 normalizedA,half3 normalizedB,half t){
            half angle = acos(dot(normalizedA,normalizedB));//acosクッソ重い
            //half _sin = sin(angle);
            half aP = sin(mad(-angle,t,angle));
            half bP = sin(angle * t);
            return angle ? (aP * normalizedA + bP * normalizedB) : normalizedA;
        }
        //ベクトルを球面線形補間します。
        half3 Slerp(half3 a,half3 b,half t){
            return normalize(SlerpAbnormal(normalize(a),normalize(b),t));
        }
        //回転行列を球面線形補間します。
        half3x3 Slerp(in half3x3 a ,in half3x3 b,in half t){
            //OpenGLは列優先メモリレイアウトなのでこのままでOK
            #if SHADER_TARGET_GLSL
                half3 iy = SlerpAbnormal(a._m01_m11_m21,b._m01_m11_m21,t);//回転行列の軸ベクトルは当然正規化済み 
                half3 iz = SlerpAbnormal(a._m02_m12_m22,b._m02_m12_m22,t);//回転行列の軸ベクトルは当然正規化済み 
                half3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
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
                half3 iy = SlerpAbnormal(a[1],b[1],t);//回転行列の軸ベクトルは当然正規化済み 
                half3 iz = SlerpAbnormal(a[2],b[2],t);//回転行列の軸ベクトルは当然正規化済み 
                half3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);//直交する正規化ベクトル同士のクロス積も正規化されている
                return half3x3(ix,iy,iz);
            #endif
        }

        //移動、回転行列の回転をSlerp、移動をLerpします。
        half4x4 InterpolateTRMatrix(in half4x4 a,in half4x4 b,in half t){
            return BuildMatrix(Slerp((half3x3)a,(half3x3)b,t), lerp(PositionOf(a),PositionOf(b),t));
        }
        //回転行列の平均を求めます。Slerp(a,b,0.5)より遥かに高速です。
        half3x3 RMatrixAverage(in half3x3 a,in half3x3 b){
            //OpenGLは列優先メモリレイアウトなのでこのままでOK
            #if SHADER_TARGET_GLSL

                half3 iy = (a._m01_m11_m21 + b._m01_m11_m21)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                half3 iz = (a._m02_m12_m22 + b._m02_m12_m22)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                half3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
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
                half3 iy = (a[1] + b[1])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                half3 iz = (a[2] + b[2])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                half3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);  //直交する正規化ベクトル同士のクロス積も正規化されている
                return half3x3(ix,iy,iz);
            #endif

        }
        //移動、回転行列の平均を求めます。InterpolateTRMatrix(a,b,0.5)より遥かに高速です。
        half4x4 TRMatrixAverage(in half4x4 a,in half4x4 b){
            return BuildMatrix(RMatrixAverage((half3x3)a,(half3x3)b),(PositionOf(a)+PositionOf(b))*0.5);
        }
        #if defined(USING_STEREO_MATRICES)
            #define StereoWorldSpaceEyeRotation (half3x3)unity_StereoCameraToWorld
            #define FaceToWorld TRMatrixAverage(unity_StereoCameraToWorld[0],unity_StereoCameraToWorld[1])
            #define WorldSpaceFaceRotation RMatrixAverage(StereoWorldSpaceEyeRotation[0],StereoWorldSpaceEyeRotation[1])

            half3 FaceToWorldPos(half3 pos) {return mul(FaceToWorld,half4(pos,1)).xyz;}

            half3 ObjectToFaceAlignedWorldPosUnscaled(in half3 pos)
            {
                half3 ret = mul(WorldSpaceFaceRotation,pos);//ワールド空間でのカメラの向きに回転
                ret += PositionOf(unity_ObjectToWorld);//オブジェクトのワールド座標を加算
                return ret;
            }
            half3 ObjectToFaceAlignedWorldPos(half3 pos)
            {
                pos *= ScaleOf(unity_ObjectToWorld);//unity_ObjectToWorldからのスケールの抽出、適応
                return ObjectToFaceAlignedWorldPosUnscaled(pos);
            }
            #define VR_WorldSpaceCameraPos (_StereoWorldSpaceCameraPos[0] + _StereoWorldSpaceCameraPos[1])*0.5
        #else
            #define FaceToWorld (half3x3)unity_CameraToWorld
        #endif
    // }
    
    // https://techblog.kayac.com/unity_advent_calendar_2018_15
    // RGB->HSV変換
    half3 rgb2hsv(half3 rgb)
    {
        half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        half4 p = rgb.g < rgb.b ? half4(rgb.bg, K.wz) : half4(rgb.gb, K.xy);
        half4 q = rgb.r < p.x ? half4(p.xyw, rgb.r) : half4(rgb.r, p.yzx);

        half d = q.x - min(q.w, q.y);
        half e = 1.0e-10;
        return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }
    // HSV->RGB変換
    half3 hsv2rgb(half3 hsv)
    {
        half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        half3 p = abs(frac(hsv.xxx + K.xyz) * 6.0 - K.www);
        return hsv.z * lerp(K.xxx, saturate(p - K.xxx), hsv.y);
    }
    
#endif