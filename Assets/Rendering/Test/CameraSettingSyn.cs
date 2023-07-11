using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
[RequireComponent(typeof(Camera))]
public class CameraSettingSyn : MonoBehaviour
{
    // Update is called once per frame
#if UNITY_EDITOR
    void Update()
    {
        var cam = SceneView.lastActiveSceneView.camera;
        var mainCam = GetComponent<Camera>();
        // cam.cullingMask = mainCam.cullingMask;
        mainCam.transform.position = cam.transform.position;
        mainCam.transform.rotation = cam.transform.rotation;
    }
#endif
}