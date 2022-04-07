#if UNITY_EDITOR

using UnityEngine;
using VRC.SDK3.Avatars.Components;
using UnityEditor;
using UnityEditor.Animations;
using AnimatorAsCode.V0;
using Linguini.Aac.V0;
using System;
using System.Collections.Generic;

namespace Linguini
{
    public class Toggle : AacDefinition
    {
        public GameObject[] items;

        public override Action Generate(AacFlBase aac)
        {
            foreach (var item in items)
            {
                // Create a layer in the FX animator.
                // Additional layers can be created in the FX animator (see later in the manual).
                var fx = aac.CreateSupportingFxLayer(item.name);

                // Creates a Bool parameter in the FX layer.
                var itemParam = fx.BoolParameter($"Toggle{item.name}");

                // The first created state is the default one connected to the "Entry" node.
                // States are automatically placed on the grid (see later in the manual).
                var hidden =
                    fx
                        .NewState("Hidden") // Animation assets are generated as sub-assets of the asset container. // The animation path to my.skinnedMesh is relative to my.avatar
                        .WithAnimation(aac.NewClip().Toggling(item, false));
                var shown =
                    fx
                        .NewState("Shown")
                        .WithAnimation(aac.NewClip().Toggling(item, true));

                hidden.TransitionsFromAny().When(itemParam.IsTrue());
                shown.TransitionsFromAny().When(itemParam.IsFalse());
            }

            return () =>
            {
                foreach (var item in items)
                {
                    aac.RemoveAllSupportingLayers(item.name);
                    aac.RemoveAllParameterIfNotUsed($"Toggle{item.name}");
                }
            };
        }
    }
}

#endif