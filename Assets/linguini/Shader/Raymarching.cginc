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
    // //メッシュのワールド座標を代入
    // o.pos = mul(unity_ObjectToWorld, v.vertex);
    //メッシュのローカル座標を代入
    o.pos = v.vertex;
    // o.uv = v.uv;
    return o;
}

float min3(float x, float y, float z){
    return min(x, min(y, z));
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

float3 getSceneNormal(float3 pos){
    float EPS = 0.0001;
    return normalize(float3(
    sceneDist(pos + float3(EPS,0,0)) - sceneDist(pos + float3(-EPS,0,0)),
    sceneDist(pos + float3(0,EPS,0)) - sceneDist(pos + float3(0,-EPS,0)),
    sceneDist(pos + float3(0,0,EPS)) - sceneDist(pos + float3(0,0,-EPS))
    )
    );
}

fragout raymarch(float3 pos, float3 rayDir) {
    float maxDistance = 1000 * _MaxDistance;
    float minDistance = 0.0001;
    float marchingDist = sceneDist(pos); 
    
    fragout fout;
    
    float3 normal;
    float3 lightDir;
    float NdotL;
    fixed3 lightColor, lightProbe, lighting, ambient;
    float4 projectionPos;
    while (length(pos) < maxDistance && minDistance <= abs(marchingDist)) {
        marchingDist = sceneDist(pos);
        pos.xyz += marchingDist * rayDir.xyz;                                
    }
    
    // 物体の近くにいなければ描画しない
    clip(minDistance - abs(marchingDist));
    
    //ランバート反射を計算
    // 法線
    normal = getSceneNormal(pos);
    //ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
    lightDir = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;

    // lightDir = normalize(mul(unity_WorldToObject,_WorldSpaceLightPos0)).xyz;
    NdotL = saturate(dot(normal, lightDir));

    lightProbe = ShadeSH9(fixed4(UnityObjectToWorldNormal(normal), 1));

    lighting = lerp(lightProbe, _LightColor0, NdotL);
    
    ambient = Shade4PointLights(
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
    
    fout.color = fixed4(lighting * _Color.rgb + (ambient? ambient: 0.1), _Color.a);
    //fout.color = _Color;

    projectionPos = UnityObjectToClipPos(float4(pos, 1.0));
    fout.depth = projectionPos.z / projectionPos.w;
    return fout;
    // fout.color = _BackGround;
    // fout.depth = 0;
    // return fout;
}

fragout frag (v2f i)
{
    // float3 pos = mul(unity_WorldToObject,_WorldSpaceCameraPos);
    float3 pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
    //float3 pos = _WorldSpaceCameraPos;
    // レイの進行方向
    float3 rayDir = normalize(i.pos.xyz - pos);
    return raymarch(pos, rayDir);
}