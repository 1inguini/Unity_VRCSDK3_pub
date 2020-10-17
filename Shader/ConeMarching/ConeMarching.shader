Shader "linguini/ConeMarching/ConeMarching"
{
//     Properties
//     {
//         // _Color ("Color", Color) = (1,1,1)
//         _MaxDistance ("MaxDistance", Range(0, 1)) = 0.1;
//     }
//     SubShader
//     {
//         Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase" }
//         LOD 100
//         Cull Front
//         ZWrite On

//         Pass
//         {
//             CGPROGRAM
//             #pragma vertex vert
//             #pragma fragment frag

//             #pragma multi_compile WORLD
            
//             #include "UnityCG.cginc"

//             sampler2D _CameraDepthTexture;

//             float _MaxDistance;
            
//             struct appdata
//             {
//                 float4 vertex : POSITION;
//                 float2 uv : TEXCOORD0;
//             };

//             struct v2f
//             {
//                 float2 uv : TEXCOORD0;
//                 float4 vertex : SV_POSITION;
//                 float4 pos : POSITION1;
//             };

//             #define EPS 0.0001

//             float3 raymarch (float3 pos, float3 rayDir) {
//                 float maxDistance = 1000 * _MaxDistance;
//                 float3 initPos = pos;
//                 for (
//                 float marchingDist = sceneDist(pos);
//                 distance(pos, initPos) < maxDistance;
//                 pos += abs(marchingDist) * rayDir
//                 ) {
//                     marchingDist = sceneDist(pos);
//                     if (abs(marchingDist) < EPS){
//                         return pos;
//                     }
//                 }
//                 return 0;
//             }

//             v2f vert (appdata v)
//             {
//                 v2f o;
//                 o.uv = v.uv;
//                 o.vertex = UnityObjectToClipPos(v.vertex);
//                 #ifdef WORLD
//                     // メッシュのワールド座標を代入
//                     o.pos = mul(unity_ObjectToWorld, UnityObjectToClipPos(v.vertex));
//                 #elif OBJECT
//                     // メッシュのローカル座標を代入
//                     o.pos = UnityObjectToClipPos(v.vertex);
//                 #else
//                     o.pos = mul(unity_ObjectToWorld, UnityObjectToClipPos(v.vertex));
//                 #endif

//                 return o;
//             }

//             fixed4 frag (v2f i) : SV_Target
//             {
//                 // sample the texture
//                 fixed4 col = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
//                 // return col;
//                 return 1;
//             }
//             ENDCG
//         }
//     }
Fallback "Standard"
}
