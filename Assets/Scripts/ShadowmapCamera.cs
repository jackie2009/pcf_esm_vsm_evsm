using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class ShadowmapCamera : MonoBehaviour
{

    public enum ShadowType
    {
        UNITY, PCF, ESM, VSM, EVSM,MY_ESM
    }
    public RenderTexture smTex;
    public RenderTexture esmTex;
    public RenderTexture vsmTex;

    public bool buildShadowmaps;
    public Camera lightCamera;
    private Shader lightingShader;
    public ShadowType shadowType = ShadowType.UNITY;
    const int shadowmapSize = 2048;
    [Range(0, 0.1f)]
    public float esmNormalBias = 0.001f;
    void Start()
    {

    }
    

    // Update is called once per frame
    void Update()
    {
        var cam = lightCamera;
        
        if (cam == null) return;
        cam.aspect = 1;
        Shader.SetGlobalMatrix("light_VP", GL.GetGPUProjectionMatrix(cam.projectionMatrix, false) * cam.worldToCameraMatrix);
        Shader.SetGlobalInt("shadowType", (int)shadowType);
        Shader.SetGlobalFloat("esmNormalBias", esmNormalBias);
        if (smTex != null) Shader.SetGlobalTexture("smTex", smTex);
        if (esmTex != null) Shader.SetGlobalTexture("esmTex", esmTex);
        if (vsmTex != null) Shader.SetGlobalTexture("vsmTex", vsmTex);
        if (buildShadowmaps) {
            buildShadowmaps = false;
           
            if (smTex != null) {
                RenderTexture.ReleaseTemporary(smTex);
            }
            smTex = RenderTexture.GetTemporary(shadowmapSize, shadowmapSize, 24, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        
            smTex.filterMode = FilterMode.Point;
            cam.targetTexture = smTex;
        

            cam.RenderWithShader(Shader.Find("ESM/ShadowmapCaster"),"");

            cam.targetTexture = null;

            if (esmTex != null)
            {
                esmTex.Release() ;
            }
            esmTex =new RenderTexture(shadowmapSize, shadowmapSize, 0, RenderTextureFormat.RFloat  , RenderTextureReadWrite.Linear);
            esmTex.autoGenerateMips = false;
            esmTex.useMipMap = false;
            esmTex.filterMode = FilterMode.Bilinear;
            var mat = new Material(Shader.Find("ESM/E_ShadowmapCaster"));
            mat.mainTexture = smTex;// _MainTex;
            Graphics.Blit(smTex, esmTex,mat,0 );


        
            if (vsmTex != null)
            {
                vsmTex.Release();
            }
            vsmTex = new RenderTexture(shadowmapSize, shadowmapSize, 0, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
            vsmTex.autoGenerateMips = false;
            vsmTex.useMipMap = false;
            vsmTex.filterMode = FilterMode.Bilinear;
            
            mat.mainTexture = smTex;// _MainTex;
            Graphics.Blit(smTex, vsmTex, mat,1 );
 


        }

        if (lightingShader == null)
            lightingShader = Shader.Find("ESM/DeferredShading");

        if (GraphicsSettings.GetCustomShader(BuiltinShaderType.DeferredShading) != lightingShader) {
            GraphicsSettings.SetShaderMode(BuiltinShaderType.DeferredShading, BuiltinShaderMode.UseCustom);
            GraphicsSettings.SetCustomShader(BuiltinShaderType.DeferredShading, lightingShader);
        }

    }
    
}
