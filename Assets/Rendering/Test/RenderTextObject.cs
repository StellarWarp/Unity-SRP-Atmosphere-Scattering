using System;
using UnityEngine;
using UnityEngine.Serialization;

[ExecuteAlways]
public class RenderTextObject : MonoBehaviour
{
    public RenderTexture renderTexture;

    private void OnEnable()
    {
        // renderTexture.descriptor = Camera.current.targetTexture.descriptor;
        // MeshRenderer mr = GetComponent<MeshRenderer>();
        // if(!TestFeature.instance.meshRenderers.Find(x => x == mr))
        //     TestFeature.instance.meshRenderers.Add(mr);
    }

    private void OnRenderObject()
    {
        // Camera.current.targetTexture = renderTexture;
        // RenderTexture.active = renderTexture;
        // Graphics.d
        // Graphics.Blit(Camera.current.targetTexture, renderTexture, renderer.material);
        //
        // RenderTexture.active = Camera.current.targetTexture;
        
    }
}