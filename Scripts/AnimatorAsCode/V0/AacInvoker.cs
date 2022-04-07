#if UNITY_EDITOR

using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using AnimatorController = UnityEditor.Animations.AnimatorController;
using VRC.SDK3.Avatars.Components;
using AnimatorAsCode.V0;

namespace Linguini.Aac.V0
{
    public class AacInvoker : MonoBehaviour
    {
        public VRCAvatarDescriptor avatar;

        public AnimatorController assetContainer;

        public bool writeDefaults;

        public AacDefinition[] definitions;
    }

    [CustomEditor(typeof(AacInvoker), true)]
    public class AacInvoker_Editor : Editor
    {
        private List<Action> removeFns = new List<Action>();

        public override void OnInspectorGUI()
        {
            this.DrawDefaultInspector();

            if (GUILayout.Button("Sync"))
            {
                var my = (AacInvoker)target;

                foreach (var definition in my.definitions)
                {
                    var aac = AacV0.Create(Config(definition));

                    aac.ClearPreviousAssets();

                    removeFns.Add(definition.Generate(aac));
                }
            }
            if (GUILayout.Button("Remove"))
            {
                foreach (var definition in ((AacInvoker)target).definitions)
                {
                    var aac = AacV0.Create(Config(definition));

                    aac.ClearPreviousAssets();
                }

                foreach (var removeFn in removeFns)
                {
                    removeFn();
                }
            }

            if (GUILayout.Button("Clean asset container"))
            {
                var my = (AacInvoker)target;
                var allSubAssets =
                    AssetDatabase
                        .LoadAllAssetsAtPath(AssetDatabase
                            .GetAssetPath(my.assetContainer));
                foreach (var subAsset in allSubAssets)
                {
                    if (
                        subAsset is AnimationClip ||
                        subAsset is BlendTree ||
                        subAsset is AvatarMask
                    )
                    {
                        AssetDatabase.RemoveObjectFromAsset(subAsset);
                    }
                }
            }
        }

        private AacConfiguration Config(AacDefinition definition)
        {
            var my = (AacInvoker)target;
            return new AacConfiguration
            {
                SystemName = definition.GetType().ToString(),
                AvatarDescriptor = my.avatar,
                AnimatorRoot = my.avatar.transform,
                DefaultValueRoot = my.avatar.transform,
                AssetContainer = my.assetContainer,
                AssetKey = definition.assetKey,
                DefaultsProvider =
                    new AacDefaultsProvider(writeDefaults: my.writeDefaults)
            };
        }
    }
}

#endif