#if UNITY_EDITOR

using Linguini.Aac.V0;
using UnityEngine;
using UnityEditor;
using Linguini.Script;

namespace Linguini
{

    //[CustomEditor(typeof(Mint), true)]
    //public class Mint_Editor : AacDefinition_Editor { }

    public class Mint : AacDefinition
    {

        [MenuItem("AacDefinition/Mint")]
        public static void ShowWindow() => GetWindow<Mint>();

        [Header("Coat")]
        public GameObject coat;
        public Transform Coat => coat.transform;

        public Material[] alternativeCoatMaterials;

        [Header("World Constraint")]
        public GameObject worldConstraint;
        public Transform WorldConstraint => worldConstraint.transform;
        public Transform Cube => WorldConstraint.FindOrAdd("Cube");
        public Transform Screen => WorldConstraint.FindOrAdd("Screen");
        public Transform RayMarching => WorldConstraint.FindOrAdd("RayMarching");

        //public GameObject cube;

        //public GameObject screen;

        //public GameObject raymarching;

        [Header("Anti Metaverse")]
        public Transform antiMetaverse;

        public override void Commit()
        {
            // lighting of lilToon
            ShaderFloats(
                shaderFamily: "lilToon",
                ("_AsUnlit", 0, 1),
                ("_LightMinLimit", 0, 1),
                ("_LightMaxLimit", 0, 10),
                ("_MonochromeLighting", 0, 1),
                ("_ShadowStrength", 0, 1),
                ("_ShadowNormalStrength", 0, 1),
                ("_ShadowBorder", 0, 1),
                ("_ShadowBlur", 0, 1),
                ("_Shadow2ndBorder", 0, 1),
                ("_Shadow2ndBlur", 0, 1),
                ("_ShadowBorderRange", 0, 1),
                ("_ShadowMainStrength", 0, 1),
                ("_ShadowEnvStrength", 0, 1));

            // Coat Materials
            SwapMaterial(Coat.GetComponent<Renderer>(), 0, alternativeCoatMaterials);

            // WorldConstraint
            Enable(WorldConstraint);
            Toggle(Cube);

            Toggle(Screen);

            Toggle(
                Screen.Find("Constraint").GetComponent<Renderer>(),
                Cube.Find("Constraint").GetComponent<Renderer>());

            // Anti Metaverse
            Toggle(antiMetaverse);
        }
    }
}

#endif