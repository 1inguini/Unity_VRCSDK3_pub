#if UNITY_EDITOR

using System.Linq;
using System.Collections.Generic;
using UnityEditor.Animations;
using UnityEngine;
using UnityEditor;

namespace Linguini.GenerateAnimatorController.V0_1
{
    public abstract class Generator : MonoBehaviour
    {
        public AnimatorController controller;

        public class Generated
        {
            public List<AnimatorControllerLayer> layers =
                new List<AnimatorControllerLayer>();

            public List<AnimatorControllerParameter> parameters =
                new List<AnimatorControllerParameter>();

            public List<Object> subAssets = new List<Object>();

            //public static Generated operator +(Generated g0, Generated g1) =>
            //    new Generated
            //    {
            //        layers = g0.layers.Concat(g1.layers),
            //        parameters = g0.parameters.Concat(g1.parameters),
            //        subAssets = g0.subAssets.Concat(g1.subAssets)
            //    };

            public AnimatorControllerLayer NewLayer(string name)
            {
                var layer = Util.New.Layer(name);
                layers.Add(layer);
                return layer;
            }

            public Util.BoolParameter NewBoolParameter(string name)
            {
                var parameter = Util.New.BoolParameter(name);
                parameters.Add(parameter);
                return parameter;
            }

            public AnimationClip NewClip(string name)
            {
                var clip = Util.New.Clip(name);
                subAssets.Add(clip);
                return clip;
            }
        }

        public abstract Generated Generate();

        private Generated generated;

        public void Sync()
        {
            generated = Generate();
            Clean();
            Add();
        }

        public void Add()
        {
            // add layers
            foreach (var layer in generated.layers)
            {
                controller.AddLayer(layer);
            }

            // add parameters
            foreach (var parameter in generated.parameters)
            {
                controller.AddParameter(parameter);
            }

            // add sub-assets
            foreach (var subAsset in generated.subAssets)
            {
                AssetDatabase.AddObjectToAsset(subAsset, controller);
            }
        }

        public void Clean()
        {
            // clean layers
            foreach (var layer in generated.layers)
            {
                controller.layers =
                    controller.layers
                        .Where(defined => defined.name != layer.name)
                        .ToArray();
            }

            // clean parameters
            foreach (var parameter in generated.parameters)
            {
                controller.parameters =
                    controller.parameters
                        .Where(defiend => defiend.name != parameter.name)
                        .ToArray();
            }

            // clean sub-assets
            var allSubAssets = AssetDatabase
                .LoadAllAssetsAtPath(AssetDatabase.GetAssetPath(controller));
            foreach (var subAsset in generated.subAssets)
            {
                foreach (var defined in allSubAssets)
                {
                    if (defined.name == subAsset.name)
                    {
                        AssetDatabase.RemoveObjectFromAsset(defined);
                    }
                }
            }
        }
    }

    [CustomEditor(typeof(Generator), true)]
    public class Generator_Editor : Editor
    {
        public override void OnInspectorGUI()
        {
            this.DrawDefaultInspector();

            if (GUILayout.Button("Sync"))
            {
                ((Generator)target).Sync();
            }

            //if (GUILayout.Button("Add"))
            //{
            //    ((Generator)target).Add();
            //}

            if (GUILayout.Button("Clean"))
            {
                ((Generator)target).Clean();
            }
        }
    }
}

#endif