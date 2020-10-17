//  Copyright (c) 2020 linguini. MIT license
// includes codes from MIT licence Unity built-in shader source by Unity Technologies.
Shader "Unlit/CRTtest"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Name "CRTtest"
            CGPROGRAM
            #pragma fragment frag
            #pragma vertex CustomRenderTextureVertexShader

            #include "UnityCG.cginc"
            #include "UnityCustomRenderTexture.cginc"

            #define INF 3.402823466e+38
            #define TextureSize float2(_CustomRenderTextureWidth,_CustomRenderTextureHeight) 
            
            float4x4 IDMAT4 = {
                {1,0,0,0}, 
                {0,1,0,0},
                {0,0,1,0},
                {0,0,0,1}
            };
            
            float min3(float x, float y, float z){
                return min(x, min(y, z));
            }
            float min3(float3 xyz) {
                return min3(xyz.x, xyz.y, xyz.z);
            }

            float max3(float x, float y, float z){
                return max(x, max(y, z));
            }
            float max3(float3 xyz) {
                return max3(xyz.x, xyz.y, xyz.z);
            }
            
            float square(float x) {
                return x*x;
            }
            float square(float3 v) {
                return dot(v,v);
            }
            // matrix operations {
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

                float4x4 scaleLocalMatrix(float4x4 mat, float x, float y, float z) {
                    mat[0][0] *= x;
                    mat[3][0] /= x;

                    mat[1][1] *= y;
                    mat[3][1] /= y;
                    
                    mat[2][2] *= z;
                    mat[3][2] /= z;
                    return mat;
                }
                float4x4 scaleLocalMatrix(float4x4 mat, float3 scale) {
                    return scaleLocalMatrix(mat, scale.x, scale.y, scale.z);
                }
            // }

            #define MEMLENGTH  // _CustomRenderTextureWidth*_CustomRenderTextureHeight

            // struct basicBodyDef {
                //     float4x4 mat;
                //     int itarget; // index of target body to apply matrix. -1 plane, -2:sphere, -3:cube
                //     uint istart; // index of the head of the "chunk" of bodies to be accounted as one.
                //     uint iend; // index of the end of the "chunk" of bodies to be accounted as one.
                
            // };
            // {
                //     float3x4
                //     {itarget, istart, iend, 1}
            // }

            struct bodyDef {
                float4 bs[MEMLENGTH];
                uint iempty; // bs is empty after iempty including iempty
            };

            bodyDef mengerSingleStepDef(bodyDef buffer, float scale) {
                float4 corners[3][4], edges[2][4];
                
                uint end = buffer.iempty;
                for(uint i = 0; i < end; i++) {
                    
                    for (uint j = 0; j < 4; j++) {
                        corners[0][j] = buffer.bs[i];
                        corners[1][j] = buffer.bs[i];
                        corners[2][j] = buffer.bs[i];
                        edges[0][j] = buffer.bs[i];
                        edges[3][j] = buffer.bs[i];
                        
                        corners[0][j] -= float4(0, scale, 0, 1);
                        corners[2][j] -= float4(0, -scale, 0, 1);
                        edges[0][j] -= float4(0, scale, 0, 1);
                        edges[1][j] -= float4(0, -scale, 0, 1);
                    }
                    for (uint j = 0; j < 3; j++) {
                        corners[j][0] -= float4(scale, 0, scale, 1);
                        corners[j][1] -= float4(-scale, 0, scale, 1);
                        corners[j][2] -= float4(scale, 0, -scale, 1);
                        corners[j][3] -= float4(-scale, 0, -scale, 1);
                    }
                    for (uint j = 0; j < 2; j++) {
                        edges[j][0] -= float4(scale, 0, 0, 1);
                        edges[j][1] -= float4(0, 0, scale, 1);
                        edges[j][2] -= float4(-scale, 0, 0, 1);
                        edges[j][3] -= float4(0, 0, -scale, 1);
                    }
                    
                    buffer.bs[i] = corners[0][0];
                    buffer.bs[buffer.iempty++] = corners[0][1];
                    buffer.bs[buffer.iempty++] = corners[0][2];
                    buffer.bs[buffer.iempty++] = corners[0][3];
                    for (uint j = 1; j < 3; j++) {
                        for (uint k = 0; k < 4; k++) {
                            buffer.bs[buffer.iempty++] = corners[j][k];
                        }
                    }
                    for (uint j = 0; j < 2; j++) {
                        for (uint k = 0; k < 4; k++) {
                            buffer.bs[buffer.iempty++] = edges[j][k];
                        }
                    }
                }
                return buffer;
            }

            // pass cube and make menger sponge // failing
            bodyDef mengerDef() {
                float scale = 1;
                bodyDef buffer;
                buffer.iempty = 0;
                for (uint i = 0; i < 2; i++) {
                    scale /= 3;
                    buffer = mengerSingleStepDef(buffer , scale);
                }
                return buffer;
            }

            // User facing vertex to fragment shader structure
            // struct v2f_customrendertexture
            struct v2f {
                float4 vertex           : SV_POSITION;
                float3 localTexcoord    : TEXCOORD0;    // Texcoord local to the update zone (== globalTexcoord if no partial update zone is specified)
                float3 globalTexcoord   : TEXCOORD1;    // Texcoord relative to the complete custom texture
                uint primitiveID        : TEXCOORD2;    // Index of the update zone (correspond to the index in the updateZones of the Custom Texture)
                float3 direction        : TEXCOORD3;    // For cube textures, direction of the pixel being rendered in the cubemap
                float4 body[MEMLENGTH]            : INFO;
            };

            // standard custom texture vertex shader that should always be used
            v2f vert(appdata_customrendertexture IN)
            {
                v2f OUT;
                // by unity {
                    #if UNITY_UV_STARTS_AT_TOP
                        const float2 vertexPositions[6] =
                        {
                            { -1.0f,  1.0f },
                            { -1.0f, -1.0f },
                            {  1.0f, -1.0f },
                            {  1.0f,  1.0f },
                            { -1.0f,  1.0f },
                            {  1.0f, -1.0f }
                        };

                        const float2 texCoords[6] =
                        {
                            { 0.0f, 0.0f },
                            { 0.0f, 1.0f },
                            { 1.0f, 1.0f },
                            { 1.0f, 0.0f },
                            { 0.0f, 0.0f },
                            { 1.0f, 1.0f }
                        };
                    #else
                        const float2 vertexPositions[6] =
                        {
                            {  1.0f,  1.0f },
                            { -1.0f, -1.0f },
                            { -1.0f,  1.0f },
                            { -1.0f, -1.0f },
                            {  1.0f,  1.0f },
                            {  1.0f, -1.0f }
                        };

                        const float2 texCoords[6] =
                        {
                            { 1.0f, 1.0f },
                            { 0.0f, 0.0f },
                            { 0.0f, 1.0f },
                            { 0.0f, 0.0f },
                            { 1.0f, 1.0f },
                            { 1.0f, 0.0f }
                        };
                    #endif

                    uint primitiveID = IN.vertexID / 6;
                    uint vertexID = IN.vertexID % 6;
                    float3 updateZoneCenter = CustomRenderTextureCenters[primitiveID].xyz;
                    float3 updateZoneSize = CustomRenderTextureSizesAndRotations[primitiveID].xyz;
                    float rotation = CustomRenderTextureSizesAndRotations[primitiveID].w * UNITY_PI / 180.0f;

                    #if !UNITY_UV_STARTS_AT_TOP
                        rotation = -rotation;
                    #endif

                    // Normalize rect if needed
                    if (CustomRenderTextureUpdateSpace > 0.0) // Pixel space
                    {
                        // Normalize xy because we need it in clip space.
                        updateZoneCenter.xy /= _CustomRenderTextureInfo.xy;
                        updateZoneSize.xy /= _CustomRenderTextureInfo.xy;
                    }
                    else // normalized space
                    {
                        // Un-normalize depth because we need actual slice index for culling
                        updateZoneCenter.z *= _CustomRenderTextureInfo.z;
                        updateZoneSize.z *= _CustomRenderTextureInfo.z;
                    }

                    // Compute rotation

                    // Compute quad vertex position
                    float2 clipSpaceCenter = updateZoneCenter.xy * 2.0 - 1.0;
                    float2 pos = vertexPositions[vertexID] * updateZoneSize.xy;
                    pos = CustomRenderTextureRotate2D(pos, rotation);
                    pos.x += clipSpaceCenter.x;
                    #if UNITY_UV_STARTS_AT_TOP
                        pos.y += clipSpaceCenter.y;
                    #else
                        pos.y -= clipSpaceCenter.y;
                    #endif

                    // For 3D texture, cull quads outside of the update zone
                    // This is neeeded in additional to the preliminary minSlice/maxSlice done on the CPU because update zones can be disjointed.
                    // ie: slices [1..5] and [10..15] for two differents zones so we need to cull out slices 0 and [6..9]
                    if (CustomRenderTextureIs3D > 0.0)
                    {
                        int minSlice = (int)(updateZoneCenter.z - updateZoneSize.z * 0.5);
                        int maxSlice = minSlice + (int)updateZoneSize.z;
                        if (_CustomRenderTexture3DSlice < minSlice || _CustomRenderTexture3DSlice >= maxSlice)
                        {
                            pos.xy = float2(1000.0, 1000.0); // Vertex outside of ncs
                        }
                    }

                    OUT.vertex = float4(pos, 0.0, 1.0);
                    OUT.primitiveID = asuint(CustomRenderTexturePrimitiveIDs[primitiveID]);
                    OUT.localTexcoord = float3(texCoords[vertexID], CustomRenderTexture3DTexcoordW);
                    OUT.globalTexcoord = float3(pos.xy * 0.5 + 0.5, CustomRenderTexture3DTexcoordW);
                    #if UNITY_UV_STARTS_AT_TOP
                        OUT.globalTexcoord.y = 1.0 - OUT.globalTexcoord.y;
                    #endif
                    OUT.direction = CustomRenderTextureComputeCubeDirection(OUT.globalTexcoord.xy);
                // }                

                OUT.body = mengerDef().bs;
                return OUT;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 uv = i.globalTexcoord;
                int2 p = floor(uv * TextureSize);
                p += (float2(_Time.y,0)+0.5)/TextureSize;   
                return i.body[_CustomRenderTextureWidth*p.x + p.y];
            }
            ENDCG
        }
    }
}
