// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "ESM/DeferredShading" {
Properties {
    _LightTexture0 ("", any) = "" {}
    _LightTextureB0 ("", 2D) = "" {}
    _ShadowMapTexture ("", any) = "" {}
    _SrcBlend ("", Float) = 1
    _DstBlend ("", Float) = 1
}
SubShader {

// Pass 1: Lighting pass
//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
//  HDR case - Lighting additively blended into floating point buffer
Pass {
    ZWrite Off
    Blend [_SrcBlend] [_DstBlend]

CGPROGRAM
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag
#pragma multi_compile_lightpass
#pragma multi_compile ___ UNITY_HDR_ON

#pragma exclude_renderers nomrt

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardBRDF.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

#define shadowmapSize 2048
int shadowType;
float4x4 light_VP;
sampler2D smTex;
sampler2D esmTex;
sampler2D vsmTex;

float pcf5x5(float4 lightScreenPos,float d) {
  
    float shadow = 0;
    float zbase = 1 - tex2Dlod(smTex, float4(lightScreenPos.xy , 0, 0)).r;
  
    for (int i = -2; i <=2; i++)
    {
        for (int j = -2; j <= 2; j++)
        {
            float z = 1 - tex2Dlod(smTex, float4(lightScreenPos.xy+1*float2(j,i)/ shadowmapSize,0,0)).r;
            shadow+= d - 0.003 < z;
            
            
        }
    }
 
    return shadow / 25;
}
float esm(float4 lightScreenPos, float d) {
    float shadow = 0;
    float zbase =  tex2Dlod(esmTex, float4(lightScreenPos.xy, 0, 0)).r;
    float esm = saturate((exp(-80 * d) * zbase));
    return esm;
}
float vsm(float4 lightScreenPos, float d) {

    float shadow = 0;
    float2 zbase = tex2Dlod(vsmTex, float4(lightScreenPos.xy, 0, 0)).rg;
    float E = zbase.x;
    float Q= zbase.y;
    float m = max(0.00000001, Q - E * E);
    float vsm = d < E ? 1 : m / (m + (d - E) * (d - E));
    return vsm;
}
float myEsm(float4 lightScreenPos, float d) {
    float shadow = 0;
    float zbase = tex2Dlod(esmTex, float4(lightScreenPos.xy, 0, 0)).r;
    float esm = saturate((exp(-80 * d) * zbase));
    float originZ = log(zbase) / 80;
    float esmDark = saturate((exp(-300 * (d - originZ))));
   


    float s = 0;
    for (int i = -2; i <=2; i++)
    {
        for (int j = -2; j <= 2; j++)
        {
            float z =   tex2Dlod(esmTex, float4(lightScreenPos.xy + float2(j, i) / 2048, 0, 0)).r;
            z = max(ddx(log(z) / 80), ddy(log(z) / 80));
            s += lerp(esmDark, esm, saturate(z * 200));
        }
    }
    return s / 25;
  
 
}
half4 CalculateLight (unity_v2f_deferred i)
{
    float3 wpos;
    float2 uv;
    float atten, fadeDist;
    UnityLight light;
    UNITY_INITIALIZE_OUTPUT(UnityLight, light);
    UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);
   

    // light space 
    float4 proPos = mul(light_VP, float4(wpos, 1));
    float4 ndcPos = proPos / proPos.w;
    float d = 1 - ndcPos.z;
    float4 screenPos = float4(ndcPos.xy * 0.5 + 0.5, ndcPos.z, ndcPos.w);

    if (shadowType == 1) {
        atten = pcf5x5(screenPos,d);
    }else if (shadowType == 2) {
        atten = esm(screenPos, d);
    }
    else if (shadowType == 3) {
        atten = vsm(screenPos, d);
    } else if (shadowType == 4) {
        atten = min(vsm(screenPos, d), esm(screenPos, d));
    }
    else if (shadowType == 5) {
        atten = myEsm(screenPos, d);
    }
    light.color = _LightColor.rgb * atten;

    // unpack Gbuffer
    half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv);
    half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);
    half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);
    UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);


    float3 eyeVec = normalize(wpos-_WorldSpaceCameraPos);
    half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

    UnityIndirect ind;
    UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
    ind.diffuse = 0;
    ind.specular = 0;

    half4 res = UNITY_BRDF_PBS (data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);

    return res;
}

#ifdef UNITY_HDR_ON
half4
#else
fixed4
#endif
frag (unity_v2f_deferred i) : SV_Target
{
    half4 c = CalculateLight(i);
    #ifdef UNITY_HDR_ON
    return c;
    #else
    return exp2(-c);
    #endif
}

ENDCG
}


// Pass 2: Final decode pass.
// Used only with HDR off, to decode the logarithmic buffer into the main RT
Pass {
    ZTest Always Cull Off ZWrite Off
    Stencil {
        ref [_StencilNonBackground]
        readmask [_StencilNonBackground]
        // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
        compback equal
        compfront equal
    }

CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

#include "UnityCG.cginc"

sampler2D _LightBuffer;
struct v2f {
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.texcoord = texcoord.xy;
#ifdef UNITY_SINGLE_PASS_STEREO
    o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
#endif
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    return -log2(tex2D(_LightBuffer, i.texcoord));
}
ENDCG
}

}
Fallback Off
}
