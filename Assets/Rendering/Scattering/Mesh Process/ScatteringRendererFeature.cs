using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

public class ScatteringRendererFeature : ScriptableRendererFeature
{
    // public LightingEventSetting settings = new LightingEventSetting();
    ScatteringPass scatteringPass;

    [Serializable]
    public struct ShaderParams
    {
        public float downSample;
        public float blur_factor;
    }

    public ShaderParams shaderParams = new()
    {
        downSample = 2,
        blur_factor = 1,
    };

    // [System.Serializable]
    // public class LightingEventSetting
    // {
    //     public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    // }

    class ScatteringPass : ScriptableRenderPass
    {
        List<Renderer> renderers = new List<Renderer>();
        Material fullscreenMat = new Material(Shader.Find("Test/BlitBlend"));
        const int renderTexCount = 6;
        const int renderTargetCount = 2;
        RenderTexture[] renderTexs = new RenderTexture[renderTexCount];
        RenderTargetIdentifier[] targetColorBuffers = new RenderTargetIdentifier[renderTargetCount];

        // RenderTexture fftTarget;
        // private FFTKernel fftKernel = new FFTKernel();
        
        ShaderParams shaderParams;
        

        static class RTIndex
        {
            public const int Color_target = 0;
            public const int Alpha_target = 1;
            public const int Color_copy = 2;
            public const int Alpha_copy = 3;
            public const int Color_final = 4;
            public const int Alpha_final = 5;
        }

        static class ShaderInfo
        {
            public const int BlendColor = 0;
            public const int BlendAlpha = 1;
            public const int FinalBlend = 2;
        }

        // SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;

        // private List<ShaderTagId> shaderTagIds = new List<ShaderTagId>()
        // {
        //     new("UniversalForward"),
        //     new("BlendTest")
        // };
        //
        // FilteringSettings filteringSettings = new FilteringSettings(
        //     RenderQueueRange.all,
        //     LayerMask.GetMask("Atmo")
        // );

        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Scattering");

        public void Setup(ShaderParams shaderParams)
        {
            if(UnityObjectUtility.IsDestroyed(fullscreenMat)) fullscreenMat = new Material(Shader.Find("Test/BlitBlend"));
            this.shaderParams = shaderParams;
            // this.renderTexture = tex;
            // m_ShaderTagIdList.Add(new ShaderTagId("UniversalPipeline"));

            var obj = FindObjectsOfType<AtmosphereScattering>();
            renderers.Clear();
            foreach (var o in obj)
            {
                renderers.Add(o.GetComponent<Renderer>());
            }
            
            // fftKernel.Init();
            // fftKernel.HalfPrecision = true;
            // fftTarget = new RenderTexture(1024, 512, 0,
            //     RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
            // fftTarget.enableRandomWrite = true;
            // fftTarget = RenderTexture.GetTemporary(desc);
        }
        
        // public void Cleanup()
        // {
        //     fftTarget.Release();
        // }


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("Scattering");
            RenderTargetIdentifier targetColor = renderingData.cameraData.renderer.cameraColorTargetHandle;
            RenderTargetIdentifier tagetDepth = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            
            //prepare render targets
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            
            desc.colorFormat = RenderTextureFormat.RGB111110Float;
            desc.depthBufferBits = 0;
            desc.width = (int)(desc.width / shaderParams.downSample);
            desc.height = (int)(desc.height / shaderParams.downSample);
            // desc.width = (int)(desc.width / downSample);
            // desc.height = (int)(desc.height / downSample);
            // renderTargets[(int)RTIndex.Back] = renderingData.cameraData.targetTexture;
            renderTexs[RTIndex.Color_target] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_target] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Color_copy] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_copy] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Color_final] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_final] = RenderTexture.GetTemporary(desc);
            
            // fftTarget = RenderTexture.GetTemporary(fftTarget.descriptor);
            // colorBuffers[(int)RTIndex.Back] = targetColor;
            targetColorBuffers[RTIndex.Color_target] = renderTexs[RTIndex.Color_target].colorBuffer;
            targetColorBuffers[RTIndex.Alpha_target] = renderTexs[RTIndex.Alpha_target].colorBuffer;

            // DrawingSettings drawingSettings =
            //     CreateDrawingSettings(shaderTagIds, ref renderingData, sortingCriteria);

            // int temp = Shader.PropertyToID("tempRT");
            // cmd.GetTemporaryRT(temp, desc);
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // cmd.GetTemporaryRT(colorBuffers[0], desc);
                // cmd.GetTemporaryRT(colorBuffers[1], desc);
                //clear render targets
                void ClearRT(RenderTargetIdentifier rt, Color color)
                {
                    cmd.SetRenderTarget(rt);
                    cmd.ClearRenderTarget(true, true, color);
                }

                ClearRT(renderTexs[RTIndex.Color_target], Color.clear);
                ClearRT(renderTexs[RTIndex.Alpha_target], Color.white);
                ClearRT(renderTexs[RTIndex.Color_copy], Color.clear);
                ClearRT(renderTexs[RTIndex.Alpha_copy], Color.white);
                ClearRT(renderTexs[RTIndex.Color_final], Color.clear);
                ClearRT(renderTexs[RTIndex.Alpha_final], Color.white);
                // cmd.SetRenderTarget(targetColorBuffers[RTIndex.Color_target]);
                // cmd.ClearRenderTarget(true, true, Color.clear);
                // cmd.SetRenderTarget(targetColorBuffers[RTIndex.Alpha_target]);
                // cmd.ClearRenderTarget(true, true, Color.white);
                //set render targets
                cmd.SetRenderTarget(targetColorBuffers, tagetDepth);
                int colorTex_id = Shader.PropertyToID("_ColorTex");
                int alphaTex_id = Shader.PropertyToID("_AlphaTex");
                int colorFinalTex_id = Shader.PropertyToID("_ColorFinalTex");
                int alphaFinalTex_id = Shader.PropertyToID("_AlphaFinalTex");
                // cmd.SetGlobalTexture(colorTex_id, renderTexs[RTIndex.Color_copy]);
                // cmd.SetGlobalTexture(alphaTex_id, renderTexs[RTIndex.Alpha_copy]);
                cmd.SetGlobalTexture(colorTex_id, renderTexs[RTIndex.Color_target]);
                cmd.SetGlobalTexture(alphaTex_id, renderTexs[RTIndex.Alpha_target]);
                cmd.SetGlobalTexture(colorFinalTex_id, renderTexs[RTIndex.Color_final]);
                cmd.SetGlobalTexture(alphaFinalTex_id, renderTexs[RTIndex.Alpha_final]);
                // cmd.GetTemporaryRT(colorTex_id, desc);
                // cmd.GetTemporaryRT(alphaTex_id, desc);
                // context.ExecuteCommandBuffer(cmd);
                // cmd.Clear();

                //sort renderers by depth
                Matrix4x4 viewMatrix = renderingData.cameraData.GetViewMatrix();

                float RendererDepth(Renderer renderer)
                {
                    return viewMatrix.MultiplyPoint(renderer.transform.position).z;
                }

                renderers.Sort((a, b) =>
                    RendererDepth(a).CompareTo(RendererDepth(b)));
                foreach (var renderer in renderers)
                {
                    cmd.DrawRenderer(renderer, renderer.sharedMaterial, 0, 0);

                    // cmd.Blit(null,
                    //     renderTexs[RTIndex.Alpha_copy].colorBuffer, mat, 1);
                    // cmd.Blit(
                    //     renderTexs[RTIndex.Alpha_copy].colorBuffer,
                    //     renderTexs[RTIndex.Alpha_final].colorBuffer);

                    cmd.Blit(
                        null,
                        renderTexs[RTIndex.Alpha_final].colorBuffer, fullscreenMat, ShaderInfo.BlendAlpha);

                    cmd.Blit(null,
                        renderTexs[RTIndex.Color_copy].colorBuffer, fullscreenMat, ShaderInfo.BlendColor);
                    cmd.Blit(
                        renderTexs[RTIndex.Color_copy].colorBuffer,
                        renderTexs[RTIndex.Color_final].colorBuffer);
                    
                    ClearRT(renderTexs[RTIndex.Color_target], Color.clear);
                    ClearRT(renderTexs[RTIndex.Alpha_target], Color.white);
                    cmd.SetRenderTarget(targetColorBuffers, tagetDepth);
                }
                //blur process
                // cmd.Blit(renderTexs[RTIndex.Color_final],fftTarget);
                // fftKernel.Convolve(fftTarget,cmd,shaderParams.blur_factor);
                // cmd.Blit(fftTarget,renderTexs[RTIndex.Color_final]);
                // cmd.Blit(renderTexs[RTIndex.Alpha_final],fftTarget);
                // fftKernel.Convolve(fftTarget,cmd,shaderParams.blur_factor);
                // cmd.Blit(fftTarget,renderTexs[RTIndex.Alpha_final]);

                //blend process
                cmd.Blit(targetColor, renderTexs[RTIndex.Color_copy].colorBuffer,
                    fullscreenMat, ShaderInfo.FinalBlend);
                cmd.Blit(renderTexs[RTIndex.Color_copy].colorBuffer, targetColor);
            }

            // cmd.ReleaseTemporaryRT(temp);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            // // context.Submit();

            // RenderTexture.ReleaseTemporary(renderTexs[RTIndex.Alpha]);
            for (int i = 0; i < renderTexCount; i++)
                RenderTexture.ReleaseTemporary(renderTexs[i]);
            // RenderTexture.ReleaseTemporary(fftTarget);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
        
    }

    public override void Create()
    {
        scatteringPass = new()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing
        };
    }
    

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        scatteringPass.Setup(shaderParams);
        renderer.EnqueuePass(scatteringPass);
    }

    // private void OnDestroy()
    // {
    //     scatteringPass.Cleanup();
    // }
}

public class AtmosphereScatteringComponent : VolumeComponent, IPostProcessComponent
{
    [Range(0, 3)] public FloatParameter lightIntensity = new FloatParameter(0);
    public FloatParameter stepSize = new FloatParameter(0.1f);
    public FloatParameter maxDistance = new FloatParameter(1000);
    public IntParameter maxStep = new IntParameter(200);
    public ClampedFloatParameter blurIntensity = new ClampedFloatParameter(1, 0, 20);
    public ClampedIntParameter loop = new ClampedIntParameter(3, 1, 10);
    public ClampedFloatParameter bilaterFilterFactor = new ClampedFloatParameter(0.3f, 0, 1);
    public bool IsActive() => lightIntensity.value > 0;
    public bool IsTileCompatible() => false;
}