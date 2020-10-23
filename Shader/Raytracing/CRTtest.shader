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

            // User facing vertex to fragment shader structure
            // struct v2f_customrendertexture
            struct v2f {
                float4 vertex           : SV_POSITION;
                float3 localTexcoord    : TEXCOORD0;    // Texcoord local to the update zone (== globalTexcoord if no partial update zone is specified)
                float3 globalTexcoord   : TEXCOORD1;    // Texcoord relative to the complete custom texture
                uint primitiveID        : TEXCOORD2;    // Index of the update zone (correspond to the index in the updateZones of the Custom Texture)
                float3 direction        : TEXCOORD3;    // For cube textures, direction of the pixel being rendered in the cubemap
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

                return OUT;
            }

            float4 frag(v2f i) : SV_Target
            {
                // float2 uv = i.globalTexcoord;
                // int2 p = floor(uv * TextureSize);
                // p += (float2(_Time.y,0)+0.5)/TextureSize;   
                // return i.body[_CustomRenderTextureWidth*p.x + p.y];
                return frac(_Time.y);
            }
            ENDCG
        }
    }
}
