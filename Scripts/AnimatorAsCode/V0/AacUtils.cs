#if UNITY_EDITOR
using AnimatorAsCode.V0;
using System;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Animations;
using VRC.SDK3.Avatars.Components;

namespace Linguini.Aac.V0.AacUtils
{
    public static class Misc
    {
        public static string ConstraintSourceWeight(int i) =>
            $"Sources.Array.data[{i}].weight";
    }

    public static class Layer
    {
        public static AacFlState Entry(this AacFlLayer layer) => layer.NewState("Entry");
    }
}
#endif