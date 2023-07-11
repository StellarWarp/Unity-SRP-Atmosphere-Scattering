using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

public class TestFeature : ScriptableRendererFeature
{
    // public Settings settings = new Settings();
    private CustomRenderPass pass;
// public RenderTexture renderTexture;

    // RenderTexture mainRT = Camera.current.targetTexture;
    //public Material material;

    // [System.Serializable]
    // public class Settings
    // {
    //     public RenderPassEvent renderPassEvent;
    // }

    class CustomRenderPass : ScriptableRenderPass
    {
        List<Renderer> renderers = new List<Renderer>();
        Material fullscreenMat = new Material(Shader.Find("Test/BlitBlend"));
        const int renderTexCount = 6;
        const int renderTargetCount = 2;
        RenderTexture[] renderTexs = new RenderTexture[renderTexCount];
        RenderTargetIdentifier[] targetColorBuffers = new RenderTargetIdentifier[renderTargetCount];

        Mesh mesh;

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
            public const int BlurHorizontal = 2;
            public const int BlurVertical = 3;
            public const int FinalBlend = 4;
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

        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Test");

        public void Setup()
        {
            // this.renderTexture = tex;
            // m_ShaderTagIdList.Add(new ShaderTagId("UniversalPipeline"));

            var obj = FindObjectsOfType<RenderTextObject>();
            renderers.Clear();
            foreach (var o in obj)
            {
                renderers.Add(o.GetComponent<Renderer>());
            }
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("TestFeature");
            RenderTargetIdentifier targetColor = renderingData.cameraData.renderer.cameraColorTargetHandle;
            RenderTargetIdentifier tagetDepth = renderingData.cameraData.renderer.cameraDepthTargetHandle;

            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            desc.colorFormat = RenderTextureFormat.ARGB2101010;
            desc.depthBufferBits = 0;
            // renderTargets[(int)RTIndex.Back] = renderingData.cameraData.targetTexture;
            renderTexs[RTIndex.Color_target] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_target] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Color_copy] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_copy] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Color_final] = RenderTexture.GetTemporary(desc);
            renderTexs[RTIndex.Alpha_final] = RenderTexture.GetTemporary(desc);
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

                // mat.SetTexture(colorTex_id, renderTargets[1]);
                //blur process
                // fullscreenMat.SetFloat("_BlurSize", 0.02f);
                for (int i = 0; i < 5; i++)
                {
                    cmd.Blit(renderTexs[RTIndex.Color_final].colorBuffer,
                        renderTexs[RTIndex.Color_copy].colorBuffer,
                        fullscreenMat, ShaderInfo.BlurHorizontal);

                    cmd.Blit(renderTexs[RTIndex.Color_copy].colorBuffer,
                        renderTexs[RTIndex.Color_final].colorBuffer,
                        fullscreenMat, ShaderInfo.BlurVertical);

                    cmd.Blit(renderTexs[RTIndex.Alpha_final].colorBuffer,
                        renderTexs[RTIndex.Alpha_copy].colorBuffer,
                        fullscreenMat, ShaderInfo.BlurHorizontal);

                    cmd.Blit(renderTexs[RTIndex.Alpha_copy].colorBuffer,
                        renderTexs[RTIndex.Alpha_final].colorBuffer,
                        fullscreenMat, ShaderInfo.BlurVertical);
                }
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
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    public override void Create()
    {
        pass = new()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents
        };

        // endPass = new();
        // endPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        pass.Setup();
        renderer.EnqueuePass(pass);
    }
}