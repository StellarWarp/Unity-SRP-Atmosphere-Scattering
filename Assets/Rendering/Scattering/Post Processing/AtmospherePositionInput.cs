using UnityEngine;

[ExecuteAlways]
public class AtmospherePositionInput : MonoBehaviour
{
    public Material atmosphere;

    // Update is called once per frame
    void Update()
    {
        atmosphere.SetVector("_Center", transform.position);
    }
}
