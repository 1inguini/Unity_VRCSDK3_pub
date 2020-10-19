#ifndef SDF_INCLUDED
    #define SDF_INCLUDED
    #include "Misc.cginc"
    
    struct distIn {
        fixed clarity; // 0 <= clarity <= 1;
        half pixSize;
        half3 pos;
    };

    distIn mkDistIn(half clarity, half pixSize, half3 pos) {
        distIn o;
        o.clarity = clarity;
        o.pixSize = pixSize;
        o.pos = pos;
        return o;
    }
    
    inline distIn addToPos(distIn din, half3 posDiff) {
        din.pos += posDiff;
        return din;
    }
    
    inline half3 fold(half3 normal, half3 pos) {
        return pos - 2*min(0, dot(pos, normal))*normal;
    }
    
    inline half3 sphereFold (half radius, half3 pos) {
        half R2 = square(radius);
        half r2 = square(pos);
        return (r2 < R2? R2/r2: 1)*pos;
    }

    inline half3 repeat(half interval, half3 pos){
        // pos -= round(pos/interval)*interval;
        // pos = (frac(pos/interval + 0.5) - 0.5)*interval;
        return pos - round(pos/interval)*interval;
    }
    
    inline half roundRem(half x) {
        return x - round(x);
    }
    inline half3 roundRem(half3 v) {
        return half3(roundRem(v.x), roundRem(v.y), roundRem(v.z));
    }

    // WIP
    inline half3 randRepeat(half interval, half3 pos){
        pos -= random3(round(pos/(interval+1)));
        pos = roundRem(pos/interval)*interval;
        return pos;
    }

    inline half sphereDist(half3 pos){
        return length(pos) - 0.5;
    }
    
    inline half torusDist(half innerRatio, half3 pos){
        pos.xz = length(pos.xz) - 0.5*(1-innerRatio);
        return length(pos) - 0.5*innerRatio;
    }
    
    inline half cubeDist(half3 pos){
        half3 q = abs(pos) - 0.5;
        return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0);
    }
       
    inline half tetrahedronDist(half3 pos) {
        half3 normal = normalize(half3(1, 1, 0));
        pos.xz = rotate90(pos.xz);
        pos = fold(normal.xyz, pos);
        pos = fold(normal.yzx, pos);
        pos = fold(normal.zxy, pos);
        pos -= 0.5/3.0;
        return dot(pos, normalize(half3(1,1,1)));
    }
    
    inline half pillarXDist(half3 pos) {
        pos = abs(pos);
        return max(pos.y, pos.z) - 0.5;
    }
    inline half pillarYDist(half3 pos) {
        pos = abs(pos);
        return max(pos.z, pos.x) - 0.5;
    }
    inline half pillarZDist(half3 pos) {
        pos = abs(pos);
        return max(pos.x, pos.y) - 0.5;
    }

    inline half pillarXYZDist(half3 pos){
        return min3(
        pillarXDist(pos),
        pillarYDist(pos),
        pillarZDist(pos)
        );
    }
    // #if defined(_BOX_SIERPINSKI) || defined(_BOX_LERP)
    half sierpinskiDist(distIn din)
    {
        half r;
        half scale = 2; // 1.75 + 0.25*_CosTime.w;
        half3 offset = 0.5;
        half3 normal = normalize(half3(1, 1, 0));
        
        half i;
        for (i = 0; i < 10 * din.clarity * _Resolution; i++) {                      
            din.pos = mul(rotationMatrix(_Time.y/5.0), din.pos);
            din.pos = fold(normal.xyz, din.pos);
            din.pos = fold(normal.yzx, din.pos);
            din.pos = fold(normal.zxy, din.pos);

            din.pos = din.pos*scale - offset*(scale - 1);	
        } 
        return tetrahedronDist(din.pos) * pow(scale, -i);
    }
    // #endif

    // #if defined(_BOX_MENGER) || defined(_BOX_LERP)
    half mengerDist(distIn din)
    {
        half r;
        half scale = 3;
        half3 offset = 0.5;
        half3 normal = normalize(half3(1, -1, 0));

        half finalscale = 1;
        half i;
        for (
        i = 0;
        i <  10 * din.clarity * _Resolution &&
        din.pixSize < finalscale;
        i++)
        {                      
            // pos = mul(rotationMatrixCos(_CosTime.x), pos);
            din.pos = abs(din.pos);
            din.pos = fold(normal.xyz, din.pos);
            din.pos = fold(normal.xzy, din.pos);
            din.pos = fold(normal.zxy, din.pos);
            din.pos.xy = din.pos.xy*scale - offset.xy*(scale - 1);	
            
            din.pos.z -= 0.5*offset.z*(scale-1)/scale;
            din.pos.z = -abs(din.pos.z);
            din.pos.z += 0.5*offset.z*(scale-1)/scale;
            din.pos.z = scale*din.pos.z;
            finalscale /= scale;
        } 
        return cubeDist(din.pos) * finalscale;
    }
    // #endif

    // #if defined(_BOX_MANDELBOX) || defined(_BOX_LERP)               
    half4 boxFoldDR(half size, half4 posDR) {
        return half4(clamp(posDR.xyz, -size, size) * 2 - posDR.xyz, posDR.w);
    }

    half4 sphereFoldDR (half radius, half innerRadius, half4 posDR) {
        half R2 = square(radius);
        half r2 = square(posDR.xyz);
        half iR2 = square(innerRadius);
        return (r2 < iR2? R2/iR2: r2 < R2? R2/r2: 1) * posDR;
    }
    
    half mandelBoxDist(distIn din) {
        // uint maxLevel = _Resolution * 100;
        half scale = -2.5 + 0.5*_CosTime.w;
        half absScale = abs(scale);
        half4 offset = half4(din.pos, 1);
        half4 posDR = half4(din.pos, 1);
        half rcpPixSize = 1/din.pixSize;
        for(uint j = 0; j < 10 * din.clarity * _Resolution && posDR.w < rcpPixSize; j++){
            posDR = sphereFoldDR(0.25, 0.125, boxFoldDR(0.25, posDR));
            posDR.xyz = scale*posDR.xyz + offset.xyz;
            posDR.w = absScale*posDR.w + offset.w;
        }
        return cubeDist(posDR.xyz)/posDR.w;
    }

    // #endif
#endif