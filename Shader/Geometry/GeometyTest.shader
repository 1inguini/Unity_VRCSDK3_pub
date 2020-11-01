Shader "linguini/Geometry/GeometyTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_nop
            #pragma geometry geom
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            appdata vert_nop (appdata i) {
                return i;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;
                return o;
            }
            
            [maxvertexcount(113)] //これ以上多くの頂点を生成することはできない
            void geom(triangle appdata input[3], uint pid : SV_PrimitiveID, inout TriangleStream<v2f> outStream)
            {
                float ext = saturate(0.4 - cos(_Time.x * UNITY_TWO_PI) * 0.41);
                ext *= 1 + 0.3 * sin(pid * 832.37843 + _Time.x * 88.76);

                
                appdata v[3] = input;

                float3 normal = normalize(input[0].normal + input[1].normal + input[2].normal);
                [unroll] for(int i = 0; i < 3; i++)
                {   
                    // v[i].normal += normal;
                    v[i].vertex.xyz += ext * normal;
                    outStream.Append(vert(v[i]));
                }
                outStream.RestartStrip();
                
                [unroll] for(int i = 0; i < 3; i++)
                {
                    float3 n = normalize(
                    cross(
                    input[i].vertex.xyz - v[i].vertex.xyz,
                    v[(i+1)%3].vertex.xyz - v[i].vertex.xyz
                    )
                    );
                    
                    input[i].normal = n; 
                    input[(i+1)%3].normal = n; 
                    outStream.Append(vert(input[i]));
                    outStream.Append(vert(input[(i+1)%3]));
                    
                    v[i].normal = n; 
                    v[(i+1)%3].normal = n; 
                    outStream.Append(vert(v[i]));
                    outStream.Append(vert(v[(i+1)%3]));
                }
                outStream.RestartStrip();
                
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(abs(i.normal), 1);
                return fixed4((fixed3)dot(_WorldSpaceLightPos0, i.normal)+0.1, 1);
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }

            ENDCG
        }
    }
}
