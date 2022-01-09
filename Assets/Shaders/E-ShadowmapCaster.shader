// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ESM/E_ShadowmapCaster"
{
 
    SubShader
    {
 CGINCLUDE
  #include "UnityCG.cginc"
        struct appdata
            {
                float4 vertex : POSITION;

                float2 texcoord : TEXCOORD0;

            };

            struct v2f
            {
                float2 uv : TEXCOORD0;

                float4 vertex : SV_POSITION;
            };
            uniform sampler2D _MainTex;
            uniform float4  _MainTex_ST;



            v2f vert(appdata v)
            {
                v2f o;


                o.vertex = UnityObjectToClipPos(v.vertex);

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);


                return o;
            }

   ENDCG
      // for esm
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
       float4 frag(v2f i) : SV_Target
            {
                  float4 texcol = 0;
                  int c = 6;
                  float v = 0;
                  float allP = 0;
                  for (int x = -c; x <=c; x++)
                  {

                      for (int y = -c; y <= c; y++)
                      {
                          float p = 1.0 /max(0.5, pow( length(float2(x, y)),2));
                        v+= exp(80 * (1 - tex2D(_MainTex, i.uv + float2(x, y) / 2048).r))*p;
                        allP += p;
                      }
                  } 
               
                   return   v / allP;
                 // return  log( v/ allP)/80;
            }
            ENDCG
        }

       // for vsm
                Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                   float4 frag(v2f i) : SV_Target
                {
                      float4 texcol = 0;
                      int c = 5;
                      float4 v = 0;
                      float allP = 0;
                      
                      for (int x = -c; x <= c; x++)
                      {

                          for (int y = -c; y <= c; y++)
                          {
                              float p = 1.0 / max(0.5, pow(length(float2(x, y)),2));
                              float d = (1 - tex2D(_MainTex, i.uv + float2(x, y) / 2048).r);
                              v.x +=d *p; 
                              v.y += d * d*p;
                            allP += p;
                          }
                      }

                      // return  v/(c*2+1)/ (c * 2 + 1);
                       return  v / allP;
                 }
                 ENDCG
            }
    }
}
