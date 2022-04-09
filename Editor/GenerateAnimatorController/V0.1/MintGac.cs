#if UNITY_EDITOR

using Linguini.GenerateAnimatorController.V0_1;
using UnityEditor.Animations;
using UnityEngine;
using VRC.SDK3.Avatars.Components;
using Util = Linguini.GenerateAnimatorController.V0_1.Util;

namespace Linguini
{
    public class MintGac : Generator
    {
        public VRCAvatarDescriptor avatar;

        [Header("Coat")]
        public GameObject Coat;

        public Material[] alternativeCoatMaterials;

        [Header("World Constraint")]
        public GameObject worldConstraint;

        public GameObject cube;

        public GameObject screen;

        [Header("Anti Metaverse")]
        public GameObject antiMetaverse;

        public override Generated Generate()
        {
            var fx = new Util.FX(avatar);
            fx.Toggle(new Transform[] { cube.transform });

            return fx;
        }
    }
}

#endif