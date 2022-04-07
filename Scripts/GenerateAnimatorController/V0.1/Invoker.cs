#if UNITY_EDITOR

using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using static
    Linguini.GenerateAnimatorController.V0_1.Generator;

namespace Linguini.GenerateAnimatorController.V0_1
{
    public class Invoker : MonoBehaviour
    {
        public AnimatorController controller;

        public Generator[] generators =
            new Generator[1];

        public void Sync()
        {
            foreach (var generator in generators)
                generator.Sync();
        }

        public void Add()
        {
            foreach (var generator in generators)
                generator.Add();
        }

        public void Clean()
        {
            foreach (var generator in generators)
                generator.Clean();
        }
    }

    [CustomEditor(typeof(Invoker), true)]
    public class Invoker_Editor : Editor
    {
        public override void OnInspectorGUI()
        {
            this.DrawDefaultInspector();

            if (GUILayout.Button("Sync"))
            {
                ((Invoker)target).Sync();
            }

            //if (GUILayout.Button("Add"))
            //{
            //    ((Invoker)target).Add();
            //}

            if (GUILayout.Button("Clean"))
            {
                ((Invoker)target).Clean();
            }
        }
    }
}

#endif